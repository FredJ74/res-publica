with hors(t) as (values ('compagnies_militaires_snapshot_20260926'), ('lois_assemblee'), ('rapports_cellules_artefacts_20260926'), ('zz_snap_cka_blob'), ('zz_snap_cka_metier')),
rel as (select c.oid, c.relname, c.relkind, c.relrowsecurity, c.relforcerowsecurity, c.relacl
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind in ('r','v','S')),
tab as (select * from rel where relkind = 'r'),
gard as (select * from tab where relname not in (select t from hors)),
-- attidentity est de type "char" (pas text) : sans ::text, la concatenation
-- echoue sur « operator is not unique: text || "char" ». Meme piege que
-- pg_policy.polcmd, rencontre au chantier 2B.
col as (select r.relname, r.relkind, a.attnum, a.attname, a.attacl,
               format_type(a.atttypid, a.atttypmod) as typ, a.attnotnull,
               a.attidentity::text as attidentity,
               pg_get_expr(ad.adbin, ad.adrelid) as defaut
        from pg_attribute a join rel r on r.oid = a.attrelid
        left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
        where a.attnum > 0 and not a.attisdropped and r.relkind in ('r','v')),
kon as (select c.relname, k.conname, pg_get_constraintdef(k.oid, false) as def, k.contype
        from pg_constraint k join tab c on c.oid = k.conrelid),
idx as (select tc.relname as tbl, ic.relname as nom, pg_get_indexdef(x.indexrelid) as def,
               exists(select 1 from pg_constraint k where k.conindid = x.indexrelid) as portee
        from pg_index x join pg_class ic on ic.oid = x.indexrelid
        join tab tc on tc.oid = x.indrelid),
-- pg_get_triggerdef(oid, true) -- la forme « pretty » -- est celle que le
-- baseline ecrit sur le disque. Le controle doit comparer la meme forme, sinon
-- il rougit alors que les declencheurs sont identiques. Les 3 declencheurs
-- INSTEAD OF de la vue personnages sont inclus : le join porte sur rel, pas
-- seulement sur tab.
trg as (select c.relname::text as tbl, t.tgname::text as tgname,
               pg_get_triggerdef(t.oid, true) as def
        from pg_trigger t join rel c on c.oid = t.tgrelid where not t.tgisinternal),
-- Le texte de la policy est rebati ici avec EXACTEMENT le meme format() que la
-- requete POLICIES ci-dessus : PostgreSQL n'offre pas de pg_get_policydef, il
-- faut reconstruire l'ordre champ par champ. Toute divergence entre les deux
-- formules ferait rougir le controle, ce qui est le comportement voulu.
pol as (select c.relname::text as tbl, p.polname::text as polname, p.polcmd::text as cmd,
               p.polpermissive::text as permissive,
               coalesce(pg_get_expr(p.polqual, p.polrelid, true), '') as q,
               coalesce(pg_get_expr(p.polwithcheck, p.polrelid, true), '') as w,
               format(
                 'CREATE POLICY %I ON public.%I%s FOR %s TO %s%s%s;',
                 p.polname, c.relname,
                 case when p.polpermissive then '' else E'\n  AS RESTRICTIVE' end,
                 case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                               when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end,
                 case when p.polroles = '{0}'::oid[] then 'PUBLIC'
                      else (select string_agg(quote_ident(r.rolname), ', ' order by r.rolname)
                            from pg_roles r where r.oid = any(p.polroles)) end,
                 case when p.polqual is not null
                      then E'\n  USING (' || pg_get_expr(p.polqual, p.polrelid, true) || ')' else '' end,
                 case when p.polwithcheck is not null
                      then E'\n  WITH CHECK (' || pg_get_expr(p.polwithcheck, p.polrelid, true) || ')' else '' end
               ) as def
        from pg_policy p join tab c on c.oid = p.polrelid),
