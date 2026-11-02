-- APPLIQUEE le 03/11/2026 vers 00 h 40 par Claude (registre securite_dissuasion_hommes_armes_20261103003000,
-- version 20261102233900), apres le banc annule outils/bancs/banc-securite-dissuasion.sql joue en production.
-- 3 novembre 2026 -- #135, socle 2 de la securite privee : LA DISSUASION.
--
-- Decision de Fred (27/10, AGENTS.md) : « l'agent present impose les malus de securite applicables ».
-- Decision de Fred (03/11, GAME-DESIGN-SECURITE-PRIVEE-135.md) : pour un acte illegal commis sous
-- les yeux d'hommes armes, le malus fait LES DEUX : l'acte reussit moins souvent ET l'auteur est
-- plus souvent repere.
--
-- Le malus n'est pas invente : c'est la regle de groupe existante du jeu, min(40, 10 + hommes),
-- celle du detachement militaire en mission `securiser` et de la Garde republicaine (migration
-- 20261010234412). Elle etait appliquee par le navigateur (state.malusSecuriteMilitaire) et s'est
-- perdue quand les ordres sont passes au serveur (20261027010000 : « aucune source serveur »).
-- Elle revient ici, au serveur, et compte desormais aussi les agents de securite privee :
--   hommes = agents prives presents (hors ceux de l'auteur, lus par
--            securite_agents_prives_presents_interne, le meme lecteur que la detection policiere)
--          + soldats d'une section en mission `securiser` dans la piece (hors ceux qui suivent l'auteur)
--          + gardes republicains du poste (garde_republicaine_piece)
--   malus  = 0 si personne, sinon min(40, 10 + hommes) -- applique UNE fois, jamais empile.
--
-- Raccordements (patchs en place de fragments verifies sur la production, pas de reecriture) :
--   . crime_detecter_interne : taux de detection + malus (plafond 100) -- detection commune de
--     tous les actes illegaux qui l'appellent.
--   . jet de reussite + malus (le jet monte, l'acte rate plus) : contrebande, corruption,
--     falsification, empoisonnement, explosifs, incendie, neutralisation d'un depute, achat
--     d'explosifs et d'arme au marche noir.
--   . crime_voler et crime_voler_materiaux : score - malus (leur score decide a la fois la reussite
--     et le reperage). Pour le vol de materiaux, le malus remplace l'ancien compte des
--     « vigiles du chantier » : Fred a ecarte tout statut de vigile (27/10), ce sont les agents
--     reellement presents qui comptent.
-- Idempotente (marqueur `securite_dissuasion`). Aucun acte de joueur.

CREATE OR REPLACE FUNCTION public.securite_malus_lieu_interne(p_acteur text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; v_rue text; v_hommes integer := 0; v_g jsonb;
BEGIN
  SELECT country, current_city, current_building, current_room, current_street INTO d
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR d.country IS NULL OR d.current_city IS NULL THEN RETURN 0; END IF;
  v_rue := CASE WHEN d.current_building IS NULL THEN d.current_street END;
  IF d.current_building IS NULL AND v_rue IS NULL THEN RETURN 0; END IF;

  -- Agents de securite privee presents, hors ceux qui travaillent pour l'auteur.
  v_hommes := jsonb_array_length(coalesce(public.securite_agents_prives_presents_interne(
    d.country, d.current_city, d.current_building, d.current_room, v_rue, p_acteur), '[]'::jsonb));

  IF d.current_building IS NOT NULL THEN
    -- Soldats d'une section en mission `securiser` dans la piece, hors ceux qui suivent l'auteur.
    v_hommes := v_hommes + (
      SELECT count(*)::integer
        FROM public.pnj_membres m
        JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
        JOIN public.compagnies_militaires c ON c.id = sm.compagnie_id
        CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
       WHERE m.famille = 'soldat' AND m.statut = 'actif' AND sm.en_reserve = false
         AND coalesce(m.pa, 0) > 0 AND m.pays = d.country
         AND m.leader_pj IS DISTINCT FROM p_acteur
         AND pe.ville = d.current_city AND pe.building_id = d.current_building AND pe.room_id = d.current_room
         AND EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.data -> 'sections') = 'array'
                                                             THEN c.data -> 'sections' ELSE '[]'::jsonb END) s
                      WHERE s ->> 'id' = sm.section_id AND s ->> 'mission' = 'securiser'));
    -- Gardes republicains du poste.
    v_g := public.garde_republicaine_piece(d.country, d.current_building, d.current_room);
    v_hommes := v_hommes + coalesce(CASE WHEN jsonb_typeof(v_g -> 'gardes') = 'number' THEN (v_g ->> 'gardes')::integer END, 0);
  END IF;

  RETURN CASE WHEN v_hommes > 0 THEN least(40, 10 + v_hommes) ELSE 0 END;
