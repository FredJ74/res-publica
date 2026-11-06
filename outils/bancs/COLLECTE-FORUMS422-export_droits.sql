select jsonb_build_object(
 'droits_relations', (select jsonb_agg(jsonb_build_object('genre',y.g,'objet',y.ob,'beneficiaire',y.ben,'privileges',y.privs) order by y.ob collate "C", y.ben collate "C") from (
     select case c.relkind when 'S' then 'SEQUENCE' else 'TABLE' end as g, c.relname as ob, coalesce(rr.rolname,'PUBLIC') as ben, string_agg(ae.privilege_type,', ' order by ae.privilege_type) as privs
     from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
     cross join lateral aclexplode(c.relacl) ae left join pg_roles rr on rr.oid=ae.grantee
     where c.relkind in ('r','v','S') group by c.relkind, c.relname, coalesce(rr.rolname,'PUBLIC')) y),
 'droits_fonctions', (select jsonb_agg(jsonb_build_object('genre','FUNCTION','objet',y.ob,'beneficiaire',y.ben,'privileges',y.privs) order by y.ob collate "C", y.ben collate "C") from (
     select p.oid::regprocedure::text as ob, coalesce(rr.rolname,'PUBLIC') as ben, string_agg(ae.privilege_type,', ' order by ae.privilege_type) as privs
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace and n.nspname='public'
     cross join lateral aclexplode(p.proacl) ae left join pg_roles rr on rr.oid=ae.grantee
     group by p.oid::regprocedure::text, coalesce(rr.rolname,'PUBLIC')) y),
 'droits_colonnes', (select coalesce(jsonb_agg(jsonb_build_object('tbl',y.t,'colonne',y.col,'beneficiaire',y.ben,'privileges',y.privs) order by y.t collate "C", y.col collate "C", y.ben collate "C"),'[]'::jsonb) from (
     select c.relname as t, a.attname as col, coalesce(rr.rolname,'PUBLIC') as ben, string_agg(ae.privilege_type,', ' order by ae.privilege_type) as privs
     from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
     cross join lateral aclexplode(a.attacl) ae left join pg_roles rr on rr.oid=ae.grantee
     where a.attacl is not null group by c.relname, a.attname, coalesce(rr.rolname,'PUBLIC')) y),
 'droits_par_defaut', (select coalesce(jsonb_agg(z.x order by z.prop collate "C", coalesce(z.portee,'') collate "C", z.typ collate "C"), '[]'::jsonb) from (
     select pg_get_userbyid(d.defaclrole) as prop, n.nspname as portee, d.defaclobjtype::text as typ,
            jsonb_build_object(
              'proprietaire', pg_get_userbyid(d.defaclrole),
              'portee', n.nspname,
              'type_objet', d.defaclobjtype::text,
              'administrable', pg_get_userbyid(d.defaclrole) = current_user,
              'accorde', (select coalesce(jsonb_agg(jsonb_build_object('beneficiaire',q.ben,'privileges',q.privs) order by q.ben collate "C"), '[]'::jsonb)
                            from (select coalesce(rr.rolname,'PUBLIC') as ben, string_agg(ae.privilege_type,', ' order by ae.privilege_type) as privs
                                    from aclexplode(d.defaclacl) ae left join pg_roles rr on rr.oid=ae.grantee
                                   group by coalesce(rr.rolname,'PUBLIC')) q),
              'revoque_du_natif', (select coalesce(jsonb_agg(jsonb_build_object('beneficiaire',q2.ben,'privileges',q2.privs) order by q2.ben collate "C"), '[]'::jsonb)
                            from (select coalesce(rr.rolname,'PUBLIC') as ben, string_agg(ae.privilege_type,', ' order by ae.privilege_type) as privs
                                    from aclexplode(acldefault(case d.defaclobjtype when 'S' then 's' when 'T' then 't' else d.defaclobjtype end, d.defaclrole)) ae
                                    left join pg_roles rr on rr.oid=ae.grantee
                                   where not exists (select 1 from aclexplode(d.defaclacl) a2
                                                      where a2.grantee=ae.grantee and a2.privilege_type=ae.privilege_type)
                                   group by coalesce(rr.rolname,'PUBLIC')) q2)
            ) as x
     from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace) z)
) as export_droits;