fon as (select p.oid, p.oid::regprocedure::text as sig, pg_get_functiondef(p.oid) as def
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.prokind in ('f','p')),
-- Le beneficiaire est resolu par une LECTURE DE pg_roles, pas par
-- grantee::regrole::text. Les deux ne disent pas la meme chose : regrole rend
-- « - » pour l'OID 0, la ligne accordee a PUBLIC, et peut mettre des guillemets
-- autour d'un nom de role. Les fichiers du baseline, eux, sont ecrits depuis la
-- forme lisible. Un controle qui comparerait l'autre forme rougirait sans
-- qu'aucun droit ait change -- ce qui est arrive une fois le 5 octobre 2026, et
-- c'est le releve de cloture du chantier qui l'a attrape.
dr as (select case when r.relkind = 'S' then 'SEQUENCE' else 'TABLE' end as genre,
              r.relname::text as objet,
              coalesce((select rolname from pg_roles where oid = acl.grantee), 'PUBLIC') as benef,
              string_agg(acl.privilege_type, ', ' order by acl.privilege_type) as priv
       from rel r, aclexplode(r.relacl) acl
       group by case when r.relkind = 'S' then 'SEQUENCE' else 'TABLE' end, r.relname::text,
                coalesce((select rolname from pg_roles where oid = acl.grantee), 'PUBLIC')),
drf as (select f.sig as objet,
               coalesce((select rolname from pg_roles where oid = acl.grantee), 'PUBLIC') as benef,
               string_agg(acl.privilege_type, ', ' order by acl.privilege_type) as priv
        from fon f join pg_proc p on p.oid = f.oid, aclexplode(p.proacl) acl
        group by f.sig, coalesce((select rolname from pg_roles where oid = acl.grantee), 'PUBLIC')),
drc as (select c.relname::text as relname, c.attname::text as attname,
               coalesce((select rolname from pg_roles where oid = acl.grantee), 'PUBLIC') as benef,
               string_agg(acl.privilege_type, ', ' order by acl.privilege_type) as priv
        from col c, aclexplode(c.attacl) acl
        group by c.relname::text, c.attname::text,
                 coalesce((select rolname from pg_roles where oid = acl.grantee), 'PUBLIC')),
-- PIEGE SERIEUX, RENCONTRE AU CHANTIER 2E. Les ::text ci-dessous ne sont pas
-- decoratifs. pg_class.relname est de type `name`, long de 63 octets au plus
-- (NAMEDATALEN - 1). Sans le cast, le type de la colonne de l'UNION ALL est
-- resolu sur la PREMIERE branche, donc `name`, et toutes les branches suivantes
-- y sont converties en silence : les signatures de fonction longues etaient
-- TRONQUEES a 63 caracteres. Le controle aurait alors valide une identite
-- amputee, et deux fonctions aux 63 premiers caracteres identiques auraient
-- ete confondues. Trois signatures etaient concernees sur ce schema.
com as (select 'TABLE' as genre, t.relname::text as objet, ''::text as sous,
               d.description as txt
          from pg_description d join tab t on t.oid = d.objoid where d.objsubid = 0
        union all
        select 'COLUMN', c.relname::text, c.attname::text, d.description
          from pg_description d join rel r on r.oid = d.objoid
          join col c on c.relname = r.relname and c.attnum = d.objsubid where d.objsubid > 0
        union all
        select 'FUNCTION', f.sig, '', d.description
          from pg_description d join fon f on f.oid = d.objoid
        union all
        select 'CONSTRAINT', c.conrelid::regclass::text, c.conname::text, d.description
          from pg_description d join pg_constraint c on c.oid = d.objoid
          join tab t on t.oid = c.conrelid)
, dpa as (
        -- LES PRIVILEGES PAR DEFAUT, limites a ceux que NOTRE role administre. Les
        -- entrees de supabase_admin / supabase_auth_admin sont volontairement hors de
        -- cette CTE : elles changent au rythme de la plateforme, et les inclure ferait
        -- rougir le controle pour une cause sur laquelle nous n'avons aucune prise.
        select pg_get_userbyid(d.defaclrole) as prop, n.nspname as portee,
               d.defaclobjtype::text as typ,
               coalesce(rr.rolname, 'PUBLIC') as benef,
               ae.privilege_type as priv
          from pg_default_acl d
          left join pg_namespace n on n.oid = d.defaclnamespace
          cross join lateral aclexplode(d.defaclacl) ae
          left join pg_roles rr on rr.oid = ae.grantee
         where pg_get_userbyid(d.defaclrole) = current_user)
