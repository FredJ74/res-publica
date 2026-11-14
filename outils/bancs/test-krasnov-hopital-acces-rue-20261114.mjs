// Krasnov : navigation bureaux → hôpital (droite), hôpital → bureaux (bas).
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const lire=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const s=lire('plateau-rue-centrale.js');
const start=s.indexOf("'krasnov-rue-bureaux':");
const end=s.indexOf("'krasnov-rue-descendante':",start);
assert.ok(start>0 && end>start,'scènes attendues');
const scene=s.slice(start,end);
assert.match(scene,/droite: 'krasnov-rue-hopital'/);
assert.match(scene,/'krasnov-rue-hopital':/);
assert.match(scene,/image: 'images\/Sovarka\/Krasnov\/Krasnov_hopital_rue.webp'/);
assert.match(scene,/nom: 'Hôpital public de Krasnov', type: 'batiment', buildingId: 'dispensaire-public-v'/);
assert.match(scene,/liens: \{ arriere: 'krasnov-rue-bureaux' \}/);
assert.match(scene,/flechesStyle: \{ arriere: RC_FLECHE_BAS \}/);
assert.equal((scene.match(/buildingId: 'dispensaire-public-v'/g)||[]).length,1);
const sql=lire('migrations/20261114115500_krasnov_hopital_acces_rue.sql');
assert.match(sql,/pays='soviet' AND ville='ville_b'/);
assert.match(sql,/VALUES \('soviet','ville_b','krasnov-rue-hopital'/);
assert.match(sql,/droite.*krasnov-rue-hopital/);
assert.match(sql,/arriere.*krasnov-rue-bureaux/);
const ctx=vm.createContext({});
vm.runInContext(lire('data.js'),ctx);
const ch=vm.runInContext("WORLD.soviet.ville_b.buildingContext['dispensaire-public-v'].roomsExtra.chambre",ctx);
assert.ok(ch && ch.orders.some(o=>o.fn==='dormir') && ch.orders.some(o=>o.fn==='repas_hopital'));
const kr=vm.runInContext("WORLD.soviet.ville_b.buildingContext['dispensaire-public-v']",ctx);
assert.equal(kr.roomOverrides.attente.imageUrl,'images/Sovarka/Krasnov/Krasnov_hopital_accueil.webp');
assert.equal(kr.roomOverrides.ehpad.imageUrl,'images/Sovarka/Krasnov/Krasnov_hopital_EPHAD.webp');
assert.equal(ch.imageUrl,'images/Sovarka/Krasnov/Krasnov_hopital_chambre.webp');
const starovka=vm.runInContext("WORLD.soviet.ville_a.buildingContext['dispensaire-public-v'].roomsExtra.chambre",ctx);
assert.notEqual(starovka.imageUrl,ch.imageUrl,'Starovka conserve sa chambre');
const images=[
  'images/Sovarka/Krasnov/Krasnov_hopital_rue.webp',
  kr.roomOverrides.attente.imageUrl,
  ch.imageUrl,
  kr.roomOverrides.ehpad.imageUrl
];
for(const path of images) {
  const file=new URL('../../'+path,import.meta.url);
  assert.ok(fs.existsSync(file),'Asset WebP absent : '+path);
  const header=fs.readFileSync(file).subarray(0,12);
  assert.equal(header.toString('ascii',0,4),'RIFF',path+' : conteneur RIFF');
  assert.equal(header.toString('ascii',8,12),'WEBP',path+' : conteneur WebP');
}
console.log('Krasnov : parcours et quatre images WebP conformes');
