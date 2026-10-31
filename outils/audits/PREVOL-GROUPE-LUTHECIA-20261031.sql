-- Luthécia / PR #219 : prévol vivant groupé, strictement LECTURE SEULE.
-- Exécuter sur Supabase avant toute fusion/migration ; ne prouve PAS la compatibilité
-- des 89 migrations et des cinq commandes orga sans comparaison des corps.
-- Les noms canoniques du registre comptent davantage que les horodatages des fichiers.
SELECT COUNT(*) AS migrations_total, MAX(version) AS derniere_version
FROM supabase_migrations.schema_migrations;

SELECT version,name FROM supabase_migrations.schema_migrations
WHERE name SIMILAR TO '%(avis_personnels_expediteurs_declares|placement_helvetia_gain_unique|squatteurs_issue_combat)%'
ORDER BY version;

SELECT COUNT(*) AS couts_total,
       COUNT(DISTINCT (fn,pa,cost)) AS couts_distincts
FROM public.ordres_couts;

SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS signature,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
       md5(pg_get_functiondef(p.oid)) AS corps_md5
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
AND p.proname IN (
 'payer_ordre','inventaire_sauver_revision','banque_nationale_mouvement',
 'resoudre_placement_helvetia',
 'organisation_commande_administrative','organisation_commande_evenement',
 'organisation_commande_membres','organisation_equipement_acheter',
 'organisation_equipements_etat','organisation_equipement_deplacer',
 'organisation_equipements_payeurs'
)
ORDER BY p.proname;

SELECT c.relname, c.relrowsecurity AS rls_active,
       has_table_privilege('authenticated',c.oid,'INSERT') AS client_insert,
       has_table_privilege('authenticated',c.oid,'UPDATE') AS client_update,
       has_table_privilege('authenticated',c.oid,'DELETE') AS client_delete
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public'
AND c.relname IN ('organisations','budgets_clubs','comptes_bancaires')
ORDER BY c.relname;

SELECT c.relname,t.tgname,t.tgenabled
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname='personnages_donnees' AND NOT t.tgisinternal
ORDER BY t.tgname;
