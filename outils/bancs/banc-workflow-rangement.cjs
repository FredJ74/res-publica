// Le rangement est corrigé ; le garde-fou doit continuer à refuser le SQL égaré.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const verifier = path.join(root, 'outils/baseline/verifier-workflow.py');
const inspection = `import runpy,sys,io,contextlib,json
m=runpy.run_path(sys.argv[1]);f=m['main'];g=f.__globals__;base=m['Rapport'];captures=[]
class Rapport(base):
 def __init__(self):
  super().__init__();captures.append(self)
g['Rapport']=Rapport;g['RACINE']=sys.argv[2]
with contextlib.redirect_stdout(io.StringIO()): f()
print(json.dumps(captures[0].pbs['5. SQL DANS SES TROIS MAISONS']))`;

test('le dépôt satisfait toujours le vérificateur Workflow original', () => {
  const r = spawnSync('python3', [verifier], {encoding:'utf8', timeout:30000});
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /CONFORME : le processus tient/);
});

for (const [nom, fichier, sql, attendu] of [
  ['fixture SQL nue dans un sous-dossier refusée', 'outils/bancs/fixtures/egare.sql', 'CREATE TABLE egare(id int);', /fichier .sql egare/],
  ['sous-dossier refusé même avec rollback', 'outils/bancs/fixtures/egare.sql', 'BEGIN;\nCREATE TABLE egare(id int);\nROLLBACK;', /fichier .sql egare/],
  ['banc sans annulation refusé', 'outils/bancs/banc-test.sql', 'CREATE TABLE egare(id int);', /sans bloc DO ni enveloppe/],
  ['banc transactionnel direct accepté', 'outils/bancs/banc-test.sql', 'BEGIN;\nCREATE TABLE jetable(id int);\nROLLBACK;', null],
  ['source documentaire dans historique acceptée', 'historique/fixtures-bancs/source.sql', 'CREATE TABLE historique(id int);', null],
]) {
  test(nom, t => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-workflow-'));
    t.after(() => fs.rmSync(tmp, {recursive:true, force:true}));
    const cible = path.join(tmp, fichier);
    fs.mkdirSync(path.dirname(cible), {recursive:true});
    fs.writeFileSync(cible, sql);
    const r = spawnSync('python3', ['-c', inspection, verifier, tmp], {encoding:'utf8', timeout:10000});
    assert.equal(r.status, 0, r.stdout + r.stderr);
    const erreurs = JSON.parse(r.stdout);
    if (attendu) assert.ok(erreurs.some(e => attendu.test(e)), r.stdout);
    else assert.deepEqual(erreurs, []);
  });
}
