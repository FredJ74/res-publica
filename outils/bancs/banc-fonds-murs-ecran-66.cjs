// Banc écran du catalogue « Fonds et murs des commerces » (#66, 01/11/2026).
// L'écran n'invente rien : il affiche les prix rendus par le serveur, masque l'achat pendant la
// priorité d'un exploitant, envoie le prix affiché et UNE requête par acte (double clic sans
// double acte), et adopte argent/PA rendus par le serveur.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const src = fs.readFileSync(path.join(__dirname, '..', '..', 'plateau-justice-economie.js'), 'utf8');
const debut = src.indexOf('const FM_VILLES');
const fin = src.indexOf('async function doActeVenteTerrain');
assert.ok(debut > 0 && fin > debut, 'bloc fonds et murs introuvable');
const bloc = src.slice(debut, fin);

function titre(id, extra) {
  return Object.assign({
    id, ville: 'ville_b', libelle: 'Café de la Gare', surface: 550, prixReferenceMurs: 82500,
    murs: { proprietaire: 'commune', regime: 'reference', prix: 82500, vendable: true, statut: 'disponible' },
    fonds: { proprietaire: 'PNJ', regime: 'reference', prix: 180000, vendable: true, sousCompromis: false },
    ensemble: { vendable: true, prix: 262500 },
    moi: { proprioMurs: false, proprioFonds: false, prioritaire: false }
  }, extra || {});
}

function monter(reponses) {
  const el = {};
  const appels = [];
  const ctx = {
    console, appels, toasts: [], journal: [],
    state: { country: 'republic', char: { name: 'Arnie' }, arg: 1000000, liquide: 1000000, pa: 20 },
    COUNTRIES: { republic: { cur: 'FR' } },
    crypto: { randomUUID: (() => { let n = 0; return () => 'req-' + (++n); })() },
    document: { getElementById: id => (el[id] = el[id] || { textContent: '', innerHTML: '', value: '', classList: { add() {}, remove() {} } }) },
    showToast: function (a, b, ok) { ctx.toasts.push([a, b, ok]); },
    addJournalEntry: function (t) { ctx.journal.push(t); },
    updateUI: function () {},
    sbRpcVerdict: async function (fn, p) { appels.push([fn, p]); const r = reponses[fn]; return typeof r === 'function' ? r(p) : r; }
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(bloc + '\nthis.api={ouvrirCatalogueFondsMurs,afficherCatalogueFondsMurs,fmAction,fmAcheterConfirme,getTitres:()=>fmTitres};', ctx);
  return { ctx, el, api: ctx.api };
}

test('catalogue : prix du serveur affichés, boutons selon les droits', async () => {
  const prio = titre('t2', {
    libelle: 'Bar des Pêcheurs', ville: 'ville_a',
    murs: { proprietaire: 'Jean Jaaj', regime: 'libre', prix: 90000, vendable: true, statut: 'priorite', prioritaire: 'Angie Porcelana', prioriteJusque: Date.now() + 3600e3 },
    fonds: { proprietaire: 'Angie Porcelana', regime: 'libre', prix: null, vendable: false },
    ensemble: { vendable: false, prix: null }
  });
  const { api, el } = monter({ immobilier_catalogue: { ok: true, titres: [titre('t1'), prio], maintenant: Date.now() } });
  await api.ouvrirCatalogueFondsMurs();
  const html = el['postes-body'].innerHTML;
  assert.match(html, /82 ?500|82 500|82,500/);
  assert.match(html, /262/);
  assert.match(html, /Acheter les murs/);
  assert.match(html, /Acheter fonds \+ murs/);
  assert.ok(!/fmAction\(0,'acheter','fonds'\)/.test(html), 'un fonds PNJ seul ne s\'achète pas ici (compromis)');
  assert.match(html, /priorité de Angie Porcelana/);
  assert.ok(!/fmAction\(1,'acheter'/.test(html), 'un tiers ne peut pas acheter pendant la priorité');
});

test('achat : prix affiché envoyé, une seule requête au double clic, valeurs du serveur adoptées', async () => {
  let resoudre;
  const { api, ctx } = monter({
    immobilier_catalogue: { ok: true, titres: [titre('t1')], maintenant: Date.now() },
    immobilier_acheter: () => new Promise(r => { resoudre = r; })
  });
  await api.ouvrirCatalogueFondsMurs();
  api.fmAction(0, 'acheter', 'ensemble');
  const p1 = api.fmAcheterConfirme();
  const p2 = api.fmAcheterConfirme(); // double clic pendant l'attente
  await new Promise(r => setImmediate(r));
  resoudre({ ok: true, total: 262500, arg: 737500, liquide: 737500, pa: 19 });
  await p1; await p2;
  const achats = ctx.appels.filter(a => a[0] === 'immobilier_acheter');
  assert.strictEqual(achats.length, 1, 'un seul acte envoyé');
  assert.strictEqual(achats[0][1].p_prix_annonce, 262500);
  assert.strictEqual(achats[0][1].p_objet, 'ensemble');
  assert.ok(achats[0][1].p_requete);
  assert.strictEqual(ctx.state.arg, 737500);
  assert.strictEqual(ctx.state.pa, 19);
  assert.ok(ctx.toasts.some(t => t[0] === 'Acte signé !'));
});

test('refus nommé : rien n\'est adopté, aucun succès annoncé', async () => {
  const { api, ctx } = monter({
    immobilier_catalogue: { ok: true, titres: [titre('t1')], maintenant: Date.now() },
    immobilier_acheter: { ok: false, raison: 'fonds_insuffisants' }
  });
  await api.ouvrirCatalogueFondsMurs();
  api.fmAction(0, 'acheter', 'murs');
  await api.fmAcheterConfirme();
  assert.strictEqual(ctx.state.arg, 1000000);
  assert.strictEqual(ctx.state.pa, 20);
  assert.ok(ctx.toasts.some(t => t[0] === 'Acte refusé' && /ne suffisent pas/.test(t[1])));
  assert.ok(!ctx.toasts.some(t => t[0] === 'Acte signé !'));
});
