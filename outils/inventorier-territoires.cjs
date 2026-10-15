// node outils/inventorier-territoires.cjs [--json]
// Inventaire du casting et des declarations, pas un certificat de fonctionnement.
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const ctx=vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
const inventaire=vm.runInContext(`(() => {
 const villes=[];
 for(const [pays,territoires] of Object.entries(VILLES))for(const [ville,definition] of Object.entries(territoires)){
  const cite=WORLD[pays]?.[ville];
  const ligne={pays,ville,nom:definition.nom,batiments:0,pieces:0,ordres:0,pnj:0,
   gabaritsAbsents:[],images:[],nominations:[],continuite:[]};
  for(const id of cite?.buildings||[]){
   const b=BUILDINGS[id];ligne.batiments++;
   if(!b){ligne.gabaritsAbsents.push(id);continue;}
   const local=cite.buildingContext?.[id];
   for(const [pieceId,piece] of Object.entries({...b.rooms,...local?.roomsExtra})){
    const surcharge=local?.roomOverrides?.[pieceId];
    const ordres=ordresDeclaresDeLaPiece(piece,local,pieceId);
    const personnes=surcharge?.persons||piece.persons||[];
    ligne.pieces++;ligne.ordres+=ordres.length;ligne.pnj+=personnes.length;
    if(ordres.some(o=>o.fn==='nominations_municipales'))ligne.nominations.push(id+'/'+pieceId);
    for(const p of personnes)if(p.posteLectureFraiche)ligne.continuite.push({piece:id+'/'+pieceId,nom:p.name,poste:p.job});
    const image=surcharge?.imageUrl||ROOM_IMAGES_EMPIRE[pays]?.[id]?.[pieceId]||piece.imageUrl;
    if(image)ligne.images.push({piece:id+'/'+pieceId,url:image});
   }
  }
  villes.push(ligne);
 }
 return villes;
})()`,ctx);
for(const ville of inventaire){
 ville.imagesLocalesAbsentes=ville.images.filter(i=>i.url.startsWith('images/')
  && !fs.existsSync(path.join(root,i.url.split('?')[0])));
 delete ville.images;
}
if(process.argv.includes('--json'))console.log(JSON.stringify(inventaire,null,2));
else {
 console.log('| Empire | Ville | Bâtiments | Pièces | Ordres statiques | Cartes PNJ | Nominations | Images locales absentes |');
 console.log('|---|---|---:|---:|---:|---:|---:|---:|');
 for(const v of inventaire)console.log(`| ${v.pays} | ${v.nom} | ${v.batiments} | ${v.pieces} | ${v.ordres} | ${v.pnj} | ${v.nominations.length} | ${v.imagesLocalesAbsentes.length} |`);
 console.log('\nDéclarations uniquement : les ordres dynamiques, conditions et droits serveur ne sont pas déduits de ces comptes.');
}
