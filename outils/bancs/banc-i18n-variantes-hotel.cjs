'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const ctx=vm.createContext({window:{}});
for(const file of ['resources.js','orders-resources.js','order-variants-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const w=ctx.window;
const engine={t(key,{lng,defaultValue}){return key.split('.').reduce((v,k)=>v?.[k],w.RP_I18N_RESOURCES[lng].translation)??defaultValue}};

test('réservation simple et standard : 9 traductions contextuelles, identifiants métiers intacts',()=>{
 const languages=Object.keys(w.RP_I18N_LANGUAGES);
 assert.equal(languages.length,9);
 for(const lng of languages) {
  const vars=w.RP_I18N_RESOURCES[lng].translation.orderVariants;
  assert.equal(Object.keys(vars).length,47);
  for(const value of Object.values(vars))assert.ok(value.trim());
 }
 for(const [key,original,cost] of [
  ['hotel_basic','Reserver une chambre',80],
  ['hotel_standard',"Réserver une chambre d'hôtel",60]
 ]) {
  const order=Object.freeze({fn:'reserver_chambre_hotel',i18nKey:'variant.'+key,label:original,cost,pa:0,requiresPost:null});
  for(const lng of languages) {
   const expected=w.RP_I18N_RESOURCES[lng].translation.orderVariants[key];
   assert.equal(w.RPOrderI18n.label(order,engine,lng),expected,lng+':'+key);
  }
  assert.equal(order.label,original);assert.equal(order.cost,cost);
  assert.equal(order.pa,0);assert.equal(order.fn,'reserver_chambre_hotel');
 }
});

test('trois ordres existants portent leur variante ; aucun nouveau fn ni modification du coût',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const found=[...data.matchAll(/fn:'reserver_chambre_hotel',\s*label:'((?:\\.|[^'])*)',\s*i18nKey:'variant\.(hotel_basic|hotel_standard)',\s*pa:0,\s*cost:(\d+)/g)];
 assert.equal(found.length,3);
 assert.equal(found.filter(x=>x[2]==='hotel_basic'&&x[3]==='80').length,1);
 assert.equal(found.filter(x=>x[2]==='hotel_standard'&&x[3]==='60').length,2);
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 assert.ok(html.indexOf('i18n/order-variants-resources.js')>html.indexOf('i18n/orders-resources.js'));
 assert.ok(html.indexOf('i18n/ordres.js')>html.indexOf('i18n/order-variants-resources.js'));
});

test('un ordre ambigu sans i18nKey ne reçoit aucune traduction par défaut',()=>{
 const order={fn:'reserver_chambre_hotel',label:'Réserver une chambre spéciale',pa:0,cost:0};
 assert.equal(w.RPOrderI18n.ambiguous(order.fn),true);
 assert.equal(w.RPOrderI18n.label(order,engine,'en'),order.label);
});


test('sept rumeurs et deux conférences disposent de variantes sûres',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const rumours=[...data.matchAll(/fn:'ecouter_rumeurs',\s*label:'((?:\\.|[^'])*)',\s*i18nKey:'variant\.(rumours_[a-z]+)'/g)];
 const press=[...data.matchAll(/fn:'conference_presse',\s*label:'((?:\\.|[^'])*)',\s*i18nKey:'variant\.press_conference'/g)];
 assert.equal(rumours.length,7);
 assert.equal(press.length,2);
 const expected=['rumours_tables','rumours_barman','rumours_general','rumours_owner','rumours_waitress','rumours_listen'];
 for(const key of expected)assert.ok(rumours.some(match=>match[2]===key),key);
 for(const lng of Object.keys(w.RP_I18N_LANGUAGES)){
  const words=w.RP_I18N_RESOURCES[lng].translation.orderVariants;
  for(const key of [...expected,'press_conference']){
   assert.ok(words[key]?.trim(),lng+'/'+key);
   const original=key==='press_conference'?'Conférence de presse':key;
   const order=Object.freeze({fn:key==='press_conference'?'conference_presse':'ecouter_rumeurs',
    label:original,i18nKey:'variant.'+key,pa:2,cost:31,requiresPost:'test'});
   assert.equal(w.RPOrderI18n.label(order,engine,lng),words[key]);
   assert.equal(order.cost,31);assert.equal(order.pa,2);assert.equal(order.requiresPost,'test');
  }
 }
});


