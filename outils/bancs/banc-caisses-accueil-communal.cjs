// Banc : caisses communales visibles à l'accueil, ordre de l'Hôtel de Ville retiré (30/10/2026).
// Décisions de Fred : (1) plus d'ordre « Consulter les caisses communales » pour les joueurs ;
// (2) chaque bâtiment communal doté d'une caisse affiche son montant dès l'accueil, lu à la
// source existante (caisses_batiments ; RPC caisse_commissariat_lire pour le commissariat).
// Le banc charge le vrai data.js et les vraies fonctions du jeu (aucune copie).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const R = path.join(__dirname, '..', '..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

function extraire(src, entete) {
  const d = src.indexOf(entete);
  assert.ok(d >= 0, 'introuvable : ' + entete);
  if (entete.startsWith('const ')) {
    let i = src.indexOf('=', d) + 1, prof = 0;
    for (; i < src.length; i++) {
      const c = src[i];
      if ('{[('.includes(c)) prof++;
      else if ('}])'.includes(c)) prof--;
      else if (c === ';' && prof === 0) return src.slice(d, i + 1);
    }
  }
  let i = src.indexOf('{', d), prof = 0;
  for (; i < src.length; i++) {
    if (src[i] === '{') prof++;
    else if (src[i] === '}' && --prof === 0) return src.slice(d, i + 1);
  }
  throw new Error('fin introuvable : ' + entete);
}

const politique = lire('plateau-politique.js');
const justice = lire('plateau-justice-economie.js');
const personnage = lire('plateau-personnage.js');
const routeur = lire('plateau-router.js');
const data = lire('data.js');

const ctx = { console, window: {}, document: {}, navigator: {}, localStorage: { getItem() {}, setItem() {} } };
ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(data, ctx);
vm.runInContext([
  extraire(personnage, 'const STRUCTURES_MEDICALES'),
  extraire(politique, 'const CATEGORIES_BUDGET_MAIRIE'),
  extraire(politique, 'const CATEGORIES_CAISSE_BATIMENTS_LOCAUX'),
  extraire(politique, 'function estAccueilBatiment('),
  extraire(politique, 'function categorieCaisseAccueilCommunal('),
  extraire(politique, 'function getBuildingIdPourCategorieBudget('),
  extraire(justice, 'function getBuildingIdCommissariat('),
  extraire(justice, 'function getBuildingIdCentreMultimodal('),
  extraire(justice, 'function getBuildingIdDispensaire('),
  extraire(justice, 'function getBuildingIdTribunal('),
  extraire(justice, 'function getCaisseLocaleId('),
  'this.accueil = estAccueilBatiment; this.cat = categorieCaisseAccueilCommunal; this.caisse = getBuildingIdPourCategorieBudget;',
  'this.B = BUILDINGS; this.W = WORLD;'
].join('\n'), ctx);

// Identifiants relevés en production (caisses_batiments, lecture seule, 30/10/2026).
const ATTENDU = {
  capitale: { 'tribunal': 'tribunal_capitale', 'dispensaire-public': 'dispensaire_capitale',
    'commissariat': 'commissariat_capitale', 'marche': 'marche_capitale', 'stade': 'stade_capitale',
    'centre-multinodal-luthecia': 'centre-multinodal-luthecia' },
  ville_a: { 'tribunal-local': 'tribunal_ville_a', 'dispensaire-public-v': 'dispensaire_ville_a',
    'commissariat-local': 'commissariat_ville_a', 'marche-psm': 'marche_ville_a', 'stade': 'stade_ville_a',
    'centre-multinodal-port-sainte-marie': 'centre-multinodal-port-sainte-marie' },
  ville_b: { 'tribunal-local': 'tribunal_ville_b', 'dispensaire-public-v': 'dispensaire_ville_b',
    'commissariat-local': 'commissariat_ville_b', 'marche': 'marche_ville_b', 'stade': 'stade_ville_b',
    'centre-multinodal-montrouge': 'centre-multinodal-montrouge' }
};

test('aucun ordre « Consulter les caisses communales » dans les bâtiments ni dans les villes', () => {
  const vus = [];
  const parcourir = (o, chemin) => {
    if (!o || typeof o !== 'object') return;
    if (o.fn === 'consulter_indices_locaux' || /caisses communales/i.test(String(o.label || ''))) vus.push(chemin);
    for (const [k, v] of Object.entries(o)) parcourir(v, chemin + '.' + k);
  };
  parcourir(ctx.B, 'BUILDINGS');
  parcourir(ctx.W, 'WORLD');
  assert.deepStrictEqual(vus, []);
  assert.ok(!/consulter_indices_locaux/.test(routeur), 'le routeur ne doit plus traiter cet ordre');
  assert.ok(!/function doConsulterIndicesLocaux/.test(politique), "l'ancien écran ne doit plus exister");
});

