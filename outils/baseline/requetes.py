#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Requetes d'introspection des catalogues PostgreSQL pour construire le baseline.

POURQUOI CE MODULE EXISTE SEPAREMENT. La machine de developpement n'a ni pg_dump,
ni psql, ni CLI Supabase : le seul canal vers la base est l'outil MCP execute_sql,
qui est appele par l'assistant, pas par un script. L'extraction se fait donc en
deux temps :

    1. ce module IMPRIME la requete exacte a executer ;
    2. l'assistant l'execute via execute_sql ; la sortie JSON est enregistree ;
    3. rendre.py lit ces sorties et ecrit les fichiers .sql du baseline.

Consequence voulue : la requete qui a produit le baseline est dans le depot, elle
est relisible et rejouable telle quelle. Rien n'est improvise au moment de
l'extraction.

Usage :
    python3 outils/baseline/requetes.py <domaine> <categorie>
    python3 outils/baseline/requetes.py communication tables
    python3 outils/baseline/requetes.py --liste

Categories : tables, sequences, contraintes, index, vues, fonctions, triggers,
             rls, policies, droits, droits_colonnes, commentaires, inventaire

Ce module n'execute aucun SQL et ne touche a rien. Il imprime du texte.
"""

import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOMAINES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "domaines.json")


def litteral(liste):
    """Rend une liste de chaines sous forme de VALUES SQL, triee pour etre stable."""
    return ", ".join("(" + "'" + x.replace("'", "''") + "'" + ")" for x in sorted(liste))


# --------------------------------------------------------------------------
# Les requetes. Chacune renvoie une ligne par objet, avec de quoi ecrire le DDL
# ET de quoi le verifier (une empreinte calculee par la base elle-meme).
# --------------------------------------------------------------------------

TABLES = """
with dom(t) as (values {tables})
select c.relname as tbl, a.attnum, a.attname,
       format_type(a.atttypid, a.atttypmod) as type,
       a.attnotnull as non_nul,
       a.attidentity as identity,
       a.attgenerated as generee,
       pg_get_expr(ad.adbin, ad.adrelid) as defaut,
       coll.collname as collation,
       md5(a.attname || format_type(a.atttypid, a.atttypmod) || a.attnotnull::text
           || coalesce(a.attidentity,'') || coalesce(pg_get_expr(ad.adbin, ad.adrelid),'')) as empreinte
from pg_attribute a
join pg_class c on c.oid = a.attrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
left join pg_collation coll on coll.oid = a.attcollation and coll.collname <> 'default'
where c.relname in (select t from dom) and a.attnum > 0 and not a.attisdropped
order by c.relname, a.attnum
"""

SEQUENCES = """
with dom(t) as (values {tables})
select s.relname as sequence, d.deftype as lien, tc.relname as tbl, a.attname as colonne,
       sq.seqstart, sq.seqincrement, sq.seqmin, sq.seqmax, sq.seqcache, sq.seqcycle
from pg_class s
join pg_namespace n on n.oid = s.relnamespace and n.nspname = 'public' and s.relkind = 'S'
join pg_sequence sq on sq.seqrelid = s.oid
left join lateral (
  select dep.deptype as deftype, dep.refobjid, dep.refobjsubid
  from pg_depend dep
  where dep.objid = s.oid and dep.classid = 'pg_class'::regclass
    and dep.refclassid = 'pg_class'::regclass and dep.deptype in ('a','i')
  limit 1) d on true
left join pg_class tc on tc.oid = d.refobjid
left join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
where tc.relname in (select t from dom)
order by s.relname
"""

CONTRAINTES = """
with dom(t) as (values {tables})
select c.relname as tbl, k.conname as nom, k.contype as genre,
       pg_get_constraintdef(k.oid, false) as definition,
       md5(pg_get_constraintdef(k.oid, false)) as empreinte
from pg_constraint k
join pg_class c on c.oid = k.conrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select t from dom)
order by case k.contype when 'p' then 1 when 'u' then 2 when 'f' then 3 else 4 end,
         c.relname, k.conname
"""

INDEX = """
with dom(t) as (values {tables})
select tc.relname as tbl, ic.relname as nom,
       pg_get_indexdef(ic.oid) as definition,
       (co.conname is not null) as porte_par_une_contrainte,
       co.conname as contrainte,
       md5(pg_get_indexdef(ic.oid)) as empreinte
