// Krasnov : galerie, quatre locaux indépendants, deux états et images optimisées.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const root = new URL('../../',import.meta.url);
const lire = p => fs.readFileSync(new URL(p,root),'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('data.js'),ctx);
const comm=vm.runInContext("WORLD.soviet.ville_b.buildingContext['centre-commercial']",ctx);
const pieces=['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve'];
assert.equal(comm.roomOverrides.hall.imageUrl,'images/Sovarka/Krasnov/Krasnov_centre_commercial_hall.webp');
assert.equal(comm.roomOverrides.hall.persons.length,0);
for(let i=0;i<4;i++){
  const room=comm.roomOverrides[pieces[i]];
  assert.match(room.name,/Box commercial/);
  assert.equal(room.imageUrl,`images/Sovarka/Krasnov/Krasnov_centre_commercial_box_${i+1}_libre.webp`);
}
const fichier=lire('plateau-variantes-pieces.js');
assert.match(fichier,/PIECE_VARIANTES\.soviet\.ville_b\['centre-commercial'\] = Object\.fromEntries/);
assert.match(fichier,/famille: 'location'/);
assert.match(fichier,/occupee: 'images\/Sovarka\/Krasnov\/Krasnov_centre_commercial_box_occupe_freemium.webp'/);
assert.match(fichier,/enseigne: Object\.assign\(\{\}, ENSEIGNE_FRONTON_LUTHECIA/);
const images=[comm.roomOverrides.hall.imageUrl,...pieces.map(p=>comm.roomOverrides[p].imageUrl),
  'images/Sovarka/Krasnov/Krasnov_centre_commercial_box_occupe_freemium.webp'];
for(const p of images){
 const b=fs.readFileSync(new URL(p,root));
 assert.equal(b.toString('ascii',0,4),'RIFF',p);
 assert.equal(b.toString('ascii',8,12),'WEBP',p);
}
const source=fs.readdirSync(new URL('images/Sovarka/Krasnov/',root));
assert.equal(source.filter(n=>/Image ChatGPT 14 nov\. 2026, 16_57_.*\.png/.test(n)).length,0);
assert.equal(source.filter(n=>/Galerie commerciale.*\.png|[ÉE]picerie sovi.*\.png/i.test(n)).length,0);
assert.match(lire('data.js'),/Box commercial 4/);
assert.ok(!vm.runInContext("WORLD.soviet.capitale.buildingContext['centre-commercial'].roomOverrides.hall.imageUrl",ctx).includes('Krasnov'));
console.log('Krasnov : galerie, quatre box libres, freemium occupé et WebP : OK');
