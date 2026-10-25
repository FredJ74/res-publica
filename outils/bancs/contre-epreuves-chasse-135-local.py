#!/usr/bin/env python3
"""Mutations du code chargé dans la base jetable ; aucun SQL publié altéré."""
from pathlib import Path
import subprocess,sys,json
R=Path(__file__).resolve().parents[2]
cas={'reliquat_ignore':'reliquat cinq plus sanction evasion deux','cible_reutilisee':'nonce ne change pas de cible','bonus_reutilise':'bonus consomme une seule fois'}
resultats=[]
for mutant,preuve in cas.items():
 p=subprocess.run([sys.executable,str(R/'outils/bancs/banc-chasse-benediction-135-local.py'),'--mutant='+mutant],cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 ok=p.returncode!=0 and preuve in p.stdout
 resultats.append({'mutant':mutant,'echec_attendu':ok,'code':p.returncode})
 print(('OK ' if ok else 'NON ')+mutant,flush=True)
 if not ok:print(p.stdout[-2500:])
print(json.dumps({'production':False,'contre_epreuves':resultats}))
raise SystemExit(not all(x['echec_attendu'] for x in resultats))
