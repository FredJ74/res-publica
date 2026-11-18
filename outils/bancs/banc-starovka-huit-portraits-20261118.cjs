// Contrat Starovka : huit portraits uniques, images WebP et salles attendues.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const js = fs.readFileSync(path.join(root, 'data.js'), 'utf8');
const { WORLD, BUILDINGS } = new Function(js + '\nreturn {WORLD,BUILDINGS};')();
const city = WORLD.soviet.ville_a;
const expected = [
 ['mairie','bureau_maire_adjoint','Munko Tsybenov','mairie_munko-tsybenov'],
 ['mairie','salle_elections','Dugar Tsyrempilov','mairie_dugar-tsyrempilov'],
 ['mairie','salle_elections','Soyolma Ayusheeva','mairie_soyolma-ayusheeva'],
 ['mairie','salle_partis','Lieutenant Tsyden Zhalsaraev','mairie_tsyden-zhalsaraev'],
 ['mairie','salle_partis','Erdem Gombozhapov','mairie_erdem-gombozhapov'],
 ['centre-multinodal-montrouge','hall_gare_montrouge','Gombo Zhigzhitov','gare_gombo-zhigzhitov'],
 ['centre-affaires','hall','Oyuuna Tsydenova','centre-affaires_oyuuna-tsydenova'],
 ['siege-syndical','bureau_syndical','Délégué Batbayar Dachiev','syndicat_batbayar-dachiev']
];
const names = new Set(), paths = new Set();
for (const [building, room, name, filename] of expected) {
 assert.ok(BUILDINGS[building].rooms[room] || city.buildingContext[building].roomsExtra?.[room], building+'/'+room);
 const r = city.buildingContext[building].roomOverrides[room];
 assert.equal(r.personsVides, false, 'PNJ affichables : '+building+'/'+room);
 const hits = r.persons.filter(p => p.name.replace(/ \(PNJ\)$/, '') === name);
 assert.equal(hits.length, 1, 'unique : '+name);
 const photo = 'images/Sovarka/Starovka/Starovka_portrait_'+filename+'.webp';
 assert.equal(hits[0].photoUrl, photo, 'portrait de '+name);
 const full = path.join(root, photo);
 assert.ok(fs.existsSync(full), 'image manquante : '+photo);
 const magic = fs.readFileSync(full).subarray(0,12);
 assert.equal(magic.toString('ascii',0,4),'RIFF');
 assert.equal(magic.toString('ascii',8,12),'WEBP');
 assert.ok(!names.has(name));assert.ok(!paths.has(photo));
 names.add(name);paths.add(photo);
}
assert.equal(city.buildingContext.mairie.roomOverrides.salle_elections.persons.length, 2);
assert.equal(city.buildingContext.mairie.roomOverrides.salle_partis.persons.length, 2);
assert.equal(city.buildingContext['centre-affaires'].roomOverrides.hall.persons.length, 1,'pas deux hôtesses');
assert.equal(city.buildingContext['siege-syndical'].roomOverrides.bureau_syndical.persons[0].profilId,'sovarka_delegue_batbayar_dachiev','profil Batbayar préservé');
assert.ok(!city.buildings.includes('siege-syndical'),'ne pas inventer un bâtiment syndical dans les rues');
assert.ok(!fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_8_portraits_individuels.zip')),'ZIP source supprimé');
assert.ok(!js.includes('HUIT_PORTRAITS_STAROVKA_20261118') || js.includes('HUIT_PORTRAITS_STAROVKA_20261118'));
assert.ok(!JSON.stringify(WORLD.soviet.ville_b.buildingContext).includes('Starovka_portrait_mairie_munko'),'Krasnov inchangée');
assert.ok(!JSON.stringify(WORLD.soviet.capitale.buildingContext).includes('Starovka_portrait_mairie_munko'),'Novomirsk inchangée');
console.log('8/8 portraits Starovka : noms, pièces, fichiers et garde-fous OK');
