-- #219, lecture seule. Un résultat JSON unique : ne pas perdre les premiers
-- jeux de résultats d'un outil qui ne renvoie que la dernière requête.
-- Métadonnées exclusivement : aucune fiche, possession, identité PJ ou solde.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT jsonb_build_object(
 'releve_utc',statement_timestamp(),
 'registre',(SELECT jsonb_agg(jsonb_build_object('version',version,'name',name) ORDER BY version) FROM supabase_migrations.schema_migrations),
 'fonctions',(SELECT jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'corps_md5',md5(p.prosrc),'definition',pg_get_functiondef(p.oid),'droits',p.proacl,'proprietaire',p.proowner::regrole::text,'security_definer',p.prosecdef,'configuration',p.proconfig) ORDER BY p.oid::regprocedure::text)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND
  (p.proname ~ '^(groupe_|pnj_|navigation_|rue_|police_|combat_|militaire_|camion_|transport_|douane_|force_publique_|effectifs_|fiche_|crime_|sanction_|payer_ordre|detention_|justice_executer|terrain_squatteurs|mail_systeme|personnages_vue_modifier|est_appel_serveur|mon_personnage)')),
 'tables',(SELECT jsonb_agg(jsonb_build_object('nom',c.relname,'rls',c.relrowsecurity,'rls_force',c.relforcerowsecurity,'droits',c.relacl,'options',c.reloptions,
  'contraintes',(SELECT jsonb_agg(jsonb_build_object('nom',k.conname,'definition',pg_get_constraintdef(k.oid))) FROM pg_constraint k WHERE k.conrelid=c.oid),
  'index',(SELECT jsonb_agg(pg_get_indexdef(i.indexrelid)) FROM pg_index i WHERE i.indrelid=c.oid),
  'colonnes',(SELECT jsonb_agg(jsonb_build_object('nom',a.attname,'type',format_type(a.atttypid,a.atttypmod)) ORDER BY a.attnum) FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),
  'politiques',(SELECT jsonb_agg(jsonb_build_object('nom',p.polname,'commande',p.polcmd,'roles',p.polroles,'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid))) FROM pg_policy p WHERE p.polrelid=c.oid),
  'triggers',(SELECT jsonb_agg(jsonb_build_object('nom',t.tgname,'definition',pg_get_triggerdef(t.oid),'fonction',pg_get_functiondef(t.tgfoid)) ORDER BY t.tgname) FROM pg_trigger t WHERE t.tgrelid=c.oid AND NOT t.tgisinternal)) ORDER BY c.relname)
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ('personnages_donnees','personnages','pnj_membres','pnj_possessions','pnj_metiers_profils','pnj_soldats_metier','groupes_pj_adhesions','navigation_lieux_regles','navigation_requetes','batailles','batailles_engagements','batailles_groupes','batailles_rounds','police_interceptions','terrains_etat','mails','mails_envois_systeme','amendes_tresor','inventaire_actions_recus')),
 'pnj_diagnostic',(SELECT jsonb_build_object('total',count(*),'actifs',count(*) FILTER(WHERE statut='actif'),'sans_nom',count(*) FILTER(WHERE nullif(btrim(nom),'') IS NULL),'classes_invalides',count(*) FILTER(WHERE classe IS NULL OR classe NOT IN ('alpha','beta','gamma')),'profils_combattants_incomplets',coalesce(jsonb_agg(id ORDER BY id) FILTER(WHERE statut='actif' AND classe IN ('alpha','beta') AND famille<>'soldat' AND (car_vol IS NULL OR car_per IS NULL OR car_dup IS NULL)),'[]'),'gardes_homonymes',coalesce(jsonb_agg(id ORDER BY id) FILTER(WHERE id IN ('garde-republic-assemblee-permanent','garde-republic-palais-gouvernement-permanent','garde-republic-palais-presidentiel-permanent')),'[]')) FROM public.pnj_membres),
 'signatures_registre',(SELECT jsonb_agg(jsonb_build_object('colonne',a.attname,'type',format_type(a.atttypid,a.atttypmod))) FROM pg_attribute a WHERE a.attrelid='supabase_migrations.schema_migrations'::regclass AND a.attnum>0 AND NOT a.attisdropped)
) AS prevol_219;
ROLLBACK;
