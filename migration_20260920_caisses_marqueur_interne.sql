-- =====================================================================
-- CAISSES : MARQUEUR D'APPEL INTERNE, PRIMITIVES DURCIES, AUTORITES
-- 20 septembre 2026
-- =====================================================================
--
-- OBJET
-- -----
-- Ce lot ferme l'exploit « un citoyen sans poste vide n'importe quelle caisse
-- institutionnelle ». La primitive heritee caisse_institution_mouvement est
-- appelee directement par le bundle deploye ; on ne peut donc pas la revoquer.
-- Elle est durcie a la place, et distingue desormais l'appel INTERNE (une RPC
-- metier qui porte deja son propre controle d'autorite) de l'appel DIRECT
-- depuis le navigateur, qui n'en avait aucun.
--
-- La distinction passe par un marqueur de session, rp.caisse_interne, pose en
-- tete de corps par chaque RPC appelante et lu par les deux primitives. Le
-- marqueur est LOCAL a la transaction (3e argument de set_config = true) : il
-- ne fuit pas d'un appel a l'autre. Un navigateur ne peut pas le poser --
-- set_config vit dans pg_catalog et PostgREST n'expose que le schema public.
--
-- PORTEE du durcissement : DEBITS et CREATION de caisse. Les credits restent
-- ouverts : verser a l'Etat n'est pas une attaque, et 17 des 29 sites du jeu
-- sont des recettes versees par des citoyens sans poste.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES
-- ----------------------------------
--   20260920091001  caisse_marqueur_appel_interne
--   20260920091040  caisse_primitive_heritee_durcie
--   20260920091408  caisses_autorites_postes_existants
--
-- POURQUOI CE FICHIER N'EST PAS UNE COPIE DES TROIS MIGRATIONS
-- ------------------------------------------------------------
-- La migration 091001 n'est pas du DDL declaratif : c'est un bloc DO qui relit
-- en base la definition de chaque fonction appelant caisse_institution_mouvement
-- et la reecrit en injectant la ligne
--     PERFORM set_config('rp.caisse_interne', 'on', true);
-- juste apres le BEGIN du corps. Son resultat depend donc de l'etat de la base
-- au moment ou on l'execute : le rejouer ailleurs ne produirait pas le meme
-- schema, et 14 fonctions portent aujourd'hui en production une definition qui
-- n'existe dans aucun fichier du depot.
--
-- Ce fichier remplace ce bloc DO par les definitions FINALES, relevees
-- verbatim en production avec pg_get_functiondef() :
--   * 13 des 14 appelants qui POSENT le marqueur ;
--   * 2 primitives qui le LISENT (caisse_institution_mouvement et
--     caisse_institution_mouvement_plafonne, reecrites par 091040).
-- Le 14e appelant, entrepot_reverser, a pour source canonique le lot
-- « entrepots » (voir plus bas) : il n'est pas duplique ici.
-- Le bloc DO n'est volontairement pas recopie. Il reste consultable dans
-- supabase_migrations.schema_migrations.
--
-- AVERTISSEMENT
-- -------------
-- Ce fichier reproduit un ETAT FINAL, pas un historique. Il est idempotent
-- (CREATE OR REPLACE partout, ON CONFLICT sur les donnees) et rejouable, mais
-- il ne rejoue pas les etapes intermediaires du 20 septembre : il pose
-- directement le resultat.
--
-- DEPENDANCES — a rejouer AVANT ce fichier
-- ----------------------------------------
-- Les 15 fonctions sont donnees en entier : aucune n'a besoin d'une definition
-- prealable. Ce sont les TABLES et les FONCTIONS APPELEES qui doivent exister.
--
-- Presentes dans le depot, verifiees :
--   migration_caisse_institution.sql      -- caisse_institution_mouvement (1re version)
--   migration_caisses_batiments_etat.sql  -- batiment_caisse_mouvement, batiments_etat
--   migration_cession_imprimerie.sql      -- imprimerie_cession_finaliser
--   migration_vente_structure_encaisser.sql -- vente_structure_encaisser
--   migration_autorite_rpc_mutantes.sql   -- est_appel_serveur(), REVOKE sur batiment_caisse_mouvement
--
-- MANQUANTE DU DEPOT — BLOQUANTE :
--   La migration de production 20260919232818 (caisse_autorite_par_batiment)
--   n'est versionnee nulle part. Elle cree public.caisses_autorites (la table
--   alimentee plus bas), public.caisses_mouvements_clients (le journal des
--   refus) et public.caisse_postes_requis() (lue par les deux primitives).
--   Sans elle, la section DONNEES echoue et les primitives ne compilent qu'a
--   l'execution. Elle doit etre versionnee separement.
--
-- Non versionnees dans le depot non plus, mais seulement APPELEES (le schema
-- se cree sans elles, c'est l'execution qui les exige) :
--   commerce_acheter_matiere, commerce_produire, commerce_vendre_produit,
--   entrepot_commander, entreprise_preempter, fret_dedouaner,
--   cellule_renseignement_creer, militaire_arrieres_regler,
--   militaire_compagnie_creer, militaire_solde_percevoir
--   -- aucun fichier .sql du depot ne definissait ces fonctions avant ce lot ;
--   leurs fichiers de reference (migration_moteur_commerce.sql,
--   migration_fret_dedouaner.sql, migration_cellule_renseignement_socle.sql,
--   les migration_militaire_*.sql) ne contiennent que des notes ou d'autres
--   objets. C'est ce fichier qui les versionne pour la premiere fois.
--
-- AUCUN DOUBLON
-- -------------
-- entrepot_reverser porte le marqueur, mais sa SOURCE CANONIQUE est
-- migration_20260920_entrepot_reversement_mairie.sql, ou elle vit avec la
-- table et les trois fonctions qui forment sa mecanique. Elle n'est donc pas
-- reprise ici : aucune fonction de ce lot n'est definie deux fois dans le
-- depot.
--
-- GRANT / REVOKE / ALTER
-- ----------------------
-- Aucun. Les trois migrations d'origine n'en contiennent pas : le durcissement
-- se fait entierement dans le corps des fonctions, precisement parce que
-- revoquer aurait casse le client deploye. A noter : ALTER FUNCTION ... SET est
-- refuse sur Supabase (le role postgres n'est pas superutilisateur, « permission
-- denied to set parameter ») -- d'ou le set_config a l'execution.
-- =====================================================================


