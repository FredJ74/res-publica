#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Inventaire des RPC du navigateur APRES le lot de migrations/, sans base.

Complément hors ligne de `epreuve-postgresql.py::verifier_rpc_clients`, qui
exige le clone de la capture privée. Ici : baseline (fonctions + droits
EXECUTE) puis, dans l'ordre des fichiers de migrations/, les CREATE FUNCTION,
DROP FUNCTION et GRANT/REVOKE EXECUTE lus par l'AST (pglast). Les droits par
défaut de Supabase (EXECUTE nommé à anon/authenticated sur toute fonction
neuve) sont appliqués, puis corrigés par les REVOKE de la migration.

Limites assumées : un REVOKE produit par du SQL dynamique (EXECUTE format)
n'est pas vu ; le verdict de production reste celui du clone.

Usage : python3 outils/baseline/simuler-rpc-apres-lot.py [--json]
Sortie 0 si aucun écart, 1 sinon.
"""
import glob, importlib.util, json, os, re, sys
from pglast import parse_sql

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))


def charger_autorite():
    spec = importlib.util.spec_from_file_location('autorite', os.path.join(ICI, 'verifier-autorite.py'))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def type_norm(t):
    t = re.sub(r'\s+', ' ', t.strip().lower())
    t = re.sub(r'^public\.', '', t)
    alias = {'int': 'integer', 'int4': 'integer', 'int8': 'bigint', 'bool': 'boolean',
             'varchar': 'character varying', 'timestamptz': 'timestamp with time zone',
             'float8': 'double precision'}
    return alias.get(t, t)


def types_ast(fn_params):
    """Types des paramètres d'entrée (signature d'identité) et noms d'entrée."""
    types, noms, defauts = [], [], 0
    for p in fn_params or []:
        mode = getattr(p.mode, 'name', str(p.mode)) if p.mode is not None else 'FUNC_PARAM_IN'
        if mode in ('FUNC_PARAM_OUT', 'FUNC_PARAM_TABLE'):
            continue
        nom_t = '.'.join(x.sval for x in p.argType.names if x.sval != 'pg_catalog')
        if p.argType.arrayBounds:
            nom_t += '[]'
        types.append(type_norm(nom_t))
        noms.append(p.name or '')
        if p.defexpr is not None:
            defauts += 1
    return types, noms, defauts


def formes_baseline():
    """(nom, types) -> {noms, obligatoires, auth}"""
    f = {}
    for chemin in sorted(glob.glob(os.path.join(RACINE, 'baseline', 'domaines', '*', '20_fonctions*.sql'))):
        texte = open(chemin, encoding='utf-8').read()
        for morceau in re.split(r'(?m)^(?=CREATE OR REPLACE FUNCTION public\.)', texte):
            if not morceau.startswith('CREATE OR REPLACE FUNCTION'):
                continue
            try:
                st = parse_sql(morceau)[0].stmt
            except Exception:
                continue
            if type(st).__name__ != 'CreateFunctionStmt':
                continue
            nom = st.funcname[-1].sval
            types, noms, defauts = types_ast(st.parameters)
            f[(nom, tuple(types))] = {'noms': noms, 'obligatoires': len(noms) - defauts, 'auth': False, 'source': 'baseline'}
    for chemin in sorted(glob.glob(os.path.join(RACINE, 'baseline', 'domaines', '*', '70_droits.sql'))):
        for m in re.finditer(r'(?m)^GRANT EXECUTE ON FUNCTION public\.([a-z_0-9]+)\((.*?)\) TO authenticated;', open(chemin, encoding='utf-8').read()):
            cle = (m.group(1), tuple(type_norm(t) for t in m.group(2).split(',')) if m.group(2) else ())
            if cle in f:
                f[cle]['auth'] = True
    return f


def cibles_fonction(objets):
    """ObjectWithArgs -> liste de (nom, types|None)."""
    sortie = []
    for o in objets or []:
        nom = o.objname[-1].sval
        if getattr(o, 'args_unspecified', False) or o.objargs is None:
            sortie.append((nom, None))
        else:
            ts = []
            for a in o.objargs:
                t = '.'.join(x.sval for x in a.names if x.sval != 'pg_catalog')
                if a.arrayBounds:
                    t += '[]'
                ts.append(type_norm(t))
            sortie.append((nom, tuple(ts)))
    return sortie


