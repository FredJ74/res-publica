// Novomirsk : depuis le quai du marché (V16), flèche de droite vers la rue de l'hôpital (V15) (Fred, 13/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('plateau-rue-centrale.js') + lire('plateau-plan-rues.js'), ctx);
const n = vm.runInContext('RUE_CENTRALE_NOEUDS.soviet', ctx);
test('V16 : droite vers V15, liens existants conservés ; V15 mène toujours à V16', () => {
  assert.deepEqual({ ...n['novomirsk-vue-16'].liens }, { arriere: 'novomirsk-vue-14', toutDroit: 'novomirsk-vue-17', droite: 'novomirsk-vue-15' });
  assert.equal(n['novomirsk-vue-15'].liens.droite, 'novomirsk-vue-16');
  assert.equal(n['novomirsk-vue-15'].memeCarrefour, 'novomirsk-vue-14');
});
test('le serveur suit l’écran (migration du 13/11)', () => {
  const sql = lire('migrations/20261113150000_novomirsk_quai_retour_hopital.sql');
  assert.match(sql, /'\{"droite":"novomirsk-vue-15"\}'[\s\S]*noeud = 'novomirsk-vue-16'/);
  assert.match(sql, /RAISE EXCEPTION/);
});
test('plan : aucune anomalie dans les 8 villes, carrefours V4/V5 et V14/V15 chacun en un point', () => {
  const D = vm.runInContext('RUE_CENTRALE_DEPART', ctx);
  for (const [p, villes] of Object.entries(D)) for (const d of Object.values(villes)) {
    const pl = vm.runInContext(`calculerPlanRues(RUE_CENTRALE_NOEUDS.${p}, ${JSON.stringify(d)})`, ctx);
    assert.equal(pl.anomalies.length, 0, p + ' ' + d + ' ' + JSON.stringify(pl.anomalies));
  }
  const pl = vm.runInContext('calculerPlanRues(RUE_CENTRALE_NOEUDS.soviet, RUE_CENTRALE_DEPART.soviet.capitale)', ctx);
  const d = (a, b) => Math.hypot(pl.noeuds[a].x - pl.noeuds[b].x, pl.noeuds[a].y - pl.noeuds[b].y);
  assert.ok(d('novomirsk-vue-4', 'novomirsk-vue-5') < 0.01);
  assert.ok(d('novomirsk-vue-14', 'novomirsk-vue-15') < 0.01);
});
test('cache : versions de la navigation et du plan à jour dans plateau.html (régressées par #861)', () => {
  const html = lire('plateau.html');
  assert.match(html, /plateau-rue-centrale\.js\?v=[^"]*quai-hopital-20261113"/);
  assert.match(html, /plateau-plan-rues\.js\?v=[^"]*carrefour-declare-20261113-quai-hopital-20261113"/);
});
