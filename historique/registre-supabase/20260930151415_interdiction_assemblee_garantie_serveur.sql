-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260930151415
-- Nom original      : interdiction_assemblee_garantie_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-30 15:14:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ad1f87034dfd10b637282c8b6c0ccb02
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'INTERDICTION DE L'ASSEMBLEE DEVIENT UNE GARANTIE SERVEUR (30 sept. 2026)
-- ARBITRAGE DEJA VALIDE : une matiere premiere interdite par l'Assemblee est hors
-- de son economie legale. Ni VENDUE ni DONNEE a un commerce ; la gratuite du
-- transfert ne contourne jamais l'interdiction.
--
-- CE QUI MANQUAIT : la regle etait DEJA decidee par le serveur --
-- assembleeControlerVenteLegale n'invente rien, elle interroge
-- assemblee_verifier_vente -- mais elle etait APPLIQUEE par le navigateur : le
-- client demandait « est-ce legal ? » puis renoncait de lui-meme. Un client qui ne
-- pose pas la question n'etait arrete par rien, aucune des deux RPC d'apport ne
-- consultant la loi. Decider au serveur et appliquer au client, c'est encore
-- appliquer au client.
--
-- SOURCE DE VERITE INCHANGEE (on n'y transpose rien, on l'appelle) :
--   assemblee_propositions            -> lois (type 'mecanique', statut 'adoptee')
--   assemblee_categories_interdiction -> categorie -> matieres / types / sousTypes
--   assemblee_objet_vise              -> la correspondance
--   assemblee_loi_en_vigueur(pays, objet, instant) -> LA regle atomique
-- Elle borne deja l'entree en vigueur (adoptee_ts <= instant, non-retroactivite
-- §38) a l'horloge du SERVEUR. Le navigateur ne transmet ni loi, ni booleen, ni
-- date : seulement la matiere et la quantite.
--
-- PRIMITIVE COMMUNE : matiere_apport_refus_legal(pays, matiere) rend NULL si
-- licite, sinon le refus COMPLET deja redige. Les deux moteurs l'appellent a
-- l'identique et ne peuvent donc diverger ni sur la forme d'objet interrogee
-- ('stackKey'), ni sur l'instant, ni sur le vocabulaire du refus.
--
-- LE PAYS EST CELUI DU COMMERCE, sans ambiguite : depuis le correctif de presence
-- du meme jour, un apport exige que le personnage soit dans le commerce, donc que
-- son pays soit celui du commerce. Les lois etant portees par
-- assemblee_propositions.country, un empire sans Assemblee n'a aucune loi et la
-- fonction rend NULL : la restriction « Republia uniquement » (§37) est obtenue
-- par les donnees, sans etre ecrite nulle part.
--
-- PORTEE : UNIQUEMENT VENDRE ET DONNER A UN COMMERCE. Quatre fonctions serveur
-- retirent une matiere de l'inventaire pour la porter dans un etablissement
-- (releve exhaustif sur pg_proc) : commerce_apporter_matiere et
-- fonds_matiere_apporter sont protegees ici ; vendre_matiere_a_usine (USINE) et
-- vendre_ressource_medicale (DISPENSAIRE) ont la MEME faiblesse mais ne sont pas
-- des commerces -- etendre la regle a l'industrie et a la sante depasse
-- VENDRE/DONNER et releve d'un arbitrage. Signale au rapport, pas decide ici.
-- Rien d'autre n'est touche : la production consomme le stock DU COMMERCE, pas
-- l'inventaire du joueur ; elle n'est ni concernee ni bloquee.

