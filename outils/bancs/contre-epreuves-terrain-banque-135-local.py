#!/usr/bin/env python3
"""Cinq corruptions réelles du code chargé sur PostgreSQL jetable ; chaque banc doit rougir."""
from pathlib import Path
import subprocess,sys,json
R=Path(__file__).resolve().parents[2]
cas={'prix_public':'prix officiel moins le depot exactement une fois','credit_fictif':'compte national reellement credite','rejeu_banque':'credit consommation idempotent','dette_legacy':'garde attendue','archive_collision':'deux ventes legitimes meme jour archives distinctes'}
resultats=[]
for mutant,motif in cas.items():
 p=subprocess.run([sys.executable,str(R/'outils/bancs/banc-terrain-banque-135-local.py'),'--apres-location','--mutant='+mutant],cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 ok=p.returncode!=0 and motif in p.stdout
 resultats.append({'mutant':mutant,'refus_attendu_observe':ok,'code':p.returncode})
 print(('OK ' if ok else 'NON ')+mutant,flush=True)
 if not ok:print(p.stdout[-2500:])
print(json.dumps({'production':False,'contre_epreuves':resultats}))
raise SystemExit(not all(x['refus_attendu_observe'] for x in resultats))
