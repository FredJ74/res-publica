// Le contrôle doit vraiment exécuter JavaScript et propager ses refus.
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const resultat = spawnSync('python3', ['-c', String.raw`
import sys,tempfile,subprocess,json
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'outils'))
from moteur_javascript import choisir_moteur,commande_moteur
m=choisir_moteur([])
assert m is not None,'Aucun moteur réel'
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'controle.js'
 p.write_text('print(JSON.stringify({prix:Math.ceil(5*1.1),zero:0}));')
 r=subprocess.run(commande_moteur(m,str(p)),capture_output=True,text=True)
 assert r.returncode==0 and json.loads(r.stdout)=={'prix':6,'zero':0},r
 p.write_text('throw new Error("contre_epreuve_execution");')
 r=subprocess.run(commande_moteur(m,str(p)),capture_output=True,text=True)
 assert r.returncode!=0 and 'contre_epreuve_execution' in r.stderr,r
assert choisir_moteur(['/aucun/moteur']) is not None
print('OK moteur réel, calculs et exception non masquée')
`], {cwd:path.resolve(__dirname,'../..'), encoding:'utf8', timeout:15000});
assert.ifError(resultat.error);
assert.equal(resultat.status,0,resultat.stdout+resultat.stderr);
console.log(resultat.stdout.trim());
