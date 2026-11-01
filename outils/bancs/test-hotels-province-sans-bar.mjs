// Hôtels de province (décision de Fred, 02/11/2026) : l'Hôtel du Port (PSM) et l'Hôtel des Mineurs /
// de la Victoire (Montrouge) n'ont ni restaurant ni bar. Pas d'écoute des tables, de rumeur,
// d'informateur ni de tournée dans leur hall ; ces ordres restent aux restaurants et à La Républia.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const src = readFileSync(new URL('../../data.js', import.meta.url), 'utf8');
const INTERDITS = ['ecouter_rumeurs', 'lancer_rumeur_cible', 'recruter_informateur_pnj', 'offrir_tournee'];

function salle(batiment, piece) {
  const b = src.indexOf(`\n  '${batiment}': {`);
  assert.ok(b > 0, `bâtiment ${batiment} introuvable`);
  const p = src.indexOf(`\n      ${piece}: {`, b);
  assert.ok(p > 0, `salle ${piece} introuvable`);
  const fin = src.indexOf('\n      },', p);
  return src.slice(p, fin);
}

for (const [batiment, piece] of [['hotel-port', 'hall_port'], ['hotel-mineur', 'hall_mineur']]) {
  test(`${batiment} : hall sans ordres de bar`, () => {
    const s = salle(batiment, piece);
    assert.match(s, /reserver_chambre_hotel/);
    for (const fn of INTERDITS) assert.doesNotMatch(s, new RegExp(`fn:'${fn}'`), `${fn} présent dans ${batiment}`);
  });
}

test('La Républia garde ses ordres de bar', () => {
  const b = src.indexOf("\n  'hotel-republica': {");
  const s = src.slice(b, src.indexOf("\n  'hotel-port': {"));
  for (const fn of INTERDITS) assert.match(s, new RegExp(`fn:'${fn}'`));
});
