// Production et logistique de Sovarka (Fred, 15/11/2026 au soir ; GAME-DESIGN-NOVOMIRSK.md,
// « Production et logistique de Sovarka »). Gardes statiques : écran, tâche de minuit et migrations.
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
  return ctx;
}
test('Raffinerie d’État du Grand Nord : nom, directeur, vente, production', () => {
  const ctx = charger('ville_a');
  const c = JSON.parse(vm.runInContext(`JSON.stringify(WORLD.soviet.ville_a.buildingContext['usine-principale'])`, ctx));
  assert.equal(c.name, 'Raffinerie d’État du Grand Nord');
  assert.equal(c.shortName, 'Raffinerie');
  const dir = c.roomOverrides.direction_usine;
  assert.deepEqual(dir.persons.map(p => p.name), ['Damdin Mazoutov (PNJ)']);
  assert.ok(dir.excludeOrders.includes('acheter_entreprise'));
  assert.deepEqual(dir.orders.map(o => o.fn), ['fixer_prix_vente_directe', 'fixer_repartition_production', 'virement_usine_ministere']);
  assert.ok(dir.orders.every(o => o.requiresPost === 'directeur_raffinerie'));
  assert.deepEqual(c.roomsExtra.salle_ventes_raffinerie.orders.map(o => o.fn), ['vente_directe_usine', 'vendre_matiere_usine']);
  assert.deepEqual(c.roomsExtra.interieur_raffinerie.orders.map(o => o.fn), ['produire_carburant', 'produire_derives_petrochimiques', 'vendre_matiere_usine']);
  assert.ok(c.roomsExtra.interieur_raffinerie.orders.every(o => !/FR\b/.test(o.desc)), 'montant en FR dans une usine de Sovarka');
  // Montrouge inchangée
  const mont = vm.runInContext(`BUILDINGS['raffinerie-montrouge'].rooms.bureau_direction.persons[0].name`, ctx);
  assert.equal(mont, 'Gustave Baril (PNJ)');
});

test('Distillerie de Krasnov : usine d’État à côté du commerce du PJ', () => {
  const ctx = charger('ville_b');
  const r = JSON.parse(vm.runInContext(`JSON.stringify(BUILDINGS['distillerie-krasnov'].rooms)`, ctx));
  const ventes = r.salle_ventes.orders.map(o => o.fn);
  // Distillerie d'État jamais à louer (Fred, 20/11/2026) : plus de commerce de PJ dans la salle des ventes.
  assert.ok(!ventes.includes('commerce_pj') && !ventes.includes('sovarka_demande_location') && ventes.includes('vente_directe_usine'));
  assert.deepEqual(r.atelier_distillerie.orders.map(o => o.fn), ['produire_alcool', 'produire_spiritueux', 'produire_sucre', 'vendre_matiere_usine']);
  assert.match(r.atelier_distillerie.orders[0].desc, /5 fruits et légumes/);
  assert.equal(r.bureau_direction.persons[0].job, 'directeur_tabac_alcools');
  assert.ok(r.bureau_direction.orders.every(o => o.requiresPost === 'directeur_tabac_alcools'));
});

test('Écran : chaînes et directeurs par pays, gabarit de Républia intact', () => {
  const src = lire('plateau-justice-economie.js');
  assert.match(src, /const CHAINES_PRODUCTION_PAYS = \{\s+soviet: \{/);
  assert.match(src, /alcool:\s+\{ buildingId: 'distillerie-krasnov',\s+city: 'ville_b',\s+matiere: 'fruits_legumes'/);
  assert.match(src, /carburant:\s+\{ buildingId: 'usine-principale',\s+city: 'ville_a'/);
  assert.match(src, /carburant:    \{ buildingId: 'raffinerie-montrouge',\s+city: 'ville_b'/, 'gabarit de Républia modifié');
  assert.ok(!/DIRECTEUR_USINE_INFO\[(state\.poste\?\.id|posteId)\]/.test(src.replace(/return t \? t\[posteId\] : DIRECTEUR_USINE_INFO\[posteId\];/, '')),
    'un accès direct au directeur sans pays subsiste');
  for (const f of ['doProduireUsine', 'produitsUsine', 'matieresAccepteesParUsine']) {
    const corps = src.slice(src.indexOf('function ' + f), src.indexOf('function ' + f) + 300);
    assert.match(corps, /chainesUsinePays\(/, f + ' ignore le pays');
  }
});

test('Tâche de minuit : production, commerce international (ports), échanges, dans cet ordre', () => {
  // 16/11/2026 : importations et exportations passent par commerce_international_passe (contrats en base).
  const src = lire('api/cron-minuit.js');
  const ordre = ['production_sovarka', 'commerce_international', 'entrepots_sovarka']
    .map(n => src.indexOf(`tacheQuotidienne('${n}'`));
  assert.ok(ordre.every(i => i > 0), 'tâche absente');
  assert.deepEqual([...ordre].sort((a, b) => a - b), ordre, 'ordre des tâches');
  const m = lire('migrations/20261116113000_ports_commerce_international.sql');
  assert.match(m, /\('republic', 'soviet', 'medicaments', 25,/);
  assert.match(m, /\('republic', 'soviet', 'plantes', 38,/);
  assert.match(m, /\('narco', 'soviet', 'plantes', 37,/);
  assert.match(m, /\('narco', 'soviet', 'tabac', 50,/);
  assert.match(src, /USINE AFFAMEE/);
});

test('Migrations : patchs gardés, Républia sans ligne par pays, passe revendiquée', () => {
  const m1 = lire('migrations/20261115213000_sovarka_usines_par_pays.sql');
  const m2 = lire('migrations/20261115214000_sovarka_production_passe.sql');
  const m3 = lire('migrations/20261115215000_sovarka_port_exterieur_contrats_medicaments.sql');
  assert.ok(!/\('republic',/.test(m1), 'aucune ligne par pays pour la Républia');
  for (const g of ['produire_en_usine', 'vendre_matiere_a_usine', 'fixer_prix_vente_directe', 'fixer_repartition_production', 'usine_virer_vers_ministere', 'ministere_virer_vers_usine'])
    assert.match(m1, new RegExp(`patch ${g} non applique`));
  assert.match(m1, /'pas_sur_place'/);
  assert.match(m2, /sovarka_production_passes WHERE jour = p_jour/);
  assert.match(m2, /pg_advisory_xact_lock\(hashtext\('sovarka_production_passe'\)\)/);
  assert.match(m2, /c_volume   constant integer := 25;/);
  assert.match(m2, /c_capacite constant integer := 5000;/);
  assert.match(m2, /REVOKE ALL ON FUNCTION public\.sovarka_production_passe\(date, text\[\]\) FROM PUBLIC, anon, authenticated;/);
  assert.match(m3, /port_exterieur_seulement/);
  assert.match(m3, /prix_base \* 2 INTO v_prix/);
  assert.match(m3, /dotation_medicaments_20261115/);
  assert.match(m3, /GRANT EXECUTE ON FUNCTION public\.importation_sovarka_recevoir\(text, date, text, integer\) TO service_role;/);
});
