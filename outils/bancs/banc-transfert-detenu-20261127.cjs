'use strict';
// Mission du 27/11/2026 (soir), étape 4 : « Demander le transfert d'un détenu » entre Républia et Sovarka. L'ambassadeur
// demande, le ministre des Affaires étrangères du pays hôte accepte ou refuse ; le détenu purge le reste de sa peine chez
// lui. Épreuves SQL passées dans une transaction annulée en production avant application.
// Usage : node --test outils/bancs/banc-transfert-detenu-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261127234000_transfert_detenu_ambassades.sql');
const fonction = n => { const i = MIG.indexOf('FUNCTION public.' + n + '('); const j = MIG.indexOf('CREATE OR REPLACE FUNCTION', i + 10); return MIG.slice(i, j > 0 ? j : undefined); };

test('serveur : seuls Républia et Sovarka, compatriote détenu dans le pays hôte, décision du ministre des Affaires étrangères hôte', () => {
  assert.match(fonction('transfert_detenu_pays_ouverts_interne'), /p_empire IN \('republic', 'soviet'\) AND p_hote IN \('republic', 'soviet'\)/);
  const refus = fonction('transfert_detenu_refus_interne');
  assert.match(refus, /personnage_nationalite\(p_detenu\) IS DISTINCT FROM p_empire/);
  assert.match(refus, /v_det\.country IS DISTINCT FROM p_hote/);
  const dem = fonction('transfert_detenu_demander');
  assert.match(dem, /ambassade_ambassadeur_interne\(p_empire\)/);
  assert.match(dem, /payer_ordre\(v_moi, 'demander_transfert_detenu', 1, 0\)/);
  assert.match(dem, /transfert_detenu_mae_interne\(v_hote\)/);
  const dec = fonction('transfert_detenu_decider');
  assert.match(dec, /v_poste IS DISTINCT FROM 'min_ae'/);
  assert.match(dec, /t\.pays_hote IS DISTINCT FROM v_pays/);
  assert.doesNotMatch(dec, /min_just/);
  assert.match(dec, /SET country = t\.empire, city = 'capitale'/);
  assert.doesNotMatch(dec, /jour_fin\s*=/, 'reste de la peine inchangé');
  for (const dest of ['t.ambassadeur', 'v_nom']) assert.ok((dec.match(new RegExp("mail_systeme_poser_interne\\('Ministère des Affaires étrangères', " + dest.replace('.', '\\.'), 'g')) || []).length >= 2, dest);
});

test('écran : transfert actif chez Républia et Sovarka, grisé ailleurs ; ordre du ministre ; routes', () => {
  const data = lire('data.js'), routeur = lire('plateau-router.js');
  const lignes = data.split('\n').filter(l => l.includes("fn:'demander_transfert_detenu'"));
  assert.equal(lignes.filter(l => !/bientot:/.test(l)).length, 2);
  assert.equal(lignes.filter(l => /bientot:/.test(l)).length, 4);
  assert.match(data, /fn:'transferts_detenus',[^\n]*requiresPost:'min_ae'/);
  assert.match(routeur, /fn === 'demander_transfert_detenu'\) \{ ouvrirTransfertDetenu\(\)/);
  assert.match(routeur, /fn === 'transferts_detenus'\) \{ ouvrirDemandesTransfert\(\)/);
  const html = lire('plateau.html');
  assert.ok(html.indexOf('plateau-transferts-detenus.js') > 0 && html.indexOf('plateau-transferts-detenus.js') < html.indexOf('src="plateau-router.js'));
  assert.doesNotMatch(lire('ARCHITECTURE.md'), /Voyage entre empires \| N'existe pas encore/);
  assert.doesNotMatch(lire('GAME-DESIGN-AMBASSADES.md'), /### Attendent le voyage entre empires/);
});

test('textes : neuf langues, mêmes clés', () => {
  const ctx = { window: {} };
  vm.runInNewContext(lire('plateau-transferts-detenus.js'), ctx);
  const T = ctx.window.RP_TRANSFERTS_DETENUS_T, cles = o => Object.keys(o).sort().join() + '|' + Object.keys(o.r).sort().join() + '|' + Object.keys(o.e).sort().join();
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(T)) assert.equal(cles(T[l]), cles(T.fr), l);
});
