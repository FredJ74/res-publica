// Descriptions des pièces propres à Sovarka : neuf langues, seulement en Sovarka, français et Républia inchangés (12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
function charger(pays, langue, lireSource = lire) {
  const ctx = { RP_I18N_GAME_ENABLED: true, state: { country: pays }, RPPlateauI18n: { language: () => langue } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lireSource('i18n/sovarka-descriptions-resources.js'), ctx);
  return ctx.RPSovarkaDescI18n;
}
function descriptionsAffichees(lireSource = lire) {
  // Mêmes règles que plateau-navigation.js : override de pièce, puis desc du bâtiment (1re pièce), puis desc de la pièce.
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lireSource('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  const parPays = p => { const m = new Set(); for (const city of Object.values(ctx.WORLD[p] || {})) for (const b of city.buildings || []) {
    const c = city.buildingContext?.[b] || {}; let first = true;
    for (const [r, room] of Object.entries({ ...(ctx.BUILDINGS[b]?.rooms || {}), ...(c.roomsExtra || {}) })) {
      if (c.roomsExclues?.includes(r)) continue;
      const d = c.roomOverrides?.[r]?.desc || ((first && c.desc) ? c.desc : (room?.desc || '')); first = false; if (d) m.add(d);
    } } return m; };
  const rep = parPays('republic');
  return [...parPays('soviet')].filter(d => !rep.has(d));
}
test('neuf colonnes non vides pour chaque description', () => {
  const src = lire('i18n/sovarka-descriptions-resources.js');
  const lignes = [...src.matchAll(/^\s*\[("[^\n]+")\],?$/gm)].map(m => JSON.parse('[' + m[1] + ']'));
  assert.ok(lignes.length >= 133);
  for (const l of lignes) { assert.equal(l.length, 9, l[0]); for (const v of l) assert.ok(v.trim(), l[0]); }
});
test(process.env.RP_I18N_KRASNOV_BASELINE ? 'descriptions Sovarka : dix absences corrigées, aucune nouvelle lacune face au main figé' : 'toute description propre à Sovarka affichée par le jeu est au catalogue', t => {
  const textes = new Set(charger('soviet', 'en').textes);
  const manquantes = descriptionsAffichees().filter(d => !textes.has(d));
  let attendues = [];
  if (process.env.RP_I18N_KRASNOV_BASELINE) {
    const preuve = JSON.parse(lire('outils/audits/I18N-KRASNOV-DESCRIPTIONS-871-preuve.json'));
    const ancien = f => execFileSync('git', ['show', preuve.integrationMainCommit + ':' + f], { cwd: new URL('../../', import.meta.url), encoding: 'utf8', maxBuffer: 4e6 });
    const anciennes = new Set(charger('soviet', 'en', ancien).textes);
    const manquantesAvant = descriptionsAffichees(ancien).filter(d => !anciennes.has(d));
    const lot = JSON.parse(lire('outils/audits/I18N-KRASNOV-DESCRIPTIONS-871-sources.json'));
    assert.equal(lot.length, 10);
    for (const texte of lot) assert.ok(manquantesAvant.includes(texte), 'absence initiale vérifiée : ' + texte);
    attendues = manquantesAvant.filter(d => !lot.includes(d));
    t.diagnostic(attendues.length + ' descriptions antérieures hors lot encore non traduites ; contrôle global sans cette option inchangé.');
  }
  // Santé et forêt (Fred, 22/11/2026, point 18) : nouveaux textes des quatre vues de la forêt de Krasnov, en français
  // seulement ; leurs traductions sont à ajouter au catalogue par Codex (RELAIS.md). Tant qu'elles manquent, ils restent en français.
  const FORET_SANTE_EN_ATTENTE = [
    'Des souches fraîches, des grumes empilées au bord d’une piste défoncée. Les bûcherons ne sont pas loin.',
    'Des souches partout, une odeur de résine. Quelque chose a gratté l’écorce d’un bouleau, bien haut.',
    'La forêt se referme. Les fougères montent aux genoux, et des empreintes larges comme une assiette marquent l’humus.',
    'Un sentier à peine tracé sous les feuilles mortes. Au loin, une odeur de feu de bois et de soupe aux choux.'
  ];
  attendues = attendues.concat(FORET_SANTE_EN_ATTENTE);
  // « Aucune nouvelle lacune » : une lacune antérieure comblée depuis par un autre lot (15/11) est bienvenue.
  assert.deepEqual(manquantes.filter(d => !attendues.includes(d)), []);
});
test('traduit en Sovarka seulement, jamais en français, texte inconnu intact', () => {
  const fr = 'Les verdicts sont décidés avant l\'audience.';
  assert.equal(charger('soviet', 'en').desc(fr), 'Verdicts are decided before the hearing.');
  assert.equal(charger('republic', 'en').desc(fr), fr);
  assert.equal(charger('soviet', 'fr').desc(fr), fr);
  assert.equal(charger('soviet', 'en').desc('Texte inconnu'), 'Texte inconnu');
  assert.match(charger('soviet', 'de').desc('Commerce installé dans le premier grand local des galeries.'), /Galerien/);
});
test('montants et sigles conservés dans toutes les langues', () => {
  const src = lire('i18n/sovarka-descriptions-resources.js');
  for (const m of src.matchAll(/^\s*\[("[^\n]+")\],?$/gm)) {
    const l = JSON.parse('[' + m[1] + ']');
    for (const n of (l[0].match(/\d+ PSK/g) || [])) for (const v of l) assert.ok(v.includes(n), l[0] + ' → ' + v);
  }
});
test('affichage et bascule de langue branchés', () => {
  const nav = lire('plateau-navigation.js');
  assert.match(nav, /displayDesc = RPSovarkaDescI18n\.desc\(displayDesc\)/);
  assert.match(nav, /data-rp-desc-source/);
  assert.match(nav, /RPSovarkaDescI18n\.desc\(src\)/);
  assert.ok(lire('plateau.html').includes('i18n/sovarka-descriptions-resources.js'));
});
