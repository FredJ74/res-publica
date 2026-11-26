// Décisions du 26/11/2026, bloc D (décision n° 10 de Fred) : traduction des textes de joueurs — le forum d'abord, puis les
// rumeurs de la chronique. Route /api/traduction (greffée sur /api/chat?mode=traduction), service côté écran, texte simple
// tiré du HTML du forum, migration du cache et du quota (20261126300000).
// Lancer : node --test outils/bancs/test-traduction-joueurs-20261126.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
import { handlerTraduction } from '../../api/_traduction-http.js';
import { texteDepuisHtml, lireOriginalSousRls } from '../../api/_traduction-lecture-rls.js';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = f => readFileSync(path.join(racine, f), 'utf8');

function reponse() {
  const r = { statusCode: 0, entetes: {}, corps: '' };
  r.setHeader = (k, v) => { r.entetes[k.toLowerCase()] = v; };
  r.end = c => { r.corps = c; };
  return r;
}

test('route : POST seulement, le texte n’est jamais lu dans la requête, la traduction seule est rendue', async () => {
  let recu = null;
  const traduire = async (demande, deps) => { recu = { demande, deps }; return { ok: true, original: 'secret', traduit: 'Hello', fromCache: false }; };
  const res = reponse();
  await handlerTraduction({ method: 'POST', headers: { origin: 'https://human-gambit.com' },
    body: { type: 'forum_post', id: '42', field: 'content', langue: 'en', texte: 'NE PAS LIRE' } }, res,
    { traduire, dependances: () => ({}) });
  assert.equal(res.statusCode, 200);
  assert.deepEqual(JSON.parse(res.corps), { ok: true, traduit: 'Hello', depuisCache: false });
  assert.deepEqual(recu.demande, { type: 'forum_post', id: '42', field: 'content', langueCible: 'en' }, 'aucun texte transmis au moteur');
  assert.equal(res.entetes['access-control-allow-origin'], 'https://human-gambit.com');
  const get = reponse();
  await handlerTraduction({ method: 'GET', headers: {} }, get, { traduire, dependances: () => ({}) });
  assert.equal(get.statusCode, 405);
  const refus = reponse();
  await handlerTraduction({ method: 'POST', headers: {}, body: { type: 'forum_post', id: '1', field: 'content', langue: 'en' } }, refus,
    { traduire: async () => ({ ok: false, raison: 'quota_atteint' }), dependances: () => ({}) });
  assert.deepEqual(JSON.parse(refus.corps), { ok: false, raison: 'quota_atteint' });
  const sansDeps = reponse();
  await handlerTraduction({ method: 'POST', headers: {}, body: {} }, sansDeps, { traduire, dependances: () => null });
  assert.equal(sansDeps.statusCode, 503);
});

test('forum : seul le texte lisible du HTML est traduit (balises retirées, entités décodées, scripts ignorés)', async () => {
  assert.equal(texteDepuisHtml('<p>Bonjour <b>Ivan</b> &amp; Olga</p><p>2e&nbsp;ligne</p><script>alert(1)</script>'), 'Bonjour Ivan & Olga\n2e ligne');
  const lu = await lireOriginalSousRls({ type: 'forum_post', id: '7', field: 'content' }, 'jeton',
    async () => ({ ok: true, donnees: [{ id: 7, content: '<p>Salut <i>camarade</i></p>' }] }));
  assert.deepEqual({ ...lu }, { text: 'Salut camarade', language: 'und' });
  const titre = await lireOriginalSousRls({ type: 'forum_topic', id: '8', field: 'title' }, 'jeton',
    async () => ({ ok: true, donnees: [{ id: 8, title: 'Un <titre>' }] }));
  assert.equal(titre.text, 'Un <titre>', 'les autres sources restent telles quelles');
});

test('raccordements : route Vercel, fonction partagée, écran du forum et de la chronique, migration activée', () => {
  const v = JSON.parse(lire('vercel.json'));
  assert.ok(v.rewrites.some(r => r.source === '/api/traduction' && r.destination === '/api/chat?mode=traduction'));
  assert.match(lire('api/chat.js'), /req\.query\.mode === 'traduction'\) return handlerTraduction\(req, res\)/);
  const html = lire('plateau.html');
  assert.ok(html.indexOf('i18n/texte-joueur.js') < html.indexOf('i18n/traduction-texte-joueur.js'));
  const f = lire('forum.js');
  assert.match(f, /data-traduire-post=/); assert.match(f, /type: 'forum_post', id: String\(id\), field: 'content'/);
  assert.match(f, /\.slice\(0, 20\)/, 'au plus 20 traductions automatiques par sujet');
  assert.match(f, /textContent = r\.traduit/, 'traduction en texte simple, jamais en HTML');
  assert.match(lire('plateau-chronique-empire.js'), /RPTraductionTexteJoueur/);
  const m = lire('migrations/20261126300000_traduction_textes_joueurs.sql');
  assert.match(m, /VALUES \(1,true,200,120000\)/);
  assert.match(m, /REVOKE ALL ON public\.rp_i18n_configuration,public\.rp_i18n_cache,\s*public\.rp_i18n_usage,public\.rp_i18n_reservations FROM PUBLIC,anon,authenticated;/);
});

test('service côté écran : seule la source part, mémoire de session, demandes identiques regroupées', async () => {
  const appels = [];
  const ctx = { window: null, rpAuthJeton: () => 'jwt', fetch: async (url, o) => { appels.push({ url, corps: JSON.parse(o.body), auth: o.headers.Authorization });
    return { json: async () => ({ ok: true, traduit: 'Hello' }) }; } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/traduction-texte-joueur.js'), ctx);
  const s = ctx.RPTraductionTexteJoueur;
  const [a, b] = await Promise.all([s.traduire({ type: 'forum_post', id: 5, field: 'content', langueCible: 'en' }),
                                    s.traduire({ type: 'forum_post', id: 5, field: 'content', langueCible: 'en' })]);
  assert.equal(a.traduit, 'Hello'); assert.equal(b.traduit, 'Hello');
  await s.traduire({ type: 'forum_post', id: 5, field: 'content', langueCible: 'en' });
  assert.equal(appels.length, 1, 'un seul appel réseau');
  assert.deepEqual(appels[0], { url: '/api/traduction', corps: { type: 'forum_post', id: '5', field: 'content', langue: 'en' }, auth: 'Bearer jwt' });
});
