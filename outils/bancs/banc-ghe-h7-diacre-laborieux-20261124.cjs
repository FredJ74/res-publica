'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.7 : Grange Sainte, image gardée telle quelle ; « Frère Kolkhoze » devient
// « Diacre laborieux » (fiche et toutes les mentions). L'ancien identifiant de fiche renvoie à la nouvelle (R4).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
test('H.7 — Diacre laborieux partout, image gardée, plus aucun « Frère Kolkhoze » affiché', async () => {
  const d = lire('data.js');
  assert.match(d, /\{name:'Diacre laborieux \(PNJ\)', role:'PNJ - Diacre du Tractorisme', rel:'neutral', job:'clerc', ancienNom:'Frère Kolkhoze'\}/);
  assert.match(d, /\['kolkhoze-spirituel', 'grange_sainte', 'Diacre laborieux \(PNJ\)', 'novo-frere-kolkhoze-portrait\.webp'\]/);
  assert.match(d, /imageUrl: "images\/Sovarka\/Novomirsk\/Novomirsk_cathedrale_accueil\.webp"/, 'image de la Grange Sainte inchangée');
  assert.doesNotMatch(d, /name:\s*'Frère Kolkhoze/);
  const { TOUS_PROFILS } = await import(path.join(R, 'api/_pnj-profils.js'));
  assert.equal(TOUS_PROFILS.diacre_laborieux.nom, 'Diacre laborieux');
  assert.equal(TOUS_PROFILS.frere_kolkhoze.nom, 'Diacre laborieux', 'ancien identifiant redirigé');
  assert.match(TOUS_PROFILS.camarade_pontife_tractorenko.caractere, /le Diacre laborieux, ton jeune assistant/);
  for (const id of ['diacre_laborieux', 'camarade_pontife_tractorenko']) assert.doesNotMatch(JSON.stringify(TOUS_PROFILS[id]), /Frère Kolkhoze/);
  const { SCENES_PNJ } = await import(path.join(R, 'api/_pnj-scenes-generes.js'));
  const grange = SCENES_PNJ[JSON.stringify(['soviet', 'capitale', 'kolkhoze-spirituel', 'grange_sainte'])];
  assert.ok(grange.personnes.includes('Diacre laborieux') && !grange.personnes.includes('Frère Kolkhoze'));
  const { NON_FONCTIONNAIRES } = await import(path.join(R, 'api/_pnj-fonctionnaires-sovarka.js'));
  assert.ok(NON_FONCTIONNAIRES.has('diacre_laborieux'));
  assert.match(lire('GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md'), /\*\*Diacre laborieux\*\*\s+\(anciennement « Frère Kolkhoze »/);
});
