// Rue des terrains en trois états et images de Port-Sainte-Marie (Fred, 20/11/2026 étape J ; images reçues le 22/11/2026).
// Aucune réception → état 1 (image actuelle) ; une réception → état 2 ; toutes → état 3 ; fichier manquant → image actuelle.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), src = fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8');
const extraire = nom => { const i = src.indexOf('function ' + nom + '('); assert.ok(i >= 0, nom); let n = 0, j = src.indexOf('{', i);
  for (let k = j; k < src.length; k++) { if (src[k] === '{') n++; else if (src[k] === '}' && --n === 0) return src.slice(i, k + 1); } };
const ctx = {}; vm.createContext(ctx); vm.runInContext(extraire('etatRueTerrains') + '\n' + extraire('imageRueTerrains'), ctx);
const IDS = ['terrain-a-batir-8', 'terrain-a-batir-9', 'terrain-a-a'];
const ligne = (id, niveau) => ({ id: 'republic_' + id, niveau_construction: niveau });
const NOEUD = { image: 'images/rue-terrains-vente-psm.webp', imagesEtatsTerrains: { ville: 'ville_a', etat2: 'images/terrains/psm/rue-terrains-psm-etat2.webp', etat3: 'images/terrains/psm/rue-terrains-psm-etat3.webp' } };

test('aucune réception : état 1, image actuelle', () => {
  assert.equal(ctx.etatRueTerrains(IDS, [ligne(IDS[0], null), { id: 'soviet_terrain-a-batir-8', niveau_construction: 'hangar' }]), 1);
  assert.equal(ctx.imageRueTerrains(NOEUD, 1), NOEUD.image);
});
test('une réception : état 2 ; toutes : état 3', () => {
  assert.equal(ctx.etatRueTerrains(IDS, [ligne(IDS[1], 'hangar')]), 2);
  assert.equal(ctx.imageRueTerrains(NOEUD, 2), NOEUD.imagesEtatsTerrains.etat2);
  assert.equal(ctx.etatRueTerrains(IDS, IDS.map(i => ligne(i, 'building'))), 3);
  assert.equal(ctx.imageRueTerrains(NOEUD, 3), NOEUD.imagesEtatsTerrains.etat3);
});
test('image d’un état non déclarée : image actuelle', () => {
  assert.equal(ctx.imageRueTerrains({ image: 'a.webp', imagesEtatsTerrains: { ville: 'ville_b' } }, 3), 'a.webp');
});
test('la rue des terrains de Port-Sainte-Marie est branchée et toutes les images reçues sont dans le dépôt', () => {
  assert.match(src, /imagesEtatsTerrains: \{ ville: 'ville_a', etat2: 'images\/terrains\/psm\/rue-terrains-psm-etat2\.webp'/);
  assert.match(src, /appliquerEtatRueTerrains\(noeudId, noeud\)/);
  const psm = ['chantier_demarrage_petit', 'chantier_demarrage_grand', 'chantier_fondations', 'chantier_gros_oeuvre', 'chantier_facade',
    'batiment_hangar', 'batiment_commerce_standard', 'batiment_commerce_premium', 'batiment_logement', 'batiment_building'].map(n => 'images/chantiers/psm/PSM_' + n + '.webp');
  for (const f of [...psm, 'images/terrains/psm/rue-terrains-psm-etat2.webp', 'images/terrains/psm/rue-terrains-psm-etat3.webp',
    'images/rue-terrains-lots-detail-psm.webp', 'images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp']) {
    const b = fs.readFileSync(path.join(root, f)); assert.equal(b.slice(8, 12).toString(), 'WEBP', f);
  }
});