-- =====================================================================
-- 1. LES 15 FONCTIONS, ETAT FINAL DE PRODUCTION
-- =====================================================================
-- Relevees verbatim par pg_get_functiondef() ; seul le point-virgule final est
-- ajoute (pg_get_functiondef n'en emet pas). Ordre alphabetique.

CREATE OR REPLACE FUNCTION public.batiment_caisse_mouvement(p_pays text, p_ville text, p_building text, p_souscle text, p_delta numeric, p_stock_cle text DEFAULT NULL::text, p_stock numeric DEFAULT 0, p_stock_max numeric DEFAULT NULL::numeric, p_exiger_existant boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_brut jsonb; v_d jsonb; v_obj jsonb; v_caisse numeric; v_st numeric; v_existe boolean;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  -- ATTRIBUTION OBLIGATOIRE : soit le serveur (cron, service_role), soit un compte portant
  -- reellement un personnage. Ne dit rien de l'AUTORITE sur le montant : voir le chantier
  -- caisse_institution_mouvement, laisse ouvert.
  IF NOT public.est_appel_serveur() AND public.mon_personnage() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_ville), '') = ''
     OR COALESCE(btrim(p_building), '') = '' OR COALESCE(btrim(p_souscle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta IS NULL OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_id := p_pays || '_' || p_ville || '_' || p_building;
  SELECT data INTO v_brut FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_existe := FOUND;

  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
              WHEN jsonb_typeof(v_brut) = 'string' THEN (v_brut #>> '{}')::jsonb
              WHEN jsonb_typeof(v_brut) = 'object' THEN v_brut
              ELSE '{}'::jsonb END;

  IF p_exiger_existant AND jsonb_typeof(v_d -> p_souscle) IS DISTINCT FROM 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_obj := CASE WHEN jsonb_typeof(v_d -> p_souscle) = 'object' THEN v_d -> p_souscle ELSE '{}'::jsonb END;
  v_caisse := CASE WHEN jsonb_typeof(v_obj -> 'caisse') = 'number' THEN (v_obj ->> 'caisse')::numeric ELSE 0 END;

  IF v_caisse + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  v_obj := v_obj || jsonb_build_object('caisse', v_caisse + p_delta);

  IF p_stock_cle IS NOT NULL AND COALESCE(p_stock, 0) <> 0 THEN
    v_st := CASE WHEN jsonb_typeof(v_obj -> p_stock_cle) = 'number' THEN (v_obj ->> p_stock_cle)::numeric ELSE 0 END;
    IF v_st + p_stock < 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_st, 'caisse', v_caisse);
    END IF;
    IF p_stock_max IS NOT NULL AND v_st + p_stock > p_stock_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plafond', 'stock', v_st,
                                'stock_max', p_stock_max, 'caisse', v_caisse);
    END IF;
    v_obj := v_obj || jsonb_build_object(p_stock_cle, v_st + p_stock);
  END IF;

  v_d := v_d || jsonb_build_object(p_souscle, v_obj);

  IF v_existe THEN
    UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = v_id;
  ELSE
    INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
    VALUES (v_id, p_pays, p_ville, p_building, to_jsonb(v_d::text), now());
  END IF;

  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse + p_delta,
                            'stock', CASE WHEN p_stock_cle IS NULL THEN NULL ELSE v_obj -> p_stock_cle END);
END;
$function$;

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(p_id text, p_delta numeric, p_exiger_existant boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_solde numeric; v_existe boolean;
  v_moi text; v_pays text; v_postes text[]; v_client boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_client := coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
              AND NOT public.est_appel_serveur();

  IF p_delta < 0 AND v_client THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_reservee_au_serveur');
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                      WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, p_delta, 'primitive_heritee', false, 'autorite_insuffisante');
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant');
  END IF;

  IF v_existe THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde + p_delta),
           updated_at = now()
     WHERE id = p_id;
  ELSE
    IF v_client THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_inexistante');
    END IF;
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (p_id, jsonb_build_object('solde', v_solde + p_delta), now());
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(p_id text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric;
        v_moi text; v_pays text; v_postes text[];
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant <= 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
     AND NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL
         OR NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                         WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, -p_montant, 'primitive_heritee_plafonnee', false, 'autorite_insuffisante');
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'verse', 0);
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', v_solde);
  END IF;
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', v_solde - v_verse);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cellule_renseignement_creer(p_pays_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa   constant integer := 3;
  c_cout constant numeric := 500;
  v_nom text; v_poste text; v_pays text;
  v_pa integer; v_caisse text; v_mvt jsonb;
  v_cellule text; v_echeance timestamptz;
  v_nb_id integer; v_libres_h integer; v_libres_f integer;
  v_besoin_h integer; v_besoin_f integer;
  v_agents jsonb := '[]'::jsonb;
  r record; v_couv text; v_prec text; v_idx integer := 0;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF p_pays_cible IS NULL OR btrim(p_pays_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF p_pays_cible = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_mon_pays'); END IF;

  SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles;
  IF v_nb_id < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identites_reelles_incompletes',
                              'definies', v_nb_id, 'attendues', 4); END IF;

  SELECT count(*) FILTER (WHERE sexe = 'H'), count(*) FILTER (WHERE sexe = 'F')
    INTO v_besoin_h, v_besoin_f FROM public.renseignement_identites_reelles;

  -- Couvertures LIBRES du pays cible, par sexe.
  SELECT count(*) FILTER (WHERE c.sexe = 'H'), count(*) FILTER (WHERE c.sexe = 'F')
    INTO v_libres_h, v_libres_f
    FROM public.renseignement_couvertures c
   WHERE c.pays = p_pays_cible
     AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                      WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                        AND a.statut IN ('actif', 'detenu'));
  IF v_libres_h < v_besoin_h OR v_libres_f < v_besoin_f THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pool_couvertures_insuffisant',
      'libres_h', v_libres_h, 'requis_h', v_besoin_h,
      'libres_f', v_libres_f, 'requis_f', v_besoin_f); END IF;

  SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'disponibles', v_pa); END IF;

  v_caisse := v_pays || '_gouvernement-min_def';
  v_mvt := public.caisse_institution_mouvement(v_caisse, -c_cout, false);
  IF coalesce((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
      'caisse', v_caisse, 'requis', c_cout, 'detail', v_mvt ->> 'raison'); END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_nom;

  v_cellule  := 'cel-' || (extract(epoch from clock_timestamp())*1000)::bigint
                       || '-' || substr(md5(random()::text), 1, 6);
  v_echeance := now() + interval '10 days';

  INSERT INTO public.cellules_renseignement
    (id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le)
  VALUES (v_cellule, v_pays, p_pays_cible, v_nom, 'active', c_cout, v_caisse, v_echeance);

  FOR r IN SELECT role, vrai_nom, dup, sexe
             FROM public.renseignement_identites_reelles ORDER BY role
  LOOP
    -- Couverture portee par CE MEME role lors de sa mission precedente dans ce
    -- pays : on l'evite si le pool le permet. Aucune table d'historique --
    -- l'information vit deja dans les lignes d'agents des cellules passees.
    SELECT a.nom_couverture INTO v_prec
      FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c2 ON c2.id = a.cellule_id
     WHERE a.role = r.role AND a.pays_couverture = p_pays_cible
       AND c2.pays_proprietaire = v_pays
     ORDER BY a.cree_le DESC LIMIT 1;

    SELECT c.nom INTO v_couv
      FROM public.renseignement_couvertures c
     WHERE c.pays = p_pays_cible
       AND c.sexe IS NOT DISTINCT FROM r.sexe            -- sexe de l'agent
       AND c.nom IS DISTINCT FROM coalesce(v_prec, '')   -- pas la precedente
       AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                        WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                          AND a.statut IN ('actif', 'detenu'))
     ORDER BY random() LIMIT 1;

    -- Repli si l'evitement rendait le tirage impossible : « si possible »,
    -- jamais au prix d'un echec de creation.
    IF v_couv IS NULL THEN
      SELECT c.nom INTO v_couv
        FROM public.renseignement_couvertures c
       WHERE c.pays = p_pays_cible
         AND c.sexe IS NOT DISTINCT FROM r.sexe
         AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                          WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                            AND a.statut IN ('actif', 'detenu'))
       ORDER BY random() LIMIT 1;
    END IF;
    IF v_couv IS NULL THEN RAISE EXCEPTION 'pool_couvertures_epuise'; END IF;

    v_idx := v_idx + 1;
    INSERT INTO public.agents_renseignement
      (id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut)
    VALUES (v_cellule || '-a' || v_idx, v_cellule, r.role, r.vrai_nom, r.dup,
            p_pays_cible, v_couv, 'actif');
    v_agents := v_agents || jsonb_build_array(jsonb_build_object(
      'role', r.role, 'vrai_nom', r.vrai_nom, 'couverture', v_couv,
      'sexe', r.sexe, 'dup', r.dup, 'statut', 'actif'));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'cellule', v_cellule, 'pays_cible', p_pays_cible,
    'echeance', v_echeance, 'cout', c_cout, 'caisse', v_caisse,
    'pa_restants', v_pa - c_pa, 'agents', v_agents);
