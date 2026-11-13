'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8'),reference='651448e',old=f=>execFileSync('git',['show',reference+':'+f],{cwd:root,encoding:'utf8',maxBuffer:6e6});
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const sources=JSON.parse(read(process.env.COMMON_SOURCE_FILE||'outils/audits/I18N-COMMUNES-ECONOMIE-871-sources.json'));
function load(previous=false){const c={RP_I18N_GAME_ENABLED:true,state:{country:'republic'},locale:'fr',RPPlateauI18n:{language:()=>c.locale}};c.window=c;vm.createContext(c);for(const f of ['i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/order-catalogues-config.js','i18n/sovarka-infobulles-resources.js'])vm.runInContext((previous?old:read)(f),c);return c;}
test(sources.length+' descriptions partagées : réemploi exact des traductions, aucun texte antérieur perdu ou dupliqué',()=>{
 const before=load(true),after=load(),plain=x=>JSON.parse(JSON.stringify(x));assert.equal(sources.length,Number(process.env.COMMON_EXPECTED_COUNT||18));
 assert.deepEqual(plain(after.RP_INFOBULLES_COMMUNES.slice(0,before.RP_INFOBULLES_COMMUNES.length)),plain(before.RP_INFOBULLES_COMMUNES));
 const current=[...after.RP_INFOBULLES_COMMUNES,...after.RP_INFOBULLES_REPUBLIA],keys=current.map(r=>r[0]);assert.equal(new Set(keys).size,keys.length);
 for(const row of [...before.RP_INFOBULLES_COMMUNES,...before.RP_INFOBULLES_REPUBLIA])assert.deepEqual(plain(current.find(r=>r[0]===row[0])),plain(row));
 for(const row of sources){assert.deepEqual(plain(after.RP_INFOBULLES_COMMUNES.find(r=>r[0]===row[0])),row);assert.ok(!after.RP_INFOBULLES_REPUBLIA.some(r=>r[0]===row[0]));}
 for(const [i,l]of langs.entries())for(const row of sources){before.locale=after.locale=l;
  for(const country of ['republic','soviet','fixture']){after.state.country=country;assert.equal(after.RPOrderDescriptionsI18n.desc(row[0]),row[i],country+'/'+l);}
  before.state.country='republic';assert.equal(before.RPOrderDescriptionsI18n.desc(row[0]),row[i]);
 }
});
test('paramètres et mécaniques inchangés, repli français et catalogues Sovarka intacts',()=>{
 const c=load();c.locale='unknown';for(const row of sources)assert.equal(c.RPOrderDescriptionsI18n.desc(row[0]),row[0]);c.locale='en';assert.equal(c.RPOrderDescriptionsI18n.desc('Description inédite'),'Description inédite');
 const base=execFileSync('git',['merge-base','HEAD','origin/main'],{cwd:root,encoding:'utf8'}).trim();
 for(const f of ['data.js','plateau-politique.js','plateau-ordres-info.js','i18n/sovarka-infobulles-resources.js','i18n/order-catalogues-config.js'])assert.equal(read(f),execFileSync('git',['show',base+':'+f],{cwd:root,encoding:'utf8',maxBuffer:6e6}),f);
 assert.equal(execFileSync('git',['diff','--name-only',base,'--','api','migrations','supabase'],{cwd:root,encoding:'utf8'}),'');
});
test('chaque ligne reclassée est une description effectivement affichée dans les deux pays',()=>{
 const c={console,state:{country:'republic'},document:{getElementById:()=>null,querySelector:()=>null,addEventListener(){}},localStorage:{getItem:()=>null}};c.window=c;vm.createContext(c);
 vm.runInContext(read('data.js').replace(/^const (WORLD|BUILDINGS) =/mg,'var $1 ='),c);
 for(const country of ['republic','soviet']){
  const descs=new Set();for(const city of Object.values(c.WORLD[country]||{}))for(const b of city.buildings||[]){const ctx=city.buildingContext?.[b]||{};
   for(const [id,room]of Object.entries({...c.BUILDINGS[b]?.rooms,...ctx.roomsExtra})){if(ctx.roomsExclues?.includes(id))continue;
    for(const o of [...c.ordresDeclaresDeLaPiece(room,ctx,id),...(ctx.roomOverrides?.[id]?.ordersExtra||[])])if(o?.desc)descs.add(o.desc);
   }}
  for(const row of sources)assert.ok(descs.has(row[0]),country+': '+row[0]);
 }
});
