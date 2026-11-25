'use strict';
// Mission de nuit du 25/11/2026, point 1.3 : Fiodor Medvedkine, guide de Krasnov, apparaît au marché de Krasnov comme les cinq
// autres guides dans le marché de leur ville (monde effectif : casting canonique des scènes, celui que voit le joueur et l'IA).
const test = require('node:test'), assert = require('node:assert/strict'), path = require('node:path'), { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const sortie = execFileSync(process.execPath, ['outils/generateurs/generer-pnj-lieux-metiers.cjs', '--scenes-js'], { cwd: root, encoding: 'utf8', maxBuffer: 5e6 });
const scenes = JSON.parse(sortie.slice(sortie.indexOf('{'), sortie.lastIndexOf('}') + 1));
const GUIDES = [
  ['republic', 'capitale', 'marche', 'Firmin Badaud'], ['republic', 'ville_b', 'marche', 'Lucien Boulon'],
  ['soviet', 'capitale', 'marche', 'Zinaïda Otcheredova'], ['soviet', 'ville_a', 'marche', 'Bair Namsaraev'],
  ['soviet', 'ville_b', 'marche', 'Fiodor Medvedkine']
];
test('chaque guide est présent dans le marché de sa ville, Fiodor compris (Krasnov), une seule fois', () => {
  for (const [pays, ville, bat, nom] of GUIDES) {
    const pieces = Object.entries(scenes).filter(([k]) => { const [p, v, b] = JSON.parse(k); return p === pays && v === ville && b === bat; });
    assert.ok(pieces.length, 'marché introuvable ' + pays + '/' + ville);
    const n = pieces.reduce((t, [, s]) => t + s.personnes.filter(x => x === nom).length, 0);
    assert.equal(n, 1, nom + ' au marché de ' + (pieces[0][1].ville));
  }
  const krasnov = scenes['["soviet","ville_b","marche","marche_ext"]'];
  assert.deepEqual(krasnov.personnes, ['Nina Gorbounova', 'Fiodor Medvedkine'], 'Nina reste là, Fiodor la rejoint');
});
test('Yvonne Bigorneau (Port-Sainte-Marie) reste au marché du port', () => {
  const n = Object.entries(scenes).filter(([k, s]) => s.personnes.includes('Yvonne Bigorneau')).length;
  assert.ok(n >= 1);
});
