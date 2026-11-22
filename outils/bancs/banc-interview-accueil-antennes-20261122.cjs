'use strict';
// Interview d'accueil des nouveaux personnages (Fred, 21/11/2026, GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md).
// Serveur /api/jodie-portrait rejoué avec une base simulée (aucune connexion externe) :
//  - l'invitation vient du journaliste de l'antenne de la ville du personnage ; Jodie Moitout jamais hors de Luthécia ;
//    une ville sans journaliste nommé n'envoie rien ;
//  - les réponses à une invitation s'envoient et le portrait se publie le premier jour ;
//  - l'état (invité, refusé, publié) est donné AVANT d'ouvrir le formulaire ; refus écrit et archivé par le serveur ;
//  - la date de création sans fuseau est lue en UTC (cause de l'invitation de Tom Tom refusée ensuite) ;
//  - la sollicitation « Jodie Moitout aimerait vous interviewer » (journal) : Luthécia seulement ;
//  - la liste des antennes est la même dans le navigateur et sur le serveur ; le navigateur n'écrit jamais au nom
//    d'un journaliste.
// Usage : node outils/bancs/banc-interview-accueil-antennes-20261122.cjs
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const { createHash, createHmac, timingSafeEqual } = require('node:crypto');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
let acorn;
try { acorn = require('../e2e/node_modules/acorn'); } catch (_) { acorn = require('../vercel/node_modules/acorn'); }

const ANTENNES_SRC = lire('api/_presse-antennes.js').replace(/^export /gm, '');
const API_SRC = lire('api/jodie-portrait.js').replace(/^import .*;\s*$/gm, '').replace('export default async function handler', 'async function handler');
const HEURE = 3600000, JOUR = 86400000;
// « timestamp without time zone » tel que PostgREST le rend (UTC, sans « Z »).
const sansFuseau = ms => new Date(ms).toISOString().replace('T', ' ').replace('Z', '');

function valeurs(filtre) {
  const v = decodeURIComponent(filtre);
  if (v.startsWith('eq.')) return [v.slice(3)];
  if (v.startsWith('in.(')) return v.slice(4, -1).split(',').map(x => x.replace(/^"|"$/g, ''));
  return null;
}
function filtrer(rows, params) {
  return rows.filter(r => [...params].every(([k, f]) => {
    if (['select', 'limit', 'order'].includes(k)) return true;
    const vs = valeurs(f); return !vs || vs.includes(String(r[k]));
  }));
}
function serveur({ fiche = {}, mails = [], topics = [], posts = [], proprio = true } = {}) {
  const base = { mails: mails.map((m, i) => ({ id: 'm' + i, to_player: 'Tom Tom', ...m })), forum_topics: [...topics], forum_posts: [...posts] };
  const rpc = [], patchs = [];
  const fetch = async (url, opts = {}) => {
    const u = new URL(url), table = u.pathname.split('/').pop(), mode = opts.method || 'GET';
    if (u.pathname.includes('/rpc/')) {
      const p = JSON.parse(opts.body); rpc.push(p);
      const id = 'mail-srv-' + rpc.length;
      base.mails.push({ id, from_player: p.p_expediteur, to_player: p.p_destinataire, subject: p.p_sujet, body: p.p_corps, time: p.p_heure });
      return { ok: true, json: async () => ({ ok: true, id }) };
    }
    if (mode === 'GET') {
      let rows;
      if (table === 'personnages_donnees') rows = proprio ? [{ name: 'Tom Tom' }] : [];
      else if (table === 'personnages') rows = [{ created_at: sansFuseau(Date.now() - 2 * JOUR), country: 'republic', current_city: 'capitale', ...fiche }];
      else rows = filtrer(base[table] || [], u.searchParams);
      return { ok: true, json: async () => rows };
    }
    if (mode === 'PATCH') { patchs.push({ table, filtre: u.search, data: JSON.parse(opts.body) }); return { ok: true, json: async () => [] }; }
    if (mode === 'POST') { const d = JSON.parse(opts.body); base[table].push(d); return { ok: true, json: async () => [d] }; }
    throw new Error('transport inattendu');
  };
  const c = vm.createContext({ Buffer, Date, URL, createHash, createHmac, timingSafeEqual, AbortSignal, encodeURIComponent, fetch,
    process: { env: { SUPABASE_SERVICE_ROLE_KEY: 'secret-de-banc' } }, console: { error() {} },
    joueurAuthentifie: async () => ({ id: 'uid-tom' }),
    appelDeepSeek: async ({ messages }) => ({ ok: true, texte: 'Portrait rédigé. ' + messages[0].content.split('.')[0] }) });
  vm.runInContext(ANTENNES_SRC + '\n' + API_SRC + '\nthis.handler = handler;', c, { filename: 'api/jodie-portrait.js' });
  const appel = async corps => {
    let status = 200, json;
    await c.handler({ method: 'POST', body: { personnage: 'Tom Tom', ...corps } }, { status(s) { status = s; return this; }, json(j) { json = j; return this; } });
    return { status, ...json };
  };
  return { appel, base, rpc, patchs };
}
const REP = ['Un', 'Deux', 'Trois', 'Quatre', 'Cinq'];
const VILLES = [['republic', 'capitale', 'Jodie Moitout', "L'Autruche Entravée"], ['republic', 'ville_a', 'Annie Houininon', 'La Tribune de Républia'],
  ['republic', 'ville_b', 'Arthur Lutte', 'La Tribune de Républia'], ['soviet', 'capitale', 'Zoïa Glazounova', 'La Voix de Sovarka'],
  ['soviet', 'ville_a', 'Saran Batbayar', 'Metel'], ['soviet', 'ville_b', 'Anatoli Kolosov', 'La Voix de Sovarka']];

