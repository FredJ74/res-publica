'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
const src=read('i18n/shared-sales-dinner-resources.js');
const journalSrc=read('plateau-journal-ventes.js'),dinnerSrc=read('plateau-restaurant-luthecia.js'),html=read('plateau.html');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function environment(locale='fr',enabled=true){
 let onLanguage;
 const cards=[],calls=[],toasts=[],timeline=[];
 const journal={querySelectorAll(){return cards.slice()},appendChild(node){cards.push(node)}};
 const fields={
 'journal':journal,
 'modal-postes':{classList:{remove(){} }},
 'invitation-message-input':{value:'Bonjour'},
 'invitation-reponse-input':{value:'À demain'}
 };
 const storage=new Map();
 const state={country:'republic',currentCity:'capitale',currentBuilding:'hotel-republica',currentRoom:'restaurant',char:{name:'Organisateur'}};
 const resultJournal={ok:true,nonLues:1,evenements:[{id:'sale1',acheteur:'pj:Arnie',enseigne:'Mon <img>',article:'Chocolat <b>',quantite:2,montant:20,ts:'2026-11-11T12:00:00Z'}]};
 const context={window:null,console,document:{
   getElementById:id=>fields[id]||null,
   createElement:()=>({dataset:{},remove(){const i=cards.indexOf(this);if(i>=0)cards.splice(i,1)}}),
   addEventListener(){}
 },RP_I18N_GAME_ENABLED:enabled,RP_I18N_RESOURCES:Object.fromEntries(locales.map(l=>[l,{translation:{}}])),
 RPPlateauI18n:{language:()=>context.currentLang},
 i18next:{on(event,fn){if(event==='languageChanged')onLanguage=fn}},
 currentLang:locale,state,
 rpAuthUid:()=> 'user123',rpAuthSessionIdentifiant:()=> 'session1',
 rpRealitesEnregistrer(){},formaterHorodatageJournal:x=>x,
 signalerEvenementJournal(){},
 sbRpcVerdict:async(name,args,opts)=>{
  calls.push({name,args,opts});
  if(name==='journal_ventes_lire')return resultJournal;
  if(name==='restaurant_diner_creer')return {ok:true,statut:'en_attente'};
  if(name==='restaurant_diner_suivre')return {ok:true,invitations:[]};
  if(name==='restaurant_diner_repondre')return {ok:true};
  if(name==='restaurant_diner_acquitter')return {ok:true};
  throw Error('Unexpected RPC '+name);
 },
 showToast:(...args)=>toasts.push(args),
 contexteNavigationRue:()=>({uid:'user123',nom:'Organisateur'}),
 contexteNavigationRueValide:()=>true,
 crypto:{randomUUID:()=> 'stable-uuid'},
 sessionStorage:{getItem:key=>storage.get(key)||null,setItem:(key,val)=>storage.set(key,val),removeItem:key=>storage.delete(key)},
 commercePjActualiserPersonnage:async()=>true,updateUI(){timeline.push('updateUI')},
 tracerActionPourRumeur:(...args)=>timeline.push(args),advanceTime:n=>timeline.push(n),
 BUILDINGS:{'hotel-republica':{rooms:{restaurant:{orders:[{fn:'diner_affaires',cost:300,pa:2}]}}}}
 };
 context.window=context;
 vm.createContext(context);vm.runInContext(src,context,{filename:'sales-resource'});
 vm.runInContext(journalSrc,context,{filename:'sales-journal'});
 vm.runInContext(dinnerSrc,context,{filename:'restaurant-dinner'});
 return {context,cards,calls,toasts,fields,storage,timeline,change(l){context.currentLang=l;for(const cb of context.RP_I18N_CHANGE_CALLBACKS||[])cb(l)},setRpc(fn){context.sbRpcVerdict=fn}};
}
test('neuf langues, 25 clés et interpolations strictement symétriques',()=>{
 const e=environment();
 const fr=e.context.RP_I18N_RESOURCES.fr.translation.sharedSalesDinner;
 assert.equal(Object.keys(fr).length,25);
 for(const lang of locales){
  const text=e.context.RP_I18N_RESOURCES[lang].translation.sharedSalesDinner;
  assert.deepEqual(Object.keys(text).sort(),Object.keys(fr).sort(),lang);
  for(const key of Object.keys(fr)){
   assert.ok(text[key].trim(),lang+'/'+key);
   const variables=str=>[...str.matchAll(/\{([a-z]+)\}/g)].map(a=>a[1]).sort();
   assert.deepEqual(variables(text[key]),variables(fr[key]),lang+'/'+key);
  }
 }
 assert.match(html,/i18n\/shared-sales-dinner-resources\.js\?v=20261111/);
 assert.match(html,/plateau-journal-ventes\.js\?v=[^"]*i18n-20261111/);
 assert.match(html,/plateau-restaurant-luthecia\.js\?v=[^"]*i18n-20261111/);
});
test('journal FR inchangé, données échappées, changement de langue sans RPC',async()=>{
 const e=environment();
 await e.context.chargerJournalVentes(false);
 assert.equal(e.calls.length,1);assert.equal(e.calls[0].name,'journal_ventes_lire');
 assert.equal(e.calls[0].args.p_acquitter,false);
 assert.equal(e.cards.length,1);
 const original=e.cards[0].innerHTML;
 assert.ok(original.includes('Arnie a acheté dans votre commerce « Mon &lt;img&gt; » 2 × Chocolat &lt;b&gt; au prix de 20 FR.'));
 assert.ok(!original.includes('<img>'));
 e.change('en');
 assert.match(e.cards[0].innerHTML,/bought 2 × Chocolat/);
 assert.ok(e.cards[0].innerHTML.includes('Mon &lt;img&gt;'));
 assert.equal(e.calls.length,1);
 e.change('ar');assert.ok(e.cards[0].innerHTML.includes('اشترى Arnie'));assert.equal(e.calls.length,1);
 e.change('fr');assert.equal(e.cards[0].innerHTML,original);
});
test('panne journal : un seul appel d\'acquittement, erreur dans chaque langue',async()=>{
 for(const lang of locales){
  const e=environment(lang);
  e.setRpc(async(name,args)=>{e.calls.push({name,args});return {ok:false};});
  assert.equal(await e.context.chargerJournalVentes(true),false);
  assert.equal(e.calls.length,1);
  assert.equal(e.calls[0].args.p_acquitter,true);
  assert.equal(e.toasts.length,1);
  assert.ok(e.toasts[0][0]&&e.toasts[0][1]);
  if(lang!=='fr')assert.notEqual(e.toasts[0][0],'Journal des ventes indisponible');
 }
});
test('invitation, réponse et refus serveur : mêmes RPC et paramètres dans neuf langues',async()=>{
 for(const lang of locales){
  const e=environment(lang);
  await e.context.restaurantLutheciaInviter('Invité',true);
  assert.equal(e.calls[0].name,'restaurant_diner_creer');
  assert.equal(e.calls[0].args.p_invite,'Invité');
  assert.equal(e.calls[0].args.p_pnj,false);
  assert.equal(e.calls[0].args.p_message,'Bonjour');
  assert.equal(e.calls[1].name,'restaurant_diner_suivre');
  assert.ok(e.toasts.length>0);
  assert.equal(e.toasts[0][2],true);
  await e.context.restaurantLutheciaRepondre('inv-1',false);
  assert.equal(e.calls[2].name,'restaurant_diner_repondre');
  assert.equal(e.calls[2].args.p_invitation,'inv-1');
  assert.equal(e.calls[2].args.p_accepte,false);
  assert.equal(e.calls[2].args.p_reponse,'À demain');
  assert.equal(e.toasts.at(-1)[2],false);
  if(lang!=='fr')assert.notEqual(e.toasts[0][0],'Invitation enregistrée');
 }
});
test('aucun tarif métier modifié ; description traduite au moment du rendu',()=>{
 const e=environment('en');
 const order=e.context.ordresRestaurantLuthecia('hotel-republica','restaurant')[0];
 assert.equal(order.fn,'diner_affaires');assert.equal(order.cost,300);assert.equal(order.pa,2);
 assert.match(order.desc,/300 FR/);assert.match(order.desc,/2 AP/);assert.match(order.desc,/\+10/);
 assert.equal(e.calls.length,0);
 e.change('fr');
 const french=e.context.ordresRestaurantLuthecia('hotel-republica','restaurant')[0];
 assert.match(french.desc,/Après acceptation/);
 assert.equal(french.pa,2);
});
test('repli français désactivé : libellés et variables conservés',async()=>{
 const e=environment('ko',false);
 await e.context.chargerJournalVentes(false);
 assert.match(e.cards[0].innerHTML,/a acheté dans votre commerce/);
 assert.match(e.context.ordresRestaurantLuthecia('hotel-republica','restaurant')[0].desc,/Après acceptation/);
});
test('résultat serveur servi : une seule confirmation et coût effectivement renvoyé',async()=>{
 const e=environment('ru');
 e.setRpc(async(name,args)=>{
  e.calls.push({name,args});
  if(name==='restaurant_diner_suivre')return {ok:true,invitations:[{id:'inv-5',invite:'Invité',inviteur:'Organisateur',resultat_service:{ok:true,champagnes:false,total:400}}]};
  if(name==='restaurant_diner_acquitter')return {ok:true};
  throw Error(name);
 });
 await e.context.restaurantLutheciaSuivre(true);
 assert.deepEqual(e.calls.map(x=>x.name),['restaurant_diner_suivre','restaurant_diner_acquitter']);
 assert.equal(e.calls[1].args.p_invitation,'inv-5');
 assert.ok(e.toasts[0][1].includes('400 FR'));
 assert.equal(e.toasts[0][2],true);
 assert.ok(e.timeline.includes(2));
});
