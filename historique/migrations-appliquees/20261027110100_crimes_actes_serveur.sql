-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027145732.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027145732.
-- Eprouvee en transaction annulee au role authenticated : hp_set refuse, soi/sans arme refuses, 4 tentatives, incendie 1j, explosifs (victime a 15 PV puis explosif consomme), decouverte de minuit -> detention.
-- ============================================================================
-- NEUTRALISER, INCENDIER, UTILISER DES EXPLOSIFS : PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », famille « Crime ». Ces trois actes etaient entierement decides par
-- l'ecran de l'auteur : jet, gravite, degats deposes sur la victime, fermeture du batiment,
-- detection. Ils etaient d'ailleurs inutilisables (leur paiement etait refuse : ordre non declare).
-- Pire, deux portes restaient ouvertes a tous, sans jet ni PA :
--   * impact_deposer('hp_set') : tout joueur pouvait mettre a terre une personne presente dans la
--     meme piece, autant de fois qu'il le voulait ;
--   * batiments_fermes : tout joueur pouvait fermer n'importe quel batiment, pour n'importe quelle
--     duree.
-- Les regles sont celles de l'ecran :
--   * neutraliser (mains 2 PA / arme blanche 2 PA / arme a feu 3 PA, -20 discretion) : taux =
--     base + 2 x caracteristique (FOR / DUP / PER, 8 par defaut) + 15 (carriere criminelle)
--     - PER de la cible / 2, plafonne (65 / 75 / 85). Reussite totale : la victime tombe a 0 PV ;
--     partielle : 25 PV ; echec partiel : 50 PV et l'auteur est recherche ; echec total : recherche.
--     Reussite : trace « assassinat » et detection (regles de checkDetection) ;
--   * incendier (3 PA) : taux = 30 + 15 (carriere) - malus de securite de la ville - 30 (centre du
--     pouvoir) ; fermeture 3, 2 ou 1 jour ; detection au taux de l'acte, sinon trace ;
--   * explosifs (3 PA, l'explosif est consomme) : taux = 35 + memes modificateurs ; reussite :
--     fermeture 5 jours, chaque personne presente dans la piece tombe a 15 PV ; echec : l'auteur
--     est signale (recherche) ; reussite : detection au taux de l'acte, sinon trace.
-- jour_fin est pose a 0 : le declencheur trg_fermeture_date_universelle le calcule.
-- La PV d'une victime ne remonte jamais par une attaque (minimum entre ses PV et le palier).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('neutraliser_mains', 2, 0), ('neutraliser_arme', 2, 0), ('neutraliser_feu', 3, 0),
  ('incendier', 3, 0), ('utiliser_explosifs', 3, 0)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.crime_malus_isn_interne(p_pays text, p_ville text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT CASE WHEN v <= 20 THEN 0 WHEN v <= 40 THEN 5 WHEN v <= 60 THEN 10 WHEN v <= 80 THEN 15 ELSE 25 END
        FROM (SELECT coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                                WHERE id = p_pays || '_' || coalesce(p_ville, 'capitale')), 30) AS v) x $$;

