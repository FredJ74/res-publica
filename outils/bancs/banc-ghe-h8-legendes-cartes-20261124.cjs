'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.8 : légendes des cartes postales, mot pour mot. Les dix cartes nommées
// existent toutes au catalogue (recettes_commerce, vérifié en base le 24/11/2026) : aucune n'a été créée.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const LEGENDES = {
  carte_starovka_hiver: 'Starovka — ici, la chaleur est dans les cœurs.',
  carte_psm_notre_dame_mer: 'Port-Sainte-Marie, sous la protection de Notre-Dame de la Mer.',
  carte_psm_touristique: 'Port-Sainte-Marie — le granit, les embruns et rien à déclarer.',
  carte_psm_culture_marine: 'Port-Sainte-Marie, où chaque marin a une histoire… et deux versions.',
  carte_montrouge_place_rail: "Montrouge, place du Rail — ici, même les statues sont à l'heure.",
  carte_montrouge_touristique: 'Bons baisers de Montrouge, la ville qui ne déraille jamais.',
  carte_montrouge_musee_rail: 'Musée du Rail de Montrouge — le progrès en marche, à 40 km/h.',
  carte_luthecia_institutions: 'Luthécia — la liberté, en trois exemplaires et dûment tamponnée.',
  carte_luthecia_internationale: 'Luthécia, capitale du monde (justificatif de séjour non fourni).',
  carte_luthecia_culture: 'Luthécia — la culture pour tous, sur réservation.'
};
test('H.8 — chaque carte affiche sa légende, mot pour mot, sous l’image', () => {
  const s = lire('plateau-personnage.js');
  const i = s.indexOf('const TEXTES_CARTE_POSTALE'), j = s.indexOf('\nfunction rectoCartePostaleHtml');
  const k = s.indexOf('\n}', s.indexOf('function rectoCartePostaleHtml')) + 2;
  const ctx = { globalThis: {}, escapeHtmlText: t => String(t) }; vm.createContext(ctx);
  vm.runInContext(s.slice(i, j) + s.slice(j, k) + ';this.recto = rectoCartePostaleHtml; this.leg = legendeCartePostale;', ctx);
  for (const [modele, texte] of Object.entries(LEGENDES)) {
    assert.equal(ctx.leg({ modele }), texte, modele);
    assert.ok(ctx.recto({ modele, imageUrl: 'x.webp' }, 200).includes('hg-carte-legende'), modele);
  }
  assert.equal(ctx.leg({ modele: 'carte_krasnov_place_ours' }), 'Krasnov, capitale de l’ours');
  // Toutes les cartes du catalogue client existent (aucune carte créée par ce point).
  const cat = lire('plateau-actions-illegales-rumeurs.js');
  for (const modele of Object.keys(LEGENDES)) assert.ok(cat.includes("id: '" + modele + "', label: 'Carte postale"), 'carte au catalogue : ' + modele);
});
