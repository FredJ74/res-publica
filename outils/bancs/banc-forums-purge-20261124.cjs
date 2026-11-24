'use strict';
// Mission « Purge » (Fred, 24/11/2026), bloc B — forums, côté écran (le serveur est éprouvé par
// banc-forums-acces-pglite-20261124.cjs). Vrai code de forum.js et supabase.js, extrait et exécuté avec un état simulé.
//  B.1 — règles d'accès : pays affichables, forums locaux (domicile + ville visitée), lecture seule des forums nationaux
//        visités, sous-forums nationaux filtrés par pays (Bernard ne voit plus ceux de Républia).
// Lancement : node --test outils/bancs/banc-forums-purge-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const FORUM = lire('forum.js'), SB = lire('supabase.js');
function bloc(src, debut) {
  const i = src.indexOf(debut); assert.ok(i >= 0, debut + ' introuvable');
  let j = src.indexOf('{', i), p = 0;
  for (; j < src.length; j++) { if (src[j] === '{') p++; else if (src[j] === '}' && --p === 0) break; }
  return src.slice(i, j + 1);
}
function ligne(src, debut) { const i = src.indexOf(debut); assert.ok(i >= 0, debut); return src.slice(i, src.indexOf('\n', i)); }
function regles(etat) {
  const c = vm.createContext({ console, state: etat, maNationalite: () => etat.nationalite });
  vm.runInContext([bloc(FORUM, 'function forumEstNational('), bloc(FORUM, 'function forumEstTerritorial('),
    bloc(FORUM, 'function paysForumsPossibles('), bloc(FORUM, 'function paysForums('), bloc(FORUM, 'function villesForumLocal('),
    bloc(FORUM, 'function villeForumLocal('), bloc(FORUM, 'function forumNationalLectureSeule('),
    bloc(SB, 'function sbForumEstTerritorial('), bloc(SB, 'function sbForumSujetDansPays(')].join('\n'), c);
  return c;
}
const liste = x => JSON.parse(JSON.stringify(x));

test('B.1 Bernard (Sovarka, chez lui) : les sous-forums nationaux sont filtrés par pays', () => {
  const c = regles({ nationalite: 'soviet', country: 'soviet', currentCity: 'capitale', domicile: { country: 'soviet', city: 'ville_b' } });
  assert.deepEqual(liste(c.paysForumsPossibles()), ['soviet']);
  for (const f of ['national', 'presidence', 'assemblee', 'gouvernement', 'presse']) {
    assert.equal(c.sbForumEstTerritorial(f), true, f + ' filtré par pays');
    assert.equal(c.sbForumSujetDansPays(f, 'republic', c.paysForums()), false, f + ' de Républia masqué');
  }
  assert.equal(c.sbForumSujetDansPays('international', 'republic', 'soviet'), true, 'international inchangé');
  assert.deepEqual(liste(c.villesForumLocal()), ['ville_b', 'capitale'], 'domicile (Krasnov) et ville où il est (Novomirsk)');
  assert.equal(c.forumNationalLectureSeule('presse'), false);
});

test('B.1 à l’étranger : pays visité en lecture seule (national et sous-forums), locaux de domicile et de visite', () => {
  const etat = { nationalite: 'republic', country: 'soviet', currentCity: 'ville_b', domicile: { country: 'republic', city: 'capitale' } };
  const c = regles(etat);
  assert.deepEqual(liste(c.paysForumsPossibles()), ['republic', 'soviet']);
  assert.equal(c.paysForums(), 'republic', 'par défaut : sa nationalité');
  assert.deepEqual(liste(c.villesForumLocal()), ['capitale'], 'Républia affichée : Luthécia (domicile)');
  assert.equal(c.forumNationalLectureSeule('national'), false);
  etat.forumPays = 'soviet';
  assert.deepEqual(liste(c.villesForumLocal()), ['ville_b'], 'Sovarka affichée : Krasnov (ville visitée)');
  for (const f of ['national', 'presse', 'presidence', 'assemblee', 'gouvernement']) assert.equal(c.forumNationalLectureSeule(f), true, f);
  assert.equal(c.forumNationalLectureSeule('local_ville_b'), false, 'forum local visité : écriture');
  etat.forumPays = 'narco';
  assert.equal(c.paysForums(), 'republic', 'un pays ni natal, ni visité, ni de domicile est ignoré');
});