select jsonb_build_object(
 'totaux', jsonb_build_object(
   'tables', (select count(*) from tab),
   'vues', (select count(*) from rel where relkind = 'v'),
   'sequences', (select count(*) from rel where relkind = 'S'),
   'colonnes', (select count(*) from col),
   'colonnes_de_vues', (select count(*) from col where relkind = 'v'),
   'contraintes', (select count(*) from kon),
   'index', (select count(*) from idx),
   'index_portes', (select count(*) from idx where portee),
   -- LE COMPTE PORTE SUR LES ENTREES de pg_default_acl administrables par notre role,
   -- pas sur les couples (entree x beneficiaire) : c'est l'unite que le manifeste du
   -- baseline inventorie, et deux unites differentes rendraient le controle incomparable.
   'droits_par_defaut', (select count(*) from (select distinct prop, portee, typ from dpa) q),
   'index_autonomes', (select count(*) from idx where not portee),
   'fonctions', (select count(*) from fon),
   'triggers', (select count(*) from trg),
   'policies', (select count(*) from pol),
   'rls_actives', (select count(*) from tab where relrowsecurity),
   'droits_relations', (select count(*) from dr),
   'droits_fonctions', (select count(*) from drf),
   'droits_colonnes', (select count(*) from drc),
   'commentaires', (select count(*) from com)),
 'ecartes', jsonb_build_object(
   'tables', (select count(*) from tab where relname in (select t from hors)),
   'liste', (select jsonb_agg(relname order by relname) from tab where relname in (select t from hors)),
   'colonnes', (select count(*) from col where relname in (select t from hors)),
   'contraintes', (select count(*) from kon where relname in (select t from hors)),
   'index', (select count(*) from idx where tbl in (select t from hors)),
   'index_autonomes', (select count(*) from idx where not portee and tbl in (select t from hors)),
   'triggers', (select count(*) from trg where tbl in (select t from hors)),
   'policies', (select count(*) from pol where tbl in (select t from hors)),
   'rls_actives', (select count(*) from tab where relrowsecurity and relname in (select t from hors)),
   'droits_relations', (select count(*) from dr where genre = 'TABLE' and objet in (select t from hors)),
   'droits_colonnes', (select count(*) from drc where relname in (select t from hors)),
   'commentaires', (select count(*) from com
                     where (genre = 'TABLE' and objet in (select t from hors))
                        or (genre = 'COLUMN' and objet in (select t from hors))
                        or (genre = 'CONSTRAINT' and objet in (select t from hors)))),
 -- PRINCIPE DES EMPREINTES. Chacune est md5 d'une liste triee COLLATE "C"
 -- d'ingredients « cle : md5(definition) », ou la definition est EXACTEMENT
 -- celle que la base renvoie et que le baseline recopie telle quelle. Le
 -- verificateur recompose la meme liste depuis les MANIFESTE.json, qui portent
 -- l'empreinte de chaque objet. Aucune des deux cotes ne reparse du SQL.
 --
 -- Les colonnes font exception et c'est assume : le fichier CREATE TABLE n'est
 -- pas le texte brut de la base (regle du bigserial). L'empreinte des colonnes
 -- porte donc sur les FAITS du catalogue, a deux niveaux pour rester
 -- decomposable par table : une empreinte par table, puis une empreinte des
 -- empreintes. La regle du bigserial ne vit ainsi qu'a un seul endroit,
 -- rendre.py, et n'est pas reecrite en SQL.
 'empreintes', jsonb_build_object(
   'colonnes', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select c.relname || ':' || md5(string_agg(
               c.attnum || ':' || c.attname || ':' || c.typ || ':' || c.attnotnull::text
               || ':' || coalesce(c.attidentity, '') || ':' || coalesce(c.defaut, ''),
               '|' order by c.attnum)) as x
      from col c where c.relkind = 'r' and c.relname not in (select t from hors)
      group by c.relname) z),
   'contraintes', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select k.relname || ':' || k.conname || ':' || md5(k.def) as x
      from kon k where k.relname not in (select t from hors)) z),
   'index', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select i.nom || ':' || md5(i.def) as x
      from idx i where not i.portee and i.tbl not in (select t from hors)) z),
   'fonctions', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select f.sig || ':' || md5(f.def) as x from fon f) z),
   'vues', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select r.relname || ':' || md5(pg_get_viewdef(r.oid, true)) as x
      from rel r where r.relkind = 'v') z),
   'triggers', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select t.tbl || ':' || t.tgname || ':' || md5(t.def) as x
      from trg t where t.tbl not in (select t from hors)) z),
   -- Deux empreintes pour les policies, volontairement. La premiere reprend la
   -- formule du chantier 2B (expressions USING / WITH CHECK, commande,
   -- permissive). Elle a un angle mort : elle ignore le role vise par le TO.
   -- Un « TO anon » devenu « TO authenticated » passerait inapercu. La seconde
   -- porte sur l'ordre CREATE POLICY complet, roles inclus. Angle mort
   -- constate au chantier 2E ; l'ancienne formule est conservee pour que les
   -- controles 2B restent comparables.
   'policies', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select p.tbl || ':' || p.polname || ':' || md5(p.q || p.w || p.cmd || p.permissive) as x
      from pol p where p.tbl not in (select t from hors)) z),
   'policies_avec_roles', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select p.tbl || ':' || p.polname || ':' || md5(p.def) as x
      from pol p where p.tbl not in (select t from hors)) z),
   'droits', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select d.genre || ':' || d.objet || ':' || d.benef || ':' || d.priv as x
      from dr d where not (d.genre = 'TABLE' and d.objet in (select t from hors))
      union all
      select 'FUNCTION:' || f.objet || ':' || f.benef || ':' || f.priv from drf f
      union all
      select 'COLUMN:' || c.relname || '.' || c.attname || ':' || c.benef || ':' || c.priv
      from drc c where c.relname not in (select t from hors)) z),
   'commentaires', (select md5(string_agg(x, '|' order by x collate "C")) from (
      select o.genre || ':' || o.objet || ':' || o.sous || ':' || md5(o.txt) as x
      from com o where o.objet not in (select t from hors)) z),
   -- L'EMPREINTE DES PRIVILEGES PAR DEFAUT. Sans elle, une reouverture de PUBLIC ou
   -- d'authenticated sur les fonctions a venir restait HORS EMPREINTE : le baseline
   -- pouvait rester vert pendant que le defaut redevenait permissif. La portee NULL
   -- (niveau global) est rendue comme '(global)' pour qu'elle ne se confonde jamais
   -- avec une portee de schema -- les deux niveaux se combinent et n'ont pas le meme
   -- effet, notamment sur le PUBLIC natif des fonctions.
   'droits_par_defaut', (select coalesce(md5(string_agg(x, '|' order by x collate "C")), 'aucun') from (
      select d.prop || ':' || coalesce(d.portee, '(global)') || ':' || d.typ
             || ':' || d.benef || ':' || d.priv as x from dpa d) z)),
 'securite', jsonb_build_object(
   -- LE DEFAUT DES FONCTIONS EST-IL FERME AUX ROLES CLIENTS ? Deux conditions, et il
   -- faut les DEUX : l'entree de niveau GLOBAL doit exister -- c'est la seule qui
   -- retire le PUBLIC que PostgreSQL accorde nativement a toute fonction -- et ni elle
   -- ni l'entree IN SCHEMA public ne doivent nommer PUBLIC, anon ou authenticated. Si
   -- l'une des entrees disparait, le defaut natif revient : l'existence fait donc
   -- partie du controle, pas seulement le contenu.
   'defaut_fonctions_ferme_aux_clients', (
      (select count(*) from dpa where portee is null and typ = 'f') > 0
      and (select count(*) from dpa where portee = 'public' and typ = 'f') > 0
      and not exists (select 1 from dpa
                       where typ = 'f' and (portee is null or portee = 'public')
                         and benef in ('PUBLIC', 'anon', 'authenticated'))),
   'fonctions_security_definer', (select count(*) from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind in ('f','p') and p.prosecdef),
   'fonctions_security_invoker', (select count(*) from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind in ('f','p') and not p.prosecdef),
   'tables_sans_rls', (select count(*) from gard g where not g.relrowsecurity),
   'tables_rls_active_sans_policy', (select count(*) from gard g
      where g.relrowsecurity and not exists(select 1 from pol p where p.tbl = g.relname)),
   'tables_rls_active_sans_policy_liste', (select jsonb_agg(g.relname order by g.relname)
      from gard g where g.relrowsecurity
      and not exists(select 1 from pol p where p.tbl = g.relname)),
   'tables_sans_rls_liste', (select jsonb_agg(g.relname order by g.relname)
      from gard g where not g.relrowsecurity)),
 'registre', (select jsonb_build_object(
    'entrees', count(*), 'derniere_version', max(version),
    'empreinte', md5(string_agg(version || ':' || coalesce(name, ''), '|'
                                order by (version || ':' || coalesce(name, '')) collate "C")))
   from supabase_migrations.schema_migrations),
 'releve_le', now() at time zone 'UTC'
) as controle_global
