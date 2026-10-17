import test from 'node:test';
import assert from 'node:assert/strict';
import { jourUniverselISO, ajouterJoursCivils, joursCivilsEcoules, echeanceJoursAtteinte } from '../../api/_calendrier-universel.mjs';

test('minuit Paris commun, hiver', () => {
  assert.equal(jourUniverselISO(new Date('2026-01-04T22:59:00Z')), '2026-01-04');
  assert.equal(jourUniverselISO(new Date('2026-01-04T23:01:00Z')), '2026-01-05');
});
test('minuit Paris commun, été', () => {
  assert.equal(jourUniverselISO(new Date('2026-07-04T21:59:00Z')), '2026-07-04');
  assert.equal(jourUniverselISO(new Date('2026-07-04T22:01:00Z')), '2026-07-05');
});
test('deux passages de minuit ne sont pas 48 heures glissantes', () => {
  assert.equal(joursCivilsEcoules('2026-10-17', '2026-10-19'), 2);
  assert.equal(echeanceJoursAtteinte('2026-10-17', 2, '2026-10-18'), false);
  assert.equal(echeanceJoursAtteinte('2026-10-17', 2, '2026-10-19'), true);
});
test('jour civil conservé lors du passage aux heures été/hiver', () => {
  assert.equal(ajouterJoursCivils('2026-03-28', 2), '2026-03-30');
  assert.equal(ajouterJoursCivils('2026-10-24', 2), '2026-10-26');
  assert.equal(joursCivilsEcoules('2026-03-28', '2026-03-30'), 2);
  assert.equal(joursCivilsEcoules('2026-10-24', '2026-10-26'), 2);
});
test('dates invalides refusées', () => {
  assert.throws(() => ajouterJoursCivils('2026-02-30', 1));
  assert.throws(() => ajouterJoursCivils('2026-10-17', 1.5));
});
