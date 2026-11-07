'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'plateau-quete-accueil.js'),'utf8');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const win={};
let locale='fr';
win.RPPlateauI18n={language:()=>locale};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES?.[lng]?.translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','jeremy-scenes-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const keys=['criminalChoice','politicalChoice','entrepreneurialChoice','undecidedChoice',
 'orientationRef','orientationUndecided','criminalWarning','conclusionRef','conclusionUnknown','enterHere'];
test('dix libellés de carrière et orientation dans les neuf langues',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
  locale=lang;
  const entries=win.RP_I18N_RESOURCES[lang].translation.jeremyScenes;
  const canonical=win.RP_I18N_RESOURCES.fr.translation.jeremyScenes;
  for(const key of keys){
   assert.ok(entries[key]?.trim(),lang+': '+key);
   assert.equal(win.RPJeremyScenesI18n.label(key,canonical[key]),entries[key],lang+': '+key);
  }
  const ref=win.RPJeremyScenesI18n.format('orientationRef',{
   name:'Pat Hounette',place:'la Place du Formulaire de la Liberté'},'Secours');
  assert.ok(ref.includes('Pat Hounette')&&ref.includes('la Place du Formulaire de la Liberté'),lang);
  assert.ok(!ref.includes('{{'),lang+': interpolation complète');
  const finale=win.RPJeremyScenesI18n.format('conclusionRef',{name:'Pat Hounette'},'Secours');
  assert.ok(finale.includes('Pat Hounette')&&!finale.includes('{{'),lang);
 }
});
test('aucun nom injecté en HTML, mêmes référents de la quête et même choix métier',()=>{
 locale='ru';
 const label=win.RPJeremyScenesI18n.format('orientationRef',
  {name:'<img src=x>',place:'<script>hi</script>'},'Secours');
 assert.ok(label.includes('&lt;img')&&label.includes('&lt;script'));
 assert.ok(!label.includes('<img')&&!label.includes('<script'));
 assert.equal(win.RPJeremyScenesI18n.format('other',{name:'x'},'Secours'),'Secours');
 for(const id of ['criminel','politique','entrepreneurial','indecis']){
  assert.ok(source.includes("queteAccueilChoisirAmbition(\\'"+id+"\\')"),id+': onclick conservé');
 }
 assert.ok(source.includes("state.char.queteCarriere = {"));
 assert.ok(source.includes("ambition: ambition"));
 assert.ok(source.includes("state.char.queteAccueil = { etape: 'carriere_orientation' }"));
 assert.ok(source.includes("suivant: ambition === 'criminel' ? fermerClotureCarriere : queteAccueilCarriereRepertoire"));
 for(const key of keys){
  if(key==='orientationRef'||key==='conclusionRef')assert.ok(source.includes("rpQueteModele('"+key+"'"),key);
  else assert.ok(source.includes("rpQueteTexte('"+key+"'"),key);
 }
 assert.ok(html.includes('i18n/jeremy-scenes-resources.js'));
});