END;
$function$;

CREATE OR REPLACE FUNCTION public.commerce_acheter_matiere(p_acteur text, p_entreprise text, p_matiere text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_inv jsonb; v_arg numeric; v_liquide numeric; v_detenu numeric;
  v_sm jsonb; v_cmm jsonb; v_caisse numeric; v_stock numeric;
  v_plafond numeric; v_declare numeric; v_smc numeric;
  v_prix numeric; v_total numeric; v_cout_moyen numeric;
  v_categorie text; v_caisse_id text; v_r jsonb; v_inv_apres jsonb;
  v_accepte boolean;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := COALESCE(v_data->>'type','');
  v_pays  := COALESCE(v_data->>'country','republic');
  v_ville := COALESCE(v_data->>'city','capitale');

  IF v_type = 'armurerie' THEN
    SELECT EXISTS (SELECT 1 FROM public.recettes_production r, jsonb_object_keys(r.materiaux) m
                    WHERE r.pays = v_pays AND m = p_matiere) INTO v_accepte;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(COALESCE(v_data->'carte','[]'::jsonb)) c
        JOIN public.recettes_commerce r ON r.id = c.value, jsonb_object_keys(r.materiaux) m
       WHERE m = p_matiere) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee');
  END IF;

  SELECT COALESCE(inventory,'[]'::jsonb), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_inv, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_matiere);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  v_sm     := COALESCE(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm    := COALESCE(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  v_stock  := COALESCE((v_sm->>p_matiere)::numeric, 0);

  IF v_type <> 'armurerie' THEN
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_declare := (v_data->'parametres'->'stockMax'->>p_matiere)::numeric;
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, COALESCE(v_smc, 20))
                      ELSE COALESCE(v_smc, 20) END;
    IF v_stock + p_qte > v_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein',
                                'placeRestante', GREATEST(0, v_plafond - v_stock));
    END IF;
  END IF;

  v_prix := (v_data->'parametres'->'prixAchatMatiere'->>p_matiere)::numeric;
  IF v_prix IS NULL THEN
    SELECT prix_achat_fournisseur INTO v_prix FROM public.ressources_economie WHERE cle = p_matiere;
  END IF;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_total := v_prix * p_qte;

  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  IF v_categorie IS NOT NULL THEN
    v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
    v_r := public.caisse_institution_mouvement(v_caisse_id, -v_total, false);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
    END IF;
  ELSE
    IF v_caisse < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
  END IF;

  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((COALESCE((v_cmm->>p_matiere)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  v_inv_apres := public.inventaire_retirer(v_inv, p_matiere, p_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres, arg = v_arg + v_total, liquide = v_liquide + v_total,
         updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_matiere], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_matiere], to_jsonb(v_cout_moyen)));
  IF v_categorie IS NULL THEN
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_total), true);
  END IF;
  v_data := public.entreprise_ajouter_historique(v_data, -v_total,
    'Achat de matière première (' || p_matiere || ' x' || p_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total, 'inventory', v_inv_apres);
END; $function$;

