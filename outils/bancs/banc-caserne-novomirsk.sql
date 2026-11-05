-- Banc annulé de la migration 20261105200000 (caserne de Novomirsk en ville). Attendu : erreur 'banc_ok'.
BEGIN;
-- Caserne centrale de Novomirsk : la caserne du socle, EN VILLE (Claude, 05/11/2026, décision de Fred).
-- En Républia (et chez les autres empires), la caserne est une zone spéciale hors des villes
-- (ville 'caserne', taxi depuis le Centre multimodal). En Sovarka, elle est dans Novomirsk, avec
-- deux entrées sur la rue (vues 11 et 12). Les fonctions militaires ne regardent que le bâtiment
-- ('caserne-militaire') : elles valent telles quelles. Seuls cinq endroits envoyaient un PJ ou un
-- soldat vers la ville 'caserne' en dur ; ils demandent désormais OÙ est la caserne du pays.
-- Idempotente : chaque patch vérifie son propre état.

-- Où est la caserne d'un pays : la ville déclarée dans la navigation, une vraie ville si le pays
-- en a une (Sovarka), sinon la zone 'caserne' (Républia et les autres).
CREATE OR REPLACE FUNCTION public.caserne_ville(p_pays text)
RETURNS text LANGUAGE sql STABLE SET search_path TO 'public' AS $f$
  SELECT coalesce((SELECT n.ville FROM public.navigation_lieux_regles n
                    WHERE n.pays = p_pays AND n.batiment = 'caserne-militaire' AND n.pieces ? 'corps_garde'
                    ORDER BY (n.ville = 'caserne'), n.ville LIMIT 1), 'caserne');
$f$;

-- Nœud de rue d'une caserne en ville (NULL pour une zone hors ville). Avec deux entrées, la plus
-- haute vue : à Novomirsk 'novomirsk-vue-12', qui est aussi la sortie canonique côté écran.
CREATE OR REPLACE FUNCTION public.caserne_noeud(p_pays text)
RETURNS text LANGUAGE sql STABLE SET search_path TO 'public' AS $f$
  SELECT max(r.noeud) FROM public.rue_sorties_batiments r
   WHERE r.country = p_pays AND r.city = public.caserne_ville(p_pays) AND r.building = 'caserne-militaire';
$f$;

