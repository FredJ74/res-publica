'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'../..');
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
const profiles=fs.readFileSync(path.join(root,'api/_pnj-personnalites.js'),'utf8');
const sql=fs.readFileSync(path.join(root,'migrations/20261103010000_montrouge_ssm_bureau.sql'),'utf8');
const start=data.indexOf("  'services-sociaux-montrouge': {",data.indexOf("const BUILDINGS"));
const end=data.indexOf("\n  'parking-tribunal-montrouge':",start);
const block=data.slice(start,end);
test('images des deux pièces présentes, noms et rôles du personnel distincts',()=>{
 assert.ok(start>=0&&end>start);
 for(const [room,file,name] of [
  ['accueil','montrouge-ssm-accueil.png','Pascale (PNJ)'],
  ['bureau_assistante_sociale','montrouge-ssm-bureau.png','Edwige Jacquard (PNJ)']]){
  assert.match(block,new RegExp(room+':\\s*\\{'));
  assert.ok(fs.existsSync(path.join(root,'images/montrouge',file)),file+' absent');
  assert.ok(block.includes("images/montrouge/"+file));
  assert.ok(block.includes(name));
 }
 assert.match(block,/role:'Assistante sociale'/);
 assert.match(block,/role:'Agente d’accueil des services sociaux'/);
});
test('rendez-vous et demande de logement social sont les seuls ordres des deux pièces',()=>{
 assert.equal((block.match(/orders: \[/g)||[]).length,2);
 assert.equal((block.match(/persons: \[/g)||[]).length,2);
 assert.match(block,/fn:'ssm_demander_rendezvous'/);
 assert.match(block,/fn:'demander_logement_social'/);
});
test('les deux profils PNJ sont raccordables par identifiant serveur',()=>{
 assert.match(profiles,/'pascale':\s*\{\s*nom:\s*"Pascale"/);
 assert.match(profiles,/'edwige_jacquard':\s*\{\s*nom:\s*"Edwige Jacquard"/);
 assert.match(profiles,/const ORDINAIRES = \{/);
});
test('navigation serveur limitée au nouveau bureau, sans modifier les positions PJ',()=>{
 assert.match(sql,/bureau_assistante_sociale/);
 assert.match(sql,/navigation_lieux_regles/);
 assert.doesNotMatch(sql,/UPDATE\s+public\.personnages|DELETE\s+FROM\s+public\.personnages/i);
 assert.doesNotMatch(sql,/services-sociaux-montrouge.*parking-tribunal-montrouge/);
});

test('Edwige oriente sur les soins sans inventer de prestations',()=>{
 const profileStart=profiles.indexOf("'edwige_jacquard': {");
 const profileEnd=profiles.indexOf("\n  },",profileStart);
 assert.ok(profileStart>=0&&profileEnd>profileStart);
 const fiche=profiles.slice(profileStart,profileEnd);
 for(const mot of ['dispensaire','gratuitement','0 PA','J0','J1','J2','20 PA','1 000 FR','30 FR','empoisonnement']){
   assert.ok(fiche.includes(mot),'information manquante : '+mot);
 }
 assert.match(fiche,/sans prétendre fournir toi-même de soins/);
});