CREATE OR REPLACE FUNCTION public.commerce_produire(p_acteur text, p_entreprise text, p_recette text, p_ordre text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_bat text; v_jour integer;
  v_rec record; v_prod record; v_prix_fixe numeric;
  v_pa_requis integer; v_salaire numeric; v_portions integer; v_materiaux jsonb;
  v_sm jsonb; v_sp jsonb; v_stock numeric; v_plafond numeric; v_declare numeric; v_smc numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text; v_r jsonb;
  v_pa integer; v_arg numeric; v_liquide numeric;
  v_m text; v_q jsonb; v_dispo numeric; v_cout numeric; v_mo numeric;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type := COALESCE(v_data->>'type','');
  v_pays := COALESCE(v_data->>'country','republic');
  v_ville:= COALESCE(v_data->>'city','capitale');
  v_bat  := COALESCE(v_data->>'buildingId','');

  IF v_type = 'armurerie' THEN
    SELECT * INTO v_prod FROM public.recettes_production WHERE id = p_recette AND pays = v_pays;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    v_materiaux := v_prod.materiaux;
    v_portions  := 1;
    v_prix_fixe := NULL;
    SELECT valeur INTO v_pa_requis FROM public.entreprises_constantes WHERE cle = 'pa_production_armurerie';
    SELECT valeur INTO v_salaire   FROM public.entreprises_constantes WHERE cle = 'salaire_production_armurerie';
  ELSE
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = p_recette;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(p_recette))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_carte');
    END IF;
    IF v_rec.types_autorises IS NOT NULL THEN
      IF NOT (v_rec.types_autorises @> jsonb_build_array(to_jsonb(v_type))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'type_non_autorise');
      END IF;
    END IF;
    IF v_rec.pays_autorises IS NOT NULL THEN
      IF NOT (v_rec.pays_autorises @> jsonb_build_array(to_jsonb(v_pays))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_autorise');
      END IF;
    END IF;
    IF v_rec.villes_autorisees IS NOT NULL THEN
      IF NOT (v_rec.villes_autorisees @> jsonb_build_array(to_jsonb(v_ville))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'ville_non_autorisee');
      END IF;
    END IF;
    IF v_rec.buildings_autorises IS NOT NULL THEN
      IF NOT (v_rec.buildings_autorises @> jsonb_build_array(to_jsonb(v_bat))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'batiment_non_autorise');
      END IF;
    END IF;
    v_materiaux := v_rec.materiaux;
    v_portions  := v_rec.portions;
    v_pa_requis := v_rec.pa;
    v_prix_fixe := v_rec.prix_fixe;
    SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
    v_salaire := v_rec.pa * COALESCE(v_mo, 0);
  END IF;

  v_sp := COALESCE(v_data->'stockProduits','{}'::jsonb);
  v_stock := COALESCE((v_sp->>p_recette)::numeric, 0);
  v_declare := (v_data->'parametres'->'stockMax'->>p_recette)::numeric;
  IF v_type = 'armurerie' THEN
    v_plafond := v_declare;
  ELSE
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, COALESCE(v_smc,20))
                      ELSE COALESCE(v_smc,20) END;
  END IF;
  IF v_plafond IS NOT NULL AND v_stock + v_portions > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'plafond', v_plafond);
  END IF;

  v_sm := COALESCE(v_data->'stockMatieres','{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_dispo := COALESCE((v_sm->>v_m)::numeric, 0);
    IF v_dispo < (v_q#>>'{}')::numeric THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_m, 'disponible', v_dispo);
    END IF;
  END LOOP;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, 0, 0);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','ordre_refuse'));
    END IF;
  END IF;

  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < COALESCE(v_pa_requis,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;

  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  IF v_categorie IS NOT NULL THEN
    v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
    v_r := public.caisse_institution_mouvement(v_caisse_id, -v_salaire, false);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
    END IF;
  ELSE
    IF v_caisse < v_salaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_salaire), true);
  END IF;

  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
             to_jsonb(COALESCE((v_sm->>v_m)::numeric,0) - (v_q#>>'{}')::numeric));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm, true);
  v_data := jsonb_set(v_data, '{stockProduits}',
                      jsonb_set(v_sp, ARRAY[p_recette], to_jsonb(v_stock + v_portions)), true);

  IF v_type <> 'armurerie' THEN
    IF COALESCE(v_data->>'proprietaire','PNJ') = 'PNJ' AND v_prix_fixe IS NULL THEN
      v_cout := public.commerce_cout_revient_portion(v_data, p_recette);
      IF v_cout IS NOT NULL THEN
        v_data := jsonb_set(v_data, ARRAY['parametres','prixVente',p_recette],
                            to_jsonb(round(v_cout * 2)), true);
      END IF;
    END IF;
  END IF;

  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || p_recette || ' (' || v_portions || ' portions) — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  UPDATE public.personnages_donnees
     SET pa = v_pa - COALESCE(v_pa_requis,0),
         arg = v_arg + v_salaire, liquide = v_liquide + v_salaire, updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'recette', p_recette, 'portions', v_portions,
    'salaire', v_salaire, 'paPreleves', COALESCE(v_pa_requis,0),
    'pa', v_pa - COALESCE(v_pa_requis,0), 'arg', v_arg + v_salaire,
    'liquide', v_liquide + v_salaire,
    'stockProduit', v_stock + v_portions,
    'prixVente', v_data->'parametres'->'prixVente'->p_recette);
END; $function$;

CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_sp jsonb; v_ligne jsonb; v_id text; v_qte numeric; v_stock numeric; v_prix numeric;
  v_dynamique numeric := 0; v_assiette numeric; v_net numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text;
  v_r jsonb; v_taxe jsonb; v_au_catalogue boolean; v_livraison jsonb := '[]'::jsonb;
  v_rec record; v_arg numeric; v_liquide numeric; v_pa_reste integer; v_libelle text := '';
  v_pa_metier numeric := 0; v_pa_actuel integer;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  IF p_mode NOT IN ('comptoir', 'service', 'marche_noir') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END IF;
  IF p_mode = 'service' AND (COALESCE(p_ordre,'') = '' OR COALESCE(p_cost,0) <= 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_requis');
  END IF;
  IF p_produits IS NULL OR jsonb_typeof(p_produits) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
  END IF;
  IF jsonb_array_length(p_produits) = 0 AND p_mode <> 'service' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
  END IF;

  IF COALESCE(p_regle_pa,'') <> '' THEN
    SELECT valeur INTO v_pa_metier FROM public.entreprises_constantes WHERE cle = p_regle_pa;
    IF v_pa_metier IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'regle_pa_inconnue', 'cle', p_regle_pa);
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := COALESCE(v_data->>'type','');
  v_pays  := COALESCE(v_data->>'country','republic');
  v_ville := COALESCE(v_data->>'city','capitale');
  v_sp    := COALESCE(v_data->'stockProduits', '{}'::jsonb);

  FOR v_ligne IN SELECT value FROM jsonb_array_elements(p_produits) LOOP
    v_id  := v_ligne->>'produit';
    v_qte := COALESCE((v_ligne->>'qte')::numeric, 1);
    IF COALESCE(v_id,'') = '' OR v_qte <= 0 OR v_qte <> trunc(v_qte) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
    END IF;
    IF v_type = 'armurerie' THEN
      SELECT EXISTS (SELECT 1 FROM public.recettes_production
                      WHERE id = v_id AND pays = v_pays) INTO v_au_catalogue;
    ELSE
      v_au_catalogue := COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(v_id));
    END IF;
    IF NOT v_au_catalogue THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose', 'produit', v_id);
    END IF;
    v_stock := COALESCE((v_sp->>v_id)::numeric, 0);
    IF v_stock < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                                'produit', v_id, 'stock', v_stock);
    END IF;
    IF p_mode <> 'service' THEN
      v_prix := (v_data->'parametres'->'prixVente'->>v_id)::numeric;
      IF v_prix IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_defini', 'produit', v_id);
      END IF;
      v_dynamique := v_dynamique + v_prix * v_qte
                     * CASE WHEN p_mode = 'marche_noir' THEN 3 ELSE 1 END;
    END IF;
  END LOOP;

  SELECT COALESCE(day,1), COALESCE(pa,0) INTO v_jour, v_pa_actuel
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa_metier > 0 AND v_pa_actuel < v_pa_metier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa_actuel);
  END IF;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'),
                                'detail', v_r);
    END IF;
  END IF;

  IF v_pa_metier > 0 THEN
    UPDATE public.personnages_donnees SET pa = GREATEST(0, pa - v_pa_metier), updated_at = now()
     WHERE name = p_acteur;
  END IF;

  IF v_dynamique > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_dynamique) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'total', v_dynamique);
    END IF;
  END IF;

  SELECT COALESCE(arg,0), COALESCE(liquide,0), COALESCE(pa,0)
    INTO v_arg, v_liquide, v_pa_reste
    FROM public.personnages_donnees WHERE name = p_acteur;

  v_assiette := CASE p_mode WHEN 'service' THEN COALESCE(p_cost,0) ELSE v_dynamique END;
  IF p_mode = 'marche_noir' THEN
    v_net := 0;
  ELSE
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_assiette);
    v_net := COALESCE((v_taxe->>'net')::numeric, v_assiette);
    v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
    IF v_categorie IS NOT NULL THEN
      v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
      PERFORM public.caisse_institution_mouvement(v_caisse_id, v_net, false);
    ELSE
      v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
      v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_net), true);
    END IF;
  END IF;

  FOR v_ligne IN SELECT value FROM jsonb_array_elements(p_produits) LOOP
    v_id  := v_ligne->>'produit';
    v_qte := COALESCE((v_ligne->>'qte')::numeric, 1);
    v_stock := COALESCE((v_sp->>v_id)::numeric, 0);
    v_sp := jsonb_set(v_sp, ARRAY[v_id], to_jsonb(v_stock - v_qte));
    v_libelle := v_libelle || CASE WHEN v_libelle = '' THEN '' ELSE ', ' END || v_id || ' x' || v_qte;
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = v_id;
    v_livraison := v_livraison || jsonb_build_array(jsonb_build_object(
      'produit', v_id, 'qte', v_qte,
      'prixUnitaire', (v_data->'parametres'->'prixVente'->>v_id)::numeric,
      'label', v_rec.label, 'categorie', v_rec.categorie,
      'effets', COALESCE(v_rec.effets, '{}'::jsonb), 'icone', v_rec.icone,
      'image', v_rec.image, 'description', v_rec.description,
      'familleProduitMarche', v_rec.famille_produit_marche,
      'bonusIntegrationVille', v_rec.bonus_integration_ville));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockProduits}', v_sp, true);

  v_data := public.entreprise_ajouter_historique(v_data, v_net,
              CASE WHEN p_mode = 'marche_noir' THEN 'Vol — ' ELSE 'Vente — ' END
              || COALESCE(NULLIF(v_libelle,''), 'prestation') || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'mode', p_mode,
    'total', v_dynamique, 'assiette', v_assiette, 'net', v_net,
    'paMetier', v_pa_metier,
    'arg', v_arg, 'liquide', v_liquide, 'pa', v_pa_reste,
    'livraison', v_livraison);
