'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const source=read('plateau-logements-sociaux.js'),dictionary=read('i18n/social-housing-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fixture(lang='fr'){
 let title='',body='',visible=false;
 const calls=[],toast=[],journal=[];
 const element={value:'250',getAttribute:k=>k==='data-social-i18n'?'setRent':k==='data-social-args'?'{}':null,textContent:''};
 const box={get innerHTML(){return body},set innerHTML(v){body=v},
  querySelector:q=>q==='[data-social-context]'&&body.includes('data-social-context')?{
   getAttribute:k=>k==='data-social-context'?(body.includes('data-social-context="demand"')?'demand':'dashboard'):null}:null,
  querySelectorAll:q=>q==='[data-social-i18n]'?[element]:[]};
 const modal={classList:{add(){visible=true},contains:k=>k==='open'&&visible,remove(){visible=false}}};
 const heading={get textContent(){return title},set textContent(t){title=t}};
 const state={country:'republic',currentCity:'capitale',char:{name:'Test'}};
 const ctx={console,window:null,state,
  document:{getElementById:id=>({'modal-postes':modal,'postes-body':box,'postes-modal-title':heading})[id]||null},
  RP_I18N_GAME_ENABLED:true,locale:lang,RPPlateauI18n:{language:()=>ctx.locale},
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}])),
  COUNTRIES:{republic:{cur:'FR'},soviet:{cur:'PSK'}},WORLD:{republic:{capitale:{name:'Luthécia'}}},
  BUILDINGS:{mairie:{name:'Mairie'}},
  showToast:(...x)=>toast.push(x),addJournalEntry:(...x)=>journal.push(x),
  updateUI:()=>{},appliquerPaiementServeur:()=>{},
  sbRpcVerdict:async name=>{calls.push(name);
   if(name==='logements_sociaux_offre')return{ok:true,offre:true};
   if(name==='logements_sociaux_tableau')return{ok:true,pays:'republic',ville:'capitale',
    appartements:[{terrain:'mairie',lot:'a',label:'Appartement A',locataire:'Pierre',loyer:100},
                  {terrain:'mairie',lot:'b',label:'Appartement B',locataire:null,loyer:150}],
    historiques:[],demandes:[{id:'dem-1',demandeur:'Anne',type:'petit'}]};
   throw Error('Unexpected server call: '+name);
  }
 };
 ctx.window=ctx;vm.createContext(ctx);
 vm.runInContext(dictionary,ctx,{filename:'social-housing-resources.js'});
 vm.runInContext(source,ctx,{filename:'plateau-logements-sociaux.js'});
 return{ctx,calls,toast,element,get title(){return title},get body(){return body}};
}
test('48 libellés et variables cohérents dans neuf langues',()=>{
 const e=fixture(),fr=e.ctx.RP_I18N_RESOURCES.fr.translation.socialHousing;
 assert.equal(Object.keys(fr).length,48);
 for(const lang of langs){
  const data=e.ctx.RP_I18N_RESOURCES[lang].translation.socialHousing;
  assert.deepEqual(Object.keys(data).sort(),Object.keys(fr).sort(),lang);
  for(const [k,v] of Object.entries(fr)){
   assert.ok(data[k]?.trim(),lang+':'+k);
   const vars=x=>(x.match(/\{[a-z]+\}/g)||[]).sort().join(',');
   assert.equal(vars(data[k]),vars(v),lang+':'+k);
  }
 }
});
test('choix de taille : valeurs de type inchangées dans les neuf langues',async()=>{
 for(const lang of langs){
  const e=fixture(lang),words=e.ctx.RP_I18N_RESOURCES[lang].translation.socialHousing;
  await e.ctx.demanderLogementSocialCommun(0,0);
  assert.equal(e.title,words.demandTitle,lang);
  assert.ok(e.body.includes(words.demandIntro),lang);
  assert.ok(e.body.includes(words.small),lang);
  assert.ok(e.body.includes(words.large),lang);
  assert.ok(e.body.includes("confirmerDemandeLogementSocialCommun('petit')"),lang);
  assert.ok(e.body.includes("confirmerDemandeLogementSocialCommun('grand')"),lang);
  assert.ok(e.body.includes('confirmerDemandeLogementSocialCommun(null)'),lang);
  assert.equal(e.calls.length,1);
 }
});
test('tableau mairie : loyer, destination, demandeurs et actions conservés',async()=>{
 for(const lang of langs){
  const e=fixture(lang),words=e.ctx.RP_I18N_RESOURCES[lang].translation.socialHousing;
  await e.ctx.ouvrirTableauLogementsSociaux();
  assert.equal(e.title,words.title,lang);
  assert.ok(e.body.includes(words.cityIntro.replace('{city}','Luthécia')),lang);
  assert.ok(e.body.includes(words.pending.replace('{count}','1')),lang);
  assert.ok(e.body.includes('value="100"'),lang);
  assert.ok(e.body.includes('value="150"'),lang);
  assert.ok(e.body.includes("attribuerLogementSocialCommun('dem-1')"),lang);
  assert.ok(e.body.includes("fixerLoyerLogementSocial('mairie','a')"),lang);
  assert.equal(e.calls.join(','),'logements_sociaux_tableau');
 }
});
test('changement de langue sans RPC ni réécriture des données saisies',async()=>{
 const e=fixture('fr');await e.ctx.ouvrirTableauLogementsSociaux();
 const original=e.body;
 e.ctx.locale='de';
 for(const handler of e.ctx.RP_I18N_CHANGE_CALLBACKS)handler();
 assert.equal(e.calls.length,1);
 assert.equal(e.body,original);
 assert.equal(e.element.textContent,e.ctx.RP_I18N_RESOURCES.de.translation.socialHousing.setRent);
 assert.equal(e.element.value,'250');
 assert.equal(e.title,e.ctx.RP_I18N_RESOURCES.de.translation.socialHousing.title);
});
test('motifs traduits sans modifier les RPC ou coûts serveur',()=>{
 for(const lang of langs){
  const e=fixture(lang);
  const res=e.ctx.logementsSociauxMotif({raison:'premier_loyer_refuse'});
  assert.equal(res,e.ctx.RP_I18N_RESOURCES[lang].translation.socialHousing.reason_premier_loyer_refuse);
 }
 for(const key of ['logements_sociaux_offre','logement_social_demander','logements_sociaux_tableau','logement_social_attribuer','logement_social_loyer_fixer'])
  assert.ok(source.includes(key),key);
 assert.match(html,/i18n\/social-housing-resources\.js\?v=20261112/);
 assert.match(html,/plateau-logements-sociaux\.js\?v=i18n-social-20261112/);
});
