-- Diagnostic ciblé à exécuter par l'intégrateur disposant du connecteur.
-- Pas un export canonique ; pour celui-ci réutiliser outils/baseline/requetes.py.
-- Aucune ligne de personnage, aucun nom de joueur, aucun compte auth lu.
-- Ne pas transformer ces droits déclarés en preuve d'exécution métier authentifiée.
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;

SELECT current_timestamp AS observe_le, current_setting('server_version') AS postgres,
       count(*) AS migrations, max(version) AS derniere_version
FROM supabase_migrations.schema_migrations;

WITH attendues(nom) AS (VALUES
 ('rue_position_lire'), ('rue_sortie_batiment_lire'), ('rue_position_enregistrer'),
 ('navigation_interieure'), ('transport_effectuer'), ('douane_controle_groupe'),
 ('crime_corrompre_douanier'), ('payer_ordre'), ('organisation_commande'),
 ('inventaire_reception_etat'), ('inventaire_sauver_revision'), ('objet_sas_deposer'),
 ('crime_voler'), ('militaire_subtiliser_tenter'), ('militaire_subtiliser'),
 ('pnj_recruter'), ('impact_deposer'), ('impact_marquer_traite'),
 ('terrain_proprietaire_muter'), ('creer_placement_national'))
SELECT a.nom, p.oid IS NOT NULL AS presente,
       CASE WHEN p.oid IS NOT NULL THEN pg_get_function_identity_arguments(p.oid) END AS signature,
       p.prosecdef AS security_definer,
       CASE WHEN p.oid IS NOT NULL THEN md5(pg_get_functiondef(p.oid)) END AS corps_md5,
       CASE WHEN p.oid IS NOT NULL THEN has_function_privilege('anon',p.oid,'EXECUTE') END AS anon_execute,
       CASE WHEN p.oid IS NOT NULL THEN has_function_privilege('authenticated',p.oid,'EXECUTE') END AS authenticated_execute,
       p.proconfig AS configuration
FROM attendues a
LEFT JOIN pg_proc p ON p.proname=a.nom AND p.pronamespace='public'::regnamespace
ORDER BY a.nom, signature;

-- Inventaire de compatibilité agrégé : ne pas supprimer les consommateurs ou
-- les anciens enregistrements sur la seule foi d'un constat daté du 31 octobre.
SELECT 'vols_en_attente' AS file, type_butin AS type, traite, count(*) AS nombre
FROM public.vols_en_attente GROUP BY type_butin, traite ORDER BY type_butin, traite;
SELECT 'impacts_indices_attente' AS file, indice AS type, traite, count(*) AS nombre
FROM public.impacts_indices_attente GROUP BY indice, traite ORDER BY indice, traite;

SELECT c.relname AS objet, c.relrowsecurity AS rls, c.relforcerowsecurity AS force_rls,
       has_table_privilege('authenticated',c.oid,'INSERT') AS authenticated_insert,
       has_table_privilege('authenticated',c.oid,'UPDATE') AS authenticated_update,
       has_table_privilege('authenticated',c.oid,'DELETE') AS authenticated_delete
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('personnages_donnees','personnages','vols_en_attente','impacts_indices_attente','pnj_membres')
ORDER BY c.relname;

SELECT tablename, policyname, cmd, roles,
       md5(coalesce(qual,'') || '|' || coalesce(with_check,'')) AS expression_md5
FROM pg_policies WHERE schemaname='public' AND tablename IN
 ('personnages_donnees','vols_en_attente','impacts_indices_attente','pnj_membres')
ORDER BY tablename, policyname;

ROLLBACK;
