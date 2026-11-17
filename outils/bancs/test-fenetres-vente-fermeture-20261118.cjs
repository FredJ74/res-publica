'use strict';
// Règle des fenêtres de vente (Fred, 18/11/2026), pour tout le jeu : une vente réussie ferme la fenêtre
// avec un message de confirmation (pour revendre, on reclique sur l'ordre) ; un refus laisse la fenêtre
// ouverte et y affiche le motif. Fonctions réelles (extraites des fichiers du jeu), serveur simulé.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const acorn = require('../vercel/node_modules/acorn');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
function extraire(fichier, noms) {
  const src = lire(fichier);
  const corps = acorn.parse(src, { ecmaVersion: 'latest' }).body
    .filter(n => n.type === 'FunctionDeclaration' && noms.includes(n.id.name)).map(n => src.slice(n.start, n.end));
  assert.equal(corps.length, noms.length, fichier + ' : ' + noms.join(','));
  return corps.join('\n');
}
const AIDES = extraire('plateau-navigation.js', ['fermerModalPostes', 'venteReussieFermer', 'venteRefusDansFenetre']);

// DOM minimal : la fenêtre #modal-postes, son corps, et les champs de quantité.
function dom(valeurChamp) {
  const classes = new Set(['open']);
  const enfants = [];
  const corps = {
    prepend: e => enfants.unshift(e),
    querySelector: () => enfants.find(e => e.className === 'vente-refus') || null
  };
  const modal = { classList: { add: c => classes.add(c), remove: c => classes.delete(c), contains: c => classes.has(c) } };
  return {
    classes, enfants,
    document: {
      getElementById: id => id === 'modal-postes' ? modal : id === 'postes-body' ? corps : { value: valeurChamp },
      createElement: () => ({ setAttribute() {}, style: {}, className: '', textContent: '' })
    }
  };
}
function contexte(valeurChamp, extra) {
  const d = dom(valeurChamp), toasts = [];
  const ctx = vm.createContext(Object.assign({
    console, document: d.document, state: { country: 'soviet', currentCity: 'ville_a', char: { name: 'Fixture' } },
    showToast: (...a) => toasts.push(a), updateUI() {}, addJournalEntry() {}, renderInventory() {},
    RESSOURCES_ECONOMIE: { petrole: { label: 'Pétrole' } }, BUILDINGS: {}
  }, extra || {}));
  vm.runInContext(AIDES, ctx);
  return { ctx, d, toasts };
}
const ouverte = d => d.classes.has('open');
const bandeau = d => (d.enfants.find(e => e.className === 'vente-refus') || {}).textContent || '';

test('aides communes : succès = fenêtre fermée + confirmation ; refus = fenêtre ouverte + motif affiché', () => {
  let { ctx, d, toasts } = contexte();
  ctx.venteReussieFermer('Vente effectuée', '+8 PSK');
  assert.equal(ouverte(d), false); assert.equal(toasts[0][0], 'Vente effectuée'); assert.equal(toasts[0][2], true);
  ({ ctx, d, toasts } = contexte());
  ctx.venteRefusDansFenetre('Vente refusée', 'Stock plein.');
  assert.equal(ouverte(d), true); assert.equal(bandeau(d), 'Vente refusée : Stock plein.'); assert.equal(toasts[0][2], false);
  ctx.venteRefusDansFenetre('Vente refusée', 'Caisse vide.');
  assert.equal(d.enfants.length, 1, 'un seul bandeau, mis à jour'); assert.equal(bandeau(d), 'Vente refusée : Caisse vide.');
});

const usine = extraire('plateau-justice-economie.js', ['confirmerVendreMatierePremiereUsineUI']);
test('usines (raffinerie de Starovka comprise) : succès ferme sans rouvrir ; refus et saisie invalide gardent la fenêtre', async () => {
  for (const [reponse, attenduOuverte, motif] of [
    [{ ok: true, total: 8, qte: 2 }, false, null],
    [{ ok: false, raison: 'stock_plein' }, true, 'Le stock maximum de cette matière est atteint pour cette usine.'],
    [{ ok: false, raison: 'caisse_insuffisante' }, true, "L'usine ne peut pas acheter cette quantité actuellement."]]) {
    let rouverte = 0;
    const { ctx, d } = contexte('2', { vendreMatierePremiereUsine: async () => reponse, doOuvrirVendreMatierePremiereUsine: () => rouverte++ });
    vm.runInContext(usine, ctx);
    await ctx.confirmerVendreMatierePremiereUsineUI('usine-principale', 'petrole');
    assert.equal(ouverte(d), attenduOuverte); assert.equal(rouverte, 0, 'jamais rouverte');
    if (motif) assert.match(bandeau(d), new RegExp(motif.replace(/[.()]/g, '\\$&')));
  }
  const { ctx, d } = contexte('0', { vendreMatierePremiereUsine: async () => { throw new Error('ne doit pas être appelé'); } });
  vm.runInContext(usine, ctx);
  await ctx.confirmerVendreMatierePremiereUsineUI('usine-principale', 'petrole');
  assert.equal(ouverte(d), true); assert.equal(bandeau(d), 'Quantité invalide');
});