REVOKE ALL ON FUNCTION public.caserne_ville(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.caserne_noeud(text) FROM PUBLIC, anon, authenticated;

-- La caserne de Sovarka passe de la zone 'caserne' à Novomirsk (mêmes sept pièces).
UPDATE public.navigation_lieux_regles SET ville = 'capitale'
 WHERE pays = 'soviet' AND ville = 'caserne' AND batiment = 'caserne-militaire';

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-11', 'caserne-militaire'),
  ('soviet', 'capitale', 'novomirsk-vue-12', 'caserne-militaire')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.patcher(p_fn regprocedure, p_ancien text, p_nouveau text)
RETURNS void LANGUAGE plpgsql AS $p$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef(p_fn);
  IF position(p_nouveau IN v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, p_ancien, p_nouveau);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique sur % : fragment absent', p_fn; END IF;
  EXECUTE v_new;
END $p$;

-- 1. Incorporation différée à la fin d'une peine (mobilisation nationale).
SELECT pg_temp.patcher('public.detention_clore_interne(text,text,integer)'::regprocedure,
  $a$AND n.ville = 'caserne' AND n.batiment = 'caserne-militaire'$a$,
  $n$AND n.ville = public.caserne_ville(v_pays_inc) AND n.batiment = 'caserne-militaire'$n$);
SELECT pg_temp.patcher('public.detention_clore_interne(text,text,integer)'::regprocedure,
  $a$SET current_city = 'caserne', current_building$a$,
  $n$SET current_city = public.caserne_ville(v_pays_inc), current_building$n$);
SELECT pg_temp.patcher('public.detention_clore_interne(text,text,integer)'::regprocedure,
  $a$current_room = 'corps_garde', current_street = NULL,$a$,
  $n$current_room = 'corps_garde', current_street = public.caserne_noeud(v_pays_inc),$n$);

-- 2. Incorporation choisie quand le motif de détention s'éteint.
SELECT pg_temp.patcher('public.detention_clore_motif_eteint(text)'::regprocedure,
  $a$n.pays = d.country WHERE n.ville = 'caserne'$a$,
  $n$n.pays = d.country WHERE n.ville = public.caserne_ville(d.country)$n$);
SELECT pg_temp.patcher('public.detention_clore_motif_eteint(text)'::regprocedure,
  $a$SET current_city = 'caserne', current_building$a$,
  $n$SET current_city = public.caserne_ville(country), current_building$n$);
SELECT pg_temp.patcher('public.detention_clore_motif_eteint(text)'::regprocedure,
  $a$current_room = 'corps_garde', current_street = NULL,$a$,
  $n$current_room = 'corps_garde', current_street = public.caserne_noeud(country),$n$);

-- 3. Soldat neutralisé (non mutin) : ramené à l'infirmerie de SA caserne.
SELECT pg_temp.patcher('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)'::regprocedure,
  $a$SET current_city = 'caserne', current_building = 'caserne-militaire',$a$,
  $n$SET current_city = public.caserne_ville(country), current_street = public.caserne_noeud(country), current_building = 'caserne-militaire',$n$);

-- 4. Position de repli par défaut d'un groupe en bataille.
SELECT pg_temp.patcher('public.militaire_bataille_groupes_constituer(bigint)'::regprocedure,
  $a$jsonb_build_object('ville', 'caserne', 'batiment', 'caserne-militaire',$a$,
  $n$jsonb_build_object('ville', public.caserne_ville((SELECT b0.pays FROM public.batailles b0 WHERE b0.id = e.bataille_id)), 'batiment', 'caserne-militaire',$n$);

-- 5. Soldats PNJ d'une nouvelle compagnie : postés au corps de garde de la caserne du pays.
SELECT pg_temp.patcher('public.militaire_compagnie_creer()'::regprocedure,
  $a$'ville', 'caserne', 'buildingId', 'caserne-militaire'$a$,
  $n$'ville', public.caserne_ville(v_pays), 'buildingId', 'caserne-militaire'$n$);

DO $$
BEGIN
  IF public.caserne_ville('soviet') <> 'capitale' OR public.caserne_ville('republic') <> 'caserne'
     OR public.caserne_noeud('soviet') <> 'novomirsk-vue-12' OR public.caserne_noeud('republic') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
                 WHERE s.nspname = 'public'
                   AND p.proname IN ('detention_clore_interne', 'detention_clore_motif_eteint',
                                     'militaire_bataille_neutralisation_terminale_interne',
                                     'militaire_bataille_groupes_constituer', 'militaire_compagnie_creer')
                   AND (pg_get_functiondef(p.oid) LIKE '%current_city = ''caserne''%'
                        OR pg_get_functiondef(p.oid) LIKE '%''ville'', ''caserne''%'
                        OR pg_get_functiondef(p.oid) LIKE '%n.ville = ''caserne''%')) THEN
    RAISE EXCEPTION 'caserne_novomirsk_incomplete';
  END IF;
END $$;
-- Rejeu : idempotente.
-- Caserne centrale de Novomirsk : la caserne du socle, EN VILLE (Claude, 05/11/2026, décision de Fred).
-- En Républia (et chez les autres empires), la caserne est une zone spéciale hors des villes
-- (ville 'caserne', taxi depuis le Centre multimodal). En Sovarka, elle est dans Novomirsk, avec
-- deux entrées sur la rue (vues 11 et 12). Les fonctions militaires ne regardent que le bâtiment
-- ('caserne-militaire') : elles valent telles quelles. Seuls cinq endroits envoyaient un PJ ou un
-- soldat vers la ville 'caserne' en dur ; ils demandent désormais OÙ est la caserne du pays.
-- Idempotente : chaque patch vérifie son propre état.

-- Où est la caserne d'un pays : la ville déclarée dans la navigation, une vraie ville si le pays
-- en a une (Sovarka), sinon la zone 'caserne' (Républia et les autres).
CREATE OR REPLACE FUNCTION public.caserne_ville(p_pays text)
RETURNS text LANGUAGE sql STABLE SET search_path TO 'public' AS $f$
  SELECT coalesce((SELECT n.ville FROM public.navigation_lieux_regles n
                    WHERE n.pays = p_pays AND n.batiment = 'caserne-militaire' AND n.pieces ? 'corps_garde'
                    ORDER BY (n.ville = 'caserne'), n.ville LIMIT 1), 'caserne');
$f$;

-- Nœud de rue d'une caserne en ville (NULL pour une zone hors ville). Avec deux entrées, la plus
-- haute vue : à Novomirsk 'novomirsk-vue-12', qui est aussi la sortie canonique côté écran.
CREATE OR REPLACE FUNCTION public.caserne_noeud(p_pays text)
RETURNS text LANGUAGE sql STABLE SET search_path TO 'public' AS $f$
  SELECT max(r.noeud) FROM public.rue_sorties_batiments r
   WHERE r.country = p_pays AND r.city = public.caserne_ville(p_pays) AND r.building = 'caserne-militaire';
$f$;

REVOKE ALL ON FUNCTION public.caserne_ville(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.caserne_noeud(text) FROM PUBLIC, anon, authenticated;

-- La caserne de Sovarka passe de la zone 'caserne' à Novomirsk (mêmes sept pièces).
UPDATE public.navigation_lieux_regles SET ville = 'capitale'
 WHERE pays = 'soviet' AND ville = 'caserne' AND batiment = 'caserne-militaire';

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-11', 'caserne-militaire'),
  ('soviet', 'capitale', 'novomirsk-vue-12', 'caserne-militaire')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.patcher(p_fn regprocedure, p_ancien text, p_nouveau text)
RETURNS void LANGUAGE plpgsql AS $p$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef(p_fn);
  IF position(p_nouveau IN v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, p_ancien, p_nouveau);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique sur % : fragment absent', p_fn; END IF;
  EXECUTE v_new;
END $p$;

-- 1. Incorporation différée à la fin d'une peine (mobilisation nationale).
SELECT pg_temp.patcher('public.detention_clore_interne(text,text,integer)'::regprocedure,
  $a$AND n.ville = 'caserne' AND n.batiment = 'caserne-militaire'$a$,
  $n$AND n.ville = public.caserne_ville(v_pays_inc) AND n.batiment = 'caserne-militaire'$n$);
SELECT pg_temp.patcher('public.detention_clore_interne(text,text,integer)'::regprocedure,
  $a$SET current_city = 'caserne', current_building$a$,
  $n$SET current_city = public.caserne_ville(v_pays_inc), current_building$n$);
SELECT pg_temp.patcher('public.detention_clore_interne(text,text,integer)'::regprocedure,
  $a$current_room = 'corps_garde', current_street = NULL,$a$,
  $n$current_room = 'corps_garde', current_street = public.caserne_noeud(v_pays_inc),$n$);

-- 2. Incorporation choisie quand le motif de détention s'éteint.
SELECT pg_temp.patcher('public.detention_clore_motif_eteint(text)'::regprocedure,
  $a$n.pays = d.country WHERE n.ville = 'caserne'$a$,
  $n$n.pays = d.country WHERE n.ville = public.caserne_ville(d.country)$n$);
SELECT pg_temp.patcher('public.detention_clore_motif_eteint(text)'::regprocedure,
  $a$SET current_city = 'caserne', current_building$a$,
  $n$SET current_city = public.caserne_ville(country), current_building$n$);
SELECT pg_temp.patcher('public.detention_clore_motif_eteint(text)'::regprocedure,
  $a$current_room = 'corps_garde', current_street = NULL,$a$,
  $n$current_room = 'corps_garde', current_street = public.caserne_noeud(country),$n$);

-- 3. Soldat neutralisé (non mutin) : ramené à l'infirmerie de SA caserne.
SELECT pg_temp.patcher('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)'::regprocedure,
  $a$SET current_city = 'caserne', current_building = 'caserne-militaire',$a$,
  $n$SET current_city = public.caserne_ville(country), current_street = public.caserne_noeud(country), current_building = 'caserne-militaire',$n$);

-- 4. Position de repli par défaut d'un groupe en bataille.
SELECT pg_temp.patcher('public.militaire_bataille_groupes_constituer(bigint)'::regprocedure,
  $a$jsonb_build_object('ville', 'caserne', 'batiment', 'caserne-militaire',$a$,
  $n$jsonb_build_object('ville', public.caserne_ville((SELECT b0.pays FROM public.batailles b0 WHERE b0.id = e.bataille_id)), 'batiment', 'caserne-militaire',$n$);

-- 5. Soldats PNJ d'une nouvelle compagnie : postés au corps de garde de la caserne du pays.
SELECT pg_temp.patcher('public.militaire_compagnie_creer()'::regprocedure,
  $a$'ville', 'caserne', 'buildingId', 'caserne-militaire'$a$,
  $n$'ville', public.caserne_ville(v_pays), 'buildingId', 'caserne-militaire'$n$);

DO $$
BEGIN
  IF public.caserne_ville('soviet') <> 'capitale' OR public.caserne_ville('republic') <> 'caserne'
     OR public.caserne_noeud('soviet') <> 'novomirsk-vue-12' OR public.caserne_noeud('republic') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
                 WHERE s.nspname = 'public'
                   AND p.proname IN ('detention_clore_interne', 'detention_clore_motif_eteint',
                                     'militaire_bataille_neutralisation_terminale_interne',
                                     'militaire_bataille_groupes_constituer', 'militaire_compagnie_creer')
                   AND (pg_get_functiondef(p.oid) LIKE '%current_city = ''caserne''%'
                        OR pg_get_functiondef(p.oid) LIKE '%''ville'', ''caserne''%'
                        OR pg_get_functiondef(p.oid) LIKE '%n.ville = ''caserne''%')) THEN
    RAISE EXCEPTION 'caserne_novomirsk_incomplete';
  END IF;
END $$;
DO $$
DECLARE v jsonb;
BEGIN
  -- Les fonctions patchées se compilent et s'exécutent (bataille inexistante : aucun groupe).
  PERFORM public.militaire_bataille_groupes_constituer(-1);
  IF (SELECT count(*) FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND batiment = 'caserne-militaire') <> 1
     OR (SELECT count(*) FROM public.rue_sorties_batiments WHERE country = 'soviet' AND building = 'caserne-militaire') <> 2
     OR EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'republic' AND batiment = 'caserne-militaire' AND ville <> 'caserne') THEN
    RAISE EXCEPTION 'banc_ko';
  END IF;
END $$;
DO $$ BEGIN RAISE EXCEPTION 'banc_ok'; END $$;
ROLLBACK;
