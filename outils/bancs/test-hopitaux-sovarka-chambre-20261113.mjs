// Chambres des hôpitaux de Sovarka (Fred, 13/11/2026) : Dormir et repas dans la chambre, à Novomirsk,
// Starovka et Krasnov ; rien en Républia.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const lire = f => fs.readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('data.js'), ctx);
for (const [ville, bat] of [['capitale', 'dispensaire-public'], ['ville_a', 'dispensaire-public-v'], ['ville_b', 'dispensaire-public-v']]) {
  const ch = vm.runInContext(`WORLD.soviet.${ville}.buildingContext['${bat}'].roomsExtra.chambre`, ctx);
  assert.equal(JSON.stringify(ch.orders.map(o => o.fn)), '["dormir","repas_hopital"]', ville);
  assert.equal(ch.orders.find(o => o.fn === 'dormir').pa, 0, 'Dormir sans PA : le patient arrive à 0 PA');
  assert.ok(fs.existsSync(new URL('../../' + ch.imageUrl, import.meta.url)), ville + ' image');
}
// Depuis le 14/11, Montrouge possède sa chambre propre. Les autres villes de Républia
// restent inchangées ; la vérification de Montrouge est dans son banc dédié.
for (const ville of ['capitale', 'ville_a'])
  for (const bat of ['dispensaire-public', 'dispensaire-public-v'])
    assert.equal(vm.runInContext(`WORLD.republic.${ville}?.buildingContext?.['${bat}']?.roomsExtra?.chambre`, ctx), undefined, 'Autres villes de Républia inchangées');
assert.match(lire('i18n/sovarka-ordres-resources.js'), /"dormir":"Sleep"/);
assert.match(lire('migrations/20261113020000_hopitaux_sovarka_chambre.sql'), /hopital_chambre_sovarka_v1/);
console.log('test-hopitaux-sovarka-chambre-20261113 : OK');
