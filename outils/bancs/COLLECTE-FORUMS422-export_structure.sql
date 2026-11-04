select jsonb_build_object(
 'colonnes', (select jsonb_agg(jsonb_build_object('tbl',c.relname,'kind',c.relkind,'attnum',a.attnum,'attname',a.attname,
      'type',format_type(a.atttypid,a.atttypmod),'non_nul',a.attnotnull,'identity',a.attidentity,'generee',a.attgenerated,
      'defaut',pg_get_expr(ad.adbin,ad.adrelid),'collation',coll.collname) order by c.relname collate "C", a.attnum)
   from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
   left join pg_attrdef ad on ad.adrelid=a.attrelid and ad.adnum=a.attnum
   left join pg_collation coll on coll.oid=a.attcollation and coll.collname<>'default'
   where c.relkind in ('r','v') and a.attnum>0 and not a.attisdropped),
 'contraintes', (select jsonb_agg(jsonb_build_object('tbl',c.relname,'nom',k.conname,'genre',k.contype,
      'definition',pg_get_constraintdef(k.oid,false),'empreinte',md5(pg_get_constraintdef(k.oid,false)))
      order by c.relname collate "C", k.conname collate "C")
   from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'),
 'index', (select jsonb_agg(jsonb_build_object('tbl',tc.relname,'nom',ic.relname,'definition',pg_get_indexdef(ic.oid),
      'contrainte',co.conname,'empreinte',md5(pg_get_indexdef(ic.oid))) order by tc.relname collate "C", ic.relname collate "C")
   from pg_index x join pg_class ic on ic.oid=x.indexrelid join pg_class tc on tc.oid=x.indrelid
   join pg_namespace n on n.oid=ic.relnamespace and n.nspname='public'
   left join pg_constraint co on co.conindid=ic.oid and co.contype in ('p','u','x')),
 'sequences', (select jsonb_agg(jsonb_build_object('sequence',s.relname,'tbl',tc.relname,'colonne',a.attname,'lien',d.deftype,
      'start',sq.seqstart::text,'increment',sq.seqincrement::text,'cache',sq.seqcache::text,'cycle',sq.seqcycle,
      'type',format_type(sq.seqtypid,NULL),'min',sq.seqmin::text,'max',sq.seqmax::text) order by s.relname collate "C")
   from pg_class s join pg_namespace n on n.oid=s.relnamespace and n.nspname='public' and s.relkind='S'
   join pg_sequence sq on sq.seqrelid=s.oid
   left join lateral (select dep.deptype as deftype, dep.refobjid, dep.refobjsubid from pg_depend dep
     where dep.objid=s.oid and dep.classid='pg_class'::regclass and dep.refclassid='pg_class'::regclass and dep.deptype in ('a','i') limit 1) d on true
   left join pg_class tc on tc.oid=d.refobjid
   left join pg_attribute a on a.attrelid=d.refobjid and a.attnum=d.refobjsubid)
) as export_structure;