END; $function$;

CREATE OR REPLACE FUNCTION public.entrepot_commander(p_acteur text, p_ressource text, p_quantite integer, p_fournisseur_type text, p_fournisseur_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dest_id text; v_dest_ville text;
  v_prix numeric; v_fret numeric := 0; v_total numeric;
  v_cap integer; v_delai integer; v_libelle text;
  v_etat_d jsonb; v_ent_d jsonb; v_caisse_d numeric;
  v_etat_f jsonb; v_ent_f jsonb; v_caisse_f numeric; v_stock_f numeric;
  v_ids text[]; v_i text; v_arrivee date;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_quantite IS NULL OR p_quantite <= 0 OR p_quantite <> floor(p_quantite) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;

  SELECT entrepot_id, ville INTO v_dest_id, v_dest_ville
    FROM public.entrepot_du_directeur(p_acteur);
  IF v_dest_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_fournisseur_type = 'entrepot' AND p_fournisseur_id = v_dest_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_est_soi_meme');
  END IF;

  -- --- Verrouillage ordonne des lignes touchees --------------------------------
  v_ids := CASE WHEN p_fournisseur_type IN ('entrepot', 'port')
                THEN ARRAY(SELECT unnest(ARRAY[v_dest_id, p_fournisseur_id]) ORDER BY 1)
                ELSE ARRAY[v_dest_id] END;
  FOREACH v_i IN ARRAY v_ids LOOP
    PERFORM 1 FROM public.batiments_etat WHERE id = v_i FOR UPDATE;
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat_d FROM public.batiments_etat WHERE id = v_dest_id;
  IF v_etat_d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent_d := coalesce(v_etat_d->'entrepot', '{}'::jsonb);
  v_caisse_d := coalesce((v_ent_d->>'caisse')::numeric, 0);

  -- --- Le fournisseur : prix, stock, delai, libelle -----------------------------
  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    v_delai := 1;
    SELECT public.batiment_etat_lire(data) INTO v_etat_f FROM public.batiments_etat WHERE id = p_fournisseur_id;
    IF v_etat_f IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable'); END IF;

    IF p_fournisseur_type = 'entrepot' THEN
      v_ent_f := coalesce(v_etat_f->'entrepot', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      -- Prix AFFICHE par le fournisseur : son prix manuel s'il en a pose un, sinon le prix de
      -- reference. Le vendeur ne peut pas refuser : s'il affiche, il vend.
      v_prix := coalesce((v_ent_f->'prixManuel'->>p_ressource)::numeric,
                         (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource));
    ELSE
      -- Port industriel : son stock institutionnel en attente de repartition, au prix de reference.
      v_ent_f := coalesce(v_etat_f->'port', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      v_prix := (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource);
    END IF;

    IF v_stock_f < p_quantite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_fournisseur_insuffisant',
                                'disponible', v_stock_f);
    END IF;
    v_libelle := p_fournisseur_id;
  ELSIF p_fournisseur_type = 'etranger' THEN
    v_delai := 2;
    SELECT prix_unitaire, libelle INTO v_prix, v_libelle
      FROM public.fournisseurs_etrangers()
     WHERE pays = p_fournisseur_id AND ressource = p_ressource;
    IF v_prix IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable');
    END IF;
    -- EMBARGO : seules les NOUVELLES commandes sont interdites. Ce qui est deja paye et en
    -- transit poursuit sa route -- aucun effet retroactif.
    IF public.embargo_actif('republic', p_fournisseur_id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'embargo', 'pays', p_fournisseur_id);
    END IF;
    v_fret := public.fret_unitaire_international();
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_type_inconnu');
  END IF;

  -- --- Capacite du destinataire, transit compris --------------------------------
  v_cap := public.entrepot_capacite_disponible(v_dest_id, p_ressource);
  IF v_cap < p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante',
                              'capacite_disponible', v_cap, 'plafond', public.capacite_entrepot());
  END IF;

  -- --- Tresorerie ---------------------------------------------------------------
  v_total := round(p_quantite * (v_prix + v_fret), 2);
  IF v_caisse_d < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante',
                              'caisse', v_caisse_d, 'montant', v_total);
  END IF;

  -- --- Mouvements : tout ou rien -------------------------------------------------
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat_d || jsonb_build_object('entrepot',
           v_ent_d || jsonb_build_object('caisse', round(v_caisse_d - v_total, 2))))::text),
         updated_at = now()
   WHERE id = v_dest_id;

  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    -- Le stock part immediatement de chez le fournisseur : il ne peut pas etre vendu deux fois.
    -- Le fret n'est PAS verse au vendeur -- c'est un cout logistique absorbe.
    IF p_fournisseur_type = 'entrepot' THEN
      v_caisse_f := coalesce((v_ent_f->>'caisse')::numeric, 0);
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)))
        || jsonb_build_object('caisse', round(v_caisse_f + round(p_quantite * v_prix, 2), 2));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('entrepot', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
    ELSE
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('port', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
      -- Le produit de la vente du Port va a SA caisse institutionnelle, la ou vont deja ses
      -- autres recettes (criee, dedouanement).
      PERFORM public.caisse_institution_mouvement('republic_port-sainte-marie',
                                                  round(p_quantite * v_prix, 2), false);
    END IF;
  END IF;

  v_arrivee := ((now() AT TIME ZONE 'utc')::date + v_delai);
  INSERT INTO public.entrepot_transits (destination_id, ressource, quantite, origine_type,
    origine_id, origine_libelle, prix_unitaire, fret_unitaire, montant_total, arrivee_le, commande_par)
  VALUES (v_dest_id, p_ressource, p_quantite, p_fournisseur_type,
    CASE WHEN p_fournisseur_type = 'etranger' THEN NULL ELSE p_fournisseur_id END,
    v_libelle, v_prix, v_fret, v_total, v_arrivee, p_acteur);

  INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
    quantite, prix_unitaire, fret_unitaire, montant, statut, arrivee_le, acteur)
  VALUES (v_dest_id, 'commande_directe', 'entree', v_libelle, p_ressource,
    p_quantite, v_prix, v_fret, v_total, 'en_transit', v_arrivee, p_acteur);

  IF p_fournisseur_type = 'entrepot' THEN
    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (p_fournisseur_id, 'commande_directe', 'sortie', v_dest_id, p_ressource,
      p_quantite, v_prix, 0, round(p_quantite * v_prix, 2), 'comptant', p_acteur);
  END IF;

  RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite,
    'prix_unitaire', v_prix, 'fret_unitaire', v_fret, 'montant', v_total,
    'arrivee_le', v_arrivee, 'delai_jours', v_delai,
    'caisse', round(v_caisse_d - v_total, 2), 'fournisseur', v_libelle);
