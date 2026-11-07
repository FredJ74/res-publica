-- Pouvoir en Sovarka, étapes 3 et 4 (Fred, 07/11/2026, GAME-DESIGN-NOVOMIRSK.md).
--
-- 1. Cycles de Sovarka : présidentielle et municipales (aucun n'existait), plus le cycle
--    `gloire_partis` de la semaine à la gloire des partis, au même calendrier que la
--    présidentielle (cloné du calendrier d'El Estado, mêmes dates que la Républia).
-- 2. Les partis recrutent leurs partisans PNJ avec les tracts, mécanique du vote de Républia :
--    la cible d'un tract « gloire » est le NOM du parti ; les candidats du cycle sont les
--    partis de Sovarka, resynchronisés chaque nuit (sovarka_gloire_synchroniser).
-- 3. Décompte à la proclamation (sovarka_gloire_proclamer, appelé par la passe de minuit) :
--    adhérents PJ + partisans PNJ ; égalité : le plus d'adhérents PJ, puis le plus ancien.
--    Sièges du Soviet Suprême (9) à la proportionnelle des partisans (plus forts restes).
-- 4. Le chef du parti vainqueur devient d'office Président du Conseil du Peuple (pm) ; tant
--    qu'un parti a gagné, le président ne nomme pas le pm ; les ministres sont nommés parmi
--    les membres du parti du pm. Aucun parti vainqueur : le président nomme librement.

-- ---------------------------------------------------------------- 1. cycles
INSERT INTO public.cycles_electoraux (id, country, poste_id, city, data, updated_at)
SELECT 'soviet_' || x.poste || CASE WHEN x.ville IS NULL THEN '' ELSE '_' || x.ville END,
       'soviet', x.poste, x.ville,
       ((src.data::jsonb - 'dernierScrutin' - 'dernierResultatTs' - 'dateDebutMandatTs' - 'indicateursDebutMandat')
         || jsonb_build_object('city', x.ville, 'posteId', x.poste, 'eluId', NULL, 'candidats', '[]'::jsonb,
                               'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb, 'tour', 1,
                               'resultatsTraites', false))::text,
       now()
  FROM (VALUES ('president', NULL::text), ('gloire_partis', NULL),
               ('maire', 'capitale'), ('maire', 'ville_a'), ('maire', 'ville_b')) AS x(poste, ville)
  JOIN public.cycles_electoraux src ON src.id = 'narco_president'
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------- 2. partis et tracts
-- Candidats du cycle de la gloire = partis de Sovarka (nom affiché, identifiant, chef).
CREATE OR REPLACE FUNCTION public.sovarka_gloire_synchroniser()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_partis jsonb; v_n integer;
BEGIN
  SELECT coalesce(jsonb_agg(jsonb_build_object('nom', o.data::jsonb ->> 'nom', 'partiId', o.id,
                                               'chef', o.data::jsonb ->> 'chef', 'voix', 0)
                            ORDER BY o.created_at), '[]'::jsonb)
    INTO v_partis
    FROM public.organisations o
   WHERE o.data::jsonb ->> 'type' = 'politique'
     AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = 'soviet'
     AND coalesce(o.data::jsonb ->> 'nom', '') <> '';
  UPDATE public.cycles_electoraux
     SET data = jsonb_set(data::jsonb, '{candidats}', v_partis)::text, updated_at = now()
   WHERE id = 'soviet_gloire_partis'
     AND (data::jsonb -> 'candidats') IS DISTINCT FROM v_partis;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'partis', jsonb_array_length(v_partis), 'modifie', v_n = 1);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_gloire_synchroniser() FROM PUBLIC, anon, authenticated;
SELECT public.sovarka_gloire_synchroniser();

-- Les tracts acceptent le scrutin de la gloire (tout le reste de la mécanique est inchangé).
DO $patch$
DECLARE v_source text;
  v_avant text := $a$NOT IN ('president', 'maire', 'depute') THEN$a$;
  v_apres text := $a$NOT IN ('president', 'maire', 'depute', 'gloire_partis') THEN$a$;
BEGIN
  SELECT pg_get_functiondef('public.tracts_electoraux_distribuer_interne(text,text,text,text,text,text,integer,timestamp with time zone)'::regprocedure)
    INTO v_source;
  IF v_source IS NULL OR strpos(v_source, v_avant) = 0 THEN
    RAISE EXCEPTION 'tracts_electoraux_distribuer_interne_version_inattendue';
  END IF;
  EXECUTE replace(v_source, v_avant, v_apres);
END $patch$;

-- ---------------------------------------------------------------- 3 et 4. décompte, pm
-- Parti vainqueur de la dernière semaine à la gloire, s'il existe encore.
CREATE OR REPLACE FUNCTION public.sovarka_gloire_vainqueur()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT o.id FROM public.cycles_electoraux c
    JOIN public.organisations o ON o.id = c.data::jsonb -> 'gloire' ->> 'vainqueur'
   WHERE c.id = 'soviet_gloire_partis';
$$;
REVOKE ALL ON FUNCTION public.sovarka_gloire_vainqueur() FROM PUBLIC, anon, authenticated;

-- Refus d'une nomination en Sovarka, NULL si elle est permise.
CREATE OR REPLACE FUNCTION public.sovarka_nomination_refus(p_poste text, p_titulaire text, p_source text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_pm text; v_parti_pm text;
BEGIN
  IF coalesce(p_source, '') IN ('sovarka_gloire') OR coalesce(p_source, '') ILIKE 'restaur%' THEN
    RETURN NULL;
  END IF;
  IF p_poste = 'pm' AND public.sovarka_gloire_vainqueur() IS NOT NULL THEN
    RETURN 'pm_impose_par_le_parti';
  END IF;
  IF p_poste IN ('min_int','min_fin','min_just','min_def','min_info','min_ae') THEN
    SELECT titulaire INTO v_pm FROM public.postes_attribues WHERE id = 'soviet_pm_national';
    IF v_pm IS NULL THEN
      SELECT nom_pnj INTO v_pm FROM public.titulaires_pnj WHERE id = 'soviet_pm_national';
    END IF;
    v_parti_pm := CASE WHEN v_pm IS NULL THEN NULL ELSE public.sovarka_parti_de(v_pm) END;
    IF v_parti_pm IS NOT NULL AND public.sovarka_parti_de(p_titulaire) IS DISTINCT FROM v_parti_pm THEN
      RETURN 'ministre_hors_parti';
    END IF;
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_nomination_refus(text,text,text) FROM PUBLIC, anon, authenticated;

-- Garde dans les deux portes de nomination (joueur : poste_attribuer_interne ; PNJ : poste_nommer).
DO $patch$
DECLARE v_source text;
  v_ancre1 text := $a$  SELECT h.habilitation INTO v_hab FROM public.habilitations_postes h WHERE h.poste_id = p_poste;
$a$;
  v_ancre2 text := $a$    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent');
  END IF;
$a$;
BEGIN
  SELECT pg_get_functiondef('public.poste_attribuer_interne(text,text,text,text,text)'::regprocedure) INTO v_source;
  IF v_source IS NULL OR strpos(v_source, v_ancre1) = 0 OR strpos(v_source, 'sovarka_nomination_refus') > 0 THEN
    RAISE EXCEPTION 'poste_attribuer_interne_version_inattendue';
  END IF;
  EXECUTE replace(v_source, v_ancre1, $g$  -- Sovarka (Fred, 07/11/2026) : pm imposé par le parti vainqueur, ministres du parti du pm.
  IF p_pays = 'soviet' AND public.sovarka_nomination_refus(p_poste, p_titulaire, p_source) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', public.sovarka_nomination_refus(p_poste, p_titulaire, p_source));
  END IF;
$g$ || v_ancre1);

  SELECT pg_get_functiondef('public.poste_nommer(text,text,text)'::regprocedure) INTO v_source;
  IF v_source IS NULL OR strpos(v_source, v_ancre2) = 0 OR strpos(v_source, 'sovarka_nomination_refus') > 0 THEN
    RAISE EXCEPTION 'poste_nommer_version_inattendue';
  END IF;
  EXECUTE replace(v_source, v_ancre2, v_ancre2 || $g$  IF v_pays = 'soviet' AND public.sovarka_nomination_refus(p_poste, p_destinataire, NULL) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', public.sovarka_nomination_refus(p_poste, p_destinataire, NULL));
  END IF;
$g$);
END $patch$;

-- Décompte de la semaine à la gloire et chef du gouvernement d'office. Appelé par la passe de
-- minuit au dépouillement du cycle `soviet_gloire_partis`, AVANT la consignation unique du
-- cycle (election_resultats_consigner). Rejouable : même tour, même résultat, même titulaire.
CREATE OR REPLACE FUNCTION public.sovarka_gloire_proclamer(p_tour bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_scores jsonb; v_vainqueur record; v_total_partisans numeric; v_sieges jsonb := '{}'::jsonb;
  v_reste integer := 9; v_base numeric; v_pm jsonb := NULL; v_chef text; v_poste_chef text;
  v_r jsonb; v_ancien text;
BEGIN
  PERFORM public.sovarka_gloire_synchroniser();

  WITH partis AS (
    SELECT o.id, o.data::jsonb ->> 'nom' AS nom, o.data::jsonb ->> 'chef' AS chef, o.created_at,
           CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array' THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END AS membres
      FROM public.organisations o
     WHERE o.data::jsonb ->> 'type' = 'politique'
       AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = 'soviet'
  ), comptes AS (
    SELECT p.id, p.nom, p.chef, p.created_at,
           (SELECT count(DISTINCT d.name) FROM public.personnages_donnees d
             WHERE d.name = p.chef
                OR d.name IN (SELECT m ->> 'nom' FROM jsonb_array_elements(p.membres) m)) AS adherents_pj,
           greatest(coalesce((SELECT sum(t.effet) FROM public.elections_tracts_pnj t
                               WHERE t.cycle_id = 'soviet_gloire_partis' AND t.tour = p_tour
                                 AND t.candidat = p.nom), 0), 0) AS partisans_pnj
      FROM partis p
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('partiId', id, 'nom', nom, 'chef', chef,
                                               'adherentsPJ', adherents_pj, 'partisansPNJ', partisans_pnj,
                                               'total', adherents_pj + partisans_pnj, 'creeLe', created_at)
                            ORDER BY adherents_pj + partisans_pnj DESC, adherents_pj DESC, created_at ASC), '[]'::jsonb)
    INTO v_scores FROM comptes;

  IF jsonb_array_length(v_scores) = 0 OR ((v_scores -> 0 ->> 'total')::numeric) <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'vainqueur', NULL, 'scores', v_scores, 'sieges', '{}'::jsonb,
                              'pm', jsonb_build_object('attribue', false, 'raison', 'aucun_parti'));
  END IF;

  -- Sièges du Soviet Suprême : 9, plus forts restes sur les partisans PNJ ; si aucun partisan,
  -- sur le total (adhérents compris), pour ne pas laisser l'assemblée vide.
  SELECT sum((e ->> 'partisansPNJ')::numeric) INTO v_total_partisans FROM jsonb_array_elements(v_scores) e;
  WITH b AS (
    SELECT e ->> 'partiId' AS id,
           CASE WHEN v_total_partisans > 0 THEN (e ->> 'partisansPNJ')::numeric ELSE (e ->> 'total')::numeric END AS poids,
           (e ->> 'creeLe')::timestamptz AS cree
      FROM jsonb_array_elements(v_scores) e
  ), q AS (
    SELECT id, cree, poids * 9 / nullif(sum(poids) OVER (), 0) AS quota FROM b
  ), r AS (
    SELECT id, floor(quota)::integer AS base, quota - floor(quota) AS reste, cree FROM q
  ), rang AS (
    SELECT id, base, row_number() OVER (ORDER BY reste DESC, cree ASC) AS rg,
           9 - sum(base) OVER () AS restants FROM r
  )
  SELECT coalesce(jsonb_object_agg(id, base + CASE WHEN rg <= restants THEN 1 ELSE 0 END)
                    FILTER (WHERE base + CASE WHEN rg <= restants THEN 1 ELSE 0 END > 0), '{}'::jsonb)
    INTO v_sieges FROM rang;

  v_chef := v_scores -> 0 ->> 'chef';
  IF v_chef IS NULL OR v_chef = '' THEN
    v_pm := jsonb_build_object('attribue', false, 'raison', 'parti_sans_chef');
  ELSIF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_chef) THEN
    SELECT poste ->> 'id' INTO v_poste_chef FROM public.personnages_donnees WHERE name = v_chef;
    IF v_poste_chef IN ('president', 'maire') THEN
      v_pm := jsonb_build_object('attribue', false, 'raison', 'chef_deja_elu', 'chef', v_chef, 'poste', v_poste_chef);
    ELSE
      SELECT titulaire INTO v_ancien FROM public.postes_attribues WHERE id = 'soviet_pm_national';
      v_r := public.poste_attribuer_interne('soviet', 'pm', NULL, v_chef, 'sovarka_gloire');
      IF coalesce((v_r ->> 'ok')::boolean, false) THEN
        v_pm := jsonb_build_object('attribue', true, 'titulaire', v_chef, 'predecesseur', v_ancien);
        IF v_ancien IS DISTINCT FROM v_chef THEN
          PERFORM public.mail_systeme_envoyer('Système', v_chef, 'Président du Conseil du Peuple',
            'Votre parti, ' || (v_scores -> 0 ->> 'nom') || ', a remporté la semaine à la gloire des partis. '
            || 'Vous êtes désormais Président du Conseil du Peuple de Sovarka : il vous revient de nommer les ministres, '
            || 'uniquement parmi les membres de votre parti.');
          IF v_ancien IS NOT NULL THEN
            PERFORM public.mail_systeme_envoyer('Système', v_ancien, 'Fin de vos fonctions',
              'Le parti ' || (v_scores -> 0 ->> 'nom') || ' a remporté la semaine à la gloire des partis : '
              || v_chef || ' devient Président du Conseil du Peuple.');
          END IF;
        END IF;
      ELSE
        v_pm := jsonb_build_object('attribue', false, 'raison', coalesce(v_r ->> 'raison', 'refus'), 'chef', v_chef);
      END IF;
    END IF;
  ELSE
    -- Chef PNJ : prise de fonction immédiate, comme poste_nommer pour un PNJ.
    UPDATE public.personnages_donnees SET poste = NULL
     WHERE name = (SELECT titulaire FROM public.postes_attribues WHERE id = 'soviet_pm_national')
       AND poste ->> 'id' = 'pm';
    DELETE FROM public.postes_attribues WHERE id = 'soviet_pm_national';
    INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at)
    VALUES ('soviet_pm_national', 'soviet', 'pm', NULL, v_chef, now())
    ON CONFLICT (id) DO UPDATE SET nom_pnj = EXCLUDED.nom_pnj, updated_at = now();
    v_pm := jsonb_build_object('attribue', true, 'titulaire', v_chef, 'pnj', true);
  END IF;

  RETURN jsonb_build_object('ok', true, 'vainqueur', v_scores -> 0 ->> 'partiId',
                            'vainqueurNom', v_scores -> 0 ->> 'nom', 'scores', v_scores,
                            'sieges', v_sieges, 'pm', v_pm, 'tour', p_tour);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_gloire_proclamer(bigint) FROM PUBLIC, anon, authenticated;
