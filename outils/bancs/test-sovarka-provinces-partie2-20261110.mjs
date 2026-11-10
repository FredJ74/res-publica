// Lot des provinces de Sovarka, partie 2 (10/11/2026, GAME-DESIGN-NOVOMIRSK.md, « Fermes : production » et forêt de Krasnov).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
function charger(ville) {
  const ctx = vm.createContext({console, state: {country: 'soviet', currentCity: ville}});
  vm.runInContext(lire('data.js'), ctx);
  vm.runInContext(lire('plateau-rue-centrale.js'), ctx);
  return ctx;
}

test('Fermes : ordres et PA décidés par Fred, façades sur les enseignes', () => {
  const ctx = charger('ville_a');
  const r = vm.runInContext(`(() => {
    const z = (n, b) => (RUE_CENTRALE_NOEUDS.soviet[n].zones || []).some(x => x.buildingId === b);
    const o = id => BUILDINGS[id].rooms.cour_ferme.orders.map(x => x.fn + ':' + x.pa).join();
    return { starovka: o('ferme-starovka'), krasnov: o('ferme-krasnov'),
      facades: z('starovka-rue-petrole-ferme', 'ferme-starovka') && z('krasnov-rue-marche-ferme', 'ferme-krasnov')
        && z('krasnov-rue-distillerie-radar', 'distillerie-krasnov') && z('starovka-rue-restaurant-boutique', 'fourreur-starovka'),
      listes: ['ferme-starovka', 'fourreur-starovka'].every(b => WORLD.soviet.ville_a.buildings.includes(b))
        && ['ferme-krasnov', 'distillerie-krasnov'].every(b => WORLD.soviet.ville_b.buildings.includes(b)),
      textile: RESSOURCES_ECONOMIE.textile.label };
  })()`, ctx);
  assert.equal(r.starovka, 'ferme_renne:5,ferme_traire:1');
  assert.equal(r.krasnov, 'ferme_legumes:1,ferme_oeufs:1,ferme_poulet:2,ferme_lapin:2');
  assert.ok(r.facades, 'façade manquante');
  assert.ok(r.listes, 'bâtiment absent de sa ville');
  assert.equal(r.textile, 'Tissus et peaux');
});

test('Distillerie et fourreur : locaux demandés à la mairie, puis commerce', () => {
  const ctx = charger('ville_b');
  const fns = vm.runInContext(`[BUILDINGS['distillerie-krasnov'].rooms.atelier_distillerie, BUILDINGS['fourreur-starovka'].rooms.boutique_fourreur]
    .map(p => p.orders.map(o => o.fn).join()).join('|')`, ctx);
  assert.equal(fns, 'sovarka_demande_location,commerce_pj|sovarka_demande_location,commerce_pj');
});

test('Forêt de Krasnov : entrée, 4 vues masquées, coupe 2 PA, retour', () => {
  const ctx = charger('ville_b');
  const r = vm.runInContext(`(() => {
    const c = WORLD.soviet.ville_b.buildingContext['zone-production'];
    return { entree: ordresDeclaresDeLaPiece(BUILDINGS['zone-production'].rooms.zone_recolte, c, 'zone_recolte').map(o => o.fn).join(),
      vues: Object.keys(c.roomsExtra).filter(k => k.startsWith('foret_vue_')).sort().join(),
      masquees: c.roomsMasquees.filter(k => k.startsWith('foret_vue_')).length,
      ordres: c.roomsExtra.foret_vue_3.orders.map(o => o.fn + ':' + o.pa).join(),
      ailleurs: !(WORLD.soviet.ville_a.buildingContext['zone-production']?.roomsExtra?.foret_vue_1) };
  })()`, ctx);
  assert.equal(r.entree, 'recolter_matiere,foret_enfoncer');
  assert.equal(r.vues, 'foret_vue_1,foret_vue_2,foret_vue_3,foret_vue_4');
  assert.equal(r.masquees, 4);
  assert.equal(r.ordres, 'foret_couper:2,foret_revenir:0');
  assert.ok(r.ailleurs, 'la forêt profonde ne doit exister qu’à Krasnov');
});

test('Écran : routeur, œufs, texte de l’hôpital', () => {
  const routeur = lire('plateau-router.js');
  for (const s of ["foretAller('enfoncer')", "foretAller('revenir')", 'foretCouper()', 'travaillerFerme(fn)']) assert.ok(routeur.includes(s), s);
  const prov = lire('plateau-sovarka-provinces.js');
  for (const rpc of ['sovarka_ferme_travailler', 'sovarka_oeufs_manger', 'sovarka_foret_aller', 'sovarka_foret_couper', 'sovarka_foret_rencontre', 'sovarka_foret_lire'])
    assert.ok(prov.includes("'" + rpc + "'"), rpc);
  assert.ok(lire('plateau-personnage.js').includes("item.stackKey === 'oeufs'"));
  for (const f of ['plateau-navigation.js', 'plateau-personnage.js']) {
    assert.ok(!lire(f).includes('Sortie possible à partir du jour 2, avec 20 PA.'), f + ' : ancien texte');
    assert.ok(lire(f).includes('dès que vous avez 20 PA'), f);
  }
});