CREATE OR REPLACE FUNCTION public.crime_neutraliser(p_cible text, p_mode text, p_per_pnj integer DEFAULT 10)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; c record; v_pj boolean; v_stat text; v_base integer; v_cap integer; v_pa integer; v_sous text[];
  v_per numeric; v_paie jsonb; v_dis numeric; v_taux integer; v_roll integer; v_palier text; v_pv integer; v_reussi boolean;
  v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  CASE p_mode
    WHEN 'mains' THEN v_stat := 'FOR'; v_base := 15; v_cap := 65; v_pa := 2; v_sous := NULL;
    WHEN 'arme'  THEN v_stat := 'DUP'; v_base := 25; v_cap := 75; v_pa := 2; v_sous := ARRAY['blanche'];
    WHEN 'feu'   THEN v_stat := 'PER'; v_base := 35; v_cap := 85; v_pa := 3; v_sous := ARRAY['poing', 'carabine'];
    ELSE RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END CASE;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT name, country, current_city, current_building, current_room, hp INTO c FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  v_pj := FOUND;
  IF v_pj THEN
    IF c.country IS DISTINCT FROM m.country OR c.current_city IS DISTINCT FROM m.current_city
       OR c.current_building IS DISTINCT FROM m.current_building OR c.current_room IS DISTINCT FROM m.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
    v_per := 10;
  ELSE
    v_per := greatest(0, least(20, coalesce(p_per_pnj, 10)));
  END IF;
  IF v_sous IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) i
        WHERE i ->> 'type' = 'arme' AND i ->> 'sousType' = ANY (v_sous)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'arme_manquante'); END IF;

  v_paie := public.payer_ordre(v_moi, 'neutraliser_' || p_mode, v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_dis := coalesce(CASE WHEN jsonb_typeof(m.resources -> 'dis') = 'number' THEN (m.resources ->> 'dis')::numeric END, 50);
  IF p_mode = 'feu' THEN
    v_dis := greatest(0, v_dis - 20);
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}', to_jsonb(v_dis))
     WHERE name = v_moi;
  END IF;
  v_taux := greatest(0, least(v_cap, round(v_base + 2 * coalesce((m.stats ->> v_stat)::numeric, 8)
              + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - v_per / 2)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux / 2.0 THEN v_palier := 'totale'; v_pv := 0; v_reussi := true;
  ELSIF v_roll <= v_taux THEN v_palier := 'partielle'; v_pv := 25; v_reussi := true;
  ELSIF v_roll <= v_taux + (100 - v_taux) / 2.0 THEN v_palier := 'echec_partiel'; v_pv := 50; v_reussi := false;
  ELSE v_palier := 'echec_total'; v_pv := NULL; v_reussi := false; END IF;

  IF v_pj AND v_pv IS NOT NULL THEN
    UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), v_pv) WHERE name = p_cible;
    PERFORM public.mail_systeme_poser_interne('Événement', p_cible, 'Agression',
      'Vous avez été agressé(e). ' || CASE WHEN v_pv = 0 THEN 'Vous êtes hors de combat.' ELSE 'Vous êtes blessé(e).' END,
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  END IF;
  IF v_reussi THEN
    PERFORM public.crime_tracer_interne(v_moi, 'assassinat', p_cible);
    v_repere := public.crime_detecter_interne(v_moi, 'assassiner_' || p_mode, true);
  ELSE
    PERFORM public.crime_rechercher_interne(v_moi, 'tentative_assassinat', 'crime');
    v_repere := true;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'palier', v_palier, 'taux', v_taux, 'jet', v_roll,
    'repere', v_repere, 'dis', v_dis, 'cible_pj', v_pj) || jsonb_build_object('paie', v_paie);
END; $function$;

CREATE OR REPLACE FUNCTION public.crime_incendier(p_nom_batiment text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_jours integer := 0; v_repere boolean; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, career INTO m FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_nom := left(coalesce(nullif(btrim(p_nom_batiment), ''), m.current_building), 80);
  v_paie := public.payer_ordre(v_moi, 'incendier', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, 30 + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city)
            - CASE WHEN m.current_building IN ('palais-presidentiel','palais-gouvernement','assemblee','tribunal','commissariat',
                                               'banque-nationale','banque-privee','mairie-capitale','mairie') THEN 30 ELSE 0 END);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux * 0.5 THEN v_jours := 3; ELSIF v_roll <= v_taux * 0.8 THEN v_jours := 2; ELSIF v_roll <= v_taux THEN v_jours := 1; END IF;
  IF v_jours > 0 THEN
    INSERT INTO public.batiments_fermes (pays, ville, batiment_id, duree_jours, motif, auteur, jour_fin)
    VALUES (m.country, m.current_city, m.current_building, v_jours, 'incendie', v_moi, 0);
    PERFORM public.annonce_publique_interne(m.country, 'INCENDIE : ' || v_nom || ' ravagé par les flammes. Fermé ' || v_jours || ' jour(s).');
  END IF;
  v_repere := public.crime_detecter_interne(v_moi, 'incendier', false);
  IF NOT v_repere AND v_jours > 0 THEN PERFORM public.crime_tracer_interne(v_moi, 'incendier', m.current_building); END IF;
  RETURN jsonb_build_object('ok', true, 'jours', v_jours, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll) || jsonb_build_object('paie', v_paie);
