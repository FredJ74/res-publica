// Mission Purge (24/11/2026) — issues #55/#60 (consommation Supabase) et #68 (session expirée sans F5).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const lire = f => fs.readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const sb = lire('supabase.js'), auth = lire('auth.js');

test('#55/#60 : le filet de 30 s ne lit ni n’écrit rien si rien n’a changé depuis la dernière écriture acceptée', () => {
  const i = sb.indexOf('async function sbVerifierEtSauvegarderPersonnage('), corps = sb.slice(i, sb.indexOf('\n}\n', i));
  const garde = corps.indexOf("if (empreinte && empreinte === charState._empreinteSauvegardee) return;");
  assert.ok(garde > 0 && garde < corps.indexOf("sbGet('personnages'"), 'la garde précède toute requête');
  assert.match(sb, /if \(resultat && !\(typeof resultat === 'object' && resultat\.ok === false\)\) charState\._empreinteSauvegardee = empreinte;/);
  // L'horodatage ne compte pas ; un changement réel compte.
  const j = sb.indexOf('function sbEmpreinteSauvegarde('), src = sb.slice(j, sb.indexOf('\n}\n', j) + 2);
  const f = vm.runInNewContext(src + ';sbEmpreinteSauvegarde');
  assert.equal(f({ name: 'A', pa: 3, updated_at: '1' }), f({ name: 'A', pa: 3, updated_at: '2' }));
  assert.notEqual(f({ name: 'A', pa: 3 }), f({ name: 'A', pa: 4 }));
  assert.notEqual(f({ name: 'A', inventory: [1] }), f({ name: 'A', inventory: [2] }));
});

test('#55/#60 : lectures de 60 et 90 s suspendues onglet masqué', () => {
  assert.match(lire('plateau-core.js'), /setInterval\(\(\) => lancerLectureFond\('dons', recupererDonsEnAttente\), 90000\);\n  setInterval\(\(\) => lancerLectureFond\('impacts', recupererImpactsEnAttente\), 90000\);/);
  const crim = lire('plateau-criminalite.js');
  assert.match(crim, /setInterval\(\(\) => \{ if \(visible\(\)\) lireEvenementsCrim\(\); \}, 60000\);/);
  assert.match(crim, /setInterval\(\(\) => \{ if \(visible\(\)\) rafraichirStatutDiscretion\(\); \}, 60000\);/);
  assert.match(lire('plateau-evenements-personnage.js'), /setInterval\(\(\) => \{ if \(!document\.hidden\) lireEvenementsPersonnage\(\); \}, 60000\);/);
});

test('#68 : refus 401 = jeton renouvelé et requête renvoyée une seule fois ; sinon fenêtre de reconnexion du jeu', () => {
  assert.match(auth, /async function rpAuthForcerRenouvellement\(\)/);
  assert.match(auth, /document\.addEventListener\('visibilitychange', rpAuthRaviver\);/);
  assert.match(sb, /if \(!opts\._renouvele && typeof rpAuthForcerRenouvellement === 'function'[\s\S]{0,120}return sbTransportRpcBrut\(fn, params, Object\.assign\(\{\}, opts, \{ _renouvele: true \}\)\);/);
  assert.match(sb, /if \(!dejaRenouvele && typeof rpAuthForcerRenouvellement === 'function'[\s\S]{0,120}return sbTransportRest\(methode, table, filtres, corps, preferResolution, true\);/);
  assert.match(sb, /function sbSignalerSessionPerdue\(\) \{[\s\S]{0,200}afficherBandeauReconnexion\(\)/);
});

test('#68 : renouvellement forcé fonctionnel (jeton refusé puis renouvelé, sans compte anonyme)', async () => {
  let appels = 0;
  const ctx = { console, Date, JSON, Object, localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    fetch: async (url) => { appels++; return { ok: true, status: 200, json: async () => ({ access_token: 'neuf', refresh_token: 'r2', expires_in: 3600, user: { id: 'u' } }) }; } };
  vm.createContext(ctx);
  vm.runInContext(auth.replace(/if \(typeof document !== 'undefined' && document\.addEventListener\)[\s\S]*$/, ''), ctx);
  vm.runInContext("RP_AUTH_SESSION = { access_token: 'vieux', refresh_token: 'r1', expire_le: Date.now() + 3600e3, user: { id: 'u' } };", ctx);
  assert.equal(vm.runInContext('rpAuthJeton()', ctx), 'vieux');
  assert.equal(await vm.runInContext('rpAuthForcerRenouvellement()', ctx), true);
  assert.equal(vm.runInContext('rpAuthJeton()', ctx), 'neuf');
  assert.equal(appels, 1, 'un seul appel : le renouvellement, jamais un compte anonyme');
});
