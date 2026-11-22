// Étape J, terrains à bâtir (GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, complément du 21/11) : étiquettes du plan en
// vignettes et branchements, sans navigateur. Le rendu réel est éprouvé par banc-terrains-plan-navigateur-20261122.cjs.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const plan = lire('plateau-terrains-plan.js'), rue = lire('plateau-rue-centrale.js');

const ctx = { SURFACE_TERRAINS: { 'terrain-a-batir-3': 2300, 'republic|ville_b|terrain-a-batir-6': 2100, 'terrain-a-batir-6': 999 },
  logementsSociauxPour: ts => String(ts?.proprietaire || '').startsWith('ville:') };
vm.createContext(ctx); vm.runInContext(plan, ctx);
const P = ctx.RPTerrainsPlan, e = (id, ville, t0) => P.etatLot(id, ville, t0).etiquette.replace(/[  ]/g, ' ');

test('étiquettes : à vendre, acheté, chantier, à réceptionner, achevé (avec la surface du serveur d’abord)', () => {
  assert.equal(e('terrain-a-batir-3', 'capitale', {}), 'Lot 3 — 2 300 m² — À vendre');
  assert.equal(e('terrain-a-batir-3', 'capitale', { surface: 2400 }), 'Lot 3 — 2 400 m² — À vendre');
  assert.equal(e('terrain-a-batir-6', 'ville_b', {}), 'Lot 6 — 2 100 m² — À vendre', 'surface propre à Montrouge');
  assert.equal(e('terrain-a-batir-3', 'capitale', { proprietaire: 'Jean Jaaj' }), 'Lot 3 — 2 300 m² — Terrain de Jean Jaaj');
  assert.equal(e('terrain-a-batir-3', 'capitale', { proprietaire: 'Arnie', chantier: { progressionJours: 11.3, dureeJours: 24 } }), 'Lot 3 — Chantier 47 %');
  assert.equal(e('terrain-a-batir-3', 'capitale', { chantier: { progressionJours: 24, dureeJours: 24, attenteReception: true } }), 'Lot 3 — Chantier 100 % — à réceptionner');
  assert.equal(e('terrain-a-batir-3', 'capitale', { proprietaire: 'Arnie', niveau_construction: 'building' }), 'Lot 3 — Building d’Arnie');
  assert.equal(e('terrain-a-batir-3', 'capitale', { proprietaire: 'Lina', niveau_construction: 'commerce_premium' }), 'Lot 3 — Commerce premium de Lina');
  assert.equal(e('terrain-a-batir-3', 'capitale', { proprietaire: 'ville:capitale', niveau_construction: 'logement' }), 'Lot 3 — Logements sociaux de la mairie');
  assert.equal(e('terrain-a-batir-3', 'capitale', { proprietaire: 'Lina', niveau_construction: 'logement' }), 'Lot 3 — Logement de Lina');
  assert.equal(e('terrain-a-batir-3', 'capitale', { niveau_construction: 'hangar' }), 'Lot 3 — Hangar');
});
test('tant que le serveur n’a pas répondu : seulement ce qui ne change jamais', () => {
  const x = P.etatLot('terrain-a-batir-3', 'capitale', null);
  assert.equal(x.etat, 'inconnu'); assert.equal(x.etiquette.replace(/[  ]/g, ' '), 'Lot 3 — 2 300 m²');
});
test('ligne serveur : data en texte JSON, colonnes proprietaire et niveau_construction en secours', () => {
  const d = P.lireLigne({ data: '{"surface":1500}', proprietaire: 'Arnie', niveau_construction: 'hangar' });
  assert.equal(d.surface, 1500); assert.equal(d.proprietaire, 'Arnie'); assert.equal(d.niveau_construction, 'hangar');
  assert.deepEqual({ ...P.lireLigne({ data: 'pas du json' }) }, {});
});
test('branchements : rue des lots de Luthécia, vue des terrains de PSM et Montrouge, retrait dans une vraie pièce, page', () => {
  assert.match(rue, /planLots: 'capitale'/);
  assert.match(rue, /afficherPlanLots\(scene, noeud\.planLots, 'rue'\)/);
  assert.match(rue, /afficherPlanLots\(pieceImg, ville, 'piece'\)/);
  assert.match(lire('plateau-navigation.js'), /if \(typeof retirerPlanLots === 'function'\) retirerPlanLots\(\);/);
  const html = lire('plateau.html');
  assert.ok(html.indexOf('plateau-terrains-plan.js') > html.indexOf('plateau-chantier-vue.js'), 'après la vue du chantier');
  assert.match(plan, /setInterval\(suivre, 15000\)/);
});
test('rue en trois états : Luthécia (images livrées) et Montrouge (emplacement prêt, repli)', () => {
  assert.match(rue, /imagesEtatsTerrains: \{ ville: 'capitale', etat2: 'images\/terrains\/luthecia\/rue-etat-2\.webp', etat3: 'images\/terrains\/luthecia\/rue-etat-3\.webp' \}/);
  assert.match(rue, /imagesEtatsTerrains: \{ ville: 'ville_b', etat2: 'images\/terrains\/montrouge\/rue-etat-2\.webp', etat3: 'images\/terrains\/montrouge\/rue-etat-3\.webp' \}/);
  for (const f of ['images/terrains/luthecia/rue-etat-2.webp', 'images/terrains/luthecia/rue-etat-3.webp'])
    assert.equal(fs.readFileSync(path.join(root, f)).slice(8, 12).toString(), 'WEBP', f);
});
