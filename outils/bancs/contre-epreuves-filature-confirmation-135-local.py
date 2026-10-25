#!/usr/bin/env python3
"""Mutations du code chargé dans la base jetable ; aucun SQL publié altéré."""
from pathlib import Path
import subprocess,sys,json
R=Path(__file__).resolve().parents[2]
cas={'pa':'ecriture ignoree acceptee','caisse':'ecriture ignoree acceptee','identite':'UID du compte authentifie requis'}
resultats=[]
for mutant,preuve in cas.items():
 p=subprocess.run([sys.executable,str(R/'outils/bancs/banc-filature-confirmation-135-local.py'),'--mutant='+mutant],cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 ok=p.returncode!=0 and preuve in p.stdout
 resultats.append({'mutant':mutant,'echec_attendu':ok,'code':p.returncode})
 print(('OK ' if ok else 'NON ')+mutant,flush=True)
 if not ok:print(p.stdout[-2500:])
print(json.dumps({'production':False,'contre_epreuves':resultats}))
raise SystemExit(not all(x['echec_attendu'] for x in resultats))
