-- BLOCUS SYNDICAL AU SERVEUR (02/11/2026, décisions de Fred dans GAME-DESIGN-BLOCUS.md).
--
-- 1. Seuls le Secrétaire Général et son Adjoint organisent et renouvellent un blocus.
-- 2. Bâtiment bloqué : on entre dans la première pièce, pas dans les autres ; les ordres du
--    bâtiment sont refusés.
-- 3. « Renouveler le blocus » relève du syndicat, « Faire intervenir les forces de l'ordre » du
--    commissaire, depuis son bureau, en choisissant parmi les blocus de sa ville.
-- Règles d'août 2026 conservées : 2 militants minimum, réussite min(90, 10 + 6 × militants +
-- puissance/5), intensité min(90, 10 + 6 × militants), fin après 25 h sans renouvellement, maire
-- de la ville −max(1, intensité/15) POP chaque nuit, dispersion max(10, min(90, 55 − intensité/3)),
-- répression violente : +1 repressionsSubies, interdite pendant une grève de policiers ; chaque
-- blocus réussi : +1 blocusReussis.
--
-- Le blocus reste rangé où il l'était (batiments_etat, sous-clé « blocus »), lu par l'écran tel quel.
-- L'écran ne peut plus l'écrire : seule une fonction serveur le pose, le renouvelle ou le lève.

-- ---------------------------------------------------------------------------------------------
-- Ordres rattachés à chaque bâtiment (catalogue effectif, généré : voir plus bas).
-- ---------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blocus_ordres_batiments (
  pays text NOT NULL DEFAULT 'republic',
  ville text NOT NULL,
  batiment text NOT NULL,
  fn text NOT NULL,
  PRIMARY KEY (pays, ville, batiment, fn)
);
ALTER TABLE public.blocus_ordres_batiments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.blocus_ordres_batiments FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Lecture : le blocus actif d'un bâtiment (NULL si aucun, ou s'il a dépassé 25 h sans
-- renouvellement — même seuil que la levée de nuit, pour qu'aucun blocus périmé ne bloque).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocus_actif_interne(p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT x.b FROM (
    SELECT public.batiment_etat_lire(e.data) -> 'blocus' AS b
      FROM public.batiments_etat e
     WHERE e.id = p_pays || '_' || p_ville || '_' || p_batiment) x
   WHERE jsonb_typeof(x.b) = 'object'
     AND coalesce(nullif(x.b->>'dernierRenouvellementTimestamp', '')::numeric,
                  nullif(x.b->>'lanceLe', '')::numeric, 0)
         > extract(epoch FROM clock_timestamp()) * 1000 - 25 * 3600000;
$function$;

-- Un ordre est refusé si l'acteur se tient dans un bâtiment bloqué et que l'ordre appartient à ce
-- bâtiment. Appelée par payer_ordre_interne, la porte commune des ordres payants.
CREATE OR REPLACE FUNCTION public.blocus_ordre_refuse_interne(p_acteur text, p_fn text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees p
      JOIN public.blocus_ordres_batiments o
        ON o.pays = coalesce(p.country, 'republic') AND o.ville = p.current_city
       AND o.batiment = p.current_building AND o.fn = p_fn
     WHERE p.name = p_acteur AND p.current_building IS NOT NULL
       AND public.blocus_actif_interne(coalesce(p.country, 'republic'), p.current_city,
                                       p.current_building) IS NOT NULL);
$function$;

-- Le Secrétaire Général (grade le plus haut, ou chef de l'organisation) et son Adjoint (grade
-- juste en dessous). Hiérarchie effective de data.js : Adhérent, Délégué, Secrétaire Adjoint,
-- Secrétaire Général — soit les rangs 3 et 2.
CREATE OR REPLACE FUNCTION public.blocus_syndicat_dirigeant_interne(p_nom text, p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_data->>'type', '') = 'syndicale' AND (
    coalesce(p_data->>'chef', '') = p_nom
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(
                 CASE WHEN jsonb_typeof(p_data->'membres') = 'array' THEN p_data->'membres'
                      ELSE '[]'::jsonb END) m
                WHERE m->>'nom' = p_nom
                  AND coalesce(m->>'estPnj', 'false') <> 'true'
                  AND (m->>'gradeIdx') ~ '^[0-9]+$' AND (m->>'gradeIdx')::int IN (2, 3)));
$function$;

