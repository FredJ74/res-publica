// Banc écran : clé d'unicité des achats (30/10/2026). Transport contrôlé, vraie aide
// executerReceptionInventaire et vraie adoption versionnée de supabase.js ; aucune connexion.
// Pendant serveur : outils/bancs/banc-achats-cle-unicite.sql (17 contrôles, transaction annulée).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const root = require('node:path').resolve(__dirname, '../..');
const lire = f => fs.readFileSync(root + '/' + f, 'utf8');
function extrait(file, start, end) { const s = lire(file), a = s.indexOf(start), b = s.indexOf(end, a); assert(a >= 0 && b > a); return s.slice(a, b); }
function monde(rpc) {
  const stockage = new Map(), appels = []; let nonce = 0;
  const c = vm.createContext({ state: { char: { name: 'Fixture' }, country: 'republic', currentCity: 'capitale', currentBuilding: 'entrepot', currentRoom: 'hall', inventory: [], _inventaireVersionne: true },
    rpAuthUid: () => 'fixture-uid', rpAuthSessionIdentifiant: () => 'fixture-session',
    sessionStorage: { getItem: k => stockage.get(k), setItem: (k, v) => stockage.set(k, v), removeItem: k => stockage.delete(k) }, crypto: { randomUUID: () => 'nonce-' + (++nonce) },
    showToast: (...a) => appels.push(['toast', ...a]), signalerRefusCout: v => appels.push(['refus', v]), updateUI: () => {}, appliquerPaiementServeur: v => appels.push(['paie', v]) });
  vm.runInContext(extrait('supabase.js', 'const RP_INVENTAIRE_ORIGINE =', '// Fusionne uniquement'), c);
  c.sbRpcVerdict = async (fn, p, opts) => { appels.push(['rpc', fn, p]); const o = c.sbContexteInventaire(); return c.sbMarquerInventaires(await rpc(fn, p, opts, c), o); };
  vm.runInContext(extrait('plateau-divers.js', 'const receptionsInventaireEnCours =', 'function addToInventory('), c);
  return { c, stockage, appels };
}
const succes = () => ({ ok: true, inventory: [{ id: 'bois', name: 'bois', qty: 2 }], revision: 3, paie: { pa: 9, liquide: 90 }, paye: 10 });
const rpcs = m => m.appels.filter(a => a[0] === 'rpc');

test('réponse perdue puis seconde tentative : la même clé est renvoyée', async () => {
  let k = 0; const m = monde(async () => ++k === 1 ? { ok: false, transport: { etat: 'reseau', envoyee: true } } : succes());
  const p = { p_acteur: 'Fixture', p_achats: { bois: 2 }, p_pa: 1, p_cost: 0 };
  assert.equal(await m.c.executerReceptionInventaire('acheter_a_entrepot', p), null);
  const v = await m.c.executerReceptionInventaire('acheter_a_entrepot', p);
  assert.equal(v.ok, true); const r = rpcs(m);
  assert.equal(r.length, 2); assert.ok(r[0][2].p_requete); assert.equal(r[0][2].p_requete, r[1][2].p_requete);
  assert.equal(m.stockage.size, 0, 'clé libérée seulement après confirmation');
});

test('achat confirmé : un nouvel achat reçoit une nouvelle clé', async () => {
  const m = monde(async () => succes());
  await m.c.executerReceptionInventaire('objet_acheter', { p_modele: 'gilet' });
  await m.c.executerReceptionInventaire('objet_acheter', { p_modele: 'gilet' });
  const r = rpcs(m); assert.notEqual(r[0][2].p_requete, r[1][2].p_requete);
});

test("refus nommé : affiché par l'écran appelant, pas de message générique, clé libérée", async () => {
  const m = monde(async () => ({ ok: false, raison: 'stock_insuffisant', disponible: 1 }));
  let vu = null;
  assert.equal(await m.c.executerReceptionInventaire('acheter_a_la_criee', {}, { surRefus: x => { vu = x; return true; } }), null);
  assert.equal(vu.raison, 'stock_insuffisant');
  assert.equal(m.appels.filter(a => a[0] === 'toast' || a[0] === 'refus').length, 0);
  assert.equal(m.stockage.size, 0);
});

test('refus non traité par l’appelant : message commun', async () => {
  const m = monde(async () => ({ ok: false, raison: 'requete_reutilisee' }));
  await m.c.executerReceptionInventaire('arme_acheter', {}, { surRefus: () => false });
  assert.ok(m.appels.some(a => a[0] === 'toast'));
});

test('rejeu : les soldes adoptés sont ceux relus, jamais ceux de la première réponse', async () => {
  const m = monde(async () => ({ ...succes(), rejeu: true, liquide: 999, paie: { pa: 9, liquide: 90 } }));
  await m.c.executerReceptionInventaire('crime_acheter_explosifs', {});
  const paies = m.appels.filter(a => a[0] === 'paie'); assert.equal(paies.length, 1); assert.equal(paies[0][1].liquide, 90);
});

// Raccordement : chaque achat passe par la clé, plus aucun appel direct sans clé, plus de PA séparés.
const sites = {
  'plateau-divers.js': ['objet_acheter'],
  'plateau-justice-economie.js': ['acheter_a_entrepot', 'acheter_vente_directe_usine', 'acheter_produit_manufacture', 'acheter_a_la_criee', 'imprimerie_acheter_bois'],
  'plateau-actions-illegales-rumeurs.js': ['arme_acheter', 'crime_acheter_arme_noire', 'crime_acheter_explosifs']
};
for (const [f, fns] of Object.entries(sites)) for (const fn of fns) test('raccordement ' + fn, () => {
  const s = lire(f);
  assert.ok(s.includes("executerReceptionInventaire('" + fn + "'"), 'passe par la clé');
  assert.ok(!new RegExp("sbRpc(Verdict)?\\('" + fn + "'").test(s), 'aucun appel direct sans clé');
});
test('PA de l’Entrepôt, de la Criée et de l’usine payés dans la même opération serveur', () => {
  const s = lire('plateau-justice-economie.js');
  for (const o of ['acheter_ressources_entrepot', 'acheter_criee', 'vente_directe_usine'])
    assert.ok(!s.includes("deduireCoutOrdre({ pa, cost, fn: '" + o + "' })"), o);
  const mig = lire('historique/migrations-appliquees/20261030180000_achats_cle_unicite.sql');
  for (const o of ['acheter_ressources_entrepot', 'acheter_criee', 'vente_directe_usine']) assert.ok(mig.includes("payer_ordre(p_acteur, '" + o + "'"), o);
});