END; $function$;

REVOKE ALL ON FUNCTION public.securite_malus_lieu_interne(text) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  f text; n integer; r record;
  m_det text := 'v_taux := least(100, v_taux + public.securite_malus_lieu_interne(p_nom)); /* securite_dissuasion */';
BEGIN
  -- 1. Detection commune.
  f := pg_get_functiondef('public.crime_detecter_interne(text,text,boolean,text)'::regprocedure);
  IF position('securite_dissuasion' IN f) = 0 THEN
    IF position('  IF floor(random() * 100)::integer + 1 > v_taux THEN RETURN false; END IF;' IN f) = 0 THEN
      RAISE EXCEPTION 'crime_detecter_interne_definition_non_examinee';
    END IF;
    f := replace(f, '  IF floor(random() * 100)::integer + 1 > v_taux THEN RETURN false; END IF;',
                 '  ' || m_det || E'\n  IF floor(random() * 100)::integer + 1 > v_taux THEN RETURN false; END IF;');
    EXECUTE f;
  END IF;

  -- 2. Jets de reussite : le jet monte du malus (plafond 100).
  FOR r IN SELECT * FROM (VALUES
      ('public.crime_contrebande(integer,integer)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.crime_corrompre(text,integer,integer)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.crime_falsifier(text,integer,integer)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.crime_empoisonner(text)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.crime_explosifs(text)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.crime_incendier(text)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.crime_acheter_explosifs(integer,integer)', 'v_roll := floor(random() * 100)::integer + 1;', 'v_moi'),
      ('public.assemblee_neutraliser_depute(text,text,text,text)', 'v_jet    := floor(random() * 100)::integer + 1;', 'p_nom'),
      ('public.crime_acheter_arme_noire(text,text,boolean)', 'v_roll := random() * 100;', 'v_moi')
    ) AS t(sig, frag, acteur)
  LOOP
    f := pg_get_functiondef(r.sig::regprocedure);
    CONTINUE WHEN position('securite_dissuasion' IN f) > 0;
    n := (length(f) - length(replace(f, r.frag, ''))) / length(r.frag);
    IF n <> 1 THEN RAISE EXCEPTION 'jet_non_examine: % (% occurrences)', r.sig, n; END IF;
    f := replace(f, r.frag,
      split_part(r.frag, ':=', 1) || ':= least(100, ' || rtrim(trim(split_part(r.frag, ':=', 2)), ';')
      || ' + public.securite_malus_lieu_interne(' || r.acteur || ')); /* securite_dissuasion */');
    EXECUTE f;
  END LOOP;

  -- 3. Vol sur un PJ : le score baisse du malus.
  f := pg_get_functiondef('public.crime_voler(text,text,boolean,integer,integer)'::regprocedure);
  IF position('securite_dissuasion' IN f) = 0 THEN
    n := (SELECT count(*) FROM regexp_matches(f, '- v_isn / 3(\s*)\+(\s*)CASE WHEN p_benediction', 'g'));
    IF n <> 1 THEN RAISE EXCEPTION 'crime_voler_definition_non_examinee (%)', n; END IF;
    f := regexp_replace(f, '- v_isn / 3(\s*)\+(\s*)CASE WHEN p_benediction',
      '- v_isn / 3 - public.securite_malus_lieu_interne(v_moi) /* securite_dissuasion */\1+\2CASE WHEN p_benediction');
    EXECUTE f;
  END IF;

  -- 4. Vol de materiaux : le malus des hommes presents remplace l'ancien compte des vigiles.
  f := pg_get_functiondef('public.crime_voler_materiaux(text,text,integer,integer,boolean)'::regprocedure);
  IF position('securite_dissuasion' IN f) = 0 THEN
    n := (SELECT count(*) FROM regexp_matches(f, '-\s*CASE WHEN v_vig <= 0 THEN 0 ELSE 20 \+ \(v_vig - 1\) \* 10 END', 'g'));
    IF n <> 1 THEN RAISE EXCEPTION 'crime_voler_materiaux_definition_non_examinee (%)', n; END IF;
    f := regexp_replace(f, '-\s*CASE WHEN v_vig <= 0 THEN 0 ELSE 20 \+ \(v_vig - 1\) \* 10 END',
      '- public.securite_malus_lieu_interne(a.name) /* securite_dissuasion */');
    EXECUTE f;
  END IF;

  -- Preuve structurelle : douze fonctions raccordees.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
   WHERE s.nspname = 'public' AND position('securite_dissuasion' IN pg_get_functiondef(p.oid)) > 0
     AND p.proname <> 'securite_malus_lieu_interne';
  IF n <> 12 THEN RAISE EXCEPTION 'securite_dissuasion: % fonctions raccordees au lieu de 12', n; END IF;
END $$;
