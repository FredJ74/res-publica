select jsonb_build_object('fonctions', (select jsonb_agg(jsonb_build_object(
   'signature', p.oid::regprocedure::text,
   'proname', p.proname,
   'retour', pg_get_function_result(p.oid),
   'langage', l.lanname,
   'security_definer', p.prosecdef,
   'volatilite', p.provolatile::text,
   'configuration', p.proconfig,
   'definition', pg_get_functiondef(p.oid),
   'empreinte', md5(pg_get_functiondef(p.oid))) order by p.oid::regprocedure::text collate "C")
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace and n.nspname='public' join pg_language l on l.oid=p.prolang)
) as export_fonctions;
