'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const code=fs.readFileSync('plateau-open-space.js','utf8');
const data=fs.readFileSync('data.js','utf8');
const dir='images/Sovarka/Starovka/';
const postes=['open_space_a','open_space_b','open_space_c','open_space_d'];

function scene(country,city) {
 const zones=[], opened=[];
 const cadre={
  clientWidth:1448,clientHeight:1086,dataset:{},
  querySelectorAll:()=>zones.slice(),
  querySelector:selector=>zones.find(z=>selector.includes(z.dataset.piece))||null,
  appendChild:el=>zones.push(el)
 };
 const document={
  getElementById:id=>id==='piece-image'?cadre:null,
  createElement:()=>({className:'',dataset:{},style:{},handlers:{},addEventListener(name,fn){this.handlers[name]=fn;},
   remove(){const k=zones.indexOf(this);if(k>=0)zones.splice(k,1);}})
 };
 const ctx={document,state:{country,currentCity:city},window:{},
   varianteDePiece:()=>country==='republic'?{}:null,
   varianteTailleNaturelle:async()=>({l:1448,h:1086}),
   varianteZoneEnPixels:(z,c)=>({gauche:z.x*1448,haut:z.y*1086,largeur:z.w*1448,hauteur:z.h*1086}),
   enterRoom:(b,r)=>opened.push([b,r]),
   getLocationPourRoom:()=>null};
 vm.createContext(ctx);vm.runInContext(code,ctx);
 return {ctx,zones,opened,cadre};
}

test('Starovka : quatre postes cliquables uniquement sur la vue générale',async()=>{
 const v=scene('soviet','ville_a');
 vm.runInContext("openSpaceInjecterZones('centre-affaires','open_space','ville_a')",v.ctx);
 assert.equal(v.zones.length,4);
 assert.equal(v.cadre.dataset.osPlan,'starovka-centre-affaires');
 await Promise.resolve();
 for(let i=0;i<4;i++){
  const z=v.zones[i];
  assert.equal(z.dataset.piece,postes[i]);
  assert.ok(Number.parseFloat(z.style.width)>50,z.dataset.piece);
  z.handlers.click();
  assert.deepEqual(v.opened[i],['centre-affaires',postes[i]]);
 }
 vm.runInContext("openSpaceInjecterZones('centre-affaires','open_space_c','ville_a')",v.ctx);
 assert.equal(v.zones.length,0,'Les cibles disparaissent en entrant dans un poste');
});

test('Luthécia : conserver les zones originales et aucun clic hors des deux villes',()=>{
 const rep=scene('republic','capitale');
 vm.runInContext("openSpaceInjecterZones('centre-affaires','open_space','capitale')",rep.ctx);
 assert.equal(rep.zones.length,4);
 assert.equal(rep.cadre.dataset.osPlan,'centre-affaires');
 for(const [country,city] of [['soviet','ville_b'],['republic','ville_a'],['narco','capitale']]){
  const v=scene(country,city);
  vm.runInContext("openSpaceInjecterZones('centre-affaires','open_space',"+JSON.stringify(city)+")",v.ctx);
  assert.equal(v.zones.length,0,country+' '+city);
 }
});

test('Correspondance des images et zones géométriques distinctes',()=>{
 assert.ok(data.includes("imageUrl:\""+dir+"Starovka_centre_affaires_poste.webp?v=20261116c\""),'zoom image quatre postes');
 assert.ok(data.includes("roomsMasquees:['open_space_a','open_space_b','open_space_c','open_space_d']"),'poste caché des onglets');
 assert.ok(data.includes("imageUrl:\""+dir+"Starovka_centre_affaires_grand_bureau.webp?v=20261116c\""));
 assert.ok(data.includes("imageUrl:\""+dir+"Starovka_centre_affaires_petit_bureau.webp?v=20261116c\""));
 assert.ok(data.includes("imageUrl:\""+dir+"Starovka_centre_affaires_open_space.webp?v=20261116c\""));
 for(const n of ['grand_bureau','petit_bureau','open_space','poste']){
  const b=fs.readFileSync(dir+'Starovka_centre_affaires_'+n+'.webp');
  assert.equal(b.subarray(0,4).toString(),'RIFF');
  assert.equal(b.subarray(8,12).toString(),'WEBP');
 }
 assert.ok(!fs.readdirSync(dir).some(n=>n.startsWith('Bureau vintage face aux montagnes')&&n.endsWith('.png')));
 const c=scene('soviet','ville_a');
 const zones=vm.runInContext("OPEN_SPACE_PLAN['starovka-centre-affaires'].postes.map(p=>p.zone)",c.ctx);
 assert.equal(zones.length,4);
 for(let i=0;i<4;i++){
  const a=zones[i];assert.ok(a.x>=0&&a.y>=0&&a.x+a.w<=1.001&&a.y+a.h<=1.001);
  for(let j=i+1;j<4;j++){
   const b=zones[j];
   assert.ok(a.x+a.w<=b.x||b.x+b.w<=a.x||a.y+a.h<=b.y||b.y+b.h<=a.y,'hotspots doivent être disjoints');
  }
 }
});
