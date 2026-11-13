'use strict';
// Contrôle déterministe du premier lot de descriptions politiques propres à Républia.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const evalFn=(src,name)=>{const a=src.indexOf('function '+name+'(');const b=src.indexOf('\n}',a);assert.ok(a>=0&&b>a,name);return src.slice(a,b+2)};
const source=read('plateau-politique.js'),data=read('data.js');
function setup(country='republic',lang='en'){
 const context={RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>context.lang},lang};
 context.window=context;vm.createContext(context);
 vm.runInContext('var state = {country:'+JSON.stringify(country)+'};',context);
 vm.runInContext(evalFn(source,'deviseDansTexte'),context);
 vm.runInContext(evalFn(data,'montantDansTexte'),context);
 for(const f of ['i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/sovarka-infobulles-resources.js'])vm.runInContext(read(f),context,{filename:f});
 return context;
}
function orderDescs(country){
 const context={console,document:{getElementById(){return null},addEventListener(){},querySelector(){return null}},localStorage:{getItem(){return null}},state:{country}};
 context.window=context;vm.createContext(context);
 vm.runInContext(data.replace(/^const (WORLD|BUILDINGS) =/mg,'var $1 ='),context);
 const d=new Set();
 for(const city of Object.values(context.WORLD[country]||{}))for(const b of city.buildings||[]){
  const c=city.buildingContext?.[b]||{};
  for(const [r,room] of Object.entries({...(context.BUILDINGS[b]?.rooms||{}),...(c.roomsExtra||{})})){
   if(c.roomsExclues?.includes(r))continue;
   const ov=c.roomOverrides?.[r]||{};
   for(const o of [...context.ordresDeclaresDeLaPiece(room,c,r),...(ov.ordersExtra||[])])if(o?.desc)d.add(o.desc);
  }
 }
 return d;
}
test('171 descriptions du catalogue Républia : françaises exactes et réellement affichées',()=>{
 const rep=orderDescs('republic'),sov=orderDescs('soviet'),spec=[...rep].filter(d=>!sov.has(d));
 // Trois commandes militaires spécifiques de Républia sont exclues de Sovarka ; la gestion de la caserne reste commune.
 assert.equal(spec.length,146,'inventaire réel après cloisonnement des deux pays');
 const rows=setup('republic','fr').RP_INFOBULLES_REPUBLIA;
 assert.equal(rows.length,171);
 for(const line of rows){assert.equal(line.length,9,line[0]);assert.ok(rep.has(line[0]),line[0]);}
 assert.equal(new Set(rows.map(l=>l[0])).size,171);
});
test('Les 171 lignes sont présentes en neuf langues, sans perte de chiffres, devises ou sigles',()=>{
 const rows=setup('republic','en').RP_INFOBULLES_REPUBLIA;
 for(const line of rows){
  for(let i=1;i<line.length;i++){
   const translation=line[i],original=line[0];
   assert.ok(translation.trim(),original+' '+langs[i]);
   assert.notEqual(translation,original,'non traduit: '+original);
   assert.ok(!/[<>"]/.test(translation),'caractère HTML à revoir: '+translation);
   for(const n of original.match(/\d+/g)||[])assert.ok(translation.includes(n),n+' absent '+langs[i]+' : '+original);
   for(const acronym of ['FR','PA','POP','INF','DIS','IS','QHS','ISN'])if(new RegExp('\\b'+acronym+'\\b').test(original)&&acronym!=='PA')
    assert.match(translation,new RegExp('\\b'+acronym+'\\b'),acronym+' absent '+langs[i]+' : '+original);
  }
 }
});
test('Républia : neuf langues et changement de langue sans requête',()=>{
 const ctx=setup();
 const original='Candidatures, nomination (2 PA) et revocation (1 PA) du Premier ministre.';
 for(const [index,lang] of langs.entries()){
  ctx.lang=lang;
  const got=ctx.RPSovarkaInfobullesI18n.desc(original);
  assert.equal(got,ctx.RP_INFOBULLES_REPUBLIA[1][index],lang);
 }
});
test('Catalogue propre à Républia sans effet sur Sovarka, descriptions communes prioritaires',()=>{
 const rep=setup('republic','en'),sov=setup('soviet','en');
 const specific='Nommer un PJ a un poste ministeriel.';
 assert.equal(rep.RPSovarkaInfobullesI18n.desc(specific),'Appoint a player character to a ministerial position.');
 assert.equal(sov.RPSovarkaInfobullesI18n.desc(specific),specific);
 const common='Voir ce qui est disponible au bar et commander.';
 assert.equal(rep.RPSovarkaInfobullesI18n.desc(common),'See what is available at the bar and order.');
 assert.equal(sov.RPSovarkaInfobullesI18n.desc(common),'See what is available at the bar and order.');
 assert.equal(rep.RPSovarkaInfobullesI18n.desc('Ordre inconnu'),'Ordre inconnu');
});
test('Français exact, coûts et paramètres d’ordre non modifiés',()=>{
 const ctx=setup('republic','fr'),line=ctx.RP_INFOBULLES_REPUBLIA[1];
 assert.equal(ctx.RPSovarkaInfobullesI18n.desc(line[0]),line[0]);
 ctx.lang='en';
 const order=Object.freeze({fn:'nommer_premier_ministre',desc:line[0],cost:0,pa:0});
 const translated=ctx.RPSovarkaInfobullesI18n.descOrdre(order,{desc:line[0]},'FR',{cost:0,pa:0});
 assert.equal(translated,line[1]);assert.equal(order.desc,line[0]);assert.equal(order.cost,0);assert.equal(order.pa,0);
 const html=read('plateau.html');
 assert.ok(html.indexOf('republia-infobulles-resources.js')>html.indexOf('infobulles-communes-resources.js'));
 assert.ok(html.indexOf('republia-infobulles-resources.js')<html.indexOf('sovarka-infobulles-resources.js'));
});
