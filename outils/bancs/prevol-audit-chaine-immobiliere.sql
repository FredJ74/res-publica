-- Inspection technique en lecture seule. Aucune reservation, emprunt, travail ou mutation.
-- Aucun compte joueur, email, inventaire ou solde individuel dans les resultats de donnees.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE name ~* '(terrain|chantier|pret|financ|solde|banque|inventaire|rue)' ORDER BY version;
SELECT p.oid::regprocedure AS signature,pg_get_userbyid(p.proowner) AS proprietaire,
 p.prosecdef,p.provolatile,p.proconfig,p.proacl,md5(p.prosrc),pg_get_functiondef(p.oid),
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f' AND
 (p.proname ~ '^(terrain_|chantier_|pret_national|approvisionner_chantier|vendre_materiaux_chantier|restituer_reliquats_chantier)'
 OR p.proname IN ('compromis_expire_resoudre','creer_pret_helvetia','traiter_prets_helvetia_quotidien','signer_compromis_bien_helvetia','finaliser_achat_bien_helvetia','payer_ordre','personnages_vue_modifier','helvetia_debiter_fonds_ordinaires','mouvement_titulaire','local_vocation_commerciale','creer_fonds_commerce'))
ORDER BY p.proname,p.oid;
SELECT c.oid::regclass AS relation,c.relrowsecurity,c.relforcerowsecurity,
 has_table_privilege('authenticated',c.oid,'INSERT') AS client_insert,
 has_table_privilege('authenticated',c.oid,'UPDATE') AS client_update,
 has_table_privilege('authenticated',c.oid,'DELETE') AS client_delete
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('terrains_etat','prets','comptes_bancaires','batiments_etat','locations_actives','dossiers_urbanisme','objets_recus','personnages_donnees');
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN ('terrains_etat','prets','comptes_bancaires','batiments_etat','locations_actives','dossiers_urbanisme','objets_recus','personnages_donnees');
SELECT t.tgrelid::regclass AS relation,t.tgname,pg_get_triggerdef(t.oid),pg_get_functiondef(t.tgfoid)
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND NOT t.tgisinternal
AND c.relname IN ('terrains_etat','prets','comptes_bancaires','batiments_etat','objets_recus','personnages','personnages_donnees');
SELECT c.conrelid::regclass AS relation,c.conname,pg_get_constraintdef(c.oid)
FROM pg_constraint c JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace
WHERE n.nspname='public' AND r.relname IN ('terrains_etat','prets','comptes_bancaires','locations_actives');
SELECT * FROM public.chantiers_paliers ORDER BY palier;
SELECT * FROM public.chantiers_besoins_jour ORDER BY position_cycle;
SELECT fn,pa,cost FROM public.ordres_couts WHERE fn IN ('acheter_terrain','signer_compromis','officialiser_transaction','acte_vente_terrain','emprunter','emprunter_construction') ORDER BY fn,pa,cost;
-- Agregats uniquement ; la validite JSON des blobs est a examiner avant requetes plus fines.
SELECT country,count(*) AS lignes,count(DISTINCT building_id) AS batiments,
 count(*) FILTER (WHERE proprietaire IS NULL) AS proprietaires_colonne_absents,
 count(*) FILTER (WHERE niveau_construction IS NOT NULL) AS niveaux_colonne FROM public.terrains_etat GROUP BY country;
SELECT type_banque,type_pret,statut,count(*) AS contrats FROM public.prets GROUP BY type_banque,type_pret,statut;
-- Fermeture des dependances : ne pas preparer une substitution depuis le seul baseline.
-- Inclut les surcharges, signatures exactes, contrats de monnaie/inventaire et emploi commun.
SELECT p.oid::regprocedure AS signature,pg_get_functiondef(p.oid),p.proacl,
 md5(p.prosrc) AS empreinte_source
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f' AND
 (p.proname ~ '(chantier|terrain|reliquat|pret|inventaire|reception|recu|entrepot)'
 OR p.proname IN ('est_appel_serveur','compte_bancaire_initial','exiger_acteur',
 'pnj_quitter_groupe','pnj_position_effective','pnj_peut_conduire',
 'pnj_co_present','pnj_axe_position_refus','pnj_mouvement_individuel_refus',
 'employeur_embaucher','employe_recruter'))
ORDER BY p.oid::regprocedure::text;
-- Types reels : aucune hypothese integer/numeric, vue/table ou JSON/texte.
SELECT c.oid::regclass AS relation,a.attname,format_type(a.atttypid,a.atttypmod) AS type,
 a.attnotnull,pg_get_expr(d.adbin,d.adrelid) AS defaut
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
WHERE n.nspname='public' AND c.relname IN ('terrains_etat','prets','comptes_bancaires',
 'personnages','personnages_donnees','batiments_etat','locations_actives',
 'pnj_membres','pnj_metiers_profils','objets_recus') ORDER BY c.oid::regclass::text,a.attnum;
-- Dependances catalogue (les appels SQL dynamiques exigent aussi l'examen des definitions).
SELECT p.oid::regprocedure AS fonction,d.deptype,
 pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS dependance
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
JOIN pg_depend d ON d.classid='pg_proc'::regclass AND d.objid=p.oid
WHERE n.nspname='public' AND p.proname ~ '(chantier|terrain|pret|reliquat|fonds_commerce)'
ORDER BY p.oid::regprocedure::text,dependance;
ROLLBACK;
