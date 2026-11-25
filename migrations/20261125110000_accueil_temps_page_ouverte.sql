-- Mission de nuit du 25/11/2026 (Claude), bloc 2 — APPLIQUÉE en production le 25/11/2026 (feu vert de Fred, contrôlée en lecture).
-- Temps de jeu du calendrier d'accueil (A.3) : la page restée ouverte compte.
--
-- Constat (Han Watta Tsé, créé le 24/11 à 19 h 33 UTC à Novomirsk, sur téléphone Android) : 484 s de jeu à 20 h 22.
-- Les journaux de l'API montrent que son navigateur n'a envoyé AUCUNE requête entre 19 h 45 et 20 h 20 : ni battement
-- de présence, ni lecture périodique. La page était masquée (écran verrouillé, autre application) et le navigateur
-- mobile la gèle ; à son retour, le premier battement trouvait un écart de plus de 120 s (battement_trou_s) et ne
-- créditait rien. Le serveur ne comptait donc que le temps où l'écran affichait le jeu.
--
-- Correctif : quand la page revient au premier plan (même page, sans rechargement), le navigateur appelle
-- accueil_reprise(durée masquée mesurée par la page). Le serveur crédite l'absence (bornée par l'écart entre deux
-- battements et par cette durée), si elle ne dépasse pas battement_absence_max_s (1 h) ; une
-- absence plus longue reste une déconnexion, non comptée. Une vraie déconnexion (onglet fermé, nouvelle page) n'appelle
-- jamais accueil_reprise() : elle ne compte toujours pas. L'ordre d'arrivée importe peu : si le battement de présence
-- arrive avant l'appel de reprise, l'écart est mis de côté (absence_s, absence_le) et crédité par la reprise qui suit
-- dans les 5 minutes. Le plafond par battement (60 s) et les autres règles du calendrier sont inchangés.
-- Aucun rattrapage : les personnages déjà créés gardent leur compteur actuel ; seules les absences futures comptent.
--
-- Contrôles en lecture après application :
--   SELECT cle, valeur FROM public.accueil_parametres WHERE cle = 'battement_absence_max_s';            -- 3600
--   SELECT column_name FROM information_schema.columns
--    WHERE table_schema = 'public' AND table_name = 'accueil_personnages' AND column_name IN ('absence_s', 'absence_le');  -- 2 lignes
--   SELECT p.oid::regprocedure, position('accueil_calendrier_v2' in p.prosrc) > 0 AS v2 FROM pg_proc p
--    WHERE p.proname IN ('accueil_temps_crediter_interne', 'accueil_reprise');                          -- 3 lignes, v2 vrai
--   SELECT has_function_privilege('authenticated', 'public.accueil_reprise(integer)', 'EXECUTE');              -- vrai
--   SELECT has_function_privilege('authenticated', 'public.accueil_temps_crediter_interne(text,boolean,integer)', 'EXECUTE');  -- faux
BEGIN;

INSERT INTO public.accueil_parametres (cle, valeur, libelle) VALUES
  ('battement_absence_max_s', 3600, 'Page restée ouverte mais masquée (écran verrouillé, autre onglet) : absence créditée au retour jusqu''à ce plafond (secondes) ; au-delà, déconnexion non comptée')
ON CONFLICT (cle) DO NOTHING;

ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS absence_s integer;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS absence_le timestamptz;

-- Crédite le temps de jeu (battement de présence, ou reprise de la page) et fait avancer le calendrier. Ne lève jamais d'erreur.
CREATE OR REPLACE FUNCTION public.accueil_temps_crediter_interne(p_nom text, p_reprise boolean, p_masque_s integer DEFAULT NULL)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; v_ecart numeric; v_delta numeric := 0; v_s integer; v_a integer; v_heure integer;
        v_trou numeric; v_abs_max numeric; v_borne numeric;
