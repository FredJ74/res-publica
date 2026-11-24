-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture) — mission « Purge » du 24/11/2026, bloc D (climat), point D.1 (consigne de Fred) :
-- « La canicule n'a lieu qu'en journée (typiquement de 12 h à 18 h). »
-- • Réglage MJ aliments_parametres.canicule_heure_debut = 12 (heure de Paris) ; la durée reste climat_parametres.duree_heures
--   (6 h) : 12 h → 18 h.
-- • climat_canicule_debut_interne(t) : premier « 12 h à Paris » à partir de t (exact aux changements d'heure).
-- • climat_creer_interne : une canicule commence à 12 h le jour tiré, au lieu d'une heure au hasard (marque canicule_journee_v1) ;
--   les autres événements gardent leur heure au hasard (décision Q1 du 21/11).
-- • climat_espacer_interne : un report de canicule (un seul événement à la fois par pays) retombe aussi à 12 h (canicule_journee_v1).
-- • Canicules déjà planifiées, pas encore commencées : ramenées à 12 h le même jour ; si l'alerte était déjà publiée, une
--   correction est publiée au journal d'événements (comme les reports du 21/11).
-- Rejouable (marques, ON CONFLICT, garde sur l'heure). Aucune fonction commune, aucun objet du goulag.
BEGIN;
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('canicule_heure_debut', 12) ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_canicule_debut_interne(p_t timestamptz)
RETURNS timestamptz LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_h integer := public.aliments_param_interne('canicule_heure_debut', 12)::integer;
        v_j date := (p_t AT TIME ZONE 'Europe/Paris')::date; v_d timestamptz;
BEGIN
  v_d := (v_j::timestamp + make_interval(hours => v_h)) AT TIME ZONE 'Europe/Paris';
  IF v_d < p_t THEN v_d := ((v_j + 1)::timestamp + make_interval(hours => v_h)) AT TIME ZONE 'Europe/Paris'; END IF;
  RETURN v_d;
END $$;
REVOKE ALL ON FUNCTION public.climat_canicule_debut_interne(timestamptz) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

SELECT pg_temp.rp_remplacer('public.climat_creer_interne(text,text,text,date,text,text)'::regprocedure,
  $a$v_debut := public.climat_heure_hasard_interne(p_jour) /* climat_heure_hasard_v1 */;$a$,
  $b$v_debut := CASE WHEN p_type = 'canicule' THEN public.climat_canicule_debut_interne(public.climat_minuit_interne(p_jour))
                     ELSE public.climat_heure_hasard_interne(p_jour) END /* climat_heure_hasard_v1 */ /* canicule_journee_v1 */;$b$,
  1, 'canicule_journee_v1');

-- Espacement : l'épisode de canicule garde son heure de début (12 h) quand il est reporté.
SELECT pg_temp.rp_remplacer('public.climat_espacer_interne(text)'::regprocedure,
  $a$bool_and(type = 'brouillard') AS brouillard, count(*) AS n$a$,
  $b$bool_and(type = 'brouillard') AS brouillard, count(*) AS n, bool_and(type = 'canicule') AS canicule /* canicule_journee_v1a */$b$,
  1, 'canicule_journee_v1a');
SELECT pg_temp.rp_remplacer('public.climat_espacer_interne(text)'::regprocedure,
  $a$SELECT x INTO v_conflit FROM unnest(v_places)$a$,
  $b$IF r.canicule THEN v_debut := public.climat_canicule_debut_interne(v_debut); END IF; /* canicule_journee_v1 */
      SELECT x INTO v_conflit FROM unnest(v_places)$b$,
  1, 'canicule_journee_v1 */');

-- Canicules déjà planifiées et pas encore commencées : 12 h le même jour (heure de Paris), si cette heure est encore à venir.
WITH c AS (
  SELECT e.id, e.alerte_le, e.debut AS ancien,
         ((((e.debut AT TIME ZONE 'Europe/Paris')::date)::timestamp
           + make_interval(hours => public.aliments_param_interne('canicule_heure_debut', 12)::integer)) AT TIME ZONE 'Europe/Paris') AS nouveau
    FROM public.climat_evenements e
   WHERE e.type = 'canicule' AND NOT e.annule AND e.debut > now() AND e.effets_le IS NULL),
m AS (
  UPDATE public.climat_evenements e SET debut = c.nouveau, fin = c.nouveau + (e.fin - e.debut), debut_prevu = c.nouveau
    FROM c WHERE e.id = c.id AND c.nouveau <> c.ancien AND c.nouveau > now()
  RETURNING e.id, e.pays, e.ville, e.debut, c.ancien, c.alerte_le)
INSERT INTO public.evenements_globaux (country, city, texte, jour)
SELECT m.pays, m.ville, '⚠️ Prévisions corrigées : la canicule annoncée à ' || public.climat_nom_ville_interne(m.pays, m.ville) || ', '
       || public.climat_quand_interne(m.ancien) || ', commencera ' || public.climat_quand_interne(m.debut)
       || ' : la canicule ne frappe qu''en journée, de 12 h à 18 h.', NULL
  FROM m WHERE m.alerte_le IS NOT NULL;
COMMIT;
