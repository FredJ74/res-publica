-- Mission de nuit du 26/11/2026 (Claude), étape 1 — APPLIQUÉE en production le 26/11/2026 à 23 h 02 (registre 20261126230215), contrôlée en lecture.
-- SUPPRESSION DE L'ORDRE « CONTREBANDE PORTUAIRE » (décision de Fred du 26/11/2026). L'ordre faisait payer 3 PA pour une
-- « Cargaison de contrebande » invendable. La contrebande se joue désormais par fausse déclaration au fret du port
-- (GAME-DESIGN-DOUANES.md) : « Corrompre un douanier », l'inspection des caisses de fret et les amendes de fausse
-- déclaration ne sont pas touchés.
-- Relevé en lecture le 26/11 avant écriture :
--   • seules crime_contrebande et ordres_chances_audit_interne citent l'ordre ; seule ordres_chances_audit_interne appelle
--     crim_contrebande_taux_interne (une ligne WHEN, retirée ici par remplacement contrôlé, marque contrebande_supprimee_v1) ;
--   • 0 objet de type « contrebande » en inventaire (retirés ci-dessous s'il en apparaît d'ici l'application) ;
--   • 0 affaire, 0 alias, 0 acte de dossier sur l'infraction contrebande_port : la ligne du barème est retirée avec l'ordre.
--
-- Contrôles en lecture après application :
--   SELECT to_regprocedure('public.crime_contrebande(integer,integer)') IS NULL
--      AND to_regprocedure('public.crim_contrebande_taux_interne(text)') IS NULL
--      AND to_regprocedure('public.crim_contrebande_gain_interne(text)') IS NULL;                                    -- vrai
--   SELECT position('contrebande_supprimee_v1' in pg_get_functiondef('public.ordres_chances_audit_interne(text,text)'::regprocedure)) > 0
--      AND position('contrebande_port' in pg_get_functiondef('public.ordres_chances_audit_interne(text,text)'::regprocedure)) = 0;  -- vrai
--   SELECT (SELECT count(*) FROM public.crim_parametres WHERE cle IN ('contrebande_gain', 'contrebande_gain_soviet'))
--        + (SELECT count(*) FROM public.ordres_couts WHERE fn = 'contrebande_port')
--        + (SELECT count(*) FROM public.infractions WHERE id = 'contrebande_port');                                    -- 0
--   SELECT count(*) FROM public.ordres_couts WHERE fn = 'contrebande_poissonniere';                                   -- 1 (autre ordre, conservé)
BEGIN;

-- 1. ordres_chances_audit_interne : la ligne de l'ordre disparaît (remplacement contrôlé de la définition de production).
DO $retrait$
DECLARE d text := pg_get_functiondef('public.ordres_chances_audit_interne(text,text)'::regprocedure);
        ligne text := E'    WHEN ''contrebande_port'' THEN RETURN greatest(0, public.crim_contrebande_taux_interne(a) - coalesce(public.securite_malus_lieu_interne(a), 0));\n';
BEGIN
  IF position('contrebande_supprimee_v1' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, ligne, ''))) / length(ligne) <> 1 THEN
    RAISE EXCEPTION 'ordres_chances_audit_interne : ligne contrebande_port introuvable ou multiple (version de production inattendue)';
  END IF;
  EXECUTE replace(d, ligne, E'    /* contrebande_supprimee_v1 : ordre Contrebande portuaire supprimé (Fred, 26/11/2026) */\n');
  IF position('contrebande_port' IN pg_get_functiondef('public.ordres_chances_audit_interne(text,text)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'ordres_chances_audit_interne : contrebande_port encore cité après remplacement';
  END IF;
END $retrait$;

-- 2. Les trois fonctions de l'ordre.
DROP FUNCTION IF EXISTS public.crime_contrebande(integer, integer);
DROP FUNCTION IF EXISTS public.crim_contrebande_taux_interne(text);
DROP FUNCTION IF EXISTS public.crim_contrebande_gain_interne(text);

-- 3. Réglages, coût et barème de l'ordre.
DELETE FROM public.crim_parametres WHERE cle IN ('contrebande_gain', 'contrebande_gain_soviet');
DELETE FROM public.ordres_couts WHERE fn = 'contrebande_port';
DELETE FROM public.infractions WHERE id = 'contrebande_port'
  AND NOT EXISTS (SELECT 1 FROM public.infractions_alias a WHERE to_jsonb(a)::text LIKE '%"contrebande_port"%')
  AND NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes x WHERE to_jsonb(x)::text LIKE '%"contrebande_port"%');

-- 4. Cargaisons de contrebande en inventaire (0 au 26/11) : retirées si l'ordre en a produit d'ici l'application.
UPDATE public.personnages_donnees d
   SET inventory = (SELECT coalesce(jsonb_agg(i ORDER BY o), '[]'::jsonb)
                      FROM jsonb_array_elements(d.inventory) WITH ORDINALITY AS t(i, o) WHERE i ->> 'type' IS DISTINCT FROM 'contrebande'),
       inventory_revision = coalesce(d.inventory_revision, 0) + 1
 WHERE jsonb_typeof(d.inventory) = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(d.inventory) i WHERE i ->> 'type' = 'contrebande');

COMMIT;
