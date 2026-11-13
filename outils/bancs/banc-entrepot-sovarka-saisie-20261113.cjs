'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function extraire(fichier, debut, fin) {
  const source = fs.readFileSync(fichier, 'utf8');
  const a = source.indexOf(debut);
  const b = source.indexOf(fin, a + debut.length);
  assert.ok(a >= 0 && b > a, 'Fonction introuvable dans ' + fichier);
  return source.slice(a, b);
}
const lecture = extraire('supabase.js',
  'async function sbGetBatimentEtat(', '\n}\n\n// Blocus syndicaux') + '\n}';
const achat = extraire('plateau-justice-economie.js',
  'async function doOuvrirAchatEntrepot(', '\n}\n\nasync function confirmerAchatEntrepot') + '\n}';

async function rendre(data) {
  const noeuds = {};
  const context = {
    state: { country: 'soviet', currentCity: 'capitale',
      currentBuilding: 'entrepot-logistique-novomirsk' },
    COUNTRIES: { soviet: { cur: 'PSK' } },
    RESSOURCES_ECONOMIE: {
      bois: { label: 'Bois', icon: 'ti-trees', prixBase: 5 },
      metal: { label: 'Métal', icon: 'ti-tool', prixBase: 10 },
      charbon: { label: 'Charbon', icon: 'ti-flame', prixBase: 8 }
    },
    sbGet: async function () { return [{ data }]; },
    stockCivilDisponible: function (etat) { return etat.entrepot?.stock || {}; },
    rafraichirAssembleeInterdictions: async function () {},
    assembleeInterdictionMatiere: function () { return null; },
    getPrixRessourceEntrepot: function () { return 5; },
    ficheLibelleHtml: function (_cle, valeur) { return valeur; },
    document: { getElementById(id) {
      return noeuds[id] ||= { innerHTML: '', classList: { add() {} } };
    }},
    window: {},
    encodeURIComponent
  };
  vm.runInNewContext(lecture + '\n' + achat +
    '\nthis.ouvrir = doOuvrirAchatEntrepot;', context);
  await context.ouvrir(1, 0);
  return noeuds['postes-body'].innerHTML;
}
function champ(html, cle) {
  const match = html.match(new RegExp('<input[^>]*id="achat-entrepot-' + cle + '"[^>]*>'));
  assert.ok(match, 'Champ absent : ' + cle);
  return match[0];
}
test('JSONB objet de Novomirsk : les quantités en stock sont saisissables', async () => {
  const html = await rendre({ entrepot: { stock: { bois: 200, metal: 0, charbon: 400 } } });
  assert.doesNotMatch(champ(html, 'bois'), /\bdisabled\b/);
  assert.match(champ(html, 'bois'), /max="200"/);
  assert.doesNotMatch(champ(html, 'charbon'), /\bdisabled\b/);
  assert.match(champ(html, 'metal'), /\bdisabled\b/);
});
test('ancien entrepôt JSON en chaîne : quantités toujours saisissables', async () => {
  const donnees = { entrepot: { stock: { bois: 12, metal: 0 } } };
  for (const data of [JSON.stringify(donnees), JSON.stringify(JSON.stringify(donnees))]) {
    const html = await rendre(data);
    assert.doesNotMatch(champ(html, 'bois'), /\bdisabled\b/);
    assert.match(champ(html, 'bois'), /max="12"/);
  }
});
test('un vrai stock vide interdit toujours la quantité, sans inventer de stock', async () => {
  const html = await rendre({ entrepot: { stock: { bois: 0, metal: 0, charbon: 0 } } });
  assert.match(champ(html, 'bois'), /\bdisabled\b/);
});
test('JSON invalide ne doit jamais fabriquer du stock', async () => {
  const html = await rendre('{json cassé');
  assert.match(champ(html, 'bois'), /\bdisabled\b/);
});
