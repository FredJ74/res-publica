-- ===========================================================================
-- DONNER DES MATIERES A UN COMMERCE HISTORIQUE (30 septembre 2026)
-- ---------------------------------------------------------------------------
-- ARBITRAGE DE GAME DESIGN (Fred, 30 septembre 2026). Le don de matiere est
-- autorise vers N'IMPORTE QUEL commerce qui accepte cette matiere, quel qu'en
-- soit le proprietaire : joueur, PNJ, institution, Etat. C'est volontaire. Le
-- don doit notamment permettre de DEBLOQUER un commerce dont la caisse est vide
-- ou dont le proprietaire est absent, mais qui a besoin de matieres pour
-- continuer a fonctionner.
--
-- REGLE : le don emprunte la meme primitive de transfert physique que la vente,
-- sans contrepartie financiere.
--   - il retire reellement la quantite de l'inventaire du joueur ;
--   - il ajoute reellement cette quantite au stock du commerce ;
--   - il ne verse rien au joueur ;
--   - il ne debite rien de la caisse du commerce ;
--   - il reste donc possible avec une caisse a 0 FR.
-- Toutes les autres validations sont conservees : matiere reellement acceptee,
-- quantite entiere strictement positive, quantite reellement possedee, plafond
-- respecte, aucune duplication, verdict serveur, operation atomique.
-- Capacite restante nulle ou matiere non acceptee : la vente ET le don sont
-- refuses, identiquement.
--
-- POURQUOI UNE NOUVELLE FONCTION PLUTOT QUE `fonds_matiere_apporter`
-- ---------------------------------------------------------------------------
-- fonds_matiere_apporter respecte DEJA exactement ces regles pour les fonds PJ
-- (prix 0, aucun mouvement d'argent, `v_payable` non borne par la caisse quand
-- le prix est nul) : rien a y changer, et rien n'y est duplique ici. Elle ne
-- peut pas servir les commerces historiques pour trois raisons structurelles,
-- pas par accident :
--   1. elle refuse tout blob de version < 2 (`pas_un_fonds_pj`) ;
--   2. elle exige une `implantation`, que les commerces historiques n'ont pas ;
--   3. elle deduit les matieres acceptees de `typesAutorises` -> generiques ->
--      recettes, la ou l'historique les deduit de `carte` -> recettes_commerce
--      (et, pour l'armurerie, de recettes_production).
-- La DERIVATION DES MATIERES ACCEPTEES est donc reellement differente entre les
-- deux moteurs ; c'est la seule chose qui l'est. Le reste -- transfert physique,
-- CMUP, historique, idempotence -- est mutualise : cette fonction ecrit dans le
-- MEME registre `apports_matieres` que les fonds PJ, avec le meme vocabulaire de
-- mode et les memes motifs de refus.
--
-- ET SURTOUT : `commerce_acheter_matiere` devient un simple RELAIS vers cette
-- fonction, en mode 'vente'. Il n'y a donc pas deux economies de l'apport de
-- matiere cote historique, mais une seule, avec deux portes d'entree. C'est ce
-- qui empeche les deux chemins de diverger au prochain lot.
--
-- NON TRAITE ICI, DELIBEREMENT : ni la fusion des deux moteurs economiques
-- (dette examinee separement), ni l'absence de controle de PRESENCE PHYSIQUE
-- cote historique. Ce second point est un manque PREEXISTANT de
-- commerce_acheter_matiere -- les fonds PJ, eux, exigent la presence. L'ajouter
-- changerait le comportement de la VENTE, ce que ce lot n'a pas mandat de faire.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. LA PRIMITIVE COMMUNE DE L'APPORT, COTE MOTEUR HISTORIQUE
-- ---------------------------------------------------------------------------
create or replace function public.commerce_apporter_matiere(
  p_requete text, p_acteur text, p_entreprise text,
  p_matiere text, p_qte integer, p_mode text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
DECLARE
  v_deja    record;
  v_data    jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_mode    text := lower(btrim(coalesce(p_mode, 'vente')));
  v_mat     text := btrim(coalesce(p_matiere, ''));
  v_inv     jsonb; v_arg numeric; v_liquide numeric; v_detenu numeric;
  v_sm      jsonb; v_cmm jsonb; v_caisse numeric; v_stock numeric;
  v_plafond numeric; v_declare numeric; v_smc numeric;
  v_prix    numeric; v_total numeric; v_cout_moyen numeric;
  v_categorie text; v_caisse_id text; v_r jsonb; v_inv_apres jsonb;
  v_accepte boolean; v_place numeric;
BEGIN
  -- Marqueur de caisse interne : identique a commerce_acheter_matiere, sans quoi
  -- les mouvements de caisse institutionnelle seraient refuses.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_entreprise, '') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  -- Quantite : entiere et strictement positive. `IS DISTINCT FROM` ferme la
  -- porte aux valeurs non entieres autant qu'aux nulles.
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  -- REJEU : on rend le meme verdict sans rien refaire. Meme registre et meme
  -- forme de reponse que les fonds PJ.
  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'mode', v_deja.mode, 'quantite', v_deja.quantite,
                              'qte', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'total', v_deja.montant);
  END IF;

  -- ORDRE DES VERROUS : entreprises puis personnages_donnees, comme
  -- commerce_acheter_matiere et fonds_matiere_apporter. Un ordre unique dans
  -- tout le domaine commerce est ce qui empeche deux transactions croisees de
  -- s'attendre mutuellement.
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := coalesce(v_data->>'type', '');
  v_pays  := coalesce(v_data->>'country', 'republic');
  v_ville := coalesce(v_data->>'city', 'capitale');

  -- MATIERE ACCEPTEE : deduite des recettes, jamais d'une liste tenue a la main.
  -- Reprise a l'identique de commerce_acheter_matiere -- c'est precisement la
  -- part qui ne peut pas etre partagee avec les fonds PJ.
  IF v_type = 'armurerie' THEN
    SELECT EXISTS (SELECT 1 FROM public.recettes_production r, jsonb_object_keys(r.materiaux) m
                    WHERE r.pays = v_pays AND m = v_mat) INTO v_accepte;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(coalesce(v_data->'carte', '[]'::jsonb)) c
        JOIN public.recettes_commerce r ON r.id = c.value, jsonb_object_keys(r.materiaux) m
       WHERE m = v_mat) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee'); END IF;

  SELECT coalesce(inventory, '[]'::jsonb), coalesce(arg, 0), coalesce(liquide, 0), coalesce(day, 1)
    INTO v_inv, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  v_sm     := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm    := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  v_stock  := coalesce((v_sm->>v_mat)::numeric, 0);

  -- PLAFOND DE STOCK. L'armurerie n'en a jamais eu : regle metier historique,
  -- conservee telle quelle. Le don ne s'en affranchit pas davantage que la
  -- vente -- capacite restante nulle, les deux sont refuses.
  v_place := NULL;
  IF v_type <> 'armurerie' THEN
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_declare := (v_data->'parametres'->'stockMax'->>v_mat)::numeric;
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, coalesce(v_smc, 20))
                      ELSE coalesce(v_smc, 20) END;
    v_place := GREATEST(0, v_plafond - v_stock);
    IF v_stock + p_qte > v_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
    END IF;
  END IF;

  -- PRIX. C'est LA seule difference entre les deux modes, et elle se lit ici en
  -- une ligne : un don vaut zero. Tout ce qui suit en decoule mecaniquement --
  -- aucune branche `IF v_mode = 'don'` ailleurs dans le corps de la fonction.
  IF v_mode = 'don' THEN
    v_prix := 0;
  ELSE
    v_prix := (v_data->'parametres'->'prixAchatMatiere'->>v_mat)::numeric;
    IF v_prix IS NULL THEN
      SELECT prix_achat_fournisseur INTO v_prix FROM public.ressources_economie WHERE cle = v_mat;
    END IF;
    IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
    v_prix := GREATEST(0, v_prix);
  END IF;
  v_total := round(v_prix * p_qte, 2);

  -- MOUVEMENT DE CAISSE. `v_total = 0` pour un don : la caisse n'est ni lue ni
  -- debitee, et un commerce a 0 FR accepte donc le don -- c'est exactement le
  -- deblocage voulu par l'arbitrage. On n'appelle meme pas la caisse
  -- institutionnelle pour un delta nul.
  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  IF v_total > 0 THEN
    IF v_categorie IS NOT NULL THEN
      v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
      v_r := public.caisse_institution_mouvement(v_caisse_id, -v_total, false);
      IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
      END IF;
    ELSE
      IF v_caisse < v_total THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
      END IF;
    END IF;
  END IF;

  -- CMUP : cout moyen pondere sur ce que le commerce a REELLEMENT paye. Un don
  -- entre donc a 0 et fait baisser le cout moyen, exactement comme chez les
  -- fonds PJ : le commerce a vraiment recu cette matiere pour rien.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>v_mat)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  -- TRANSFERT PHYSIQUE. La meme primitive pour les deux modes ; seul le credit
  -- du joueur est conditionne au montant.
  v_inv_apres := public.inventaire_retirer(v_inv, v_mat, p_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres,
         arg     = v_arg     + v_total,
         liquide = v_liquide + v_total,
         updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data || jsonb_build_object(
    'stockMatieres',     jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[v_mat], to_jsonb(v_cout_moyen)));
  IF v_categorie IS NULL THEN
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_total), true);
  END IF;
  v_data := public.entreprise_ajouter_historique(v_data, -v_total,
    CASE WHEN v_mode = 'don' THEN 'Don de matière première (' ELSE 'Achat de matière première (' END
    || v_mat || ' x' || p_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  INSERT INTO public.apports_matieres
    (requete, fonds_id, acteur, matiere, mode, quantite, prix_unitaire, montant)
  VALUES (p_requete, p_entreprise, p_acteur, v_mat, v_mode, p_qte, v_prix, v_total);

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', p_qte, 'qte', p_qte, 'demandee', p_qte,
    'prixUnitaire', v_prix, 'montant', v_total, 'total', v_total,
    'stock', v_stock + p_qte,
    'placeRestante', CASE WHEN v_place IS NULL THEN NULL ELSE GREATEST(0, v_place - p_qte) END,
    'coutMoyen', v_cout_moyen, 'caisse', v_caisse - v_total,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total, 'inventory', v_inv_apres);
