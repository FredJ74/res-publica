'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.join(__dirname,'../..');
const quest=fs.readFileSync(path.join(root,'plateau-quete-accueil.js'),'utf8');
const page=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const win={};
let locale='fr';
win.RPPlateauI18n={language:()=>locale};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((x,k)=>x?.[k],win.RP_I18N_RESOURCES?.[lng]?.translation)??defaultValue};
const sandbox=vm.createContext({window:win});
for(const file of ['resources.js','jeremy-scenes-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),sandbox,{filename:file});
const keys=['welcomeJeremy','hotelInstructions','sleepInstructions','hotelRoom','barIntroduction','clinic','electionRoom','stadium','turnLeft','keepDirection','selectBuilding','routeStadium','exploreStadium','bedroomSleepOrder','partWays','careerChoice','contactsTip','contactJeremy','localForumInvite','returnEmployees','rememberElections','goElections','leaveTownHall','openCharacterSheet','returnHotel','toBar','askDrink','returnStadium','tryStadium','sayGoodbyeAgain'];
test('trente scènes réelles traduites en neuf langues avec exactement la ponctuation de guidage',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  locale=lng;
  const dict=win.RP_I18N_RESOURCES[lng].translation.jeremyScenes;
  assert.deepEqual(Object.keys(dict).sort(),keys.slice().sort());
  for(const key of keys){
   assert.ok(dict[key].trim(),lng+': '+key);
   const original=win.RP_I18N_RESOURCES.fr.translation.jeremyScenes[key];
   assert.equal(win.RPJeremyScenesI18n.label(key,original),dict[key],lng+': '+key);
   assert.ok(!/<(?!br\s*\/?\s*>)/i.test(dict[key]),lng+': interdiction du HTML tiers');
  }
  assert.equal((dict.hotelInstructions.match(/<br><br>/g)||[]).length,1,lng+': séparation des deux paragraphes');
  assert.equal((dict.sleepInstructions.match(/<br><br>/g)||[]).length,1,lng+': sommeil en deux paragraphes');
  assert.equal((dict.barIntroduction.match(/<br><br>/g)||[]).length,2,lng+': bar en trois paragraphes');
  assert.equal((dict.clinic.match(/<br><br>/g)||[]).length,2,lng+': dispensaire en trois paragraphes');
  assert.equal((dict.electionRoom.match(/<br><br>/g)||[]).length,3,lng+': élections en quatre paragraphes');
  assert.equal((dict.stadium.match(/<br><br>/g)||[]).length,5,lng+': stade en six paragraphes');
  assert.equal((dict.routeStadium.match(/<br><br>/g)||[]).length,2,lng+': itinéraire en trois paragraphes');
  assert.equal((dict.partWays.match(/<br><br>/g)||[]).length,1,lng+': séparation avec Jérémy en deux paragraphes');
  assert.equal((dict.localForumInvite.match(/<br><br>/g)||[]).length,2,lng+': invitation forum en trois paragraphes');
 }
});
test('les transitions et ordres ne dépendent pas des traductions',()=>{
 for(const key of keys)assert.ok(quest.includes("rpQueteTexte('"+key+"'"),key);
 assert.equal((quest.match(/rpQueteTexte\('toBar'/g)||[]).length,2,'deux rappels bar partagent le même libellé');
 assert.ok((quest.match(/rpQueteTexte\('turnLeft'/g)||[]).length>=2,'guidage gauche réutilisé');
 assert.ok((quest.match(/rpQueteTexte\('exploreStadium'/g)||[]).length>=2,'guidage stade réutilisé');
 assert.ok(quest.includes("state.char.queteAccueil = { etape: 'jeremy_groupe' }"));
 assert.ok(quest.includes("state.char.queteAccueil = { etape: 'attente_hotel' }"));
 assert.ok(quest.includes("queteAccueilSurbrillance('.piece-tab[onclick*=\"salle_elections\"]'"));
 assert.ok(quest.includes("if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state)"));
 const translate=page.indexOf('src="i18n/jeremy-scenes-resources.js');
 const init=page.indexOf('src="i18n/plateau-init.js');
 assert.ok(translate>0&&init>translate);
});
test('un changement du contenu métier ou un fragment HTML suspect conserve la source française',()=>{
 locale='ru';
 assert.equal(win.RPJeremyScenesI18n.label('welcomeJeremy','Autre scène'),'Autre scène');
 assert.equal(win.RPJeremyScenesI18n.label('unknown','Autre scène'),'Autre scène');
 const originalT=win.i18next.t;
 win.i18next.t=()=>'<img src=x onerror=alert(1)>';
 const original=win.RP_I18N_RESOURCES.fr.translation.jeremyScenes.welcomeJeremy;
 assert.equal(win.RPJeremyScenesI18n.label('welcomeJeremy',original),original);
 win.i18next.t=originalT;
});
