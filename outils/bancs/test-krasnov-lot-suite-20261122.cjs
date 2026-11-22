'use strict';
// Lot de Krasnov, étape I (22/11/2026), côté navigateur :
//   point 2 : fenêtre unique du marché (colonnes Acheter / Vendre / Produire, totaux en direct, Valider grisé avec la raison),
//             ordres du marché de Krasnov, portrait de Nina, chemise à revêtir (+1 ENT à Krasnov, perdu avec ninja ou gilet) ;
//   point 3 : fenêtre de la fontaine générique (nom et image de chaque ville, repli sans image).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

function elementFactice() {
  const el = { innerHTML: '', textContent: '', style: {}, disabled: false, title: '', dataset: {}, value: '',
    classList: { add() {}, remove() {} }, addEventListener() {} };
  return el;
}
function chargerMarche(etat, appels) {
  const els = {};
  const doc = { getElementById: id => (els[id] = els[id] || elementFactice()), querySelectorAll: () => [] };
  const ctx = { console, document: doc, showToast() {}, sbRpc: async (fn, p) => { appels.push([fn, p]); return fn === 'marche_krasnov_etat' ? etat : { ok: false, raison: 'caisse_vide', caisse: 0 }; } };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-marche-krasnov.js'), ctx);
  return { ctx, els };
}
const ETAT = {
  ok: true, ici: true, caisse: 40, pa: 3, argent: 50, place: 10, salaire_pa: 15, produits: [
    { cle: 'fruits_legumes', label: 'Fruits et légumes', genre: 'brut', prix_vente: 2, prix_rachat: 1, stock: 20, stock_max: 60, possede: 5, recette: null, pa: 0, unites: 0 },
    { cle: 'sucre', label: 'Sucre', genre: 'brut', prix_vente: 2, prix_rachat: 1, stock: 1, stock_max: 60, possede: 0, recette: null, pa: 0, unites: 0 },
    { cle: 'confiture', label: 'Confiture d’airelles (bocal)', genre: 'transforme', prix_vente: 10, prix_rachat: 7, stock: 8, stock_max: 60, possede: 0,
      recette: { fruits_legumes: 1, sucre: 1 }, pa: 1, unites: 4 },
    { cle: 'tenue_ninja', label: 'Tenue ninja', genre: 'objet', prix_vente: 32, prix_rachat: 24, stock: 2, stock_max: 10, possede: 2, recette: null, pa: 0, unites: 0 }] };

test('point 2 : prévision fidèle au serveur — totaux, puis la première raison qui grise « Valider »', () => {
  const { ctx } = chargerMarche(ETAT, []);
  const p = ctx.RPMarcheKrasnov.prevoir;
  assert.equal(p(ETAT, {}).raison, 'rien_a_faire');
  const ok = p(ETAT, { fruits_legumes: { a: 2 }, tenue_ninja: { v: 1 }, confiture: { p: 1 } });
  assert.equal(ok.raison, undefined); assert.equal(ok.cout, 4); assert.equal(ok.gain, 24); assert.equal(ok.salaire, 15); assert.equal(ok.pa, 1);
  assert.equal(p(ETAT, { confiture: { p: 2 } }).raison, 'matiere_manquante', 'un seul sucre au marché');
  assert.equal(p(ETAT, { sucre: { v: 1 }, confiture: { p: 2 } }).raison, 'vous_n_en_avez_pas_assez');
  assert.equal(p(ETAT, { tenue_ninja: { a: 3 } }).raison, 'stock_insuffisant');
  assert.equal(p(ETAT, { tenue_ninja: { a: 2 } }).raison, 'argent_insuffisant');
  assert.equal(p(ETAT, { tenue_ninja: { v: 2 } }).raison, 'caisse_vide', 'la caisse ne peut payer que 40 PSK');
  assert.equal(p(Object.assign({}, ETAT, { pa: 0 }), { confiture: { p: 1 } }).raison, 'pa_insuffisants');
  assert.equal(p(Object.assign({}, ETAT, { place: 0 }), { fruits_legumes: { a: 1 } }).raison, 'inventaire_plein');
  assert.equal(p(Object.assign({}, ETAT, { place: 0 }), { fruits_legumes: { a: 1, v: 1 } }).raison, undefined, 'vendre libère de la place');
  assert.match(ctx.RPMarcheKrasnov.txt('r_caisse_vide', { caisse: 40 }), /caisse du marché est vide/);
});

test('point 2 : la fenêtre montre les trois colonnes, les prix, le stock, la recette, et grise « Valider » avec la raison', async () => {
  const appels = [];
  const { ctx, els } = chargerMarche(ETAT, appels);
  await ctx.ouvrirMarcheKrasnov();
  const h = els['postes-body'].innerHTML;
  assert.equal(els['postes-modal-title'].textContent, 'Marché de Krasnov');
  for (const m of ['>Acheter<', '>Vendre<', '>Produire<', '2 PSK l’unité', 'rachat 24 PSK', 'Au marché : 8', 'Vous en avez : 2',
    '1 fournée = 1 PA → 4 confiture', 'prend au marché : 1 Fruits et légumes + 1 Sucre', 'payé 15 PSK par PA', 'Caisse du marché : 40 PSK',
    'tout se fait en une seule fois, ou rien du tout', '>Annuler<', '>Valider<']) assert.ok(h.includes(m), m);
  assert.equal(els['mk-valider'].disabled, true);
  assert.equal(els['mk-valider'].title, 'Inscrivez au moins une quantité.');
  assert.equal(els['mk-raison'].textContent, 'Inscrivez au moins une quantité.');
  ctx.RPMarcheKrasnov._saisie({ fruits_legumes: { a: 1 } });
  await ctx.ouvrirMarcheKrasnov();
  assert.equal(els['mk-valider'].disabled, false);
  assert.match(els['mk-total'].textContent, /Vous dépensez 2 PSK · vous gagnez 0 PSK \(ventes\) \+ 0 PSK \(travail\) · PA : 0/);
  assert.deepEqual(appels.map(a => a[0]), ['marche_krasnov_etat', 'marche_krasnov_etat']);
});

