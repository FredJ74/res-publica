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

DROITS = """
with dom(t) as (values {tables}), fdom(sig) as (values {fonctions}),
objets as (
  select 'TABLE' as genre, c.relname as objet, c.relacl as acl
  from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  where c.relname in (select t from dom)
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


def main():
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
