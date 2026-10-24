#!/usr/bin/env python3
"""Trois régressions injectées uniquement dans PostgreSQL jetable, aucune source modifiée."""
from pathlib import Path
import subprocess,sys,json
R=Path(__file__).resolve().parents[2]
cas={'jour_rejoue':'rejeu quotidien aucun paiement supplementaire','prix_uniformises':'superficie et prix propres a terrain-a-batir-2','tranche_modifiee':'appel de fonds cumul 35 70 100'}
resultats=[]
for mutant,preuve in cas.items():
 p=subprocess.run([sys.executable,str(R/'outils/bancs/banc-parcours-terrain-construction-135-local.py'),'--mutant='+mutant],cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 ok=p.returncode!=0 and preuve in p.stdout
 resultats.append({'mutant':mutant,'echec_attendu':ok,'code':p.returncode})
 print(('OK ' if ok else 'NON ')+mutant,flush=True)
 if not ok:print(p.stdout[-2500:])
print(json.dumps({'production':False,'contre_epreuves':resultats}))
raise SystemExit(not all(x['echec_attendu'] for x in resultats))
