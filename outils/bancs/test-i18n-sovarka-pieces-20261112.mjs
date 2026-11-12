// Noms des pièces propres à Sovarka : neuf langues, seulement en Sovarka, français inchangé (12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
function charger(pays, langue) {
  const ctx = { RP_I18N_GAME_ENABLED: true, state: { country: pays }, RPPlateauI18n: { language: () => langue } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/sovarka-pieces-resources.js'), ctx);
  return ctx.RPSovarkaPiecesI18n;
}
test('neuf colonnes non vides pour chaque nom', () => {
  const src = lire('i18n/sovarka-pieces-resources.js');
  const lignes = [...src.matchAll(/^\s*\[("[^\n]+")\],?$/gm)].map(m => JSON.parse('[' + m[1] + ']'));
  assert.ok(lignes.length >= 80);
  for (const l of lignes) { assert.equal(l.length, 9, l[0]); for (const v of l) assert.ok(v.trim(), l[0]); }
});
test('traduit en Sovarka, jamais ailleurs, jamais en français', () => {
  assert.equal(charger('soviet', 'en').label('x', 'y', 'Salle d’écoute'), 'Listening room');
  assert.equal(charger('soviet', 'ar').label('x', 'y', 'Douanes'), 'الجمارك');
  assert.equal(charger('republic', 'en').label('x', 'y', 'Salle d’écoute'), 'Salle d’écoute');
  assert.equal(charger('soviet', 'fr').label('x', 'y', 'Salle d’écoute'), 'Salle d’écoute');
  assert.equal(charger('soviet', 'en').label('x', 'y', 'Nom inconnu'), 'Nom inconnu');
});
test('chaque nom français existe tel quel dans les données', () => {
  const data = lire('data.js').replace(/\\'/g, "'");
  // Noms parfois assemblés (« Forêt profonde — » + lieu, « EHPAD de » + ville, « Local n° » + numéro) :
  // chaque morceau fixe doit exister tel quel dans data.js.
  for (const nom of charger('soviet', 'fr').noms) {
    for (const morceau of nom.split(' — ')) {
      const fixe = morceau.split(/(?:Starovka|Krasnov|Novomirsk|\d)/)[0].trim();
      assert.ok(data.includes(morceau) || (fixe.length >= 6 && data.includes(fixe)), nom + ' / ' + morceau);
    }
  }
});
test('le traducteur de pièces consulte Sovarka en dernier recours, et le catalogue est chargé', () => {
  const rr = lire('i18n/room-resources.js');
  assert.match(rr, /global\.RPSovarkaPiecesI18n\?\.label\?\.\(buildingId,roomId,original\)/);
  assert.match(rr, /global\.RPRoomI18n=Object\.freeze\(\{label:labelAvecSovarka,labelHtml:labelHtmlAvecSovarka\}\)/);
  assert.ok(lire('plateau.html').includes('i18n/sovarka-pieces-resources.js'));
});