BEGIN
  IF p_nom IS NULL OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN RETURN; END IF;
  r := public.accueil_ligne_interne(p_nom);
  IF NOT r.calendrier THEN RETURN; END IF;
  v_heure := public.accueil_param('premiere_heure_s', 3600)::integer;
  IF r.heure_finie_le IS NOT NULL THEN RETURN; END IF;   -- après la première heure, plus rien à compter
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom FOR UPDATE;
  v_trou := public.accueil_param('battement_trou_s', 120);
  v_abs_max := public.accueil_param('battement_absence_max_s', 3600);
  -- L'absence créditée ne dépasse jamais la durée où la page s'est dite masquée.
  v_borne := least(v_abs_max, coalesce(p_masque_s, 0));
  v_ecart := CASE WHEN r.battement_le IS NULL THEN 0 ELSE extract(epoch FROM now() - r.battement_le) END;
  IF v_ecart >= 0 AND v_ecart <= v_trou THEN
    v_delta := least(v_ecart, public.accueil_param('battement_max_s', 60));
  ELSIF v_ecart > v_trou THEN
    IF p_reprise THEN
      IF v_ecart <= v_abs_max AND p_masque_s IS NOT NULL THEN v_delta := least(v_ecart, v_borne); END IF;   -- page restée ouverte
    ELSE
      r.absence_s := floor(v_ecart)::integer; r.absence_le := now();   -- mise de côté pour une reprise qui suivrait
    END IF;
  END IF;
  IF p_reprise THEN
    -- Le battement est arrivé avant la reprise : il a mis l'absence de côté.
    IF r.absence_s IS NOT NULL AND r.absence_le >= now() - interval '5 minutes' AND r.absence_s <= v_abs_max
       AND p_masque_s IS NOT NULL THEN
      v_delta := v_delta + least(r.absence_s, v_borne);
    END IF;
    r.absence_s := NULL; r.absence_le := NULL;
  END IF;
  v_s := least(r.secondes_jeu + floor(v_delta)::integer, v_heure);
  v_a := coalesce(r.interview_a, public.accueil_param('interview_min_s', 300)::integer
           + floor(random() * (public.accueil_param('interview_max_s', 600) - public.accueil_param('interview_min_s', 300) + 1))::integer);
  -- Interview : due au moment tiré, repoussée de 5 min si le joueur vient de parler à un PNJ, forcée à 30 min.
  IF r.interview_due_le IS NULL AND r.etat_interview = 'a_faire' AND v_s >= v_a THEN
    IF v_s < public.accueil_param('interview_force_s', 1800)
       AND r.pnj_parle_a IS NOT NULL AND r.pnj_parle_a > v_s - public.accueil_param('interview_report_s', 300) THEN
      v_a := least(v_a + public.accueil_param('interview_report_s', 300)::integer, public.accueil_param('interview_force_s', 1800)::integer);
    ELSE
      r.interview_due_le := now();
      PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'accueil_interview', '', jsonb_build_object('secondes', v_s));
    END IF;
  END IF;
  -- Fin des 5 minutes de découverte (aucune fenêtre avant, hormis l'avertissement des PA) : la quête d'accueil de
  -- Luthécia (garde du Palais, #1188) peut se présenter.
  IF r.decouverte_le IS NULL AND v_s >= public.accueil_param('interview_min_s', 300) THEN
    r.decouverte_le := now();
    PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'accueil_decouverte_finie', '', '{}'::jsonb);
  END IF;
  IF r.heure_finie_le IS NULL AND v_s >= v_heure THEN
    r.heure_finie_le := now();
    PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'accueil_heure_finie', '', '{}'::jsonb);
  END IF;
  UPDATE public.accueil_personnages SET secondes_jeu = v_s, battement_le = now(), interview_a = v_a,
         interview_due_le = r.interview_due_le, heure_finie_le = r.heure_finie_le, decouverte_le = r.decouverte_le,
         absence_s = r.absence_s, absence_le = r.absence_le, maj_le = now()
   WHERE personnage = p_nom;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'accueil_temps_crediter_interne : %', SQLERRM; /* accueil_calendrier_v2 */
END $function$;

-- Le battement de présence (déclencheur sur presences) garde sa signature.
CREATE OR REPLACE FUNCTION public.accueil_temps_crediter_interne(p_nom text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.accueil_temps_crediter_interne(p_nom, false, NULL); /* accueil_calendrier_v2 */
END $function$;

-- Retour de la page au premier plan (même page, sans rechargement) : appelée par le navigateur du joueur, pour lui seul.
CREATE OR REPLACE FUNCTION public.accueil_reprise(p_masque_s integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.accueil_temps_crediter_interne(a, true, greatest(0, least(coalesce(p_masque_s, 0), 86400)));
  RETURN jsonb_build_object('ok', true); /* accueil_calendrier_v2 */
END $function$;

REVOKE ALL ON FUNCTION public.accueil_temps_crediter_interne(text, boolean, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_temps_crediter_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_reprise(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_reprise(integer) TO authenticated;

COMMIT;
