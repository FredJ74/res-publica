import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const root=new URL('../../',import.meta.url);
const read=p=>fs.readFileSync(new URL(p,root),'utf8');
const ctx=vm.createContext({});vm.runInContext(read('data.js'),ctx);
const b=vm.runInContext('BUILDINGS',ctx),city=vm.runInContext('WORLD.soviet.ville_b',ctx);
const rue=read('plateau-rue-centrale.js');
const source=read('data.js');
assert.ok(city.buildings.includes('tabac-presse-krasnov'));
assert.ok(city.buildings.includes('logements-krasnov-rue-tabac'));
assert.match(source,/imageUrl: 'images\/Sovarka\/Krasnov\/Krasnov_bar_sever_salle.webp'/);
assert.ok(city.buildingContext?.['cafe-tabac-cheminots-montrouge'] || source.includes("contexte('ville_b', 'cafe-tabac-cheminots-montrouge')"));
assert.equal(Object.keys(b['tabac-presse-krasnov'].rooms).join(','),'boutique');
// 14/11/2026 : quatre articles en vente (migration 20261114220000), ordres du moteur commun des commerces.
assert.equal(b['tabac-presse-krasnov'].rooms.boutique.orders.map(o=>o.fn).join(','),'faire_achats_marche,parier_match,produire_commerce,gerer_commerce,vendre_matiere_commerce');
const sourceBuilding=b['logements-krasnov-place-ours'],target=b['logements-krasnov-rue-tabac'];
assert.notEqual(sourceBuilding,target);
assert.equal(Object.keys(target.rooms).length,9);
assert.equal(Object.keys(sourceBuilding.rooms).length,9);
for (const [piece,room] of Object.entries(target.rooms)) {
  assert.ok(room.imageUrl, piece);
  assert.equal(room.imageUrl,sourceBuilding.rooms[piece].imageUrl,piece);
  if (piece!=='hall') {
    assert.ok(room.locationData.logementSocial);
    assert.equal(room.locationData.prix,piece.startsWith('petit')?10:20);
    assert.equal(room.orders.some(o=>o.fn==='gerer_logement_social'),true);
  }
}
const street=rue.slice(rue.indexOf("Z('krasnov-rue-tabac-bar'"),rue.indexOf("// Partie 2 du lot",rue.indexOf("Z('krasnov-rue-tabac-bar'")));
assert.match(street,/Bar Sever/);
assert.match(street,/Tabac\/Presse de Krasnov/);
assert.match(street,/logements-krasnov-rue-tabac/);
const hitboxes=Array.from(street.matchAll(/Z\('krasnov-rue-tabac-bar', \[(\d+), (\d+)\], '([^']+)', '([^']+)'(?:, \[(\d+), (\d+)\])?\);/g))
  .map(m=>({xMin:Number(m[1]),xMax:Number(m[2]),name:m[3],id:m[4],yMin:Number(m[5]??8),yMax:Number(m[6]??76)}));
const building=hitboxes.find(h=>h.id==='logements-krasnov-rue-tabac');
const tabac=hitboxes.find(h=>h.id==='tabac-presse-krasnov');
const bar=hitboxes.find(h=>h.id==='cafe-tabac-cheminots-montrouge');
assert.ok(building&&tabac&&bar);
assert.deepEqual([building.xMin,building.xMax],[58,78]);
assert.deepEqual([tabac.xMin,tabac.xMax],[79,100]);
assert.ok(bar.xMax < building.xMin,'Le bar ne doit pas masquer l immeuble');
assert.ok(building.xMax < tabac.xMin,'Le tabac ne doit pas être masqué par l immeuble');
assert.ok(building.yMin<=25 && building.yMax>=65,'La façade peinte doit être cliquable');
assert.ok(tabac.yMin<=40 && tabac.yMax>=70,'La devanture doit être cliquable');

const sql=read('migrations/20261114210000_krasnov_tabac_presse_immeuble.sql');
assert.match(sql,/logements-krasnov-rue-tabac/);
assert.doesNotMatch(sql,/DELETE FROM|TRUNCATE|DROP TABLE/i);
const images=[b['tabac-presse-krasnov'].rooms.boutique.imageUrl, 'images/Sovarka/Krasnov/Krasnov_bar_sever_salle.webp'];
for(const path of images) {
 const bytes=fs.readFileSync(new URL(path,root));
 assert.equal(bytes.toString('ascii',0,4),'RIFF',path);
 assert.equal(bytes.toString('ascii',8,12),'WEBP',path);
}
console.log('Krasnov : Bar Sever, tabac-presse, 8 logements indépendants, deux WebP OK');
