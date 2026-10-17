// Tests de non-regression du calendrier du polling football.
// node --test outils/bancs/test-calendrier-polling-football.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../plateau-core.js', import.meta.url), 'utf8');
function extraireFonction(nom, nomSuivant) {
  const debut = source.indexOf('  function ' + nom + '(');
  assert.ok(debut >= 0, 'Fonction ' + nom + ' introuvable');
  const fin = source.indexOf('  async function ' + nomSuivant + '(', debut);
  assert.ok(fin > debut, 'Fin de fonction ' + nom + ' introuvable');
  return source.slice(debut, fin);
}
const script = extraireFonction('estDimancheParis', 'verifierSaisonSelonCalendrier') +
  extraireFonction('estFenetreFootballLive', 'tickFootballSelonCalendrier') +
  '\n({ estDimancheParis, estFenetreFootballLive })';
const { estDimancheParis, estFenetreFootballLive } = vm.runInNewContext(script, { Intl, Date, Number });

test('semaine inactive, même à 20h Paris', () => {
  const lundi = new Date('2026-10-19T18:00:00Z');
  assert.equal(estDimancheParis(lundi), false);
  assert.equal(estFenetreFootballLive(lundi), false);
});
test('dimanche avant 19h45 et après 21h inactif', () => {
  assert.equal(estFenetreFootballLive(new Date('2026-10-18T17:44:00Z')), false);
  assert.equal(estFenetreFootballLive(new Date('2026-10-18T19:01:00Z')), false);
});
test('dimanche 19h45-21h heure française en octobre', () => {
  assert.equal(estDimancheParis(new Date('2026-10-18T17:45:00Z')), true);
  assert.equal(estFenetreFootballLive(new Date('2026-10-18T17:45:00Z')), true);
  assert.equal(estFenetreFootballLive(new Date('2026-10-18T18:25:00Z')), true);
  assert.equal(estFenetreFootballLive(new Date('2026-10-18T19:00:00Z')), true);
});
test('passage à l’heure d’hiver sans décalage du match', () => {
  assert.equal(estFenetreFootballLive(new Date('2026-11-01T18:45:00Z')), true);
  assert.equal(estFenetreFootballLive(new Date('2026-11-01T20:01:00Z')), false);
});
test('passage à l’heure d’été sans décalage du match', () => {
  assert.equal(estFenetreFootballLive(new Date('2027-04-04T17:45:00Z')), true);
  assert.equal(estFenetreFootballLive(new Date('2027-04-04T19:01:00Z')), false);
});