END; $function$;

CREATE OR REPLACE FUNCTION public.crime_explosifs(p_nom_batiment text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_pos integer; v_taux integer; v_roll integer; v_reussi boolean;
  v_repere boolean; v_nom text; v_victimes text[] := ARRAY[]::text[]; v_v record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, career, inventory INTO m
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  SELECT (o.ord - 1)::integer INTO v_pos
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(item, ord)
   WHERE o.item ->> 'type' = 'explosif' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'explosif_manquant'); END IF;
  v_nom := left(coalesce(nullif(btrim(p_nom_batiment), ''), m.current_building), 80);
  v_paie := public.payer_ordre(v_moi, 'utiliser_explosifs', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = v_moi;

  v_taux := greatest(5, 35 + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city)
            - CASE WHEN m.current_building IN ('palais-presidentiel','palais-gouvernement','assemblee','tribunal','commissariat',
                                               'banque-nationale','banque-privee','mairie-capitale','mairie') THEN 30 ELSE 0 END);
  v_roll := floor(random() * 100)::integer + 1;
  v_reussi := v_roll <= v_taux;
  IF v_reussi THEN
    INSERT INTO public.batiments_fermes (pays, ville, batiment_id, duree_jours, motif, auteur, jour_fin)
    VALUES (m.country, m.current_city, m.current_building, 5, 'explosifs', v_moi, 0);
    FOR v_v IN SELECT name FROM public.personnages_donnees
                WHERE country = m.country AND current_city = m.current_city AND current_building = m.current_building
                  AND current_room IS NOT DISTINCT FROM m.current_room AND name <> v_moi FOR UPDATE LOOP
      UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), 15) WHERE name = v_v.name;
      PERFORM public.mail_systeme_poser_interne('Événement', v_v.name, 'Explosion !',
        'Une explosion s''est produite dans la pièce où vous vous trouviez. Vous êtes gravement blessé(e).',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
      v_victimes := v_victimes || v_v.name;
    END LOOP;
    PERFORM public.annonce_publique_interne(m.country, 'EXPLOSION : ' || v_nom || ' dévasté par un attentat à l''explosif. Fermé 5 jours.'
      || CASE WHEN array_length(v_victimes, 1) > 0 THEN ' ' || array_length(v_victimes, 1) || ' blessé(s).' ELSE '' END);
    v_repere := public.crime_detecter_interne(v_moi, 'utiliser_explosifs', false);
    IF NOT v_repere THEN PERFORM public.crime_tracer_interne(v_moi, 'utiliser_explosifs', m.current_building); END IF;
  ELSE
    PERFORM public.crime_rechercher_interne(v_moi, 'utiliser_explosifs', 'crime');
    v_repere := true;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'repere', v_repere, 'victimes', to_jsonb(v_victimes),
    'taux', v_taux, 'jet', v_roll, 'inventaire', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))
    || jsonb_build_object('paie', v_paie);
END; $function$;

REVOKE ALL ON FUNCTION public.crime_malus_isn_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_neutraliser(text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_neutraliser(text, text, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_incendier(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_incendier(text) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_explosifs(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_explosifs(text) TO authenticated;

-- Les portes ouvertes a tous se ferment.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.impact_deposer(text,text,text,integer,text)'::regprocedure);
  IF position('hp_set_par_le_serveur' IN v_def) = 0 THEN
    v_def := replace(v_def, E'  IF p_indice = ''hp_set'' THEN\n',
      E'  IF p_indice = ''hp_set'' THEN\n'
      || E'    -- 27/10/2026 : les degats sont poses par crime_neutraliser et crime_explosifs.\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''hp_set_par_le_serveur'');\n');
    IF position('hp_set_par_le_serveur' IN v_def) = 0 THEN RAISE EXCEPTION 'impact_deposer : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
DROP POLICY IF EXISTS "fermeture inscrite en son propre nom" ON public.batiments_fermes;
REVOKE INSERT, UPDATE, DELETE ON public.batiments_fermes FROM anon, authenticated;