-- Un syndicat de policiers en grève rend la répression impossible (règle de septembre 2026).
CREATE OR REPLACE FUNCTION public.blocus_police_en_greve_interne(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.organisations o
     WHERE left(btrim(coalesce(o.data, '')), 1) = '{'
       AND (o.data::jsonb->>'type') = 'syndicale'
       AND (o.data::jsonb->>'corpsMetier') = 'police'
       AND coalesce(o.data::jsonb->>'country', o.country_origine) = p_pays
       AND (coalesce(o.data::jsonb #>> '{greve,actif}', 'false') = 'true'
            OR (o.data::jsonb->>'greveGeneraleStatut') = 'actif'));
$function$;

-- Écriture du blocus d'un bâtiment (NULL = levée), au format historique de batiments_etat.
CREATE OR REPLACE FUNCTION public.blocus_ecrire_interne(p_pays text, p_ville text, p_batiment text, p_blocus jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_' || p_ville || '_' || p_batiment; v_etat jsonb;
BEGIN
  SELECT coalesce(public.batiment_etat_lire(data), '{}'::jsonb) INTO v_etat
    FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN
    IF p_blocus IS NULL THEN RETURN; END IF;
    INSERT INTO public.batiments_etat (id, country, city, building_id, data)
    VALUES (v_id, p_pays, p_ville, p_batiment, to_jsonb(jsonb_build_object('blocus', p_blocus)::text));
    RETURN;
  END IF;
  v_etat := CASE WHEN p_blocus IS NULL THEN v_etat - 'blocus'
                 ELSE jsonb_set(v_etat, '{blocus}', p_blocus, true) END;
  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now() WHERE id = v_id;
END $function$;

CREATE OR REPLACE FUNCTION public.blocus_pop_ajuster_interne(p_nom text, p_delta numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pop numeric;
BEGIN
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{pop}',
           to_jsonb(greatest(0, least(100, coalesce(nullif(resources->>'pop', '')::numeric, 50) + p_delta)))),
         updated_at = clock_timestamp()
   WHERE name = p_nom
  RETURNING (resources->>'pop')::numeric INTO v_pop;
  RETURN v_pop;
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Liste des blocus actifs d'un pays (syndicat : renouveler ; commissaire : intervenir).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocus_syndicaux_actifs(p_pays text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'country', e.country, 'city', e.city, 'buildingId', e.building_id,
           'syndicatId', b->>'syndicatId', 'syndicatNom', b->>'syndicatNom',
           'revendication', b->>'revendication', 'nbMilitants', (b->>'nbMilitants')::numeric,
           'intensite', (b->>'intensite')::numeric, 'leaderActuel', b->>'leaderActuel',
           'lanceLe', (b->>'lanceLe')::numeric,
           'dernierRenouvellementTimestamp', (b->>'dernierRenouvellementTimestamp')::numeric,
           'tauxDispersion', greatest(10, least(90, round(55 - coalesce((b->>'intensite')::numeric, 40) / 3))))
         ORDER BY e.city, e.building_id), '[]'::jsonb)
    FROM public.batiments_etat e
   CROSS JOIN LATERAL (SELECT public.blocus_actif_interne(e.country, e.city, e.building_id) AS b) a
   WHERE a.b IS NOT NULL
     AND e.country = coalesce(p_pays, (SELECT coalesce(country, 'republic')
                                         FROM public.personnages_donnees WHERE name = public.mon_personnage()));
$function$;

