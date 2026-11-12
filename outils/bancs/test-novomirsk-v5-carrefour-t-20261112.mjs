// Novomirsk V5 (Centre d'affaires / Grand Hôtel) : carrefour en T, pas de rue à gauche (Fred, 12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('plateau-rue-centrale.js') + lire('plateau-plan-rues.js'), ctx);
test('V5 : seulement tout droit (V3) et à droite (V4) ; V6 reliée à la seule V7', () => {
  const n = vm.runInContext('RUE_CENTRALE_NOEUDS.soviet', ctx);
  assert.deepEqual({ ...n['novomirsk-vue-5'].liens }, { toutDroit: 'novomirsk-vue-3', droite: 'novomirsk-vue-4' });
  assert.deepEqual({ ...n['novomirsk-vue-6'].liens }, { toutDroit: 'novomirsk-vue-7' });
  assert.equal(n['novomirsk-vue-7'].liens.arriere, 'novomirsk-vue-6');
});
test('le serveur suit l’écran (migration du jour)', () => {
  const sql = lire('migrations/20261112120000_novomirsk_v5_sans_fleche_gauche.sql');
  assert.match(sql, /array_remove\(voisins, 'novomirsk-vue-6'\)[\s\S]*noeud = 'novomirsk-vue-5'/);
  assert.match(sql, /array_remove\(voisins, 'novomirsk-vue-5'\)[\s\S]*noeud = 'novomirsk-vue-6'/);
});
test('plan : un carrefour photographié deux fois n’est pas une impasse ; aucune anomalie', () => {
  const pl = vm.runInContext('calculerPlanRues(RUE_CENTRALE_NOEUDS.soviet, RUE_CENTRALE_DEPART.soviet.capitale)', ctx);
  assert.equal(pl.anomalies.length, 0);
  const d = (a, b) => Math.hypot(pl.noeuds[a].x - pl.noeuds[b].x, pl.noeuds[a].y - pl.noeuds[b].y);
  assert.ok(d('novomirsk-vue-4', 'novomirsk-vue-3') < 1.5, 'le carrefour de l’hôtel reste à sa place');
});
