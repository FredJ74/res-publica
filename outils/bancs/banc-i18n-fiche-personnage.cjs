'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
let lang='fr';
const win={RPPlateauI18n:{language:()=>lang}};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((x,k)=>x?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','character-sheet-resources.js']){
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx,{filename:file});
}
const keys=['identity','statistics','characteristics','resources','totalMoney','cash','bank',
 'investments','outstandingLoans','influence','popularity','discretion','health','morale','journey',
 'forumSignature','edit','hotelReservations','inventory','noItems','noReservedNights','readUnavailable'];
const actionKeys=['sleep','sleepNow','heal','useMedicine','meditate','tacticalActions','hide',
 'myVehicles','organizeBlockade','unionBlockadeHere','renewUnionBlockade','noPaBonus',
 'paBonusTomorrow','alreadySlept','noMedicine','meditateHint'];
const section=source.slice(source.indexOf('async function openCharSheet()'),
 source.indexOf('function switchCharSheetTab('));
test('fiche personnage : 22 titres traduits dans neuf langues',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 assert.equal(keys.length,22);
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=locale;
  const labels=win.RP_I18N_RESOURCES[locale].translation.characterSheet;
  assert.deepEqual(Object.keys(labels).sort(),keys.concat(actionKeys).sort(),locale+': ensemble des clés');
  for(const key of keys){
   assert.ok(labels[key]?.trim(),locale+': '+key);
   const origin=win.RP_I18N_RESOURCES.fr.translation.characterSheet[key];
   assert.equal(win.RPCharacterSheetI18n.label(key,origin),labels[key]
     .replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),locale+': texte');
   assert.ok(section.includes("rpCharSheetLabel('"+key+"'"),locale+': intégration '+key);
  }
 }
});
test('actions personnelles : 16 boutons et états visibles en neuf langues, commandes inchangées',()=>{
 assert.equal(actionKeys.length,16);
 const personal=source.slice(source.indexOf('function switchSelfTab('),
  source.indexOf('// =====================\n// ',source.indexOf('function switchSelfTab(')+100));
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=locale;
  const texts=win.RP_I18N_RESOURCES[locale].translation.characterSheet;
  for(const key of actionKeys){
   assert.ok(texts[key]?.trim(),locale+': '+key);
   const origin=win.RP_I18N_RESOURCES.fr.translation.characterSheet[key];
   assert.equal(win.RPCharacterSheetI18n.label(key,origin),texts[key]
    .replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])));
   assert.ok(personal.includes("rpCharSheetLabel('"+key+"'"),key+': liaison au DOM');
  }
 }
 // Les ordres de l'ancien menu restent identiques : coût, cible, échec et réputation ne sont pas traduits.
 for(const invariant of ["onclick=\"doDormir()\"","onclick=\"doSesoigner()\"",
  "doOrder(\\'se_reposer\\',1,0,\\'Mediter\\'","doOrder(\\'se_cacher\\',1,0,\\'Se cacher\\'",
  "doOrder(\\'organiser_blocus\\',1,0,\\'Organiser un blocus\\'",">70% · 1 PA</span>",
  "Math.min(90, 25 + (groupSize - 1))","doOrganiserBlocusSyndical()","doRenouvelerBlocusSyndical()"]){
  assert.ok(personal.includes(invariant),invariant);
 }
});
test('la fiche garde ses onglets, calculs, droits et erreurs de lecture distincts',()=>{
 for(const call of ["switchCharSheetTab('identite')","switchCharSheetTab('stats')",
  "sbRpc('hotel_reservations_lire', {})", "sbGetPretsEnCours(char.name)",
  "resumeFortune().comptes","totalComptesBancaires()","state.liquide",
  "pretsEnCours.length === 0","listeHotelBrute === null","groupesHotel.length === 0",
  "sanitizeRichHtml(char.signatureHtml)"]){
  assert.ok(section.includes(call),call);
 }
 assert.ok(section.includes("rpCharSheetLabel('readUnavailable'"));
 assert.ok(section.includes("rpCharSheetLabel('noReservedNights'"));
 assert.ok(section.includes("rpCharSheetLabel('noItems'"));
 const bridge=html.indexOf('src="i18n/plateau-bridge.js');
 const resource=html.indexOf('src="i18n/character-sheet-resources.js');
 const init=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(bridge>=0&&resource>bridge&&init>resource);
});
test('nom PJ non traduit et tout HTML injecté dans un libellé est échappé',()=>{
 lang='de';
 assert.equal(win.RPCharacterSheetI18n.label('identity','Nom de personnage'),
  'Nom de personnage');
 const t=win.i18next.t;
 win.i18next.t=()=>'<img src=x onerror=alert(1)> &';
 const encoded=win.RPCharacterSheetI18n.label('edit','Modifier');
 assert.ok(encoded.includes('&lt;img')&&encoded.includes('&amp;'));
 assert.ok(!encoded.includes('<img'));
 win.i18next.t=t;
});


