// « Fouiller ou voler » : un seul ordre vert, tout en bas, dans les pieces et les rues ; menu
// deroulant (fouille ou vol), chacun avec sa fenetre (decisions de Fred, 11/11/2026).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const racine = new URL('../../', import.meta.url);
const lire = f => fs.readFileSync(new URL(f, racine), 'utf8');

function charger() {
  const ctx = { window: {}, state: {}, console };
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-surveillance.js'), ctx);
  return ctx;
}

test('ordre de piece vert, place en bas, enregistre dans le registre', () => {
  const ctx = charger();
  assert.ok(ctx.window.RP_ORDRES_DYNAMIQUES.includes(ctx.ordresFouillerVoler));
  const [o] = ctx.ordresFouillerVoler('bureaux', 'bureau_1');
  assert.equal(o.fn, 'fouiller_voler');
  assert.equal(o.type, 'legal');
  assert.equal(o.basDeListe, true);
  assert.equal(ctx.ordresFouillerVoler(null, null).length, 0);
  assert.match(ctx.ordreFouillerVolerRueHtml(), /class="action-btn legal"[^>]*onclick="ouvrirMenuFouillerVoler\(this\)"/);
});

test('la liste des ordres met les ordres basDeListe a la fin ; la rue ajoute le bouton en dernier', () => {
  assert.match(lire('plateau-politique.js'), /\.concat\(dynOrders\.filter\(d => !d\.basDeListe\)\)\s*\n[^\n]*\n\s*\.concat\(dynOrders\.filter\(d => d\.basDeListe\)\)/);
  assert.match(lire('plateau-navigation.js'), /: ''\)\s*\n[^\n]*\n\s*\+ \(typeof ordreFouillerVolerRueHtml === 'function' \? ordreFouillerVolerRueHtml\(\) : ''\);/);
});

test('menu : deux choix, chacun vers sa fenetre ; plus de boutons dans la colonne', () => {
  const s = lire('plateau-surveillance.js');
  assert.match(s, /item\('🔍 Fouiller les lieux \(2 PA\)', ouvrirFenetreFouille\)/);
  assert.match(s, /item\('🕵 Voler du matériel installé \(3 PA\)', \(\) => \{ if \(typeof ouvrirVolMateriel === 'function'\) ouvrirVolMateriel\(\); \}\)/);
  assert.match(s, /equipementsModale\('Fouiller les lieux', html\)/);
  assert.ok(!s.includes('onclick="surveillanceFouiller()"'));
  assert.ok(!s.includes('onclick="ouvrirVolMateriel()"'));
  const routeur = lire('plateau-router.js');
  const i = routeur.indexOf("fn === 'fouiller_voler'");
  assert.ok(i > 0 && i < routeur.indexOf("fn === 'camion_militaire'"));
});
