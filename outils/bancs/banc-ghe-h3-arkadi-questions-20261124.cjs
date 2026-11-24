'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.3 : au musée de Krasnov, Arkadi Pamiatnikov répond aux questions libres,
// 1 PA pour 3 questions, par salle et par jour, comme à Novomirsk.
//   • serveur (PGlite) : guide_musee_salle_interne reconnaît les six pièces du musée de Krasnov sous « krasnov: »,
//     sans rien changer aux deux musées de Novomirsk ;
//   • /api/chat : chaque guide n'est servi que dans SON musée (table GUIDES_MUSEE_PREFIXE) ;
//   • écran : la fenêtre « Écouter le guide » d'Arkadi propose les questions, n'affiche que ce que le serveur renvoie,
//     et garde l'énigme de la feuille volante.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIGRATION = 'migrations/20261124142000_ghe_h3_arkadi_questions_musee_krasnov.sql';

test('H.3 — /api/chat : Arkadi servi au musée de Krasnov seulement, mêmes règles pour Ouliana et Ilia', () => {
  const src = lire('api/chat.js');
  const i = src.indexOf('const GUIDES_MUSEE_PREFIXE'), j = src.indexOf('\n\n', i);
  const ctx = {}; vm.createContext(ctx);
  vm.runInContext("const PROFIL_GUIDE_MUSEE = 'ouliana_historiskaia';" + src.slice(i, j) + ';this.G = GUIDES_MUSEE_PREFIXE; this.m = museeDeLaSalle;', ctx);
  assert.equal(ctx.G.arkadi_pamiatnikov, 'krasnov:');
  assert.equal(ctx.G.veteran_ilia_krioukov, 'novomirsk:');
  assert.equal(ctx.G.ouliana_historiskaia, '');
  assert.equal(ctx.m('krasnov:faune_sauvage'), 'krasnov:');
  assert.equal(ctx.m('novomirsk:salle_origines'), 'novomirsk:');
  assert.equal(ctx.m('salle_presidents'), '');
  assert.match(src, /museeDeLaSalle\(etat\.salle\) !== GUIDES_MUSEE_PREFIXE\[req\.body\.profil\]/);
  assert.match(src, /guide_musee_question_consommer/);
});

test('H.3 — fenêtre d’Arkadi : questions (1 PA, 3 par salle), réponses du serveur, énigme conservée', async () => {
  const appels = [];
  const ctx = { console, state: { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'musee-novomirsk', currentRoom: 'faune_sauvage', inventory: [] },
    document: { getElementById: id => id === 'arkadi-question' ? { value: 'Qui a abattu l’ours ?', nextElementSibling: null } : null, body: { contains: () => true } } };
  ctx.window = ctx;
  let html = '';
  ctx.sovModal = (t, h) => { html = h; };
  ctx.showToast = (...a) => appels.push(['toast', ...a]);
  ctx.appliquerPaiementServeur = p => appels.push(['paiement', p.pa]);
  ctx.rpAuthJeton = () => 'jeton';
  let ouvert = false;
  ctx.sbRpcVerdict = async (fn) => {
    appels.push([fn]);
    if (fn === 'guide_musee_dialogue_lire') return { ok: true, salle: 'krasnov:faune_sauvage', ouvert, restantes: ouvert ? 3 : 0 };
    if (fn === 'guide_musee_dialogue_ouvrir') { ouvert = true; return { ok: true, salle: 'krasnov:faune_sauvage', restantes: 3, pa: 9 }; }
    return null;
  };
  ctx.fetch = async (url, o) => { appels.push(['fetch', JSON.parse(o.body).profil]); return { ok: true, json: async () => ({ reponse: 'Un garde forestier, en 1931.', restantes: 2 }) }; };
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-guide-arkadi.js'), ctx);
  await ctx.arkadiEcouterGuide();
  assert.match(html, /Pour 1 PA, Arkadi répond à trois questions dans cette salle, aujourd’hui\./);
  assert.match(html, /Poser des questions \(1 PA\)/);
  assert.match(html, /data-arkadi-enigme/, 'énigme conservée');
  await ctx.arkadiOuvrirQuestions();
  assert.deepEqual(appels.find(a => a[0] === 'paiement'), ['paiement', 9], 'PA renvoyés par le serveur');
  assert.match(html, /id="arkadi-question"/);
  assert.match(html, /Demander \(3 restantes\)/);
  await ctx.arkadiPoser();
  assert.deepEqual(appels.find(a => a[0] === 'fetch'), ['fetch', 'arkadi_pamiatnikov']);
  assert.match(html, /Un garde forestier, en 1931\./);
  assert.match(html, /Demander \(2 restantes\)/);
  // Hors du musée de Krasnov : rien ne s'ouvre.
  ctx.state.currentCity = 'capitale'; html = '';
  await ctx.arkadiEcouterGuide();
  assert.equal(html, '');
});

test('H.3 — clic sur un guide sans questions ouvertes : le refus nommé renvoie à la fenêtre du guide', () => {
  const s = lire('plateau-pnj.js');
  assert.match(s, /err\.raison = motif;/);
  assert.match(s, /dialogue_non_ouvert: "Le guide répond à vos questions dans sa fenêtre « Écouter le guide »/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
test('H.3 — guide_musee_salle_interne : Krasnov sous « krasnov: », Novomirsk inchangé (PGlite)', { skip: !PGlite && 'PGlite absent (PGLITE_DIR)' }, async () => {
  const db = new PGlite();
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE TABLE public.personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text);
    CREATE TABLE public.ordres_couts (fn text, pa integer, cost integer); INSERT INTO public.ordres_couts VALUES ('questionner_guide_musee', 1, 0);
    INSERT INTO public.personnages_donnees VALUES
      ('K1', 'soviet', 'ville_b', 'musee-novomirsk', 'faune_sauvage'), ('K2', 'soviet', 'ville_b', 'musee-novomirsk', 'hall'),
      ('K3', 'soviet', 'ville_b', 'musee-novomirsk', 'reserve'), ('K4', 'soviet', 'ville_b', 'mairie', 'hall'),
      ('N1', 'soviet', 'capitale', 'musee-novomirsk', 'salle_origines'), ('N2', 'soviet', 'capitale', 'musee-national-republia', 'salle_presidents'),
      ('S1', 'soviet', 'ville_a', 'musee-novomirsk', 'hall'), ('R1', 'republic', 'ville_b', 'musee-novomirsk', 'hall');`);
  await db.exec(lire(MIGRATION));
  await db.exec(lire(MIGRATION));
  const r = Object.fromEntries((await db.query('SELECT name, public.guide_musee_salle_interne(name) s FROM personnages_donnees')).rows.map(x => [x.name, x.s]));
  assert.deepEqual(r, { K1: 'krasnov:faune_sauvage', K2: 'krasnov:hall', K3: null, K4: null, N1: 'novomirsk:salle_origines',
    N2: 'salle_presidents', S1: null, R1: null });
});
