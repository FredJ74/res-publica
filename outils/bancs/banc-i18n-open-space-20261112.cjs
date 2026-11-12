'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const catalog=read('i18n/open-space-resources.js'),impl=read('plateau-open-space.js'),html=read('plateau.html');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function make(lang='fr'){
 const win={RP_I18N_GAME_ENABLED:true,RP_I18N_RESOURCES:Object.fromEntries(locales.map(l=>[l,{translation:{}}])),RPPlateauI18n:{language:()=>ctx.lang}};
 const ctx={window:win,lang,console};vm.createContext(ctx);vm.runInContext(catalog,ctx);vm.runInContext(impl,ctx);return {ctx,win};
}
test('six libellés sur neuf locales, identifiants de poste inchangés',()=>{
 const v=make();
 for(const locale of locales){
   const words=v.win.RP_I18N_RESOURCES[locale].translation.openSpace;
   assert.deepEqual(Object.keys(words).sort(),['occupied','postA','postB','postC','postD','toRent'].sort());
   for(const [k,label] of Object.entries(words))assert.ok(label.trim(),locale+'.'+k);
 }
 assert.equal(vm.runInContext("OPEN_SPACE_PLAN['centre-affaires'].postes.length",v.ctx),4);
 assert.equal(vm.runInContext("OPEN_SPACE_PLAN['centre-affaires'].postes.map(p=>p.piece).join(',')",v.ctx),
 'open_space_a,open_space_b,open_space_c,open_space_d');
});
test('traduire occupation et quatre postes, changer de langue sans réseau',()=>{
 const {ctx}=make('fr');
 ctx.getLocationPourRoom=()=>null;
 assert.equal(vm.runInContext("openSpaceSituationPoste('centre-affaires','open_space_a','capitale').texte",ctx),'À louer');
 ctx.lang='ar';
 assert.equal(vm.runInContext("openSpaceSituationPoste('centre-affaires','open_space_a','capitale').texte",ctx),'متاح للإيجار');
 assert.equal(vm.runInContext("openSpaceNom(OPEN_SPACE_PLAN['centre-affaires'].postes[0])",ctx),'مساحة عمل مشتركة A');
 ctx.getLocationPourRoom=()=>({locataire:'pj:Persona'});
 assert.equal(vm.runInContext("openSpaceSituationPoste('centre-affaires','open_space_a','capitale').texte",ctx),'Persona');
 ctx.getLocationPourRoom=()=>({locataire:''});
 assert.equal(vm.runInContext("openSpaceSituationPoste('centre-affaires','open_space_a','capitale').texte",ctx),'مشغول');
 ctx.lang='ko';
 assert.equal(vm.runInContext("openSpaceSituationPoste('centre-affaires','open_space_a','capitale').texte",ctx),'사용 중');
 ctx.lang='fr';
 assert.equal(vm.runInContext("openSpaceNom(OPEN_SPACE_PLAN['centre-affaires'].postes[0])",ctx),'Open Space A');
});
test('catalogue bien chargé avant le module et connu de l’audit',()=>{
 assert.match(html,/i18n\/open-space-resources\.js\?v=20261112[\s\S]*plateau-open-space\.js\?v=i18n-20261112/);
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/'open-space-resources\.js'/);
});