from pg_index x
join pg_class ic on ic.oid = x.indexrelid
join pg_class tc on tc.oid = x.indrelid
join pg_namespace n on n.oid = ic.relnamespace and n.nspname = 'public'
left join pg_constraint co on co.conindid = ic.oid and co.contype in ('p','u','x')
where tc.relname in (select t from dom)
order by tc.relname, ic.relname
"""

VUES = """
with dom(t) as (values {tables})
select c.relname as vue, c.reloptions, pg_get_viewdef(c.oid, true) as definition,
       md5(pg_get_viewdef(c.oid, true)) as empreinte
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relkind = 'v' and c.relname in (select t from dom)
order by c.relname
"""

FONCTIONS = """
with dom(sig) as (values {fonctions})
select p.oid::regprocedure::text as signature,
       p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as retour,
       l.lanname as langage,
       p.prosecdef as security_definer,
       p.provolatile as volatilite,
       p.proconfig as configuration,
       pg_get_functiondef(p.oid) as definition,
       md5(pg_get_functiondef(p.oid)) as empreinte
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
join pg_language l on l.oid = p.prolang
where p.oid::regprocedure::text in (select sig from dom)
order by p.oid::regprocedure::text
"""

TRIGGERS = """
with dom(t) as (values {tables})
select c.relname as tbl, t.tgname as nom, t.tgenabled as actif,
       p.oid::regprocedure::text as fonction,
       pg_get_triggerdef(t.oid, true) as definition,
       md5(pg_get_triggerdef(t.oid, true)) as empreinte
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal and c.relname in (select t from dom)
order by c.relname, t.tgname
"""

RLS = """
with dom(t) as (values {tables})
select c.relname as tbl, c.relrowsecurity as rls_active, c.relforcerowsecurity as rls_forcee
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select t from dom)
order by c.relname
"""

# Il n'existe pas de pg_get_policydef : le CREATE POLICY est reconstitue champ
# par champ. quote_ident est indispensable (des noms de policy contiennent des
# espaces et des accents).
POLICIES = """
with dom(t) as (values {tables})
select c.relname as tbl, pol.polname as nom,
       format(
         'CREATE POLICY %I ON public.%I%s FOR %s TO %s%s%s;',
         pol.polname, c.relname,
         case when pol.polpermissive then '' else E'\\n  AS RESTRICTIVE' end,
         case pol.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                         when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end,
         case when pol.polroles = '{{0}}'::oid[] then 'PUBLIC'
              else (select string_agg(quote_ident(r.rolname), ', ' order by r.rolname)
                    from pg_roles r where r.oid = any(pol.polroles)) end,
         case when pol.polqual is not null
              then E'\\n  USING (' || pg_get_expr(pol.polqual, pol.polrelid, true) || ')' else '' end,
         case when pol.polwithcheck is not null
              then E'\\n  WITH CHECK (' || pg_get_expr(pol.polwithcheck, pol.polrelid, true) || ')' else '' end
       ) as definition,
       md5(coalesce(pg_get_expr(pol.polqual, pol.polrelid, true),'')
           || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true),'')
           || pol.polcmd || pol.polpermissive::text) as empreinte
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select t from dom)
order by c.relname, pol.polname
"""

# PIEGE CORRIGE AU CHANTIER 2E. La premiere version de cette requete ne couvrait
# que les TABLES et les FONCTIONS. Les 31 sequences du schema portent pourtant
# 102 lignes de droits : sans elles, une base reconstruite refuse le moindre
# nextval() aux roles clients, donc tout INSERT sur une table a cle serielle.
# Le controle global (CONTROLE_GLOBAL) a attrape l'oubli : 927 lignes en base
# contre 825 extraites. La branche SEQUENCE ci-dessous ne prend que les sequences
# POSSEDEES par une table du domaine (pg_depend deptype='a') ; les sequences
# autonomes n'appartiennent a aucun domaine et sont traitees par l'extraction
# globale.
DROITS = """
with dom(t) as (values {tables}), fdom(sig) as (values {fonctions}),
objets as (
  select 'TABLE' as genre, c.relname as objet, c.relacl as acl
  from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  where c.relname in (select t from dom)
  union all
  select 'SEQUENCE', s.relname, s.relacl
  from pg_class s join pg_namespace n on n.oid = s.relnamespace and n.nspname = 'public'
  where s.relkind = 'S' and exists (
    select 1 from pg_depend d join pg_class tc on tc.oid = d.refobjid
    where d.objid = s.oid and d.deptype = 'a' and tc.relname in (select t from dom))
  union all
  select 'FUNCTION', p.oid::regprocedure::text, p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
  where p.oid::regprocedure::text in (select sig from fdom))
