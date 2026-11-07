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
 'rulesReligion','recipient','recipientPlaceholder','subjectPlaceholder','messagePlaceholder'];

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
 assert.match(markup,/<input\b[^>]*id="compose-mail-subject"[^>]*data-i18n-placeholder="plateau\.subjectPlaceholder"/);
 assert.match(markup,/<textarea\b[^>]*id="compose-mail-body"[^>]*data-i18n-placeholder="plateau\.messagePlaceholder"/);
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


test('les boutons communs restent cliquables, localisés et conservent leurs icônes',()=>{
 const codes=Object.keys(window.RP_I18N_LANGUAGES);
 const labels=['closeButton','exitButton','sendButton','backHomeTitle'];
 for(const code of codes){
  const words=window.RP_I18N_RESOURCES[code].translation.plateau;
  for(const key of labels)assert.ok(words[key]?.trim(),code+'/'+key);
 }
 for(const handler of ['closeSelfView','closeRulesView','closeForumView','closeMailView']){
  const rx=new RegExp('<button[^>]*onclick="'+handler+'\\(\\)"[^>]*>\\s*<i[^>]+><\\/i>\\s*<span data-i18n="plateau\\.closeButton">Fermer<\\/span>');
  assert.match(markup,rx,handler);
 }
 assert.match(markup,/onclick="sortirBatiment\(\)"[^>]*>\s*<i[^>]+><\/i>\s*<span data-i18n="plateau\.exitButton">Sortir<\/span>/);
 assert.match(markup,/onclick="envoyerComposeMail\(\)"[^>]*>[\s\S]{0,180}<span data-i18n="plateau\.sendButton">Envoyer<\/span>/);
 assert.match(markup,/data-i18n-title="plateau\.backHomeTitle"/);
});


test('menu mobile : 3 commandes historiques et libellé vocal en neuf langues',()=>{
 const names={personnage:'mobileCharacter',personnes:'mobilePresent',menu:'mobileMenu'};
 for(const code of Object.keys(window.RP_I18N_LANGUAGES)){
  const dict=window.RP_I18N_RESOURCES[code].translation.plateau;
  for(const key of [...Object.values(names),'mobileClosePanel'])
   assert.ok(dict[key]?.trim(),code+'/'+key);
 }
 for(const [panel,key] of Object.entries(names)){
  const line=markup.split('\n').find(l=>l.includes('data-hg-panneau="'+panel+'"'));
  assert.ok(line,'missing mobile panel '+panel);
  assert.ok(line.includes('data-i18n="plateau.'+key+'"'),'not localised '+panel);
  assert.ok(line.includes('aria-expanded="false"'),'ARIA missing '+panel);
 }
 assert.match(markup,/id="hg-mobile-fond"[^>]*aria-label="Fermer le panneau"[^>]*data-i18n-aria-label="plateau\.mobileClosePanel"/);
 assert.match(markup,/src="plateau-mobile\.js[^"]*" defer/);
});
