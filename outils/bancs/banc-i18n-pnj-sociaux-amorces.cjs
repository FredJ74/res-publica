'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const files=['i18n/resources.js','i18n/social-pnj-resources.js','plateau-social-pnj.js'];
const languages=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function load(lang,enabled,genre='H'){
  const window={RP_I18N_GAME_ENABLED:enabled,RPPlateauI18n:{language:()=>lang}};
  const context=vm.createContext({window,state:{char:{name:'Alix',stats:{genre}}}});
  for(const file of files)
    vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),context,{filename:file});
  return {context,window};
}
test('les amorces de Jean-Lou et Marine disposent de traductions dans les neuf langues',()=>{
  for(const lang of languages){
    const {context,window}=load(lang,true,'H');
    const words=window.RP_I18N_RESOURCES[lang]?.translation?.socialPnj;
    assert.ok(words?.jeanLou?.trim(),lang+' : Jean-Lou absent');
    assert.ok(words?.marine?.includes('{{name}}'),lang+' : variable du prénom absente');
    const jean=vm.runInContext('RP_SOCIAL_JALONS.abordage_deuxieme_visite.texte()',context);
    const marine=vm.runInContext("RP_SOCIAL_JALONS.accueil_premiere_visite.texte('Alix')",context);
    if(lang==='fr'){
      assert.equal(jean,"Alors moussaillon, on apprécie l'endroit ? C'est la deuxième fois que je vous vois venir ici.");
      assert.equal(marine,"Bonjour Monsieur Alix, bienvenue dans notre restaurant Capitaine Sauvage. N'ayez crainte, c'est le surnom de mon Papa, mais il est très gentil.");
    }else{
      assert.equal(jean,words.jeanLou,lang+' : amorce Jean-Lou');
      assert.equal(marine,words.marine.replace('{{name}}','Alix'),lang+' : amorce Marine');
      assert.ok(!marine.includes('{{name}}'),lang+' : interpolation non résolue');
    }
  }
});
test('les deux PNJ conservent les textes français exacts quand le plateau multilingue est fermé',()=>{
  for(const lang of languages){
    const {context}=load(lang,false,'F');
    assert.equal(vm.runInContext('RP_SOCIAL_JALONS.abordage_deuxieme_visite.texte()',context),
      "Alors moussaillon, on apprécie l'endroit ? C'est la deuxième fois que je vous vois venir ici.");
    assert.equal(vm.runInContext("RP_SOCIAL_JALONS.accueil_premiere_visite.texte('Alix')",context),
      "Bonjour Madame Alix, bienvenue dans notre restaurant Capitaine Sauvage. N'ayez crainte, c'est le surnom de mon Papa, mais il est très gentil.");
  }
});
test('clé inconnue : pas de traduction et aucun contenu de conversation joueur altéré',()=>{
  const {window}=load('ko',true);
  assert.equal(window.RPSocialPnjI18n.format('cle-inexistante',{name:'Alix'},'Original'),
    'Original');
  assert.equal(window.RPSocialPnjI18n.format('marine',{name:'X'},null),null);
});
