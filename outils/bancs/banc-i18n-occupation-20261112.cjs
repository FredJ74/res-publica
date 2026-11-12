'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const load=p=>fs.readFileSync(path.join(root,p),'utf8');
const code=load('plateau-occupation-commandes.js'),resources=load('i18n/occupation-resources.js'),html=load('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function session(){
 const mem=new Map();
 return {getItem:key=>mem.get(key)||null,setItem:(key,val)=>mem.set(key,String(val)),removeItem:key=>mem.delete(key),count:()=>mem.size};
}
function setup(lang){
 const calls=[],warnings=[],choice={};
 const c={language:lang,state:{char:{name:'Test'},country:'republic'},
  RP_I18N_GAME_ENABLED:true,RP_I18N_RESOURCES:Object.fromEntries(langs.map(l=>[l,{translation:{}}])),
  RPPlateauI18n:{language:()=>c.language},sessionStorage:session(),console,
  crypto:{randomUUID:()=> 'fictive-id'},
  contexteNegociationSquatteurs:()=>choice,
  memeContexteNegociation:ctx=>ctx===choice,
  sbRpcVerdict:async(name,params)=>{
   calls.push({name,params});
   if(name!=='terrain_occupation_action_preparer')throw Error('No write RPC in presentation');
   return params.p_action==='police'?{ok:true,pa:1,delaiHeures:4}: {ok:true,pa:2,cout:100,delaiHeures:2,taux:67};
  },
  showToast:(...args)=>warnings.push(args),constructionBouton:(label,onclick)=>'<button data-click="'+onclick+'">'+label+'</button>',
  constructionFenetre:(title,body)=>{c.title=title;c.body=body},
  document:{getElementById:id=>{
   if(id==='modal-postes')return {classList:{contains:key=>key==='open'}};
   if(id==='postes-body')return {querySelector:selector=>c.body?.includes('data-occupation-police="1"')?{}:null};
   return null;
  }}
 };
 c.window=c;vm.createContext(c);
 vm.runInContext(resources,c,{filename:'occupation-resources.js'});
 vm.runInContext(code,c,{filename:'plateau-occupation-commandes.js'});
 return {c,calls,warnings,choice};
}
test('24 clés complètes dans neuf langues, variables conservées',()=>{
 const {c}=setup('fr'),fr=c.RP_I18N_RESOURCES.fr.translation.occupation;
 assert.equal(Object.keys(fr).length,24);
 const params=x=>(x.match(/\{[a-z]+\}/g)||[]).sort().join(',');
 for(const lang of langs){
  const dict=c.RP_I18N_RESOURCES[lang].translation.occupation;
  assert.deepEqual(Object.keys(dict).sort(),Object.keys(fr).sort(),lang);
  for(const key of Object.keys(fr)){
   assert.ok(dict[key]?.trim(),lang+':'+key);
   assert.equal(params(dict[key]),params(fr[key]),lang+':'+key);
  }
 }
});
test('neuf langues : même choix technique et montants du verdict serveur',async()=>{
 for(const lang of langs){
  const {c,calls}=setup(lang);
  await c.occupationOuvrirPolice();
  const dict=c.RP_I18N_RESOURCES[lang].translation.occupation;
  assert.equal(c.title,dict.callPolice,lang);
  assert.ok(c.body.includes(dict.requestLegal),lang);
  assert.ok(c.body.includes(dict.bribe),lang);
  assert.ok(c.body.includes('100 FR'),lang);
  assert.ok(c.body.includes('67'),lang);
  assert.ok(c.body.includes('data-occupation-police="1"'));
  assert.ok(c.body.includes('occupationExecuterPolice("police")'));
  assert.ok(c.body.includes('occupationExecuterPolice("corruption_police")'));
  assert.equal(calls.length,2,lang);
  assert.deepEqual(calls.map(x=>x.params.p_action),['police','corruption_police']);
 }
});
test('bascule à chaud : redessiner la proposition depuis le cache, zéro RPC',async()=>{
 const {c,calls}=setup('fr');
 await c.occupationOuvrirPolice();const before=c.body;
 c.language='ko';
 for(const callback of c.RP_I18N_CHANGE_CALLBACKS)callback();
 assert.equal(calls.length,2,'pas de seconde préparation serveur');
 assert.notEqual(c.body,before);
 assert.equal(c.title,c.RP_I18N_RESOURCES.ko.translation.occupation.callPolice);
 assert.ok(c.body.includes(c.RP_I18N_RESOURCES.ko.translation.occupation.requestLegal));
 assert.ok(c.body.includes('100 FR'));
});
test('références métier, clés de reprise, RPC et audit inchangés',()=>{
 assert.match(code,/terrain_occupation_action_preparer/);
 assert.match(code,/terrain_occupation_action'/);
 assert.match(code,/p_requete:intention.requete/);
 assert.match(code,/sessionStorage\.setItem\(cle,JSON\.stringify\(intention\)\)/);
 assert.match(code,/sbGetTerrainState/);
 assert.match(code,/memeContexteNegociation/);
 assert.match(html,/i18n\/occupation-resources\.js\?v=20261112/);
 assert.match(html,/plateau-occupation-commandes\.js\?v=occupation-i18n-20261112/);
 assert.match(load('outils/audits/audit-i18n-editorial.cjs'),/occupation-resources\.js/);
});