const medical = extraire('plateau-personnage.js', ['confirmerVendreRessourceMedicaleUI']);
test('structures médicales : même règle', async () => {
  for (const [reponse, attendu] of [[{ ok: true, total: 5, qte: 1 }, false], [{ ok: false, raison: 'stock_plein' }, true]]) {
    let rouverte = 0;
    const { ctx, d } = contexte('1', { vendreRessourceMedicaleStructure: async () => reponse, doOuvrirVendreRessourceMedicale: () => rouverte++ });
    vm.runInContext(medical, ctx);
    await ctx.confirmerVendreRessourceMedicaleUI('dispensaire', 'petrole');
    assert.equal(ouverte(d), attendu); assert.equal(rouverte, 0);
  }
});

const commerce = extraire('plateau-actions-illegales-rumeurs.js', ['texteVenteMatiere', 'confirmerVendreMatiereCommerceUI']);
test('commerces et marchés PNJ (vente et don) : succès ferme sans rouvrir ; refus garde la fenêtre avec le motif', async () => {
  for (const mode of ['vente', 'don']) for (const [reponse, attendu] of [[{ ok: true, total: 4, qte: 2 }, false], [{ ok: false, raison: 'stock_plein' }, true]]) {
    let rouverte = 0;
    const { ctx, d } = contexte('2', { window: {}, vendreMatiereCommerce: async () => reponse, doVendreMatiereCommerce: () => rouverte++ });
    vm.runInContext(commerce, ctx);
    await ctx.confirmerVendreMatiereCommerceUI('marche', 'marche', 'marche_ext', 'petrole', mode);
    assert.equal(ouverte(d), attendu, mode); assert.equal(rouverte, 0);
    if (attendu) assert.match(bandeau(d), /stock maximum/);
  }
});

const vehicule = extraire('plateau-vehicules.js', ['vehVendreMatiere']);
test('garages et stations-service : la fenêtre se ferme après une vente de matières, reste ouverte sur refus', async () => {
  for (const [reponse, attendu] of [[{ ok: true, qte: 3, total: 12 }, false], [{ ok: false, raison: 'stock_plein' }, true]]) {
    const { ctx, d } = contexte(null, { vehLireChamp: () => 3, commerceApporterMatiere: async () => reponse, VEH_MOTIFS: { stock_plein: 'Stock plein.' }, vehNombre: String, vehMonnaie: () => 'PSK' });
    vm.runInContext(vehicule, ctx);
    await ctx.vehVendreMatiere('garage-1', 'petrole');
    assert.equal(ouverte(d), attendu);
  }
});

// Les autres fenêtres de vente : même règle, vérifiée sur le code (le serveur est appelé avant toute fermeture).
test('aucune fenêtre de vente ne se ferme avant la réponse du serveur, et aucune ne se rouvre après un succès', () => {
  const flux = [
    ['plateau-justice-economie.js', 'confirmerVendreBoisImprimerie', 'venteReussieFermer'],
    ['plateau-actions-illegales-rumeurs.js', 'confirmerVenteMatiere', 'fermerModalPostes()'],
    ['plateau-commerce-pj.js', 'commercePjApporter', 'venteReussieFermer'],
    ['plateau-equipements.js', 'offreServir', 'fermerModalPostes()'],
    ['plateau-justice-economie.js', 'confirmerVenteMateriauxChantier', "classList.remove('open')"]
  ];
  for (const [fichier, nom, fermeture] of flux) {
    const c = extraire(fichier, [nom]);
    const appel = c.search(/await (sbRpc|sbRpcVerdict|executerReceptionInventaire|commerceApporterMatiere|sbFondsMatiereApporter)\(/);
    assert.ok(appel > 0, nom + ' : appel serveur');
    const avant = c.slice(0, appel);
    assert.doesNotMatch(avant, /classList\.remove\('open'\)|fermerModalPostes\(\)|venteReussieFermer\(/, nom + ' : fermée avant le serveur');
    assert.ok(c.slice(appel).includes(fermeture), nom + ' : fermée après succès');
    assert.doesNotMatch(c, /ouvrirOffresAchat\(\);\s*\n\}$|commercePjEcranMatieresPubliques\(\)/, nom + ' : rouverte');
  }
  assert.doesNotMatch(extraire('plateau-commerce-pj.js', ['commercePjApporter']), /referenceId/, 'variable inexistante retirée');
});
