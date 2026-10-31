-- Prévol de clôture Luthécia après fermeture des caisses #300.
-- LECTURE SEULE. Réexécuter avant paquet #219 et comparer les valeurs observées.
SELECT jsonb_build_object(
 'registre',(SELECT jsonb_build_object('total',count(*),'derniere_version',max(version)) FROM supabase_migrations.schema_migrations),
 'tarifs',(SELECT jsonb_build_object('total',count(*),'uniques',count(DISTINCT (fn,pa,cost))) FROM public.ordres_couts),
 'migrations_caisses',(SELECT jsonb_agg(jsonb_build_object('version',version,'nom',name) ORDER BY version) FROM supabase_migrations.schema_migrations WHERE name LIKE 'caisses_collectives_%'),
 'contrats_finances',(SELECT jsonb_agg(proname ORDER BY proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND proname IN ('organisation_ordre_financier','organisation_adhesion_payante','club_supporters_cotiser','club_sponsoriser','club_transfert_conclure')),
 'contrats_219',(SELECT jsonb_agg(proname ORDER BY proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND proname IN ('organisation_commande_administrative','organisation_commande_evenement','organisation_commande_membres')),
 'triggers_caisses',(SELECT jsonb_agg(tgname ORDER BY tgname) FROM pg_trigger WHERE tgname IN ('trg_organisations_finances_garder','trg_transferts_clubs_garder')),
 'permissions',(SELECT jsonb_agg(jsonb_build_object('table',relname,'ins',has_table_privilege('authenticated',c.oid,'INSERT'),'upd',has_table_privilege('authenticated',c.oid,'UPDATE'),'del',has_table_privilege('authenticated',c.oid,'DELETE')) ORDER BY relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND relname IN ('budgets_clubs','organisations','transferts_clubs'))
) AS controle;
