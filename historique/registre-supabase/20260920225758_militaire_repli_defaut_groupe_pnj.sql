-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225758
-- Nom original      : militaire_repli_defaut_groupe_pnj
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:57:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 60583c79c4800e5d096ac82d23b8615c
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Un groupe mene par des PNJ n'avait aucune position de repli : la position
-- etait derivee d'un PJ du groupe, et il n'y en a pas. Consequence mesuree au
-- banc : le groupe combattait jusqu'au dernier homme, alors que l'arbitrage
-- prevoit son repli automatique a 50 % de pertes.
--
-- Le repli par defaut est la CASERNE de l'empire du groupe : c'est la
-- position canonique ou militaire_compagnie_creer pose deja tout contingent
-- neuf ('caserne' / 'caserne-militaire' / 'corps_garde'). Aucune position
-- nouvelle n'est inventee.
CREATE OR REPLACE FUNCTION public.militaire_bataille_groupes_constituer(p_bataille_id bigint)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.batailles_groupes
    (bataille_id, groupe_id, camp, compagnie_id, section_id, leader, effectif_initial, repli)
  SELECT e.bataille_id, e.groupe_id, min(e.camp), min(e.compagnie_id), min(e.section_id),
         (SELECT p.personnage FROM public.batailles_engagements p
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL
           ORDER BY CASE p.grade WHEN 'commandant' THEN 1 WHEN 'capitaine' THEN 2
                                 WHEN 'lieutenant' THEN 3 ELSE 4 END, p.id LIMIT 1),
         count(*),
         coalesce(
           (SELECT public.militaire_position_repli(p.personnage, b.ville, b.batiment, b.piece)
              FROM public.batailles_engagements p
              JOIN public.batailles b ON b.id = p.bataille_id
             WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
               AND p.personnage IS NOT NULL LIMIT 1),
           jsonb_build_object('ville', 'caserne', 'batiment', 'caserne-militaire',
                              'piece', 'corps_garde'))
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
   GROUP BY e.bataille_id, e.groupe_id
  ON CONFLICT (bataille_id, groupe_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_groupes_constituer(bigint) FROM PUBLIC, anon, authenticated;