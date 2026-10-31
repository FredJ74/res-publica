#!/usr/bin/env python3
"""Mutation de nos seuls fichiers preparatoires, restauration obligatoire, PostgreSQL jetable.
Ne se connecte jamais a Supabase ; exige un echec d'assertion precis pour chaque mutant.
"""
from pathlib import Path
import subprocess,sys,tempfile,json
R=Path(__file__).resolve().parents[2]
import runpy
_sources=runpy.run_path(str(R/'outils/bancs/banc-audit-securite-135-local.py'))
M='migrations/'
CAS=[
 ('piles_dupliquees',M+'20261027210800_inventaire_depot_piles_historiques.sql','CASE WHEN o=v_pile',"CASE WHEN coalesce((e->>'stackable')::boolean,false) AND e->>'stackKey'=v_cle",'banc-inventaire-receptions-local.py','piles historiques : une seule unite ajoutee'),
 ('nonce_libre',M+'20261027210810_inventaire_sels_objets_trouves.sql','IF r.action IS DISTINCT FROM p_action OR r.parametres IS DISTINCT FROM p_parametres THEN','IF false THEN','banc-inventaire-receptions-local.py','nonce lie aux parametres'),
 ('fret_sans_depot',M+'20261027213520_inventaire_fret_transactionnel.sql','d:=public.fret_deposer_objet_interne(a.name,l.objet,q);',"d:='{}'::jsonb;",'banc-inventaire-fret-local.py','reprise conserve quantites identite et metadonnees'),
 ('colis_non_protege',M+'20261027213521_inventaire_employes_socle.sql','IF public.inventaire_objet_protege(a.quete_carriere,o) THEN','IF false THEN','banc-inventaire-employes-local.py','colis protege par helper commun cote serveur'),
 ('budget_non_credite',M+'20261027213522_inventaire_accessoires_club.sql',"coalesce((budget->>'caisse')::numeric,0)+prix","coalesce((budget->>'caisse')::numeric,0)+0",'banc-inventaire-club-local.py','credit exact du budget existant'),
 ('succession_non_resolue',M+'20261027214001_inventaire_etat_civil_documents.sql',"AND statut='resolue'","AND true",'banc-inventaire-etat-civil-local.py','succession non resolue non divulguee ni delivree'),
 ('mission_reemise',M+'20261027214213_inventaire_missions_et_enigme.sql',"AND action='mission_carriere' AND parametres=params)","AND false AND action='mission_carriere' AND parametres=params)",'banc-inventaire-missions-local.py','ancienne sauvegarde ne reemet pas le colis'),
 ('delai_ignore',M+'20261027214213_inventaire_missions_et_enigme.sql','>=3*86400','>=0','banc-inventaire-missions-local.py','pas de calepin avant 72 heures reelles'),
]
def main():
 out=Path(tempfile.mkdtemp(prefix='hg-contre-inventaire-'));resultats=[]
 for nom,file,avant,apres,banc,message in CAS:
  p=_sources['chemin_source'](file);initial=p.read_bytes();src=initial.decode()
  if src.count(avant)!=1:raise AssertionError((nom,'ancrage',src.count(avant)))
  try:
   p.write_text(src.replace(avant,apres));r=subprocess.run([sys.executable,str(R/'outils/bancs'/banc)],cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
  finally:p.write_bytes(initial)
  (out/(nom+'.log')).write_text(r.stdout)
  valide=r.returncode!=0 and ('AssertionError: '+message) in r.stdout
  resultats.append({'mutant':nom,'detecte':valide,'code':r.returncode})
  print(('OK' if valide else 'ECHEC'),nom,flush=True)
  if not valide:print(r.stdout[-2000:])
 (out/'resultats.json').write_text(json.dumps(resultats,indent=2)+'\n');print('Preuves :',out)
 if not all(r['detecte'] for r in resultats):raise SystemExit(1)
 print(f'{len(CAS)}/{len(CAS)} contre-epreuves detectees, fichiers restaures, aucune connexion distante.')
if __name__=='__main__':main()