test('rendu complet de la fiche PJ en neuf langues sur des valeurs identiques et sans Supabase',async()=>{
 const start=source.indexOf('function rpCharSheetLabel(key,source) {');
 const end=source.indexOf('function switchCharSheetTab(',start);
 assert.ok(start>=0&&end>start);
 const code=source.slice(start,end);
 const values=[];
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=locale;
  let rendered='';
  const node={classList:{add:()=>{}},set innerHTML(value){rendered=value;},get innerHTML(){return rendered;}};
  const person={name:'Testeur',country:'republic',stats:{},bio:'',motto:'',signatureHtml:''};
  const fixture={
   window:win,
   state:{char:person,poste:null,placementsBancaires:[],inventory:[],liquide:150,
     inf:10,pop:20,dis:30,hp:40,moral:50},
   COUNTRIES:{republic:{cur:'FR',n:'Republia'}},
   ARCHETYPES:[],CAREERS:[],ORIGINS:[],SCHOOLS:[],STAT_DEFS:[],
   TYPES_PRET:{},
   document:{getElementById:()=>node},
   sbRpc:async()=>[], // lecture serveur simulée : vide véritable, non panne
   resumeFortune:()=>({comptes:123}),
   totalComptesBancaires:()=>123,
   genererStatsHtml:()=>'<span>STATISTIC_TABLE</span>'
  };
  const sandbox=vm.createContext(fixture);
  vm.runInContext(code,sandbox,{filename:'openCharSheet'});
  await vm.runInContext('openCharSheet()',sandbox);
  const labels=win.RP_I18N_RESOURCES[locale].translation.characterSheet;
  for(const key of ['identity','statistics','resources','cash','bank','hotelReservations','noReservedNights','noItems']){
   const translated=win.RPCharacterSheetI18n.label(key,win.RP_I18N_RESOURCES.fr.translation.characterSheet[key]);
   assert.ok(rendered.includes(translated),locale+': visible '+key);
  }
  assert.ok(rendered.includes('Testeur'),locale+': identité PJ non traduite');
  assert.ok(rendered.includes('150')&&rendered.includes('123'),locale+': valeurs liquidités et banque identiques');
  assert.ok(rendered.includes("switchCharSheetTab('identite')"),locale+': bouton identité');
  assert.ok(rendered.includes("switchCharSheetTab('stats')"),locale+': bouton statistiques');
  assert.ok(rendered.includes('STATISTIC_TABLE'),locale+': moteur statistique conservé');
  // Contre-épreuve : serveur indisponible, ne jamais présenter ce résultat
  // comme une liste de réservations vide ou effacer un droit déjà payé.
  fixture.sbRpc=async()=>null;
  await vm.runInContext('openCharSheet()',sandbox);
  assert.ok(rendered.includes(win.RPCharacterSheetI18n.label('readUnavailable',
    win.RP_I18N_RESOURCES.fr.translation.characterSheet.readUnavailable)),
    locale+': échec de lecture distinct de zéro réservation');
  assert.ok(!rendered.includes(win.RPCharacterSheetI18n.label('noReservedNights',
    win.RP_I18N_RESOURCES.fr.translation.characterSheet.noReservedNights)),
    locale+': jamais de faux vide en panne');
  values.push({liquide:150,comptes:123,locale});
 }
 assert.equal(values.length,9);
});
