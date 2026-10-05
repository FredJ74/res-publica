-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- pnj_administrateur(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_administrateur(p_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.pnj_autorite_de(p_id);
$function$;

-- pnj_argent_transferer(text,numeric,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_argent_transferer(p_pnj text, p_montant numeric, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pj numeric; v_pnj numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT public.pnj_co_present(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  SELECT liquide INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT liquide INTO v_pnj FROM public.pnj_membres WHERE id = p_pnj FOR UPDATE;
  IF v_pj IS NULL OR v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  IF p_sens = 'donner' THEN
    IF v_pj < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE public.personnages_donnees SET liquide = v_pj - p_montant, arg = arg - p_montant
     WHERE name = v_moi;
    UPDATE public.pnj_membres SET liquide = v_pnj + p_montant WHERE id = p_pnj;
  ELSIF p_sens = 'retirer' THEN
    IF v_pnj < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE public.pnj_membres SET liquide = v_pnj - p_montant WHERE id = p_pnj;
    UPDATE public.personnages_donnees SET liquide = v_pj + p_montant, arg = arg + p_montant
     WHERE name = v_moi;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'montant', p_montant);
END; $function$;

-- pnj_autorite_de(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_autorite_de(p_pnj_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN m.proprietaire_pj IS NOT NULL THEN m.proprietaire_pj
              ELSE public.pnj_autorite_de_perimetre(
                     m.pays, m.proprietaire_institution, m.proprietaire_perimetre) END
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$function$;

-- pnj_autorite_de_perimetre(text,text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_autorite_de_perimetre(p_pays text, p_institution text, p_perimetre text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_res text; v_nom text;
BEGIN
  IF p_institution IS NULL OR p_perimetre IS NULL THEN RETURN NULL; END IF;
  SELECT resolveur INTO v_res FROM public.pnj_institutions WHERE institution = p_institution;
  IF v_res IS NULL THEN RETURN NULL; END IF;      -- institution non enregistree : personne.
  EXECUTE format('SELECT %I($1, $2)', v_res) INTO v_nom USING p_pays, p_perimetre;
  RETURN v_nom;                                    -- NULL legitime : aucune autorite humaine.
END; $function$;

-- pnj_axe_au_socle(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_axe_au_socle(p_famille text, p_axe text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Totale par construction : une famille ou un axe inconnu rend false, jamais NULL.
  SELECT COALESCE((SELECT a.autorite = 'socle' FROM public.pnj_axes_autorite a
                    WHERE a.famille = p_famille AND a.axe = p_axe), false);
$function$;

-- pnj_axe_position_refus(text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_axe_position_refus(p_ids text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_bloque text;
BEGIN
  v_bloque := public.pnj_axe_verrouille(p_ids, 'position_leader');
  IF v_bloque IS NULL THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('raison', 'axe_position_hors_socle', 'pnj', v_bloque,
    'explication', 'La position de cette famille est decidee ailleurs que dans le socle. '
                || 'L''ecrire ici creerait deux verites.');
END; $function$;

-- pnj_axe_verrouille(text[],text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_axe_verrouille(p_ids text[], p_axe text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids)
     AND NOT public.pnj_axe_au_socle(m.famille, p_axe)
   LIMIT 1;
$function$;

-- pnj_caracteristique_base(text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_caracteristique_base(p_pnj_id text, p_cle text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v jsonb;
BEGIN
  IF p_cle IS NULL OR NOT (p_cle = ANY (public.pnj_caracteristiques_cles())) THEN
    RAISE EXCEPTION 'pnj_caracteristique_base: caracteristique inconnue %. Referentiel : %',
      COALESCE(p_cle, '<NULL>'), array_to_string(public.pnj_caracteristiques_cles(), ', ')
      USING ERRCODE = 'invalid_parameter_value';
  END IF;
  v := public.pnj_caracteristiques_base(p_pnj_id);
  IF v IS NULL THEN RETURN NULL; END IF;        -- PNJ introuvable : pas une erreur de cle.
  RETURN (v->>p_cle)::integer;
END; $function$;

-- pnj_caracteristiques_base(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_caracteristiques_base(p_pnj_id text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
           'INT', m.car_int, 'CHA', m.car_cha, 'VOL', m.car_vol,
           'PER', m.car_per, 'DUP', m.car_dup, 'ENT', m.car_ent)
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$function$;

-- pnj_caracteristiques_cles() -> text[] | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.pnj_caracteristiques_cles()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT ARRAY['INT','CHA','VOL','PER','DUP','ENT']::text[];
$function$;

-- pnj_classe_de(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_classe_de(p_pnj_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- L'individu d'abord, le defaut de sa famille ensuite. Jamais de classe inventee.
  SELECT COALESCE(m.classe,
                  (SELECT c.classe FROM public.pnj_familles_classes c WHERE c.famille = m.famille))
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$function$;

-- pnj_classe_decor(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_classe_decor(p_fonction text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT COALESCE((SELECT f.classe_decor FROM public.pnj_fonctions f WHERE f.fonction = p_fonction),
                  'gamma');
$function$;

-- pnj_co_present(text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_co_present(p_moi text, p_pnj_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a record; pe record; v_b text; v_r text;
BEGIN
  IF p_moi IS NULL THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_moi;
  IF a.current_city IS NULL THEN RETURN false; END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(p_pnj_id);
  IF pe.ville IS NULL THEN RETURN false; END IF;
  v_b := COALESCE(pe.building_id,
                  CASE WHEN pe.rue_noeud_id IS NOT NULL THEN 'rue-centrale' END);
  v_r := COALESCE(pe.room_id, pe.rue_noeud_id);
  RETURN COALESCE(pe.pays = a.country AND pe.ville = a.current_city
     AND v_b IS NOT DISTINCT FROM a.current_building
     AND v_r IS NOT DISTINCT FROM a.current_room, false);
END; $function$;

-- pnj_comparer_agents() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_comparer_agents()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_div jsonb; v_prof jsonb; v_nb integer;
BEGIN
  v_prof := public.pnj_metier_profil('agent');
  SELECT count(*) INTO v_nb FROM public.pnj_membres WHERE famille = 'agent' AND statut = 'actif';

  WITH attendu AS (SELECT i.role, i.vrai_nom FROM public.renseignement_identites_reelles i),
  socle AS (SELECT m.* FROM public.pnj_membres m WHERE m.famille = 'agent'),
  cmp AS (
    SELECT COALESCE(a.role, replace(s.id, 'agent-', '')) AS role,
      CASE
        WHEN s.id IS NULL THEN 'identite_absente_du_socle'
        WHEN a.role IS NULL THEN 'surnumeraire_au_socle'
        WHEN s.nom IS DISTINCT FROM a.vrai_nom THEN 'nom_reel'
        WHEN s.classe IS DISTINCT FROM 'beta' THEN 'classe'
        WHEN public.pnj_caracteristiques_base(s.id) IS DISTINCT FROM v_prof THEN 'profil'
        WHEN s.proprietaire_institution IS DISTINCT FROM 'renseignement' THEN 'institution'
        WHEN s.pa IS DISTINCT FROM 12 THEN 'pa'
        ELSE NULL END AS divergence
      FROM attendu a FULL OUTER JOIN socle s
        ON s.id = public.renseignement_pnj_id(a.role))
  SELECT COALESCE(jsonb_agg(jsonb_build_object('role', role, 'divergence', divergence)
           ORDER BY role) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_div FROM cmp;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb = 4
          AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement WHERE pnj_id IS NULL)
          AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                            JOIN public.pnj_membres m ON m.id = a.pnj_id
                           WHERE a.statut = 'actif' AND a.dup IS DISTINCT FROM m.car_dup),
    'identites_au_socle', v_nb, 'attendues', 4,
    'profil', v_prof, 'divergences', v_div,
    'occurrences_de_mission', (SELECT count(*) FROM public.agents_renseignement),
    'missions_non_raccordees', (SELECT count(*) FROM public.agents_renseignement WHERE pnj_id IS NULL),
    'missions_actives', (SELECT count(*) FROM public.agents_renseignement WHERE statut = 'actif'),
    'dup_active_desalignee', (SELECT count(*) FROM public.agents_renseignement a
                                JOIN public.pnj_membres m ON m.id = a.pnj_id
                               WHERE a.statut = 'actif' AND a.dup IS DISTINCT FROM m.car_dup),
    'observation_axe_position', (SELECT autorite FROM public.pnj_axes_autorite
                                  WHERE famille = 'agent' AND axe = 'position_leader'));
END; $function$;

-- pnj_comparer_douaniers(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_comparer_douaniers(p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer; v_def jsonb;
        v_per text := p_ville || ':' || p_batiment;
BEGIN
  v_def := public.douane_caracteristiques_metier();
  WITH etat AS (
    SELECT public.batiment_etat_lire(data) AS e FROM public.batiments_etat
     WHERE country = p_pays AND city = p_ville AND building_id = p_batiment
  ), blob AS (
    SELECT d->>'matricule' AS matricule,
           COALESCE(d->>'type', 'standard') AS type_unite,
           COALESCE(d->>'buildingId', p_batiment) AS bat,
           d->>'roomId' AS room,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'INT')::integer, (v_def->>'INT')::integer) AS c_int,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'CHA')::integer, (v_def->>'CHA')::integer) AS c_cha,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'VOL')::integer, (v_def->>'VOL')::integer) AS c_vol,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'PER')::integer, (v_def->>'PER')::integer) AS c_per,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'DUP')::integer, (v_def->>'DUP')::integer) AS c_dup,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'ENT')::integer, (v_def->>'ENT')::integer) AS c_ent
      FROM etat, jsonb_array_elements(
             CASE WHEN jsonb_typeof(etat.e->'effectifsDouane'->'douaniers')='array'
                  THEN etat.e->'effectifsDouane'->'douaniers' ELSE '[]'::jsonb END) d
     WHERE COALESCE(d->>'matricule','') <> ''
  ), socle AS (
    SELECT fp.matricule, fp.type_unite, m.building_id AS bat, m.room_id AS room,
           m.car_int AS c_int, m.car_cha AS c_cha, m.car_vol AS c_vol,
           m.car_per AS c_per, m.car_dup AS c_dup, m.car_ent AS c_ent,
           m.ville, m.pa, m.proprietaire_pj, m.proprietaire_institution AS institution,
           m.proprietaire_perimetre AS perimetre, m.leader_pj, m.leader_pnj_id, m.liquide,
           public.pnj_classe_de(m.id) AS classe
      FROM public.pnj_membres m
      JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
     WHERE m.famille = 'douanier' AND m.pays = p_pays
       AND m.proprietaire_perimetre = v_per AND m.statut = 'actif'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.type_unite IS DISTINCT FROM s.type_unite THEN 'type_unite'
        WHEN b.bat   IS DISTINCT FROM s.bat   THEN 'batiment'
        WHEN b.room  IS DISTINCT FROM s.room  THEN 'piece'
        WHEN s.ville IS DISTINCT FROM p_ville THEN 'ville'
        WHEN b.c_int IS DISTINCT FROM s.c_int THEN 'car_int'
        WHEN b.c_cha IS DISTINCT FROM s.c_cha THEN 'car_cha'
        WHEN b.c_vol IS DISTINCT FROM s.c_vol THEN 'car_vol'
        WHEN b.c_per IS DISTINCT FROM s.c_per THEN 'car_per'
        WHEN b.c_dup IS DISTINCT FROM s.c_dup THEN 'car_dup'
        WHEN b.c_ent IS DISTINCT FROM s.c_ent THEN 'car_ent'
        WHEN s.classe IS DISTINCT FROM 'beta'          THEN 'classe'
        WHEN s.pa IS DISTINCT FROM 12                  THEN 'pa'
        WHEN s.proprietaire_pj IS NOT NULL             THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'douane'   THEN 'institution'
        WHEN s.perimetre IS DISTINCT FROM v_per        THEN 'perimetre'
        WHEN s.leader_pj IS NOT NULL OR s.leader_pnj_id IS NOT NULL THEN 'leader_inattendu'
        WHEN COALESCE(s.liquide, 0) <> 0               THEN 'liquide_inattendu'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div), 'details', v_div,
    'observation_partis', (SELECT count(*) FROM public.pnj_membres
       WHERE famille='douanier' AND pays=p_pays AND proprietaire_perimetre=v_per
         AND statut='disparu'));
END; $function$;

-- pnj_comparer_policiers(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_comparer_policiers(p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer; v_def jsonb;
        v_per text := p_ville || ':' || p_batiment;
BEGIN
  v_def := public.police_caracteristiques_metier();
  WITH etat AS (
    SELECT public.batiment_etat_lire(data) AS e FROM public.batiments_etat
     WHERE country = p_pays AND city = p_ville AND building_id = p_batiment
  ), st AS (
    SELECT d->>'matricule' AS matricule,
           COALESCE(d->>'type','standard') AS type_unite,
           d->>'buildingId' AS bat, d->>'roomId' AS room, d->>'rueNoeudId' AS rue,
           CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats' ELSE '{}'::jsonb END AS s
      FROM etat, jsonb_array_elements(
             CASE WHEN jsonb_typeof(etat.e->'effectifsPolice'->'policiers')='array'
                  THEN etat.e->'effectifsPolice'->'policiers' ELSE '[]'::jsonb END) d
     WHERE COALESCE(d->>'matricule','') <> ''
  ), blob AS (
    SELECT matricule, type_unite, bat, room, rue,
           COALESCE((s->>'INT')::integer, (v_def->>'INT')::integer) AS c_int,
           COALESCE((s->>'CHA')::integer, (v_def->>'CHA')::integer) AS c_cha,
           COALESCE((s->>'VOL')::integer, (v_def->>'VOL')::integer) AS c_vol,
           COALESCE((s->>'PER')::integer, (v_def->>'PER')::integer) AS c_per,
           COALESCE((s->>'DUP')::integer, (v_def->>'DUP')::integer) AS c_dup,
           COALESCE((s->>'ENT')::integer, (v_def->>'ENT')::integer) AS c_ent
      FROM st
  ), socle AS (
    SELECT fp.matricule, fp.type_unite, m.building_id AS bat, m.room_id AS room,
           m.rue_noeud_id AS rue,
           m.car_int AS c_int, m.car_cha AS c_cha, m.car_vol AS c_vol,
           m.car_per AS c_per, m.car_dup AS c_dup, m.car_ent AS c_ent,
           m.ville, m.pa, m.proprietaire_pj, m.proprietaire_institution AS institution,
           m.proprietaire_perimetre AS perimetre, m.leader_pj, m.leader_pnj_id, m.liquide,
           public.pnj_classe_de(m.id) AS classe
      FROM public.pnj_membres m
      JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
     WHERE m.famille = 'policier' AND m.pays = p_pays
       AND m.proprietaire_perimetre = v_per AND m.statut = 'actif'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.type_unite IS DISTINCT FROM s.type_unite THEN 'type_unite'
        WHEN b.bat  IS DISTINCT FROM s.bat  THEN 'batiment'
        WHEN b.room IS DISTINCT FROM s.room THEN 'piece'
        WHEN b.rue  IS DISTINCT FROM s.rue  THEN 'noeud_de_rue'
        WHEN s.ville IS DISTINCT FROM p_ville THEN 'ville'
        WHEN b.c_int IS DISTINCT FROM s.c_int THEN 'car_int'
        WHEN b.c_cha IS DISTINCT FROM s.c_cha THEN 'car_cha'
        WHEN b.c_vol IS DISTINCT FROM s.c_vol THEN 'car_vol'
        WHEN b.c_per IS DISTINCT FROM s.c_per THEN 'car_per'
        WHEN b.c_dup IS DISTINCT FROM s.c_dup THEN 'car_dup'
        WHEN b.c_ent IS DISTINCT FROM s.c_ent THEN 'car_ent'
        WHEN s.classe IS DISTINCT FROM 'beta'         THEN 'classe'
        WHEN s.pa IS DISTINCT FROM 12                 THEN 'pa'
        WHEN s.proprietaire_pj IS NOT NULL            THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'police'  THEN 'institution'
        WHEN s.perimetre IS DISTINCT FROM v_per       THEN 'perimetre'
        WHEN s.leader_pj IS NOT NULL OR s.leader_pnj_id IS NOT NULL THEN 'leader_inattendu'
        WHEN COALESCE(s.liquide, 0) <> 0              THEN 'liquide_inattendu'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'ville', p_ville, 'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div), 'details', v_div,
    'observation_partis', (SELECT count(*) FROM public.pnj_membres
       WHERE famille='policier' AND pays=p_pays AND proprietaire_perimetre=v_per
         AND statut='disparu'));
END; $function$;

-- pnj_comparer_soldats(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
        v_pos_blob integer; v_pos_socle integer; v_pos_div jsonb;
        v_liquide numeric; v_liquide_non_nuls integer;
        v_axe_poss text; v_axe_posl text; v_axe_pa text; v_axe_arg text; v_axe_prop text;
        v_poss_au_socle boolean; v_posl_au_socle boolean; v_pa_au_socle boolean;
        v_les_deux integer; v_ni_lun_ni_lautre integer;
BEGIN
  SELECT COALESCE(max(autorite) FILTER (WHERE axe='possessions'),      'blob'),
         COALESCE(max(autorite) FILTER (WHERE axe='position_leader'),  'blob'),
         COALESCE(max(autorite) FILTER (WHERE axe='pa'),               'blob'),
         COALESCE(max(autorite) FILTER (WHERE axe='argent'),           'blob'),
         COALESCE(max(autorite) FILTER (WHERE axe='propriete'),        'blob')
    INTO v_axe_poss, v_axe_posl, v_axe_pa, v_axe_arg, v_axe_prop
    FROM public.pnj_axes_autorite WHERE famille = 'soldat';
  v_poss_au_socle := public.pnj_axe_au_socle('soldat', 'possessions');
  v_posl_au_socle := public.pnj_axe_au_socle('soldat', 'position_leader');
  v_pa_au_socle   := public.pnj_axe_au_socle('soldat', 'pa');

  WITH blob AS (
    SELECT sol->>'matricule' AS matricule, sol->>'leaderCourant' AS leader,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS room,
           (sol->>'pa')::integer AS pa, sol->>'arme' AS arme,
           COALESCE(sol->'formation','{}'::jsonb) AS formation,
           false AS en_reserve, s->>'id' AS section_id, sol->>'mutin' AS mutin,
           s->>'id' AS perimetre,
           sol->>'dernier_ration' AS dernier_ration, (sol->>'nb_ration')::integer AS nb_ration,
           sol->>'dernier_bivouac' AS dernier_bivouac, sol->>'dernier_sommeil' AS dernier_sommeil
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', r->>'leaderCourant', r->>'ville', r->>'buildingId', r->>'roomId',
           (r->>'pa')::integer, r->>'arme', COALESCE(r->'formation','{}'::jsonb), true, NULL,
           r->>'mutin', p_compagnie || ':reserve',
           r->>'dernier_ration', (r->>'nb_ration')::integer,
           r->>'dernier_bivouac', r->>'dernier_sommeil'
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r
     WHERE c.id = p_compagnie
  ), socle AS (
    SELECT sm.matricule, m.leader_pj AS leader, m.ville, m.building_id AS bat,
           m.room_id AS room, m.pa, sm.arme, sm.formation, sm.en_reserve, sm.section_id,
           sm.mutin, m.statut, m.proprietaire_pj,
           m.proprietaire_institution AS institution, m.proprietaire_perimetre AS perimetre,
           m.leader_pnj_id, m.rue_noeud_id, sm.compagnie_id,
           sm.dernier_ration, sm.nb_ration, sm.dernier_bivouac, sm.dernier_sommeil
      FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.id LIKE p_compagnie || '-%'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.leader      IS DISTINCT FROM s.leader      THEN
             CASE WHEN v_posl_au_socle THEN 'projection_leader'   ELSE 'leader'   END
        WHEN b.ville       IS DISTINCT FROM s.ville       THEN
             CASE WHEN v_posl_au_socle THEN 'projection_ville'    ELSE 'ville'    END
        WHEN b.bat         IS DISTINCT FROM s.bat         THEN
             CASE WHEN v_posl_au_socle THEN 'projection_batiment' ELSE 'batiment' END
        WHEN b.room        IS DISTINCT FROM s.room        THEN
             CASE WHEN v_posl_au_socle THEN 'projection_piece'    ELSE 'piece'    END
        WHEN b.pa          IS DISTINCT FROM s.pa          THEN
             CASE WHEN v_pa_au_socle   THEN 'projection_pa'       ELSE 'pa'       END
        WHEN b.arme        IS DISTINCT FROM s.arme        THEN 'arme'
        WHEN b.formation   IS DISTINCT FROM s.formation   THEN 'entrainement'
        WHEN b.en_reserve  IS DISTINCT FROM s.en_reserve  THEN 'reserve'
        WHEN b.section_id  IS DISTINCT FROM s.section_id  THEN 'section'
        WHEN s.compagnie_id IS DISTINCT FROM p_compagnie  THEN 'compagnie'
        WHEN b.mutin       IS DISTINCT FROM s.mutin       THEN 'mutin'
        WHEN b.dernier_ration  IS DISTINCT FROM s.dernier_ration  THEN 'dernier_ration'
        WHEN b.nb_ration       IS DISTINCT FROM s.nb_ration       THEN 'nb_ration'
        WHEN b.dernier_bivouac IS DISTINCT FROM s.dernier_bivouac THEN 'dernier_bivouac'
        WHEN b.dernier_sommeil IS DISTINCT FROM s.dernier_sommeil THEN 'dernier_sommeil'
        WHEN s.proprietaire_pj IS NOT NULL                THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'militaire'   THEN 'institution'
        WHEN b.perimetre   IS DISTINCT FROM s.perimetre   THEN 'perimetre'
        WHEN s.leader_pnj_id IS NOT NULL                  THEN 'leader_pnj_inattendu'
        WHEN s.rue_noeud_id  IS NOT NULL                  THEN 'rue_noeud_inattendu'
        WHEN s.statut IS DISTINCT FROM 'actif'            THEN 'statut'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  IF NOT v_poss_au_socle THEN
    WITH pb AS (
      SELECT sol->>'matricule' AS matricule, a AS objet,
             row_number() OVER (PARTITION BY sol->>'matricule', a::text) AS occ
        FROM public.compagnies_militaires c,
             jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
             jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol,
             jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                       THEN sol->'accessoires' ELSE '[]'::jsonb END) a
       WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
      UNION ALL
      SELECT r->>'matricule', a,
             row_number() OVER (PARTITION BY r->>'matricule', a::text)
        FROM public.compagnies_militaires c,
             jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r,
             jsonb_array_elements(CASE WHEN jsonb_typeof(r->'accessoires')='array'
                                       THEN r->'accessoires' ELSE '[]'::jsonb END) a
       WHERE c.id = p_compagnie
    ), ps AS (
      SELECT sm.matricule, p.objet,
             row_number() OVER (PARTITION BY sm.matricule, p.objet::text) AS occ
        FROM public.pnj_possessions p
        JOIN public.pnj_soldats_metier sm ON sm.pnj_id = p.pnj_id
        JOIN public.pnj_membres m ON m.id = p.pnj_id
       WHERE m.id LIKE p_compagnie || '-%' AND p.origine = 'blob_accessoires'
    ), pcmp AS (
      SELECT COALESCE(b.matricule, s.matricule) AS matricule,
             COALESCE(b.objet, s.objet) AS objet,
             CASE WHEN s.matricule IS NULL THEN 'possession_absente_du_socle'
                  WHEN b.matricule IS NULL THEN 'possession_surnumeraire_dans_le_socle'
                  ELSE NULL END AS divergence
        FROM pb b FULL OUTER JOIN ps s
          ON s.matricule = b.matricule AND s.objet::text = b.objet::text AND s.occ = b.occ
    )
    SELECT (SELECT count(*) FROM pb), (SELECT count(*) FROM ps),
           COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule,
                      'objet', COALESCE(objet->>'name', objet->>'nom', '?'),
                      'divergence', divergence) ORDER BY matricule)
                    FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
      INTO v_pos_blob, v_pos_socle, v_pos_div FROM pcmp;
  ELSE
    SELECT count(*), count(*), '[]'::jsonb INTO v_pos_blob, v_pos_socle, v_pos_div
      FROM public.pnj_possessions p JOIN public.pnj_membres m ON m.id = p.pnj_id
     WHERE m.id LIKE p_compagnie || '-%';
  END IF;

  SELECT COALESCE(sum(m.liquide), 0), count(*) FILTER (WHERE m.liquide <> 0)
    INTO v_liquide, v_liquide_non_nuls
    FROM public.pnj_membres m WHERE m.id LIKE p_compagnie || '-%';

  SELECT count(*) FILTER (WHERE m.leader_pj IS NOT NULL AND m.building_id IS NOT NULL),
         count(*) FILTER (WHERE m.leader_pj IS NULL     AND m.building_id IS NULL)
    INTO v_les_deux, v_ni_lun_ni_lautre
    FROM public.pnj_membres m WHERE m.id LIKE p_compagnie || '-%' AND m.statut = 'actif';

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle
          AND jsonb_array_length(v_pos_div) = 0 AND v_pos_blob = v_pos_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div),
    'manquants', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'absent_du_socle'),
    'surnumeraires', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'surnumeraire_dans_le_socle'),
    'details', v_div,
    'axes', jsonb_build_object('position_leader', v_axe_posl, 'pa', v_axe_pa,
              'possessions', v_axe_poss, 'argent', v_axe_arg, 'propriete', v_axe_prop),
    'sens', jsonb_build_object(
              'position_leader', CASE WHEN v_posl_au_socle THEN 'projection socle -> blob'
                                     ELSE 'miroir blob -> socle' END,
              'pa',              CASE WHEN v_pa_au_socle   THEN 'projection socle -> blob'
                                     ELSE 'miroir blob -> socle' END,
              'metier',          'miroir blob -> socle'),
    'possessions_blob', v_pos_blob, 'possessions_socle', v_pos_socle,
    'possessions_divergences', jsonb_array_length(v_pos_div),
    'possessions_details', v_pos_div,
    'observation_liquide_total', v_liquide,
    'observation_liquide_non_nuls', v_liquide_non_nuls,
    'observation_leader_et_position_propre', v_les_deux,
    'observation_ni_leader_ni_position', v_ni_lun_ni_lautre);
END; $function$;

-- pnj_copier_soldats(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_copier_soldats(p_compagnie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c record; s jsonb; sol jsonb; v_id text; v_pays text;
  v_sections integer := 0; v_sect integer := 0; v_res integer := 0; v_deja integer := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';

  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'soldat' AND m.id LIKE p_compagnie || '-%';
  IF v_deja > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_copie', 'deja', v_deja); END IF;

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sections := v_sections + 1;
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_institution,
          proprietaire_perimetre, leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', s->>'id',
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif');
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
          en_reserve, arme, formation, mutin,
          dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
      VALUES (v_id, sol->>'matricule', p_compagnie, s->>'id', false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
              sol->>'dernier_ration', (sol->>'nb_ration')::integer,
              sol->>'dernier_bivouac', sol->>'dernier_sommeil');
      v_sect := v_sect + 1;
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_institution,
        proprietaire_perimetre, leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire',
        p_compagnie || ':reserve',
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif');
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
        en_reserve, arme, formation, mutin,
        dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
    VALUES (v_id, sol->>'matricule', p_compagnie, NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
            sol->>'dernier_ration', (sol->>'nb_ration')::integer,
            sol->>'dernier_bivouac', sol->>'dernier_sommeil');
    v_res := v_res + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'compagnie', p_compagnie, 'pays', v_pays,
    'sections', v_sections, 'copies_section', v_sect, 'copies_reserve', v_res,
    'total', v_sect + v_res);
END; $function$;

-- pnj_employe_debaucher(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.pnj_employe_debaucher(p_ancien_proprietaire text, p_pnj_nom text, p_job text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_col text; v_liste jsonb; v_reste jsonb; v_present boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_pnj_nom), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_invalide');
  END IF;
  -- Un PNJ sans proprietaire (employeur PNJ ou personne) : rien a retirer, le debauchage est
  -- simplement libre. On le dit explicitement plutot que d'echouer.
  IF COALESCE(btrim(p_ancien_proprietaire), '') = '' OR p_ancien_proprietaire = v_moi THEN
    RETURN jsonb_build_object('ok', true, 'retire', false, 'sans_proprietaire', true);
  END IF;

  v_col := CASE WHEN p_job = 'escort' THEN 'escort_active' ELSE 'employes' END;

  IF v_col = 'escort_active' THEN
    SELECT escort_active INTO v_liste FROM public.personnages_donnees
     WHERE name = p_ancien_proprietaire FOR UPDATE;
  ELSE
    SELECT employes INTO v_liste FROM public.personnages_donnees
     WHERE name = p_ancien_proprietaire FOR UPDATE;
  END IF;
  IF NOT FOUND THEN
    -- L'ancien proprietaire n'existe plus : plus rien ne detient ce PNJ.
    RETURN jsonb_build_object('ok', true, 'retire', false, 'proprietaire_absent', true);
  END IF;

  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;

  SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) INTO v_reste
    FROM jsonb_array_elements(v_liste) e
   WHERE e->>'nom' IS DISTINCT FROM p_pnj_nom;

  v_present := jsonb_array_length(v_liste) > jsonb_array_length(v_reste);
  IF NOT v_present THEN
    -- Deja parti (double-clic, ou un autre joueur l'a debauche entre-temps).
    RETURN jsonb_build_object('ok', true, 'retire', false, 'deja_parti', true);
  END IF;

  IF v_col = 'escort_active' THEN
    UPDATE public.personnages_donnees SET escort_active = v_reste, updated_at = now()
     WHERE name = p_ancien_proprietaire;
  ELSE
    UPDATE public.personnages_donnees SET employes = v_reste, updated_at = now()
     WHERE name = p_ancien_proprietaire;
  END IF;

  RETURN jsonb_build_object('ok', true, 'retire', true,
                            'ancien_proprietaire', p_ancien_proprietaire, 'pnj', p_pnj_nom);
END;
$function$;

-- pnj_evenements_lire(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_evenements_lire(p_limite integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'evenements', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('id', e.id, 'type', e.type, 'pnj', e.pnj_nom,
             'famille', e.famille, 'ville', e.ville, 'building_id', e.building_id,
             'room_id', e.room_id, 'cree_le', e.cree_le, 'lu', e.lu_le IS NOT NULL)
             ORDER BY e.cree_le DESC)
      FROM (SELECT * FROM public.pnj_evenements e2
             WHERE e2.proprietaire_pj = v_moi
                OR (e2.proprietaire_institution IS NOT NULL
                    AND v_moi = public.pnj_autorite_de_perimetre(
                          e2.pays, e2.proprietaire_institution, e2.proprietaire_perimetre))
             ORDER BY e2.cree_le DESC LIMIT greatest(1, least(coalesce(p_limite,30), 100))) e
  ), '[]'::jsonb));
END; $function$;

-- pnj_fonction_recrutable(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_fonction_recrutable(p_fonction text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT COALESCE((SELECT f.recrutable FROM public.pnj_fonctions f WHERE f.fonction = p_fonction),
                  false);
$function$;

-- pnj_garde_dissolution_compagnie() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_garde_dissolution_compagnie()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_n integer;
BEGIN
  SELECT count(*) INTO v_n FROM public.pnj_membres WHERE id LIKE OLD.id || '-%';
  IF v_n > 0 THEN
    RAISE EXCEPTION 'pnj_garde_dissolution_compagnie: refus de supprimer la compagnie % : % PNJ '
      'du socle en dependent et deviendraient orphelins (perimetre pointant vers une compagnie '
      'disparue). Aucune regle de dissolution n existe : traiter le sort de ces hommes d abord.',
      OLD.id, v_n
      USING ERRCODE = 'raise_exception';
  END IF;
  RETURN OLD;
END; $function$;

-- pnj_garde_suppression() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_garde_suppression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.statut = 'actif' THEN
    RAISE EXCEPTION 'pnj_garde_suppression: refus de supprimer le PNJ vivant % (%). Le cycle de '
      'mort n a pas eu lieu : ses possessions seraient detruites et son proprietaire jamais '
      'informe. Appeler pnj_mourir() d abord, ou corriger le statut si la disparition est voulue.',
      OLD.id, OLD.nom
      USING ERRCODE = 'raise_exception';
  END IF;
  RETURN OLD;
END; $function$;

-- pnj_membres_ici(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_membres_ici(p_pays text, p_ville text, p_building text, p_room text, p_rue_noeud text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS DISTINCT FROM p_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  RETURN jsonb_build_object('ok', true,
    -- La position employee, pour que le client voie son propre retard s'il y en a un.
    'position_serveur', jsonb_build_object('ville', a.current_city,
      'building_id', a.current_building, 'room_id', a.current_room),
    'membres', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'id', m.id, 'nom', m.nom, 'famille', m.famille, 'pa', m.pa,
             'liquide', m.liquide, 'statut', m.statut,
             'leader_pj', m.leader_pj, 'leader_pnj_id', m.leader_pnj_id,
             'porte', pe.porte, 'mien', true) ORDER BY m.nom)
      FROM public.pnj_membres m
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.statut = 'actif'
       AND m.pays = a.country
       AND COALESCE(sm.en_reserve, false) = false
       -- LES MIENS SEULEMENT : ceux que je mene, ou dont je detiens l'autorite.
       AND (m.leader_pj = v_moi OR public.pnj_peut_administrer(v_moi, m.id))
       -- LA MEME CO-PRESENCE QUE LES VERBES, pas une seconde ecriture du meme test.
       AND public.pnj_co_present(v_moi, m.id)
  ), '[]'::jsonb));
END; $function$;

-- pnj_metier_de(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_metier_de(p_pnj_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN m.famille = 'employe'
              THEN (SELECT e.job FROM public.pnj_employes_metier e WHERE e.pnj_id = m.id)
              ELSE m.famille END
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$function$;

-- pnj_metier_profil(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_metier_profil(p_metier text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('INT', p.car_int, 'CHA', p.car_cha, 'VOL', p.car_vol,
                            'PER', p.car_per, 'DUP', p.car_dup, 'ENT', p.car_ent)
    FROM public.pnj_metiers_profils p WHERE p.metier = p_metier;
$function$;

-- pnj_miroir_compagnie(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text; v_res_per text;
        v_pos_blob boolean; v_pa_blob boolean;
BEGIN
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';
  v_res_per := p_compagnie || ':reserve';
  -- Le miroir importe des que le socle NE fait PAS autorite : le blob, ou qui que ce soit d'autre,
  -- garde alors la main. `pnj_axe_au_socle` est totale, il n'y a donc pas de COALESCE a prevoir.
  v_pos_blob := NOT public.pnj_axe_au_socle('soldat', 'position_leader');
  v_pa_blob  := NOT public.pnj_axe_au_socle('soldat', 'pa');

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sec := s->>'id';
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      v_vus := v_vus || v_id;
      INSERT INTO public.pnj_membres (id, famille, nom, pays,
          proprietaire_institution, proprietaire_perimetre,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_sec,
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif')
      ON CONFLICT (id) DO UPDATE SET
          leader_pj   = CASE WHEN v_pos_blob THEN EXCLUDED.leader_pj   ELSE pnj_membres.leader_pj END,
          ville       = CASE WHEN v_pos_blob THEN EXCLUDED.ville       ELSE pnj_membres.ville END,
          building_id = CASE WHEN v_pos_blob THEN EXCLUDED.building_id ELSE pnj_membres.building_id END,
          room_id     = CASE WHEN v_pos_blob THEN EXCLUDED.room_id     ELSE pnj_membres.room_id END,
          pa          = CASE WHEN v_pa_blob  THEN EXCLUDED.pa          ELSE pnj_membres.pa END,
          statut = EXCLUDED.statut,
          proprietaire_institution = EXCLUDED.proprietaire_institution,
          proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
          maj_le = now();
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
          en_reserve, arme, formation, mutin,
          dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
      VALUES (v_id, sol->>'matricule', p_compagnie, v_sec, false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
              sol->>'dernier_ration', (sol->>'nb_ration')::integer,
              sol->>'dernier_bivouac', sol->>'dernier_sommeil')
      ON CONFLICT (pnj_id) DO UPDATE SET
          compagnie_id = EXCLUDED.compagnie_id,
          section_id = EXCLUDED.section_id, en_reserve = EXCLUDED.en_reserve,
          arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin,
          dernier_ration = EXCLUDED.dernier_ration, nb_ration = EXCLUDED.nb_ration,
          dernier_bivouac = EXCLUDED.dernier_bivouac, dernier_sommeil = EXCLUDED.dernier_sommeil;
      v_maj := v_maj + 1;
      PERFORM public.pnj_miroir_possessions_si_axe_blob(v_id,
        CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    v_vus := v_vus || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_res_per,
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif')
    ON CONFLICT (id) DO UPDATE SET
        leader_pj   = CASE WHEN v_pos_blob THEN EXCLUDED.leader_pj   ELSE pnj_membres.leader_pj END,
        ville       = CASE WHEN v_pos_blob THEN EXCLUDED.ville       ELSE pnj_membres.ville END,
        building_id = CASE WHEN v_pos_blob THEN EXCLUDED.building_id ELSE pnj_membres.building_id END,
        room_id     = CASE WHEN v_pos_blob THEN EXCLUDED.room_id     ELSE pnj_membres.room_id END,
        pa          = CASE WHEN v_pa_blob  THEN EXCLUDED.pa          ELSE pnj_membres.pa END,
        statut = EXCLUDED.statut,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        maj_le = now();
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
        en_reserve, arme, formation, mutin,
        dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
    VALUES (v_id, sol->>'matricule', p_compagnie, NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
            sol->>'dernier_ration', (sol->>'nb_ration')::integer,
            sol->>'dernier_bivouac', sol->>'dernier_sommeil')
    ON CONFLICT (pnj_id) DO UPDATE SET
        compagnie_id = EXCLUDED.compagnie_id,
        section_id = NULL, en_reserve = true,
        arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin,
        dernier_ration = EXCLUDED.dernier_ration, nb_ration = EXCLUDED.nb_ration,
        dernier_bivouac = EXCLUDED.dernier_bivouac, dernier_sommeil = EXCLUDED.dernier_sommeil;
    v_maj := v_maj + 1;
    PERFORM public.pnj_miroir_possessions_si_axe_blob(v_id,
      CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
  END LOOP;

  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_sup = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'supprimes', v_sup);
END; $function$;

-- pnj_miroir_compagnie_trg() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie_trg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- On ne miroite que si le blob a reellement change, pour ne pas payer O(n) sur un
  -- UPDATE qui ne touche que updated_at.
  IF TG_OP = 'UPDATE' AND NEW.data IS NOT DISTINCT FROM OLD.data THEN RETURN NEW; END IF;
  PERFORM public.pnj_miroir_compagnie(NEW.id);
  RETURN NEW;
END; $function$;

-- pnj_miroir_douane(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_douane(p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_etat jsonb; v_liste jsonb; d jsonb; v_id text; v_vus text[] := '{}';
  v_maj integer := 0; v_partis integer := 0; v_st jsonb; v_def jsonb;
  v_per text := p_ville || ':' || p_batiment;
BEGIN
  SELECT public.batiment_etat_lire(data) INTO v_etat
    FROM public.batiments_etat
   WHERE country = p_pays AND city = p_ville AND building_id = p_batiment;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etat_introuvable'); END IF;
  v_liste := v_etat->'effectifsDouane'->'douaniers';
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_def := public.douane_caracteristiques_metier();

  FOR d IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    CONTINUE WHEN COALESCE(d->>'matricule', '') = '';
    v_id := public.douane_pnj_id(p_pays, p_ville, d->>'matricule');
    v_vus := v_vus || v_id;
    v_st := CASE WHEN jsonb_typeof(d->'stats') = 'object' THEN d->'stats' ELSE '{}'::jsonb END;

    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        ville, building_id, room_id, pa, statut,
        car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_id, 'douanier', d->>'matricule', p_pays, 'douane', v_per,
        p_ville, COALESCE(d->>'buildingId', p_batiment), d->>'roomId', 12, 'actif',
        COALESCE((v_st->>'INT')::integer, (v_def->>'INT')::integer),
        COALESCE((v_st->>'CHA')::integer, (v_def->>'CHA')::integer),
        COALESCE((v_st->>'VOL')::integer, (v_def->>'VOL')::integer),
        COALESCE((v_st->>'PER')::integer, (v_def->>'PER')::integer),
        COALESCE((v_st->>'DUP')::integer, (v_def->>'DUP')::integer),
        COALESCE((v_st->>'ENT')::integer, (v_def->>'ENT')::integer))
    ON CONFLICT (id) DO UPDATE SET
        statut = 'actif',
        ville = EXCLUDED.ville, building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
        car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
        maj_le = now();

    INSERT INTO public.pnj_force_publique_metier
        (pnj_id, matricule, type_unite, maitre_nom, chien_nom, recrute_le)
    VALUES (v_id, d->>'matricule', COALESCE(d->>'type', 'standard'),
            d->>'maitreNom', d->>'chienNom',
            COALESCE(to_timestamp(NULLIF(d->>'recruteLe','')::numeric / 1000.0), now()))
    ON CONFLICT (pnj_id) DO UPDATE SET
        matricule = EXCLUDED.matricule, type_unite = EXCLUDED.type_unite,
        maitre_nom = EXCLUDED.maitre_nom, chien_nom = EXCLUDED.chien_nom;
    v_maj := v_maj + 1;
  END LOOP;

  -- DEPART, PAS DECES. On ne supprime pas : la garde le refuserait sur un PNJ actif, et un agent
  -- retire faute de budget n'est pas mort. On le delie et on le marque disparu.
  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL, maj_le = now()
   WHERE famille = 'douanier' AND pays = p_pays AND proprietaire_perimetre = v_per
     AND statut = 'actif' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_partis = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'partis', v_partis);
END; $function$;

-- pnj_miroir_douane_declencheur() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_douane_declencheur()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Ne s'active que sur l'etat qui porte reellement des douaniers.
  IF NEW.building_id = 'port-sainte-marie'
     AND COALESCE(public.batiment_etat_lire(NEW.data), '{}'::jsonb) ? 'effectifsDouane' THEN
    PERFORM public.pnj_miroir_douane(NEW.country, NEW.city, NEW.building_id);
  END IF;
  RETURN NULL;
END; $function$;

-- pnj_miroir_police(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_police(p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_etat jsonb; v_liste jsonb; d jsonb; v_id text; v_vus text[] := '{}';
  v_maj integer := 0; v_partis integer := 0; v_st jsonb; v_def jsonb;
  v_per text := p_ville || ':' || p_batiment;
BEGIN
  SELECT public.batiment_etat_lire(data) INTO v_etat
    FROM public.batiments_etat
   WHERE country = p_pays AND city = p_ville AND building_id = p_batiment;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etat_introuvable'); END IF;
  v_liste := v_etat->'effectifsPolice'->'policiers';
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_def := public.police_caracteristiques_metier();

  FOR d IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    CONTINUE WHEN COALESCE(d->>'matricule', '') = '';
    v_id := public.police_pnj_id(p_pays, p_ville, d->>'matricule');
    v_vus := v_vus || v_id;
    v_st := CASE WHEN jsonb_typeof(d->'stats') = 'object' THEN d->'stats' ELSE '{}'::jsonb END;

    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        ville, building_id, room_id, rue_noeud_id, pa, statut,
        car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_id, 'policier', d->>'matricule', p_pays, 'police', v_per,
        p_ville, d->>'buildingId', d->>'roomId', d->>'rueNoeudId', 12, 'actif',
        COALESCE((v_st->>'INT')::integer, (v_def->>'INT')::integer),
        COALESCE((v_st->>'CHA')::integer, (v_def->>'CHA')::integer),
        COALESCE((v_st->>'VOL')::integer, (v_def->>'VOL')::integer),
        COALESCE((v_st->>'PER')::integer, (v_def->>'PER')::integer),
        COALESCE((v_st->>'DUP')::integer, (v_def->>'DUP')::integer),
        COALESCE((v_st->>'ENT')::integer, (v_def->>'ENT')::integer))
    ON CONFLICT (id) DO UPDATE SET
        statut = 'actif',
        ville = EXCLUDED.ville, building_id = EXCLUDED.building_id,
        room_id = EXCLUDED.room_id, rue_noeud_id = EXCLUDED.rue_noeud_id,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
        car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
        maj_le = now();

    INSERT INTO public.pnj_force_publique_metier
        (pnj_id, matricule, type_unite, maitre_nom, chien_nom, recrute_le)
    VALUES (v_id, d->>'matricule', COALESCE(d->>'type', 'standard'),
            d->>'maitreNom', d->>'chienNom',
            COALESCE(to_timestamp(NULLIF(d->>'recruteLe','')::numeric / 1000.0), now()))
    ON CONFLICT (pnj_id) DO UPDATE SET
        matricule = EXCLUDED.matricule, type_unite = EXCLUDED.type_unite,
        maitre_nom = EXCLUDED.maitre_nom, chien_nom = EXCLUDED.chien_nom;
    v_maj := v_maj + 1;
  END LOOP;

  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL, maj_le = now()
   WHERE famille = 'policier' AND pays = p_pays AND proprietaire_perimetre = v_per
     AND statut = 'actif' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_partis = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'partis', v_partis);
END; $function$;

-- pnj_miroir_police_declencheur() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_police_declencheur()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.building_id IN ('commissariat','commissariat-local')
     AND COALESCE(public.batiment_etat_lire(NEW.data), '{}'::jsonb) ? 'effectifsPolice' THEN
    PERFORM public.pnj_miroir_police(NEW.country, NEW.city, NEW.building_id);
  END IF;
  RETURN NULL;
END; $function$;

-- pnj_miroir_possessions(text,jsonb) -> TABLE(ins integer, sup integer) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_possessions(p_pnj_id text, p_accessoires jsonb)
 RETURNS TABLE(ins integer, sup integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ins integer := 0; v_sup integer := 0;
BEGIN
  -- Ce qui a disparu du blob disparait du socle. Comparaison par texte de l'objet ENTIER et par
  -- rang d'occurrence, pour gerer correctement deux exemplaires identiques.
  WITH voulu AS (
    SELECT a::text AS cle, row_number() OVER (PARTITION BY a::text) AS occ
      FROM jsonb_array_elements(COALESCE(p_accessoires,'[]'::jsonb)) a),
  present AS (
    SELECT p.id, p.objet::text AS cle, row_number() OVER (PARTITION BY p.objet::text ORDER BY p.id) AS occ
      FROM public.pnj_possessions p
     WHERE p.pnj_id = p_pnj_id AND p.origine = 'blob_accessoires'),
  a_supprimer AS (
    SELECT pr.id FROM present pr
     WHERE NOT EXISTS (SELECT 1 FROM voulu v WHERE v.cle = pr.cle AND v.occ = pr.occ))
  DELETE FROM public.pnj_possessions p USING a_supprimer d WHERE p.id = d.id;
  GET DIAGNOSTICS v_sup = ROW_COUNT;

  -- Ce qui est apparu dans le blob apparait dans le socle, objet COMPLET, sans reconstruction.
  WITH voulu AS (
    SELECT a AS objet, a::text AS cle, row_number() OVER (PARTITION BY a::text) AS occ
      FROM jsonb_array_elements(COALESCE(p_accessoires,'[]'::jsonb)) a),
  present AS (
    SELECT p.objet::text AS cle, row_number() OVER (PARTITION BY p.objet::text ORDER BY p.id) AS occ
      FROM public.pnj_possessions p
     WHERE p.pnj_id = p_pnj_id AND p.origine = 'blob_accessoires')
  INSERT INTO public.pnj_possessions (pnj_id, objet, exemplaire_unique, origine)
  SELECT p_pnj_id, v.objet,
         COALESCE((v.objet->>'usageUnique')::boolean, false),
         'blob_accessoires'
    FROM voulu v
   WHERE NOT EXISTS (SELECT 1 FROM present pr WHERE pr.cle = v.cle AND pr.occ = v.occ);
  GET DIAGNOSTICS v_ins = ROW_COUNT;

  RETURN QUERY SELECT v_ins, v_sup;
END; $function$;

-- pnj_miroir_possessions_si_axe_blob(text,jsonb) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_miroir_possessions_si_axe_blob(p_pnj_id text, p_accessoires jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF public.pnj_axe_verrouille(ARRAY[p_pnj_id], 'possessions') IS NOT NULL THEN
    PERFORM public.pnj_miroir_possessions(p_pnj_id, p_accessoires);
  END IF;
END; $function$;

-- pnj_mon_inventaire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_mon_inventaire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'inventaire', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('index', t.rang, 'objet', t.v) ORDER BY t.rang)
        FROM (SELECT (row_number() OVER ()) - 1 AS rang, value AS v
                FROM public.personnages_donnees d,
                     jsonb_array_elements(COALESCE(d.inventory,'[]'::jsonb))
               WHERE d.name = v_moi) t
    ), '[]'::jsonb));
END; $function$;

-- pnj_mourir(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_mourir(p_id text, p_cause text DEFAULT 'indetermine'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m record; pe record; v_n integer := 0; o record; v_ville text; v_bat text; v_room text;
BEGIN
  SELECT * INTO m FROM public.pnj_membres WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF m.statut = 'mort' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_mort', 'deposes', 0); END IF;

  SELECT * INTO pe FROM public.pnj_position_effective(p_id);
  -- Le lieu du depot, encode comme le jeu le fait deja pour la rue.
  v_ville := COALESCE(pe.ville, 'inconnue');
  v_bat   := COALESCE(pe.building_id, 'rue-centrale');
  v_room  := COALESCE(pe.room_id, pe.rue_noeud_id, 'inconnu');

  -- Delier AVANT d'ecrire la position propre : I1 interdit les deux a la fois.
  UPDATE public.pnj_membres
     SET statut = 'mort', leader_pj = NULL, leader_pnj_id = NULL,
         ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
   WHERE id = p_id;

  -- TOUTES les possessions tombent, y compris celles issues du miroir du blob : dans ce chemin
  -- le blob perd le soldat, donc la ligne miroir est le dernier exemplaire. C'est ici qu'elle
  -- doit atterrir au sol, pas disparaitre.
  FOR o IN SELECT * FROM public.pnj_possessions WHERE pnj_id = p_id LOOP
    INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
    VALUES ('objet-abandonne-' || replace(gen_random_uuid()::text, '-', ''),
            pe.pays, v_ville, v_bat, v_room,
            (o.objet || jsonb_build_object('id',
               'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '')))::text);
    v_n := v_n + 1;
  END LOOP;
  DELETE FROM public.pnj_possessions WHERE pnj_id = p_id;

  -- L'AVIS AU PROPRIETAIRE. Inconditionnel : aucune radio, aucune co-presence exigee.
  INSERT INTO public.pnj_evenements (pnj_id, pnj_nom, famille, type, pays, proprietaire_pj,
      proprietaire_institution, proprietaire_perimetre, ville, building_id, room_id,
      objets_deposes, argent_du_defunt)
  VALUES (m.id, m.nom, m.famille, 'mort', m.pays, m.proprietaire_pj,
      m.proprietaire_institution, m.proprietaire_perimetre, v_ville, v_bat, v_room,
      v_n, COALESCE(m.liquide, 0));

  RETURN jsonb_build_object('ok', true, 'cause', p_cause, 'deposes', v_n,
                            'argent_du_defunt', COALESCE(m.liquide, 0),
                            'ville', v_ville, 'building_id', v_bat, 'room_id', v_room);
END; $function$;

-- pnj_mouvement_individuel_refus(text[]) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_mouvement_individuel_refus(p_ids text[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('pnj', m.id, 'famille', m.famille,
                            'raison', r.raison, 'explication', r.note)
    FROM public.pnj_membres m
    JOIN public.pnj_mouvement_individuel r ON r.famille = m.famille
   WHERE m.id = ANY(p_ids) AND r.autorise = false
   LIMIT 1;
$function$;

-- pnj_objet_transferer(text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_objet_transferer(p_pnj text, p_index integer, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_inv jsonb; v_objet jsonb; v_poss record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT public.pnj_co_present(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  IF p_sens = 'donner' THEN
    SELECT COALESCE(inventory, '[]'::jsonb) INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    IF p_index IS NULL OR p_index < 0 OR p_index >= jsonb_array_length(v_inv) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'index_invalide'); END IF;
    v_objet := v_inv -> p_index;
    UPDATE public.personnages_donnees
       SET inventory = (v_inv - p_index) WHERE name = v_moi;
    INSERT INTO public.pnj_possessions (pnj_id, objet) VALUES (p_pnj, v_objet);
    RETURN jsonb_build_object('ok', true, 'sens', 'donner', 'objet', v_objet);

  ELSIF p_sens = 'retirer' THEN
    -- Meme ordonnancement que pnj_possessions_lire : l'index reste l'index affiche.
    SELECT * INTO v_poss FROM public.pnj_possessions
     WHERE pnj_id = p_pnj ORDER BY id OFFSET p_index LIMIT 1 FOR UPDATE;
    IF v_poss.id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'index_invalide'); END IF;
    IF v_poss.origine <> 'socle' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_cessible',
        'origine', v_poss.origine,
        'explication', 'Cet objet est le miroir d une possession que le metier detient encore. '
                    || 'Le reprendre le dupliquerait. Il faut passer par l action metier.'); END IF;
    SELECT COALESCE(inventory, '[]'::jsonb) INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    UPDATE public.personnages_donnees
       SET inventory = v_inv || jsonb_build_array(v_poss.objet) WHERE name = v_moi;
    DELETE FROM public.pnj_possessions WHERE id = v_poss.id;
    RETURN jsonb_build_object('ok', true, 'sens', 'retirer', 'objet', v_poss.objet);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
END; $function$;

-- pnj_pa_crediter(text[],integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_pa_crediter(p_ids text[], p_gain integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_refus jsonb; v_n integer := 0;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_gain IS NULL OR p_gain < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'gain_invalide'); END IF;
  UPDATE public.pnj_membres
     SET pa = least(public.pnj_pa_max(), pa + p_gain), maj_le = now()
   WHERE id = ANY(p_ids) AND statut = 'actif';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'touches', v_n, 'gain', p_gain);
END; $function$;

-- pnj_pa_debiter(text[],integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_pa_debiter(p_ids text[], p_cout integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_refus jsonb; v_touches integer := 0; v_epuises integer := 0;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_cout IS NULL OR p_cout < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide'); END IF;

  WITH maj AS (
    UPDATE public.pnj_membres
       SET pa = greatest(0, pa - p_cout), maj_le = now()
     WHERE id = ANY(p_ids) AND statut = 'actif'
    RETURNING pa)
  SELECT count(*), count(*) FILTER (WHERE pa = 0) INTO v_touches, v_epuises FROM maj;

  -- `epuises` est une CONSTATATION remise au metier, pas une mort.
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'epuises', v_epuises,
                            'cout', p_cout);
END; $function$;

-- pnj_pa_fixer(text[],integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_pa_fixer(p_ids text[], p_valeur integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_refus jsonb; v_n integer := 0; v_val integer;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_valeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  v_val := least(public.pnj_pa_max(), greatest(0, p_valeur));
  UPDATE public.pnj_membres SET pa = v_val, maj_le = now()
   WHERE id = ANY(p_ids) AND statut = 'actif';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'touches', v_n, 'valeur', v_val,
                            'epuises', CASE WHEN v_val = 0 THEN v_n ELSE 0 END);
END; $function$;

-- pnj_pa_garde(text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_pa_garde(p_ids text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_bloque text; v_hors text; v_classe text;
BEGIN
  v_bloque := public.pnj_axe_verrouille(p_ids, 'pa');
  IF v_bloque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'axe_pa_hors_socle', 'pnj', v_bloque,
      'explication', 'Les PA de cette famille vivent encore dans son magasin historique.');
  END IF;
  SELECT m.id, public.pnj_classe_de(m.id) INTO v_hors, v_classe
    FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids) AND COALESCE(public.pnj_classe_de(m.id), '') <> 'alpha'
   LIMIT 1;
  IF v_hors IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'classe_sans_consommation_de_pa',
      'pnj', v_hors, 'classe', COALESCE(v_classe, 'non_declaree'),
      'explication', 'Seule la classe alpha voit ses PA varier pour agir.');
  END IF;
  RETURN NULL;
END; $function$;

-- pnj_pa_max() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.pnj_pa_max()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 12; $function$;

-- pnj_pas_de_sous_hierarchie() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_pas_de_sous_hierarchie()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF (NEW.leader_pj IS NOT NULL OR NEW.leader_pnj_id IS NOT NULL)
     AND EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.leader_pnj_id = NEW.id) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: % conduit deja des membres', NEW.id;
  END IF;
  IF NEW.leader_pnj_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM public.pnj_membres m WHERE m.id = NEW.leader_pnj_id
         AND (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: le leader % suit lui-meme un chef',
                    NEW.leader_pnj_id;
  END IF;
  NEW.maj_le := now();
  RETURN NEW;
END; $function$;

-- pnj_peut_administrer(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_peut_administrer(p_moi text, p_pnj_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (p_moi = public.pnj_autorite_de(p_pnj_id)) IS TRUE;
$function$;

-- pnj_peut_conduire(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_peut_conduire(p_moi text, p_pnj_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.pnj_peut_administrer(p_moi, p_pnj_id)
      OR ((p_moi = (SELECT leader_pj FROM public.pnj_membres WHERE id = p_pnj_id)) IS TRUE);
$function$;

-- pnj_position_effective(text) -> TABLE(pays text, ville text, building_id text, room_id text, rue_noeud_id text, porte boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_position_effective(p_id text)
 RETURNS TABLE(pays text, ville text, building_id text, room_id text, rue_noeud_id text, porte boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.pays,
    CASE WHEN m.leader_pj IS NOT NULL THEN d.current_city
         WHEN m.leader_pnj_id IS NOT NULL THEN l.ville ELSE m.ville END,
    CASE WHEN m.leader_pj IS NOT NULL THEN d.current_building
         WHEN m.leader_pnj_id IS NOT NULL THEN l.building_id ELSE m.building_id END,
    CASE WHEN m.leader_pj IS NOT NULL THEN d.current_room
         WHEN m.leader_pnj_id IS NOT NULL THEN l.room_id ELSE m.room_id END,
    CASE WHEN m.leader_pj IS NOT NULL THEN NULL
         WHEN m.leader_pnj_id IS NOT NULL THEN l.rue_noeud_id ELSE m.rue_noeud_id END,
    (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)
  FROM public.pnj_membres m
  LEFT JOIN public.personnages_donnees d ON d.name = m.leader_pj
  LEFT JOIN public.pnj_membres         l ON l.id   = m.leader_pnj_id
  WHERE m.id = p_id;
$function$;

-- pnj_possessions_lire(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_possessions_lire(p_pnj text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT public.pnj_co_present(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;
  RETURN jsonb_build_object('ok', true,
    'liquide', (SELECT liquide FROM public.pnj_membres WHERE id = p_pnj),
    'possessions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('index', t.rang, 'objet', t.objet,
               'origine', t.origine, 'cessible', t.origine = 'socle') ORDER BY t.rang)
        FROM (SELECT (row_number() OVER (ORDER BY p.id)) - 1 AS rang, p.objet, p.origine
                FROM public.pnj_possessions p WHERE p.pnj_id = p_pnj) t
    ), '[]'::jsonb));
END; $function$;

-- pnj_prendre(text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_prendre(p_ids text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record; v_n integer := 0; v_refus jsonb;
BEGIN
  v_refus := public.pnj_axe_position_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_refus := public.pnj_mouvement_individuel_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    IF NOT public.pnj_co_present(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    UPDATE public.pnj_membres SET leader_pj = v_moi, leader_pnj_id = NULL,
      ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'pris', v_n);
END; $function$;

-- pnj_quitter_groupe(text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_quitter_groupe(p_ids text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record; pe record; v_n integer := 0; v_refus jsonb;
BEGIN
  v_refus := public.pnj_axe_position_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_refus := public.pnj_mouvement_individuel_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres WHERE id = ANY(p_ids) FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pe FROM public.pnj_position_effective(r.id);
    UPDATE public.pnj_membres
       SET leader_pj = NULL, leader_pnj_id = NULL,
           ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
     WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'detaches', v_n);
END; $function$;

-- pnj_rollback_soldats(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_rollback_soldats(p_compagnie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant integer; v_apres integer; v_autres_avant integer; v_autres_apres integer;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  SELECT count(*) INTO v_avant FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_autres_avant FROM public.pnj_membres WHERE id NOT LIKE p_compagnie || '-%';
  DELETE FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_apres FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_autres_apres FROM public.pnj_membres WHERE id NOT LIKE p_compagnie || '-%';
  RETURN jsonb_build_object('ok', v_apres = 0 AND v_autres_avant = v_autres_apres,
    'supprimes', v_avant - v_apres, 'restants_compagnie', v_apres,
    'autres_familles_avant', v_autres_avant, 'autres_familles_apres', v_autres_apres,
    'metier_orphelin', (SELECT count(*) FROM public.pnj_soldats_metier sm
                         WHERE NOT EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.id = sm.pnj_id)));
END; $function$;

-- pnj_social_contexte(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_social_contexte(p_pnj_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.pnj_social_relations
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;
  IF NOT FOUND THEN
    -- Pas de relation : soit ce PNJ n'en tient pas, soit ils ne se sont jamais vus.
    -- Dans les deux cas le prompt reste celui d'avant.
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_relation'); END IF;

  RETURN jsonb_build_object('ok', true,
    'rencontres', r.rencontres, 'conversations', r.conversations,
    'familiarite', r.familiarite, 'confiance', r.confiance,
    'memoire', r.memoire);
END; $function$;

-- pnj_social_entrer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_social_entrer(p_pnj_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record; v_jalon text; v_genre text; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_pnj_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_absent'); END IF;
  -- Un PNJ sans regle de jalon n'est pas un PNJ social : on ne cree aucune ligne
  -- pour les 175 autres, qui n'ont aucune memoire a tenir.
  IF NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = p_pnj_id) THEN
    RETURN jsonb_build_object('ok', true, 'social', false); END IF;

  INSERT INTO public.pnj_social_relations (pnj_id, joueur, rencontres)
       VALUES (p_pnj_id, v_moi, 1)
  ON CONFLICT (pnj_id, joueur) DO UPDATE
     SET rencontres = public.pnj_social_relations.rencontres + 1,
         derniere_le = now();

  SELECT * INTO r FROM public.pnj_social_relations
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;

  -- Le premier jalon eligible, non deja joue. Ordre stable par `rang`.
  SELECT g.jalon INTO v_jalon
    FROM public.pnj_social_jalons_regles g
   WHERE g.pnj_id = p_pnj_id
     AND r.rencontres >= g.min_rencontres
     AND (g.max_conversations IS NULL OR r.conversations <= g.max_conversations)
     AND coalesce((r.jalons ->> g.jalon)::boolean, false) = false
   ORDER BY g.rang, g.jalon
   LIMIT 1;

  IF v_jalon IS NOT NULL THEN
    -- MARQUE AVANT D'ETRE JOUE. Un F5 entre les deux ne le rejouera pas.
    UPDATE public.pnj_social_relations
       SET jalons = jsonb_set(jalons, ARRAY[v_jalon], 'true'::jsonb, true)
     WHERE pnj_id = p_pnj_id AND joueur = v_moi;
  END IF;

  -- La memoire de V1 ne contient que des faits CERTAINS, connus du jeu : le nom du
  -- joueur et son genre s'il est renseigne. Aucun contenu de conversation, aucun
  -- resume, aucune extraction.
  SELECT d.name, nullif(btrim(coalesce(d.stats->>'genre', '')), '')
    INTO v_nom, v_genre
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  UPDATE public.pnj_social_relations
     SET memoire = memoire || jsonb_strip_nulls(jsonb_build_object('nom', v_nom, 'genre', v_genre))
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;

  RETURN jsonb_build_object('ok', true, 'social', true,
    'rencontres', r.rencontres, 'conversations', r.conversations,
    'familiarite', r.familiarite, 'jalon', v_jalon);
END; $function$;

-- pnj_social_noter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_social_noter(p_pnj_id text, p_evenement text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_fam integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_evenement IS DISTINCT FROM 'conversation' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'evenement_inconnu'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = p_pnj_id)
     AND NOT EXISTS (SELECT 1 FROM public.pnj_social_relations r
                      WHERE r.pnj_id = p_pnj_id AND r.joueur = v_moi) THEN
    RETURN jsonb_build_object('ok', true, 'social', false); END IF;

  INSERT INTO public.pnj_social_relations (pnj_id, joueur, rencontres, conversations, familiarite)
       VALUES (p_pnj_id, v_moi, 1, 1, 1)
  ON CONFLICT (pnj_id, joueur) DO UPDATE
     SET conversations = public.pnj_social_relations.conversations + 1,
         familiarite   = LEAST(5, public.pnj_social_relations.familiarite + 1),
         derniere_le   = now();

  SELECT familiarite INTO v_fam FROM public.pnj_social_relations
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;
  RETURN jsonb_build_object('ok', true, 'social', true, 'familiarite', v_fam);
END; $function$;

-- pnj_transferer(text[],text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pnj_transferer(p_ids text[], p_dest text, p_dest_est_pnj boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record; dv text; db text; dr text; pm record; v_n integer := 0; v_refus jsonb;
BEGIN
  v_refus := public.pnj_axe_position_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_refus := public.pnj_mouvement_individuel_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_dest_est_pnj THEN
    SELECT ville, building_id, room_id INTO dv, db, dr
      FROM public.pnj_position_effective(p_dest);
    IF NOT EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = p_dest AND statut = 'actif') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  ELSE
    SELECT current_city, current_building, current_room INTO dv, db, dr
      FROM public.personnages_donnees WHERE name = p_dest;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  END IF;

  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pm FROM public.pnj_position_effective(r.id);
    IF pm.ville IS DISTINCT FROM dv OR pm.building_id IS DISTINCT FROM db
       OR pm.room_id IS DISTINCT FROM dr THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    IF p_dest_est_pnj THEN
      UPDATE public.pnj_membres SET leader_pj = NULL, leader_pnj_id = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    ELSE
      UPDATE public.pnj_membres SET leader_pnj_id = NULL, leader_pj = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'transferes', v_n, 'nouveau_leader', p_dest);
END; $function$;