END; $function$;

-- entrepot_reverser : VOIR migration_20260920_entrepot_reversement_mairie.sql
-- ---------------------------------------------------------------------------
-- Elle pose le marqueur rp.caisse_interne comme les treize fonctions ci-dessus,
-- mais sa SOURCE CANONIQUE est le lot « entrepots », ou elle est definie avec
-- la table entrepots_reversements et les trois autres fonctions de reversement
-- qui forment sa mecanique. La dupliquer ici creerait une seconde source qui
-- divergerait le jour ou la fonction changerait.
--
-- ORDRE DE REJEU : migration_20260920_entrepot_reversement_mairie.sql doit etre
-- rejoue APRES ce fichier, car entrepot_reverser appelle
-- caisse_institution_mouvement, durcie ici.

CREATE OR REPLACE FUNCTION public.entreprise_preempter(p_acteur text, p_entreprise text, p_montant numeric, p_duree integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_prix numeric; v_pays text; v_taux numeric; v_total numeric;
  v_maintenant bigint; v_r jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;
  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  IF (COALESCE((v_data->>'compromis')::boolean, false)
      AND COALESCE((v_data->>'compromisExpireAt')::bigint,0) > v_maintenant)
     OR COALESCE(v_data->>'preemptionEtat','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  IF p_montant IS NULL OR p_montant < v_prix OR COALESCE(p_duree,0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_insuffisant', 'prix', v_prix);
  END IF;

  v_pays  := COALESCE(v_data->>'country','republic');
  v_taux  := public.taux_pret_nationale(v_pays);
  v_total := round(p_montant * (1 + v_taux / 100));

  -- Mouvements institutionnels atomiques, jamais une lecture-modification-ecriture cliente.
  PERFORM public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', p_montant, false);
  v_r := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', -v_prix, false);
  IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
  END IF;

  v_data := v_data || jsonb_build_object('preemptionEtat', 'attente_acte',
                                         'preemptionPar', p_acteur);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'montant', p_montant,
    'montantTotal', v_total, 'mensualite', ceil(v_total / p_duree), 'taux', v_taux);
END; $function$;

CREATE OR REPLACE FUNCTION public.fret_dedouaner(p_caisse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; c record; v_val numeric; v_jours int; v_factures int;
  v_douane numeric; v_gard numeric; v_total numeric; v_caisse text; v_mvt jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  IF c.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF COALESCE(c.dedouanee, false) THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'deja_dedouanee');
  END IF;
  IF COALESCE(c.statut, '') <> 'arrivee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide', 'statut', c.statut);
  END IF;

  v_val := GREATEST(0, COALESCE(c.valeur_declaree, 0));
  v_douane := round(v_val * 10 / 100.0);
  v_gard := 0;
  IF c.date_arrivee_reelle IS NOT NULL THEN
    v_jours := floor(EXTRACT(epoch FROM (now() - c.date_arrivee_reelle)) / 86400)::int;
    v_factures := GREATEST(0, v_jours - 7);
    IF v_factures > 0 THEN v_gard := round(v_val * 1 / 100.0 * v_factures); END IF;
  END IF;
  v_total := v_douane + v_gard;

  IF v_total > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                                'douane', v_douane, 'gardiennage', v_gard);
    END IF;
    -- Credit de la caisse du port DANS LA MEME TRANSACTION que le debit.
    v_caisse := c.pays_destination || '_' || c.building_destination;
    v_mvt := public.caisse_institution_mouvement(v_caisse, v_total, false);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'credit_caisse_port_impossible: %', COALESCE(v_mvt->>'raison','?');
    END IF;
  END IF;

  UPDATE public.caisses_fret
     SET dedouanee = true, date_dedouanement = now()
   WHERE id = p_caisse_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'douane', v_douane,
    'gardiennage', v_gard, 'jours_factures', COALESCE(v_factures, 0), 'caisse', v_caisse,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

