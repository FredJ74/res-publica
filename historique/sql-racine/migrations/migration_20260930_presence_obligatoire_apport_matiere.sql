-- ===========================================================================
-- LA PRESENCE PHYSIQUE REDEVIENT OBLIGATOIRE POUR APPORTER UNE MATIERE
-- (30 septembre 2026)
-- ---------------------------------------------------------------------------
-- ARBITRAGE (Fred, 30 septembre 2026) : il n'a JAMAIS ete prevu qu'on puisse
-- vendre ou donner une matiere premiere a distance. La presence du personnage
-- dans le commerce destinataire est obligatoire pour TOUS les commerces, sans
-- exception liee au moteur : fonds PJ, historique, PNJ, institutionnel, Etat,
-- armurerie. Le comportement du moteur historique etait donc un BUG, pas une
-- regle metier a preserver.
--
-- CAUSE EXACTE DU DEFAUT HISTORIQUE
-- ---------------------------------------------------------------------------
-- commerce_acheter_matiere n'a jamais lu la position du personnage. Elle verifie
-- l'identite (exiger_acteur), la matiere, le stock detenu, le plafond et la
-- caisse -- mais rien qui rattache l'appelant au LIEU du commerce. Le moteur des
-- fonds PJ, arrive un an plus tard, a lui ete ecrit avec fonds_acteur_present
-- des le depart. Les deux moteurs ne divergeaient donc pas par accident de
-- lecture : l'un posait la question, l'autre ne l'a jamais posee.
--
-- CE QUI A RENDU LE CORRECTIF NON TRIVIAL
-- ---------------------------------------------------------------------------
-- On ne pouvait pas recopier fonds_acteur_present telle quelle. Elle compare la
-- piece avec `IS NOT DISTINCT FROM`, donc exige une piece EXACTE ; or les
-- commerces historiques n'ont pas tous une piece. Releve en base avant d'ecrire
-- une ligne, et confirme par le miroir commerces_types (image serveur de
-- BUILDING_COMMERCE_TYPE) :
--   - 7 commerces occupent un BATIMENT ENTIER  (cle 'hotel-republica', 'marche',
--     'cafe-gare-montrouge'...) et leur blob porte roomId = null ;
--   - 4 occupent une PIECE PRECISE (cle 'stade|buvette', 'marche-psm|etals'...)
--     et leur blob porte cette piece.
-- Les 11 blobs s'accordent exactement avec le miroir : la granularite variable
-- n'est pas du desordre, c'est une REGLE DU JEU. Une verification au niveau de
-- la piece aurait donc refuse toute vente a La Republia et dans les cafes de
-- Montrouge -- on aurait remplace un trou par une panne.
--
-- LA VALIDATION RETENUE : UNE SEULE NOTION DE PRESENCE POUR TOUT LE JEU
-- ---------------------------------------------------------------------------
-- acteur_present_sur_site(acteur, pays, ville, batiment, piece) :
--   - lit la position FAISANT AUTORITE, celle de personnages_donnees, jamais un
--     ecran affiche par le navigateur ;
--   - exige pays + ville + batiment identiques ;
--   - la piece n'est comparee que si le site en declare une ; sinon le batiment
--     entier vaut presence -- exactement la granularite de commerces_types ;
--   - FERME PAR DEFAUT : un site sans pays, sans ville ou sans batiment ne
--     permet pas d'etablir la presence, donc refuse.
-- fonds_acteur_present devient un RELAIS vers elle : une seule regle de
-- localisation dans le jeu, et non deux qui pourraient se contredire. C'est ce
-- que demande l'arbitrage -- eviter deux controles independants.
--
-- CE RELAIS NE CHANGE RIEN POUR LES FONDS PJ, et c'est verifie plutot que
-- suppose : le bloc de garde en fin de migration refuse de s'appliquer si un
-- seul fonds avait une implantation incomplete (la seule difference theorique
-- entre l'ancienne fonction et la nouvelle porte sur une piece nulle). Au jour
-- de la migration, l'unique fonds en base a une implantation complete.
--
-- PAS UN CHANTIER DE NAVIGATION. La position lue ici est celle du serveur. Le
-- desaccord observe hier entre l'ecran affiche apres rafraichissement et la
-- sortie reelle du batiment concerne l'affichage, pas cette colonne : aucune
-- ligne de ce correctif ne s'en approche.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. LA PRIMITIVE UNIQUE DE PRESENCE
-- ---------------------------------------------------------------------------
create or replace function public.acteur_present_sur_site(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
DECLARE a record;
BEGIN
  -- FERME PAR DEFAUT. Un site dont on ignore le pays, la ville ou le batiment ne
  -- permet pas d'etablir une presence : on refuse, on ne devine pas. C'est ce qui
  -- protege les lignes 'entreprises' anciennes ou de test, restees sans lieu.
  IF p_acteur IS NULL OR coalesce(p_pays, '') = ''
     OR coalesce(p_ville, '') = '' OR coalesce(p_batiment, '') = '' THEN
    RETURN false;
  END IF;

  -- LA POSITION FAISANT AUTORITE, et elle seule. Le navigateur ne transmet ici
  -- aucune localisation : il ne pourrait pas mentir meme s'il essayait.
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR a.current_city IS NULL OR a.current_building IS NULL THEN
    RETURN false;
  END IF;

  IF a.country          IS DISTINCT FROM p_pays     THEN RETURN false; END IF;
  IF a.current_city     IS DISTINCT FROM p_ville    THEN RETURN false; END IF;
  IF a.current_building IS DISTINCT FROM p_batiment THEN RETURN false; END IF;

  -- La piece ne compte que si le site en designe une. Sept commerces du jeu
  -- occupent leur batiment entier (voir commerces_types) : y etre, c'est y etre.
  IF coalesce(p_piece, '') <> '' AND a.current_room IS DISTINCT FROM p_piece THEN
    RETURN false;
  END IF;

  RETURN true;
END $fn$;

comment on function public.acteur_present_sur_site(text, text, text, text, text) is
  'Presence physique d''un personnage sur un site du jeu, d''apres la position faisant autorite (personnages_donnees). Exige pays + ville + batiment ; la piece n''est comparee que si le site en declare une, ce qui couvre les commerces occupant un batiment entier. Ferme par defaut : un site sans lieu complet ne permet aucune presence. Regle de localisation UNIQUE du jeu -- fonds_acteur_present la relaie.';

revoke all on function public.acteur_present_sur_site(text, text, text, text, text) from public, anon;
grant execute on function public.acteur_present_sur_site(text, text, text, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. LA PRESENCE DES FONDS PJ DEVIENT UN RELAIS DE LA PRIMITIVE UNIQUE
-- ---------------------------------------------------------------------------
-- Trois fonctions l'appellent (fonds_matiere_apporter, fonds_reference_produire_lots,
-- acheter_produit_commerce). Elles ne changent pas d'une ligne, et continuent de
-- voir exactement le meme verdict : l'implantation d'un fonds vient du bail, qui
-- designe toujours une piece precise.
create or replace function public.fonds_acteur_present(p_acteur text, p_implantation jsonb)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $relais$
  SELECT p_implantation IS NOT NULL
     AND public.acteur_present_sur_site(
           p_acteur,
           p_implantation->>'country',
           p_implantation->>'city',
           p_implantation->>'buildingId',
           p_implantation->>'roomId');
$relais$;

comment on function public.fonds_acteur_present(text, jsonb) is
  'RELAIS (30 septembre 2026) vers acteur_present_sur_site, a partir de l''implantation d''un fonds PJ. Ne contient plus de regle de localisation propre : il n''en existe qu''une dans le jeu.';

revoke all on function public.fonds_acteur_present(text, jsonb) from public, anon;
grant execute on function public.fonds_acteur_present(text, jsonb) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. LE SITE DES TROIS ARMURERIES VIVANTES EST INSCRIT DANS LEUR BLOB
-- ---------------------------------------------------------------------------
-- Ces lignes sont nees avant que entreprise_assurer_existence ne persiste le
-- lieu : elles n'ont ni buildingId ni roomId, et seraient donc desormais
-- INJOIGNABLES (ferme par defaut). Le lieu inscrit ici n'est pas invente -- c'est
-- celui que le client declare lui-meme depuis toujours dans
-- chargerEntrepriseParId : `{ batiment: 'armurerie', room: null }`. Les armureries
-- creees plus tard le portent deja.
--
-- roomId reste absent volontairement : l'armurerie occupe son batiment entier,
-- comme les sept commerces batiment-entier de commerces_types.
update public.entreprises
   set data = data || jsonb_build_object('buildingId', 'armurerie'),
       updated_at = now()
 where coalesce((data->>'version')::numeric, 0) < 2
   and data->>'type' = 'armurerie'
   and coalesce(data->>'buildingId', '') = ''
   and coalesce(data->>'country', '') <> ''
   and coalesce(data->>'city', '') <> '';

-- NON TOUCHEES, ET C'EST VOULU : 'armurerie-republic' (ligne dormante d'avant le
-- decoupage par ville : plus aucun code ne fabrique cet identifiant) et
-- 'zztest-commerce-p3' (ligne de test). Sans pays ni ville, leur lieu ne peut pas
-- etre deduit ; elles restent donc fermees, ce qui est le bon defaut.

-- ---------------------------------------------------------------------------
-- 4. commerce_apporter_matiere EXIGE LA PRESENCE
-- ---------------------------------------------------------------------------
-- UN SEUL CONTROLE POUR LES DEUX MODES ET LES DEUX PORTES. La verification est
-- posee dans commerce_apporter_matiere, que commerce_acheter_matiere relaie
-- depuis ce matin : la vente par l'ancien nom, la vente par le nouveau et le don
-- franchissent donc tous les trois la meme garde. Il n'y a pas deux controles a
-- maintenir en accord.
--
-- ELLE EST POSEE SOUS LE VERROU du personnage, avant toute autre verification
-- metier et avant la moindre ecriture : un refus a distance ne touche ni
-- l'inventaire, ni le stock, ni aucune caisse. Le verrou du personnage est
-- simplement remonte avant le controle de la matiere -- l'ordre entreprises puis
-- personnages_donnees, commun a tout le domaine commerce, est preserve.
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

  -- ORDRE DES VERROUS : entreprises puis personnages_donnees, comme
  -- fonds_matiere_apporter et acheter_produit_commerce.
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := coalesce(v_data->>'type', '');
  v_pays  := coalesce(v_data->>'country', 'republic');
  -- La ville ne prend PLUS 'capitale' par defaut : cette valeur servait de repli
  -- inoffensif tant qu'on ne s'en servait que pour nommer une caisse
  -- institutionnelle, mais elle deviendrait un mensonge si on la comparait a la
  -- position du joueur. Inerte pour les caisses : les deux seules lignes sans
  -- ville ne sont ni buvette ni marche, donc aucun identifiant de caisse n'en
  -- depend.
  v_ville := coalesce(v_data->>'city', '');

  SELECT coalesce(inventory, '[]'::jsonb), coalesce(arg, 0), coalesce(liquide, 0), coalesce(day, 1)
    INTO v_inv, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- PRESENCE PHYSIQUE. La marchandise doit etre portee sur place : on ne vend ni
  -- ne donne a distance, quel que soit le proprietaire du commerce. Verifie sous
  -- le verrou du personnage, donc sur une position qui ne peut plus bouger, et
  -- AVANT la moindre ecriture.
  IF NOT public.acteur_present_sur_site(p_acteur, v_pays, v_ville,
                                        v_data->>'buildingId', v_data->>'roomId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

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

comment on function public.commerce_apporter_matiere(text, text, text, text, integer, text) is
  'Apport d''une matiere premiere a un commerce du moteur historique, par vente (prix fixe par le commerce) ou par don (prix 0, aucun mouvement d''argent, possible caisse vide). EXIGE LA PRESENCE PHYSIQUE sur le site du commerce (acteur_present_sur_site), verifiee sous verrou avant toute ecriture. Deduit la matiere acceptee de la carte du commerce (recettes de production pour l''armurerie). Conserve plafond, possession reelle, CMUP et historique. Idempotente par cle de requete, dans le meme registre apports_matieres que les fonds PJ.';

revoke all on function public.commerce_apporter_matiere(text, text, text, text, integer, text) from public, anon;
grant execute on function public.commerce_apporter_matiere(text, text, text, text, integer, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. GARDES : ON REFUSE LA MIGRATION PLUTOT QUE DE LE DECOUVRIR EN JEU
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer; ids text; nom text;
BEGIN
  -- a) Le relais ne doit rien changer pour les fonds PJ. La seule difference
  --    theorique avec l'ancienne fonction porte sur une implantation incomplete.
  SELECT count(*), string_agg(id, ', ') INTO n, ids FROM public.entreprises
   WHERE coalesce((data->>'version')::numeric, 0) >= 2
     AND (coalesce(data->'implantation'->>'country', '')    = ''
       OR coalesce(data->'implantation'->>'city', '')       = ''
       OR coalesce(data->'implantation'->>'buildingId', '') = ''
       OR coalesce(data->'implantation'->>'roomId', '')     = '');
  IF n > 0 THEN
    RAISE EXCEPTION 'fonds PJ a implantation incomplete (%) : le relais changerait leur verdict de presence -- %', n, ids;
  END IF;

  -- b) Aucune surcharge sous les noms touches : PostgREST deviendrait ambigu.
  FOREACH nom IN ARRAY ARRAY['acteur_present_sur_site', 'fonds_acteur_present',
                             'commerce_apporter_matiere', 'commerce_acheter_matiere']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom;
    IF n <> 1 THEN RAISE EXCEPTION '% : % signatures, 1 attendue', nom, n; END IF;
  END LOOP;

  -- c) Tout commerce historique VIVANT doit desormais avoir un site exploitable,
  --    sinon il deviendrait injoignable sans qu'on s'en apercoive. Les deux
  --    lignes connues sans lieu (armurerie-republic, dormante, et
  --    zztest-commerce-p3, de test) sont nommement exclues.
  SELECT count(*), string_agg(id, ', ') INTO n, ids FROM public.entreprises
   WHERE coalesce((data->>'version')::numeric, 0) < 2
     AND id NOT IN ('armurerie-republic', 'zztest-commerce-p3')
     AND (coalesce(data->>'buildingId', '') = ''
       OR coalesce(data->>'country', '')    = ''
       OR coalesce(data->>'city', '')       = '');
  IF n > 0 THEN
    RAISE EXCEPTION 'commerce(s) historique(s) sans site exploitable, ils seraient injoignables (%) : %', n, ids;
  END IF;
END $garde$;
