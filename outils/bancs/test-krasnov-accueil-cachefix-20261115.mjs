import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {test} from 'node:test';
const data=fs.readFileSync('data.js','utf8');
const html=fs.readFileSync('plateau.html','utf8');
const ctx=vm.createContext({});
vm.runInContext(data,ctx);
const center=vm.runInContext("WORLD.soviet.ville_b.buildingContext['centre-affaires']",ctx);
test('une nouvelle URL permet de contourner le cache de l ancienne scène',()=>{
 const room=center.roomOverrides.hall;
 assert.equal(room.imageUrl,'images/Sovarka/Krasnov/Krasnov_centre_affaires_accueil_20261115.webp');
 assert.equal(room.persons[0].photoUrl,'images/Sovarka/Krasnov/Krasnov_centre_affaires_hotesse_20261115.webp');
 assert.equal(room.cadrageIntegral,undefined);
 assert.match(html,/data\.js\?v=[^"]*krasnov-accueil-image-cachefix-20261115/);
 for (const path of [room.imageUrl,room.persons[0].photoUrl]) {
    const bytes=fs.readFileSync(path);
    assert.equal(bytes.toString('ascii',0,4),'RIFF');
    assert.equal(bytes.toString('ascii',8,12),'WEBP');
 }
 assert.equal(fs.existsSync('images/Sovarka/Krasnov/Krasnov_centre_affaires_accueil.webp'),false);
 assert.equal(fs.existsSync('images/Sovarka/Krasnov/Krasnov_centre_affaires_hotesse.webp'),false);
});
test('quatre bureaux conservés tels quels',()=>{
 const rooms=center.roomsExtra;
 assert.equal(Object.keys(rooms).length,4);
 assert.match(rooms.bureau_1.imageUrl,/bureau_maison_bleue\.webp/);
 assert.match(rooms.bureau_4.imageUrl,/bureau_hopital\.webp/);
});
