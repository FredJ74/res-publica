-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922070327
-- Nom original      : renseignement_position_effective_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-22 07:03:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7de32ac332cbefdff95bf811321cbb88
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
ALTER TABLE public.agents_renseignement ADD COLUMN IF NOT EXISTS pays text;

COMMENT ON COLUMN public.agents_renseignement.pays IS
  'Pays de PRESENCE PHYSIQUE de l''agent pose. NULL tant qu''il n''a jamais ete pose. Ne jamais confondre avec pays_couverture, qui est purement narratif.';
COMMENT ON COLUMN public.agents_renseignement.pays_couverture IS
  'Pays de la COUVERTURE : tenue, faux nom, profession fictive. Aucun effet mecanique. N''est JAMAIS une localisation (arbitrage du 22 septembre 2026).';

UPDATE public.agents_renseignement
   SET pays = pays_couverture
 WHERE pays IS NULL AND ville IS NOT NULL;

DROP INDEX IF EXISTS public.idx_agents_position;
CREATE INDEX IF NOT EXISTS idx_agents_position
    ON public.agents_renseignement (pays, ville, building_id)
 WHERE statut = 'actif';

CREATE OR REPLACE FUNCTION public.agent_position_effective(p_agent_id text)
RETURNS TABLE(pays text, ville text, building_id text, room_id text, porte boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT
    CASE WHEN ag.leader_courant IS NULL THEN ag.pays        ELSE d.country          END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.ville       ELSE d.current_city     END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.building_id ELSE d.current_building END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.room_id     ELSE d.current_room     END,
    ag.leader_courant IS NOT NULL
  FROM public.agents_renseignement ag
  LEFT JOIN public.personnages_donnees d ON d.name = ag.leader_courant
  WHERE ag.id = p_agent_id;
$$;

CREATE OR REPLACE FUNCTION public.agent_au_bureau_min_def(p_bat text, p_piece text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_bat = 'palais-gouvernement' AND p_piece = 'bureau_min_def';
$$;

GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text, text) TO authenticated, service_role;