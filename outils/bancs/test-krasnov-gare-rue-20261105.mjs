import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');

test('Krasnov : gare, entrepôt et maisons avec directions exactement validées',()=>{
  const ctx=vm.createContext({console, state:{country:'soviet',currentCity:'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    depart:RUE_CENTRALE_DEPART.soviet.ville_b,
    noeud:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-gare'],
    entrepot:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-entrepot'],
    maison:RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-maison'],
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
  assert.equal(Object.keys(got.maison.liens).length,0);
  assert.equal(got.maison.zones.length,0);
  assert.equal(got.entrepot.zones.length,0);
  assert.equal(got.noeud.zones.length,1);
  assert.equal(got.noeud.zones[0].buildingId,'centre-multinodal-montrouge');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.imageUrl,'images/Sovarka/Krasnov/Krasnov_gare_hall.webp');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.personsVides,true);
  assert.notEqual(got.hallPSM,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl);
  for (const f of [got.noeud.image,got.entrepot.image,got.maison.image,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl]){
    assert.ok(fs.statSync(path.join(root,f)).size>0,f);
  }
});
