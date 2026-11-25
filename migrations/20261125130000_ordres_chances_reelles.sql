-- Mission de nuit du 25/11/2026 (Claude), bloc 4 — APPLIQUÉE en production le 25/11/2026 (feu vert de Fred, contrôlée en lecture). Après 20261125120000 (bloc 3).
-- « Vos chances réelles : X % » (décision de Fred du 24/11 au soir) : avant le clic, la chance d'un ordre est calculée par le
-- SERVEUR, par la même formule que celle qui tranche l'ordre. Aucune règle de jeu ne change.
--
-- Une seule source de vérité : chaque formule est sortie dans une fonction que l'ordre ET la lecture des chances appellent.
--   • Résolution commune (crim_resoudre_interne) : la borne finale (min, max, bonus de brouillard, dissuasion #135) devient
--     crim_taux_borne_interne ; crim_resoudre_interne l'appelle à la place de son expression en ligne (raccord vérifié).
--   • Crimes : utiliser des explosifs (crime_explosifs → crim_explosifs_brut_interne).
--   • Rumeurs : lancer une rumeur (rumeur_lancer → crim_rumeur_brut_interne).
--   • Combat : neutraliser une cible, trois modes (crime_neutraliser → crim_neutraliser_brut_interne ; la chance dépend de la
--     cible : lue avec p_cible, une fois la cible choisie).
--   • Se cacher : se_cacher_chances (existant, déjà affiché par l'écran).
--   • Vols : subtiliser des explosifs (crim_subtiliser_chance_interne du bloc 3, si sa migration est appliquée).
-- ordres_chances_lire(p_fns, p_cible) : lecture seule, pour le personnage connecté, à l'endroit où le serveur le place.
--
-- Contrôles en lecture après application :
--   SELECT position('chances_reelles_v1' in pg_get_functiondef(p::regprocedure)) > 0 FROM unnest(ARRAY[
--     'public.crim_resoudre_interne(text,text,text,jsonb)', 'public.crime_explosifs(text,uuid)',
--     'public.rumeur_lancer(text,text,text,text,integer,integer)', 'public.crime_neutraliser(text,text,uuid)']) p;   -- 4 × vrai
--   SELECT has_function_privilege('authenticated', 'public.ordres_chances_lire(text[],text)', 'EXECUTE');            -- vrai
--   SELECT has_function_privilege('anon', 'public.ordres_chances_lire(text[],text)', 'EXECUTE');                     -- faux
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder_re(p_fn regprocedure, p_motif text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  SELECT count(*) INTO n FROM regexp_matches(d, p_motif, 'g');
  IF n <> 1 THEN RAISE EXCEPTION '% : ancrage introuvable ou multiple (% occurrences)', p_fn, n; END IF;
  EXECUTE regexp_replace(d, p_motif, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Borne finale de la résolution commune (expression reprise à l'identique de crim_resoudre_interne) ──────────────
CREATE OR REPLACE FUNCTION public.crim_taux_borne_interne(p_taux numeric, p_min numeric, p_max numeric, p_brouillard jsonb, p_dis integer)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT greatest(coalesce(p_min, 0), least(coalesce(p_max, 100), p_taux
    + CASE WHEN coalesce((p_brouillard ->> 'brouillard')::boolean, false) THEN coalesce((p_brouillard ->> 'bonus_reussite')::numeric, 0) ELSE 0 END
    - coalesce(p_dis, 0)))::integer;
$$;

SELECT pg_temp.rp_raccorder_re('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $re$v_taux := greatest\(coalesce\(\(p ->> 'min'\)::numeric, 0\), least\(coalesce\(\(p ->> 'max'\)::numeric, 100\), \(p ->> 'taux'\)::numeric \+ CASE WHEN coalesce\(\(v_brouillard ->> 'brouillard'\)::boolean, false\) THEN coalesce\(\(v_brouillard ->> 'bonus_reussite'\)::numeric, 0\) ELSE 0 END /\* crim_brouillard_taux_v1 \*/ - v_dis\)\)::integer;$re$,
  $r$v_taux := public.crim_taux_borne_interne((p ->> 'taux')::numeric, (p ->> 'min')::numeric, (p ->> 'max')::numeric, v_brouillard, v_dis); /* crim_brouillard_taux_v1 */ /* chances_reelles_v1 */$r$,
  'chances_reelles_v1');

-- Chance finale vue par la résolution commune, pour un acte dont on connaît la formule brute.
CREATE OR REPLACE FUNCTION public.crim_chance_bornee_interne(p_nom text, p_brut numeric, p_min numeric, p_max numeric, p_brouillard boolean)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_b jsonb := '{}'::jsonb;
BEGIN
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF p_brouillard THEN v_b := coalesce(public.climat_brouillard_modificateurs_interne(d.country, d.current_city), '{}'::jsonb); END IF;
  RETURN public.crim_taux_borne_interne(p_brut, p_min, p_max, v_b, coalesce(public.securite_malus_lieu_interne(p_nom), 0));
END $$;

-- ── Crimes : utiliser des explosifs ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_explosifs_brut_interne(p_nom text, p_batiment text, p_mode text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_explosifs_taux_interne(public.crim_stat_interne(p_nom, 'dis', 50), public.crim_stat_interne(p_nom, 'INT', 8),
           p_mode IN ('cache', 'cache_masque'), public.crim_carriere_interne(p_nom), public.crim_batiment_officiel_interne(p_batiment));
$$;
-- crime_explosifs lit la carrière par crim_carriere_interne(name) (m.career) et v_officiel par crim_batiment_officiel_interne :
-- mêmes entrées que crim_explosifs_brut_interne.
SELECT pg_temp.rp_raccorder_re('public.crime_explosifs(text,uuid)'::regprocedure,
  $re$v_taux := public\.crim_explosifs_taux_interne\(public\.crim_stat_interne\(a, 'dis', 50\), public\.crim_stat_interne\(a, 'INT', 8\),\s+v_mode IN \('cache', 'cache_masque'\), m\.career, v_officiel\);$re$,
  $r$v_taux := public.crim_explosifs_brut_interne(a, m.current_building, v_mode); /* chances_reelles_v1 */$r$,
  'chances_reelles_v1');

-- ── Rumeurs : lancer une rumeur ──────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_rumeur_brut_interne(p_nom text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_rumeur_taux_interne(public.crim_stat_interne(p_nom, 'dis', 50), public.crim_stat_interne(p_nom, 'CHA', 8));
$$;
SELECT pg_temp.rp_raccorder_re('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure,
  $re$'taux', public\.crim_rumeur_taux_interne\(v_dis, public\.crim_stat_interne\(v_moi, 'CHA', 8\)\),$re$,
  $r$'taux', public.crim_rumeur_brut_interne(v_moi) /* chances_reelles_v1 */,$r$,
  'chances_reelles_v1');

-- ── Combat : neutraliser (mains / arme / feu), selon la cible ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_neutraliser_brut_interne(p_nom text, p_ci jsonb, p_mode text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_neutraliser_taux_interne(p_mode,
           public.crim_stat_interne(p_nom, CASE p_mode WHEN 'mains' THEN 'FOR' WHEN 'arme' THEN 'DUP' ELSE 'PER' END, 8),
           public.crim_carriere_interne(p_nom) = 'criminal_c', (p_ci ->> 'per')::numeric, public.crim_cache_interne(p_nom),
           coalesce((p_ci ->> 'pj')::boolean, false) AND public.crim_objet_porte_interne(p_ci ->> 'nom', 'gilet'));
$$;
SELECT pg_temp.rp_raccorder_re('public.crime_neutraliser(text,text,uuid)'::regprocedure,
  $re$v_taux := public\.crim_neutraliser_taux_interne\(p_mode, public\.crim_stat_interne\(a, v_stat, 8\), m\.career = 'criminal_c',\s+\(ci ->> 'per'\)::numeric, v_cache, v_gilet\);$re$,
  $r$v_taux := public.crim_neutraliser_brut_interne(a, ci, p_mode); /* chances_reelles_v1 */$r$,
  'chances_reelles_v1');

-- ── Lecture des chances (personnage connecté, lieu tenu par le serveur) ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ordres_chances_lire(p_fns text[], p_cible text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; f text; out jsonb := '{}'::jsonb; v jsonb; ci jsonb; m text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building INTO d FROM public.personnages_donnees WHERE name = a;
  FOREACH f IN ARRAY coalesce(p_fns[1:30], ARRAY[]::text[]) LOOP
    BEGIN
      IF f = 'se_cacher' THEN
        v := public.se_cacher_chances();
        IF coalesce((v ->> 'ok')::boolean, false) THEN out := out || jsonb_build_object(f, (v ->> 'taux')::integer); END IF;
      ELSIF f = 'acheter_bombe_illegale' THEN
        IF to_regprocedure('public.crim_subtiliser_chance_interne(text)') IS NOT NULL THEN
          out := out || jsonb_build_object(f, (public.crim_subtiliser_chance_interne(a) ->> 'taux')::integer);
        END IF;
      ELSIF f = 'utiliser_explosifs' THEN
        out := out || jsonb_build_object(f, public.crim_chance_bornee_interne(a,
          public.crim_explosifs_brut_interne(a, d.current_building, public.crim_mode_action_interne(a)),
          public.crim_param_interne('explosifs_min', 5), public.crim_param_interne('explosifs_max', 75), true));
      ELSIF f = 'lancer_rumeur_cible' THEN
        out := out || jsonb_build_object(f, public.crim_chance_bornee_interne(a, public.crim_rumeur_brut_interne(a),
          public.crim_param_interne('rumeur_taux_min', 10), public.crim_param_interne('rumeur_taux_max', 90), false));
      ELSIF f = 'neutraliser' AND p_cible IS NOT NULL THEN
        ci := public.crim_cible_resoudre_interne(a, p_cible);
        IF coalesce((ci ->> 'ok')::boolean, false) THEN
          v := '{}'::jsonb;
          FOREACH m IN ARRAY ARRAY['mains', 'arme', 'feu'] LOOP
            v := v || jsonb_build_object(m, public.crim_chance_bornee_interne(a, public.crim_neutraliser_brut_interne(a, ci, m), 0,
                         CASE m WHEN 'mains' THEN 65 WHEN 'arme' THEN 75 ELSE 85 END, true));
          END LOOP;
          out := out || jsonb_build_object(f, v);
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;   -- une chance illisible n'empêche jamais les autres
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'chances', out); /* chances_reelles_v1 */
END $$;

REVOKE ALL ON FUNCTION public.crim_chance_bornee_interne(text,numeric,numeric,numeric,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crim_explosifs_brut_interne(text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crim_rumeur_brut_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crim_neutraliser_brut_interne(text,jsonb,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ordres_chances_lire(text[],text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ordres_chances_lire(text[],text) TO authenticated;

COMMIT;
