'use strict';
// Mission du soir du 25/11/2026, bloc 4 : écran du premium (plateau-premium.js) et retrait des tarifs écrits en dur.
// Aucun prix ni « Stripe » dans le code servi ; la fenêtre n'affiche un prix que si la base le rend (et ≥ 2 €) ;
// sans la migration, « offert pendant la bêta » ; la réclame est toujours échappée ; l'encadré ne touche jamais aux ordres.
// Lancer : node --test outils/bancs/banc-premium-ecran-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('aucun tarif écrit en dur ni mention de Stripe dans le code servi', () => {
  const servis = ['plateau-premium.js', 'plateau-publicite-premium.js', 'plateau-commerce-pj.js', 'plateau-appartements.js', 'admin.html',
    'i18n/premium-ads-resources.js', 'i18n/appartements-resources.js', 'supabase/edge-functions/commerce-decoration/index.ts',
    'supabase/edge-functions/logement-decoration/index.ts'];
  // Le 28/11/2026, Fred a choisi Stripe (api/_paiement.js, plateau-paiement.js) : seuls les tarifs en dur restent interdits partout.
  for (const f of ['api/_paiement.js', 'plateau-paiement.js']) assert.doesNotMatch(lire(f), /[047][.,]99 ?€|€ ?[047][.,]99/, f);
  for (const f of servis) {
    const s = lire(f);
    assert.doesNotMatch(s, /[047][.,]99 ?€|€ ?[047][.,]99|0[.,]99 (euro|يورو|歐元|유로)/i, f);
    assert.doesNotMatch(s, /stripe/i, f);
  }
});

test('branchements : script chargé, réveil, atelier de presse, ateliers de décoration côté serveur', () => {
  assert.match(lire('plateau.html'), /<script src="plateau-premium\.js\?v=premium-20261125-stripe-20261128"><\/script>/);
  assert.match(lire('plateau-personnage.js'), /window\.premiumPubExterneAuDormir\(\)/);
  assert.match(lire('plateau-publicite-premium.js'), /ouvrirPublicitesJoueur\(\)/);
  assert.match(lire('supabase/edge-functions/commerce-decoration/index.ts'), /premium_renouvellement_autoriser_service[\s\S]*premium_personnalisation_autoriser_service/);
  assert.match(lire('supabase/edge-functions/logement-decoration/index.ts'), /premium_renouvellement_autoriser_service/);
});

function charger(rpcs) {
  const noeuds = {};
  const el = id => (noeuds[id] = noeuds[id] || { id, innerHTML: '', textContent: '', classList: { add() {} },
    querySelector(sel) { return { innerHTML: '', set innerHTML(v) { el(id)._zone = v; }, get innerHTML() { return el(id)._zone || ''; },
      querySelectorAll() { return []; }, querySelector() { return null; } }; } });
  const ctx = { window: {}, document: { getElementById: id => (id === 'hg-reclame' ? null : el(id)), body: { appendChild(n) { ctx.ajoutes.push(n); } }, createElement: () => ({ style: {}, setAttribute() {},
    set innerHTML(v) { this._h = v; }, get innerHTML() { return this._h; }, querySelector() { return { addEventListener() {} }; } }) },
    ajoutes: [], setTimeout: f => f(), state: { char: { name: 'Olga' } }, console,
    sbRpc: async (fn, p) => (rpcs[fn] ? rpcs[fn](p) : null) };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-premium.js'), ctx);
  return { ctx, noeuds };
}

test('fenêtre : sans la migration, « offert pendant la bêta » ; prix montré seulement s’il est rendu et ≥ 2 €', async () => {
  const a = charger({});
  await a.ctx.ouvrirPremium('commerce_premium', 'fonds-1');
  assert.match(a.noeuds['postes-body']._zone, /offertes à tous pendant la bêta/);
  const d = { ok: true, beta: false, abonne: false, paiement_ouvert: true, semaine: {}, produits: [
    { produit: 'commerce_premium', nature: 'option', libelle: 'Commerce premium', prix_fixe: true, prix_centimes: 300, droit: false },
    { produit: 'bureau_six', nature: 'option', libelle: 'Bureau à 6', prix_fixe: false, droit: false },
    { produit: 'abonnement_mensuel', nature: 'abonnement', libelle: 'Abonnement', prix_fixe: true, prix_centimes: 150 }] };
  const b = charger({ premium_droits_lire: () => d });
  await b.ctx.ouvrirPremium('commerce_premium', 'fonds-1');
  const h = b.noeuds['postes-body']._zone;
  assert.match(h, /data-premium-acheter="commerce_premium">Acheter — 3,00\s?€/);
  assert.match(h, /Bureau à 6[\s\S]*Bientôt disponible/);
  assert.doesNotMatch(h, /1,50/, 'un prix sous 2 € n’est jamais proposé');
  const c = charger({ premium_droits_lire: () => ({ ...d, beta: true }) });
  await c.ctx.ouvrirPremium();
  assert.doesNotMatch(c.noeuds['postes-body']._zone, /Acheter/, 'bêta : rien à acheter');
});

test('réclames : texte échappé, une demande par jour et par support, encadré vide', async () => {
  let n = 0;
  const a = charger({ publicite_joueur_tirer: () => { n++; return { ok: true, publicite: { titre: '<img src=x onerror=alert(1)>', texte: 'Soupe <b>chaude</b>', annonceur: 'Olga' } }; } });
  assert.equal(a.ctx.RP_ENCADRES_PIECE[0]('rue-centrale', 'rue', 'ville_b'), '');
  await new Promise(r => setImmediate(r));
  a.ctx.RP_ENCADRES_PIECE[0]('rue-centrale', 'rue', 'ville_b');
  await new Promise(r => setImmediate(r));
  assert.equal(n, 1);
  const html = a.ctx.ajoutes[0]._h;
  assert.doesNotMatch(html, /<img src=x|<b>chaude/);
  assert.match(html, /&lt;img src=x/);
});
