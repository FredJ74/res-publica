#!/usr/bin/env python3
"""Compose les lots existants (5 + 89 + tarifs), ne les exécute jamais."""
import argparse,hashlib,importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def charger(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def corps_transaction(sql):
 from pglast import parse_sql
 x=parse_sql(sql);begin=parse_sql('BEGIN;')[0].stmt.kind;commit=parse_sql('COMMIT;')[0].stmt.kind
 if len(x)<3 or type(x[0].stmt).__name__!='TransactionStmt' or x[0].stmt.kind!=begin or type(x[-1].stmt).__name__!='TransactionStmt' or x[-1].stmt.kind!=commit or any(type(t.stmt).__name__=='TransactionStmt' for t in x[1:-1]):raise ValueError('Une seule enveloppe transactionnelle attendue')
 return sql[x[1].stmt_location:x[-1].stmt_location]

def preparer(destination=None):
 org=charger('org219','outils/livraison/preparer-organisations-219.py');grp=charger('grp219','outils/livraison/preparer-groupes-219.py')
 om=json.loads(org.MAN.read_text());gm=json.loads(grp.MAN.read_text());cm=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text());p=R/cm['migration'];cout=p.read_text()
 if hashlib.sha256(p.read_bytes()).hexdigest()!=cm['sha256']:raise ValueError('Migration de tarifs modifiée')
 gen=json.loads(subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],cwd=R,text=True));t=sorted((r['fn'],r['pa'],r['cost']) for r in gen);md5=hashlib.md5('\n'.join('%s|%d|%d'%r for r in t).encode()).hexdigest()
 if md5!=cm['apres']['md5'] or len(t)!=cm['apres']['lignes']:raise ValueError('Sources de tarifs changées : réexaminer le plan')
 entrees=om['migrations']+gm['prerequis']+gm['migrations']+[{'version':cm['version'],'fichier':cm['migration'],'sha256':cm['sha256']}]
 versions=[e['version'] for e in entrees]
 if len(entrees)!=95 or versions!=sorted(set(versions)):raise ValueError('Ordre exact 5 + 89 + 1 requis')
 with tempfile.TemporaryDirectory(prefix='hg219-compose-') as d:
  f=Path(d)/'groupe.sql';grp.preparer(f,inclure_prerequis=True);groupe=f.read_text()
 citer=lambda v:"'"+v.replace("'","''")+"'"
 sql="""-- PR #219 : composition préparée, NON exécutée et NON validée contre le catalogue 1008.
-- Aucun des 65 autres préparatifs n'est inclus. Pas de déploiement autorisé ici.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='120s';
DO $versions_globales$ BEGIN
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version IN ("""+','.join(citer(v) for v in versions)+""")) THEN RAISE EXCEPTION '219_complet_versions_presentes_prevol_frais_requis';END IF;
END $versions_globales$;
"""
 sql+=corps_transaction(org.preparer())+'\n'+corps_transaction(groupe)+'\n'+cout+'\n'
 sql+='INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES('+citer(cm['version'])+','+citer(p.stem[15:])+',ARRAY['+citer(cout)+']);\nCOMMIT;\n'
 from pglast import parse_sql
 if len([x for x in parse_sql(sql) if type(x.stmt).__name__=='TransactionStmt'])!=2:raise ValueError('Transaction interne détectée')
 if destination:Path(destination).write_text(sql)
 return sql,entrees
if __name__=='__main__':
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--sortie');o=a.parse_args();sql,entrees=preparer(o.sortie);print(json.dumps({'migrations':len(entrees),'sha256':hashlib.sha256(sql.encode()).hexdigest(),'transaction_unique':True,'production_executee':False,'compatibilite_catalogue1008':'non_verifiee'},ensure_ascii=False,indent=2))
