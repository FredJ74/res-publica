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
    immeubles:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-immeubles-centre-commercial'],
    mairie:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-mairie-place'],
    tabac:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-tabac-bar'],
    station:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-station-musee'],
    bureaux:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-bureaux'],
    descendante:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-descendante'],
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
  assert.deepEqual(Array.from(got.stade.zones, z=>z.buildingId), ['commissariat-local','stade']);
  assert.deepEqual(Array.from(got.stade.zones, z=>z.xPct.join('-')), ['0-42','57-100']);
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
  assert.deepEqual(Object.keys(got.distillerie.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.distillerie.liens.arriere,'krasnov-rue-ecole-foret');
  assert.equal(got.distillerie.liens.toutDroit,'krasnov-rue-immeubles-centre-commercial');
  assert.equal(got.distillerie.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.distillerie.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.immeubles.image,'images/Sovarka/Krasnov/Krasnov rue immeubles centre commercial.webp');
  assert.deepEqual(Object.keys(got.immeubles.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.immeubles.liens.arriere,'krasnov-rue-distillerie-radar');
  assert.equal(got.immeubles.liens.toutDroit,'krasnov-rue-mairie-place');
  assert.equal(got.immeubles.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.immeubles.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.mairie.image,'images/Sovarka/Krasnov/Krasnov rue mairie place.webp');
  assert.deepEqual(Object.keys(got.mairie.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.mairie.liens.arriere,'krasnov-rue-immeubles-centre-commercial');
  assert.equal(got.mairie.liens.toutDroit,'krasnov-rue-tabac-bar');
  assert.equal(got.mairie.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.mairie.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.tabac.image,'images/Sovarka/Krasnov/Krasnov rue tabac bar.webp');
  assert.deepEqual(Object.keys(got.tabac.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.tabac.liens.arriere,'krasnov-rue-mairie-place');
  assert.equal(got.tabac.liens.toutDroit,'krasnov-rue-station-musee');
  assert.equal(got.tabac.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.tabac.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.station.image,'images/Sovarka/Krasnov/Krasnov rue station musée.webp');
  assert.deepEqual(Object.keys(got.station.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.station.liens.arriere,'krasnov-rue-tabac-bar');
  assert.equal(got.station.liens.toutDroit,'krasnov-rue-bureaux');
  assert.equal(got.station.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.station.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.bureaux.image,'images/Sovarka/Krasnov/Krasnov_rue_bureaux.webp');
  assert.deepEqual(Object.keys(got.bureaux.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.bureaux.liens.arriere,'krasnov-rue-station-musee');
  assert.equal(got.bureaux.liens.toutDroit,'krasnov-rue-descendante');
  assert.equal(got.bureaux.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.bureaux.flechesStyle.toutDroit,'top:10px; left:43%; transform:translateX(-50%);');
  assert.equal(got.descendante.image,'images/Sovarka/Krasnov/Krasnov_rue_descendante.webp');
  assert.deepEqual(Object.keys(got.descendante.liens).sort(),['arriere','toutDroit']);
  assert.equal(got.descendante.liens.arriere,'krasnov-rue-bureaux');
  assert.equal(got.descendante.liens.toutDroit,'krasnov-rue-eglise');
  assert.equal(got.descendante.flechesStyle.arriere,'bottom:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.descendante.flechesStyle.toutDroit,'top:10px; left:50%; transform:translateX(-50%);');
  assert.equal(got.eglise.image,'images/Sovarka/Krasnov/Krasnov rue église.webp');
  assert.deepEqual(Object.keys(got.eglise.liens).sort(),['arriere','droite']);
  assert.equal(got.eglise.liens.droite,'krasnov-rue-descendante');
  assert.equal(got.eglise.liens.arriere,'krasnov-rue-terrains');
  assert.equal(got.eglise.flechesStyle.arriere,'bottom:10px; left:43%; transform:translateX(-50%);');
  assert.equal(got.eglise.liensEnAttente,undefined);
  assert.equal(got.eglise.flechesStyle.droite,'top:33.3333%; right:10px; transform:translateY(-50%);');
  assert.equal(got.terrains.zones.length,0);
  assert.equal(got.maison.zones.length,0);
  // L'entrepôt de Krasnov est raccordé (05/11/2026, migration 20261105030000).
  assert.equal(got.entrepot.zones.length,1);
  assert.equal(got.entrepot.zones[0].buildingId,'entrepot-logistique-krasnov');
  assert.equal(got.noeud.zones.length,1);
  assert.equal(got.noeud.zones[0].buildingId,'centre-multinodal-montrouge');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.imageUrl,'images/Sovarka/Krasnov/Krasnov_gare_hall.webp');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.personsVides,true);
  assert.notEqual(got.hallPSM,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl);
  for (const f of [got.noeud.image,got.entrepot.image,got.maison.image,got.terrains.image,got.eglise.image,got.marche.image,got.artisanal.image,got.stade.image,got.ecole.image,got.distillerie.image,got.immeubles.image,got.mairie.image,got.tabac.image,got.station.image,got.bureaux.image,got.descendante.image,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl]){
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

test('Krasnov : visuel WebP de la salle des ventes et ordres logistiques inchangés',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    city:WORLD.soviet.ville_b,
    salle:BUILDINGS['entrepot-logistique-krasnov'].rooms.salle_ventes,
    bureau:BUILDINGS['entrepot-logistique-krasnov'].rooms.bureau_direction
  })`,ctx);
  assert.ok(got.city.buildings.includes('entrepot-logistique-krasnov'));
  assert.equal(got.salle.imageUrl,'images/Sovarka/Krasnov/Krasnov_entrepot_salle ventes.webp');
  assert.ok(fs.statSync(path.join(root,got.salle.imageUrl)).size>100);
  assert.deepEqual(Array.from(got.salle.orders,o=>o.fn),
    ['receptionner_commande','acheter_ressources_entrepot']);
  assert.ok(got.bureau.orders.some(o=>o.fn==='tableau_bord_entrepot'));
  assert.ok(got.bureau.orders.some(o=>o.fn==='fixer_prix_achat_entrepot'));
});