CREATE OR REPLACE FUNCTION public.imprimerie_cession_finaliser(p_requete text, p_acheteur text, p_imprimerie_id text, p_prix numeric, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_prix     constant numeric := 180000;
  v_rej      jsonb;
  v_data     jsonb;
  v_pays     text;
  v_caisse   text;
  v_acompte  numeric;
  v_expire   numeric;
  v_mvt      jsonb;
  v_hist     jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acheteur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_acheteur, 'cession_imprimerie');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_imprimerie_id), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_invalide'));
  END IF;
  IF p_prix IS DISTINCT FROM c_prix THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'prix', c_prix));
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_imprimerie_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_introuvable'));
  END IF;
  IF v_data ->> 'type' IS DISTINCT FROM 'imprimerie' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'bien_non_imprimerie'));
  END IF;
  IF v_data ->> 'proprietaire' IS DISTINCT FROM 'PNJ' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vendue',
                                                                        'proprietaire', v_data ->> 'proprietaire'));
  END IF;
  IF COALESCE((v_data -> 'compromis')::text, 'false') <> 'true'
     OR v_data ->> 'compromisPar' IS DISTINCT FROM p_acheteur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_invalide'));
  END IF;
  v_expire := CASE WHEN jsonb_typeof(v_data -> 'compromisExpireAt') = 'number'
                   THEN (v_data ->> 'compromisExpireAt')::numeric ELSE NULL END;
  IF v_expire IS NOT NULL AND v_expire < extract(epoch FROM now()) * 1000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_expire'));
  END IF;

  v_pays := COALESCE(NULLIF(btrim(v_data ->> 'country'), ''), 'republic');
  v_caisse := v_pays || '_gouvernement-min_fin';
  v_acompte := CASE WHEN jsonb_typeof(v_data -> 'acompte') = 'number'
                    THEN (v_data ->> 'acompte')::numeric ELSE 0 END;

  v_mvt := public.caisse_institution_mouvement(v_caisse, c_prix, true);
  IF COALESCE((v_mvt -> 'ok')::text, 'false') <> 'true' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'caisse_etat_indisponible', 'detail', v_mvt -> 'raison'));
  END IF;

  v_hist := CASE WHEN jsonb_typeof(v_data -> 'historique') = 'array' THEN v_data -> 'historique' ELSE '[]'::jsonb END;
  v_hist := v_hist || jsonb_build_array(jsonb_build_object(
    'jour', COALESCE(p_jour, 1), 'montant', 0,
    'motif', 'Rachat de l''entreprise par ' || p_acheteur || ' (acte notarié)'));
  IF jsonb_array_length(v_hist) > 50 THEN
    v_hist := (SELECT jsonb_agg(e) FROM (
      SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
       ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) s);
  END IF;

  UPDATE public.entreprises
     SET data = (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt')
                || jsonb_build_object('proprietaire', p_acheteur, 'historique', v_hist),
         updated_at = now()
   WHERE id = p_imprimerie_id;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'prix', c_prix, 'acompte', v_acompte, 'solde', c_prix - v_acompte,
    'caisse_id', v_caisse, 'caisse_solde', v_mvt -> 'solde', 'proprietaire', p_acheteur));
END;
$function$;

CREATE OR REPLACE FUNCTION public.militaire_arrieres_regler()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays text; v_l record; v_mvt jsonb; v_manque integer;
  v_verse integer; v_total integer := 0; v_lignes integer := 0;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  FOR v_l IN SELECT id, du, verse FROM public.soldes_militaires
              WHERE personnage = v_moi AND pays = v_pays AND verse < du
              ORDER BY jour FOR UPDATE LOOP
    v_manque := v_l.du - v_l.verse;
    v_mvt := public.caisse_institution_mouvement_plafonne(v_pays || '_caserne-militaire', v_manque);
    v_verse := greatest(0, coalesce((v_mvt->>'verse')::integer, 0));
    EXIT WHEN v_verse = 0;                 -- caisse vide : on s'arrete, rien n'est invente
    PERFORM public.assemblee_crediter_joueur(v_moi, v_verse);
    UPDATE public.soldes_militaires
       SET verse = v_l.verse + v_verse,
           regle_le = CASE WHEN v_l.verse + v_verse >= v_l.du THEN now() END
     WHERE id = v_l.id;
    v_total := v_total + v_verse; v_lignes := v_lignes + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'verse', v_total, 'lignes', v_lignes,
    'reste_du', (SELECT coalesce(sum(du - verse), 0) FROM public.soldes_militaires
                  WHERE personnage = v_moi AND pays = v_pays AND verse < du));
END; $function$;

