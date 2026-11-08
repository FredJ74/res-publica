'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const ctx=vm.createContext({window:{}});
for(const file of ['resources.js','orders-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const w=ctx.window;
const engine={t(key,{lng,defaultValue}){return key.split('.').reduce((v,k)=>v?.[k],w.RP_I18N_RESOURCES[lng]?.translation)??defaultValue}};

test('un ordre canonique ne traduit que son texte HTML, jamais ses paramètres métier',()=>{
 const order=Object.freeze({fn:'plainte_police',label:'Porter plainte',pa:1,cost:200,requiresPost:'commissaire'});
 assert.equal(w.RPOrderI18n.labelHtml(order,engine,'de'),'Anzeige erstatten');
 assert.equal(w.RPOrderI18n.labelHtml(order,engine,'ar'),'تقديم بلاغ');
 assert.equal(order.fn,'plainte_police');
 assert.equal(order.label,'Porter plainte');
 assert.equal(order.pa,1);assert.equal(order.cost,200);
});

test('les libellés variables et non répertoriés restent exactement originaux',()=>{
 const ordre={fn:'louer_local',label:'Louer la boutique (800 FR/jour)'};
 assert.equal(w.RPOrderI18n.labelHtml(ordre,engine,'en'),ordre.label);
 const inconnu={fn:'nouvel_ordre',label:'Action spéciale'};
 assert.equal(w.RPOrderI18n.labelHtml(inconnu,engine,'ru'),'Action spéciale');
});

test('une traduction HTML dangereuse est échappée, sans modifier la source',()=>{
 const original=Object.freeze({fn:'plainte_police',label:'Porter plainte'});
 const dangerous={t(key,{lng,defaultValue}){return lng==='fr'?'Porter plainte':'<img src=x onerror="evil()" /> & test';}};
 const value=w.RPOrderI18n.labelHtml(original,dangerous,'de');
 assert.equal(value,'&lt;img src=x onerror=&quot;evil()&quot; /&gt; &amp; test');
 assert.equal(original.label,'Porter plainte');
});

test('le renderer ne change que le texte visible : doOrder conserve le libellé original',()=>{
 const source=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
 const from=source.indexOf('function renderRoomActions(room, buildingId, roomId) {');
 assert.ok(from>=0);
 const end=source.indexOf('\nfunction ',from+30);
 assert.ok(end>from);
 const segment=source.slice(from,end);
 assert.match(segment,/const libelleAffiche = \(window\.RPOrderI18n/);
 assert.match(segment,/window\.RPOrderI18n\.labelHtml\(o,window\.i18next,window\.RPPlateauI18n\.language\(\)\)/);
 assert.match(segment,/safeLabel = o\.label\.replace/);
 assert.match(segment,/doOrder\('/);
 assert.match(segment,/const libelleMarque = '<span data-rp-order-index=/);
 assert.equal(segment.split(" + libelleMarque + ").length-1,2);
 assert.ok(segment.includes('registerRenderedOrders?.(ordresTerrainLuthecia)'));
 assert.match(segment,/const coutJoint = \[costDisplay, paDisplay\]/);
});

test('bascule FR vers AR dans les menus ouverts : conserver noeuds, couts, saisies et gestionnaires',()=>{
 const order=Object.freeze({fn:'plainte_police',label:'Porter plainte',pa:1,cost:200});
 const originalMeta={fn:order.fn,cost:order.cost,pa:order.pa};
 const node={textContent:'Porter plainte',attrs:{'data-rp-order-index':'0'},
  getAttribute(key){return this.attrs[key]}};
 const input={value:'Texte saisi, inchangé'};
 const button={onclick(){return 'action originale'},disabled:false};
 const root={querySelectorAll(selector){
  return selector==='[data-rp-order-index]'?[node]:[];
 }};
 w.RPOrderI18n.registerRenderedOrders([order]);
 w.RPOrderI18n.refreshVisibleLabels(root,engine,'ar');
 assert.equal(node.textContent,'تقديم بلاغ');
 assert.equal(button.onclick(),'action originale');
 assert.equal(button.disabled,false);
 assert.equal(input.value,'Texte saisi, inchangé');
 assert.deepEqual({fn:order.fn,cost:order.cost,pa:order.pa},originalMeta);
 w.RPOrderI18n.refreshVisibleLabels(root,engine,'fr');
 assert.equal(node.textContent,'Porter plainte');
});
test('un changement de langue ne recalcule jamais les ordres dynamiques et ne touche pas les mauvais index',()=>{
 const order={fn:'plainte_police',label:'Porter plainte',pa:1,cost:200};
 const good={textContent:'Porter plainte',getAttribute:()=> '0'};
 const alien={textContent:'Ne pas modifier',getAttribute:()=> '400'};
 const root={querySelectorAll:()=>[good,alien]};
 w.RPOrderI18n.registerRenderedOrders([order]);
 w.RPOrderI18n.refreshVisibleLabels(root,engine,'de');
 assert.equal(good.textContent,'Anzeige erstatten');
 assert.equal(alien.textContent,'Ne pas modifier');
 assert.equal(order.label,'Porter plainte');
});

test('sous-menus ouverts après la bascule : rafraîchissement du texte existant, sans nouveau doOrder',()=>{
 const source=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
 for(const name of ['ouvrirMenuOrdresCommissaire','ouvrirMenuOrdresGreffe','ouvrirMenuOrdresTerrain','ouvrirMenuOrdresTribune']){
  const from=source.indexOf('function '+name+'(');
  const end=source.indexOf('\nfunction ',from+10);
  assert.ok(from>=0 && end>from,name);
  const code=source.slice(from,end);
  assert.ok(code.includes('refreshVisibleLabels?.('),name+' : texte du menu stale');
  assert.ok(code.indexOf('refreshVisibleLabels?.(')>code.indexOf("classList.add('open')"),name+' : le texte doit être mis à jour après insertion');
 }
});