test('invitation par le journaliste de la ville du personnage, dans les six villes jouables ; Jodie seulement à Luthécia', async () => {
  for (const [pays, ville, journaliste, journal] of VILLES) {
    const s = serveur({ fiche: { country: pays, current_city: ville } });
    const r = await s.appel({ action: 'inviter', heure: '22/11 10h' });
    assert.equal(r.envoye, true, pays + '/' + ville);
    assert.equal(s.rpc.length, 1);
    assert.equal(s.rpc[0].p_expediteur, journaliste);
    assert.equal(s.rpc[0].p_sujet, 'Un portrait pour ' + journal + ' ?');
    assert.equal(s.rpc[0].p_heure, '22/11 10h');
    assert.equal(s.rpc[0].p_expediteur === 'Jodie Moitout', pays === 'republic' && ville === 'capitale', 'Jodie hors de Luthécia');
    // Jamais deux fois.
    assert.equal((await s.appel({ action: 'inviter' })).raison, 'deja');
    assert.equal(s.rpc.length, 1);
  }
  // Sujet de Jodie inchangé mot pour mot : les invitations déjà en base restent reconnues.
  assert.equal('Un portrait pour ' + VILLES[0][3] + ' ?', "Un portrait pour L'Autruche Entravée ?");
});

test('aucune invitation sans journaliste nommé (El Estado, Khalija, caserne) ni avant un jour d’ancienneté (heure UTC exacte)', async () => {
  for (const [pays, ville] of [['narco', 'capitale'], ['khalija', 'ville_a'], ['republic', 'caserne']]) {
    const s = serveur({ fiche: { country: pays, current_city: ville } });
    assert.equal((await s.appel({ action: 'inviter' })).raison, 'aucun_journaliste', pays + '/' + ville);
    assert.equal(s.rpc.length, 0);
  }
  // Tom Tom : créé 23 h avant, date sans fuseau. Avant le correctif, le navigateur (heure de Paris) le croyait
  // âgé de 24 h et écrivait l'invitation, que le serveur (UTC) refusait ensuite.
  let s = serveur({ fiche: { country: 'soviet', current_city: 'ville_b', created_at: sansFuseau(Date.now() - 23 * HEURE) } });
  assert.equal((await s.appel({ action: 'inviter' })).raison, 'trop_tot');
  s = serveur({ fiche: { country: 'soviet', current_city: 'ville_b', created_at: sansFuseau(Date.now() - 25 * HEURE) } });
  assert.equal((await s.appel({ action: 'inviter' })).envoye, true);
});

test('premier jour : réponses envoyées et portrait publié, signé du journaliste qui a invité, dans son pays', async () => {
  const s = serveur({ fiche: { country: 'soviet', current_city: 'ville_b', created_at: sansFuseau(Date.now() - HEURE) },
    mails: [{ from_player: 'Anatoli Kolosov', subject: 'Un portrait pour La Voix de Sovarka ?' }] });
  const e = await s.appel({ action: 'etat' });
  assert.deepEqual([e.peutRepondre, e.journaliste, e.journal], [true, 'Anatoli Kolosov', 'La Voix de Sovarka']);
  const a = await s.appel({ action: 'apercu', reponses: REP });
  assert.equal(a.status, 200, a.error);
  assert.match(a.texte, /Tu es Anatoli Kolosov, journaliste du journal La Voix de Sovarka/);
  const p = await s.appel({ action: 'publier', jeton: a.jeton });
  assert.equal(p.status, 200, p.error);
  const t = s.base.forum_topics[0];
  assert.deepEqual([t.title, t.author, t.country], ['Un jour, un portrait : Tom Tom', 'Anatoli Kolosov', 'soviet']);
  assert.equal(s.base.forum_posts[0].author, 'Anatoli Kolosov');
  // Publié : l'état le dit avant toute réouverture du formulaire.
  assert.deepEqual([(await s.appel({ action: 'etat' })).peutRepondre, (await s.appel({ action: 'etat' })).raison], [false, 'deja_publie']);
  assert.equal(lire('api/jodie-portrait.js').includes('Portrait disponible après le premier jour'), false, 'verrou retiré');
});

