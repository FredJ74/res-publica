-- SOVARKA : CENTRES D'ECOUTE (decisions de Fred du 10/11/2026 ; GAME-DESIGN-NOVOMIRSK.md, « Reponses de Fred »,
-- point 5 « Poste militaire (Starovka) et station radar (Krasnov) »). Specialite de Sovarka : l'espionnage.
-- - Trois cellules : Novomirsk (Direction du Renseignement), Starovka (Poste de Vigilance Glaciale), Krasnov
--   (station radar). Couverture : Novomirsk = la ville + Republia ; Starovka = la ville + El Estado ; Krasnov =
--   la ville + Al-Khalija (les empires P2W n'existent pas encore ; l'empire Coree/Japon ne pourra pas etre
--   espionne).
-- - « Mails de la ville / du pays » = mails envoyes ou recus par un PJ DOMICILIE dans cette ville / ce pays
--   (domicile, a defaut le pays du personnage). Seuls les mails ecrits entre PJ sont interceptes.
-- - Chaque centre intercepte 10 % des mails de la journee (chaque mail a une chance sur dix) ; en fin de
--   journee (passe de minuit), les ecoutes sont compilees en un rapport consigne (archives).
-- - Le ministre de la Defense de Sovarka demande a chaque cellule le rapport du jour qu'il veut, a distance :
--   il le recoit par mail.
-- - Vol d'archives (tout PJ qui n'est pas ministre de la Defense), au poste ou a la station : un rapport au
--   hasard parmi ceux des 30 derniers jours ; acte illegal, jet selon la regle existante (45 % moins le malus
--   de securite de la ville, jet augmente du malus des hommes armes presents). Echec : bagarre avec
--   l'operateur puis prison (arrestation en flagrant delit, bareme du delit grave). Reussite : le PJ obtient le
--   rapport (par mail) mais laisse une trace.
-- Batiments : une seule piece (« Salle d'ecoute ») avec l'operateur et les archives. Operateurs valides par
-- Fred : Sergent Bair Dorjiev (Starovka), Lieutenante Nadejda Sokolova (Krasnov).
BEGIN;

-- 1. Batiments, entrees de rue.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_a', 'poste-vigilance-glaciale', '["salle_ecoute"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'station-radar-krasnov', '["salle_ecoute"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
  ('soviet', 'ville_a', 'starovka-rue-bureaux-caserne', 'poste-vigilance-glaciale'),
  ('soviet', 'ville_b', 'krasnov-rue-distillerie-radar', 'station-radar-krasnov')
ON CONFLICT DO NOTHING;

-- 2. Rapports consignes.
CREATE TABLE IF NOT EXISTS public.sovarka_ecoutes_rapports (
  centre text NOT NULL CHECK (centre IN ('novomirsk', 'starovka', 'krasnov')),
  jour date NOT NULL,
  mails jsonb NOT NULL DEFAULT '[]'::jsonb,
  examines integer NOT NULL DEFAULT 0,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (centre, jour)
);
ALTER TABLE public.sovarka_ecoutes_rapports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_ecoutes_rapports FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.sovarka_ecoutes_vols (
  acteur text NOT NULL,
  requete text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete)
);
ALTER TABLE public.sovarka_ecoutes_vols ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_ecoutes_vols FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'voler_archives_ecoute', 2, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'voler_archives_ecoute' AND pa = 2 AND cost = 0);
INSERT INTO public.actes_illegaux (fn, type, detect_rate, peine_jours, amende, decouvrable)
VALUES ('voler_archives_ecoute', 'delit_grave', 100, NULL, NULL, false)
ON CONFLICT (fn) DO NOTHING;

