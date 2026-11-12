// Fiches des musées de Sovarka : toutes au catalogue, huit langues complètes, français inchangé (12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
function charger(langue) {
  const ctx = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => langue } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/musee-sovarka-resources.js'), ctx);
  vm.runInContext(lire('plateau-musee-personnalites.js').replace(/^const (\w+) =/gm, 'var $1 ='), ctx);
  return ctx;
}
const SOVARKA = ['musee-novomirsk', 'palais-presidentiel'];
function fichesSovarka(ctx) {
  return SOVARKA.flatMap(b => Object.values(ctx.MUSEE_PROVINCE_PERSONNALITES[b]).flat());
}
test('chaque fiche des musées de Sovarka est au catalogue, avec huit traductions non vides', () => {
  const ctx = charger('fr');
  const fiches = fichesSovarka(ctx);
  assert.equal(fiches.length, 41);
  const noms = new Set(ctx.RPMuseeSovarkaI18n.noms);
  for (const f of fiches) assert.ok(noms.has(f.nom), f.nom);
  for (const lang of ctx.RPMuseeSovarkaI18n.langues) {
    const c = charger(lang);
    for (const f of fichesSovarka(c)) {
      const t = c.RPMuseeSovarkaI18n.fiche(f);
      assert.ok(t.nom.trim() && t.dates.trim() && t.bio.trim(), lang + ' ' + f.nom);
      assert.notEqual(t.bio, f.bio, lang + ' ' + f.nom);
      if (!/^\d/.test(f.dates)) assert.notEqual(t.dates, f.dates, lang + ' dates ' + f.nom);
    }
  }
});
test('français et fiches hors catalogue inchangés', () => {
  const fr = charger('fr'), en = charger('en');
  const f = fr.MUSEE_PROVINCE_PERSONNALITES['musee-novomirsk'].salle_personnalites_discretes[0];
  assert.equal(fr.RPMuseeSovarkaI18n.fiche(f), f);
  const rep = en.MUSEE_NATIONAL_PERSONNALITES.salle_politiques[0];
  assert.equal(en.RPMuseeSovarkaI18n.fiche(rep), rep);
  assert.equal(en.RPMuseeSovarkaI18n.fiche(f).nom, f.nom);
  assert.match(en.RPMuseeSovarkaI18n.fiche(f).bio, /^Inventor of a loom/);
  assert.equal(en.RPMuseeSovarkaI18n.ui('retour', 'Retour à la liste'), 'Back to the list');
  assert.equal(fr.RPMuseeSovarkaI18n.ui('retour', 'Retour à la liste'), 'Retour à la liste');
});
test('liste et fiche passent par le traducteur ; script chargé par la page', () => {
  const src = lire('plateau-musee-personnalites.js');
  assert.match(src, /personnalitesMuseeCourantes\(\)\.map\(ficheMuseeAffichee\)/);
  assert.match(src, /ficheMuseeAffichee\(liste\[idx\]\)/);
  assert.ok(lire('plateau.html').includes('i18n/musee-sovarka-resources.js'));
});
