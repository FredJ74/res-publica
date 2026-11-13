-- Centres d'écoute de Sovarka : consultation du ministre et habilitations (Fred, 13/11/2026,
-- 21 h 59 – 22 h 14 ; GAME-DESIGN-NOVOMIRSK.md). Partie 3/4.
--  - Les trois centres appartiennent au ministère de la Défense ; son ministre ne lit les rapports
--    QUE depuis son bureau du Palais du Gouvernement (toujours gratuitement).
--  - Le ministre de la Sécurité du Peuple accorde ou retire une habilitation à n'importe quel PJ,
--    jamais à lui-même ; il voit la liste des habilités. Il n'a pas lui-même accès aux rapports.
--  - Le PJ habilité consulte sur place, dans la salle d'écoute d'un centre, les archives de CE
--    centre (30 derniers jours) : recherche par nom de personnage, 1 PA, sans argent ni limite.

CREATE OR REPLACE FUNCTION pg_temp.patch(p_code text, p_ancien text, p_nouveau text, p_nom text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  IF position(p_ancien IN p_code) = 0 THEN RAISE EXCEPTION 'fragment introuvable dans % : %', p_nom, left(p_ancien, 80); END IF;
  RETURN replace(p_code, p_ancien, p_nouveau);
END $$;

-- 1. Le ministre de la Défense lit les rapports depuis son bureau seulement.
DO $m$
DECLARE f text; n text;
  garde text := 'IF public.sovarka_titulaire_interne(''min_def'') IS DISTINCT FROM a THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_ministre_defense''); END IF;';
  lieu text := E'\n  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = ''soviet''\n'
            || E'     AND current_building = ''palais-gouvernement'' AND current_room = ''bureau_min_def'') THEN\n'
            || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_sur_place''); END IF; /* ecoutes_au_bureau */';
BEGIN
  FOREACH n IN ARRAY ARRAY['public.sovarka_ecoutes_lire()', 'public.sovarka_ecoute_rapport_demander(text,date)'] LOOP
    f := pg_get_functiondef(n::regprocedure);
    CONTINUE WHEN position('ecoutes_au_bureau' IN f) > 0;
    EXECUTE pg_temp.patch(f, garde, garde || lieu, n);
  END LOOP;
END $m$;

-- 2. Habilitations (propriété du ministère, pas du ministre) et journal des consultations.
CREATE TABLE IF NOT EXISTS public.sovarka_habilitations_ecoute (
  beneficiaire text PRIMARY KEY,
  accordee_par text NOT NULL,
  accordee_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.sovarka_ecoutes_consultations (
  acteur text NOT NULL, requete text NOT NULL, centre text NOT NULL, cible text NOT NULL,
  resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete));
ALTER TABLE public.sovarka_habilitations_ecoute ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_ecoutes_consultations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_habilitations_ecoute, public.sovarka_ecoutes_consultations FROM anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'consulter_archives_ecoute', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'consulter_archives_ecoute');

-- Le ministre de la Sécurité du Peuple, dans son bureau ; rend NULL si tout va bien.
CREATE OR REPLACE FUNCTION public.sovarka_habilitation_refus_interne(a text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.sovarka_titulaire_interne('min_int') IS DISTINCT FROM a THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_ministre_securite'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = 'soviet'
                   AND current_building = 'palais-gouvernement' AND current_room = 'bureau_min_int') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.sovarka_habilitations_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb := public.sovarka_habilitation_refus_interne(a);
