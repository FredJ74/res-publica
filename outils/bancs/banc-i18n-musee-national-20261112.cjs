'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const catalog=read('i18n/museum-national-bios-resources.js'),source=read('plateau-musee-personnalites.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function make(lang='fr'){
 const state={country:'republic',currentBuilding:'musee-national-republia',currentRoom:'salle_politiques'};
 const visible={title:'',body:'',open:false};
 const body={get innerHTML(){return visible.body},set innerHTML(v){visible.body=v},
  querySelector(selector){
   const m=selector.match(/\[data-musee-national="([^"]+)"\]/);
   if(!m||!visible.body.includes('data-musee-national="'+m[1]+'"'))return null;
   const idx=visible.body.match(/data-personnalite="([^"]+)"/);
   return{dataset:{personnalite:idx?.[1]||''}};
 }};
 const document={getElementById(id){
  if(id==='postes-body')return body;
  if(id==='postes-modal-title')return{set textContent(x){visible.title=x}};
  if(id==='modal-postes')return{classList:{add(){visible.open=true},contains(x){return x==='open'&&visible.open}}};
  return null;
 }};
 const ctx={console,document,state,lang,BUILDINGS:{'musee-national-republia':{rooms:{salle_politiques:{name:'Salle des politiques'}}}},
  RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>ctx.lang},
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(k=>[k,{translation:{}}]))};
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(catalog,ctx);vm.runInContext(source,ctx);
 return{ctx,state,visible};
}
test('douze biographies intégralement couvertes dans neuf langues',()=>{
 const f=make(),ref=f.ctx.RP_I18N_RESOURCES.fr.translation.museumNationalBios;
 assert.equal(Object.keys(ref.bios).length,12);
 for(const lang of langs){
  const d=f.ctx.RP_I18N_RESOURCES[lang].translation.museumNationalBios;
  assert.deepEqual(Object.keys(d.bios).sort(),Object.keys(ref.bios).sort());
  for(const [name,bio] of Object.entries(d.bios))assert.ok(bio.trim().length>=5,lang+' '+name);
  for(const key of ['title','back','empty'])assert.ok(d[key]);
 }
});
test('la fiche nationale montre la traduction tout en préservant identité et dates',()=>{
 for(const lang of langs){
  const f=make(lang);vm.runInContext('doConsulterPersonnalitesMusee()',f.ctx);
  assert.match(f.visible.body,/Antoine Ferréol/);assert.match(f.visible.body,/1888–1962/);
  vm.runInContext('afficherFichePersonnaliteMusee(0)',f.ctx);
  const expected=f.ctx.RP_I18N_RESOURCES[lang].translation.museumNationalBios.bios['Antoine Ferréol'];
  assert.ok(f.visible.body.includes(expected),lang);
  assert.ok(f.visible.body.includes(f.ctx.RP_I18N_RESOURCES[lang].translation.museumNationalBios.back),lang);
  assert.ok(f.visible.body.includes('1888–1962'),lang);
 }
});
test('changement de langue à chaud : conserve la personnalité sélectionnée',()=>{
 const f=make('fr');vm.runInContext('doConsulterPersonnalitesMusee()',f.ctx);
 vm.runInContext('afficherFichePersonnaliteMusee(2)',f.ctx);
 assert.ok(f.visible.body.includes('Gustave Ombreval'));
 f.ctx.lang='ko';for(const cb of f.ctx.RP_I18N_CHANGE_CALLBACKS)cb();
 assert.ok(f.visible.body.includes('Gustave Ombreval'));
 assert.ok(f.visible.body.includes('40년'));
 assert.ok(f.visible.body.includes('1901–1975'));
});
test('un nom présent au musée de Montrouge ne reçoit pas les biographies nationales',()=>{
 const f=make('en');
 f.state.currentBuilding='musee-histoire-montrouge';f.state.currentRoom='salle_loisirs';
 const original=vm.runInContext("MUSEE_PROVINCE_PERSONNALITES['musee-histoire-montrouge'].salle_loisirs.find(p=>p.nom==='Patrick Lemaître')",f.ctx);
 assert.equal(vm.runInContext("ficheMuseeAffichee(MUSEE_PROVINCE_PERSONNALITES['musee-histoire-montrouge'].salle_loisirs.find(p=>p.nom==='Patrick Lemaître')).bio",f.ctx),original.bio,'la province conserve sa biographie');
 assert.equal(vm.runInContext("ficheMuseeAffichee(MUSEE_PROVINCE_PERSONNALITES['musee-histoire-montrouge'].salle_loisirs.find(p=>p.nom==='Patrick Lemaître')).bio",f.ctx),original.bio);
 f.state.country='soviet';
 assert.equal(vm.runInContext("museeNationalRepubI18nActif()",f.ctx),false);
});
test('catalogue enregistré, mise en cache sans réseau et scripts liés',()=>{
 assert.match(html,/i18n\/museum-national-bios-resources\.js\?v=20261112/);
 assert.match(html,/plateau-musee-personnalites\.js\?v=i18n-musee-national-20261112/);
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/'museum-national-bios-resources\.js'/);
 assert.ok(source.includes("state.country === 'republic' && state.currentBuilding === 'musee-national-republia'"));
});