CREATE OR REPLACE FUNCTION public.militaire_compagnie_creer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_contingent constant integer := 96;
  c_sections   constant integer := 4;
  c_cout       constant numeric := 20000;
  c_pa         constant integer := 3;
  v_moi text; v_pays text; v_pa integer; v_id text; v_prefixe text;
  v_paye jsonb; v_caisse jsonb; v_sections jsonb; v_reserve jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic'), coalesce(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  v_caisse := public.caisse_institution_mouvement(v_pays || '_caserne-militaire', -c_cout, true);
  IF NOT coalesce((v_caisse->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false,
      'raison', coalesce(v_caisse->>'raison', 'caisse_refusee'), 'cout', c_cout);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'recruter_compagnie', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_compagnie_creer: paiement des PA refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  v_id := 'compagnie-' || v_pays || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text;
  v_prefixe := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYYMM');

  SELECT jsonb_agg(jsonb_build_object(
           'id', v_id || '-s' || i, 'numero', i, 'lieutenantNom', NULL,
           'soldats', '[]'::jsonb) ORDER BY i)
    INTO v_sections FROM generate_series(1, c_sections) AS g(i);

  SELECT jsonb_agg(jsonb_build_object(
           'matricule', v_prefixe || '-' || lpad(i::text, 3, '0'),
           'formation', jsonb_build_object('combat_rapproche', 0, 'tir', 0,
                                           'reconnaissance', 0, 'secourisme', 0),
           'arme', 'corps_a_corps',
           'ville', 'caserne', 'buildingId', 'caserne-militaire', 'roomId', 'corps_garde',
           'leaderCourant', NULL, 'pa', 12) ORDER BY i)
    INTO v_reserve FROM generate_series(1, c_contingent) AS g(i);

  INSERT INTO public.compagnies_militaires (id, data)
  VALUES (v_id, jsonb_build_object(
    'id', v_id, 'pays', v_pays, 'capitaineNom', NULL,
    'contingentInitial', c_contingent, 'reserve', v_reserve, 'sections', v_sections));

  RETURN jsonb_build_object('ok', true, 'compagnie', v_id, 'contingent', c_contingent,
                            'sections', c_sections, 'cout', c_cout, 'pa', v_paye->'pa');
END;
$function$;

CREATE OR REPLACE FUNCTION public.militaire_solde_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays text; v_grade text; v_du integer; v_jour date; v_id text;
  v_mvt jsonb; v_verse integer; v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;

  -- Baremes GD. Les PNJ n'ont aucune solde : ils ne passent jamais par ici.
  v_du := CASE v_grade WHEN 'soldat' THEN 50 WHEN 'lieutenant' THEN 150
                       WHEN 'capitaine' THEN 250 WHEN 'commandant' THEN 400 END;
  IF v_du IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_sans_solde'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  -- ANTI-REJEU PAR LA CLE : deux clics simultanes ne peuvent pas creer deux lignes.
  BEGIN
    INSERT INTO public.soldes_militaires (id, personnage, pays, grade, jour, du, verse)
    VALUES (v_id, v_moi, v_pays, v_grade, v_jour, v_du, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percue_aujourdhui', 'jour', v_jour);
  END;

  -- Debit PLAFONNE : la caserne verse ce qu'elle peut, le reste devient une dette.
  v_mvt := public.caisse_institution_mouvement_plafonne(v_pays || '_caserne-militaire', v_du);
  v_verse := greatest(0, coalesce((v_mvt->>'verse')::integer, 0));

  IF v_verse > 0 THEN
    v_credit := public.assemblee_crediter_joueur(v_moi, v_verse);
  END IF;
  UPDATE public.soldes_militaires
     SET verse = v_verse, regle_le = CASE WHEN v_verse >= v_du THEN now() END
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'grade', v_grade, 'du', v_du, 'verse', v_verse,
    'dette', v_du - v_verse, 'jour', v_jour,
    'liquide', v_credit->'liquide', 'arg', v_credit->'arg');
END; $function$;

CREATE OR REPLACE FUNCTION public.vente_structure_encaisser(p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_caisse text DEFAULT NULL::text, p_ville text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_pays text;
  v_ville text;
  v_taxable boolean;
  v_paye jsonb;
  v_taxe jsonb := NULL;
  v_net numeric;
  v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_taxable := CASE p_fn
    WHEN 'reserver_chambre_hotel' THEN true
    WHEN 'consommer_buvette'      THEN true
    WHEN 'faire_don'              THEN false
    ELSE NULL
  END;
  IF v_taxable IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vente_non_declaree', 'fn', p_fn);
  END IF;

  SELECT coalesce(pd.country, 'republic'),
         coalesce(nullif(btrim(coalesce(p_ville, '')), ''), pd.current_city, 'capitale')
    INTO v_pays, v_ville
    FROM public.personnages_donnees pd
   WHERE pd.name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF coalesce(btrim(coalesce(p_caisse, '')), '') = ''
     OR p_caisse NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_empire', 'caisse', p_caisse);
  END IF;

  v_paye := public.payer_ordre(v_acteur, p_fn, p_pa, p_cost);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RETURN v_paye;
  END IF;

  v_net := coalesce(p_cost, 0);
  IF v_taxable AND v_net > 0 THEN
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_net);
    v_net := coalesce((v_taxe->>'net')::numeric, v_net);
  END IF;

  IF v_net > 0 THEN
    v_credit := public.caisse_institution_mouvement(p_caisse, v_net, false);
    IF NOT coalesce((v_credit->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'vente_structure: credit impossible sur % (%)',
        p_caisse, coalesce(v_credit->>'raison', 'motif inconnu');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'pa', v_paye->'pa',
    'liquide', v_paye->'liquide',
    'arg', v_paye->'arg',
    'solde_national', v_paye->'solde_national',
    'pa_preleves', v_paye->'pa_preleves',
    'montant_preleve', v_paye->'montant_preleve',
    'net', v_net,
    'taxe', v_taxe,
    'caisse', p_caisse,
    'ville', v_ville);
END;
$function$;


-- =====================================================================
-- 2. DONNEES DE REFERENCE — migration 20260920091408
-- =====================================================================
-- §4 — CAISSES NON MINISTERIELLES : REUTILISER LES POSTES QUI EXISTENT DEJA
--
-- Avant de demander « qui repond de ces caisses », on regarde ce que le jeu
-- declare deja. postes_nommes_regles contient quatre directions economiques et
-- une capitainerie qui correspondent exactement a des caisses existantes. Les
-- rattacher n'invente aucune mecanique : cela applique l'autorite que le jeu a
-- deja definie, et que personne n'avait reliee a la caisse correspondante.
--
--   capitaine_port          <- nomme par min_fin, scope pays
--   directeur_entrepot      <- nomme par maire_adjoint, scope ville
--   directeur_pharma        <- nomme par min_fin, scope pays
--   directeur_raffinerie    <- nomme par min_fin, scope pays
--   directeur_tabac_alcools <- nomme par min_fin, scope pays
--
-- Le palais du gouvernement est le siege du Premier ministre : sa caisse suit la
-- meme autorite que gouvernement-pm.
--
-- NOTE DE VERSIONNEMENT : public.caisses_autorites contient en production 15
-- lignes. Les 9 autres (assemblee, caserne-militaire, commissariat,
-- gouvernement-, mairie, palais-presidentiel, qhs-prison, reserve-nationale,
-- tribunal) ont ete posees par la migration 20260919232818, qui cree aussi la
-- table : elles ne sont PAS reprises ici. Seules les 6 lignes de 091408 le sont.
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES
  ('port-sainte-marie',    false, '{capitaine_port,min_fin}',        'port industriel — capitainerie'),
  ('palais-gouvernement',  false, '{pm}',                            'siege du Premier ministre'),
  ('entrepot',             true,  '{directeur_entrepot,maire_adjoint}', 'entrepots logistiques'),
  ('usine-pharma',         true,  '{directeur_pharma,min_fin}',      'pharmacie nationale'),
  ('raffinerie',           true,  '{directeur_raffinerie,min_fin}',  'raffinerie'),
  ('pole-tabac-alcools',   true,  '{directeur_tabac_alcools,min_fin}','tabac et alcools')
ON CONFLICT (motif) DO UPDATE
  SET est_prefixe=EXCLUDED.est_prefixe, postes_debit=EXCLUDED.postes_debit, note=EXCLUDED.note;