test('66 ordres de commerces et banque localisés par contexte, sans altérer leur coût',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const expected={produire_commerce:14,consulter_carte_commerce:11,vendre_matiere_commerce:16,gerer_finances:3,gerer_local:22};
 const keys={
  produire_commerce:['commerce_produce_market','commerce_cook','commerce_prepare_drinks','commerce_serve','commerce_breakfast_prep','commerce_produce'],
  consulter_carte_commerce:['commerce_menu','commerce_breakfast_menu'],
  vendre_matiere_commerce:['commerce_sell_market','commerce_sell_business'],
  gerer_finances:['finance_account_placements','finance_open_account'],
  gerer_local:['local_manage','local_safe']
 };
 for(const [fn,count] of Object.entries(expected)){
  const regex=new RegExp("fn:'"+fn+"',\\s*label:'((?:\\\\.|[^'])*)',\\s*i18nKey:'variant\\.([a-z_]+)',\\s*pa:(\\d+),\\s*cost:(\\d+)",'g');
  const matches=[...source.matchAll(regex)];
  assert.equal(matches.length,count,fn);
  for(const m of matches){
   const key=m[2];assert.ok(keys[fn].includes(key),fn+'/'+key);
   const sourceLabel=m[1].replace(/\\u([0-9a-fA-F]{4})/g,(_,hex)=>String.fromCharCode(parseInt(hex,16))).replace(/\\(['"\\])/g,'$1');
   const order=Object.freeze({fn,label:sourceLabel,i18nKey:'variant.'+key,pa:Number(m[3]),cost:Number(m[4])});
   for(const lng of Object.keys(w.RP_I18N_LANGUAGES)){
    const translation=w.RP_I18N_RESOURCES[lng].translation.orderVariants[key];
    assert.ok(translation?.trim(),lng+'/'+key);
    assert.equal(w.RPOrderI18n.label(order,engine,lng),translation);
   }
   assert.equal(order.fn,fn);assert.equal(order.pa,Number(m[3]));assert.equal(order.cost,Number(m[4]));
   assert.equal(order.label,sourceLabel);
  }
 }
});

test('les quatre cultes et leurs dons gardent la bonne traduction par empire dans neuf langues',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const {extract}=require('../audits/libelles-ordres-source.cjs');
 const rows=extract(source);
 const forms=[
  ['prier','Prier le Formulaire Sacré','religion_formulaire'],
  ['prier','Communier avec la Feuille','religion_feuille'],
  ['prier',"Chanter l'hymne au Tracteur",'religion_tracteur'],
  ['prier','Communier avec le Loukoum','religion_loukoum'],
  ['faire_don',"Faire un don a l'Eglise",'don_eglise'],
  ['faire_don','Faire une offrande','don_offrande'],
  ['faire_don','Donner au Kolkhoze','don_kolkhoze'],
  ['faire_don','Offrir des loukoums','don_loukoums']
 ];
 for(const [fn,label,key] of forms){
  assert.ok(rows.some(item=>item.fn===fn && item.label===label),'forme canonique absente '+fn+'/'+label);
  const order=Object.freeze({fn,label,pa:4,cost:83,requiresPost:'rite_test',successRate:23});
  for(const locale of Object.keys(w.RP_I18N_LANGUAGES)){
   const translation=w.RP_I18N_RESOURCES[locale].translation.orderVariants[key];
   assert.ok(translation?.trim(),locale+'/'+key);
   assert.equal(w.RPOrderI18n.label(order,engine,locale),translation,locale+'/'+key);
  }
  assert.equal(order.fn,fn);
  assert.equal(order.label,label);
  assert.equal(order.pa,4);
  assert.equal(order.cost,83);
  assert.equal(order.requiresPost,'rite_test');
  assert.equal(order.successRate,23);
 }
 // Aucune variante n'est déduite d'une chaîne inconnue, même à fn identique.
 for(const fn of ['prier','faire_don']){
  const unknown=Object.freeze({fn,label:'Cérémonie temporaire',pa:1,cost:7});
  assert.equal(w.RPOrderI18n.label(unknown,engine,'ru'),unknown.label);
 }
 // Les libellés inconnus, ou une traduction absente, reviennent au français.
 const noVariant={t:(_key,opts)=>opts.defaultValue};
 assert.equal(w.RPOrderI18n.label({fn:'prier',label:'Communier avec la Feuille'},noVariant,'ko'),'Communier avec la Feuille');
});

test('seize autres variantes ambiguës sont traduites par le couple fn et libellé exact',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const {extract}=require('../audits/libelles-ordres-source.cjs');
 const records=extract(source);
 const variants={
  propagande_etat:[["Propagande d'Etat",'politics_propaganda_state'],['Campagne de propagande','politics_propaganda_campaign']],
  dementi:[['Dementi officiel','politics_denial_plain'],['Démenti officiel','politics_denial_accent']],
  archives_police:[['Consulter les archives','police_archives'],['Consulter le registre','police_register']],
  repartition_budget_local:[['Repartir le budget municipal','budget_plain'],['Répartir le budget municipal','budget_accent']],
  receptionner_commande:[['Réceptionner une caisse','shipment_receive_crate'],['Réceptionner une commande','shipment_receive_order']],
  expedier_colis:[['Réserver une caisse de fret','shipment_book_crate'],['Expédier un colis','shipment_send_parcel']],
  corrompre_fonctionnaire_permis:[['Corrompre un fonctionnaire (accélérer)','permit_bribe_general'],['Corrompre un fonctionnaire (accélérer le permis)','permit_bribe_permit']],
  corrompre_fonct:[['Corrompre le directeur','corruption_director'],['Falsifier un proces-verbal','corruption_false_report']]
 };
 for(const [fn,labels] of Object.entries(variants))for(const [original,key] of labels){
  assert.ok(records.some(row=>row.fn===fn&&row.label===original),'ordre déclaré manquant '+fn+'/'+original);
  const order=Object.freeze({fn,label:original,pa:2,cost:430,requiresPost:'test',successRate:41});
  for(const locale of Object.keys(w.RP_I18N_LANGUAGES)){
   const expected=w.RP_I18N_RESOURCES[locale].translation.orderVariants[key];
   assert.ok(expected?.trim(),locale+'/'+key);
   assert.equal(w.RPOrderI18n.label(order,engine,locale),expected,locale+'/'+key);
  }
  assert.equal(order.label,original);assert.equal(order.pa,2);
  assert.equal(order.cost,430);assert.equal(order.requiresPost,'test');
  assert.equal(order.successRate,41);
 }
 for(const fn of Object.keys(variants)){
  const order={fn,label:'Variante sans équivalent dans le catalogue',pa:1,cost:1};
  assert.equal(w.RPOrderI18n.label(order,engine,'es'),order.label);
 }
});