BEGIN
  IF v IS NOT NULL THEN RETURN v; END IF;
  RETURN jsonb_build_object('ok', true, 'habilites', coalesce((SELECT jsonb_agg(jsonb_build_object(
    'nom', h.beneficiaire, 'par', h.accordee_par, 'le', h.accordee_le) ORDER BY h.accordee_le DESC)
    FROM public.sovarka_habilitations_ecoute h), '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.sovarka_habilitation_accorder(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb := public.sovarka_habilitation_refus_interne(a); n text := btrim(p_nom);
BEGIN
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name INTO n FROM public.personnages_donnees WHERE lower(name) = lower(n) LIMIT 1;
  IF n IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF n = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_soi_meme'); END IF;
  INSERT INTO public.sovarka_habilitations_ecoute (beneficiaire, accordee_par) VALUES (n, a)
  ON CONFLICT (beneficiaire) DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_habilite'); END IF;
  PERFORM public.mail_systeme_poser_interne('Ministère de la Sécurité du Peuple', n,
    'Habilitation aux archives d''écoute',
    'Le ministre de la Sécurité du Peuple vous accorde l''habilitation aux archives des centres d''écoute de Sovarka. '
    || 'Dans la salle d''écoute de chaque centre (Novomirsk, Starovka, Krasnov), vous pouvez consulter les archives de ce centre '
    || 'en cherchant un nom de personnage (1 PA par recherche). Cette habilitation peut vous être retirée à tout moment.');
  RETURN public.sovarka_habilitations_lire() || jsonb_build_object('accorde', n);
END $$;

CREATE OR REPLACE FUNCTION public.sovarka_habilitation_retirer(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb := public.sovarka_habilitation_refus_interne(a); n text;
BEGIN
  IF v IS NOT NULL THEN RETURN v; END IF;
  DELETE FROM public.sovarka_habilitations_ecoute WHERE beneficiaire = btrim(p_nom) RETURNING beneficiaire INTO n;
  IF n IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_habilite'); END IF;
  PERFORM public.mail_systeme_poser_interne('Ministère de la Sécurité du Peuple', n,
    'Habilitation retirée', 'Le ministre de la Sécurité du Peuple vous retire l''habilitation aux archives des centres d''écoute.');
  RETURN public.sovarka_habilitations_lire() || jsonb_build_object('retire', n);
END $$;

-- 3. Consultation par un PJ habilité, sur place, dans le centre où il se trouve.
CREATE OR REPLACE FUNCTION public.sovarka_ecoute_archives_consulter(p_cible text, p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; c text; x record; v_paie jsonb; v jsonb;
        v_cible text := btrim(p_cible); v_mails jsonb; v_nb integer; v_texte text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF coalesce(v_cible, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:consulter_archives:' || a, 0));
  SELECT * INTO x FROM public.sovarka_ecoutes_consultations WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_habilitations_ecoute WHERE beneficiaire = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_habilite'); END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = a;
  c := CASE WHEN p.country = 'soviet' THEN public.sovarka_ecoute_centre_interne(p.current_city, p.current_building) END;
  IF c IS NULL OR (c = 'novomirsk' AND p.current_room IS DISTINCT FROM 'salle_ecoutes') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_paie := public.payer_ordre(a, 'consulter_archives_ecoute', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT coalesce(jsonb_agg(m || jsonb_build_object('jour', r.jour) ORDER BY r.jour, m->>'heure'), '[]'::jsonb)
    INTO v_mails
    FROM public.sovarka_ecoutes_rapports r, jsonb_array_elements(r.mails) m
   WHERE r.centre = c AND r.jour >= public.sovarka_jour_paris() - 30
     AND (lower(m->>'de') = lower(v_cible) OR lower(m->>'a') = lower(v_cible));
  v_nb := jsonb_array_length(v_mails);
  IF v_nb > 0 THEN
    SELECT 'Archives de la cellule d''écoute de ' || initcap(c) || ' — recherche « ' || v_cible || ' » (30 derniers jours)'
           || E'\n' || v_nb || ' communication(s) trouvée(s) :' || E'\n\n'
           || string_agg('• ' || to_char((m->>'jour')::date, 'DD/MM') || ' ' || coalesce(m->>'heure', '') || ' — de ' || (m->>'de') || ' à ' || (m->>'a')
                || E'\n  Objet : ' || coalesce(m->>'sujet', '') || E'\n  « ' || coalesce(m->>'texte', '') || ' »', E'\n\n')
      INTO v_texte FROM jsonb_array_elements(v_mails) m;
    PERFORM public.mail_systeme_poser_interne('Archives d''écoute', a,
      'Archives consultées — ' || v_cible || ', ' || initcap(c), v_texte);
  END IF;
  v := jsonb_build_object('ok', true, 'centre', c, 'cible', v_cible, 'nb', v_nb, 'pa', v_paie->'pa');
  INSERT INTO public.sovarka_ecoutes_consultations (acteur, requete, centre, cible, resultat) VALUES (a, p_requete, c, v_cible, v);
  RETURN v;
END $$;

REVOKE ALL ON FUNCTION public.sovarka_habilitation_refus_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sovarka_habilitations_lire(), public.sovarka_habilitation_accorder(text),
  public.sovarka_habilitation_retirer(text), public.sovarka_ecoute_archives_consulter(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_habilitations_lire(), public.sovarka_habilitation_accorder(text),
  public.sovarka_habilitation_retirer(text), public.sovarka_ecoute_archives_consulter(text, text) TO authenticated;

DO $preuve$
BEGIN
  IF position('ecoutes_au_bureau' IN pg_get_functiondef('public.sovarka_ecoutes_lire()'::regprocedure)) = 0
     OR position('ecoutes_au_bureau' IN pg_get_functiondef('public.sovarka_ecoute_rapport_demander(text,date)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'garde de lieu du ministre absente'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'consulter_archives_ecoute' AND pa = 1 AND cost = 0) THEN
    RAISE EXCEPTION 'coût de consultation absent'; END IF;
END $preuve$;
