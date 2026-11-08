import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { LANGUES, traduireTexte } from '../../api/_traduction.js';
const win={};vm.runInNewContext(fs.readFileSync(new URL('../../i18n/resources.js',import.meta.url),'utf8'),{window:win});
test('langues serveur et interface rigoureusement identiques',()=>{
 assert.deepEqual([...LANGUES],Object.keys(win.RP_I18N_LANGUAGES));
});
test('une traduction conserve strictement l original et les paramètres',async()=>{
 let calls=0;
 const provider=async request=>{calls++;assert.match(request.systeme,/untrusted/i);
  assert.equal(request.messages[0].content,'Salut {{name}}');
  return {ok:true,texte:'Hello {{name}}',tronque:false};};
 const r=await traduireTexte({texte:'Salut {{name}}',langueOriginale:'fr',langueCible:'en'},provider);
 assert.equal(r.ok,true);
 assert.equal(r.original,'Salut {{name}}');
 assert.equal(r.traduit,'Hello {{name}}');
 assert.equal(calls,1);
});
test('ne jamais accepter de remplacement ou disparition des placeholders',async()=>{
 const r=await traduireTexte({texte:'Bonjour {{name}}',langueOriginale:'fr',langueCible:'de'},
  async()=>({ok:true,texte:'Hallo {{nickname}}'}) );
 assert.equal(r.ok,false);assert.equal(r.original,'Bonjour {{name}}');
});
test('repli d origine sans appel fournisseur sur même langue, défaut et réponse tronquée',async()=>{
 let calls=0;const provider=async()=>{calls++;return {ok:true,texte:'Text',tronque:true};};
 const same=await traduireTexte({texte:'Bonjour',langueOriginale:'fr',langueCible:'fr'},provider);
 assert.equal(same.traduit,'Bonjour');assert.equal(calls,0);
 const bad=await traduireTexte({texte:'Bonjour',langueOriginale:'fr',langueCible:'xx'},provider);
 assert.equal(bad.ok,false);assert.equal(calls,0);
 const truncated=await traduireTexte({texte:'Bonjour',langueOriginale:'fr',langueCible:'en'},provider);
 assert.equal(truncated.ok,false);assert.equal(calls,1);
});


test('langue source indéterminée : traduction automatique sans supposer le français',async()=>{
 let invoked=0;
 const result=await traduireTexte({texte:'Hola {{name}}',langueOriginale:'und',langueCible:'de'},
  async req=>{invoked++;assert.match(req.systeme,/German/);assert.match(req.systeme,/never assume it is French/);
   assert.equal(req.messages[0].content,'Hola {{name}}');
   return {ok:true,texte:'Hallo {{name}}',tronque:false};});
 assert.equal(invoked,1);
 assert.equal(result.ok,true);
 assert.equal(result.langueOriginale,'und');
 assert.equal(result.traduit,'Hallo {{name}}');
});

test('P2-01: refuser changement de montant, de devise ou du nombre de PA, sans cache',async()=>{
 const source='Votre commande coûte 100 FR et 1 PA, {{name}}.';
 for(const text of [
  'Your order costs 1000 USD and 9 AP, {{name}}.',
  'Your order costs 100 FR and 9 PA, {{name}}.',
  'Your order costs 100 USD and 1 PA, {{name}}.',
  'Your order costs 1 FR and 100 PA, {{name}}.',
  'Your order costs 100 FR and 1 PA, {{name}}.\u0000'
 ]){
  const response=await traduireTexte({texte:source,langueOriginale:'fr',langueCible:'en'},
   async()=>({ok:true,texte:text,tronque:false}));
  assert.equal(response.ok,false,JSON.stringify(text));
  assert.equal(response.traduit,null);
  assert.equal(response.original,source);
  assert.equal(response.raison,'traduction_invalide');
 }
 const correct=await traduireTexte({texte:source,langueOriginale:'fr',langueCible:'en'},
  async()=>({ok:true,texte:'Your order costs 100 FR and 1 PA, {{name}}.',tronque:false}));
 assert.equal(correct.ok,true);
 assert.equal(correct.traduit,'Your order costs 100 FR and 1 PA, {{name}}.');
});
test('P2-01: refuser tout marqueur de contrôle dans la sortie fournisseur',async()=>{
 const source='Bienvenue sur le forum.';
 for(const char of ['\u0000','\u0007','\u001f']){
  const response=await traduireTexte({texte:source,langueOriginale:'fr',langueCible:'en'},
   async()=>({ok:true,texte:'Welcome to the forum.'+char,tronque:false}));
  assert.equal(response.ok,false);
 }
});