select o.genre, o.objet,
       coalesce((select rolname from pg_roles where oid = ae.grantee), 'PUBLIC') as beneficiaire,
       string_agg(ae.privilege_type, ', ' order by ae.privilege_type) as privileges
from objets o, lateral aclexplode(o.acl) ae
group by o.genre, o.objet, 3
order by o.genre, o.objet, 3
"""

# Piege avere ailleurs dans ce schema : un droit peut n'exister QU'au niveau
# colonne. L'ignorer produirait une base ou un role perd un acces sans que
# relacl ne le montre.
DROITS_COLONNES = """
with dom(t) as (values {tables})
select c.relname as tbl, a.attname as colonne,
       coalesce((select rolname from pg_roles where oid = ae.grantee), 'PUBLIC') as beneficiaire,
       string_agg(ae.privilege_type, ', ' order by ae.privilege_type) as privileges
from pg_attribute a
join pg_class c on c.oid = a.attrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public',
     lateral aclexplode(a.attacl) ae
where c.relname in (select t from dom) and a.attacl is not null
group by c.relname, a.attname, 3
order by c.relname, a.attname, 3
"""

COMMENTAIRES = """
with dom(t) as (values {tables}), fdom(sig) as (values {fonctions})
select 'TABLE' as genre, c.relname as objet, null::text as colonne,
       obj_description(c.oid, 'pg_class') as commentaire
from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select t from dom) and obj_description(c.oid, 'pg_class') is not null
union all
select 'COLUMN', c.relname, a.attname, col_description(c.oid, a.attnum)
from pg_attribute a join pg_class c on c.oid = a.attrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select t from dom) and a.attnum > 0 and not a.attisdropped
  and col_description(c.oid, a.attnum) is not null
union all
select 'FUNCTION', p.oid::regprocedure::text, null, obj_description(p.oid, 'pg_proc')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
where p.oid::regprocedure::text in (select sig from fdom)
  and obj_description(p.oid, 'pg_proc') is not null