def appliquer(f, chemin):
    texte = open(chemin, encoding='utf-8').read()
    try:
        arbres = parse_sql(texte)
    except Exception as e:
        return 'illisible : %s' % e
    base = os.path.basename(chemin)
    for r in arbres:
        st = r.stmt; genre = type(st).__name__
        if genre == 'CreateFunctionStmt' and st.funcname[0].sval in ('public',) and len(st.funcname) == 2:
            nom = st.funcname[-1].sval
            types, noms, defauts = types_ast(st.parameters)
            cle = (nom, tuple(types))
            ancien = f.get(cle)
            # CREATE OR REPLACE conserve les droits existants ; une fonction neuve
            # reçoit les droits par défaut nommés de Supabase.
            f[cle] = {'noms': noms, 'obligatoires': len(noms) - defauts,
                      'auth': ancien['auth'] if ancien else True, 'source': base}
        elif genre == 'DropStmt' and getattr(st.removeType, 'name', '') in ('OBJECT_FUNCTION', 'OBJECT_ROUTINE'):
            for objet in st.objects:
                for nom, types in cibles_fonction([objet]):
                    for cle in [k for k in f if k[0] == nom and (types is None or k[1] == types)]:
                        del f[cle]
        elif genre == 'GrantStmt' and getattr(st.objtype, 'name', '') in ('OBJECT_FUNCTION', 'OBJECT_ROUTINE'):
            roles = {getattr(g, 'rolename', None) or ('PUBLIC' if getattr(g.roletype, 'name', '') == 'ROLESPEC_PUBLIC' else '?') for g in st.grantees}
            if not ({'authenticated', 'PUBLIC'} & roles):
                continue
            privs = {p.priv_name for p in (st.privileges or [])} or {'all'}
            if not ({'execute', 'all'} & privs):
                continue
            if getattr(st.targtype, 'name', '') == 'ACL_TARGET_ALL_IN_SCHEMA':
                continue
            for nom, types in cibles_fonction(st.objects):
                for cle in [k for k in f if k[0] == nom and (types is None or k[1] == types)]:
                    if st.is_grant and 'authenticated' in roles:
                        f[cle]['auth'] = True
                    elif not st.is_grant and 'authenticated' in roles:
                        f[cle]['auth'] = False
    return None


def ecarts_apres_lot(appels=None):
    """Écarts des appels du navigateur contre baseline + migrations/ (dans l'ordre)."""
    if appels is None:
        appels = charger_autorite().rpc_du_navigateur()
    return calculer(appels)[0]


def calculer(appels):
    f = formes_baseline()
    illisibles = []
    for chemin in sorted(glob.glob(os.path.join(RACINE, 'migrations', '*.sql'))):
        e = appliquer(f, chemin)
        if e:
            illisibles.append((os.path.basename(chemin), e))
    par_nom = {}
    for (nom, types), v in f.items():
        par_nom.setdefault(nom, []).append(v)
    ecarts = []
    for nom, variantes in sorted(appels.items()):
        for passes, sites in variantes.items():
            formes = par_nom.get(nom, [])
            ok = [v for v in formes if passes <= set(v['noms']) and set(v['noms'][:v['obligatoires']]) <= passes]
            if any(v['auth'] for v in ok):
                continue
            diag = ('fonction_absente' if not formes else
                    'execution_client_refusee' if ok else 'parametres_incompatibles_ou_spread_non_resolu')
            ecarts.append({'fonction': nom, 'parametres': sorted(passes), 'sites': sorted(sites)[:3], 'diagnostic': diag,
                           'signatures': [{'noms': v['noms'], 'obligatoires': v['obligatoires'], 'auth': v['auth'], 'source': v['source']} for v in formes]})
    return ecarts, illisibles


def main():
    ecarts, illisibles = calculer(charger_autorite().rpc_du_navigateur())
    if '--json' in sys.argv:
        print(json.dumps({'ecarts': ecarts, 'illisibles': illisibles}, ensure_ascii=False, indent=1))
    else:
        for e in ecarts:
            print('%-28s %-46s %s  %s' % (e['diagnostic'], e['fonction'], ','.join(e['parametres']), e['sites'][0]))
        for nom, err in illisibles:
            print('ILLISIBLE', nom, err[:120])
        print('%d ecart(s) apres lot' % len(ecarts))
    return 1 if ecarts else 0


if __name__ == '__main__':
    sys.exit(main())