test('B.1 domicile hors de son pays : le pays du domicile est proposé et son forum local accessible', () => {
  const etat = { nationalite: 'republic', country: 'republic', currentCity: 'capitale', domicile: { country: 'soviet', city: 'ville_a' }, forumPays: 'soviet' };
  const c = regles(etat);
  assert.deepEqual(liste(c.paysForumsPossibles()), ['republic', 'soviet']);
  assert.deepEqual(liste(c.villesForumLocal()), ['ville_a']);
});

test('B.1 raccords : lecture seule dite en clair, publication bornée aux forums locaux accessibles', () => {
  assert.match(bloc(FORUM, 'function renderTopicList('), /lectureSeule \? htmlForumLectureSeule\(\) : ''/);
  assert.match(bloc(FORUM, 'function renderTopicView('), /forumNationalLectureSeule\(currentForumId\) \? htmlForumLectureSeule\(\)/);
  assert.match(bloc(FORUM, 'async function forumPublierAvecJauges('), /villesForumLocal\(\)\.map\(v => idForumLocal\(v\)\)\.includes\(forumId\)/);
  assert.match(bloc(FORUM, 'async function forumPublierAvecJauges('), /const territorial = forumEstTerritorial\(forumId\)/);
  assert.match(lire('GAME-DESIGN-FORUMS.md'), /Règles d'accès du 24\/11\/2026/);
});

test('B.2 section « Forums locaux » séparée des « Forums nationaux »', () => {
  assert.match(FORUM, /private: false, cat: 'local', local: true \};/);
  const items = bloc(FORUM, 'function renderForumCategorieItems(');
  assert.doesNotMatch(items, /parLocal/, 'plus de forum local dans les forums nationaux');
  assert.match(items, /cat === 'local' && entries\.length === 0/);
  const barre = bloc(FORUM, 'function renderForumSidebar(');
  const iNat = barre.indexOf("renderCategorieHeader('intra'"), iLoc = barre.indexOf("renderCategorieHeader('local'"), iInter = barre.indexOf("renderCategorieHeader('inter'");
  assert.ok(iNat > 0 && iLoc > iNat && iInter > iLoc, 'Forums nationaux, puis Forums locaux, puis internationaux');
  assert.match(barre, /'localForums','Forums locaux'/);
});

function dates() {
  const c = vm.createContext({ console, Intl, Date });
  vm.runInContext([bloc(FORUM, 'function rpDecalageParisMs('), bloc(FORUM, 'function rpInstantForum('), bloc(FORUM, 'function rpDateLisible('),
    bloc(FORUM, 'function parseGameTime(')].join('\n'), c);
  return c;
}
test('B.3 sujets classés de la publication ou réponse la plus récente à la plus ancienne, tous formats confondus', () => {
  const c = dates();
  // Formats réellement présents en production le 24/11/2026 (forum_topics.time / last_post_time).
  const sujets = [
    { id: 'iso-z', time: '2026-11-16T17:33:38.901Z' },
    { id: 'serveur', time: '21/11/2026 03:06', lastPostTime: '23/11/2026 22:51' },
    { id: 'ancien', time: '22/11/2026 · 20h04' },
    { id: 'pg', time: '2026-11-23 18:48:24.969+00' },
    { id: 'jour', time: 'Jour 3 · 10h00' }
  ];
  const ordre = sujets.slice().sort((a, b) => c.parseGameTime(b.lastPostTime || b.time) - c.parseGameTime(a.lastPostTime || a.time)).map(t => t.id);
  assert.deepEqual(ordre, ['serveur', 'pg', 'ancien', 'iso-z', 'jour'], 'la réponse du 23/11 à 22 h 51 remonte le sujet du 21/11 en tête');
  // Les deux tris de forum.js lisent la dernière activité.
  assert.match(bloc(FORUM, 'function renderTopicList('), /parseGameTime\(b\.lastPostTime \|\| b\.time\) - parseGameTime\(a\.lastPostTime \|\| a\.time\)/);
  assert.match(bloc(FORUM, 'async function loadForumTopicsFromSB('), /sort\(\(a, b\) => parseGameTime\(b\.lastPostTime \|\| b\.time\) - parseGameTime\(a\.lastPostTime \|\| a\.time\)\)/);
});