union all
select 'CONSTRAINT', c.relname, k.conname, obj_description(k.oid, 'pg_constraint')
from pg_constraint k join pg_class c on c.oid = k.conrelid
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relname in (select t from dom) and obj_description(k.oid, 'pg_constraint') is not null
order by 1, 2, 3
"""

# Compte de controle, a executer AVANT et APRES l'extraction : si un chiffre
# bouge, le baseline a ete pris pendant une modification du schema.
INVENTAIRE = """
with dom(t) as (values {tables}), fdom(sig) as (values {fonctions})
select
 (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind='r' and c.relname in (select t from dom)) as tables,
 (select count(*) from pg_attribute a join pg_class c on c.oid=a.attrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
   and c.relname in (select t from dom) and a.attnum>0 and not a.attisdropped) as colonnes,
 (select count(*) from pg_constraint k join pg_class c on c.oid=k.conrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
   and c.relname in (select t from dom)) as contraintes,
 (select count(*) from pg_index x join pg_class tc on tc.oid=x.indrelid
   join pg_namespace n on n.oid=tc.relnamespace where n.nspname='public'
   and tc.relname in (select t from dom)) as index,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.oid::regprocedure::text in (select sig from fdom)) as fonctions,
 (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
   and not t.tgisinternal and c.relname in (select t from dom)) as triggers,
 (select count(*) from pg_policy pol join pg_class c on c.oid=pol.polrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
   and c.relname in (select t from dom)) as policies,
 (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname in (select t from dom) and c.relrowsecurity) as rls_actives,
 (select count(*) from pg_attribute a join pg_class c on c.oid=a.attrelid
   join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
   and c.relname in (select t from dom) and a.attacl is not null) as droits_colonnes,
 -- COLLATE "C" OBLIGATOIRE. Sans lui, le tri suit la collation de la base, qui
 -- ignore la ponctuation au premier rang : « ..._autorise_strict » passe AVANT
 -- « ..._autorise(...) ». Tout outil qui recalcule l'empreinte hors de Postgres
 -- trie par point de code et obtient une autre valeur, alors que les definitions
 -- sont rigoureusement identiques. Piege rencontre et corrige le 5 octobre 2026.
 (select md5(string_agg(x, '|' order by x collate "C")) from (
    select p.oid::regprocedure::text || ':' || md5(pg_get_functiondef(p.oid)) as x
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.oid::regprocedure::text in (select sig from fdom)) z) as empreinte_fonctions
"""

# Controle GLOBAL du baseline (chantier 2E). Ne porte pas sur un domaine mais sur
# tout le schema public. Il renvoie une seule ligne jsonb, donc il ne devie pas
# dans un fichier et peut etre relu directement.
#
# Il repond a deux questions distinctes, et c'est voulu :
#   1. COMPLETUDE  -- les totaux du catalogue se decomposent-ils exactement en
#      « rendu dans le baseline » + « ecarte deliberement » ? Aucun objet ne peut
#      donc disparaitre en silence : il est soit rendu, soit nomme comme ecarte.
#   2. FIDELITE    -- les empreintes du perimetre RETENU, calculees par la base,
#      correspondent-elles a ce qui est ecrit sur le disque ?
#
# {exclues} recoit la liste des tables classees hors_baseline en 2C. Elle est
# passee explicitement pour que l'exclusion soit lisible DANS la requete, et non
# cachee dans un script.
#
# COLLATE "C" sur toutes les empreintes ordonnees : cf. le commentaire de
# INVENTAIRE ci-dessus. Ce n'est pas une precaution, c'est une correction.
CONTROLE_GLOBAL = """
with hors(t) as (values {exclues}),
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
                 case when p.polpermissive then '' else E'\\n  AS RESTRICTIVE' end,
                 case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                               when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end,
                 case when p.polroles = '{{0}}'::oid[] then 'PUBLIC'
                      else (select string_agg(quote_ident(r.rolname), ', ' order by r.rolname)
                            from pg_roles r where r.oid = any(p.polroles)) end,
                 case when p.polqual is not null
                      then E'\\n  USING (' || pg_get_expr(p.polqual, p.polrelid, true) || ')' else '' end,
                 case when p.polwithcheck is not null
                      then E'\\n  WITH CHECK (' || pg_get_expr(p.polwithcheck, p.polrelid, true) || ')' else '' end
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
select jsonb_build_object(
 'totaux', jsonb_build_object(
   'tables', (select count(*) from tab),
   'vues', (select count(*) from rel where relkind = 'v'),
   'sequences', (select count(*) from rel where relkind = 'S'),
   'colonnes', (select count(*) from col),
   'contraintes', (select count(*) from kon),
   'index', (select count(*) from idx),
   'index_portes', (select count(*) from idx where portee),
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
      from com o where o.objet not in (select t from hors)) z)),
 'securite', jsonb_build_object(
   'fonctions_security_definer', (select count(*) from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind in ('f','p') and p.prosecdef),
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
 'releve_le', now() at time zone 'Europe/Paris'
) as controle_global
"""

CATEGORIES = {
    "tables": TABLES, "sequences": SEQUENCES, "contraintes": CONTRAINTES,
    "index": INDEX, "vues": VUES, "fonctions": FONCTIONS, "triggers": TRIGGERS,
    "rls": RLS, "policies": POLICIES, "droits": DROITS,
    "droits_colonnes": DROITS_COLONNES, "commentaires": COMMENTAIRES,
    "inventaire": INVENTAIRE,
}


def requete(domaine, categorie):
    conf = json.load(open(DOMAINES, encoding="utf-8"))
    if domaine not in conf:
        raise SystemExit("domaine inconnu : " + domaine)
    if categorie not in CATEGORIES:
        raise SystemExit("categorie inconnue : " + categorie)
    d = conf[domaine]
    return CATEGORIES[categorie].format(
        tables=litteral(d["tables"]),
        fonctions=litteral(d["fonctions"]),
    ).strip()


def tables_hors_baseline():
    """Lit dans la classification 2C les tables classees hors_baseline. Source
    unique : la liste n'est jamais recopiee dans le code."""
    import csv
    chemin = os.path.join(RACINE, "baseline", "classification-donnees.csv")
    with open(chemin, encoding="utf-8") as fh:
        return [l["table"] for l in csv.DictReader(fh, delimiter=";")
                if l["strategie"] == "hors_baseline"]


def requete_controle_global():
    return CONTROLE_GLOBAL.format(exclues=litteral(tables_hors_baseline())).strip()


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--controle-global":
        print(requete_controle_global())
        return 0
    if len(sys.argv) == 2 and sys.argv[1] == "--liste":
        print("categories : " + ", ".join(sorted(CATEGORIES)))
        conf = json.load(open(DOMAINES, encoding="utf-8"))
        print("domaines   : " + ", ".join(k for k in conf if not k.startswith("_")))
        return 0
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    print(requete(sys.argv[1], sys.argv[2]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
