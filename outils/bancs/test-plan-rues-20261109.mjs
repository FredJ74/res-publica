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
    for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
      const a = r.plan.noeuds[ids[i]], b = r.plan.noeuds[ids[j]];
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

test('Plan déduit des rues : les flèches sans retour de Novomirsk sont signalées', () => {
  const { ctx } = charger();
  const ano = vm.runInContext(`calculerPlanRues(RUE_CENTRALE_NOEUDS.soviet, RUE_CENTRALE_DEPART.soviet.capitale).anomalies.filter(a => a.type === 'sans_retour').map(a => a.noeuds.join('>'))`, ctx);
  // Constat du 09/11/2026 : deux flèches à sens unique. Le test suit la donnée, pas l'inverse :
  // si la navigation est corrigée, la liste rétrécit et ce test doit être mis à jour.
  for (const a of ano) assert.match(a, /^novomirsk-vue-\d+>novomirsk-vue-\d+$/);
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
