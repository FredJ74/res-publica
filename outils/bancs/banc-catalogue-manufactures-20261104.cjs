// Banc de non-régression : catalogue manufacturé, sans connexion serveur ni PJ réel.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.resolve(__dirname, '../..');
const data = fs.readFileSync(path.join(racine, 'data.js'), 'utf8');
const router = fs.readFileSync(path.join(racine, 'plateau-router.js'), 'utf8');
const economie = fs.readFileSync(path.join(racine, 'plateau-justice-economie.js'), 'utf8');
const debut = economie.indexOf('async function doConsulterCatalogueManufactures()');
const fin = economie.indexOf('async function doFabriquerArmoireSouvenirs()', debut);
assert.ok(debut >= 0 && fin > debut, 'Fonction catalogue introuvable');
const fonction = economie.slice(debut, fin);

function scene({ ville='ville_a', bâtiment='zone-production', disponible=2, bois=4, minerai=4, fail=false }={}) {
  const elements = {
    'postes-modal-title': { textContent: '' },
    'postes-body': { innerHTML: '' },
    'modal-postes': { classList: { add() {} } }
  };
  const toasts = [];
  const catalogue = { armoire_souvenirs: {
    type:'armoire_souvenirs',label:'Armoire à souvenirs',prixVente:390,encombrement:3,
    recette:{pa:3,materiaux:{bois:2,minerai:2}}
  }};
  const ctx = {
    state:{country:'republic',currentCity:ville,currentBuilding:bâtiment},
    produitsManufacturesUsine:(id,pays,city)=>id==='zone-production' && pays==='republic' && city==='ville_a' ? ['armoire_souvenirs'] : [],
    PRODUITS_MANUFACTURES_USINE:catalogue,
    sbGetBatimentEtat:async()=>fail?null:{usine:{stockProduits:{armoire_souvenirs:disponible},stockMatieres:{bois,minerai}}},
    RESSOURCES_ECONOMIE:{bois:{label:'Bois'},minerai:{label:'Minerai'}},
    COUNTRIES:{republic:{cur:'FR'}},
    document:{getElementById:id=>elements[id]},
    showToast:(...args)=>toasts.push(args)
  };
  vm.runInNewContext(fonction+'\nthis.ouvrir = doConsulterCatalogueManufactures;',ctx);
  return {ouvrir:ctx.ouvrir, elements, toasts};
}

test('la scierie propose un seul catalogue, fabrication et achat y sont reunis', async()=>{
  assert.equal((data.match(/fn:'consulter_catalogue_manufactures'/g)||[]).length,1);
  assert.ok(!data.includes("{fn:'fabriquer_armoire_souvenirs', label:"));
  assert.ok(!data.includes("{fn:'acheter_armoire_souvenirs', label:"));
  assert.match(router,/fn === 'consulter_catalogue_manufactures'/);
  const s=scene(); await s.ouvrir();
  const h=s.elements['postes-body'].innerHTML;
  for (const texte of ['Armoire à souvenirs','390 FR','Stock disponible : 2','Bois','Minerai','Produire','Acheter']) assert.ok(h.includes(texte),texte);
  assert.match(h,/onclick="doFabriquerArmoireSouvenirs\(\)"/);
  assert.match(h,/onclick="doAcheterArmoireSouvenirs\(\)"/);
});

test('stock nul : achat refuse dans la carte ; production toujours possible',async()=>{
  const s=scene({disponible:0});await s.ouvrir();const h=s.elements['postes-body'].innerHTML;
  assert.match(h,/Stock disponible : 0/);
  assert.doesNotMatch(h,/onclick="doAcheterArmoireSouvenirs\(\)"/);
  assert.match(h,/onclick="doFabriquerArmoireSouvenirs\(\)"/);
});
test('matieres insuffisantes : production inactive, achat possible',async()=>{
  const s=scene({bois:0});await s.ouvrir();const h=s.elements['postes-body'].innerHTML;
  assert.doesNotMatch(h,/onclick="doFabriquerArmoireSouvenirs\(\)"/);
  assert.match(h,/onclick="doAcheterArmoireSouvenirs\(\)"/);
});
test('un autre territoire ne lit pas le catalogue de PSM',async()=>{
  const s=scene({ville:'ville_b'});await s.ouvrir();
  assert.equal(s.elements['postes-body'].innerHTML,'');
  assert.equal(s.toasts.length,1);
});
test('lecture serveur absente : refus sans afficher un ancien stock',async()=>{
  const s=scene({fail:true});await s.ouvrir();
  assert.equal(s.elements['postes-body'].innerHTML,'');
  assert.equal(s.toasts.length,1);
});
