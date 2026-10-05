-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927142259
-- Nom original      : militaire_accessoires_section_lecture_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:22:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 46a9d3ceb19ddbef7187422c44a0c5ce
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
-- LOT 4c — L'ECRAN D'EQUIPEMENT LIT LE SOCLE (27 septembre 2026)
--
-- L'ecran « Equiper les soldats » lisait `sol.accessoires` dans le blob. Une fois l'axe bascule,
-- ce tableau est un vestige gele : l'ecran aurait montre l'equipement d'avant la bascule, et le
-- bouton « Reprendre » aurait vise des objets qui ne sont plus la. C'est le seul lecteur client
-- de cet axe qui restait.
--
-- AUTORITE INCHANGEE : `militaire_section_de_moi`, c'est-a-dire le Lieutenant de CETTE section
-- dans SON empire -- exactement la meme porte que l'equipement lui-meme. On n'emprunte pas
-- `pnj_possessions_lire`, qui exige en plus la CO-PRESENCE physique : un Lieutenant doit pouvoir
-- consulter le paquetage de sa section depuis la salle de commandement, comme aujourd'hui.
CREATE OR REPLACE FUNCTION public.militaire_accessoires_section(
  p_compagnie_id text, p_section_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  RETURN jsonb_build_object('ok', true, 'portes', COALESCE((
    SELECT jsonb_object_agg(t.matricule, t.objets)
      FROM (SELECT sm.matricule,
                   jsonb_agg(jsonb_build_object('id', p.objet->>'id',
                              'name', COALESCE(p.objet->>'name', p.objet->>'nom'),
                              'produitMilitaire', p.objet->>'produitMilitaire')
                             ORDER BY p.id) AS objets
              FROM public.pnj_soldats_metier sm
              JOIN public.pnj_membres m ON m.id = sm.pnj_id
              JOIN public.pnj_possessions p ON p.pnj_id = sm.pnj_id
             WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
               AND m.statut = 'actif'
             GROUP BY sm.matricule) t
  ), '{}'::jsonb));
END; $$;

REVOKE ALL ON FUNCTION public.militaire_accessoires_section(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_accessoires_section(text,text)
  TO authenticated, service_role;