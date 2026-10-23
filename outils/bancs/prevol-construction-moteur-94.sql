-- Lecture seule #94 ; aucune invocation de RPC metier, aucun export de personnage.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT p.oid::regprocedure::text AS signature,md5(p.prosrc) AS empreinte,
 pg_get_functiondef(p.oid) AS definition,p.prosecdef,p.proconfig,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS client_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anonyme_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('chantier_commande','chantier_commande_recu','chantier_jour_traiter','chantier_lancer',
 'chantier_verser','chantier_travailler','chantier_prix_definir','vendre_materiaux_chantier',
 'terrain_permis_acte','terrain_lots_acte','terrain_reamenagement_poser',
 'pret_national_contracter','compromis_expire_resoudre','entreprise_signer_compromis',
 'helvetia_debiter_fonds_ordinaires','objet_sas_deposer','mail_systeme_poser_interne',
 'organisation_equipement_exiger','militaire_bataille_engager','militaire_bataille_combattants') ORDER BY 1;
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
WHERE c.relnamespace='public'::regnamespace AND c.relname IN
 ('terrains_etat','personnages_donnees','prets','comptes_bancaires','organisations','cycles_electoraux',
 'locations_actives','caisses_batiments','batiments_etat','pnj_identites','chantiers_paliers',
 'chantiers_besoins_jour','chantier_commandes') AND a.attnum>0 AND NOT a.attisdropped ORDER BY 1,a.attnum;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE c.relnamespace='public'::regnamespace AND NOT t.tgisinternal AND c.relname IN
 ('terrains_etat','personnages_donnees','comptes_bancaires','locations_actives','organisations') ORDER BY 1,2;
SELECT * FROM pg_policies WHERE schemaname='public' AND tablename IN
 ('terrains_etat','prets','locations_actives','organisations','chantier_commandes');
SELECT country,count(*) AS terrains,
 count(*) FILTER(WHERE jsonb_typeof(public.terrain_etat_lire(data)->'chantier')='object') AS constructions,
 count(*) FILTER(WHERE jsonb_typeof(public.terrain_etat_lire(data)->'chantierReamenagement')='object') AS reamenagements
FROM public.terrains_etat GROUP BY country;
SELECT count(*) FILTER(WHERE solde::text IN('NaN','Infinity','-Infinity') OR solde<>trunc(solde)) AS soldes_a_examiner
FROM public.comptes_bancaires;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE name ~ '(chantier|construction|terrain|permis|pret)' ORDER BY version;
ROLLBACK;
