-- #94 : lecture seule. Aucune requete ci-dessous n'execute une fonction metier.
BEGIN;
SET TRANSACTION READ ONLY;
-- Definitions vivantes et droits, y compris dependances non remplacees par la migration.
SELECT p.oid::regprocedure::text AS signature, l.lanname AS langage,p.prosecdef,p.proconfig,
 md5(p.prosrc) AS empreinte_corps, pg_get_functiondef(p.oid) AS definition,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
WHERE n.nspname='public' AND p.proname IN
 ('payer_ordre','terrain_permis_acte','terrain_permis_deposer','mon_personnage','exiger_acteur',
 'titulaire_est_moi','jour_de_jeu_pays','terrain_etat_verrouiller_interne','terrain_etat_fusionner_interne',
 'objet_sas_deposer','chantier_commande','chantier_jour_transactionnel') ORDER BY 1;
-- Structures exactes : la migration ne convertit aucun solde ni aucun terrain historique.
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('personnages_donnees','comptes_bancaires','terrains_etat',
 'dossiers_urbanisme','objets_recus','ordres_couts','permis_depots_recus','permis_transactions_internes')
 AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE NOT t.tgisinternal AND c.relnamespace='public'::regnamespace AND c.relname IN
 ('personnages_donnees','comptes_bancaires','terrains_etat','dossiers_urbanisme','objets_recus') ORDER BY 1,2;
SELECT * FROM pg_policies WHERE schemaname='public' AND tablename IN
 ('terrains_etat','dossiers_urbanisme','objets_recus','permis_depots_recus','permis_transactions_internes');
SELECT fn,pa,cost FROM public.ordres_couts WHERE fn='deposer_demande_permis';
-- Compromis : uniquement des agregats ; aucune identite ou finance individuelle exportee.
WITH terrains AS (SELECT country,public.terrain_etat_lire(data) AS etat FROM public.terrains_etat)
SELECT country,count(*) AS terrains,
 count(*) FILTER(WHERE etat->>'compromis'='true') AS compromis,
 count(*) FILTER(WHERE etat->>'compromis'='true' AND
  (jsonb_typeof(etat->'compromisExpireAt') IS DISTINCT FROM 'number' OR nullif(etat->>'compromisPar','') IS NULL)) AS compromis_a_examiner,
 count(*) FILTER(WHERE etat->>'permis' IS NOT NULL AND jsonb_typeof(etat->'permis') IS DISTINCT FROM 'object') AS permis_format_inattendu
FROM terrains GROUP BY country;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE name ILIKE '%chantier%' OR name ILIKE '%construction%' OR name ILIKE '%permis%' ORDER BY version;
ROLLBACK;