-- 1. LA PRIMITIVE COMMUNE DE CONTROLE LEGAL
create or replace function public.matiere_apport_refus_legal(p_pays text, p_matiere text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_loi jsonb;
BEGIN
  IF coalesce(p_pays, '') = '' OR coalesce(p_matiere, '') = '' THEN RETURN NULL; END IF;

  -- UNE MATIERE EST UN OBJET EMPILABLE dont la cle est celle de
  -- RESSOURCES_ECONOMIE : c'est ce que `stackKey` designe dans les categories
  -- d'interdiction. Cette traduction n'existe qu'ici, pour les deux moteurs.
  -- L'instant est celui du serveur : la non-retroactivite est portee par
  -- assemblee_loi_en_vigueur, on ne la reimplemente pas.
  v_loi := public.assemblee_loi_en_vigueur(p_pays,
             jsonb_build_object('stackKey', p_matiere), now());
  IF v_loi IS NULL THEN RETURN NULL; END IF;

  -- Le refus est rendu DEJA REDIGE pour que les deux moteurs ne puissent pas le
  -- formuler differemment. La loi accompagne le verdict : le joueur a le droit de
  -- savoir laquelle lui est opposee.
  RETURN jsonb_build_object('ok', false, 'raison', 'matiere_interdite',
                            'matiere', p_matiere, 'loi', v_loi);
END $fn$;

comment on function public.matiere_apport_refus_legal(text, text) is
  'Controle legal COMMUN de l''apport d''une matiere premiere a un commerce (vente ou don). Rend NULL si l''apport est licite, sinon le refus complet (raison matiere_interdite, avec la loi). Source de verite : assemblee_loi_en_vigueur, donc les lois adoptees de assemblee_propositions et les categories de assemblee_categories_interdiction, a l''horloge du serveur. Le navigateur ne transmet aucun etat legal. Appelee par commerce_apporter_matiere et fonds_matiere_apporter.';

revoke all on function public.matiere_apport_refus_legal(text, text) from public, anon;
grant execute on function public.matiere_apport_refus_legal(text, text) to authenticated, service_role;

-- 2. LE MOTEUR HISTORIQUE CONSULTE LA LOI
-- Le controle est pose juste apres la presence, donc avant toute autre
-- verification metier et avant la moindre ecriture. L'escalade se lit de haut en
-- bas : qui etes-vous, etes-vous la, en avez-vous le droit -- puis seulement
-- l'affaire est-elle faisable. commerce_acheter_matiere relayant vers cette
-- fonction, l'ancienne porte herite de la garde sans une ligne de plus.
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
  v_accepte boolean; v_place numeric; v_refus jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_entreprise, '') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  -- REJEU : on rend le meme verdict sans rien refaire.
  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'mode', v_deja.mode, 'quantite', v_deja.quantite,
                              'qte', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'total', v_deja.montant);
  END IF;

  -- ORDRE DES VERROUS : entreprises puis personnages_donnees.
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := coalesce(v_data->>'type', '');
  v_pays  := coalesce(v_data->>'country', 'republic');
  -- La ville ne prend PLUS 'capitale' par defaut : ce repli etait inoffensif tant
  -- qu'il ne servait qu'a nommer une caisse institutionnelle, mais il deviendrait
  -- un mensonge compare a la position du joueur.
  v_ville := coalesce(v_data->>'city', '');

  SELECT coalesce(inventory, '[]'::jsonb), coalesce(arg, 0), coalesce(liquide, 0), coalesce(day, 1)
    INTO v_inv, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- PRESENCE PHYSIQUE. On ne vend ni ne donne a distance.
  IF NOT public.acteur_present_sur_site(p_acteur, v_pays, v_ville,
                                        v_data->>'buildingId', v_data->>'roomId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LEGALITE. Une matiere interdite par l'Assemblee est hors economie legale : ni
  -- vendue, ni donnee. Le serveur lit la loi lui-meme ; aucun etat legal ne vient
  -- du navigateur.
  v_refus := public.matiere_apport_refus_legal(v_pays, v_mat);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;

  -- MATIERE ACCEPTEE : deduite des recettes, jamais d'une liste tenue a la main.
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

  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  v_sm     := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm    := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  v_stock  := coalesce((v_sm->>v_mat)::numeric, 0);

  -- PLAFOND DE STOCK. L'armurerie n'en a jamais eu : regle metier historique.
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

  -- PRIX. LA seule difference entre les deux modes, et elle tient en une ligne.
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

  -- MOUVEMENT DE CAISSE. v_total = 0 pour un don : la caisse n'est ni lue ni
  -- debitee, un commerce a 0 FR accepte donc le don.
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

  -- CMUP : cout moyen pondere sur ce que le commerce a REELLEMENT paye.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>v_mat)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

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

revoke all on function public.commerce_apporter_matiere(text, text, text, text, integer, text) from public, anon;
grant execute on function public.commerce_apporter_matiere(text, text, text, text, integer, text) to authenticated, service_role;