for (const [ville, batiments] of Object.entries(ATTENDU)) {
  test('caisse de chaque bâtiment communal à ' + ville, () => {
    for (const [bid, caisseId] of Object.entries(batiments)) {
      assert.ok(ctx.W.republic[ville].buildings.includes(bid), bid + ' absent de ' + ville);
      const cat = ctx.cat(bid, ville, 'republic');
      assert.ok(cat, bid + ' : aucune caisse résolue');
      assert.strictEqual(ctx.caisse(cat, ville, 'republic'), caisseId, bid + ' (' + ville + ')');
    }
  });
}

test('la propre caisse des mairies est affichée sans restaurer la consultation centralisée', () => {
  const mairies = { capitale: ['mairie-capitale', 'mairie-capitale'],
    ville_a: ['mairie', 'mairie_ville_a'], ville_b: ['mairie', 'mairie_ville_b'] };
  const bloc = extraire(politique, 'function afficherCaisseAccueilCommunal(');
  assert.match(bloc, /categorie === 'mairie'/);
  assert.match(bloc, /caisseTerritorialeId\('mairie', state\.currentCity\)/);
  for (const [ville, [batiment, caisseId]] of Object.entries(mairies)) {
    assert.ok(ctx.W.republic[ville].buildings.includes(batiment), batiment + ' absent de ' + ville);
    assert.strictEqual(ctx.cat(batiment, ville, 'republic'), 'mairie');
    assert.strictEqual(ctx.caisseTerritorialeId('mairie', ville), caisseId);
    assert.ok(Object.keys(ctx.B[batiment].rooms).length > 0);
  }
});

test("les 21 accueils publics affichent leur caisse, les salles intérieures non", () => {
  const MAIRIES = { capitale: 'mairie-capitale', ville_a: 'mairie', ville_b: 'mairie' };
  let n = 0;
  for (const [ville, batiments] of Object.entries(ATTENDU)) {
    for (const bid of [...Object.keys(batiments), MAIRIES[ville]]) {
      const salles = Object.keys(ctx.B[bid]?.rooms || {});
      assert.ok(salles.length > 0, bid + ' sans salle');
      assert.ok(ctx.accueil(bid, salles[0]), bid + ' : accueil ' + salles[0] + ' non reconnu');
      assert.ok(ctx.cat(bid, ville, 'republic'), bid + ' (' + ville + ') : aucune caisse');
      n++;
    }
  }
  assert.strictEqual(n, 21);
  for (const [bid, salle] of [['mairie-capitale', 'bureau_maire'], ['mairie', 'bureau_maire_local'],
    ['commissariat', 'bureau_commissaire'], ['tribunal', 'greffe'], ['stade', 'vestiaires']])
    assert.strictEqual(ctx.accueil(bid, salle), false, bid + '/' + salle);
  const bloc = extraire(politique, 'function afficherCaisseAccueilCommunal(');
  assert.match(bloc, /state\.country === 'republic' && estAccueilBatiment\(buildingId, roomId\)/);
});

test('une mairie hors ville réelle ou hors liste de la ville n\'a pas de caisse', () => {
  assert.strictEqual(ctx.cat('mairie', 'caserne', 'republic'), null);
  assert.strictEqual(ctx.cat('mairie-capitale', 'ville_a', 'republic'), null);
  assert.strictEqual(ctx.cat('mairie', 'capitale', 'republic'), null);
});

test('bâtiments sans caisse communale : rien affiché', () => {
  for (const bid of ['banque-nationale', 'clinique-privee', 'office-notarial', 'hotel-republica'])
    assert.strictEqual(ctx.cat(bid, 'capitale', 'republic'), null, bid);
});

test('la lecture passe par la source existante, sans écriture ni droit de gestion', () => {
  const bloc = extraire(politique, 'function afficherCaisseAccueilCommunal(');
  const affichage = bloc;
  const render = extraire(politique, 'function renderRoomActions(');
  assert.match(render, /typeof afficherCaisseAccueilCommunal === 'function'\) afficherCaisseAccueilCommunal\(buildingId, roomId\)/);
  assert.doesNotMatch(render, /sbGetCaisseBatiment|lireCaisseCommissariat/, "la lecture ne vit qu'à un endroit");
  assert.match(affichage, /lireCaisseCommissariat\(state\.country, caisseId\)/);
  assert.match(affichage, /sbGetCaisseBatiment\(state\.country \+ '_' \+ caisseId\)/);
  assert.doesNotMatch(affichage, /sbSave|Mouvement|upsert|onclick|<button/i);
});
