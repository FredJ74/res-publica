import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const ctx=vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8')+';this.world=WORLD;this.buildings=BUILDINGS;',ctx);
const nov=ctx.world.soviet.capitale.buildingContext;
const rooms={
 'commissariat': {
   accueil_police:'Novomirsk_Commissariat_acceuil.webp',
   prison:'Novomirsk_commissariat_geoles.webp',
   bureau_commissaire:'Novomirsk_commissariat-bureau.webp'
 },
 'office-notarial':{accueil_notaire:'Novomirsk_notaire_accueil.webp'}
};

test('Quatre pièces Novomirsk utilisent exactement les quatre nouvelles images',()=>{
 for(const [building,parts] of Object.entries(rooms)){
   for(const [room,file] of Object.entries(parts)){
     const def=nov[building]?.roomOverrides?.[room];
     assert.ok(def,building+'/'+room);
     assert.equal(def.imageUrl,'images/Sovarka/Novomirsk/'+file);
     const output=path.join(root,def.imageUrl);
     assert.ok(fs.statSync(output).size>100);
     assert.equal(fs.existsSync(output.slice(0,-5)+'.png'),false);
     assert.ok(ctx.buildings[building].rooms[room],building+'/'+room+' : socle manquant');
   }
 }
});

test('Klara, Matrakov et Vassili : noms, profils et vrais portraits découpés',()=>{
 const expected=[
  ['office-notarial','accueil_notaire','Klara Delounova (PNJ)','Novo_klara_delounova_portrait.webp'],
  ['commissariat','accueil_police','Sergent Matrakov (PNJ)','Novo_sergent_matrakov_portrait.webp'],
  ['commissariat','bureau_commissaire','Vassili Ordonov (PNJ)','Novo_vassili_ordonov_portrait.webp']
 ];
 for(const [b,r,name,file] of expected){
  const people=nov[b].roomOverrides[r].persons;
  const matches=people.filter(p=>p.name===name);
  assert.equal(matches.length,1,'identité '+name);
  const npc=matches[0];
  assert.ok(npc.profilId,'profil conversation '+name);
  assert.equal(npc.photoUrl,'images/Sovarka/Novomirsk/'+file);
  assert.ok(fs.statSync(path.join(root,npc.photoUrl)).size>100);
 }
 assert.equal(nov['commissariat'].roomOverrides.accueil_police.persons.length,1);
 // Décision de Fred (06/11) : le commissaire seul dans son bureau, plus d'inspectrice.
 assert.equal(nov['commissariat'].roomOverrides.bureau_commissaire.persons.length,1);
 assert.ok(!nov['commissariat'].roomOverrides.bureau_commissaire.persons.some(p=>/Menott/.test(p.name)));
 // Décision de Fred (06/11) : la secrétaire seule à l'accueil, sous le nom de l'ancienne clerc.
 assert.equal(JSON.stringify(nov['office-notarial'].roomOverrides.accueil_notaire.persons.map(p=>p.name+' — '+p.role)),JSON.stringify(['Klara Delounova (PNJ) — Secrétaire']));
});

test('Socles partagé et autres villes non modifiés',()=>{
 const republic=ctx.world.republic.capitale;
 assert.equal(republic.buildingContext['office-notarial'].roomOverrides.accueil_notaire.imageUrl,'images/accueil-notaire-luthecia.webp');
 assert.equal(ctx.buildings['commissariat'].rooms.accueil_police.imageUrl,'images/commissariat-accueil.webp');
 assert.ok(ctx.world.soviet.ville_a.buildingContext['commissariat']?.roomOverrides?.accueil_police?.imageUrl !== nov.commissariat.roomOverrides.accueil_police.imageUrl);
});
