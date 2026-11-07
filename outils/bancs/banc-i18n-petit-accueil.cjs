'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const quest=fs.readFileSync(path.join(root,'plateau-quete-accueil.js'),'utf8');
const pnj=fs.readFileSync(path.join(root,'plateau-pnj.js'),'utf8');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
let locale='fr';
const window={RPPlateauI18n:{language:()=>locale}};
window.i18next={t:(key,{lng,player,defaultValue}={})=>{
 const value=key.split('.').reduce((v,k)=>v?.[k],window.RP_I18N_RESOURCES?.[lng]?.translation);
 return (value||defaultValue).replace('{{player}}',()=>player||'{{player}}');
}};
const vmctx=vm.createContext({window});
for(const file of ['resources.js','petit-accueil-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),vmctx);
vm.runInContext(quest,vmctx);
const examples={
 fr:['je suis nouveau','une question banale'],
 en:["I'm new here",'I like coffee'],
 es:['Soy nuevo en la ciudad','Me gusta el café'],
 'zh-TW':['我是新來的','我想喝咖啡'],
 ru:['Я новенький','Я люблю кофе'],
 ko:['새로 왔어요','커피를 마셔요'],
 ar:['أنا جديد هنا','أحب القهوة'],
 'pt-BR':['Sou novo aqui','Gosto de café'],
 de:['Ich bin neu hier','Ich mag Kaffee']
};
test('entrée de quête : reconnaissance dans la langue choisie, sans supprimer le français',()=>{
 assert.equal(Object.keys(window.RP_I18N_LANGUAGES).length,9);
 for(const [lng,[positive,negative]] of Object.entries(examples)){
  locale=lng;
  assert.equal(vm.runInContext('queteAccueilPhraseDeNouvelArrivant('+JSON.stringify(positive)+')',vmctx),true,lng+': arrivée');
  assert.equal(vm.runInContext('queteAccueilPhraseDeNouvelArrivant('+JSON.stringify(negative)+')',vmctx),false,lng+': pas de faux positif');
  assert.equal(vm.runInContext("queteAccueilPhraseDeNouvelArrivant('je suis nouveau')",vmctx),true,
   lng+': formulations historiques françaises toujours valides');
 }
 locale='fr';
 assert.equal(vm.runInContext("queteAccueilPhraseDeNouvelArrivant(\"I'm new here\")",vmctx),false,
  'pas de déclenchement anglais quand le joueur joue en français');
});
test('script de Petit et les deux choix visibles dans neuf langues sans modification des clics',()=>{
 const keys=['intro','accept','decline'];
 for(const lng of Object.keys(window.RP_I18N_LANGUAGES)){
  locale=lng;
  const data=window.RP_I18N_RESOURCES[lng].translation.petitAccueil;
  for(const key of keys)assert.ok(data[key]?.trim(),lng+': '+key);
  const message=window.RPPetitAccueilI18n.translated('intro','fallback',{player:'Arnie'});
  assert.ok(message.includes('Arnie'),lng);
  assert.ok(!message.includes('{{player}}'),lng);
 }
 assert.ok(pnj.includes('RPPetitAccueilI18n?.translated?'));
 assert.ok(pnj.includes('data-i18n="petitAccueil.accept"'));
 assert.ok(pnj.includes('data-i18n="petitAccueil.decline"'));
 assert.ok(pnj.includes('RPI18nPlateau.apply(document.getElementById'));
 assert.ok(pnj.includes('queteAccueilAccepterJeremy()'));
 assert.ok(pnj.includes('queteAccueilRefuserJeremy()'));
 assert.ok(quest.includes("state.char.queteAccueil = { etape: 'jeremy_groupe' }"));
 assert.ok(html.includes('i18n/petit-accueil-resources.js'));
});
