'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const files=['i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/order-catalogues-config.js','i18n/sovarka-infobulles-resources.js'];
const shared='Voir ce qui est disponible au bar et commander.';
function load(country,language='en',original=false){
 const c={RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>language},state:{country},RPC:[]};c.window=c;vm.createContext(c);
 for(const f of files){if(original&&f==='i18n/order-catalogues-config.js')continue;
  const source=original?execFileSync('git',['show','1163bad:'+f],{cwd:root,encoding:'utf8',maxBuffer:4e6}):read(f);vm.runInContext(source,c);}
 return c;
}
test('anciennes traductions conservées ; les anciens replis français peuvent bénéficier du catalogue commun',()=>{
 for(const country of ['republic','soviet'])for(const lang of langs){const a=load(country,lang),b=load(country,lang,true),I=a.RPOrderDescriptionsI18n,B=b.RPSovarkaInfobullesI18n;
  assert.equal(I,a.RPSovarkaInfobullesI18n);
  for(const row of [...B.communes,...B.republia,...B.lignes]){
   const previous=B.desc(row[0]),sharedRow=I.communes.find(r=>r[0]===row[0]);
   // Une traduction déjà livrée reste exacte ; un ancien repli français peut désormais
   // recevoir la traduction déclarée du catalogue partagé (sans figer ses anciens manques).
   const expected=previous===row[0]&&sharedRow?(sharedRow[langs.indexOf(lang)]||row[0]):previous;
   assert.equal(I.desc(row[0]),expected,country+'/'+lang+': '+row[0]);
  }
 }
});
test('troisième empire déclaré : commun hérité, propres isolées, français et absence de langue conservés',()=>{
 for(const lang of langs){const c=load('fixture',lang),I=c.RPOrderDescriptionsI18n;
  assert.equal(I.desc(shared),I.communes.find(r=>r[0]===shared)[langs.indexOf(lang)]);
  const entry=Object.fromEntries(langs.map(l=>[l,l==='fr'?'Description nouvelle.':l+' description.']));entry.ar='';entry.id='orders.description.fixture.new';
  assert.equal(I.registerCatalogue({id:'fixture',countries:['fixture'],entries:[entry]}),true);
  assert.equal(I.desc('Français reformulé.',entry.id),lang==='fr'||lang==='ar'?'Français reformulé.':entry[lang]);
  assert.equal(I.desc('Inconnu.'),'Inconnu.');assert.equal(I.desc(shared,'unknown.key'),shared);
  assert.equal(I.desc(entry.fr,entry.id,'republic'),entry.fr);assert.equal(I.desc(entry.fr,entry.id,'soviet'),entry.fr);
  assert.equal(I.desc(I.lignes[0][0]),I.lignes[0][0]);assert.equal(I.desc(I.republia[0][0]),I.republia[0][0]);
 }
});
test('priorité au catalogue partagé, ID indépendant du français et ordre des entrées sans importance',()=>{
 const c=load('fixture'),I=c.RPOrderDescriptionsI18n;
 assert.equal(I.desc('Nouvelle formulation.','orders.description.common.bar-menu'),I.desc(shared));
 assert.equal(I.registerCatalogue({id:'private',countries:['fixture'],rows:[[shared,...langs.slice(1).map(()=> 'Override')]]}),true);
 assert.notEqual(I.desc(shared),'Override');
 const entries=[{id:'fixture.two',fr:'Deux',en:'Two'},{id:'fixture.one',fr:'Un',en:'One'}];
 assert.equal(I.registerCatalogue({id:'reordered',countries:['fixture'],entries}),true);assert.equal(I.desc('Autre formulation','fixture.one'),'One');
});
test('paramètres nationaux, repli de la copie déjà tarifée et données métier restent intacts',()=>{
 const c=load('fixture'),I=c.RPOrderDescriptionsI18n;const entry={id:'fixture.price',fr:'Payer 10 FR.',en:'Pay 10 FR.'};
 I.registerCatalogue({id:'prices',countries:['fixture'],entries:[entry]});c.deviseDansTexte=(s,d)=>s.replace(/\bFR\b/g,d);c.montantDansTexte=(s,a,b)=>s.replace(String(a),String(b));
 const src={desc:entry.fr,descriptionKey:entry.id,cost:10,pa:1},shown={desc:'Payer 20 ECO.'},tariff={cost:20,pa:2};const snapshot=JSON.stringify({src,shown,tariff});
 assert.equal(I.descOrdre(src,shown,'ECO',tariff),'Pay 20 ECO.');assert.equal(JSON.stringify({src,shown,tariff}),snapshot);
 assert.equal(I.descOrdre({...src,descriptionKey:'unknown'},shown,'ECO',tariff),shown.desc);assert.deepEqual(c.RPC,[]);
});
test('configurations invalides refusées sans erreur, fuite nationale ou remplacement silencieux',()=>{
 const I=load('fixture').RPOrderDescriptionsI18n;
 for(const spec of [null,{id:'x',rows:[]},{id:'x',shared:true,countries:{}},{id:'x',shared:true,entries:{}},{id:'common',shared:true},
  {id:'x',shared:true,rows:[['a']]},{id:'x',shared:true,entries:[{id:'bad key',fr:'a'}]}])assert.equal(I.registerCatalogue(spec),false);
 assert.equal(I.desc('Pas de ressource'),'Pas de ressource');
});
test('déclaration partielle ou invalide avant chargement : traductions communes et nationales conservées',()=>{
 for(const config of [[],[{id:'extra',countries:['fixture'],entries:[{id:'extra.new',fr:'Nouveau',en:'New'}]}],[{id:'common',shared:true,rows:'invalid'}]]){
  const c={RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=> 'en'},state:{country:'fixture'}};c.window=c;vm.createContext(c);
  for(const f of files.filter(f=>f.includes('infobulles-')&&!f.includes('sovarka-')))vm.runInContext(read(f),c);
  c.RP_ORDER_DESCRIPTION_CATALOGUES=config;vm.runInContext(read('i18n/sovarka-infobulles-resources.js'),c);
  assert.equal(c.RPOrderDescriptionsI18n.desc(shared),'See what is available at the bar and order.');
  c.state.country='republic';const row=c.RPOrderDescriptionsI18n.republia[0];assert.equal(c.RPOrderDescriptionsI18n.desc(row[0]),row[1]);
 }
});
test('métadonnées seulement dans le renderer ; données, catalogues et handlers métier inchangés',()=>{
 const base=execFileSync('git',['merge-base','origin/main','HEAD'],{cwd:root,encoding:'utf8'}).trim();
 const original=execFileSync('git',['show',base+':plateau-politique.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6});
 // Garde de migration de ce lot, désactivée une fois la métadonnée intégrée à main.
 // Ne pas figer data.js ou tout le renderer contre les futurs chantiers de jeu.
 if(!original.includes("q: ordreSource.descriptionKey || '', ")){
  assert.equal(read('plateau-politique.js').replace("q: ordreSource.descriptionKey || '', ",''),original);
  for(const file of ['data.js','plateau-ordres-info.js','i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js'])assert.equal(read(file),execFileSync('git',['show',base+':'+file],{cwd:root,encoding:'utf8',maxBuffer:4e6}));
 }
 assert.match(read('plateau-politique.js'),/q: ordreSource.descriptionKey/);
 assert.match(read('plateau.html'),/order-catalogues-config\.js/);
});