-- ---------------------------------------------------------------------------------------------
-- Organiser un blocus dans le bâtiment où l'on se tient.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocus_syndical_organiser(p_organisation text, p_militants integer, p_revendication text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_pays text; v_data jsonb;
  v_militants integer; v_n integer; v_puissance integer; v_taux integer; v_intensite integer;
  v_jet integer; v_ms bigint; v_rev text; v_blocus jsonb; v_ailleurs boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v_pays := coalesce(p.country, 'republic');
  IF p.current_building IS NULL OR p.current_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
                  WHERE pays = v_pays AND ville = p.current_city AND batiment = p.current_building) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'batiment_inconnu'); END IF;

  SELECT CASE WHEN left(btrim(coalesce(o.data, '')), 1) = '{' THEN o.data::jsonb END INTO v_data
    FROM public.organisations o WHERE o.id = p_organisation FOR UPDATE;
  IF v_data IS NULL OR coalesce(v_data->>'type', '') <> 'syndicale' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_introuvable'); END IF;
  IF NOT public.blocus_syndicat_dirigeant_interne(v_moi, v_data) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_secretaire_general'); END IF;

  SELECT count(*) INTO v_militants
    FROM public.pnj_militants_metier mm JOIN public.pnj_membres pm ON pm.id = mm.pnj_id
   WHERE mm.organisation_id = p_organisation AND pm.statut = 'actif' AND pm.famille = 'militant';
  IF v_militants < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'militants_insuffisants', 'militants', v_militants); END IF;
  v_n := coalesce(p_militants, v_militants);
  IF v_n < 2 OR v_n > v_militants THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nombre_militants_invalide', 'militants', v_militants); END IF;

  PERFORM 1 FROM public.batiments_etat
   WHERE id = v_pays || '_' || p.current_city || '_' || p.current_building FOR UPDATE;
  IF public.blocus_actif_interne(v_pays, p.current_city, p.current_building) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_bloque'); END IF;

  SELECT EXISTS (SELECT 1 FROM public.batiments_etat e
                  WHERE e.country = v_pays
                    AND public.blocus_actif_interne(e.country, e.city, e.building_id)->>'syndicatId' = p_organisation)
    INTO v_ailleurs;
  v_puissance := greatest(0, least(100, v_militants * 3 + CASE WHEN v_ailleurs THEN 15 ELSE 0 END
                 + coalesce(nullif(v_data->>'blocusReussis', '')::int, 0) * 5
                 + coalesce(nullif(v_data->>'repressionsSubies', '')::int, 0) * 8));
  v_taux := least(90, 10 + 6 * v_n + round(v_puissance / 5.0)::int);
  v_intensite := least(90, 10 + 6 * v_n);
  v_jet := floor(random() * 100)::int + 1;
  IF v_jet > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet); END IF;

  v_rev := left(btrim(coalesce(p_revendication, '')), 280);
  IF v_rev = '' THEN v_rev := 'Revendications non précisées.'; END IF;
  v_ms := floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  v_blocus := jsonb_build_object('syndicatId', p_organisation,
    'syndicatNom', coalesce(v_data->>'nom', 'Syndicat'), 'revendication', v_rev,
    'nbMilitants', v_n, 'intensite', v_intensite, 'leaderActuel', v_moi,
    'lanceLe', v_ms, 'dernierRenouvellementTimestamp', v_ms);
  PERFORM public.blocus_ecrire_interne(v_pays, p.current_city, p.current_building, v_blocus);

  UPDATE public.organisations
     SET data = jsonb_set(v_data, '{blocusReussis}',
                  to_jsonb(coalesce(nullif(v_data->>'blocusReussis', '')::int, 0) + 1))::text
   WHERE id = p_organisation;

  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet,
    'intensite', v_intensite, 'blocus', v_blocus,
    'city', p.current_city, 'buildingId', p.current_building);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Renouveler un blocus de son syndicat (menu du personnage, sans être sur place).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocus_syndical_renouveler(p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_blocus jsonb; v_data jsonb; v_ms bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM 1 FROM public.batiments_etat WHERE id = v_pays || '_' || p_ville || '_' || p_batiment FOR UPDATE;
  v_blocus := public.blocus_actif_interne(v_pays, p_ville, p_batiment);
  IF v_blocus IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_blocus'); END IF;
  SELECT CASE WHEN left(btrim(coalesce(o.data, '')), 1) = '{' THEN o.data::jsonb END INTO v_data
    FROM public.organisations o WHERE o.id = v_blocus->>'syndicatId';
  IF v_data IS NULL OR NOT public.blocus_syndicat_dirigeant_interne(v_moi, v_data) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_secretaire_general'); END IF;
  v_ms := floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  v_blocus := v_blocus || jsonb_build_object('dernierRenouvellementTimestamp', v_ms, 'leaderActuel', v_moi);
  PERFORM public.blocus_ecrire_interne(v_pays, p_ville, p_batiment, v_blocus);
  RETURN jsonb_build_object('ok', true, 'blocus', v_blocus);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Faire intervenir les forces de l'ordre (commissaire de la ville, depuis son bureau).
-- p_mode : 'disperser' (jet de dispersion) ou 'reprimer' (manière forte : le blocus tient et le
-- syndicat en sort renforcé). 2 PA, coût de « mobiliser_police ».
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocus_syndical_intervenir(p_ville text, p_batiment text, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_pays text; v_blocus jsonb; v_pay jsonb;
  v_taux integer; v_jet integer; v_intensite numeric; v_pop numeric; v_data jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_mode NOT IN ('disperser', 'reprimer') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_inconnu'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi;
  v_pays := coalesce(p.country, 'republic');
  IF (p.poste->>'id') IS DISTINCT FROM 'commissaire' OR (p.poste->>'city') IS DISTINCT FROM p_ville THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_commissaire'); END IF;
  IF p.current_city IS DISTINCT FROM p_ville
     OR p.current_building NOT IN ('commissariat', 'commissariat-local')
     OR p.current_room IS DISTINCT FROM 'bureau_commissaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'depuis_bureau_commissaire'); END IF;

  PERFORM 1 FROM public.batiments_etat WHERE id = v_pays || '_' || p_ville || '_' || p_batiment FOR UPDATE;
  v_blocus := public.blocus_actif_interne(v_pays, p_ville, p_batiment);
  IF v_blocus IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_blocus'); END IF;
  IF p_mode = 'reprimer' AND public.blocus_police_en_greve_interne(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'police_en_greve'); END IF;

  v_pay := public.payer_ordre(v_moi, 'mobiliser_police', 2, 0);
  IF coalesce((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  v_intensite := coalesce(nullif(v_blocus->>'intensite', '')::numeric, 40);

  IF p_mode = 'reprimer' THEN
    SELECT CASE WHEN left(btrim(coalesce(o.data, '')), 1) = '{' THEN o.data::jsonb END INTO v_data
      FROM public.organisations o WHERE o.id = v_blocus->>'syndicatId' FOR UPDATE;
    IF v_data IS NOT NULL THEN
      UPDATE public.organisations
         SET data = jsonb_set(v_data, '{repressionsSubies}',
                      to_jsonb(coalesce(nullif(v_data->>'repressionsSubies', '')::int, 0) + 1))::text
       WHERE id = v_blocus->>'syndicatId';
    END IF;
    v_pop := public.blocus_pop_ajuster_interne(v_moi, -15);
    RETURN jsonb_build_object('ok', true, 'mode', 'reprimer', 'leve', false, 'isn', 10, 'pop_delta', -15,
      'pop', v_pop, 'paiement', v_pay);
  END IF;

  v_taux := greatest(10, least(90, round(55 - v_intensite / 3)::int));
  v_jet := floor(random() * 100)::int + 1;
  IF v_jet > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'mode', 'disperser', 'leve', false, 'taux', v_taux, 'jet', v_jet,
      'paiement', v_pay);
  END IF;
  PERFORM public.blocus_ecrire_interne(v_pays, p_ville, p_batiment, NULL);
  v_pop := public.blocus_pop_ajuster_interne(v_moi, -8);
  IF nullif(v_blocus->>'leaderActuel', '') IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Police', v_blocus->>'leaderActuel', 'Blocus dispersé',
      'Les forces de l''ordre ont dispersé votre blocus. Vos militants restent employés, libre à vous de les renvoyer ou de retenter ailleurs.',
      NULL);
  END IF;
  RETURN jsonb_build_object('ok', true, 'mode', 'disperser', 'leve', true, 'taux', v_taux, 'jet', v_jet,
    'isn', 8, 'pop_delta', -8, 'pop', v_pop, 'paiement', v_pay);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- La nuit (appelées par le cron, rôle service uniquement).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocus_nuit_expirer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT e.country, e.city, e.building_id, public.batiment_etat_lire(e.data)->'blocus' AS b
      FROM public.batiments_etat e
     WHERE jsonb_typeof(public.batiment_etat_lire(e.data)->'blocus') IN ('object', 'null')
       AND public.blocus_actif_interne(e.country, e.city, e.building_id) IS NULL
  LOOP
    PERFORM public.blocus_ecrire_interne(r.country, r.city, r.building_id, NULL);
    IF jsonb_typeof(r.b) = 'object' THEN
      v_n := v_n + 1;
      IF nullif(r.b->>'leaderActuel', '') IS NOT NULL THEN
        PERFORM public.mail_systeme_poser_interne(coalesce(r.b->>'syndicatNom', 'Syndicat'),
          r.b->>'leaderActuel', 'Blocus levé', 'Faute de renouvellement, le blocus a été levé.', NULL);
      END IF;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'leves', v_n);
END $function$;

CREATE OR REPLACE FUNCTION public.blocus_nuit_effets()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_maire text; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT e.country, e.city, a.b FROM public.batiments_etat e
     CROSS JOIN LATERAL (SELECT public.blocus_actif_interne(e.country, e.city, e.building_id) AS b) a
     WHERE a.b IS NOT NULL
  LOOP
    SELECT name INTO v_maire FROM public.personnages_donnees
     WHERE coalesce(country, 'republic') = r.country AND poste->>'id' = 'maire' AND poste->>'city' = r.city
     LIMIT 1;
    IF v_maire IS NOT NULL THEN
      PERFORM public.blocus_pop_ajuster_interne(v_maire,
        -greatest(1, round(coalesce(nullif(r.b->>'intensite', '')::numeric, 40) / 15)));
      v_n := v_n + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'appliques', v_n);
