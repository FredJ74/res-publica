-- Guide du Musée de la République de Sovarka : questions libres à Ouliana (décision de Fred, 11/11/2026,
-- GAME-DESIGN-NOVOMIRSK.md). 1 PA ouvre le dialogue dans une salle, 3 questions au maximum par salle et par
-- jour (heure de Paris), ensuite la guide invite à poursuivre la visite.
-- Le serveur tient le compte : le client ne transmet aucune salle, la salle est celle où se trouve le PJ.
-- /api/chat lit le compte avant d'interroger l'IA et ne le consomme qu'après une réponse obtenue
-- (aucun remboursement à prévoir, aucune RPC de restitution exposée).
BEGIN;

CREATE TABLE IF NOT EXISTS public.guide_musee_dialogues (
  acteur text NOT NULL,
  jour date NOT NULL,
  salle text NOT NULL,
  questions integer NOT NULL DEFAULT 0 CHECK (questions BETWEEN 0 AND 3),
  ouvert_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, jour, salle)
);
ALTER TABLE public.guide_musee_dialogues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guide_musee_dialogues FROM PUBLIC, anon, authenticated;

-- Tarif de l'ouverture du dialogue (1 PA, 0 PSK), validé par payer_ordre.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('questionner_guide_musee', 1, 0) ON CONFLICT DO NOTHING;

-- Salle du musée où se tient le PJ (NULL hors des neuf salles de la guide).
CREATE OR REPLACE FUNCTION public.guide_musee_salle_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT d.current_room FROM public.personnages_donnees d
   WHERE d.name = p_nom AND d.country = 'soviet' AND d.current_city = 'capitale'
     AND d.current_building = 'musee-national-republia'
     AND d.current_room IN ('hall', 'salle_presidents', 'salle_politiques', 'salle_honneur_militaire_nationale',
       'salle_organisations', 'salle_artistes_sportifs', 'salle_civils_intellectuels', 'salle_grandes_villes',
       'expositions_temporaires');
$$;
REVOKE ALL ON FUNCTION public.guide_musee_salle_interne(text) FROM PUBLIC, anon, authenticated;

-- Lecture : le dialogue est-il ouvert dans cette salle aujourd'hui, et combien de questions restent-elles ?
CREATE OR REPLACE FUNCTION public.guide_musee_dialogue_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); s text; q integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  s := public.guide_musee_salle_interne(a);
  IF s IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT questions INTO q FROM public.guide_musee_dialogues WHERE acteur = a AND jour = public.sovarka_jour_paris() AND salle = s;
  RETURN jsonb_build_object('ok', true, 'salle', s, 'ouvert', q IS NOT NULL, 'restantes', CASE WHEN q IS NULL THEN 0 ELSE 3 - q END);
END $$;
REVOKE ALL ON FUNCTION public.guide_musee_dialogue_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guide_musee_dialogue_lire() TO authenticated;

-- Ouverture : 1 PA, une fois par salle et par jour. Rejouée, elle ne prélève rien.
CREATE OR REPLACE FUNCTION public.guide_musee_dialogue_ouvrir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); s text; q integer; j date := public.sovarka_jour_paris(); v_paie jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('guide_musee:' || a, 0));
  s := public.guide_musee_salle_interne(a);
  IF s IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT questions INTO q FROM public.guide_musee_dialogues WHERE acteur = a AND jour = j AND salle = s FOR UPDATE;
  IF FOUND THEN
    IF q >= 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'questions_epuisees'); END IF;
    RETURN jsonb_build_object('ok', true, 'deja', true, 'salle', s, 'restantes', 3 - q);
  END IF;
  v_paie := public.payer_ordre(a, 'questionner_guide_musee', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.guide_musee_dialogues (acteur, jour, salle) VALUES (a, j, s);
  RETURN jsonb_build_object('ok', true, 'salle', s, 'restantes', 3,
    'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
END $$;
REVOKE ALL ON FUNCTION public.guide_musee_dialogue_ouvrir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guide_musee_dialogue_ouvrir() TO authenticated;

-- Consommation d'une question, appelée par /api/chat APRÈS une réponse de l'IA : refusée au-delà de 3.
CREATE OR REPLACE FUNCTION public.guide_musee_question_consommer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); s text; q integer; j date := public.sovarka_jour_paris();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('guide_musee:' || a, 0));
  s := public.guide_musee_salle_interne(a);
  IF s IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT questions INTO q FROM public.guide_musee_dialogues WHERE acteur = a AND jour = j AND salle = s FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'dialogue_non_ouvert'); END IF;
  IF q >= 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'questions_epuisees'); END IF;
  UPDATE public.guide_musee_dialogues SET questions = q + 1 WHERE acteur = a AND jour = j AND salle = s;
  RETURN jsonb_build_object('ok', true, 'salle', s, 'restantes', 2 - q);
END $$;
REVOKE ALL ON FUNCTION public.guide_musee_question_consommer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guide_musee_question_consommer() TO authenticated;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.guide_musee_dialogues', 'SELECT') THEN
    RAISE EXCEPTION 'guide_musee_dialogues ne doit pas être lisible par le client'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'questionner_guide_musee' AND pa = 1 AND cost = 0) THEN
    RAISE EXCEPTION 'tarif questionner_guide_musee absent'; END IF;
END $$;

COMMIT;
