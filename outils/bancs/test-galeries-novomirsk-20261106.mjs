import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const ctx=vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8')+';this.world=WORLD;this.buildings=BUILDINGS;',ctx);
vm.runInContext(fs.readFileSync(path.join(root,'plateau-variantes-pieces.js'),'utf8')+';this.variantes=PIECE_VARIANTES;',ctx);

const ville=ctx.world.soviet.capitale;
const galeries=ville.buildingContext['centre-commercial'];
const rooms=ctx.buildings['centre-commercial'].rooms;
const imageRoot='images/Sovarka/Novomirsk/';
const mapping={
  vitrine_principale:{type:'grand',file:'Novomirsk_galeries_grand_local.webp'},
  boutique_milieu:{type:'grand',file:'Novomirsk_galeries_grand_local.webp'},
  arriere_boutique:{type:'moyen',file:'Novomirsk_galeries_moyen_local.webp'},
  cave_reserve:{type:'moyen',file:'Novomirsk_galeries_moyen_local.webp'}
};
const pngSources=[
  'Novomirsk_galeries_entrée.png',
  'Novomirsk_galeries_grand local.png',
  'Novomirsk_galeries_moyen local.png'
];

test('entrée des galeries et ses trois images WebP réellement intégrées',()=>{
  assert.ok(ville.buildings.includes('centre-commercial'));
  assert.equal(galeries.name,'Galeries de Novomirsk');
  assert.equal(galeries.roomOverrides.hall.imageUrl,imageRoot+'Novomirsk_galeries_entree.webp');
  for(const name of ['Novomirsk_galeries_entree.webp','Novomirsk_galeries_grand_local.webp','Novomirsk_galeries_moyen_local.webp']){
    const file=fs.readFileSync(path.join(root,imageRoot,name));
    assert.ok(file.byteLength>100000,'WebP de taille suspecte : '+name);
    assert.equal(file.toString('ascii',0,4),'RIFF',name);
    assert.equal(file.toString('ascii',8,12),'WEBP',name);
  }
  for(const file of pngSources){
    assert.equal(fs.existsSync(path.join(root,imageRoot,file)),false,'PNG original conservé : '+file);
  }
});

test('exactement deux grands et deux moyens, quatre identifiants de bail inchangés',()=>{
  assert.equal(Object.keys(galeries.roomOverrides).length,5);
  assert.equal(Object.keys(mapping).length,4);
  assert.equal(Object.values(mapping).filter(x=>x.type==='grand').length,2);
  assert.equal(Object.values(mapping).filter(x=>x.type==='moyen').length,2);
  for(const [piece,{type,file}] of Object.entries(mapping)){
    assert.equal(rooms[piece].isLocationRoom,true,piece);
    assert.ok(rooms[piece].locationData?.prix>0,piece);
    assert.ok(rooms[piece].orders.some(x=>x.fn==='commerce_pj'),piece);
    assert.ok(rooms[piece].orders.some(x=>x.fn==='louer_local'),piece);
    assert.equal(galeries.roomOverrides[piece].imageUrl,imageRoot+file,piece);
    assert.ok(galeries.roomOverrides[piece].name.includes(type==='grand'?'Grand local':'Local moyen'),piece);
    assert.equal('locationData' in galeries.roomOverrides[piece],false,'prix serveur non surchargé');
    // Les surcharges d'ordres éventuelles peuvent provenir du socle de données
    // existant ; la présence de ces champs ne prouve pas un changement métier.
    // Les trois ordres clefs de location sont vérifiés sur la pièce canonique.
  }
});

test('les enseignes des quatre boutiques reçoivent le nom du locataire par le socle existant',()=>{
  const declarations=ctx.variantes.soviet.capitale['centre-commercial'];
  assert.equal(Object.keys(declarations).length,4);
  for(const [piece,{file}] of Object.entries(mapping)){
    const v=declarations[piece];
    assert.equal(v.famille,'location');
    assert.equal(v.ancrage,mapping[piece].type==='grand'?'bas-grand':'haut');
    assert.equal(v.images.libre,imageRoot+file);
    assert.equal(v.images.occupee,imageRoot+file);
    assert.ok(v.enseigne.etats.includes('occupee'));
    assert.equal(v.enseigne.mode,'texte');
    assert.ok(v.enseigne.zone.w>0.5);
    assert.ok(v.nom.occupee);
  }
  assert.equal(ctx.variantes.republic.capitale['centre-commercial'].vitrine_principale.images.libre,'images/luthecia-centre-commercial-grand-local-vide.webp');
  assert.equal(ctx.world.republic.capitale.buildingContext['centre-commercial'].roomOverrides.hall.imageUrl,'images/centre-commercial-republic.webp');
});

test('ancrage bas des grandes vitrines et enseignes : CSS, décor Premium, géométrie concordants',()=>{
 const css=fs.readFileSync(path.join(root,'style.css'),'utf8');
 const engine=fs.readFileSync(path.join(root,'plateau-variantes-pieces.js'),'utf8');
 assert.ok(css.includes('.piece-image[data-ancrage="bas"]{background-position:center bottom!important}'));
 assert.ok(css.includes('.piece-image[data-ancrage="bas-grand"]{background-position:center 72%!important}'));
 assert.ok(css.includes('.piece-image[data-commerce-decor="1"][data-ancrage="bas"]{background-position:center center!important}'));
 assert.ok(css.includes('.piece-image[data-commerce-decor="1"][data-ancrage="bas-grand"]{background-position:center center!important}'));
 const pieces=ctx.variantes.soviet.capitale['centre-commercial'];
 assert.equal(pieces.vitrine_principale.ancrage,'bas-grand');
 assert.equal(pieces.boutique_milieu.ancrage,'bas-grand');
 assert.equal(pieces.arriere_boutique.ancrage,'haut');
 assert.equal(pieces.cave_reserve.ancrage,'haut');
 vm.runInContext(';this.zone=varianteZoneEnPixels;',ctx);
 const geom=ctx;
 const cadre={clientWidth:1200,clientHeight:300};
 const taille={l:1536,h:1024},zone={x:0,y:0,w:1,h:1};
 const top=geom.zone(zone,cadre,taille,'haut');
 const center=geom.zone(zone,cadre,taille,'centre');
 const bottom=geom.zone(zone,cadre,taille,'bas');
 assert.equal(top.haut,0);
 assert.ok(bottom.haut<center.haut);
 const softened=geom.zone(zone,cadre,taille,'bas-grand');
 assert.ok(softened.haut>bottom.haut && softened.haut<center.haut);
 assert.ok(Math.abs(softened.haut-(cadre.clientHeight-bottom.hauteur)*0.72)<0.001);
 assert.equal(bottom.haut+bottom.hauteur,cadre.clientHeight);
});