END $function$;

-- ---------------------------------------------------------------------------------------------
-- Les portes existantes tiennent le blocus (patchs vérifiés, idempotents).
-- ---------------------------------------------------------------------------------------------
DO $blocus$
DECLARE f text; ancien text; nouveau text;
BEGIN
  -- (a) L'écran ne peut plus écrire la sous-clé « blocus ».
  f := pg_get_functiondef('public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)'::regprocedure);
  IF position('blocus_syndical_v1' IN f) = 0 THEN
    ancien := 'v_serveur := public.est_appel_serveur();';
    nouveau := ancien || E'\n  IF p_sous_cle = ''blocus'' AND NOT v_serveur THEN -- blocus_syndical_v1\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''commande_serveur_requise'');\n  END IF;';
    IF (length(f) - length(replace(f, ancien, ''))) / length(ancien) <> 1 THEN
      RAISE EXCEPTION 'blocus_sous_cle_definition_non_examinee'; END IF;
    EXECUTE replace(f, ancien, nouveau);
  END IF;

  -- (b) Bâtiment bloqué : première pièce seulement.
  f := pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
  IF position('blocus_syndical_v1' IN f) = 0 THEN
    ancien := ' IF EXISTS(SELECT 1 FROM public.batiments_fermes f WHERE';
    nouveau := E' -- blocus_syndical_v1\n IF p_batiment IS NOT NULL AND p_piece IS DISTINCT FROM (l.pieces->>0)'
      || E' AND public.blocus_actif_interne(p.country,p.current_city,p_batiment) IS NOT NULL THEN\n'
      || E'  RETURN jsonb_build_object(''ok'',false,''raison'',''blocus_syndical''); END IF;\n' || ancien;
    IF (length(f) - length(replace(f, ancien, ''))) / length(ancien) <> 1 THEN
      RAISE EXCEPTION 'blocus_navigation_definition_non_examinee'; END IF;
    EXECUTE replace(f, ancien, nouveau);
  END IF;

  -- (c) Ordres du bâtiment refusés, à la porte commune des ordres payants.
  f := pg_get_functiondef('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure);
  IF position('blocus_syndical_v1' IN f) = 0 THEN
    ancien := 'PERFORM public.exiger_acteur(p_acteur);';
    nouveau := ancien || E'\n  IF public.blocus_ordre_refuse_interne(p_acteur, v_fn) THEN -- blocus_syndical_v1\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''blocus_syndical'', ''fn'', v_fn);\n  END IF;';
    IF (length(f) - length(replace(f, ancien, ''))) / length(ancien) <> 1 THEN
      RAISE EXCEPTION 'blocus_paiement_definition_non_examinee'; END IF;
    EXECUTE replace(f, ancien, nouveau);
  END IF;
END $blocus$;

-- ---------------------------------------------------------------------------------------------
-- Droits.
-- ---------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.blocus_actif_interne(text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_ordre_refuse_interne(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_syndicat_dirigeant_interne(text,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_police_en_greve_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_ecrire_interne(text,text,text,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_pop_ajuster_interne(text,numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_nuit_expirer() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.blocus_nuit_effets() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.blocus_nuit_expirer() TO service_role;
GRANT EXECUTE ON FUNCTION public.blocus_nuit_effets() TO service_role;
REVOKE ALL ON FUNCTION public.blocus_syndicaux_actifs(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.blocus_syndical_organiser(text,integer,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.blocus_syndical_renouveler(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.blocus_syndical_intervenir(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocus_syndicaux_actifs(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.blocus_syndical_organiser(text,integer,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.blocus_syndical_renouveler(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.blocus_syndical_intervenir(text,text,text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- Catalogue des ordres par bâtiment (outils/generateurs/generer_blocus_ordres_batiments.py).
-- ---------------------------------------------------------------------------------------------
-- Source : outils/audits/AUDIT-GLOBAL-REPUBLIA-20261102.json (commit a99c406928ec7449f7dc11f5a447177c59b5452b), 961 ordres.
INSERT INTO public.blocus_ordres_batiments (pays, ville, batiment, fn)
SELECT 'republic', x.v, x.b, unnest(string_to_array(x.f, ' ')) FROM (VALUES
('capitale','armurerie','acheter_gilet choisir_arme consulter_registre_armes marche_noir produire_arme vendre_matiere_commerce'),
('capitale','assemblee','amender_projet calendrier_elections consulter_lobbyiste ecouter_rumeurs marchander_vote observer_debats projet_loi registre_assemblee reveiller_depute seance_parlementaire voter_loi'),
('capitale','banque-nationale','emprunter gerer_finances gerer_local louer_local presenter_autorisation_coffre virement_automatique virement_joueur'),
('capitale','banque-privee','blanchiment compte_offshore emprunter_prive gerer_finances societe_ecran'),
('capitale','bureau-national-emploi','bne_passer_annonce consulter_offres_emploi'),
('capitale','centre-affaires','embaucher_agent_securite embaucher_maitre_chien gerer_local installer_equipements louer_local se_renseigner'),
('capitale','centre-artisanal','commerce_pj gerer_local louer_local se_renseigner'),
('capitale','centre-commercial','commerce_pj gerer_local louer_local se_renseigner'),
('capitale','centre-multinodal-luthecia','aller_douanes_aeroport corrompre_douanier passer_douanes_aeroport prendre_avion prendre_bus_taxi prendre_train taxi_caserne taxi_qhs'),
('capitale','clinique-privee','centre_anti_poison gerer_visites_chambre ouvrir_chambres_clinique repas_clinique soins soins_discrets soins_urgence sortie_hopital vendre_ressource_medicale'),
('capitale','commissariat','archives_police arreter dossiers_plaintes gerer_effectifs_police mener_enquete organiser_chasse_homme organiser_filature plainte_police recruter_policier recruter_policier_cynophile se_justifier se_rebeller temoin_deposition tentative_evasion'),
('capitale','dispensaire-public','centre_anti_poison repas_hopital soin_public sortie_hopital transfert_clinique_privee vendre_ressource_medicale'),
('capitale','entrepot-logistique-luthecia','acheter_ressources_entrepot fixer_prix_achat_entrepot tableau_bord_entrepot'),
('capitale','hotel-republica','choisir_suite consulter_carte_commerce diner_affaires dormir_chambre ecouter_rumeurs escort_piege gerer_commerce gerer_local lancer_rumeur_cible louer_local offrir_tournee produire_commerce recruter_informateur_pnj reserver_chambre_hotel service_etage vendre_matiere_commerce'),
('capitale','la-tribune','article consulter_archives_presse corrompre_journaliste deposer_petite_annonce etouffer fabriquer_scandale imprimer_tracts_choix interview produire_fuite publicite_premium vendre_bois_imprimerie'),
('capitale','loge-maconnique','consulter_info_4 deliberer_loge demander_parler_loge gerer_informateurs recruter_info_4 recruter_informateur_2'),
('capitale','mairie-capitale','acte_officiel_mairie bourrer_urnes calendrier_elections campagne_securite consulter_dossiers_urbanisme consulter_elections consulter_etat_civil consulter_mandats_maires consulter_organigramme_mairie contester_resultats demander_logement_social etat_civil falsifier_listes_electorales financer_communal fixer_impots_locaux nominations_municipales objet_trouve repartition_budget_local subvention_proposer traiter_demandes_logement_social traiter_demandes_permis truquer_depouillement voter_election'),
('capitale','marche','faire_achats_marche lancer_rumeur_cible pouls_populaire produire_commerce vendre_matiere_commerce'),
('capitale','musee-national-republia','consulter_personnalites_musee'),
('capitale','office-notarial','acte_officiel_notaire acte_rachat_entreprise_preemption commerces_fonds_murs consulter_archives_notariales consulter_dossier_notarial demander_divorce gerer_testament officialiser_transaction racheter_entreprise reclamer_heritage transfert_compromis'),
('capitale','palais-gouvernement','activer_cessez_le_feu bne_caisse_prelever censurer_media commanditer_sondage conference_presse consulter_dossiers_gouv declencher_vote_confiance demandes_naturalisation dementi diplomatie_bilaterale fuite_info garde_republicaine gerer_ambassades gerer_budget_interieur gerer_budget_justice gerer_chef_douanes gerer_couvre_feu gerer_juges gestion_caserne gestion_industrielle_portuaire gestion_manifestations gestion_qhs lois_votees_an mobilisation_nationale nommer_ministre_pm ouvrir_enquete pilotage_fiscal_budgetaire postuler preempter_entreprise propagande_etat proposer_grace proposer_treve renseignement_militaire revoquer_ministre_pm subvention subvention_min_int'),
('capitale','palais-presidentiel','adresse_a_la_nation banquet_diplo conference_presse dementi effort_national gestion_premier_ministre gracier postes_par_decret pouvoirs_exceptionnels propagande_etat reception_etat solliciter_audience_president'),
('capitale','place-formulaire-liberte','organiser_manifestation_spontanee'),
('capitale','quartier-ambassades','demander_asile_politique demander_audience_ambassadeur demander_transfert_detenu financer_oeuvre_culturelle organiser_reception_diplomatique relations_bilaterales reserver_salle_reception'),
('capitale','stade','acheter_accessoire_personnalise annuler_non_renouvellement_licence choisir_accessoire_club conseil_entraineur_adjoint consommer_buvette consulter_budget_club consulter_bureau_president consulter_carte_commerce consulter_classement_joueurs_club consulter_organigramme_supporters consulter_palmares declencher_election_club demander_non_renouvellement_licence gerer_offres_transfert gerer_salaires_club observer_match organiser_boycott organiser_manifestation parier_match postuler_president_club prendre_licence_sportive produire_commerce proposer_transfert regarder_live rejoindre_club_supporters sponsoriser_club tenue_entrainement tenue_match vendre_matiere_commerce'),
('capitale','tabernacle-impots','faire_don prier'),
('capitale','terrain-a-batir-1','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('capitale','terrain-a-batir-2','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('capitale','terrain-a-batir-3','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('capitale','terrain-a-batir-4','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('capitale','terrain-a-batir-5','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('capitale','tribunal','acte_officiel_juge archives audience_juge audience_salle avocat_barreau avocat_dossiers casier_extrait_enquete casier_mon_extrait defense demander_juge_instruction falsifier_document greffe_affaires greffe_archives greffe_corrompre_dossier greffe_corrompre_faux_casier orga_extrait_duplicata parquet rendre_sentence temoins_mes_convocations'),
('capitale','universite','donner_conf recruter_etud suivre_formation syndicat_etudiant_creer syndicat_etudiant_gerer'),
('capitale','usine-pharmaceutique-luthecia','acheter_sels_ammoniaque fixer_prix_vente_directe fixer_repartition_production produire_desinfectant produire_medicaments vendre_matiere_usine vente_directe_usine virement_usine_ministere'),
('ville_a','banque-locale','emprunter gerer_finances virement_automatique virement_joueur'),
('ville_a','bar-des-pecheurs','consulter_carte_commerce ecouter_rumeurs gerer_commerce lancer_rumeur_cible offrir_tournee produire_commerce recruter_informateur_pnj vendre_matiere_commerce'),
('ville_a','capitaine-sauvage','consulter_carte_commerce diner_affaires ecouter_rumeurs gerer_commerce lancer_rumeur_cible produire_commerce vendre_matiere_commerce'),
('ville_a','centre-affaires','article bne_passer_annonce consulter_archives_presse consulter_offres_emploi corrompre_journaliste deposer_petite_annonce etouffer fabriquer_scandale gerer_local installer_equipements interview louer_local produire_fuite publicite_premium se_renseigner'),
('ville_a','centre-artisanal','commerce_pj gerer_local louer_local se_renseigner'),
('ville_a','centre-commercial','commerce_pj gerer_local louer_local se_renseigner'),
('ville_a','centre-multinodal-port-sainte-marie','prendre_bus_taxi prendre_train'),
('ville_a','chasse-peche-psm','acheter_gilet choisir_arme consulter_registre_armes marche_noir produire_arme vendre_matiere_commerce'),
('ville_a','commissariat-local','archives_police arreter dossiers_plaintes gerer_effectifs_police mener_enquete organiser_chasse_homme organiser_filature plainte_police recruter_policier recruter_policier_cynophile se_justifier se_rebeller temoin_deposition tentative_evasion'),
('ville_a','dispensaire-public-v','centre_anti_poison repas_hopital soin_public sortie_hopital transfert_clinique_privee vendre_ressource_medicale'),
('ville_a','entrepot-logistique-psm','acheter_ressources_entrepot fixer_prix_achat_entrepot tableau_bord_entrepot'),
('ville_a','hotel-port','consulter_carte_commerce dormir_chambre gerer_commerce produire_commerce reserver_chambre_hotel service_etage vendre_matiere_commerce'),
('ville_a','imprimerie-librairie','imprimer_tracts_calomnieux imprimer_tracts_electoraux vendre_bois_imprimerie'),
('ville_a','mairie','acte_officiel_mairie bourrer_urnes calendrier_elections campagne_securite consulter_dossiers_urbanisme consulter_elections consulter_etat_civil consulter_mandats_maires consulter_organigramme_mairie contester_resultats demander_logement_social etat_civil falsifier_listes_electorales financer_communal fixer_impots_locaux nominations_municipales objet_trouve repartition_budget_local subvention_proposer traiter_demandes_logement_social traiter_demandes_permis truquer_depouillement voter_election'),
('ville_a','marche-psm','faire_achats_marche lancer_rumeur_cible pouls_populaire produire_commerce vendre_matiere_commerce'),
('ville_a','musee-port-sainte-marie','consulter_personnalites_musee'),
('ville_a','notre-dame-mer','faire_don prier'),
('ville_a','place-armes-psm','organiser_manifestation_spontanee'),
('ville_a','pole-tabac-alcools-psm','fixer_prix_vente_directe fixer_repartition_production produire_alcool produire_tabac vendre_matiere_usine vente_directe_usine virement_usine_ministere'),
('ville_a','port-sainte-marie','acheter_criee blocus_portuaire consulter_administration_port consulter_effectifs_douane consulter_manifeste consulter_organigramme_syndicat controler_caisse_douane declencher_election_syndicat expedier_colis gerer_box gerer_effectifs_douane gerer_logistique_port inspecter_cargaisons louer_box marchandises_non_reclamees organiser_manifestation_syndicat prendre_bateau receptionner_commande recruter_douanier recruter_douanier_cynophile se_syndiquer'),
('ville_a','stade','acheter_accessoire_personnalise annuler_non_renouvellement_licence choisir_accessoire_club conseil_entraineur_adjoint consommer_buvette consulter_budget_club consulter_bureau_president consulter_carte_commerce consulter_classement_joueurs_club consulter_organigramme_supporters consulter_palmares declencher_election_club demander_non_renouvellement_licence gerer_offres_transfert gerer_salaires_club observer_match organiser_boycott organiser_manifestation parier_match postuler_president_club prendre_licence_sportive produire_commerce proposer_transfert regarder_live rejoindre_club_supporters sponsoriser_club tenue_entrainement tenue_match vendre_matiere_commerce'),
('ville_a','terrain-a-batir-10','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_a','terrain-a-batir-11','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_a','terrain-a-batir-8','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_a','terrain-a-batir-9','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_a','tribunal-local','acte_officiel_juge archives audience_juge audience_salle avocat_barreau avocat_dossiers casier_extrait_enquete casier_mon_extrait defense falsifier_document greffe_affaires greffe_archives greffe_corrompre_dossier greffe_corrompre_faux_casier orga_extrait_duplicata parquet rendre_sentence temoins_mes_convocations'),
('ville_a','zone-production','acheter_armoire_souvenirs consulter_caisse_usine consulter_stock_usine fabriquer_armoire_souvenirs vendre_matiere_usine'),
('ville_b','armurerie','acheter_gilet choisir_arme consulter_registre_armes marche_noir produire_arme vendre_matiere_commerce'),
('ville_b','banque-locale','emprunter gerer_finances virement_automatique virement_joueur'),
('ville_b','brasserie-voyageurs-montrouge','consulter_carte_commerce gerer_commerce lancer_rumeur_cible produire_commerce vendre_matiere_commerce'),
('ville_b','cafe-gare-montrouge','consulter_carte_commerce gerer_commerce lancer_rumeur_cible offrir_tournee produire_commerce vendre_matiere_commerce'),
('ville_b','cafe-tabac-cheminots-montrouge','consulter_carte_commerce gerer_commerce lancer_rumeur_cible offrir_tournee produire_commerce vendre_matiere_commerce'),
('ville_b','centre-affaires','article bne_passer_annonce consulter_archives_presse consulter_offres_emploi corrompre_journaliste deposer_petite_annonce etouffer fabriquer_scandale gerer_local installer_equipements interview louer_local produire_fuite publicite_premium se_renseigner'),
('ville_b','centre-artisanal','commerce_pj gerer_local louer_local se_renseigner'),
('ville_b','centre-commercial','commerce_pj gerer_local louer_local se_renseigner'),
('ville_b','centre-multinodal-montrouge','prendre_bus_taxi prendre_train'),
('ville_b','commissariat-local','archives_police arreter dossiers_plaintes gerer_effectifs_police mener_enquete organiser_chasse_homme organiser_filature plainte_police recruter_policier recruter_policier_cynophile se_justifier se_rebeller temoin_deposition tentative_evasion'),
('ville_b','dispensaire-public-v','centre_anti_poison repas_hopital soin_public sortie_hopital transfert_clinique_privee vendre_ressource_medicale'),
('ville_b','eglise-montrouge','faire_don prier'),
('ville_b','entrepot-logistique-montrouge','acheter_ressources_entrepot fixer_prix_achat_entrepot tableau_bord_entrepot'),
('ville_b','hotel-mineur','consulter_carte_commerce dormir_chambre gerer_commerce produire_commerce reserver_chambre_hotel service_etage vendre_matiere_commerce'),
('ville_b','jardins-ouvriers-montrouge','laisser_legumes_jardins prendre_legumes_jardins travailler_jardins'),
('ville_b','la-tribune','consulter_archives_presse corrompre_journaliste fabriquer_scandale imprimer_tracts_calomnieux imprimer_tracts_electoraux interview produire_fuite publicite_premium vendre_bois_imprimerie'),
('ville_b','loge-maconnique','consulter_info_4 deliberer_loge demander_parler_loge gerer_informateurs recruter_info_4 recruter_informateur_2'),
('ville_b','logements-montrouge','gerer_logement_social'),
('ville_b','mairie','acte_officiel_mairie bourrer_urnes calendrier_elections campagne_securite consulter_dossiers_urbanisme consulter_elections consulter_etat_civil consulter_mandats_maires consulter_organigramme_mairie contester_resultats demander_logement_social etat_civil falsifier_listes_electorales financer_communal fixer_impots_locaux nominations_municipales objet_trouve repartition_budget_local subvention_proposer traiter_demandes_logement_social traiter_demandes_permis truquer_depouillement voter_election'),
('ville_b','marche','faire_achats_marche lancer_rumeur_cible pouls_populaire produire_commerce vendre_matiere_commerce'),
('ville_b','musee-histoire-montrouge','consulter_personnalites_musee'),
('ville_b','place-du-rail-montrouge','organiser_manifestation_spontanee'),
('ville_b','raffinerie-montrouge','fixer_prix_vente_directe fixer_repartition_production produire_carburant vendre_matiere_usine vente_directe_usine virement_usine_ministere'),
('ville_b','siege-syndical','mobiliser'),
('ville_b','stade','acheter_accessoire_personnalise annuler_non_renouvellement_licence choisir_accessoire_club conseil_entraineur_adjoint consommer_buvette consulter_budget_club consulter_bureau_president consulter_carte_commerce consulter_classement_joueurs_club consulter_organigramme_supporters consulter_palmares declencher_election_club demander_non_renouvellement_licence gerer_offres_transfert gerer_salaires_club observer_match organiser_boycott organiser_manifestation parier_match postuler_president_club prendre_licence_sportive produire_commerce proposer_transfert regarder_live rejoindre_club_supporters sponsoriser_club tenue_entrainement tenue_match vendre_matiere_commerce'),
('ville_b','terrain-a-batir-6','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_b','terrain-a-batir-montrouge-12','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_b','terrain-a-batir-montrouge-3','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_b','terrain-a-batir-montrouge-7','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_b','terrain-a-batir-montrouge-8','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_b','terrain-a-batir-montrouge-9','acheter_terrain appeler_police_terrain construire_sur_terrain corrompre_fonctionnaire_permis corrompre_rdv_notaire diviser_construction emprunter_construction faire_disparaitre_cadavre gerer_fonds_commerce gerer_lot_loue louer_lot_ici modifier_plan_chantier negocier_squatteurs payer_versement_chantier racheter_terrain reconfigurer_lots signer_compromis travailler_chantier vendre_materiaux_chantier voler_materiel_chantier'),
('ville_b','tribunal-local','acte_officiel_juge archives audience_juge audience_salle avocat_barreau avocat_dossiers casier_extrait_enquete casier_mon_extrait defense falsifier_document greffe_affaires greffe_archives greffe_corrompre_dossier greffe_corrompre_faux_casier orga_extrait_duplicata parquet rendre_sentence temoins_mes_convocations'),
('ville_b','usine-principale','acheter_entreprise'),
('ville_b','zone-production','recolter_matiere')
) AS x(v, b, f)
ON CONFLICT DO NOTHING;
