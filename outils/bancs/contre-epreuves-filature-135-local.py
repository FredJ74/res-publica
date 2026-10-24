#!/usr/bin/env python3
"""Corruptions en mémoire sur PostgreSQL jetable, jamais du SQL publié ou de la production."""
from pathlib import Path
import subprocess,sys,json
R=Path(__file__).resolve().parents[2]
cas={'rejeu':'acte_benediction_deja_traite','caisse':'deux PA personnels et 150 FR institutionnels','badge':'badge de presentation ne donne aucun pouvoir'}
resultats=[]
for mutant,preuve in cas.items():
 p=subprocess.run([sys.executable,str(R/'outils/bancs/banc-filature-benediction-135-local.py'),'--mutant='+mutant],cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 ok=p.returncode!=0 and preuve in p.stdout
 resultats.append({'mutant':mutant,'echec_attendu':ok,'code':p.returncode})
 print(('OK ' if ok else 'NON ')+mutant,flush=True)
 if not ok:print(p.stdout[-2500:])
print(json.dumps({'production':False,'contre_epreuves':resultats}))
raise SystemExit(not all(r['echec_attendu'] for r in resultats))
