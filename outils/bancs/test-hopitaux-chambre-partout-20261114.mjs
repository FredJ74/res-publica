// Chambre d'hôpital uniforme (Fred, 14/11/2026) : les six hôpitaux publics de Républia et de Sovarka ont la
// pièce « chambre » avec Dormir, repas de l'hôpital et transfert en clinique privée ; le serveur y conduit
// tout personnage tombé à 0 PA (migration 20261114130000, vérifiée en base pour les six villes).
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const lire = f => fs.readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('data.js'), ctx);
const villes = [['republic', 'capitale', 'dispensaire-public'], ['republic', 'ville_a', 'dispensaire-public-v'], ['republic', 'ville_b', 'dispensaire-public-v'],
  ['soviet', 'capitale', 'dispensaire-public'], ['soviet', 'ville_a', 'dispensaire-public-v'], ['soviet', 'ville_b', 'dispensaire-public-v']];
const reference = JSON.stringify(vm.runInContext('CHAMBRE_HOPITAL_ORDRES()', ctx));
for (const [pays, ville, bat] of villes) {
  const ch = vm.runInContext(`WORLD.${pays}.${ville}.buildingContext?.['${bat}']?.roomsExtra?.chambre`, ctx);
  assert.ok(ch, `${pays} ${ville} : chambre absente`);
  assert.equal(ch.name, "Chambre d'hôpital");
  assert.deepEqual(Array.from(ch.orders, o => [o.fn, o.pa, o.cost]),
    [['dormir', 0, 0], ['repas_hopital', 1, 0], ['transfert_clinique_privee', 0, 1000]], `${pays} ${ville}`);
  assert.equal(JSON.stringify(ch.orders), reference, `${pays} ${ville} : mêmes ordres et mêmes textes partout`);
  assert.ok(fs.existsSync(new URL('../../' + ch.imageUrl, import.meta.url)), `${pays} ${ville} : image ${ch.imageUrl}`);
}
// Textes repris du socle, déjà traduits.
const communes = lire('i18n/infobulles-communes-resources.js');
assert.ok(communes.includes('Meilleure prise en charge, convalescence plus rapide. 1000 FR.'));
assert.ok(communes.includes('Réservé aux patients hospitalisés, une fois par jour. +2 PA à votre prochain sommeil.'));
const sql = lire('migrations/20261114130000_hopitaux_chambre_partout.sql');
assert.match(sql, /ville = 'capitale' AND batiment = 'dispensaire-public'/);
assert.match(sql, /ville = 'ville_a' AND batiment = 'dispensaire-public-v'/);
assert.match(sql, /IF n <> 6/);
assert.match(lire('plateau-router.js'), /fn === 'transfert_clinique_privee'/);
console.log('test-hopitaux-chambre-partout-20261114 : OK');