END; $fn$;

comment on function public.commerce_apporter_matiere(text, text, text, text, integer, text) is
  'Apport d''une matiere premiere a un commerce du moteur historique, par vente (prix fixe par le commerce) ou par don (prix 0, aucun mouvement d''argent, possible caisse vide). Deduit la matiere acceptee de la carte du commerce (ou des recettes de production pour l''armurerie). Conserve plafond, possession reelle, CMUP et historique. Idempotente par cle de requete, dans le meme registre apports_matieres que les fonds PJ.';

revoke all on function public.commerce_apporter_matiere(text, text, text, text, integer, text) from public, anon;
grant execute on function public.commerce_apporter_matiere(text, text, text, text, integer, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. L'ANCIEN NOM DEVIENT UN RELAIS : UNE SEULE ECONOMIE DE L'APPORT
-- ---------------------------------------------------------------------------
-- Le corps de commerce_acheter_matiere etait, a l'octet pres, celui de la
-- migration du 20 septembre (empreinte verifiee en production avant reecriture).
-- Il est desormais vide de toute logique : la vente et le don passent par la
-- meme fonction, et il devient impossible de corriger l'une en oubliant l'autre.
-- La signature est INCHANGEE -- aucune surcharge creee, aucune ambiguite
-- PostgREST possible.
--
-- La cle de requete est fabriquee ici, cote serveur : cette porte d'entree n'en
-- recevait pas et reste donc non idempotente, exactement comme avant. Les
-- appelants qui veulent l'idempotence appellent commerce_apporter_matiere.
create or replace function public.commerce_acheter_matiere(
  p_acteur text, p_entreprise text, p_matiere text, p_qte integer)
returns jsonb
language sql
security definer
set search_path to 'public'
as $relais$
  SELECT public.commerce_apporter_matiere(
    'appro-legacy-' || md5(random()::text || clock_timestamp()::text),
    p_acteur, p_entreprise, p_matiere, p_qte, 'vente');
$relais$;

comment on function public.commerce_acheter_matiere(text, text, text, integer) is
  'RELAIS HISTORIQUE (30 septembre 2026) vers commerce_apporter_matiere en mode vente. Ne contient plus aucune logique economique : conserve pour ne casser aucun appelant. Non idempotente (aucune cle de requete recue) ; preferer commerce_apporter_matiere.';

revoke all on function public.commerce_acheter_matiere(text, text, text, integer) from public, anon;
grant execute on function public.commerce_acheter_matiere(text, text, text, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. GARDE-FOU : AUCUNE SURCHARGE, SOUS AUCUN DES DEUX NOMS
-- ---------------------------------------------------------------------------
-- Une seconde signature sous l'un de ces noms rendrait PostgREST ambigu (42725)
-- et les deux portes d'entree tomberaient d'un coup. On refuse la migration
-- plutot que de le decouvrir en jeu.
DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'commerce_apporter_matiere';
  IF n <> 1 THEN RAISE EXCEPTION 'commerce_apporter_matiere : % signatures, 1 attendue', n; END IF;
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'commerce_acheter_matiere';
  IF n <> 1 THEN RAISE EXCEPTION 'commerce_acheter_matiere : % signatures, 1 attendue', n; END IF;
END $garde$;

-- Le commentaire du registre mentionnait le seul ecrivain d'alors.
comment on table public.apports_matieres is
  'Journal des apports de matiere premiere a un commerce (vente ou don), pour les DEUX moteurs : fonds PJ via fonds_matiere_apporter, commerces historiques via commerce_apporter_matiere. La colonne fonds_id porte l''identifiant entreprises dans les deux cas. La cle de requete porte l''idempotence. Ferme au client.';
