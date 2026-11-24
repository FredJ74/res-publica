-- Purge, bloc A, point A.3 (Fred, 24/11/2026) : calendrier du nouveau venu. NON APPLIQUÉE. Rejouable. Rien du goulag.
-- Après 20261124101000_accueil_bienvenue (colonne calendrier).
--
-- Les temps se comptent en secondes de jeu CUMULÉES d'une connexion à l'autre, tenues par le SERVEUR :
--  • le battement de présence existant (écriture de « presences » par l'écran, toutes les 30 s onglet visible) crédite le
--    temps écoulé depuis le battement précédent (au plus battement_max_s = 60 s ; un trou de plus de battement_trou_s =
--    120 s, déconnexion ou onglet caché, ne compte pas). Déclencheur zz_accueil_temps_jeu sur presences : aucune requête
--    de plus pour l'écran. Le compteur s'arrête à une heure (rien d'autre ne s'en sert).
--  • le moment de l'interview est tiré UNE fois par le serveur entre 5 et 10 minutes (interview_a, en secondes).
--  • une conversation avec un PNJ (api/chat.js, après une réponse obtenue) note l'instant de jeu (accueil_pnj_parle) ; si
--    le joueur a parlé à un PNJ dans les 5 dernières minutes au moment prévu, l'interview est repoussée de 5 minutes,
--    autant de fois que nécessaire ; à 30 minutes de jeu elle arrive quand même. Quand elle est due, le serveur prévient
--    l'écran (personnage_evenements, clé accueil_interview) ; l'écran attend seulement que la fenêtre ouverte soit fermée.
--  • à une heure de jeu, le serveur prévient (clé accueil_heure_finie) : fin de la première heure sans fenêtre automatique.
-- Le déclenchement de l'interview à la connexion est retiré pour les personnages du calendrier (A.2) ; le déclenchement
-- « après le 3e déplacement » cité par la consigne n'existe ni dans le code de main ni dans la base (relevé du 24/11).
-- Réglages MJ (accueil_parametres) : interview_min_s, interview_max_s, interview_report_s, interview_force_s,
-- premiere_heure_s, battement_max_s, battement_trou_s.

INSERT INTO public.accueil_parametres (cle, valeur, libelle) VALUES
  ('interview_min_s', 300, 'Nouveau venu : interview au plus tôt après ce temps de jeu (secondes)'),
  ('interview_max_s', 600, 'Nouveau venu : interview au plus tard après ce temps de jeu, hors report (secondes)'),
  ('interview_report_s', 300, 'Report de l''interview si le joueur a parlé à un PNJ dans ce délai (secondes)'),
  ('interview_force_s', 1800, 'Temps de jeu où l''interview arrive quand même (secondes)'),
  ('premiere_heure_s', 3600, 'Première heure de jeu sans fenêtre automatique (secondes)'),
  ('battement_max_s', 60, 'Temps de jeu crédité au plus par battement de présence (secondes)'),
  ('battement_trou_s', 120, 'Au-delà de cet écart entre deux battements, le temps ne compte pas (secondes)')
ON CONFLICT (cle) DO NOTHING;

ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS secondes_jeu integer NOT NULL DEFAULT 0;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS battement_le timestamptz;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS interview_a integer;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS interview_due_le timestamptz;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS pnj_parle_a integer;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS heure_finie_le timestamptz;

-- Crédite le temps de jeu d'un battement et fait avancer le calendrier. Ne lève jamais d'erreur.
CREATE OR REPLACE FUNCTION public.accueil_temps_crediter_interne(p_nom text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; v_delta numeric; v_s integer; v_a integer; v_heure integer;
BEGIN
  IF p_nom IS NULL OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN RETURN; END IF;
  r := public.accueil_ligne_interne(p_nom);
  IF NOT r.calendrier THEN RETURN; END IF;
  v_heure := public.accueil_param('premiere_heure_s', 3600)::integer;
  IF r.heure_finie_le IS NOT NULL THEN RETURN; END IF;   -- après la première heure, plus rien à compter
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom FOR UPDATE;
  v_delta := CASE WHEN r.battement_le IS NULL THEN 0 ELSE extract(epoch FROM now() - r.battement_le) END;
  IF v_delta < 0 OR v_delta > public.accueil_param('battement_trou_s', 120) THEN v_delta := 0; END IF;
  v_delta := least(v_delta, public.accueil_param('battement_max_s', 60));
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
  IF r.heure_finie_le IS NULL AND v_s >= v_heure THEN
    r.heure_finie_le := now();
    PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'accueil_heure_finie', '', '{}'::jsonb);
  END IF;
  UPDATE public.accueil_personnages SET secondes_jeu = v_s, battement_le = now(), interview_a = v_a,
         interview_due_le = r.interview_due_le, heure_finie_le = r.heure_finie_le, maj_le = now()
   WHERE personnage = p_nom;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'accueil_temps_crediter_interne : %', SQLERRM; /* accueil_calendrier_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.accueil_presence_trg()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Seul le battement du personnage connecté compte (règle d'écriture de presences : soi seul).
  IF NEW.name IS NOT NULL AND NEW.name = public.mon_personnage() THEN
    PERFORM public.accueil_temps_crediter_interne(NEW.name);
  END IF;
  RETURN NEW; /* accueil_calendrier_v1 */
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END $function$;
DROP TRIGGER IF EXISTS zz_accueil_temps_jeu ON public.presences;
CREATE TRIGGER zz_accueil_temps_jeu AFTER INSERT OR UPDATE ON public.presences
  FOR EACH ROW EXECUTE FUNCTION public.accueil_presence_trg();

-- Conversation avec un PNJ (appelée par api/chat.js sous le jeton du joueur, après une réponse obtenue).
CREATE OR REPLACE FUNCTION public.accueil_pnj_parle()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.accueil_personnages SET pnj_parle_a = secondes_jeu, maj_le = now()
   WHERE personnage = a AND calendrier AND interview_due_le IS NULL;
  RETURN jsonb_build_object('ok', true); /* accueil_calendrier_v1 */
END $function$;

-- Vue complète de l'accueil pour le navigateur (jamais un calcul du navigateur).
CREATE OR REPLACE FUNCTION public.accueil_vue_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; j record; v_pays text; v_etapes jsonb; v_chemins jsonb; v_lib text; v_heure integer;
BEGIN
  r := public.accueil_ligne_interne(p_nom);
  v_heure := public.accueil_param('premiere_heure_s', 3600)::integer;
  v_pays := coalesce(r.pays, (SELECT country FROM public.personnages_donnees WHERE name = p_nom));
  SELECT * INTO j FROM public.accueil_journalistes WHERE pays = v_pays;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', c.chemin, 'libelle', c.libelle) ORDER BY c.rang), '[]'::jsonb)
    INTO v_chemins FROM public.accueil_chemins c WHERE c.pays = v_pays;
  SELECT libelle INTO v_lib FROM public.accueil_chemins WHERE pays = v_pays AND chemin = r.chemin;
  SELECT coalesce(jsonb_agg(jsonb_build_object('n', e.n, 'texte', e.texte, 'lieu', e.lieu, 'validation', e.validation,
           'pnj', e.pnj, 'faite', r.etapes_faites ? e.n::text, 'faite_le', r.etapes_faites ->> e.n::text) ORDER BY e.n), '[]'::jsonb)
    INTO v_etapes FROM public.accueil_etapes e WHERE e.pays = v_pays AND e.chemin = r.chemin;
  RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'pays', v_pays,
    'interview', jsonb_build_object('etat', r.etat_interview, 'journaliste', j.journaliste, 'journal', j.journal,
      'question', j.question,
      -- Ancien accueil : à la connexion. Calendrier du nouveau venu : quand le serveur l'a déclarée due (A.3).
      'ouvrir_auto', r.etat_interview = 'a_faire' AND r.ouverte_auto_le IS NULL
                     AND public.accueil_param('interview_ouverture_auto', 1) >= 1
                     AND (NOT r.calendrier OR r.interview_due_le IS NOT NULL)),
    'calendrier', jsonb_build_object('actif', r.calendrier, 'secondes_jeu', r.secondes_jeu,
      'premiere_heure', r.calendrier AND r.heure_finie_le IS NULL AND r.secondes_jeu < v_heure,
      'interview_due', r.interview_due_le IS NOT NULL,
      'interview_forcee', r.calendrier AND r.secondes_jeu >= public.accueil_param('interview_force_s', 1800)),
    'bienvenue', jsonb_build_object('a_voir', r.calendrier AND r.bienvenue_vue_le IS NULL,
      'pays', coalesce(r.pays, v_pays), 'ville', r.ville_depart,
      'signataire', nullif((SELECT valeur FROM public.accueil_parametres_textes WHERE cle = 'bienvenue_signataire'), ''),
      'portrait', nullif((SELECT valeur FROM public.accueil_parametres_textes WHERE cle = 'bienvenue_portrait'), '')),
    'mot_max', public.accueil_param('mot_longueur_max', 280)::integer,
    'chemins', v_chemins,
    'chemin', CASE WHEN r.chemin IS NULL THEN NULL ELSE jsonb_build_object('id', r.chemin, 'libelle', v_lib) END,
    'mot', r.mot, 'etapes', v_etapes,
    'bulle_pa', jsonb_build_object('vue', r.bulle_pa_le IS NOT NULL, 'pa', r.bulle_pa_pa,
      'active', public.accueil_param('bulle_pa_active', 1) >= 1)); /* accueil_interview_v1 accueil_bienvenue_v1 accueil_calendrier_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.accueil_temps_crediter_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_presence_trg() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_vue_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_pnj_parle() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_pnj_parle() TO authenticated;
