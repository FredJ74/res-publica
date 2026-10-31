#!/usr/bin/env python3
"""Épreuve PostgreSQL locale du baseline canonique, sans migrations historiques.

N'accepte aucune URL de base : démarre seulement un serveur éphémère local.
Le schéma vient exclusivement de reconstruire.assembler(). Aucun remplacement
MAINTAIN, aucune erreur ignorée. Les dépendances de fonctions sont résolues
après création des vues, puis tous les corps sont recompilés avec vérification.
"""
import argparse
import importlib.util
import json
import hashlib
import re
import csv
from pathlib import Path
import sys
import tempfile

ICI = Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
from reconstruire import assembler, decouper

PLATEFORME = """
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY, email text, raw_user_meta_data jsonb,
 raw_app_meta_data jsonb, created_at timestamptz, is_anonymous boolean, email_confirmed_at timestamptz);
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS
 $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
 $$ SELECT nullif(coalesce(auth.jwt()->>'sub',current_setting('request.jwt.claim.sub',true)),'')::uuid $$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS
 $$ SELECT auth.jwt()->>'role' $$;
GRANT USAGE ON SCHEMA auth TO anon,authenticated,service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon,authenticated,service_role;
CREATE SCHEMA extensions;
"""


def installer(q, morceaux):
    """Toute erreur remonte ; l'appelant annule toute la transaction.

    Retourne le nombre d'ordres et de fonctions réellement recompilées.
    check_function_bodies=off ne sert qu'à la déclaration initiale des routines,
    jamais à accepter leur compilation finale ni celle des migrations.
    """
    n, fonctions, recompiles = 0, [], 0
    for origine, sql in morceaux:
        for ast, texte in decouper(sql):
            fonction = type(ast).__name__ == 'CreateFunctionStmt'
            try:
                q.execute('SET LOCAL check_function_bodies=' + ('off' if fonction else 'on'))
                q.execute(texte)
                n += 1
                if fonction:
                    fonctions.append((origine, texte))
            except Exception as e:
                raise RuntimeError(f'{origine}, ordre {n+1}, SQLSTATE {getattr(e,"pgcode",None)} : {str(e).splitlines()[0]}') from e
    q.execute('SET LOCAL check_function_bodies=on')
    # PostgreSQL fournit lui-même CREATE OR REPLACE, y compris si le DDL
    # initial était CREATE FUNCTION sans OR REPLACE. Droits conservés.
    q.execute("SELECT p.oid::regprocedure::text,pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind IN ('f','p') ORDER BY p.oid")
    definitions=q.fetchall()
    for signature, texte in definitions:
        try:
            q.execute(texte)
            recompiles += 1
        except Exception as e:
            raise RuntimeError(f'{signature}, recompilation finale : {str(e).splitlines()[0]}') from e
    return {'ordres': n, 'fonctions_recompilees': recompiles}


def lire_registre(chemin):
    """Registre réel communiqué ; jamais une liste vide pour forcer le prévol."""
    valeur=json.loads(Path(chemin).read_text())
    # Le relais Git communiqué contient directement les 1 002 lignes, pas
    # une seule ligne MCP enveloppant un champ registre.
    if isinstance(valeur,list) and valeur and all(isinstance(x,dict) and 'version' in x for x in valeur):
        lignes=valeur
    else:
        if isinstance(valeur,list):
            if len(valeur)!=1:raise ValueError('Un relevé de registre attendu')
            valeur=valeur[0]
        if isinstance(valeur,dict) and 'prevol_219' in valeur:valeur=valeur['prevol_219']
        lignes=valeur.get('registre') if isinstance(valeur,dict) else None
    if not isinstance(lignes,list) or not lignes:raise ValueError('Registre vivant complet absent, installation du lot refusée')
    versions=set()
    for ligne in lignes:
        if not isinstance(ligne,dict) or not isinstance(ligne.get('version'),str) or not re.fullmatch(r'\d{14}',ligne.get('version','')) or ligne['version'] in versions:
            raise ValueError('Version de registre invalide ou dupliquée')
        versions.add(ligne['version'])
    return lignes


