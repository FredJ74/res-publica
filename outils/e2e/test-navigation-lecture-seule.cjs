'use strict';
// Fixture structurelle : aucune authentification ni requete serveur.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const acorn=require('acorn');

test('la consultation authentifiee se termine avant les ordres de deplacement',()=>{
 const source=fs.readFileSync(path.join(__dirname,'luthecia.cjs'),'utf8');
 const ast=acorn.parse(source,{ecmaVersion:'latest'});
 assert.ok(ast.body.length>0);
 const debut=source.indexOf("if(conf.mode==='consultation_seule'){\n   await etape('consultation-position-existante'");
 const suivant=source.indexOf("await etape('office-notarial-entree'");
 assert.ok(debut>=0&&suivant>debut);
 const section=source.slice(debut,suivant);
 assert.match(section,/return rapport;/);
 assert.doesNotMatch(section,/\.aller\(|\.sortir\(|\.piece\(|rue_position_enregistrer/);
});

test('les controles policiers et de garde ne sont jamais traites comme lectures pures',()=>{
 const {decisionConsultation}=require('./consultation.cjs');
 const {configuration}=require('./luthecia.cjs');
 const uid='00000000-0000-4000-8000-000000000001';
 const env={HG_E2E_DECLENCHEMENT:'workflow_dispatch',HG_E2E_MODE:'consultation_seule',
  HG_E2E_PERSONNAGE:'Arnie',HG_E2E_UID:uid,HG_E2E_BASE_URL:'https://res-publica.vercel.app/',
  HG_E2E_EMAIL:'fixture@example.invalid',HG_E2E_PASSWORD:'fixture'};
 const conf=configuration(env);
 const jwt='factice.'+Buffer.from(JSON.stringify({sub:uid})).toString('base64url')+'.factice';
 for(const rpc of ['police_detection_verifier','garde_republicaine_controle','rue_position_enregistrer']){
  const resultat=decisionConsultation({
   url:conf.autorisation.backend+'/rest/v1/rpc/'+rpc,methode:'POST',
   corps:{},entetes:{authorization:'Bearer '+jwt}
  },conf,{uidValide:true,personnageValide:true});
  assert.equal(resultat.action,'bloquer',rpc);
 }
});
