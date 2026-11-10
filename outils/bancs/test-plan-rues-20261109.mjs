import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const VILLES = [['republic', 'capitale'], ['republic', 'ville_a'], ['republic', 'ville_b'],
  ['soviet', 'capitale'], ['soviet', 'ville_a'], ['soviet', 'ville_b']];

function charger(st) {
  const elements = {};
  const document = { getElementById: id => (elements[id] = elements[id] || { id, innerHTML: '', textContent: '', classList: { add() { this.open = true; }, remove() {} } }) };
  const ctx = vm.createContext({ console, state: st || {}, document });
  for (const f of ['data.js', 'plateau-rue-centrale.js', 'plateau-plan-rues.js'])
    vm.runInContext(fs.readFileSync(path.join(root, f), 'utf8'), ctx, { filename: f });
  return { ctx, elements };
}

test('Plan déduit des rues : chaque ville à rues est entièrement posée, sans superposition', () => {
  const { ctx } = charger();
  for (const [p, v] of VILLES) {
    const r = vm.runInContext(`(() => {
      const depart = RUE_CENTRALE_DEPART['${p}']['${v}'];
      const comp = planRuesComposante(RUE_CENTRALE_NOEUDS['${p}'], depart);
      const plan = calculerPlanRues(RUE_CENTRALE_NOEUDS['${p}'], depart);
      return { comp, plan };
    })()`, ctx);
    const ids = Object.keys(r.plan.noeuds);
    assert.deepEqual([...ids].sort(), [...r.comp].sort(), `${p}/${v} : toutes les vues de la ville sont posées`);
    for (const id of ids) {
      const n = r.plan.noeuds[id];
      assert.ok(Number.isFinite(n.x) && Number.isFinite(n.y), `${p}/${v} ${id} : position calculée`);
    }
    const fusion = new Set(r.plan.fusions.map(([x, y]) => x < y ? x + '|' + y : y + '|' + x));
    for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
      const a = r.plan.noeuds[ids[i]], b = r.plan.noeuds[ids[j]];
      if (fusion.has(ids[i] < ids[j] ? ids[i] + '|' + ids[j] : ids[j] + '|' + ids[i])) continue;
      assert.ok(Math.hypot(a.x - b.x, a.y - b.y) > 0.7, `${p}/${v} : ${ids[i]} et ${ids[j]} ne se superposent pas`);
    }
    assert.ok(r.plan.rues.length >= ids.length - 1, `${p}/${v} : les rues relient la ville`);
  }
});

test('Plan déduit des rues : chaque bâtiment visible en rue figure une seule fois dans la légende', () => {
  const { ctx } = charger();
  for (const [p, v] of VILLES) {
    const r = vm.runInContext(`(() => {
      const depart = RUE_CENTRALE_DEPART['${p}']['${v}'];
      const noeuds = RUE_CENTRALE_NOEUDS['${p}'];
      const plan = calculerPlanRues(noeuds, depart);
      const attendus = new Set();
      for (const id of Object.keys(plan.noeuds)) for (const z of noeuds[id].zones || []) if (z.buildingId) attendus.add(z.buildingId);
      const d = dessinerPlanRues(plan, {});
      return { attendus: [...attendus], legende: d.legende, svg: d.svg };
    })()`, ctx);
    const ids = r.legende.map(l => l.id);
    assert.equal(new Set(ids).size, ids.length, `${p}/${v} : pas de doublon`);
    assert.deepEqual([...ids].sort(), [...r.attendus].sort(), `${p}/${v} : légende complète`);
    assert.deepEqual(r.legende.map(l => l.num), r.legende.map((_, k) => k + 1), `${p}/${v} : numéros 1..n`);
    assert.match(r.svg, /^<svg [^>]*>.*<\/svg>$/s);
    assert.doesNotMatch(r.svg, /NaN|undefined/);
  }
});

test('Plan déduit des rues : les carrefours photographiés deux fois ne sont pas des anomalies', () => {
  const { ctx } = charger();
  // Novomirsk V5→V3 et V15→V16 : le retour ramène à l'autre image du même carrefour (V4, V14),
  // voulu par la navigation serveur (migration 20261105011000).
  const ano = vm.runInContext(`calculerPlanRues(RUE_CENTRALE_NOEUDS.soviet, RUE_CENTRALE_DEPART.soviet.capitale).anomalies.filter(a => a.type === 'sans_retour')`, ctx);
  assert.equal(ano.length, 0);
  // Une vraie rue sans retour reste signalée.
  const vraie = vm.runInContext(`calculerPlanRues({ a: { liens: { toutDroit: 'b' } }, b: { liens: {} } }, 'a').anomalies.filter(a => a.type === 'sans_retour').length`, ctx);
  assert.equal(vraie, 1);
});

