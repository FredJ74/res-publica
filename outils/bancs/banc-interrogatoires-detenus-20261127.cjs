'use strict';
// Mission du 27/11/2026 (soir), étape 1 : « Interroger un détenu » au goulag, au QHS et au Renseignement, sur le
// modèle du goulag (1 PA, −7 PA au détenu, refus à 1 PA, jet de Volonté) ; indice réel au(x) juge(s) avec boutons
// « Me saisir » / « Classer » ; mauvais traitement consigné contre l'interrogateur. Les épreuves SQL ont tourné dans
// une transaction annulée en production avant application (RELAIS.md, mission du 27/11 soir).
// Usage : node --test outils/bancs/banc-interrogatoires-detenus-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261127220000_interrogatoires_detenus.sql');
const corps = nom => { const i = MIG.indexOf('FUNCTION public.' + nom + '('); assert.ok(i > 0, nom); const j = MIG.indexOf('CREATE OR REPLACE FUNCTION', i + 10); return MIG.slice(i, j > 0 ? j : undefined); };

test('serveur : les trois lieux suivent le modèle du goulag et laissent les deux traces', () => {
  for (const f of ['qhs_interroger', 'renseignement_interroger', 'sovarka_goulag_interroger']) {
    const c = corps(f);
    assert.match(c, /interrogatoire_traces_v1/, f);
    assert.match(c, /<= 1 THEN[\s\S]{0,80}detenu_epuise/, f + ' : refus à 1 PA');
    assert.match(c, /greatest\(1, coalesce\(d\.pa, ?0\) - 7\)/, f + ' : −7 PA, plancher 1');
    assert.match(c, /interrogatoire_mauvais_traitement_interne\(/, f + ' : mauvais traitement');
    assert.match(c, /interrogatoire_indice_poser_interne\(/, f + ' : indice au juge');
    assert.match(c, /, 1, 0\)/, f + ' : 1 PA');
  }
  assert.match(corps('interrogatoire_probabilite_interne'), /least\(95, greatest\(5, round\(50 \+ 5 \*/);
  assert.match(corps('qhs_interroger'), /FROM public\.jugements j[\s\S]{0,120}ORDER BY j\.created_at DESC/);
  // Renseignement : tous les juges du pays (juge NULL) + copie au ministre, sans bouton.
  const r = corps('renseignement_interroger');
  assert.match(r, /'renseignement', v_pays, d\.name, v_nom, NULL,/);
  assert.match(r, /mail_systeme_poser_interne\('Direction du Renseignement', v_nom,/);
  assert.doesNotMatch(r, /'inf'/, 'plus de +5 d’influence');
  assert.match(MIG, /DELETE FROM public\.ordres_generiques WHERE fn IN \('interroger', 'interroger_renseignement'\)/);
});

test('serveur : le goulag reste sous son verrou', () => {
  const c = corps('sovarka_goulag_interroger');
  assert.ok(c.indexOf('sovarka_goulag_ordres_refus_interne()') < c.indexOf('payer_ordre_interne'));
  assert.doesNotMatch(MIG, /sovarka_goulag_ordres_refus_interne\s*\(\)\s*\n?\s*RETURNS/);
  assert.doesNotMatch(MIG, /actif\s*=\s*true/i);
});

test('serveur : se saisir ouvre une affaire au nom du juge, visible dans juge_dossiers (statut saisie)', () => {
  const c = corps('interrogatoire_indice_traiter');
  assert.match(c, /juge_moi\(\)/);
  assert.match(c, /'status', 'saisie'/);
  assert.match(c, /dossier_acte_consigner\(v_aff, i\.pays, v_ville, 'juge_saisi'/);
  assert.match(c, /i\.juge IS NOT NULL AND i\.juge IS DISTINCT FROM v_j\.nom/);
});

test('écran : routes, ordre des juges, coûts affichés', () => {
  const routeur = lire('plateau-router.js'), data = lire('data.js'), html = lire('plateau.html');
  for (const [fn, f] of [['interroger', 'ouvrirInterrogatoireQhs'], ['indices_interrogatoire', 'ouvrirIndicesInterrogatoire'], ['interroger_renseignement', 'ouvrirInterrogatoireRenseignement']])
    assert.match(routeur, new RegExp("fn === '" + fn + "'\\) \\{ " + f + '\\(\\)'));
  assert.ok(html.indexOf('plateau-interrogatoires.js') > 0 && html.indexOf('plateau-interrogatoires.js') < html.indexOf('src="plateau-router.js'));
  assert.equal((data.match(/fn:'indices_interrogatoire'/g) || []).length, 2);
  assert.match(data, /ordre\('indices_interrogatoire'/);
  for (const m of data.match(/\{fn:'interroger(_renseignement)?'[^}]*\}/g)) assert.match(m, /pa:1, cost:0/);
  assert.doesNotMatch(lire('plateau-sovarka-provinces.js'), /function ouvrirInterrogatoireRenseignement/);
});

test('textes : neuf langues, mêmes clés', () => {
  const ctx = { window: {}, document: { readyState: 'complete' } };
  vm.runInNewContext(lire('plateau-interrogatoires.js'), ctx);
  const T = ctx.window.RP_INTERROGATOIRES_T;
  const cles = o => Object.keys(o).filter(k => k !== 'r').sort().join(',') + '|' + Object.keys(o.r).sort().join(',');
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(T)) assert.equal(cles(T[l]), cles(T.fr), l);
});
