#!/usr/bin/env python3
"""Plan 95 + #318 + #324 et delta tarifaire privé. N'exécute aucune migration."""
import argparse,hashlib,importlib.util,json,os,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
COMPLEMENTS=('migrations/20261101170000_circuits_residuels_positions_219.sql','migrations/20261101171000_hospitalisation_pa0.sql')
def module(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def verifier_ordre(entrees):
 versions=[x['version'] for x in entrees]
 if len(entrees)!=97 or versions!=sorted(set(versions)) or [x['fichier'] for x in entrees[-2:]]!=list(COMPLEMENTS):raise ValueError('Ordre canonique 95 puis #318 puis #324 requis')
 for e in entrees:
  p=R/e['fichier']
  if hashlib.sha256(p.read_bytes()).hexdigest()!=e['sha256']:raise ValueError('Source de migration modifiée : '+p.name)
 return entrees
def preparer(paquet=None):
 org=json.loads((R/'outils/audits/LIVRAISON-ORGANISATIONS-219-20261031.json').read_text());grp=json.loads((R/'outils/audits/LIVRAISON-GROUPES-219-20261030.json').read_text());couts=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text())
 es=org['migrations']+grp['prerequis']+grp['migrations']+[{'version':couts['version'],'fichier':couts['migration'],'sha256':couts['sha256']}]
 for nom in COMPLEMENTS:es.append({'version':Path(nom).name[:14],'fichier':nom,'sha256':hashlib.sha256((R/nom).read_bytes()).hexdigest()})
 verifier_ordre(es)
 source=json.loads(subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],cwd=R,text=True))
 cmp=module('delta_recette97','outils/baseline/comparer-couts-captures.py');ts=sorted(cmp.triples(source));md5=hashlib.md5('\n'.join('%s|%d|%d'%t for t in ts).encode()).hexdigest()
 rapport={'production_executee':False,'execution_autorisee':False,'migrations':es,'nombre':97,'tarifs_source':{'lignes':len(ts),'md5':md5},'ancien_plan_tarifaire_conforme_source':couts['apres']=={'lignes':len(ts),'md5':md5},'etapes':['valider paquet atomique et SHA indépendants','rendre et seeds depuis les exports ; comparer six racines, douze référentiels et locale','réconcilier le delta tarifaire complet ; régénérer le plan SQL et ses contrôles','95 : panne tardive + rollback, installation atomique, rejeu refusé sans mutation','recettes groupes/organisations puis #318 et #324 dans cet ordre, avec leurs gardes et reçus de registre','recette finale GoTrue/PostgREST : 27 cas, puis contre-épreuves et contrôles globaux'], 'limite':'Plan d’ordre et de provenance seulement ; aucun clone courant certifié ni migration exécutée.'}
 if paquet:
  editor=module('paquet_recette97','outils/livraison/export-sql-editor-219.py');paquet=Path(paquet).resolve()
  # Les sept octets originaux doivent être présents, pas une reconstruction manuelle.
  fs={e['fichier']:(paquet/e['fichier']).read_bytes() for e in editor.manifeste()['requetes']};ann=editor.lire_json((paquet/editor.MANIFESTE).read_bytes());docs,_=editor.verifier_documents(fs,ann)
  for e in ann['fichiers']:
   if len(fs[e['fichier']])!=e['octets'] or editor.h(fs[e['fichier']])!=e['sha256']:raise ValueError('Intégrité privée contraire au manifeste')
  rapport['registre_capture']=docs['empreinte']['registre'];rapport['delta_tarifaire_a_revoir']=cmp.comparer(source,docs['referentiels']['ordres_couts'])
 return rapport
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--paquet',type=Path);a.add_argument('--sortie',type=Path,required=True);o=a.parse_args();sortie=o.sortie.resolve();relais=module('prive_plan97','outils/livraison/relais-canonique-219.py')
 if any(relais.marqueur_git_actif(p) for p in (sortie,*sortie.parents)):a.error('Plan privé hors Git requis')
 v=preparer(o.paquet);fd=os.open(sortie,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f:json.dump(v,f,ensure_ascii=False,indent=2)
 print(json.dumps({k:v[k] for k in ('nombre','production_executee','execution_autorisee','tarifs_source','ancien_plan_tarifaire_conforme_source')}))
if __name__=='__main__':main()
