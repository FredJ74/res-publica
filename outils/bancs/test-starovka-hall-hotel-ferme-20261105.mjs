import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : gare, hôtel, ferme, port et hall bidirectionnels',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    gare:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-gare'],
    hotel:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-hotel'],
    ferme:RUE_CENTRALE_NOEUDS.soviet['starovka-maisons-ferme'],
    port:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-port-industriel'],
    contexte:WORLD.soviet.ville_a.buildingContext['centre-multinodal-montrouge'],
    sortie:noeudRueDuBatiment('soviet','centre-multinodal-montrouge')
  })`,ctx);
  assert.equal(got.gare.liens.arriere,'starovka-rue-hotel');
  assert.equal(got.gare.liens.toutDroit,'starovka-rue-port-industriel');
  assert.equal(got.hotel.liens.toutDroit,'starovka-rue-gare');
  assert.equal(got.hotel.liens.arriere,'starovka-maisons-ferme');
  assert.equal(got.ferme.liens.toutDroit,'starovka-rue-hotel');
  assert.equal(got.port.liens.arriere,'starovka-rue-gare');
  assert.equal(got.gare.zones[0].buildingId,'centre-multinodal-montrouge');
  assert.equal(got.sortie,'starovka-rue-gare');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.imageUrl,'images/Sovarka/Starovka/Starovka_gare_hall.webp');
  for(const node of [got.gare,got.hotel,got.ferme,got.port])
    assert.ok(fs.statSync(path.join(root,node.image)).size>100,node.image);
  assert.ok(fs.statSync(path.join(root,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl)).size>100);
  for (const name of ['Starovka_gare_hall','Starovka_rue_hotel','Starovka_maisons_ferme','Starovka_rue_pétrole_ferme']) assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka',name+'.png')),false,name);
});
