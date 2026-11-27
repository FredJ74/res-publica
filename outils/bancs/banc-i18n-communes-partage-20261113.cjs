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
 // 27/11/2026 (Fred) : textes et traductions des ordres supprimés retirés du catalogue Républia.
 const RETIRES=new Set(['Placements declares et offshore avec Ursula Offshore.','Voir le solde actuel de la caisse de la Scierie.','Voir les matières premières et les produits finis actuellement détenus par la Scierie.']);
 for(const row of [...before.RP_INFOBULLES_COMMUNES,...before.RP_INFOBULLES_REPUBLIA])if(!RETIRES.has(row[0]))assert.deepEqual(plain(current.find(r=>r[0]===row[0])),plain(row));
 for(const row of sources){assert.deepEqual(plain(after.RP_INFOBULLES_COMMUNES.find(r=>r[0]===row[0])),row);assert.ok(!after.RP_INFOBULLES_REPUBLIA.some(r=>r[0]===row[0]));}
 for(const [i,l]of langs.entries())for(const row of sources){before.locale=after.locale=l;
  for(const country of ['republic','soviet','fixture']){after.state.country=country;assert.equal(after.RPOrderDescriptionsI18n.desc(row[0]),row[i],country+'/'+l);}
  before.state.country='republic';assert.equal(before.RPOrderDescriptionsI18n.desc(row[0]),row[i]);
 }
});
test('paramètres et mécaniques inchangés, repli français et catalogues Sovarka intacts',()=>{
 const c=load();c.locale='unknown';for(const row of sources)assert.equal(c.RPOrderDescriptionsI18n.desc(row[0]),row[0]);c.locale='en';assert.equal(c.RPOrderDescriptionsI18n.desc('Description inédite'),'Description inédite');
 // Preuve figée sur la PR #885 (651448e → b23e794) : ce lot n'a touché ni ces fichiers ni le serveur. La comparer à
 // merge-base faisait échouer tout chantier ultérieur qui modifie data.js (ex. renseignement de Sovarka, 13/11).
 const avant='651448e04e0455cc726312073f85e9df61ad762a',apres='b23e79499b6c2fd431a8f8df95402b2ad925b06d';
 assert.equal(execFileSync('git',['diff','--name-only',avant,apres,'--','data.js','plateau-politique.js','plateau-ordres-info.js','i18n/sovarka-infobulles-resources.js','i18n/order-catalogues-config.js','api','migrations','supabase'],{cwd:root,encoding:'utf8'}),'');
});
test('chaque ligne reclassée est une description effectivement affichée dans les deux pays',()=>{
 const c={console,state:{country:'republic'},document:{getElementById:()=>null,querySelector:()=>null,addEventListener(){}},localStorage:{getItem:()=>null}};c.window=c;vm.createContext(c);
 vm.runInContext(read('data.js').replace(/^const (WORLD|BUILDINGS) =/mg,'var $1 ='),c);
 for(const country of ['republic','soviet']){
  const descs=new Set();for(const city of Object.values(c.WORLD[country]||{}))for(const b of city.buildings||[]){const ctx=city.buildingContext?.[b]||{};
   for(const [id,room]of Object.entries({...c.BUILDINGS[b]?.rooms,...ctx.roomsExtra})){if(ctx.roomsExclues?.includes(id))continue;
    for(const o of [...c.ordresDeclaresDeLaPiece(room,ctx,id),...(ctx.roomOverrides?.[id]?.ordersExtra||[])])if(o?.desc)descs.add(o.desc);
   }}
  // Sovarka remplace certains ordres communs par les siens et les retire par excludeOrders (manifestations de soutien
  // seulement, propagande et sondages de la Vérité officielle : décisions de Fred des 08 et 14/11). Une ligne dont tous
  // les ordres sont ainsi exclus en Sovarka n'y est plus affichée ; sa traduction reste utile en Républia.
  const exclusSovarka=new Set();for(const city of Object.values(c.WORLD.soviet||{}))for(const ctx of Object.values(city.buildingContext||{})){
   for(const fn of ctx.excludeOrders||[])exclusSovarka.add(fn);for(const ov of Object.values(ctx.roomOverrides||{}))for(const fn of ov?.excludeOrders||[])exclusSovarka.add(fn);}
  const fnsDe=d=>{const f=new Set();for(const b of Object.values(c.BUILDINGS))for(const r of Object.values(b.rooms||{}))for(const o of r.orders||[])if(o?.desc===d)f.add(o.fn);return [...f];};
  // Plus de banques en Sovarka (décision de Fred, 15/11/2026) : une ligne qui n'existe que dans des banques n'y est plus affichée.
  const batimentsDe=d=>Object.entries(c.BUILDINGS).filter(([,b])=>Object.values(b.rooms||{}).some(r=>(r.orders||[]).some(o=>o?.desc===d))).map(([id])=>id);
  // Audit des chances (mission du soir, 25/11/2026, bloc 1A) : description de la campagne de sécurité alignée sur le serveur ;
  // la ligne livrée reste au catalogue jusqu'à la traduction de la nouvelle par Codex.
  // Fin de soirée du 25/11 (agent B) : description de la censure réécrite (Sovarka). Mission du soir (25/11, blocs 1A et 1B) : autres descriptions de l'audit réécrites, mêmes raisons.
  const REMPLACEES=new Set(["+10 ISN local. Deploiement de forces de l'ordre supplementaires. Preleve sur budget mairie.", "+10 ISN local. Preleve sur budget mairie.", "Cibler un citoyen, un club sportif, une entreprise ou une organisation. Coute a la caisse du gouvernement.", "Influencer massivement l'opinion publique. +POP.", "Interdire un organe de presse. -liberte +controle."]);
  for(const row of sources){if(REMPLACEES.has(row[0]))continue;const fns=fnsDe(row[0]);if(country==='soviet'&&fns.length&&fns.every(fn=>exclusSovarka.has(fn)))continue;
   const bats=batimentsDe(row[0]);if(country==='soviet'&&bats.length&&bats.every(id=>id.startsWith('banque-')))continue;assert.ok(descs.has(row[0]),country+': '+row[0]);}
 }
});
