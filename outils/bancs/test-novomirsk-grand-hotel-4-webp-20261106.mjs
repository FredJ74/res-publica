import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const ctx=vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8')+';this.world=WORLD;this.buildings=BUILDINGS;',ctx);
const hotel=ctx.world.soviet.capitale.buildingContext['hotel-republica'];
const map={
  accueil:'Novomirsk_Grand_Hotel_reception.webp',
  restaurant:'Novomirsk_Grand_Hotel_restaurant.webp',
  bar:'Novomirsk_Grand_Hotel_bar.webp',
  chambres:'Novomirsk_Grand_Hotel_chambre.webp'
};
const png={
  accueil:'Novomirsk_Grand Hotel_reception.png',
  restaurant:'Novomirsk_Grand Hotel_Restaurant.png',
  bar:'Novomirsk_Grand Hotel_bar.png',
  chambres:'Novomirsk_Grand Hotel_chambre.png'
};
test('quatre salles du Grand Hôtel de Novomirsk affichent chacune leur WebP',()=>{
  for(const [room,file] of Object.entries(map)){
    assert.ok(ctx.buildings['hotel-republica'].rooms[room],'salle manquante : '+room);
    const url=hotel.roomOverrides[room]?.imageUrl;
    assert.equal(url,'images/Sovarka/Novomirsk/'+file,room);
    const target=path.join(root,url);
    assert.ok(fs.statSync(target).size>100000,'WebP absent : '+file);
    assert.equal(fs.readFileSync(target).subarray(0,4).toString('ascii'),'RIFF','entête WebP');
    assert.equal(fs.readFileSync(target).subarray(8,12).toString('ascii'),'WEBP','signature WebP');
    assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Novomirsk',png[room])),false,'PNG non supprimé');
  }
});
test('les ordres et exclusions hôtel restent canoniques, les autres villes restent distinctes',()=>{
  assert.ok(hotel.roomsExclues.includes('suite_privee'));
  assert.ok(hotel.roomsExclues.includes('suite_presidentielle'));
  assert.ok(hotel.roomOverrides.accueil.excludeOrders.includes('choisir_suite'));
  assert.ok(ctx.buildings['hotel-republica'].rooms.accueil.orders.some(o=>o.fn==='reserver_chambre_hotel'));
  assert.ok(ctx.buildings['hotel-republica'].rooms.bar.orders.some(o=>o.fn==='offrir_tournee'));
  assert.ok(ctx.buildings['hotel-republica'].rooms.restaurant.orders.some(o=>o.fn==='diner_affaires'));
  assert.ok(ctx.buildings['hotel-republica'].rooms.chambres.orders.some(o=>o.fn==='dormir_chambre'));
  assert.ok(ctx.buildings['hotel-republica'].rooms.accueil.imageUrl !== hotel.roomOverrides.accueil.imageUrl);
  assert.ok(ctx.world.soviet.ville_a.buildingContext['hotel-republica']?.roomOverrides?.accueil?.imageUrl !== hotel.roomOverrides.accueil.imageUrl);
});
