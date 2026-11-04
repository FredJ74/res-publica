// Regression du catalogue manufacture : entree unique, deux choix, aucun debit client.
// node --test outils/bancs/banc-catalogue-produits-manufactures-20261104.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const data = fs.readFileSync('data.js', 'utf8');
const router = fs.readFileSync('plateau-router.js', 'utf8');
const economie = fs.readFileSync('plateau-justice-economie.js', 'utf8');
const debut = economie.indexOf('async function doOuvrirCatalogueProduitsManufactures() {');
const fin = economie.indexOf('\nasync function doFabriquerArmoireSouvenirs()', debut);
assert.ok(debut > 0 && fin > debut);
const source = economie.slice(debut, fin);

test('Scierie : un ordre catalogue et les deux anciens chemins conserves', () => {
  const portion = data.slice(data.indexOf("'zone-production': {"), data.indexOf("'centre-affaires': {", data.indexOf("'zone-production': {")));
  assert.equal((portion.match(/fn:'catalogue_produits_manufactures'/g) || []).length, 1);
  assert.equal((portion.match(/fn:'fabriquer_armoire_souvenirs'/g) || []).length, 0);
  assert.equal((portion.match(/fn:'acheter_armoire_souvenirs'/g) || []).length, 0);
  assert.match(router, /if \(fn === 'catalogue_produits_manufactures'\)/);
  assert.match(economie, /async function confirmerFabriquerArmoireSouvenirs\(/);
  assert.match(economie, /async function confirmerAchatArmoireSouvenirs\(/);
});

async function affiche(stock, matieres, disponible=true) {
  const elements = {
    'postes-modal-title': { textContent: '' },
    'postes-body': { innerHTML: '' },
    'modal-postes': { classList: { add() {} } }
  };
  const context = {
    state: { country:'republic',currentCity:'ville_a',currentBuilding:'zone-production' },
    PRODUITS_MANUFACTURES_USINE: { armoire_souvenirs: {
      type:'armoire_souvenirs',label:'Armoire à souvenirs',pays:'republic',ville:'ville_a',
      buildingId:'zone-production',prixVente:390,encombrement:3,recette:{pa:3,materiaux:{bois:2,minerai:2}}
    }},
    RESSOURCES_ECONOMIE: {bois:{label:'Bois'},minerai:{label:'Minerai'}},
    COUNTRIES:{republic:{cur:'FR'}},
    sbGetBatimentEtat:async()=>disponible?{usine:{stockProduits:{armoire_souvenirs:stock},stockMatieres:matieres}}:null,
    document:{getElementById:id=>elements[id]},
    showToast:()=>{},
  };
  vm.createContext(context);
  vm.runInContext(source,context);
  await context.doOuvrirCatalogueProduitsManufactures();
  return elements['postes-body'].innerHTML;
}

test('Catalogue : les deux actions sont presentees sur une seule fiche', async()=>{
  const html=await affiche(3,{bois:4,minerai:4});
  for (const attendu of ['Armoire à souvenirs','390 FR','Stock : 3','3 PA','Produire','Acheter'])assert.ok(html.includes(attendu),attendu);
  assert.match(html,/onclick="doFabriquerArmoireSouvenirs\(\)"/);
  assert.match(html,/onclick="doAcheterArmoireSouvenirs\(\)"/);
});
test('Stocks insuffisants : actions desactivees sans fausser le stock',async()=>{
  const html=await affiche(0,{bois:1,minerai:0});
  assert.match(html,/disabled onclick="doFabriquerArmoireSouvenirs/);
  assert.match(html,/disabled onclick="doAcheterArmoireSouvenirs/);
});
test('Serveur indisponible : aucune valeur inventee',async()=>{
  const html=await affiche(1,{bois:2,minerai:2},false);
  assert.equal(html,'');
});