-- 3. LE MOTEUR DES FONDS PJ CONSULTE LA MEME LOI
-- Corps repris a l'IDENTIQUE de la production (releve par pg_get_functiondef avant
-- reecriture, y compris les apports du lot C7 : matiere_hors_activites, la colonne
-- `acceptee`, `illimite` et v_reste). Seul ajout : les deux lignes de controle
-- legal, juste apres la presence.
create or replace function public.fonds_matiere_apporter(
  p_requete text, p_acteur text, p_fonds_id text,
  p_matiere text, p_qte integer, p_mode text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
DECLARE
  v_deja   record;
  v_data   jsonb;
  v_mat    text := btrim(coalesce(p_matiere, ''));
  v_mode   text := lower(btrim(coalesce(p_mode, 'vente')));
  v_veut   integer := GREATEST(0, coalesce(p_qte, 0));
  v_m      record;
  v_inv    jsonb; v_jour integer;
  v_detenu numeric; v_capacite integer; v_payable integer;
  v_prix   numeric; v_qte integer; v_montant numeric;
  v_caisse numeric; v_stock numeric; v_cmup numeric; v_nouveau numeric;
  v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb; v_reste integer; v_refus jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'mode', v_deja.mode);
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(p_acteur, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  -- LEGALITE. Meme primitive, meme verdict, meme vocabulaire que le moteur
  -- historique : une matiere interdite n'est ni vendue ni donnee, et la gratuite
  -- ne contourne rien. Le pays est celui de l'implantation du fonds.
  v_refus := public.matiere_apport_refus_legal(v_data->'implantation'->>'country', v_mat);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;

  SELECT * INTO v_m FROM public.fonds_matieres_accessibles(p_fonds_id) m WHERE m.matiere = v_mat;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites', 'matiere', v_mat); END IF;
  IF NOT v_m.acceptee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'matiere', v_mat); END IF;
  IF v_m.plafond_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini',
                              'pays', v_data->'implantation'->>'country'); END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(day,1) INTO v_inv, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu); END IF;

  v_capacite := v_m.place_restante;
  IF v_capacite <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein',
                              'stock', v_m.stock, 'maximum', v_m.maximum); END IF;

  v_prix   := CASE WHEN v_mode = 'don' THEN 0 ELSE GREATEST(0, coalesce(v_m.prix_achat, 0)) END;
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));

  v_payable := CASE WHEN v_prix <= 0 THEN v_veut ELSE floor(v_caisse / v_prix)::integer END;
  v_qte := LEAST(v_veut, floor(v_detenu)::integer, v_capacite, v_payable);

  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'prixUnitaire', v_prix); END IF;

  v_montant := round(v_prix * v_qte, 2);

  IF v_montant > 0 THEN
    UPDATE public.personnages_donnees
       SET arg     = COALESCE(arg, 0)     + v_montant,
           liquide = COALESCE(liquide, 0) + v_montant,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_introuvable'); END IF;
  END IF;

  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm   := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_stock := GREATEST(0, coalesce((v_sm->>v_mat)::numeric, 0));
  v_cmup  := coalesce((v_cmm->>v_mat)::numeric, 0);
  v_nouveau := round(((v_cmup * v_stock) + (v_prix * v_qte)) / (v_stock + v_qte), 4);

  v_inv_apres := public.inventaire_retirer(v_inv, v_mat, v_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres, updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data
    || jsonb_build_object(
         'stockMatieres',     jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_qte)),
         'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[v_mat], to_jsonb(v_nouveau)))
    || jsonb_build_object('caisse', v_caisse - v_montant);

  v_data := public.entreprise_ajouter_historique(v_data, -v_montant,
    CASE WHEN v_mode = 'don' THEN 'Don de matiere (' ELSE 'Achat de matiere (' END
    || v_mat || ' x' || v_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  INSERT INTO public.apports_matieres
    (requete, fonds_id, acteur, matiere, mode, quantite, prix_unitaire, montant)
  VALUES (p_requete, p_fonds_id, p_acteur, v_mat, v_mode, v_qte, v_prix, v_montant);

  v_reste := CASE WHEN v_m.maximum = 0
                  THEN GREATEST(0, coalesce(v_m.plafond_pays, 0) - (v_stock + v_qte))::integer
                  ELSE GREATEST(0, v_m.maximum - (v_stock + v_qte))::integer END;

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', v_qte, 'demandee', v_veut, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stock', v_stock + v_qte, 'maximum', v_m.maximum, 'illimite', v_m.maximum = 0,
    'placeRestante', v_reste,
    'coutMoyen', v_nouveau, 'caisse', v_caisse - v_montant, 'inventory', v_inv_apres);
END; $fn$;

revoke all on function public.fonds_matiere_apporter(text, text, text, text, integer, text) from public, anon;
grant execute on function public.fonds_matiere_apporter(text, text, text, text, integer, text) to authenticated, service_role;

-- 4. GARDES : ON REFUSE LA MIGRATION PLUTOT QUE DE LE DECOUVRIR EN JEU
DO $garde$
DECLARE n integer; nom text;
BEGIN
  -- a) Les DEUX moteurs d'apport consultent effectivement la primitive commune.
  FOREACH nom IN ARRAY ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom
       AND pg_get_functiondef(p.oid) LIKE '%matiere_apport_refus_legal%';
    IF n <> 1 THEN RAISE EXCEPTION '% ne consulte pas le controle legal commun', nom; END IF;
  END LOOP;

  -- b) Les deux moteurs gardent leur controle de presence : ce lot ne doit rien
  --    defaire du precedent.
  FOREACH nom IN ARRAY ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom
       AND (pg_get_functiondef(p.oid) LIKE '%acteur_present_sur_site%'
         OR pg_get_functiondef(p.oid) LIKE '%fonds_acteur_present%');
    IF n <> 1 THEN RAISE EXCEPTION '% a perdu son controle de presence', nom; END IF;
  END LOOP;

  -- c) Une seule signature partout, et la regle de fond relayee est toujours la.
  FOREACH nom IN ARRAY ARRAY['matiere_apport_refus_legal', 'assemblee_loi_en_vigueur',
                             'assemblee_objet_vise', 'commerce_apporter_matiere',
                             'fonds_matiere_apporter']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom;
    IF n <> 1 THEN RAISE EXCEPTION '% : % signatures, 1 attendue', nom, n; END IF;
  END LOOP;

  -- d) La source de verite n'est pas vide de sens : sans categories, aucune loi ne
  --    viserait jamais rien et la garde serait un decor.
  SELECT count(*) INTO n FROM public.assemblee_categories_interdiction;
  IF n = 0 THEN RAISE EXCEPTION 'assemblee_categories_interdiction est vide : le controle legal ne viserait rien'; END IF;
END $garde$;