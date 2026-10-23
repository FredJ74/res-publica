const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const s=fs.readFileSync('plateau-politique.js','utf8');
const a=s.indexOf('  const achatTerrainBloqueParIntrus ='),b=s.indexOf('  const buttons = ordresTerrainLuthecia.map',a);
const c=s.indexOf('    // Verifier requiresPost',b);
const g=s.indexOf('  // #57 — groupes de commandes',c),h=s.indexOf('  // Informations de lecture seule',g);
const message='Achat impossible, vous devez libérer le terrain en gérant les intrus';
function rendu(pnj,lot=1){
 const contexte={buildingId:'terrain-a-batir-'+lot,roomId:'terrain',window:{},getTerrainState:()=>({pnj}),terrainOrdreDisponible:fn=>({ok:fn==='negocier_squatteurs'?String(pnj).startsWith('squatter'):fn==='faire_disparaitre_cadavre'?pnj==='cadavre':!pnj}),allOrders:['acheter_terrain','signer_compromis','negocier_squatteurs','appeler_police_terrain','faire_disparaitre_cadavre'].map(fn=>({fn,label:fn,icon:'ti-test'}))};
 const code=s.slice(a,b)+s.slice(b,c)+"return '<button>'+o.fn+'</button>';\n});\n"+s.slice(g,h)+'\n({html:buttons.join(""),ordres:ordresTerrainLuthecia.map(o=>o.fn),groupes:window._terrainOrdresGroupes});';
 return vm.runInNewContext(code,contexte);
}
test('les cinq parcelles gardent achat visible et inactif avec chaque occupation',()=>{
 for(let lot=1;lot<=5;lot++)for(const pnj of ['cadavre','squatter_cool','squatter_agr']){
  const r=rendu(pnj,lot);assert.match(r.html,/Achat de terrains/);assert.match(r.html,/Gestion des intrus/);
  assert.doesNotMatch(r.html.replace(/<[^>]*>/g,''),/Achat impossible/);
  assert.match(r.html,/aria-disabled="true" onclick="expliquerAchatTerrainBloque\(\)"/);
  const groupe=Object.values(r.groupes).find(g=>g.titre==='Achat de terrains');
  assert.equal(groupe.entries.length,2);
  for(const e of groupe.entries){assert.match(e.html,/disabled/);assert.doesNotMatch(e.html,/onclick|doOrder/);}
 }
});
test('terrain libre : achat actif et aucune gestion des intrus',()=>{
 const r=rendu(null);assert.match(r.html,/Achat de terrains/);assert.match(r.html,/ouvrirMenuOrdresTerrain/);
 assert.doesNotMatch(r.html,/disabled|Gestion des intrus/);
});
