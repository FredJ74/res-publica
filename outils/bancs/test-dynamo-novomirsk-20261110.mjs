import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const ctx = vm.createContext({ console, window: {} });
vm.runInContext(read('data.js'), ctx);
const context = vm.runInContext('WORLD.soviet.capitale.buildingContext.stade', ctx);
const room = vm.runInContext('BUILDINGS.stade.rooms', ctx);
const inOtherCities = vm.runInContext(
  "[WORLD.republic.capitale, WORLD.republic.ville_a, WORLD.republic.ville_b, WORLD.soviet.ville_a, WORLD.soviet.ville_b].map(v=>v.buildingContext?.stade?.roomsExtra?.boutique?.imageUrl)", ctx);

const scenes = {
  terrain: 'terrain',
  vestiaires: 'vestiaire',
  buvette: 'buvette',
  guichet_paris: 'bookmaker',
  siege_supporters: 'club',
  boutique: 'boutique'
};
test('six WebP valides et aucun PNG source dans les six pieces', () => {
  for (const [piece, stem] of Object.entries(scenes)) {
    const expected = `images/Sovarka/Novomirsk/Novomirsk.stade.${stem}.webp`;
    const file = path.join(root, expected);
    assert.equal(piece === 'boutique' ? context.roomsExtra?.boutique?.imageUrl : context.roomOverrides?.[piece]?.imageUrl, expected);
    assert.equal(fs.existsSync(file), true, expected);
    const bytes = fs.readFileSync(file);
    assert.equal(bytes.toString('ascii',0,4),'RIFF');
    assert.equal(bytes.toString('ascii',8,12),'WEBP');
    assert.ok(bytes.length > 10000, expected);
    assert.equal(fs.existsSync(file.slice(0,-5)+'.png'), false, 'Ancien PNG encore present: '+file);
  }
});
test('bureau du président : illustration unique du Dynamo, conversion contrôlée et PNG supprimé', () => {
  const expected='images/Sovarka/Novomirsk/Novomirsk.stade.bureau président.webP';
  assert.equal(context.roomOverrides?.bureau_president?.imageUrl, expected);
  assert.equal(context.roomOverrides?.bureau_president?.name, 'Bureau du président du Dynamo');
  const webp=path.join(root,expected);
  assert.ok(fs.existsSync(webp),'WebP absent du repository');
  const bytes=fs.readFileSync(webp);
  assert.equal(bytes.toString('ascii',0,4),'RIFF');
  assert.equal(bytes.toString('ascii',8,12),'WEBP');
  assert.ok(bytes.length>10000);
  assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Novomirsk/Les cinq triomphes mondiaux du Dynamo Novomirsk.png')),false);
  assert.equal(room.bureau_president.imageUrl,'images/bureau-president-luthecia.webp',
    'Le gabarit des autres stades ne doit pas être modifié');
});

test('boutique uniquement pour le Dynamo, achats du socle et pas de copie dans les autres villes', () => {
  assert.ok(context.roomsExtra?.boutique);
  assert.deepEqual([...context.roomsExtra.boutique.orders.map(v=>v.fn)], [
    'choisir_accessoire_club', 'acheter_accessoire_personnalise'
  ]);
  assert.equal(inOtherCities.every(x=>x===undefined), true);
  assert.ok(context.roomOverrides.buvette.excludeOrders.includes('choisir_accessoire_club'));
  assert.ok(context.roomOverrides.siege_supporters.excludeOrders.includes('organiser_manifestation'));
  for (const key of ['terrain','vestiaires','buvette','guichet_paris','siege_supporters']) {
    assert.ok(room[key], 'Le gabarit partage doit garder la piece '+key);
  }
});
test('navigation et vente autorisees cote serveur pour le seul stade sovarkien',()=>{
  const sql = read('migrations/20261110000500_dynamo_boutique_accessoires.sql');
  assert.match(sql,/navigation_lieux_regles/);
  assert.match(sql,/pays='soviet' AND ville='capitale' AND batiment='stade'/);
  assert.match(sql,/a.country='soviet' AND a.current_city='capitale' AND a.current_room='boutique'/);
  assert.match(sql,/a.current_room IS DISTINCT FROM 'buvette'/);
  assert.match(read('plateau.html'),/data\.js\?v=[^"]*dynamo-six-images-20261110/);
});