test('Fenêtre « Plan de la ville » : le joueur dans un bâtiment le voit surligné, lecture seule', () => {
  const { ctx, elements } = charger({ country: 'republic', currentCity: 'ville_a', currentBuilding: 'mairie' });
  const ok = vm.runInContext(`ouvrirPlanRuesVille('republic', 'ville_a')`, ctx);
  assert.equal(ok, true);
  const corps = elements['minimap-ville-body'].innerHTML;
  assert.match(corps, /vous êtes ici/);
  assert.doesNotMatch(corps, /onclick|enterBuilding/, 'le plan ne déplace pas le joueur');
  assert.equal(elements['modal-minimap-ville'].classList.open, true);
});

test('Fenêtre « Plan de la ville » : une ville sans rues garde l’ancien plan', () => {
  const { ctx } = charger({ country: 'republic', currentCity: 'capitale' });
  assert.equal(vm.runInContext(`ouvrirPlanRuesVille('republic', 'ville_inexistante')`, ctx), false);
});

test('Plan déduit des rues : un carrefour photographié deux fois est un seul point (Novomirsk V4/V5, V14/V15)', () => {
  const { ctx } = charger();
  const r = vm.runInContext(`(() => { const pl = calculerPlanRues(RUE_CENTRALE_NOEUDS.soviet, RUE_CENTRALE_DEPART.soviet.capitale);
    const d = (a, b) => Math.hypot(pl.noeuds[a].x - pl.noeuds[b].x, pl.noeuds[a].y - pl.noeuds[b].y);
    return { v45: d('novomirsk-vue-4', 'novomirsk-vue-5'), v1415: d('novomirsk-vue-14', 'novomirsk-vue-15'), ano: pl.anomalies.length }; })()`, ctx);
  assert.ok(r.v45 < 1e-6, 'V4 et V5 au même point');
  assert.ok(r.v1415 < 1e-6, 'V14 et V15 au même point');
  assert.equal(r.ano, 0, 'plus d’anomalie « flèches opposées » entre deux images du même carrefour');
});

test('Plan déduit des rues : une impasse s’arrête avant la rue qu’elle couperait (Montrouge, impasse du tribunal)', () => {
  const { ctx } = charger();
  const r = JSON.parse(vm.runInContext(`(() => { const pl = calculerPlanRues(RUE_CENTRALE_NOEUDS.republic, RUE_CENTRALE_DEPART.republic.ville_b);
    const P = n => [pl.noeuds[n].x, pl.noeuds[n].y];
    const coupe = (p1, p2, p3, p4) => { const d = (p2[0]-p1[0])*(p4[1]-p3[1]) - (p2[1]-p1[1])*(p4[0]-p3[0]); if (Math.abs(d) < 1e-9) return false;
      const t = ((p3[0]-p1[0])*(p4[1]-p3[1]) - (p3[1]-p1[1])*(p4[0]-p3[0])) / d, u = ((p3[0]-p1[0])*(p2[1]-p1[1]) - (p3[1]-p1[1])*(p2[0]-p1[0])) / d;
      return t > 0 && t < 1 && u > 0 && u < 1; };
    const a = P('montrouge-vue-13'), b = P('montrouge-tribunal-ssm');
    const croise = pl.rues.filter(x => ![x.de, x.vers].some(n => n === 'montrouge-vue-13' || n === 'montrouge-tribunal-ssm'))
      .filter(x => coupe(a, b, P(x.de), P(x.vers))).map(x => x.de + '-' + x.vers);
    // Nord = y plus petit : le bout de l'impasse reste au nord de l'Hôtel de Ville (mairie, vue 7).
    return JSON.stringify({ croise, auNord: b[1] < P('montrouge-vue-7')[1] }); })()`, ctx));
  assert.deepEqual(r.croise, [], 'l’impasse ne croise aucune rue');
  assert.ok(r.auNord, 'le tribunal est au nord de l’Hôtel de Ville');
});
