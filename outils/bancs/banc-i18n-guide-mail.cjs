'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const markup=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const window={};
for(const file of ['resources.js','plateau-resources.js']) {
 vm.runInNewContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),{window});
}
const keys=['rulesIntro','rulesTutorial','rulesCharacter','rulesBoard',
 'rulesPolitics','rulesInteractions','rulesEconomy','rulesFootball',
 'rulesReligion','recipient','recipientPlaceholder'];

test('les neuf langues possèdent les titres du guide et les champs mail',()=>{
 const codes=Object.keys(window.RP_I18N_LANGUAGES);
 assert.equal(codes.length,9);
 for(const code of codes){
  const resources=window.RP_I18N_RESOURCES[code].translation.plateau;
  for(const key of keys) assert.ok(typeof resources[key]==='string' && resources[key].trim(),code+'/'+key);
 }
 assert.ok(window.RP_I18N_RESOURCES.fr.translation.plateau.rulesTutorial.startsWith('🎓'));
 assert.ok(window.RP_I18N_RESOURCES.fr.translation.plateau.rulesFootball.startsWith('⚽'));
});

test('les neuf onglets du guide gardent leur section et leur handler historique',()=>{
 const sections={intro:'rulesIntro',tuto:'rulesTutorial',personnage:'rulesCharacter',
  plateau:'rulesBoard',politique:'rulesPolitics',interactions:'rulesInteractions',
  economie:'rulesEconomy',sport:'rulesFootball',religion:'rulesReligion'};
 for(const [section,key] of Object.entries(sections)){
  const line=markup.split('\n').find(l=>l.includes('data-section="'+section+'"')&&l.includes('rules-tab'));
  assert.ok(line,'onglet absent '+section);
  assert.ok(line.includes('data-i18n="plateau.'+key+'"'),'clé manquante '+section);
  assert.ok(line.includes("renderRulesContent('"+section+"')"),'handler modifié '+section);
 }
});

test('inventaire, rue et courriel ajoutent seulement une clé texte',()=>{
 for(const key of ['noItems','streetHint','planTitle','recipient'])
  assert.ok(markup.includes('data-i18n="plateau.'+key+'"'),key);
 assert.match(markup,/<input\b[^>]*id="compose-mail-to"[^>]*data-i18n-placeholder="plateau\.recipientPlaceholder"/);
 assert.ok(markup.includes('onclick="fermerComposeMail()"'));
});


test('inventaire vide : le rendu dynamique réapplique la traduction sans toucher aux objets',()=>{
 const source=fs.readFileSync(path.join(root,'plateau-divers.js'),'utf8');
 const start=source.indexOf('function renderInventory() {');
 assert.ok(start>=0);
 const block=source.slice(start,start+700);
 assert.match(block,/data-i18n="plateau\.noItems"/);
 assert.match(block,/RPI18nPlateau\.apply\(el\)/);
 assert.match(block,/state\.inventory\.length === 0/);
});