test('point 2 : ordres du marché de Krasnov, routeur, script chargé, portrait de Nina descendu', () => {
  const data = lire('data.js');
  assert.match(data, /excludeOrders: \['se_nourrir', 'produire_commerce', 'faire_achats_marche', 'vendre_matiere_commerce', 'acheter_graisse'\]/);
  assert.match(data, /\{fn:'marche_krasnov', label:'Acheter, vendre, produire'/);
  const ctx = { window: {}, console, navigator: {}, localStorage: { getItem() { return null; }, setItem() {} },
    document: { addEventListener() {}, getElementById() { return null; }, querySelector() { return null; } } };
  vm.createContext(ctx);
  vm.runInContext(data + ';globalThis.__W = WORLD;', ctx);
  const ro = ctx.__W.soviet.ville_b.buildingContext.marche.roomOverrides.marche_ext;
  assert.equal(ro.persons.find(p => p.name === 'Nina Gorbounova (PNJ)').photoPos, '50% 18%');
  assert.equal(ro.orders.map(o => o.fn).join(), 'marche_krasnov');
  assert.match(lire('plateau-router.js'), /if \(fn === 'marche_krasnov'\) \{ if \(typeof ouvrirMarcheKrasnov === 'function'\) ouvrirMarcheKrasnov\(\); return; \}/);
  assert.match(lire('plateau.html'), /<script src="plateau-marche-krasnov\.js\?v=krasnov-marche-20261122"><\/script>/);
  assert.equal((lire('plateau-personnage.js').match(/boutonMangerProduitMarche\(item,/g) || []).length, 2, 'bouton « Manger » dans les deux fiches d’objet');
});

test('point 2 : la chemise de bûcheron ne donne +1 ENT à Krasnov que revêtue, et pas avec la tenue ninja ou le gilet', () => {
  const src = lire('plateau-organisations-quetes.js');
  const debut = src.indexOf('function categorieRevetementObjet'), fin = src.indexOf('function getStatEffective');
  const ctx = { state: {} }; vm.createContext(ctx);
  vm.runInContext(src.slice(debut, fin), ctx);
  const chemise = { familleProduitMarche: 'integration_locale', bonusIntegrationVille: 'soviet.ville_b', revetable: 'chemise' };
  const base = { char: { name: 'Nina' }, country: 'soviet', currentCity: 'ville_b' };
  const bonus = inv => { ctx.state = Object.assign({}, base, { inventory: inv }); return vm.runInContext('bonusEntIntegrationLocale()', ctx); };
  assert.equal(bonus([chemise]), 0, 'dans le sac : rien');
  assert.equal(bonus([Object.assign({ porte_par: 'Nina' }, chemise)]), 1, 'revêtue à Krasnov : +1 ENT');
  assert.equal(bonus([Object.assign({ porte_par: 'Nina' }, chemise), { type: 'tenue_ninja_marche', porte_par: 'Nina' }]), 0, 'tenue ninja revêtue');
  assert.equal(bonus([Object.assign({ porte_par: 'Nina' }, chemise), { type: 'protection', name: 'Gilet pare-balles', porte_par: 'Nina' }]), 0, 'gilet revêtu');
  ctx.state = Object.assign({}, base, { currentCity: 'capitale', inventory: [Object.assign({ porte_par: 'Nina' }, chemise)] });
  assert.equal(vm.runInContext('bonusEntIntegrationLocale()', ctx), 0, 'hors de Krasnov');
  assert.equal(bonus([{ familleProduitMarche: 'integration_locale', bonusIntegrationVille: 'ville_b' }]), 1, 'objets d’intégration sans « revetable » : règle d’origine');
});

test('point 3 : fenêtre de la fontaine générique — nom de la fontaine de chaque ville, texte exact à Krasnov, pas d’image de repli', () => {
  const c = lire('plateau-climat.js');
  assert.match(c, /tete: '\{lieu\}\. L’eau est gratuite\. Puiser coûte 1 PA, quelle que soit la quantité\./);
  assert.match(c, /lieuKrasnov: 'Fontaine de la statue de l’Ours'/);
  assert.match(c, /const img = \(e\.point && e\.point\.image\) \|\| '';/);
  assert.match(c, /onerror="this\.remove\(\)"/);
  assert.doesNotMatch(c, /\|\| 'images\/Sovarka\/Krasnov\/Krasnov_place_ours_fontaine\.webp'/);
  const m = lire('migrations/20261122161000_points_eau_une_fontaine_par_ville.sql');
  for (const n of ['luthecia-hotel-de-ville', 'montrouge-vue-7', 'psm-hotel-mairie-place', 'novomirsk-vue-1', 'starovka-rue-mairie-marche'])
    assert.ok(m.includes("'" + n + "'"), n);
});
