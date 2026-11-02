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
