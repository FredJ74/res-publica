'use strict';
// Décisions de Fred du 18/11/2026 (points 3, 5 et 7) : syndicat national de Sovarka et départ d'un maire.
// Le serveur est éprouvé à part (migrations 20261118053000 et 20261118054000, essais en transaction annulée).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];

function monde() {
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  return ctx;
}

test('bureau du syndicat national dans les trois mairies de Sovarka, un PNJ chacun, plus de siège syndical', () => {
  const ctx = monde();
  const attendus = { capitale: ['mairie-capitale', 'Lev Lozungov (PNJ)', 'lev_lozungov'], ville_b: ['mairie', 'Anatoli Transparantov (PNJ)', 'anatoli_transparantov'], ville_a: ['mairie', 'Tserenjav Dachiev (PNJ)', 'tserenjav_dachiev'] };
  for (const [ville, [bat, nom, profil]] of Object.entries(attendus)) {
    const cite = ctx.WORLD.soviet[ville];
    const piece = cite.buildingContext[bat].roomsExtra.bureau_syndicat_national;
    assert.ok(piece, ville);
    assert.equal(piece.name, 'Bureau du syndicat national');
    assert.equal(JSON.stringify(piece.persons.map(p => [p.name, p.profilId])), JSON.stringify([[nom, profil]]));
    assert.deepEqual([...piece.orders.map(o => o.fn)], ['se_syndiquer_etat', 'consulter_syndicat_etat', 'quitter_syndicat_etat', 'declencher_election_syndicat_etat', 'manifestation_soutien_president']);
    assert.ok(piece.orders.find(o => o.fn === 'manifestation_soutien_president').requiresChefSyndicatEtat);
    const adh = piece.orders.find(o => o.fn === 'se_syndiquer_etat'); assert.equal(adh.cost, 15); assert.equal(adh.pa, 1);
    assert.match(piece.imageUrl, /_mairie_bureau_syndicat_national\.webp$/, 'décor de Fred');
    assert.match(piece.persons[0].photoUrl, /_portrait_mairie_/); assert.ok(fs.existsSync(path.join(R, piece.persons[0].photoUrl)));
    assert.ok(!cite.buildingContext['siege-syndical'], 'siège syndical retiré : ' + ville);
    assert.ok(fs.existsSync(path.join(R, piece.imageUrl)), piece.imageUrl);
  }
  // La Républia garde son siège syndical.
  assert.ok(ctx.WORLD.republic.ville_b.buildings.includes('siege-syndical'));
  const fiches = lire('api/_pnj-personnalites.js');
  for (const p of ['lev_lozungov', 'anatoli_transparantov', 'tserenjav_dachiev']) {
    const i = fiches.indexOf("'" + p + "':"); assert.ok(i > 0, p);
    const f = fiches.slice(i, fiches.indexOf('style:', i));
    assert.match(f, /le travailleur ne bloque pas son propre outil/);
    assert.match(f, /1 PA et une cotisation unique de 15 PSK, jamais renouvelée/); assert.match(f, /au moins 10 syndiqués/); assert.match(f, /2 PA chacun/);
    assert.doesNotMatch(f, /référent/i, 'PNJ non référent');
  }
  assert.doesNotMatch(lire('plateau-pnj.js'), /lev_lozungov|anatoli_transparantov/, 'hors des listes de référents');
});

test('écran du syndicat : routes, garde du chef, script chargé, textes dans les neuf langues', () => {
  const routeur = lire('plateau-router.js');
  for (const fn of ['se_syndiquer_etat', 'consulter_syndicat_etat', 'quitter_syndicat_etat', 'declencher_election_syndicat_etat', 'manifestation_soutien_president'])
    assert.ok(routeur.includes("fn === '" + fn + "'"), fn);
  assert.match(lire('plateau.html'), /<script src="plateau-sovarka-syndicat\.js\?v=[^"]+"><\/script>/);
  assert.match(lire('plateau-politique.js'), /if \(o\.requiresChefSyndicatEtat\) \{/);
  const ctx = { console, i18next: { language: 'fr' } }; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('plateau-sovarka-syndicat.js'), ctx);
  const T = ctx.RPSyndicatEtatI18n.textes;
  assert.deepEqual([...Object.keys(T)].sort(), LANGUES.slice().sort());
  for (const l of LANGUES) {
    assert.deepEqual(Object.keys(T[l]), Object.keys(T.fr), l);
    for (const k of Object.keys(T.fr)) {
      assert.ok(String(T[l][k]).trim(), l + ' ' + k);
      for (const v of (T.fr[k].match(/\{[a-z]+\}/g) || [])) assert.ok(T[l][k].includes(v), l + ' ' + k + ' ' + v);
    }
  }
  assert.match(lire('plateau-sovarka-syndicat.js'), /sbRpcVerdict\('syndicat_etat_manifester', \{ p_requete: requete \}\)/);
  const variantes = lire('i18n/order-variants-resources.js');
  for (const k of ['union_state_join', 'union_state_view', 'union_state_leave', 'union_state_election', 'union_state_rally'])
    assert.equal((variantes.match(new RegExp('"' + k + '": ', 'g')) || []).length, 9, k);
});

