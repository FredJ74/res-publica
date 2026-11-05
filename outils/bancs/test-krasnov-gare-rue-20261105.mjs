import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');

test('Krasnov : continuité de la gare au radar, toutes les flèches validées',()=>{
  const ctx=vm.createContext({console, state:{country:'soviet',currentCity:'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    depart:RUE_CENTRALE_DEPART.soviet.ville_b,
    noeud:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-gare'],
    entrepot:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-entrepot'],
    maison:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-maison'],
    terrains:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-terrains'],
    eglise:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-eglise'],
    marche:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-marche-ferme'],
    artisanal:RUE_CENTRALE_NOEUDS.soviet['krasnov-centre-artisanal'],
    stade:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-stade-commissariat'],
    ecole:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-ecole-foret'],
    distillerie:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-distillerie-radar'],
    bas:RC_FLECHE_BAS,
    contexte:WORLD.soviet.ville_b.buildingContext['centre-multinodal-montrouge'],
    hallPSM:BUILDINGS['centre-multinodal-montrouge'].rooms.hall_gare_montrouge.imageUrl,
    nodeFromBuilding:noeudRueDuBatiment('soviet','centre-multinodal-montrouge')
  })`,ctx);
  assert.equal(got.depart,'krasnov-rue-gare');
  assert.equal(got.nodeFromBuilding,'krasnov-rue-gare');
  assert.equal(got.noeud.image,'images/Sovarka/Krasnov/Krasnov rue gare.webp');
  assert.deepEqual(Object.keys(got.noeud.liens),['arriere']);
  assert.equal(got.noeud.liens.arriere,'krasnov-rue-entrepot');
  assert.equal(got.noeud.flechesStyle.arriere,got.bas);
  assert.equal(got.entrepot.image,'images/Sovarka/Krasnov/Krasnov rue entrepôt.webp');
  assert.deepEqual(Object.keys(got.entrepot.liens).sort(),['droite','toutDroit']);
  assert.equal(got.entrepot.liens.toutDroit,'krasnov-rue-gare');
  assert.equal(got.entrepot.liens.droite,'krasnov-rue-maison');
  assert.equal(got.entrepot.flechesStyle.toutDroit,'top:10px; left:66.6667%; transform:translateX(-50%);');
  assert.equal(got.entrepot.flechesStyle.droite,'bottom:10px; right:10px;');
  assert.equal(got.maison.image,'images/Sovarka/Krasnov/Krasnov rue maison.webp');
  assert.deepEqual(Object.keys(got.maison.liens).sort(),['droite','gauche']);
  assert.equal(got.maison.liens.gauche,'krasnov-rue-entrepot');
  assert.equal(got.maison.liens.droite,'krasnov-rue-terrains');
  assert.equal(got.maison.flechesStyle.gauche,'top:50%; left:10px; transform:translateY(-50%);');
  assert.equal(got.maison.flechesStyle.droite,'top:50%; right:10px; transform:translateY(-50%);');
  assert.equal(got.terrains.image,'images/Sovarka/Krasnov/Krasnov rue terrains.webp');
  assert.deepEqual(Object.keys(got.terrains.liens).sort(),['droite','gauche','toutDroit']);
  assert.equal(got.terrains.liens.gauche,'krasnov-rue-maison');
  assert.equal(got.terrains.liens.toutDroit,'krasnov-rue-eglise');
  assert.equal(got.terrains.liens.droite,'krasnov-rue-marche-ferme');
  assert.equal(got.terrains.flechesStyle.gauche,'top:50%; left:10px; transform:translateY(-50%);');
  assert.equal(got.terrains.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.terrains.liensEnAttente,undefined);
  assert.equal(got.terrains.flechesStyle.droite,'top:66.6667%; right:10px; transform:translateY(-50%);');
  assert.equal(got.marche.image,'images/Sovarka/Krasnov/Krasnov rue marché ferme.webp');
  assert.deepEqual(Object.keys(got.marche.liens).sort(),['droite','gauche']);
  assert.equal(got.marche.liens.gauche,'krasnov-rue-terrains');
  assert.equal(got.marche.liens.droite,'krasnov-centre-artisanal');
  assert.equal(got.marche.flechesStyle.gauche,'top:66.6667%; left:10px; transform:translateY(-50%);');
  assert.equal(got.marche.flechesStyle.droite,'top:66.6667%; right:10px; transform:translateY(-50%);');
  assert.equal(got.artisanal.image,'images/Sovarka/Krasnov/Krasnov centre artisanal.webp');
  assert.deepEqual(Object.keys(got.artisanal.liens).sort(),['gauche','toutDroit']);
  assert.equal(got.artisanal.liens.gauche,'krasnov-rue-marche-ferme');
  assert.equal(got.artisanal.liens.toutDroit,'krasnov-rue-stade-commissariat');
  assert.equal(got.artisanal.flechesStyle.gauche,'top:66.6667%; left:10px; transform:translateY(-50%);');
  assert.equal(got.artisanal.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.stade.image,'images/Sovarka/Krasnov/Krasnov rue stade commissariat.webp');
  assert.deepEqual(got.stade.zones.map(z=>z.buildingId), ['commissariat-local','stade']);
  assert.deepEqual(got.stade.zones.map(z=>z.xPct.join('-')), ['0-42','57-100']);
  assert.ok(got.stade.zones.every(z=>z.type==='batiment'));
  assert.deepEqual(Object.keys(got.stade.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.stade.liens.arriere,'krasnov-centre-artisanal');
  assert.equal(got.stade.liens.toutDroit,'krasnov-rue-ecole-foret');
  assert.equal(got.stade.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.stade.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.ecole.image,'images/Sovarka/Krasnov/Krasnov rue école foret.webp');
  assert.deepEqual(Object.keys(got.ecole.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.ecole.liens.arriere,'krasnov-rue-stade-commissariat');
  assert.equal(got.ecole.liens.toutDroit,'krasnov-rue-distillerie-radar');
  assert.equal(got.ecole.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.ecole.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.distillerie.image,'images/Sovarka/Krasnov/Krasnov rue distillerie centre radar.webp');
  assert.equal(Object.keys(got.distillerie.liens).length,0);
  assert.equal(got.eglise.image,'images/Sovarka/Krasnov/Krasnov rue église.webp');
  assert.deepEqual(Object.keys(got.eglise.liens),['arriere']);
  assert.equal(got.eglise.liens.arriere,'krasnov-rue-terrains');
  assert.equal(got.eglise.flechesStyle.arriere,'bottom:10px; left:43%; transform:translateX(-50%);');
  assert.equal(got.eglise.liensEnAttente.droite,true);
  assert.equal(got.eglise.flechesStyle.droite,'top:33.3333%; right:10px; transform:translateY(-50%);');
  assert.equal(got.terrains.zones.length,0);
  assert.equal(got.maison.zones.length,0);
  assert.equal(got.entrepot.zones.length,0);
  assert.equal(got.noeud.zones.length,1);
  assert.equal(got.noeud.zones[0].buildingId,'centre-multinodal-montrouge');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.imageUrl,'images/Sovarka/Krasnov/Krasnov_gare_hall.webp');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.personsVides,true);
  assert.notEqual(got.hallPSM,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl);
  for (const f of [got.noeud.image,got.entrepot.image,got.maison.image,got.terrains.image,got.eglise.image,got.marche.image,got.artisanal.image,got.stade.image,got.ecole.image,got.distillerie.image,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl]){
    assert.ok(fs.statSync(path.join(root,f)).size>0,f);
  }
});

test('Krasnov : commissariat et stade héritent des pièces et ordres du socle commun',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    city:WORLD.soviet.ville_b,
    commissariat:BUILDINGS['commissariat-local'],
    stade:BUILDINGS.stade
  })`,ctx);
  assert.ok(got.city.buildings.includes('commissariat-local'));
  assert.ok(got.city.buildings.includes('stade'));
  assert.equal(got.city.buildingContext['commissariat-local'].name,'Commissariat de Krasnov');
  assert.equal(got.city.buildingContext.stade.name,'Stade Étoile Rouge de Krasnov');
  assert.deepEqual(Object.keys(got.commissariat.rooms).sort(),['accueil_loc','bureau_commissaire','geoles']);
  assert.deepEqual(Object.keys(got.stade.rooms).sort(),['bureau_president','buvette','guichet_paris','siege_supporters','terrain','vestiaires']);
  for(const [building,rooms] of [[got.commissariat,got.commissariat.rooms],[got.stade,got.stade.rooms]]){
    assert.ok(building);
    for(const [id,room] of Object.entries(rooms)){
      assert.ok(Array.isArray(room.orders), id+' : ordres hérités du socle');
      assert.ok(room.orders.length>0, id+' : ordres absents');
      assert.ok(room.orders.every(o=>typeof o.fn==='string'&&o.fn.length>0),id+' : handler manquant');
    }
  }
  assert.ok(got.commissariat.rooms.accueil_loc.orders.some(o=>o.fn==='plainte_police'));
  assert.ok(got.stade.rooms.terrain.orders.some(o=>o.fn==='observer_match'));
  assert.ok(got.stade.rooms.vestiaires.orders.some(o=>o.fn==='prendre_licence_sportive'));
});
