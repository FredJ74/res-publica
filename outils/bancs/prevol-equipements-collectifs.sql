-- Lecture seule : diagnostic pour l'agent disposant du connecteur autorise.
-- Ce fichier N'APPLIQUE AUCUNE migration. Aucun nom ni solde individuel extrait.
-- Completer avec les quatre extractions canoniques de WORKFLOW-SUPABASE.md.
BEGIN;
SET TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '20s';
SELECT current_database() AS base, current_setting('server_version') AS postgres;

-- Une ligne vraie est un BLOCAGE, pas une invitation a revoquer le droit :
-- les circuits legitimes de sauvegarde, election et caisse doivent etre migres avant.
SELECT role, has_column_privilege(role,'public.organisations','data','UPDATE') AS ecriture_blob_bloquante
FROM (VALUES ('authenticated'),('anon')) r(role);
SELECT polname, pg_get_expr(polqual,polrelid) AS condition,
       pg_get_expr(polwithcheck,polrelid) AS verification
FROM pg_policy WHERE polrelid='public.organisations'::regclass ORDER BY polname;

-- Empreintes et signatures vivantes : comparer aux gardes, sans les ajuster
-- pour accepter une definition qui n'a pas ete examinee.
SELECT p.oid::regprocedure::text AS signature, md5(p.prosrc) AS empreinte_corps,
       p.prosecdef AS security_definer, p.proconfig, p.proacl,
       pg_get_function_result(p.oid) AS resultat
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND (p.proname IN
 ('acheter_produit_commerce','mouvement_titulaire','appliquer_taxe_transaction',
  'mon_personnage','exiger_acteur','inventaire_reception_etat',
  'inventaire_reclamer_livraison','inventaire_sauver_revision')
 OR p.proname LIKE 'organisation_equipement%' OR p.proname IN
 ('organisation_direction_garder','organisation_livraison_integrer',
  'organisation_vente_receptionner','organisation_capacite_exiger'))
ORDER BY signature;

SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity, c.relacl,
       a.attname, format_type(a.atttypid,a.atttypmod) AS type
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
WHERE n.nspname='public' AND c.relname IN
 ('organisations','ventes_snapshots','livraisons_objets','organisation_objets',
  'organisation_equipements_actes','organisation_equipements_journal','equipements_capacites')
ORDER BY c.relname,a.attnum;
SELECT c.relname, t.tgname, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE NOT t.tgisinternal AND t.tgrelid IN
 ('public.organisations'::regclass,'public.ventes_snapshots'::regclass)
ORDER BY c.relname,t.tgname;

-- Agregat uniquement ; ne jamais corriger ces anomalies par arrondi automatique.
SELECT count(*) AS recus, count(*) FILTER (WHERE
 prix_unitaire::numeric*100<>trunc(prix_unitaire::numeric*100) OR
 montant_total::numeric*100<>trunc(montant_total::numeric*100)) AS recus_fraction_centime
FROM public.ventes_snapshots;
SELECT pg_describe_object(d.classid,d.objid,d.objsubid) AS dependant,
       pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS reference, d.deptype
FROM pg_depend d
WHERE d.refclassid='pg_class'::regclass AND d.refobjid IN
 ('public.organisations'::regclass,'public.ventes_snapshots'::regclass)
ORDER BY reference,dependant;
ROLLBACK;
