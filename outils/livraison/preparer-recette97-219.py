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
 # Le plan 97 est une photographie HISTORIQUE des 461 triplets. Deux ordres SSM
 # gratuits ont ete ajoutes depuis (rendez-vous puis information Pascale).
 # Ils n'etaient pas executes par ce plan : les exclure de la comparaison
 # historique, mais les controler explicitement dans le catalogue actuel.
 ajouts_ssm=('ssm_besoin_aide','ssm_demander_rendezvous')
 hors_coupe=sorted((x for x in source if x['fn'] in ajouts_ssm),key=lambda x:x['fn'])
 if hors_coupe!=[{'fn':'ssm_besoin_aide','pa':0,'cost':0},
                 {'fn':'ssm_demander_rendezvous','pa':0,'cost':0}]:
  raise ValueError('Ordres SSM non conformes ou absents du catalogue actuel')
 # Le catalogue manufacturé gratuit remplace deux anciens boutons (04/11/2026).
 # Ce nouveau point d'entrée n'existait pas lors du plan 97. Les deux anciens
 # ordres restent dans la photographie d'origine, sans revenir à l'écran.
 ajouts_manufactures=('consulter_catalogue_manufactures',)
 hors_coupe_manufactures=[x for x in source if x['fn'] in ajouts_manufactures]
 if hors_coupe_manufactures!=[{'fn':'consulter_catalogue_manufactures','pa':0,'cost':0}]:
  raise ValueError('Catalogue manufacturé absent ou tarif inattendu')
 # Six parcelles de PSM (decision de Fred, 04/11/2026) : nouveaux prix d'achat (12 FR/m²)
 # des lots 9, 11, 12 et 13, absents du plan 97 (26 400 FR existait deja a Montrouge). Exclus de la photographie, controles ici.
 ajouts_terrains_psm=[{'fn':'acheter_terrain','pa':2,'cost':c} for c in (19800,37200,50400,66000)]
 cle=lambda x:(x['fn'],x['pa'],x['cost'])
 if not all(any(cle(x)==cle(t) for x in source) for t in ajouts_terrains_psm):
  raise ValueError('Prix des terrains de PSM absents du catalogue actuel')
 # Nouvelle gamme petro-chimique (04/11) : absente de la coupe historique.
 # Controle explicite de l'unique ordre de la sous-famille, sans polluer l'empreinte du plan 97.
 ajouts_petrochimie=[{'fn':'produire_derives_petrochimiques','pa':1,'cost':0}]
 if [x for x in source if x['fn'] in {t['fn'] for t in ajouts_petrochimie}] != ajouts_petrochimie:
  raise ValueError('Ordres petro-chimiques manquants, dupliques ou mal tarifes')
 ajouts_naval=[{'fn':'consulter_devis_chantier_naval','pa':0,'cost':0}]
 if [x for x in source if x['fn']=='consulter_devis_chantier_naval']!=ajouts_naval:
  raise ValueError('Devis naval absent ou tarif anormal')
 source_historique=[x for x in source if x['fn'] not in ajouts_ssm+ajouts_manufactures and cle(x) not in {cle(t) for t in ajouts_terrains_psm} and x not in ajouts_petrochimie+ajouts_naval]
 # Les deux virements bancaires sont désormais un sous-menu graphique (04/11) :
 # leurs anciens triplets sont maintenus dans la photographie d'origine,
 # et le menu gratuit 'virements' n'appartenait pas au plan 97.
 menu_virements=('virements',)
 if [x for x in source if x['fn'] in menu_virements]!=[{'fn':'virements','pa':0,'cost':0}]:
  raise ValueError('Menu Virements absent ou facture : un choix ne coute aucun PA')
 source_historique=[x for x in source_historique if x['fn'] not in menu_virements]
 # Ordres retirés depuis la coupe historique : restauration UNIQUEMENT pour
 # vérifier son empreinte d'origine, jamais dans le catalogue de jeu courant.
 retires=[{'fn':'assigner_mission','pa':1,'cost':0},
          {'fn':'fabriquer_armoire_souvenirs','pa':3,'cost':0},
          {'fn':'acheter_armoire_souvenirs','pa':0,'cost':0},
          {'fn':'virement_joueur','pa':1,'cost':0},
          {'fn':'virement_automatique','pa':1,'cost':0}]
 if any(x['fn'] in {r['fn'] for r in retires} for x in source):
  raise ValueError('Un ordre retiré ne doit plus figurer au catalogue actuel')
 source_historique=source_historique+retires
 cmp=module('delta_recette97','outils/baseline/comparer-couts-captures.py')
 ts=sorted(cmp.triples(source_historique))
 md5=hashlib.md5('\n'.join('%s|%d|%d'%t for t in ts).encode()).hexdigest()
 triplets_actuels=sorted(cmp.triples(source))
 md5_actuel=hashlib.md5('\n'.join('%s|%d|%d'%t for t in triplets_actuels).encode()).hexdigest()
 rapport={'production_executee':False,'execution_autorisee':False,'migrations':es,'nombre':97,'tarifs_source':{'lignes':len(ts),'md5':md5},'tarifs_ajoutes_apres_plan97':hors_coupe,'tarifs_ajoutes_manufactures':hors_coupe_manufactures,'tarifs_ajoutes_petrochimie':ajouts_petrochimie,'tarifs_ajoutes_naval':ajouts_naval,'tarifs_actuels':{'lignes':len(triplets_actuels),'md5':md5_actuel},'ancien_plan_tarifaire_conforme_source':couts['apres']=={'lignes':len(ts),'md5':md5},'etapes':['valider paquet atomique et SHA indépendants','rendre et seeds depuis les exports ; comparer six racines, douze référentiels et locale','réconcilier le delta tarifaire complet ; régénérer le plan SQL et ses contrôles','95 : panne tardive + rollback, installation atomique, rejeu refusé sans mutation','recettes groupes/organisations puis #318 et #324 dans cet ordre, avec leurs gardes et reçus de registre','recette finale GoTrue/PostgREST : 27 cas, puis contre-épreuves et contrôles globaux'], 'limite':'Plan d’ordre et de provenance seulement ; aucun clone courant certifié ni migration exécutée.'}
 if paquet:
  editor=module('paquet_recette97','outils/livraison/export-sql-editor-219.py');paquet=Path(paquet).resolve()
  # Les sept octets originaux doivent être présents, pas une reconstruction manuelle.
  fs={e['fichier']:(paquet/e['fichier']).read_bytes() for e in editor.manifeste()['requetes']};ann=editor.lire_json((paquet/editor.MANIFESTE).read_bytes());docs,_=editor.verifier_documents(fs,ann)
  for e in ann['fichiers']:
   if len(fs[e['fichier']])!=e['octets'] or editor.h(fs[e['fichier']])!=e['sha256']:raise ValueError('Intégrité privée contraire au manifeste')
  rapport['registre_capture']=docs['empreinte']['registre'];rapport['delta_tarifaire_a_revoir']=cmp.comparer(source_historique,docs['referentiels']['ordres_couts'])
 return rapport
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--paquet',type=Path);a.add_argument('--sortie',type=Path,required=True);o=a.parse_args();sortie=o.sortie.resolve();relais=module('prive_plan97','outils/livraison/relais-canonique-219.py')
 if any(relais.marqueur_git_actif(p) for p in (sortie,*sortie.parents)):a.error('Plan privé hors Git requis')
 v=preparer(o.paquet);fd=os.open(sortie,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f:json.dump(v,f,ensure_ascii=False,indent=2)
 print(json.dumps({k:v[k] for k in ('nombre','production_executee','execution_autorisee','tarifs_source','ancien_plan_tarifaire_conforme_source')}))
if __name__=='__main__':main()
