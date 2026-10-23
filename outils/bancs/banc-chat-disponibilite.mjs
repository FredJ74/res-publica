// node --test outils/bancs/banc-chat-disponibilite.mjs
// Vrai handler et vrais profils ; authentification, Supabase et IA simules.
// Aucune requete distante, aucun joueur et aucun appel IA payant.
import test from 'node:test';
import assert from 'node:assert/strict';
import chat from '../../api/chat.js';
import {construirePromptSysteme, maxTokensProfil, profilExiste} from '../../api/_pnj-profils.js';
import {joueurAuthentifie} from '../../api/_deepseek.js';

const json = (v, status = 200) => new Response(JSON.stringify(v), {status});
async function scenario(options, verifier) {
  const original = {fetch: globalThis.fetch, error: console.error, key: process.env.DEEPSEEK_API_KEY,
    timeout: AbortSignal.timeout, timer: globalThis.setTimeout, now: Date.now};
  const appels = [], journaux = [], delais = [];
  let temps = 1000;
  process.env.DEEPSEEK_API_KEY = 'cle-fixture-confidentielle';
  if (options.sansCle) delete process.env.DEEPSEEK_API_KEY;
  console.error = (...args) => journaux.push(args);
  if (options.horloge) Date.now = () => temps;
  if (options.accelerer) AbortSignal.timeout = ms => {
    const c = new AbortController();
    original.timer(() => c.abort(new DOMException('delai fixture', 'TimeoutError')), 5);
    return c.signal;
  };
  globalThis.setTimeout = (fn, ms, ...args) => {
    delais.push(ms);
    return original.timer(fn, options.delaiIA ? 5 : ms, ...args);
  };
  const attendreAnnulation = signal => new Promise((resolve, reject) => {
    assert.ok(signal, 'Toute lecture du chat porte une borne');
    if (signal.aborted) return reject(signal.reason);
    signal.addEventListener('abort', () => reject(signal.reason), {once: true});
  });
  globalThis.fetch = async (url, init = {}) => {
    const u = new URL(url); appels.push({u, init});
    if (u.pathname === '/auth/v1/user') {
      assert.equal(init.headers.Authorization, 'Bearer jeton-fixture-confidentiel');
      assert.ok(init.signal);
      if (options.horloge) temps = 4000;
      if (options.authLente) return attendreAnnulation(init.signal);
      if (options.authReseau) throw Error('detail prive de reseau');
      return json({id: 'utilisateur-fixture-prive'}, options.authHttp || 200);
    }
    if (u.hostname === 'api.deepseek.com') {
      assert.equal(u.pathname, '/chat/completions');
      assert.equal(init.headers.Authorization, 'Bearer cle-fixture-confidentielle');
      if (options.delaiIA) return attendreAnnulation(init.signal);
      if (options.reseauIA) throw Error('detail fournisseur prive');
      if (options.httpIA) return json({error: 'detail fournisseur prive'}, options.httpIA);
      if (options.videIA) return json({choices: []});
      return json({choices: [{message: {content: 'Reponse IA fixture'}, finish_reason: 'stop'}]});
    }
    assert.ok(u.pathname.startsWith('/rest/v1/'), 'Aucun appel inconnu');
    assert.equal(init.headers.Authorization, 'Bearer jeton-fixture-confidentiel');
    assert.ok(init.signal);
    if (options.horloge) temps = 5000;
    if (options.contexteLent) return attendreAnnulation(init.signal);
    if (options.contexteHttp) return json({}, options.contexteHttp);
    if (!u.pathname.includes('/rpc/')) return json([]);
    return json({ok: false});
  };
  const req = {method: 'POST', headers: {authorization: 'Bearer jeton-fixture-confidentiel'},
    body: {profil: options.profil || 'sabri_coledur', lang: 'fr', message: 'message prive fixture',
      historique: [{role: 'assistant', content: 'souvenir prive fixture'}], ...options.body}};
  if (options.sansJeton) req.headers = {};
  const res = {setHeader() {}, status(code) {this.code = code; return this;},
    json(body) {this.body = body; return this;}};
  try {
    await chat(req, res);
    await verifier({req, res, appels, journaux, delais});
    const traces = JSON.stringify(journaux);
    for (const interdit of ['cle-fixture-confidentielle', 'jeton-fixture-confidentiel',
      'utilisateur-fixture-prive', 'message prive fixture', 'souvenir prive fixture',
      'detail fournisseur prive', 'detail prive de reseau']) assert.ok(!traces.includes(interdit), interdit);
  } finally {
    globalThis.fetch = original.fetch; console.error = original.error;
    AbortSignal.timeout = original.timeout; globalThis.setTimeout = original.timer; Date.now = original.now;
    if (original.key === undefined) delete process.env.DEEPSEEK_API_KEY;
    else process.env.DEEPSEEK_API_KEY = original.key;
  }
}
for (const profil of ["sabri_coledur","ced_labone","henrico_stot","gerard_poincon","jeremy","les_gars_du_bas","la_bande_a_rotule","los_relajados","los_violentos","famille_kolkhozov","miliciens_zeles","famille_al_bedouin","clan_al_resistant"]) {
  test(`conversation ${profil} : vrai prompt et historique, sans alteration`, async () => {
    await scenario({profil}, ({req, res, appels}) => {
      assert.equal(res.code, 200); assert.equal(res.body.reponse, 'Reponse IA fixture');
      const ia = appels.filter(a => a.u.hostname === 'api.deepseek.com'); assert.equal(ia.length, 1);
      const corps = JSON.parse(ia[0].init.body);
      assert.equal(corps.messages[0].content, construirePromptSysteme(profil, 'fr', null, null, null, null, null, null, null));
      assert.deepEqual(corps.messages.slice(1), [...req.body.historique, {role: 'user', content: req.body.message}]);
      assert.equal(corps.max_tokens, maxTokensProfil(profil)); assert.equal(corps.model, 'deepseek-chat');
      assert.ok(appels.filter(a => a.u.pathname.startsWith('/rest/v1/')).every(a => a.u.pathname.includes('/rpc/')),
        'Les lectures municipales ne concernent pas ces profils');
    });
  });
}
for (const [options, cause] of [
  [{sansCle: true}, 'cle_absente'], [{httpIA: 401}, 'authentification'],
  [{httpIA: 402}, 'credits_epuises'], [{httpIA: 429}, 'debit_limite'],
  [{httpIA: 503}, 'panne_fournisseur'], [{httpIA: 400}, 'requete_invalide'],
  [{videIA: true}, 'reponse_vide'], [{reseauIA: true}, 'reseau'],
  [{delaiIA: true}, 'delai_depasse']
]) test(`fournisseur : ${cause}, diagnostic prive et erreur publique neutre`, async () => {
  await scenario(options, ({res, journaux}) => {
    assert.equal(res.code, 502);
    assert.deepEqual(res.body, {error: 'Le PNJ est momentanément indisponible.'});
    assert.ok(journaux.some(j => j[0] === '[chat]' && j[1].etape === 'fournisseur' && j[1].cause === cause));
  });
});
for (const [options, cause] of [[{sansJeton: true}, 'jeton_absent'], [{authHttp: 401}, 'http'],
  [{authHttp: 503}, 'http'], [{authReseau: true}, 'reseau_ou_format'],
  [{authLente: true, accelerer: true}, 'delai_depasse']]) {
  test(`authentification : ${JSON.stringify(options)}, aucun appel payant`, async () => {
    await scenario(options, ({res, appels, journaux}) => {
      assert.equal(res.code, 401);
      assert.ok(appels.every(a => a.u.pathname === '/auth/v1/user'));
      assert.ok(journaux.some(j => j[1]?.etape === 'authentification' && j[1].cause === cause));
    });
  });
}
test('profil invalide refuse avant authentification et IA', async () => {
  await scenario({body: {profil: 'inconnu'}}, ({res, appels}) => {
    assert.equal(res.code, 400); assert.equal(appels.length, 0);
  });
});
test('budget IA calcule apres authentification et lectures, marge avant Vercel', async () => {
  await scenario({horloge: true}, ({res, delais}) => {
    assert.equal(res.code, 200); assert.deepEqual(delais, [23000]);
    assert.ok(delais[0] + 4000 < 30000);
  });
});
for (const options of [{contexteLent: true, accelerer: true}, {contexteHttp: 503},
  {profil: 'le_maire_de_luthecia', contexteLent: true, accelerer: true}]) {
  test(`contexte facultatif indisponible : ${JSON.stringify(options)}`, async () => {
    await scenario(options, ({res, appels, journaux}) => {
      assert.equal(res.code, 200); assert.ok(journaux.length);
      assert.ok(appels.some(a => a.u.hostname === 'api.deepseek.com'));
      if (options.profil) {
        const prompt = JSON.parse(appels.find(a => a.u.hostname === 'api.deepseek.com').init.body).messages[0].content;
        assert.ok(prompt.includes('fonction non vérifiée'));
      }
    });
  });
}
test('autres API : appel sans options conserve le contrat auth historique', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    assert.equal(init.signal, undefined); return json({id: 'fixture'});
  };
  try {assert.deepEqual(await joueurAuthentifie({headers: {authorization: 'Bearer fixture'}}), {id: 'fixture', jeton: 'fixture'});}
  finally {globalThis.fetch = original;}
});

test('aucun cadavre ne dispose de profil de conversation',()=>{for(const id of ['cadavre','individu_non_identifie','deux_inconnus','camarade_inconnu','inconnu'])assert.equal(profilExiste(id),false);});
