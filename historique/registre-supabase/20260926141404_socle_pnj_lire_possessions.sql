-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926141404
-- Nom original      : socle_pnj_lire_possessions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:14:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5964176f39a9d312d796630ac45db563
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
-- Lecture des possessions d'un PNJ. Reservee a qui peut le commander : son administrateur
-- (proprietaire personnel ou titulaire du poste proprietaire) ou son leader courant.
CREATE OR REPLACE FUNCTION public.pnj_possessions_lire(p_pnj text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_commander(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  RETURN jsonb_build_object('ok', true, 'liquide',
      (SELECT liquide FROM public.pnj_membres WHERE id = p_pnj),
    'possessions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('index', (row_number() OVER (ORDER BY p.id)) - 1,
                                          'objet', p.objet) ORDER BY p.id)
        FROM public.pnj_possessions p WHERE p.pnj_id = p_pnj), '[]'::jsonb));
END; $$;

-- Inventaire et liquide de l'acteur, pour alimenter l'ecran DONNER sans que le client n'ait
-- a deviner ce qu'il possede.
CREATE OR REPLACE FUNCTION public.pnj_mon_inventaire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'inventaire', COALESCE((SELECT jsonb_agg(jsonb_build_object('index', o.i - 1, 'objet', o.v)
                                              ORDER BY o.i)
      FROM (SELECT row_number() OVER () AS i, value AS v
              FROM public.personnages_donnees d,
                   jsonb_array_elements(COALESCE(d.inventory,'[]'::jsonb))
             WHERE d.name = v_moi) o), '[]'::jsonb));
END; $$;

REVOKE ALL ON FUNCTION public.pnj_possessions_lire(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_mon_inventaire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_possessions_lire(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_mon_inventaire() TO authenticated, service_role;