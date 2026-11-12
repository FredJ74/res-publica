// Rôles des PNJ de Sovarka : neuf langues, seulement en Sovarka, français et Républia inchangés (12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
function charger(pays, langue) {
  const ctx = { RP_I18N_GAME_ENABLED: true, state: { country: pays }, RPPlateauI18n: { language: () => langue } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/sovarka-roles-resources.js'), ctx);
  return ctx.RPSovarkaRolesI18n;
}
test('neuf colonnes non vides pour chaque rôle', () => {
  const src = lire('i18n/sovarka-roles-resources.js');
  const lignes = [...src.matchAll(/^\s*\[("[^\n]+")\],?$/gm)].map(m => JSON.parse('[' + m[1] + ']'));
  assert.ok(lignes.length >= 130);
  for (const l of lignes) { assert.equal(l.length, 9, l[0]); for (const v of l) assert.ok(v.trim(), l[0]); }
});
test('préfixe et suffixe PNJ localisés, cœur traduit', () => {
  assert.equal(charger('soviet', 'en').label('PNJ - Greffe'), 'NPC - Court registry');
  assert.equal(charger('soviet', 'de').label('PNJ - Soldat'), 'NSC - Soldat');
  assert.equal(charger('soviet', 'en').label('Médecin (PNJ)'), 'Doctor (NPC)');
  assert.equal(charger('soviet', 'ko').label('Coiffeuse'), '미용사');
});
test('aucun effet hors Sovarka, en français ou sur un rôle inconnu', () => {
  assert.equal(charger('republic', 'en').label('PNJ - Greffe'), 'PNJ - Greffe');
  assert.equal(charger('soviet', 'fr').label('PNJ - Greffe'), 'PNJ - Greffe');
  assert.equal(charger('soviet', 'en').label('Rôle inconnu'), 'Rôle inconnu');
  assert.equal(charger('soviet', 'en').label(undefined), undefined);
});
test('les trois affichages passent par le traducteur, le rôle source reste dans les données', () => {
  const mj = lire('plateau-multijoueur.js'), pnj = lire('plateau-pnj.js');
  assert.equal((mj.match(/roleAfficheSovarka\(p\.role\)/g) || []).length, 2);
  assert.match(mj, /function roleAfficheSovarka\(role\)/);
  assert.match(pnj, /roleAfficheSovarka\(pnj\.role\?\.replace\(' \(PNJ\)', ''\)/);
  assert.ok(lire('plateau.html').includes('i18n/sovarka-roles-resources.js'));
});
