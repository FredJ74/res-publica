select jsonb_build_object(
 'vues', (select jsonb_agg(jsonb_build_object('vue',c.relname,'reloptions',c.reloptions,'definition',pg_get_viewdef(c.oid,true),'empreinte',md5(pg_get_viewdef(c.oid,true))) order by c.relname collate "C")
   from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public' where c.relkind='v'),
 'triggers', (select jsonb_agg(jsonb_build_object('tbl',c.relname,'nom',t.tgname,'actif',t.tgenabled,'fonction',p.oid::regprocedure::text,
      'definition',pg_get_triggerdef(t.oid,true),'empreinte',md5(pg_get_triggerdef(t.oid,true))) order by c.relname collate "C", t.tgname collate "C")
   from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
   join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal),
 'rls', (select jsonb_agg(jsonb_build_object('tbl',c.relname,'active',c.relrowsecurity,'forcee',c.relforcerowsecurity) order by c.relname collate "C")
   from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public' where c.relkind='r'),
 'policies', (select jsonb_agg(jsonb_build_object('tbl',c.relname,'nom',pol.polname,
      'definition', format('CREATE POLICY %I ON public.%I%s FOR %s TO %s%s%s;', pol.polname, c.relname,
         case when pol.polpermissive then '' else E'
  AS RESTRICTIVE' end,
         case pol.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end,
         case when pol.polroles = '{0}'::oid[] then 'PUBLIC' else (select string_agg(quote_ident(rr.rolname), ', ' order by rr.rolname) from pg_roles rr where rr.oid = any(pol.polroles)) end,
         case when pol.polqual is not null then E'
  USING (' || pg_get_expr(pol.polqual, pol.polrelid, true) || ')' else '' end,
         case when pol.polwithcheck is not null then E'
  WITH CHECK (' || pg_get_expr(pol.polwithcheck, pol.polrelid, true) || ')' else '' end),
      'empreinte', md5(coalesce(pg_get_expr(pol.polqual,pol.polrelid,true),'')||coalesce(pg_get_expr(pol.polwithcheck,pol.polrelid,true),'')||pol.polcmd::text||pol.polpermissive::text)
    ) order by c.relname collate "C", pol.polname collate "C")
   from pg_policy pol join pg_class c on c.oid=pol.polrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'),
 'commentaires', (select jsonb_agg(z.x order by z.k collate "C") from (
     select jsonb_build_object('genre','TABLE','objet',c.relname,'colonne',null,'texte',obj_description(c.oid,'pg_class')) as x, 'T'||c.relname as k
     from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public' where c.relkind in ('r','v') and obj_description(c.oid,'pg_class') is not null
     union all select jsonb_build_object('genre','COLUMN','objet',c.relname,'colonne',a.attname,'texte',col_description(c.oid,a.attnum)), 'C'||c.relname||'.'||a.attname
     from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
     where a.attnum>0 and not a.attisdropped and col_description(c.oid,a.attnum) is not null
     union all select jsonb_build_object('genre','FUNCTION','objet',p.oid::regprocedure::text,'colonne',null,'texte',obj_description(p.oid,'pg_proc')), 'F'||p.oid::regprocedure::text
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace and n.nspname='public' where obj_description(p.oid,'pg_proc') is not null
     union all select jsonb_build_object('genre','CONSTRAINT','objet',c.relname,'colonne',k.conname,'texte',obj_description(k.oid,'pg_constraint')), 'K'||c.relname||'.'||k.conname
     from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public' where obj_description(k.oid,'pg_constraint') is not null) z)
) as export_logique;