def expression_check(definition):
    """Arbre syntaxique d'un CHECK, avec associativité AND/OR seulement.

    PostgreSQL aplatit les deux premiers termes lors du retour DDL/catalogue.
    Ni opérateur, ni constante, ni ordre, ni cast ne sont ignorés.
    """
    from pglast.parser import parse_sql_json
    arbre=json.loads(parse_sql_json('CREATE TABLE t (x integer, '+definition+')'))
    def normaliser(x):
        if isinstance(x,list):return [normaliser(v) for v in x]
        if not isinstance(x,dict):return x
        y={k:normaliser(v) for k,v in x.items() if k not in ('location','stmt_location','stmt_len')}
        if 'BoolExpr' in y:
            b=y['BoolExpr'];args=[]
            for v in b.get('args',[]):
                if isinstance(v,dict) and v.get('BoolExpr',{}).get('boolop')==b.get('boolop') and b.get('boolop') in ('AND_EXPR','OR_EXPR'):
                    args.extend(v['BoolExpr']['args'])
                else:args.append(v)
            b['args']=args
        return y
    return normaliser(arbre)


def comparer_catalogues(q, repertoire):
    # Les mêmes requêtes, jamais une photographie SQL reconstruite de mémoire.
    from rendre import charger_exports
    from requetes import EXPORTS
    attendu,_=charger_exports(str(repertoire))
    with open(ICI.parents[1]/'baseline/classification-donnees.csv',encoding='utf-8') as f:
        exclues={x['table'] for x in csv.DictReader(f,delimiter=';') if x['strategie']=='hors_baseline'}
    def retenue(x):
        if x.get('tbl') in exclues:return False
        return not (x.get('genre') in ('TABLE','SEQUENCE','COLUMN','CONSTRAINT') and x.get('objet') in exclues)
    def dans_perimetre(categorie,x):
        if categorie=='droits_par_defaut':
            # Même périmètre EXPLICITE que rendre.phase_defauts : les ACL
            # des services Supabase et du schéma storage ne sont pas rejouées.
            return x['administrable'] and x['portee'] in (None,'public')
        return retenue(x)
    def comparable(categorie,x):
        if categorie=='contraintes' and x.get('genre')=='c':
            return {**{k:v for k,v in x.items() if k not in ('definition','empreinte')},
                    'expression':expression_check(x['definition'])}
        return x
    differences=[]
    for export,requete in EXPORTS.items():
        q.execute(requete);obtenu=q.fetchone()[0]
        for categorie,lignes in obtenu.items():
            source=[x for x in (attendu[categorie] or []) if dans_perimetre(categorie,x)]
            cible=[x for x in (lignes or []) if dans_perimetre(categorie,x)]
            if [comparable(categorie,x) for x in source]!=[comparable(categorie,x) for x in cible]:
                exemples=[]
                for i in range(max(len(source),len(cible))):
                    a=source[i] if i<len(source) else None;b=cible[i] if i<len(cible) else None
                    if a!=b:
                        exemples.append({'source':a,'local':b})
                        if len(exemples)==2:break
                differences.append({'export':export,'categorie':categorie,'source':len(source),'local':len(cible),'exemples':exemples})
    return differences


def configurer_binaires(chemin):
    """Même gestionnaire pgserver épinglé ; seuls ses binaires locaux changent."""
    import pgserver._commands as commandes
    import pgserver.postgres_server as serveurs
    chemin=Path(chemin).resolve()
    for nom in ['postgres','initdb','pg_ctl']:
        if not (chemin/nom).is_file():raise ValueError('Binaire local absent : '+nom)
    commandes.POSTGRES_BIN_PATH=chemin
    serveurs.POSTGRES_BIN_PATH=chemin


def installer_prerequis_233(q):
    """Dépendance préparée sur main, explicitement distincte du catalogue reçu.

    Absente des 1003 versions et du catalogue : ni présumée appliquée, ni
    confondue avec les 88 migrations #219. Installée uniquement sur base jetable.
    """
    p=ICI.parents[1]/'migrations/20261029181000_squatteurs_issue_combat.sql'
    texte=p.read_text()
    if q.execute("SELECT to_regprocedure('public.terrain_squatteurs_issue_interne(text,text,text,uuid)')") is not None:
        raise RuntimeError('Erreur de lecture du prérequis')
    if q.fetchone()[0] is not None:raise RuntimeError('Prérequis #233 déjà présent : réconcilier, ne pas écraser')
    q.execute(texte)
    return {'source':str(p.relative_to(ICI.parents[1])),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
            'portee':'Dépendance préparée #233 distincte des 88 migrations, installée seulement en local.'}


