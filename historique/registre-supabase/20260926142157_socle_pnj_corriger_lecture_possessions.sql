-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926142157
-- Nom original      : socle_pnj_corriger_lecture_possessions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:21:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2d900720cd7c7cbaf4becc23306e6ff2
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
-- CORRECTIF : jsonb_agg ne peut pas contenir row_number() OVER (...).
-- La premiere version etait du SQL invalide, accepte a la CREATION parce que PL/pgSQL ne
-- valide le corps des requetes qu'a l'EXECUTION -- meme piege que l'identifiant fictif de
-- pnj_miroir_compagnie. Elle echouait a l'appel avec
--   42803 aggregate function calls cannot contain window function calls
-- On numerote dans une sous-requete, puis on agrege.
CREATE OR REPLACE FUNCTION public.pnj_possessions_lire(p_pnj text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_commander(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  RETURN jsonb_build_object('ok', true,
    'liquide', (SELECT liquide FROM public.pnj_membres WHERE id = p_pnj),
    'possessions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('index', t.rang, 'objet', t.objet) ORDER BY t.rang)
        FROM (SELECT (row_number() OVER (ORDER BY p.id)) - 1 AS rang, p.objet
                FROM public.pnj_possessions p WHERE p.pnj_id = p_pnj) t
    ), '[]'::jsonb));
END; $$;

-- Meme prudence sur mon_inventaire : on verifie qu'elle s'execute reellement.
CREATE OR REPLACE FUNCTION public.pnj_mon_inventaire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'inventaire', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('index', t.rang, 'objet', t.v) ORDER BY t.rang)
        FROM (SELECT (row_number() OVER ()) - 1 AS rang, value AS v
                FROM public.personnages_donnees d,
                     jsonb_array_elements(COALESCE(d.inventory,'[]'::jsonb))
               WHERE d.name = v_moi) t
    ), '[]'::jsonb));
END; $$;

REVOKE ALL ON FUNCTION public.pnj_possessions_lire(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_mon_inventaire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_possessions_lire(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_mon_inventaire() TO authenticated, service_role;