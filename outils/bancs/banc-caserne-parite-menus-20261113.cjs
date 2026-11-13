'use strict';
const { test }=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const data=fs.readFileSync('data.js','utf8');
const plateau=fs.readFileSync('plateau-politique.js','utf8');
const navigation=fs.readFileSync('plateau-navigation.js','utf8');
const traductions=fs.readFileSync('i18n/room-actions-resources.js','utf8');
const context=vm.createContext({});
vm.runInContext(data,context);
const pieces=['corps_garde','infirmerie','salle_commandement','armurerie_militaire','refectoire','salle_faits_armes','quartier_troupes'];
function ordres(country,ville,piece) {
 const exp=`ordresDeclaresDeLaPiece(BUILDINGS['caserne-militaire'].rooms[${JSON.stringify(piece)}],WORLD[${JSON.stringify(country)}][${JSON.stringify(ville)}]?.buildingContext?.['caserne-militaire'],${JSON.stringify(piece)})`;
 return Array.from(vm.runInContext(exp,context),o=>({fn:o.fn,pa:o.pa,cost:o.cost,requiresPost:JSON.stringify(o.requiresPost??null)}));
}
function famille(piece) {
 const a=plateau.indexOf("const familles = roomId === 'corps_garde'");
 const b=plateau.indexOf('window._caserneOrdresGroupes = {}',a);
 assert.ok(a>=0&&b>a,'configuration des menus de caserne');
 const ctx=vm.createContext({roomId:piece});
 vm.runInContext(plateau.slice(a,b).replace('const familles =','var familles =')+'\nthis.resultat=familles;',ctx);
 return Array.from(ctx.resultat,f=>({titre:f.titre,cle:f.cle,fns:Array.from(f.fns)}));
}
test('Sept pièces identiques et sept illustrations Sovarka effectivement livrées',()=>{
 const contextSov=vm.runInContext("WORLD.soviet.capitale.buildingContext['caserne-militaire']",context);
 for(const p of pieces) {
  const source=vm.runInContext(`BUILDINGS['caserne-militaire'].rooms[${JSON.stringify(p)}]`,context);
  assert.ok(source,p);
  assert.ok(contextSov.roomOverrides[p]?.imageUrl,'illustration '+p);
  assert.ok(fs.existsSync(contextSov.roomOverrides[p].imageUrl),contextSov.roomOverrides[p].imageUrl);
 }
 assert.match(navigation,/roomOverride\?\.imageUrl \|\| empireRoomImg \|\| room\.imageUrl/);
});
test('Les ordres de Republia sont tous conservés à Novomirsk avec les mêmes coûts et accès',()=>{
 for(const p of pieces){
  const rep=ordres('republic','caserne',p),sov=ordres('soviet','capitale',p);
  for(const o of rep)assert.deepEqual(sov.find(x=>x.fn===o.fn),o,p+' / '+o.fn);
  const propres=sov.filter(x=>!rep.some(r=>r.fn===x.fn));
  if(p==='corps_garde')assert.deepEqual(propres.map(x=>x.fn),['sovarka_conscrit_presenter']);
  else assert.equal(propres.length,0,p);
 }
});
test('Les menus conservent sans duplication chaque ordre de service',()=>{
 for(const p of ['corps_garde','salle_commandement']){
  const original=ordres('republic','caserne',p).map(o=>o.fn);
  const groupes=famille(p);
  assert.equal(groupes.length,3,'trois menus '+p);
  const fns=groupes.flatMap(g=>g.fns);
  assert.equal(fns.length,new Set(fns).size,'pas de doublon '+p);
  assert.deepEqual([...fns].sort(),original.sort(),'aucun ordre égaré '+p);
  assert.ok(groupes.every(g=>g.cle&&g.titre),'titres non vides');
 }
});
test('Les autres ordres, notamment la conscription, restent directement présents',()=>{
 assert.match(plateau,/const nonClasses = ordresTerrainLuthecia\.map\(\(ordre, i\) => utilises\.has\(ordre\.fn\) \? '' : buttons\[i\]\)/);
 assert.ok(!famille('corps_garde').some(g=>g.fns.includes('sovarka_conscrit_presenter')));
});
test('Les sous-menus reprennent les boutons existants et les contrôles de pays/poste',()=>{
 assert.match(plateau,/function ouvrirMenuOrdresCaserne\(index\)/);
 assert.match(plateau,/e\.html \+ '<\/div>'/);
 assert.match(plateau,/html: buttons\[i\]/);
 assert.match(plateau,/state\.currentRoom !== groupe\.piece/);
 assert.match(plateau,/state\.country !== groupe\.pays/);
 assert.match(plateau,/state\.currentCity !== groupe\.ville/);
 assert.match(plateau,/if \(o\.requiresPost && !needsPost && paysMandatPourOrdre\(\) !== state\.country\)/);
});
test('Six titres de menus traduits dans les neuf langues sans modifier les ordres',()=>{
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const ressources=Object.fromEntries(locales.map(k=>[k,{translation:{}}]));
 const w={RP_I18N_RESOURCES:ressources,RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=> 'fr'}};
 const ctx=vm.createContext({window:w});
 vm.runInContext(traductions,ctx);
 for(const locale of locales)
  for(const key of ['caserneEngagement','caserneService','caserneRecrutement','caserneCommandement','caserneSection','caserneBudget'])
   assert.ok(ressources[locale].translation.roomActions[key],locale+' '+key);
 assert.equal(w.RPRoomActionsI18n.label('caserneEngagement','Engagement et affectation'),'Engagement et affectation');
 w.RPPlateauI18n.language=()=> 'en';
 assert.equal(w.RPRoomActionsI18n.label('caserneBudget','Budget et stratégie'),'Budget and strategy');
});
