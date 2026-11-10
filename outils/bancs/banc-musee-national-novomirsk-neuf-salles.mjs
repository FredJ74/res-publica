import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(root, f),'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('data.js'),ctx);
const monde = vm.runInContext('WORLD',ctx);
const socle = vm.runInContext("BUILDINGS['musee-national-republia']",ctx);
const local = monde.soviet.capitale.buildingContext['musee-national-republia'];
const images = {
  hall:['Accueil','accueil'],
  salle_presidents:['Salle des présidents','salle présidents'],
  salle_politiques:['Salle des partis politiques victorieux','salle partis'],
  salle_honneur_militaire_nationale:['Salle des honneurs militaires','salle des honneurs militaires'],
  salle_organisations:['Salle du tractorisme','salle tractorisme'],
  salle_artistes_sportifs:['Salle des sportifs de Sovarka','salle sportifs'],
  salle_civils_intellectuels:['Salle des artistes de Sovarka','salle artistes'],
  salle_grandes_villes:['Salle des grandes crises de Sovarka','salle crises'],
  expositions_temporaires:['Salle des expositions tournantes','salle expo tournantes']
};
test('Neuf salles de musée sovarkiennes sur identifiants existants', () => {
  assert.equal(Object.keys(local.roomOverrides).length, 9);
  assert.equal(local.roomsExclues.length, 3);
  for (const id of Object.keys(images)) {
    assert.ok(socle.rooms[id], 'salle inexistante du serveur : '+id);
    assert.equal(local.roomsExclues.includes(id),false);
    assert.equal(local.roomOverrides[id].name,images[id][0]);
  }
  for (const id of local.roomsExclues) assert.ok(socle.rooms[id]);
  assert.equal(Object.keys(socle.rooms).length-local.roomsExclues.length,9);
});
test('Chaque scène référence un WebP présent, sans PNG restant', () => {
  const prefix='images/Sovarka/Novomirsk/Novomirsk_musée national_';
  for (const [id,[,suffixe]] of Object.entries(images)) {
    const src=prefix+suffixe+'.webp';
    assert.equal(local.roomOverrides[id].imageUrl,src);
    const bytes=fs.readFileSync(path.join(root,src));
    assert.equal(bytes.toString('ascii',0,4),'RIFF');
    assert.equal(bytes.toString('ascii',8,12),'WEBP');
    assert.ok(bytes.length>100000);
    assert.ok(!fs.existsSync(path.join(root,prefix+suffixe+'.png')));
  }
});
test('Sovarka isolée, ressources audios françaises et visuels empruntés désactivés',()=>{
  assert.equal(local.imagesAVenir,true);
  assert.equal(local.audiosAVenir,true);
  assert.equal(monde.republic.capitale.buildingContext?.['musee-national-republia']?.roomOverrides?.hall?.imageUrl?.includes('Novomirsk'),undefined);
  assert.match(lire('plateau.html'),/data\.js\?v=[^"]*musee-national-sovarka-neuf-salles-20261110/);
});
