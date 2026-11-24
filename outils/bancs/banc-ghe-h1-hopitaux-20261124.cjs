'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.1 : salle d'attente et chambre séparées dans TOUS les hôpitaux publics, en
// Sovarka et en Républia (modèle de Krasnov, point 30 du 23/11). Relu hôpital par hôpital sur le vrai data.js, avec la
// même résolution d'ordres que l'écran (ordresDeclaresDeLaPiece) :
//   • salle d'attente = visiteurs : ni transfert, ni repas, ni sortie ; plus de « Salle bondée » ;
//   • chambre = hospitalisés : dormir, repas, transfert (0 PA), sortir ;
//   • le serveur a la pièce « chambre » dans les six hôpitaux (migration 20261114130000) ; El Estado et Al-Khalija intacts.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
function jeu() {
  const ctx = { console, window: {}, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; ctx.globalThis = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W=WORLD;globalThis.__B=BUILDINGS;globalThis.__o=ordresDeclaresDeLaPiece;', ctx);
  return ctx;
}
const fns = l => Array.from(l || [], o => o.fn);
const HOPITAUX = [
  ['republic', 'capitale', 'dispensaire-public', 'salle_attente', 'Luthécia'], ['republic', 'ville_a', 'dispensaire-public-v', 'attente', 'Port-Sainte-Marie'],
  ['republic', 'ville_b', 'dispensaire-public-v', 'attente', 'Montrouge'], ['soviet', 'capitale', 'dispensaire-public', 'salle_attente', 'Novomirsk'],
  ['soviet', 'ville_a', 'dispensaire-public-v', 'attente', 'Starovka'], ['soviet', 'ville_b', 'dispensaire-public-v', 'attente', 'Krasnov']
];
const RESERVES = ['transfert_clinique_privee', 'repas_hopital', 'sortie_hopital'];

test('H.1 — six hôpitaux : salle d’attente des visiteurs, chambre des hospitalisés', () => {
  const c = jeu();
  for (const [pays, ville, bat, salle, nom] of HOPITAUX) {
    const h = c.__W[pays][ville].buildingContext[bat];
    const attente = fns(c.__o(c.__B[bat].rooms[salle], h, salle));
    for (const fn of RESERVES) assert.ok(!attente.includes(fn), nom + ' : ' + fn + ' encore dans la salle d’attente');
    assert.ok(attente.includes('centre_anti_poison'), nom + ' : centre antipoison');
    assert.ok(attente.includes('vendre_ressource_medicale'), nom + ' : fournir des ressources médicales');
    const desc = (h.roomOverrides[salle] && h.roomOverrides[salle].desc) || c.__B[bat].rooms[salle].desc;
    assert.doesNotMatch(desc, /bond[ée]e/i, nom + ' : « Salle bondée » supprimé');
    const chambre = h.roomsExtra.chambre.orders;
    assert.deepEqual(fns(chambre), ['dormir', 'repas_hopital', 'transfert_clinique_privee', 'sortie_hopital'], nom);
    assert.equal(chambre.find(o => o.fn === 'transfert_clinique_privee').pa, 0, nom + ' : transfert à 0 PA');
  }
  // Les hôpitaux hors consigne (El Estado, Al-Khalija) gardent leur salle d'attente.
  for (const pays of ['narco', 'khalija']) {
    const h = (c.__W[pays].ville_b.buildingContext || {})['dispensaire-public-v'] || {};
    assert.ok(fns(c.__o(c.__B['dispensaire-public-v'].rooms.attente, h, 'attente')).includes('sortie_hopital'), pays + ' inchangé');
  }
});

test('H.1 — le serveur conduit l’hospitalisé dans la chambre des six hôpitaux ; décision consignée à la source', () => {
  assert.match(lire('migrations/20261114130000_hopitaux_chambre_partout.sql'), /IF n <> 6/);
  const gd = lire('GAME-DESIGN-HOSPITALISATION.md');
  assert.match(gd, /24\/11\/2026[^\n]*H\.1/);
  assert.doesNotMatch(gd, /Les autres hôpitaux \(Starovka, Novomirsk, Républia\) gardent leur salle d'attente actuelle/);
});