def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('--rapport',type=Path,required=True)
    a.add_argument('--diagnostic-version-differente',action='store_true',help='Ne certifie jamais la fidélité si le moteur diffère de PG17.')
    a.add_argument('--lot-219',action='store_true',help='Après reconstruction et compilation réussies seulement.')
    a.add_argument('--prerequis-233',action='store_true',help='Installer explicitement la dépendance #233 manquante sur le décor local, sans la déclarer en production.')
    a.add_argument('--schema-seul',action='store_true',help='Épreuve explicite du catalogue, sans prétendre avoir installé les seeds du monde.')
    a.add_argument('--registre',type=Path,help='Export JSON du registre vivant complet, métadonnées seulement, requis avec --lot-219.')
    a.add_argument('--exports',type=Path,help='Quatre exports complets servant à comparer le catalogue reconstruit.')
    a.add_argument('--postgres-bin',type=Path,help='Répertoire de binaires PostgreSQL locaux ; aucune adresse de base distante.')
    args=a.parse_args()
    import pgserver,psycopg2
    if args.postgres_bin:
        configurer_binaires(args.postgres_bin)
    rapport={'production':False,'historique_rejoue':False,'donnees_joueurs_copiees':False,'reconstruction':False,'lot_219_installe':False,'fidelite_catalogue_vivant':False,'plateforme_auth':'Primitives SQL locales de fixture ; pas de service GoTrue ni de connexion réelle.'}
    c=None
    try:
        with tempfile.TemporaryDirectory(prefix='hg-baseline-pg-') as d:
            serveur=pgserver.get_server(Path(d)/'data',cleanup_mode='delete')
            try:
                c=psycopg2.connect(serveur.get_uri());q=c.cursor()
                q.execute('SHOW server_version_num');version=int(q.fetchone()[0]);rapport['version_moteur']=version
                if version//10000!=17 and not args.diagnostic_version_differente:
                    raise RuntimeError('Moteur PostgreSQL 17 requis ; aucune substitution de grammaire/privilège autorisée. Diagnostic explicite possible sans certification.')
                for role in ['anon','authenticated','service_role','authenticator','supabase_auth_admin','supabase_admin','dashboard_user','supabase_read_only_user']:
                    q.execute('CREATE ROLE '+role)
                q.execute(PLATEFORME)
                morceaux,_=assembler()
                if args.schema_seul:morceaux=[(n,s) for n,s in morceaux if not n.startswith('seeds/')]
                rapport['seeds_installes']=not args.schema_seul
                rapport.update(installer(q,morceaux));rapport['reconstruction']=True
                if args.exports:
                    rapport['ecarts_catalogue']=comparer_catalogues(q,args.exports)
                    if rapport['ecarts_catalogue']:raise RuntimeError('Catalogue reconstruit différent des exports : lot interdit')
                    rapport['fidelite_catalogue_vivant']=True
                if args.lot_219:
                    if not args.exports:raise RuntimeError('Quatre exports complets requis avant installation du lot')
                    if not args.registre:raise RuntimeError('Export du registre vivant requis ; aucun faux registre vide créé')
                    registre=lire_registre(args.registre)
                    if args.prerequis_233:rapport['prerequis_233_local']=installer_prerequis_233(q)
                    rapport['registre_sha256']=hashlib.sha256(args.registre.read_bytes()).hexdigest()
                    rapport['registre_versions']=len(registre)
                    q.execute('CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,name text,statements text[])')
                    q.executemany('INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES(%s,%s)',[(x['version'],x.get('name')) for x in registre])
                    spec=importlib.util.spec_from_file_location('lot219',ICI.parent/'livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
                    f=Path(d)/'lot.sql';rapport['migrations_preparees']=m.preparer(str(f))
                    # Métadonnées du registre réel, pas une liste vide inventée.
                    c.commit();q.execute(f.read_text());rapport['lot_219_installe']=True
                c.commit()
                rapport['limite']='Catalogue public comparé dans le périmètre déclaré du baseline (hors cinq tables exclues et services plateforme). Auth SQL locale : aucune recette GoTrue authentifiée réelle.'
            finally:
                if c is not None:c.close()
                serveur._cleanup()
    except Exception as e:
        rapport['erreur']=str(e)
    args.rapport.parent.mkdir(parents=True,exist_ok=True)
    args.rapport.write_text(json.dumps(rapport,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(rapport,ensure_ascii=False,indent=2))
    # Une reconstruction n'est pas une homologation du catalogue externe.
    return 0 if 'erreur' not in rapport and rapport['reconstruction'] and rapport.get('version_moteur',0)//10000==17 and (not args.lot_219 or rapport['lot_219_installe']) else 1

if __name__=='__main__':sys.exit(main())