-- 3. Le centre d'un batiment, et sa couverture.
CREATE OR REPLACE FUNCTION public.sovarka_ecoute_centre_interne(p_ville text, p_batiment text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_ville = 'ville_a' AND p_batiment = 'poste-vigilance-glaciale' THEN 'starovka'
              WHEN p_ville = 'ville_b' AND p_batiment = 'station-radar-krasnov' THEN 'krasnov' END;
$$;

CREATE OR REPLACE FUNCTION public.sovarka_ecoute_couvre_interne(p_centre text, p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     CROSS JOIN LATERAL (SELECT coalesce(d.domicile->>'country', d.country) AS pays, d.domicile->>'city' AS ville) x
     WHERE d.name = p_nom AND (
          (p_centre = 'novomirsk' AND ((x.pays = 'soviet' AND x.ville = 'capitale') OR x.pays = 'republic'))
       OR (p_centre = 'starovka'  AND ((x.pays = 'soviet' AND x.ville = 'ville_a') OR x.pays = 'narco'))
       OR (p_centre = 'krasnov'   AND ((x.pays = 'soviet' AND x.ville = 'ville_b') OR x.pays = 'khalija'))));
$$;
REVOKE ALL ON FUNCTION public.sovarka_ecoute_couvre_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Texte d'un rapport.
CREATE OR REPLACE FUNCTION public.sovarka_ecoute_rapport_texte_interne(r public.sovarka_ecoutes_rapports)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT 'Cellule d''écoute de ' || CASE r.centre WHEN 'novomirsk' THEN 'Novomirsk' WHEN 'starovka' THEN 'Starovka' ELSE 'Krasnov' END
    || ' — rapport du ' || to_char(r.jour, 'DD/MM/YYYY') || E'\n'
    || CASE WHEN jsonb_array_length(r.mails) = 0 THEN 'Aucune communication interceptée ce jour-là.'
       ELSE jsonb_array_length(r.mails) || ' communication(s) interceptée(s) :' || E'\n\n' || (
         SELECT string_agg('• ' || coalesce(m->>'heure', '') || ' — de ' || (m->>'de') || ' à ' || (m->>'a')
                || E'\n  Objet : ' || coalesce(m->>'sujet', '') || E'\n  « ' || coalesce(m->>'texte', '') || ' »', E'\n\n'
                ORDER BY m->>'heure')
           FROM jsonb_array_elements(r.mails) m) END;
$$;
REVOKE ALL ON FUNCTION public.sovarka_ecoute_rapport_texte_interne(public.sovarka_ecoutes_rapports) FROM PUBLIC, anon, authenticated;

-- 4. Compilation de la veille (passe de minuit).
CREATE OR REPLACE FUNCTION public.sovarka_ecoutes_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := public.sovarka_jour_paris() - 1; c text; v_mails jsonb; v_n integer; v_out jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOREACH c IN ARRAY ARRAY['novomirsk', 'starovka', 'krasnov'] LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour = v_jour);
    WITH du_jour AS (
      SELECT m.* FROM public.mails m
       WHERE ((m.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris')::date = v_jour
         AND m.from_org_id IS NULL
         AND EXISTS (SELECT 1 FROM public.personnages_donnees a WHERE a.name = m.from_player)
         AND EXISTS (SELECT 1 FROM public.personnages_donnees b WHERE b.name = m.to_player)
         AND (public.sovarka_ecoute_couvre_interne(c, m.from_player) OR public.sovarka_ecoute_couvre_interne(c, m.to_player))
    ), tires AS (SELECT * FROM du_jour WHERE random() < 0.10)
    SELECT (SELECT count(*) FROM du_jour),
           coalesce((SELECT jsonb_agg(jsonb_build_object(
               'heure', to_char((t.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris', 'HH24"h"MI'),
               'de', t.from_player, 'a', t.to_player, 'sujet', left(coalesce(t.subject, ''), 120),
               'texte', left(coalesce(t.body, ''), 600)) ORDER BY t.created_at) FROM tires t), '[]'::jsonb)
      INTO v_n, v_mails;
    INSERT INTO public.sovarka_ecoutes_rapports (centre, jour, mails, examines) VALUES (c, v_jour, v_mails, v_n)
    ON CONFLICT DO NOTHING;
    v_out := v_out || jsonb_build_object(c, jsonb_array_length(v_mails));
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'interceptes', v_out);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ecoutes_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_ecoutes_passe() TO service_role;

-- 5. Le ministre de la Defense : liste des rapports, demande d'un rapport (recu par mail).
CREATE OR REPLACE FUNCTION public.sovarka_ecoutes_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.sovarka_titulaire_interne('min_def') IS DISTINCT FROM a THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_ministre_defense'); END IF;
  RETURN jsonb_build_object('ok', true, 'rapports', coalesce((
    SELECT jsonb_agg(jsonb_build_object('centre', centre, 'jour', jour, 'nb', jsonb_array_length(mails)) ORDER BY jour DESC, centre)
      FROM public.sovarka_ecoutes_rapports WHERE jour >= public.sovarka_jour_paris() - 30), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ecoutes_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_ecoutes_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_ecoute_rapport_demander(p_centre text, p_jour date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); r public.sovarka_ecoutes_rapports;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.sovarka_titulaire_interne('min_def') IS DISTINCT FROM a THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_ministre_defense'); END IF;
  SELECT * INTO r FROM public.sovarka_ecoutes_rapports WHERE centre = p_centre AND jour = p_jour;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'rapport_introuvable'); END IF;
  PERFORM public.mail_systeme_poser_interne('Renseignement militaire de Sovarka', a,
    'Rapport d''écoute — ' || initcap(r.centre) || ', ' || to_char(r.jour, 'DD/MM'),
    public.sovarka_ecoute_rapport_texte_interne(r));
  RETURN jsonb_build_object('ok', true, 'nb', jsonb_array_length(r.mails));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ecoute_rapport_demander(text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_ecoute_rapport_demander(text, date) TO authenticated;

-- 6. Vol d'archives.
CREATE OR REPLACE FUNCTION public.sovarka_ecoute_archives_voler(p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; c text; v_paie jsonb; v_taux integer; v_roll integer;
        r public.sovarka_ecoutes_rapports; v jsonb; x record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:vol_archives:' || a, 0));
  SELECT * INTO x FROM public.sovarka_ecoutes_vols WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true) || public.crime_etat_acteur_interne(a); END IF;
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  c := CASE WHEN p.country = 'soviet' THEN public.sovarka_ecoute_centre_interne(p.current_city, p.current_building) END;
  IF c IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.sovarka_titulaire_interne('min_def') IS NOT DISTINCT FROM a THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ministre_defense'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour >= public.sovarka_jour_paris() - 30) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'archives_vides'); END IF;
  v_paie := public.payer_ordre(a, 'voler_archives_ecoute', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, 45 - public.crime_malus_isn_interne(p.country, p.current_city));
  v_roll := least(100, floor(random() * 100)::integer + 1 + public.securite_malus_lieu_interne(a)); /* securite_dissuasion */
  IF v_roll > v_taux THEN
    PERFORM public.crime_detecter_interne(a, 'voler_archives_ecoute', false);
    v := jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll, 'pa', v_paie->'pa',
      'arrestation', public.arrestation_flagrant_interne(a, 'voler_archives_ecoute', false, 'vol_archives_ecoute',
        'Surpris en train de fouiller les archives d''écoute, après une bagarre avec l''opérateur'));
  ELSE
    SELECT * INTO r FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour >= public.sovarka_jour_paris() - 30
     ORDER BY random() LIMIT 1;
    PERFORM public.crime_tracer_interne(a, 'voler_archives_ecoute', 'archives d''écoute de ' || initcap(c));
    PERFORM public.mail_systeme_poser_interne('Archives volées', a,
      'Rapport d''écoute dérobé — ' || initcap(r.centre) || ', ' || to_char(r.jour, 'DD/MM'),
      public.sovarka_ecoute_rapport_texte_interne(r));
    v := jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_roll, 'pa', v_paie->'pa',
      'centre', r.centre, 'jour', r.jour, 'nb', jsonb_array_length(r.mails));
  END IF;
  INSERT INTO public.sovarka_ecoutes_vols (acteur, requete, resultat) VALUES (a, p_requete, v);
  RETURN v || public.crime_etat_acteur_interne(a);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ecoute_archives_voler(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_ecoute_archives_voler(text) TO authenticated;

COMMIT;
