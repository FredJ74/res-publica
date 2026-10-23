// #57 — banque de controles non financiers du menu commun des cinq terrains.
const fs = require('fs');
const assert = require('node:assert/strict');
const data = fs.readFileSync('data.js','utf8');
const ui = fs.readFileSync('plateau-politique.js','utf8');
const start = data.indexOf('const ORDRES_TERRAIN_LUTHECIA = [');
const end = data.indexOf('];',start);
assert(start>=0 && end>start, 'Catalogue commun absent');
const source = data.slice(start,end+2);
const catalogue = Function(source + '\nreturn ORDRES_TERRAIN_LUTHECIA;')();
const unique = new Set(catalogue.map(o=>o.fn));
assert.equal(unique.size,catalogue.length,'Ordres dupliques');
for(const fn of ['acheter_terrain','signer_compromis','racheter_terrain',
 'negocier_squatteurs','appeler_police_terrain','faire_disparaitre_cadavre',
 'construire_sur_terrain','travailler_chantier','vendre_materiaux_chantier',
 'donner_materiaux_chantier','modifier_plan_chantier','reconfigurer_lots']) {
 assert(unique.has(fn),'Ordre valide absent : '+fn);
}
assert(!unique.has('corrompre_chantier'),'Acceleration payante interdite');
const expected={1:25800,2:27600,3:27600,4:22200,5:33000};
for(const [n,prix] of Object.entries(expected)){
 const k=data.indexOf("'terrain-a-batir-"+n+"':");
 assert(k>=0,'Terrain manquant '+n);
 const part=data.slice(k,k+2400);
 assert(part.includes('orders: ORDRES_TERRAIN_LUTHECIA.map'),'Catalogue different sur '+n);
 assert(part.includes('cost:'+prix),'Prix individuel incorrect sur '+n);
 assert(part.includes('imageUrl: "images/terrain-a-vendre-republic.webp"'),'Image terrain differente '+n);
 assert(/rooms:\s*\{\s*terrain:\s*\{/.test(part),'Salle non canonique '+n);
}
const a=ui.indexOf('const ordresTerrainLuthecia = (() => {');
const b=ui.indexOf('  const buttons = ordresTerrainLuthecia.map',a);
assert(a>=0&&b>a,'Filtrage contextuel manquant');
const exp=ui.slice(a,b);
const filtrer=Function('buildingId','roomId','getTerrainState','allOrders',
 'terrainOrdreDisponible','estTitulaire','verdictModificationPlan','chantierTermine',
 exp+'\nreturn ordresTerrainLuthecia;');
const test=(n,etat)=>new Set(filtrer('terrain-a-batir-'+n,'terrain',()=>etat,catalogue,
 (fn)=>({ok:(fn==='faire_disparaitre_cadavre'&&etat.pnj==='cadavre') ||
 (fn==='negocier_squatteurs'&&['squatter_agr','squatter_cool'].includes(etat.pnj))}),
 p=>p==='Alice',()=>({ok:true}),ch=>ch.progressionJours>=ch.dureeJours).map(x=>x.fn));
for(const n of [1,2,3,4,5]){
 let libre=test(n,{});
 assert(libre.has('acheter_terrain')&&libre.has('signer_compromis'),'Achat incomplet '+n);
 assert(!libre.has('racheter_terrain')&&!libre.has('construire_sur_terrain'),'Mauvaise phase '+n);
 let squatteurs=test(n,{pnj:'squatter_cool'});
 assert(squatteurs.has('negocier_squatteurs')&&squatteurs.has('appeler_police_terrain'),'Squatteurs '+n);
 let cadavre=test(n,{pnj:'cadavre'});
 assert(cadavre.has('faire_disparaitre_cadavre')&&!cadavre.has('negocier_squatteurs'),'Cadavre '+n);
 let tiers=test(n,{proprietaire:'Bob'});
 assert(tiers.has('racheter_terrain')&&!tiers.has('construire_sur_terrain'),'Droits tiers '+n);
 let proprio=test(n,{proprietaire:'Alice'});
 assert(proprio.has('construire_sur_terrain'),'Droits constructeur '+n);
 let chantier=test(n,{proprietaire:'Alice',chantier:{progressionJours:2,dureeJours:6}});
 assert(chantier.has('travailler_chantier')&&chantier.has('donner_materiaux_chantier'),'Chantier '+n);
 let livre=test(n,{proprietaire:'Alice',niveau_construction:'commerce_premium'});
 assert(livre.has('reconfigurer_lots')&&!livre.has('acheter_terrain'),'Livraison '+n);
}
// Un visiteur ne doit jamais obtenir les commandes reservees au titulaire.
for(const n of [1,2,3,4,5]){
  const id='terrain-a-batir-'+n;
  const enCours={proprietaire:'Bob',chantier:{progressionJours:2,dureeJours:6}};
  const visible=filtrer(id,'terrain',()=>enCours,catalogue,()=>({ok:false}),
    x=>x==='Alice',()=>({ok:false}),()=>false).map(o=>o.fn);
  assert(!visible.includes('payer_versement_chantier'),'Un tiers voit les versements du chantier '+n);
  assert(!visible.includes('modifier_plan_chantier'),'Le plan est disponible avant son dernier tiers '+n);
  assert(!visible.includes('receptionner_chantier'),'Reception prematuree '+n);
}
console.log('OK — 5 terrains, image, prix, catalogue et phases conformes.');
