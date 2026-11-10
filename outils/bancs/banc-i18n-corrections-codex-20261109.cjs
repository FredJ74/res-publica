'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');

function element(attributes,initial='') {
 const attrs=new Map(Object.entries(attributes));
 return {
   textContent:initial,
   getAttribute:k=>attrs.get(k)||null,
   hasAttribute:k=>attrs.has(k),
   setAttribute:(k,v)=>attrs.set(k,v),
   closest:()=>null,
   get attrs(){return attrs;}
 };
}
function container(nodes){return {querySelectorAll:()=>nodes};}

test('ancien bouton conserve son ordre et son texte apres le rendu d une autre piece',()=>{
 const window={}; vm.runInNewContext(read('i18n/ordres.js'),{window});
 const api=window.RPOrderI18n;
 const translate=(key,{lng,defaultValue})=>key==='orders.plainte'?(lng==='de'?'Anzeige erstatten':'Porter plainte'):
  key==='orders.hotel'?(lng==='de'?'Ein Hotelzimmer buchen':'Réserver une chambre'):defaultValue;
 const engine={t:translate};
 const plainte={fn:'plainte',label:'Porter plainte',i18nKey:'plainte',handler:'openPlainteModal(1,200)',cost:200};
 const hotel={fn:'hotel',label:'Réserver une chambre',i18nKey:'hotel'};
 const old=element({'data-rp-order-index':'0','data-rp-order-fn':'plainte','data-rp-order-source':encodeURIComponent(plainte.label),'data-rp-order-key':'plainte'});
 const newer=element({'data-rp-order-index':'0','data-rp-order-fn':'hotel','data-rp-order-source':encodeURIComponent(hotel.label),'data-rp-order-key':'hotel'});
 api.registerRenderedOrders([plainte]);api.bindVisibleLabels(container([old]));
 api.registerRenderedOrders([hotel]);api.bindVisibleLabels(container([newer]));
 api.refreshVisibleLabels(container([old,newer]),engine,'de');
 assert.equal(old.textContent,'Anzeige erstatten');
 assert.equal(newer.textContent,'Ein Hotelzimmer buchen');
 assert.equal(plainte.handler,'openPlainteModal(1,200)');
 assert.equal(plainte.cost,200);
 // Sous-menu créé tardivement depuis le HTML de la première pièce.
 const deferred=element({'data-rp-order-index':'0','data-rp-order-fn':'plainte','data-rp-order-source':encodeURIComponent(plainte.label),'data-rp-order-key':'plainte'});
 api.refreshVisibleLabels(container([deferred]),engine,'de');
 assert.equal(deferred.textContent,'Anzeige erstatten');
});

test('le titre de salle et les onglets se relocalisent sans navigation',()=>{
 const src=read('plateau-navigation.js');
 const start=src.indexOf('function rpRefreshOpenRoomNames()');
 assert.ok(start>0);
 const title=element({'data-rp-room-source':'Accueil','data-rp-room-building':'banque','data-rp-room-id':'accueil'},'Accueil');
 const tab=element({'data-rp-room-source':encodeURIComponent('Accueil'),'data-rp-room-building':'banque','data-rp-room-id':'accueil'},'Accueil');
 tab.closest=()=>({});
 const calls=[];
 const context={document:container([title,tab]),RPRoomI18n:{label:(b,r,s)=>{calls.push([b,r,s]);return 'استقبال البنك';}},window:{}};
 vm.runInNewContext(src.slice(start),context);
 context.window.RPRefreshOpenRoomNames();
 assert.equal(title.textContent,'استقبال البنك');
 assert.equal(tab.textContent,'استقبال البنك');
 assert.equal(calls.length,2);
});

test('le courrier conserve ses saisies lorsque les etiquettes changent',()=>{
 const src=read('forum.js');
 const start=src.indexOf('function rpRefreshForumOpenLabels()');
 const end=src.indexOf("if(typeof window!=='undefined')window.RPRefreshForumOpenLabels=",start);
 assert.ok(start>0&&end>start);
 const title=element({'data-rp-plateau-key':'newMessage','data-rp-plateau-source':encodeURIComponent('Nouveau message')},'Nouveau message');
 const recipient=element({'data-rp-placeholder-key':'recipientPlaceholder','data-rp-placeholder-source':'Nom du destinataire...'});
 recipient.value='Jean Jaaj';
 const context={document:{querySelectorAll:sel=>sel==='[data-rp-plateau-key]'?[title]:sel==='[data-rp-placeholder-key]'?[recipient]:[]},window:{RPPlateauI18n:{translate:key=>key==='plateau.recipientPlaceholder'?'Empfängername...':key}},rpForumNom:()=>'',rpForumPlateauLibelle:()=> 'Neue Nachricht'};
 vm.runInNewContext(src.slice(start,end),context);
 context.rpRefreshForumOpenLabels();
 assert.equal(title.innerHTML,'Neue Nachricht');
 assert.equal(recipient.getAttribute('placeholder'),'Empfängername...');
 assert.equal(recipient.value,'Jean Jaaj');
});
