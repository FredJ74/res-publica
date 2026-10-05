-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919175233
-- Nom original      : creation_cellule_couvertures_sexees
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:52:33 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d62416f36133cdfb1a9e05d1ca24940f
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
-- Attribution des couvertures : sexe correspondant a celui de l'agent, unicite
-- au sein de la cellule, et evitement de la couverture precedente du MEME role
-- dans le MEME pays -- sans mecanique d'historique dediee : l'information est
-- deja dans les lignes d'agents des cellules passees.
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