test('manifestation de soutien : règle du taux et de l\'effet sur la POP (serveur)', () => {
  const sql = lire('migrations/20261118053000_syndicat_national_sovarka.sql');
  // Même formule qu'au serveur, recopiée ici pour éprouver les exemples de Fred.
  const effet = t => t > 50 ? Math.min(10, Math.floor((t - 50) / 5)) : t < 50 ? -Math.min(10, Math.floor((50 - t) / 5)) : 0;
  assert.equal(effet(100), 10); assert.equal(effet(40), -2); assert.equal(effet(50), 0); assert.equal(effet(55), 1); assert.equal(effet(180), 10);
  assert.match(sql, /WHEN p_taux > 50 THEN least\(10, \(p_taux - 50\) \/ 5\)/);
  assert.match(sql, /WHEN p_taux < 50 THEN -least\(10, \(50 - p_taux\) \/ 5\)/);
  assert.match(sql, /coalesce\(x\.pa, 0\) > 3/); assert.match(sql, /SET pa = pa - 2/);
  assert.match(sql, /< 10 THEN\s+RETURN jsonb_build_object\('ok', false, 'raison', 'syndicat_trop_petit'/);
  assert.match(sql, /PRIMARY KEY \(ville, jour\)/);
  assert.match(lire('migrations/20261118056000_syndicat_cotisation_tutelle_complete.sql'), /SET pa = 1, cost = 15 WHERE fn = 'se_syndiquer_etat'/);
  assert.doesNotMatch(lire('api/cron-minuit.js'), /orga_syndicat_etat_soviet/, 'cotisation jamais renouvelée');
  assert.match(sql, /INSERT INTO public\.evenements_globaux/); assert.match(sql, /INSERT INTO public\.journal_articles_en_attente/);
});

test('départ d\'un maire : proposition à l\'adjoint (72 h), tutelle du ministre, pas de maire PNJ de secours', () => {
  const sql = lire('migrations/20261118054000_maire_depart.sql');
  assert.match(sql, /now\(\) \+ interval '72 hours'/);
  assert.match(sql, /CASE WHEN p_pays = 'soviet' THEN 'min_fin' ELSE 'min_int' END/);
  assert.match(sql, /\[\[act:maire_oui\|' \|\| v_id \|\| '\]\] \[\[act:maire_non\|/);
  const forum = lire('forum.js');
  assert.match(forum, /maire_oui: +\{ fn:'repondreSuccessionMairie', n:1, apres:\['true'\]/);
  assert.equal((lire('i18n/forum-ui.js').match(/"maire_oui": /g) || []).length, 9);
  const cron = lire('api/cron-minuit.js');
  assert.match(cron, /tacheQuotidienne\('maires_departs', traiterMairesDepartsQuotidien\)/);
  assert.match(cron, /if \(posteId === 'maire' && \(cycle\.vacance \|\| cycle\.tutelle\)\)/);
  // Garde d'écran : le ministre de tutelle a le bureau du maire, jamais celui de l'adjoint.
  const pol = lire('plateau-politique.js');
  const i = pol.indexOf('function tutelleMairieIci('), src = pol.slice(i, pol.indexOf('\n}\n', i) + 3);
  const essai = (pays, poste, piece, cycle) => {
    const ctx = vm.createContext({ state: { country: pays, currentRoom: piece, currentCity: 'ville_a' }, CYCLES_ELECTORAUX: { [pays]: { maire_ville_a: cycle } } });
    vm.runInContext(src, ctx); return ctx.tutelleMairieIci(poste);
  };
  assert.equal(essai('soviet', 'min_fin', 'bureau_maire_local', { eluId: null, tutelle: { poste: 'min_fin' } }), true);
  assert.equal(essai('soviet', 'min_fin', 'bureau_maire_adjoint', { eluId: null, tutelle: {} }), false, 'pas le bureau de l\'adjoint');
  assert.equal(essai('soviet', 'min_int', 'bureau_maire_local', { eluId: null, tutelle: {} }), false, 'mauvais ministre en Sovarka');
  assert.equal(essai('republic', 'min_int', 'bureau_maire_local', { eluId: null, tutelle: {} }), true);
  assert.equal(essai('republic', 'min_int', 'bureau_maire_local', { eluId: 'X', tutelle: {} }), false, 'un maire est élu');
  const nat = lire('plateau-nationalite.js');
  assert.match(pol, /regle\.nommePar === 'maire' && typeof tutelleMairieIci === 'function' && tutelleMairieIci\(/, 'nominations sous tutelle');
  const tut = lire('migrations/20261118056000_syndicat_cotisation_tutelle_complete.sql');
  assert.match(tut, /mairie_campagne_securite_interne/); assert.match(tut, /poste_autorite_de/);
  assert.match(nat, /sbRpcVerdict\('maire_succession_repondre', \{ p_id: String\(id \|\| ''\), p_accepte: oui \}\)/);
});
