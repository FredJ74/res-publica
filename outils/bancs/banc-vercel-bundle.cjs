// npm ci --prefix outils/vercel ; node --test outils/bancs/banc-vercel-bundle.cjs
// Vrai constructeur @vercel/node epingle ; aucun acces Supabase, IA ou Vercel.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {createRequire} = require('node:module');
const outils = createRequire(path.join(__dirname, '../vercel/package.json'));
const {build} = outils('@vercel/node');
const constructeur = createRequire(outils.resolve('@vercel/node/package.json'));
const {FileFsRef, FileBlob} = constructeur('@vercel/build-utils');
const ROOT = path.resolve(__dirname, '../..');
const RUNNER = path.join(__dirname, 'fixtures/vercel-chat-runner.cjs');
const fichiersApi = fs.readdirSync(path.join(ROOT, 'api')).filter(f => f.endsWith('.js'));
async function compiler(entrypoint, ancien, verifier) {
  const temporaire = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-vercel-bundle-'));
  try {
    const source = path.join(temporaire, 'source'), entree = path.join(temporaire, 'entree'),
      sortie = path.join(temporaire, 'lambda');
    fs.mkdirSync(source, {recursive: true});
    const files = {};
    for (const f of fichiersApi.map(f => 'api/' + f).concat(['continuite-municipale.js', 'continuite-municipale.mjs'])) {
      let contenu = fs.readFileSync(path.join(ROOT, f));
      if (ancien && f === 'api/chat.js') contenu = Buffer.from(String(contenu).replace(
        "from '../continuite-municipale.js'", "from '../continuite-municipale.mjs'"));
      if (ancien && f === 'continuite-municipale.mjs') contenu = fs.readFileSync(path.join(ROOT, 'continuite-municipale.js'));
      const p = path.join(entree, f); fs.mkdirSync(path.dirname(p), {recursive: true}); fs.writeFileSync(p, contenu);
      files[f] = new FileFsRef({fsPath: p});
    }
    const resultat = await build({files, entrypoint, workPath: source,
      config: {zeroConfig: true, projectSettings: {nodeVersion: '22.x', installCommand: ''}},
      considerBuildCommand: true});
    for (const [f, blob] of Object.entries(resultat.output.files)) {
      const p = path.join(sortie, f); fs.mkdirSync(path.dirname(p), {recursive: true});
      fs.writeFileSync(p, (await FileBlob.fromStream({stream: await blob.toStream()})).data);
    }
    // Les Node recents peuvent accepter require(ESM) et masquer la regression.
    // Desactiver cette extension reproduit le runtime CommonJS rapporte en production.
    const charger = (mode = 'chargement') => spawnSync(process.execPath,
      ['--no-experimental-require-module', '--no-experimental-detect-module', RUNNER, path.join(sortie, entrypoint), mode],
      {encoding: 'utf8', timeout: 30000, env: {...process.env, DEEPSEEK_API_KEY: ''}});
    await verifier({sortie, charger, files: Object.keys(resultat.output.files)});
  } finally {fs.rmSync(temporaire, {recursive: true, force: true});}
}
test('contre-epreuve : ancien import mjs produit ERR_REQUIRE_ESM dans le vrai bundle Vercel', async () => {
  await compiler('api/chat.js', true, ({sortie, charger, files}) => {
    assert.ok(files.includes('continuite-municipale.mjs'));
    assert.match(fs.readFileSync(path.join(sortie, 'api/chat.js'), 'utf8'), /require\("\.\.\/continuite-municipale\.mjs"\)/);
    const r = charger(); assert.equal(r.status, 1); assert.match(r.stderr, /ERR_REQUIRE_ESM/);
  });
});
test('bundle corrige : chargement CommonJS et dix conversations, dont transitions municipales', async () => {
  await compiler('api/chat.js', false, ({sortie, charger, files}) => {
    assert.ok(files.includes('continuite-municipale.js'));
    assert.ok(!files.some(f => f.endsWith('.mjs')), 'Aucun ESM natif dans les dependances serveur');
    assert.match(fs.readFileSync(path.join(sortie, 'continuite-municipale.js'), 'utf8'), /exports\./);
    const r = charger('dialogues'); assert.equal(r.status, 0, r.stderr || r.stdout);
    const verdict = JSON.parse(r.stdout.trim().split('\n').at(-1));
    assert.equal(verdict.dialogues.length, 10); assert.equal(verdict.anonyme, 401); assert.equal(verdict.methode, 405);
  });
});
for (const f of fichiersApi.filter(f => !f.startsWith('_') && f !== 'chat.js')) {
  test(`autre fonction Vercel ${f} : graphe compile et chargement CommonJS`, async () => {
    await compiler('api/' + f, false, ({charger, files}) => {
      assert.ok(!files.some(f => f.endsWith('.mjs')), 'Pas de dependance ESM native echappant au compilateur');
      const r = charger(); assert.equal(r.status, 0, r.stderr || r.stdout);
    });
  });
}