test('une invitation reçue reste valable après un déménagement (l’antenne qui a invité fait foi)', async () => {
  const s = serveur({ fiche: { country: 'soviet', current_city: 'ville_b' }, mails: [{ from_player: 'Jodie Moitout', subject: "Un portrait pour L'Autruche Entravée ?" }] });
  const a = await s.appel({ action: 'apercu', reponses: REP });
  assert.match(a.texte, /Tu es Jodie Moitout/);
  await s.appel({ action: 'publier', jeton: a.jeton });
  assert.deepEqual([s.base.forum_topics[0].author, s.base.forum_topics[0].country], ['Jodie Moitout', 'republic']);
});

test('état avant ouverture : pas invité, refusé ; refus écrit par le serveur puis archivé ; invitation falsifiée ignorée', async () => {
  let s = serveur();
  let e = await s.appel({ action: 'etat' });
  assert.deepEqual([e.peutRepondre, e.raison], [false, 'pas_invite']);
  assert.equal((await s.appel({ action: 'apercu', reponses: REP })).status, 403);
  // Un courrier « Un portrait pour L'Autruche Entravée ? » signé d'un autre nom n'est pas une invitation.
  s = serveur({ mails: [{ from_player: 'Tom Tom', subject: "Un portrait pour L'Autruche Entravée ?" }] });
  assert.equal((await s.appel({ action: 'etat' })).peutRepondre, false);
  s = serveur({ mails: [{ from_player: 'Annie Houininon', subject: 'Un portrait pour La Tribune de Républia ?' }] });
  const r = await s.appel({ action: 'refuser', heure: '22/11 11h' });
  assert.equal(r.ok, true);
  assert.deepEqual([s.rpc[0].p_expediteur, s.rpc[0].p_sujet], ['Annie Houininon', 'Un portrait pour La Tribune de Républia ? (classé)']);
  assert.deepEqual(s.patchs[0].data, { archived: true });
  e = await s.appel({ action: 'etat' });
  assert.deepEqual([e.peutRepondre, e.raison], [false, 'refuse']);
  assert.equal((await s.appel({ action: 'apercu', reponses: REP })).status, 403);
  assert.equal((await s.appel({ action: 'inviter' })).raison, 'deja', 'aucune relance après un refus');
});

test('navigateur : même liste d’antennes que le serveur ; jamais de courrier écrit au nom d’un journaliste', () => {
  const src = lire('plateau-communication.js');
  const n = acorn.parse(src, { ecmaVersion: 'latest' }).body.find(x => x.type === 'VariableDeclaration' && x.declarations[0].id.name === 'PRESSE_ANTENNES_ACCUEIL');
  const client = vm.runInNewContext(src.slice(n.start, n.end) + ';PRESSE_ANTENNES_ACCUEIL');
  const srv = vm.runInNewContext(ANTENNES_SRC + ';ANTENNES_PRESSE');
  assert.deepEqual(JSON.parse(JSON.stringify(client)), JSON.parse(JSON.stringify(srv)));
  const noms = srv.map(a => a.journaliste);
  for (const f of fs.readdirSync(root).filter(f => /\.js$/.test(f))) {
    const s = lire(f);
    for (const nom of noms) {
      assert.equal(new RegExp("sbSendMail\\(\\s*['\"]" + nom).test(s), false, f + ' écrit au nom de ' + nom);
      assert.equal(new RegExp("p_expediteur:\\s*['\"]" + nom).test(s), false, f + ' (RPC) au nom de ' + nom);
    }
  }
});

test('journal : la sollicitation de Jodie ne part que vers un personnage de Luthécia', async () => {
  const src = lire('api/_journal-generation.js');
  const ast = acorn.parse(src, { ecmaVersion: 'latest', sourceType: 'module' });
  const f = ast.body.find(x => x.type === 'FunctionDeclaration' && x.id.name === 'solliciterInterviewsProactives');
  const consts = ast.body.filter(x => x.type === 'VariableDeclaration' && /JODIE_(COOLDOWN|RELANCE|SUJET)/.test(src.slice(x.start, x.end)));
  for (const [pays, ville, attendu] of [['republic', 'capitale', 1], ['republic', 'ville_a', 0], ['soviet', 'capitale', 0]]) {
    const envois = [];
    const c = vm.createContext({ SUPABASE_SERVICE_ROLE: 'x', SB_HEADERS_SERVICE: {}, encodeURIComponent, Date,
      sbGet: async t => t === 'personnages' ? [{ country: pays, current_city: ville }] : [],
      sbRpc: async (n, p) => { envois.push(p); return { ok: true }; }, dateEditionPourPays: () => 'h', console });
    vm.runInContext(consts.map(x => src.slice(x.start, x.end)).join('\n') + '\n' + src.slice(f.start, f.end) + '\nthis.s = solliciterInterviewsProactives;', c);
    await c.s('republic', { articles: [{ interview_suggeree: true, source_ids: ['f'] }] }, { f: { estPJ: true, acteur: 'Peter' } }, new Date());
    assert.equal(envois.length, attendu, pays + '/' + ville);
  }
});
