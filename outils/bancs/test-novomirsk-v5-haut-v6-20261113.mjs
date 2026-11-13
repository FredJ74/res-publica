// Novomirsk V5 (Centre d'affaires / Grand Hôtel) : flèche du haut vers les Ambassades et
// l'Armurerie (V6), retour de V6 vers V5 par le bas, pas de rue à gauche (Fred, 12 et 13/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('plateau-rue-centrale.js') + lire('plateau-plan-rues.js'), ctx);
const n = vm.runInContext('RUE_CENTRALE_NOEUDS.soviet', ctx);
test('V5 : haut vers V6, droite vers V4, pas de gauche ; V6 : haut vers V7, bas vers V5', () => {
  assert.deepEqual({ ...n['novomirsk-vue-5'].liens }, { toutDroit: 'novomirsk-vue-6', droite: 'novomirsk-vue-4' });
  assert.deepEqual({ ...n['novomirsk-vue-6'].liens }, { toutDroit: 'novomirsk-vue-7', arriere: 'novomirsk-vue-5' });
  assert.equal(n['novomirsk-vue-6'].flechesStyle.arriere, vm.runInContext('RC_FLECHE_BAS', ctx));
  assert.equal(n['novomirsk-vue-7'].liens.arriere, 'novomirsk-vue-6');
  // La rue du notaire (V3) reste accessible depuis le Grand Hôtel (V4), dans les deux sens.
  assert.equal(n['novomirsk-vue-4'].liens.toutDroit, 'novomirsk-vue-3');
  assert.equal(n['novomirsk-vue-3'].liens.arriere, 'novomirsk-vue-4');
});
test('graphe de l’écran symétrique autour de V3 à V7', () => {
  const voisins = id => new Set(Object.values(n[id].liens || {}).filter(Boolean));
  for (const id of ['novomirsk-vue-3', 'novomirsk-vue-4', 'novomirsk-vue-5', 'novomirsk-vue-6', 'novomirsk-vue-7'])
    for (const v of voisins(id)) if (n[v]) assert.ok(voisins(v).has(id) || v === 'novomirsk-vue-15' || v === 'novomirsk-vue-2' || v === 'novomirsk-vue-8' || v === 'novomirsk-vue-18', id + ' → ' + v + ' sans retour');
  assert.ok(!voisins('novomirsk-vue-5').has('novomirsk-vue-3'));
});
test('le serveur suit l’écran (migration du 13/11)', () => {
  const sql = lire('migrations/20261113113500_novomirsk_v5_haut_vers_v6.sql');
  assert.match(sql, /voisins = ARRAY\['novomirsk-vue-4','novomirsk-vue-6'\][\s\S]*"toutDroit":"novomirsk-vue-6","droite":"novomirsk-vue-4"[\s\S]*noeud = 'novomirsk-vue-5'/);
  assert.match(sql, /voisins = ARRAY\['novomirsk-vue-5','novomirsk-vue-7'\][\s\S]*"arriere":"novomirsk-vue-5"[\s\S]*noeud = 'novomirsk-vue-6'/);
  assert.match(sql, /array_remove\(voisins, 'novomirsk-vue-5'\)[\s\S]*noeud = 'novomirsk-vue-3'/);
  assert.match(sql, /RAISE EXCEPTION/);
});
test('plan : aucune anomalie, le carrefour de l’hôtel reste à sa place', () => {
  const pl = vm.runInContext('calculerPlanRues(RUE_CENTRALE_NOEUDS.soviet, RUE_CENTRALE_DEPART.soviet.capitale)', ctx);
  assert.equal(pl.anomalies.length, 0, JSON.stringify(pl.anomalies));
  const d = (a, b) => Math.hypot(pl.noeuds[a].x - pl.noeuds[b].x, pl.noeuds[a].y - pl.noeuds[b].y);
  assert.ok(d('novomirsk-vue-4', 'novomirsk-vue-3') < 1.5);
});
