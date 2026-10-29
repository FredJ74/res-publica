// Toutes les villes de Republia : mêmes ordres de location et premium selon la nature du local.
'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path');
const data=fs.readFileSync(path.join(__dirname,'../../data.js'),'utf8');
const loc=fs.readFileSync(path.join(__dirname,'../../plateau-justice-economie.js'),'utf8');
const commerce=fs.readFileSync(path.join(__dirname,'../../plateau-commerce-pj.js'),'utf8');
const v=fs.readFileSync(path.join(__dirname,'../../plateau-variantes-pieces.js'),'utf8');
const specs={
 'centre-commercial':['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve'],
 'centre-artisanal':['echoppe_facade','atelier_milieu','reserve_arriere'],
 'centre-affaires':['bureau_prestige','bureau_standard','open_space']
};
for(const [batiment,pieces] of Object.entries(specs)){
 const marker="'"+batiment+"': {";
 const start=data.indexOf(marker,data.indexOf('V28A — CENTRES COMMERCIAUX'));
 const next=batiment==='centre-commercial'?"  'centre-artisanal': {":batiment==='centre-artisanal'?"  'centre-affaires': {":"  'centre-";
 const end=data.indexOf(next,start+marker.length);
 const building=data.slice(start,end>start?end:undefined);
 for(const id of pieces){
  const i=building.indexOf('      '+id+': {');
  assert.ok(i>=0,batiment+'/'+id+' déclaré');
  const j=building.indexOf('\n      },',i);
  const room=building.slice(i,j>i?j:undefined);
  assert.ok(room.includes('isLocationRoom: true'),batiment+'/'+id+' louable');
  for(const fn of ['louer_local','gerer_local'])
    assert.ok(room.includes("fn:'"+fn+"'"),batiment+'/'+id+' '+fn);
  if(batiment!=='centre-affaires')assert.ok(room.includes("fn:'commerce_pj'"),batiment+'/'+id+' commerce');
  else assert.ok(room.includes('ORDRE_EQUIPEMENTS'),id+' équipement bureau');
 }
}
const i=loc.indexOf('async function chargerLocations()');
const chunk=loc.slice(i,loc.indexOf('\n}',i)+2);
for(const b of Object.keys(specs))assert.ok(chunk.includes("'"+b+"'"),b+' rechargement');
for(const city of ['capitale','ville_a','ville_b'])assert.ok(chunk.includes("'"+city+"'"),city+' rechargement');
assert.ok(chunk.indexOf('state.locationsActives = locations')<chunk.indexOf('renderRoomActions(room, batiment, piece)'), 'baux chargés avant les ordres');
assert.ok(commerce.includes("fn: 'commerce_personnaliser'"),'premium commun');
assert.ok(commerce.includes("if (moi && titulaire === moi)"),'prime au titulaire uniquement');
assert.ok(commerce.includes("return buildingId === 'centre-affaires'"),'bureau jamais traité comme boutique commerciale');
assert.ok(v.includes('PIECE_VARIANTES.republic.ville_a'), 'variantes centre commercial PSM');
console.log('OK — 3 villes x 3 centres : ordres de bail, premium commerce/artisan, équipements bureaux');
