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
  ['SELECT pur accepté sans transaction', 'outils/bancs/banc-test.sql', 'SELECT count(*) FROM pg_class;', null],
  ['CTE de suppression refusée', 'outils/bancs/banc-test.sql', 'WITH x AS (DELETE FROM t RETURNING *) SELECT * FROM x;', /sans bloc DO ni enveloppe/],
  ['SELECT INTO refusé', 'outils/bancs/banc-test.sql', 'SELECT * INTO nouveau FROM ancien;', /sans bloc DO ni enveloppe/],
  ['fonction mutante ou inconnue refusée', 'outils/bancs/banc-test.sql', 'SELECT public.payer_ordre(1);', /sans bloc DO ni enveloppe/],
  ['configuration transactionnelle refusée', 'outils/bancs/banc-test.sql', "SELECT set_config('transaction_read_only','off',true);", /sans bloc DO ni enveloppe/],
  ['fonction publique homonyme refusée', 'outils/bancs/banc-test.sql', 'SELECT public.count(1);', /sans bloc DO ni enveloppe/],
  ['SELECT verrouillant refusé', 'outils/bancs/banc-test.sql', 'SELECT * FROM t FOR UPDATE;', /sans bloc DO ni enveloppe/],
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

test('la capture du registre distingue âge du fichier, version et nom réellement appliqués', () => {
 const script=String.raw`
import runpy,hashlib,copy
m=runpy.run_path('outils/baseline/verifier-workflow.py',run_name='importe')
vs=['20261101000000','20261102000000'];reg={'versions':vs,'lignes':2,'derniere':vs[-1],'sha256_versions':hashlib.sha256('\n'.join(vs).encode()).hexdigest(),'noms_sha256':[hashlib.sha256(b'deja_fait').hexdigest()]};ctl={'entrees':2,'derniere_version':vs[-1]}
m['verifier_registre_observe'](reg,ctl)
f=m['migration_presente_au_registre']
assert f('20261101000000_autre_nom.sql',reg)
assert f('20261001000000_deja_fait.sql',reg)
assert not f('20260901000000_encore_a_livrer.sql',reg)
for key,value in [('lignes',3),('sha256_versions','0'*64),('derniere','20260101000000'),('noms_sha256',[])]:
 d=copy.deepcopy(reg);d[key]=value
 try:m['verifier_registre_observe'](d,ctl);raise AssertionError('capture falsifiée acceptée')
 except ValueError:pass
`;
 const r=spawnSync('python3',['-c',script],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr||r.stdout);
});
