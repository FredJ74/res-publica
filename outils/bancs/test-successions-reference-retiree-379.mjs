// L'ancien miroir ne doit pas être recréé pour rendre un contrôle vert.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
test('succession : corps nocturne épinglé, ancien client absent et réintroductions détectées',()=>{
 const script=String.raw`
import importlib.util,json,tempfile,pathlib
s=importlib.util.spec_from_file_location('v','outils/baseline/verifier-fonctions.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
d=json.loads(pathlib.Path('outils/baseline/fonctions.json').read_text());r=next(x for x in d['copies']if x['cle']=='successions/etape-suivante')
assert r['canon_absent']is True
assert m.references_client_interdites(r['symbole_canon'])==[]
assert m.empreinte(m.fonctions_du_fichier(r['module'])[r['symbole_serveur']])==r['empreinte_serveur']
with tempfile.TemporaryDirectory()as td:
 p=pathlib.Path(td)/'fixture.js'
 for code in ['function determinerEtapeSuivante(){}','determinerEtapeSuivante();','window["determinerEtapeSuivante"]();','const copie=determinerEtapeSuivante;']:
  p.write_text(code);assert m.references_client_interdites(r['symbole_canon'],[p])==[str(p)]
 p.write_text('// determinerEtapeSuivante retirée\nconst x=1;');assert m.references_client_interdites(r['symbole_canon'],[p])==[]
print('serveur conservé ; 4 réintroductions détectées ; commentaire ignoré')
`;
 const r=execFileSync(process.env.PYTHON||'python3',['-c',script],{encoding:'utf8'});assert.match(r,/4 réintroductions détectées/);
});
