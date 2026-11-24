// CI découpée (mission Purge, 24/11/2026) : les six parts de controler-client.py couvrent chaque banc exactement une fois,
// et la sélection « poussée » rejoue tout quand le lanceur change, un banc quand il change ou quand il cite un fichier modifié.
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const py = code => JSON.parse(execFileSync('python3', ['-c', `
import importlib.util, json
sp = importlib.util.spec_from_file_location('cc', 'outils/bancs/controler-client.py'); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
b = sorted(p for p in m.ICI.glob('banc-*') if p.suffix in ('.js', '.cjs', '.mjs'))
${code}`], { cwd: racine, encoding: 'utf8' }));

test('six parts : chaque banc joué exactement une fois, parts équilibrées', () => {
  const r = py(`parts=[[x.name for x in m.repartir(b,k,6)] for k in range(1,7)]
print(json.dumps({'n':len(b),'parts':parts,'poids':[sum(m.poids(x) for x in m.repartir(b,k,6)) for k in range(1,7)]}))`);
  const tous = r.parts.flat();
  assert.equal(tous.length, r.n);
  assert.equal(new Set(tous).size, r.n);
  assert.ok(Math.max(...r.poids) - Math.min(...r.poids) <= 30, JSON.stringify(r.poids));
});

test('poussée : lanceur modifié = tout ; banc modifié ou fichier cité = ce banc ; rien de lié = rien', () => {
  const r = py(`rel=lambda x:[y.name for y in x]
print(json.dumps({
 'tout': len(m.bancs_lies(b,['outils/bancs/controler-client.py'])),
 'ref_inutilisable': len(m.bancs_lies(b,None)),
 'n': len(b),
 'banc': rel(m.bancs_lies(b,['outils/bancs/banc-bloc2-journal-fleches-20261123.cjs'])),
 'cite': rel(m.bancs_lies(b,['plateau-rue-centrale.js'])),
 'doc': rel(m.bancs_lies(b,['RELAIS.md']))}))`);
  assert.equal(r.tout, r.n);
  assert.equal(r.ref_inutilisable, r.n);
  assert.ok(r.banc.includes('banc-bloc2-journal-fleches-20261123.cjs'));
  assert.ok(r.cite.includes('banc-bloc2-journal-fleches-20261123.cjs') && r.cite.length < r.n);
  assert.deepEqual(r.doc, []);
});
