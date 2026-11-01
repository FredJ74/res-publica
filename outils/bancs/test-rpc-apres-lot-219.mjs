// Contre-épreuve du contrôle Authority après lot (#219, 01/11/2026).
// 1. L'inventaire réel des RPC du navigateur est appelable après baseline + migrations/.
// 2. Les huit anciens appels refusés et le spread de tournee_creer, réinjectés, sont détectés.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const script = `
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location('s', 'outils/baseline/simuler-rpc-apres-lot.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
appels = m.charger_autorite().rpc_du_navigateur()
reel = m.ecarts_apres_lot(appels)
anciens = {
  'chantier_travailler': {frozenset(['p_acteur','p_pays','p_batiment','p_heures']): ['x']},
  'batiment_caisse_mouvement': {frozenset(['p_pays','p_ville','p_building','p_souscle','p_delta']): ['x']},
  'creer_placement_national': {frozenset(['p_personnage','p_montant','p_int_snapshot','p_ville']): ['x']},
  'militaire_subtiliser': {frozenset(['p_pays','p_joueur']): ['x']},
  'tracts_appliquer_effet_pop': {frozenset(['p_cible','p_delta']): ['x']},
  'tracts_reclamer_don': {frozenset(['p_id','p_destinataire']): ['x']},
  'vendre_fonds_commerce': {frozenset(['p_vendeur','p_acheteur','p_fonds_id','p_prix']): ['x']},
  'vendre_materiaux_chantier': {frozenset(['p_vendeur','p_country','p_building_id','p_matiere','p_quantite','p_prix']): ['x']},
  'tournee_creer': {frozenset(['p_id']): ['x']},
}
injecte = m.ecarts_apres_lot(anciens)
print(json.dumps({'reel': reel, 'injecte': sorted({e['fonction'] for e in injecte})}))
`;

test('les RPC du navigateur sont appelables après le lot, les anciens appels sont refusés', () => {
  const sortie = JSON.parse(execFileSync('python3', ['-c', script], { cwd: racine, encoding: 'utf8', maxBuffer: 64 << 20 }));
  assert.deepEqual(sortie.reel, [], 'écarts réels après lot : ' + JSON.stringify(sortie.reel).slice(0, 600));
  assert.deepEqual(sortie.injecte, [
    'batiment_caisse_mouvement', 'chantier_travailler', 'creer_placement_national', 'militaire_subtiliser',
    'tournee_creer', 'tracts_appliquer_effet_pop', 'tracts_reclamer_don', 'vendre_fonds_commerce',
    'vendre_materiaux_chantier',
  ]);
});

import fs from 'node:fs';
import vm from 'node:vm';

function extraire(source, nom) {
  const debut = source.indexOf('async function ' + nom + '(');
  assert.ok(debut >= 0, nom + ' introuvable');
  let i = source.indexOf('{', debut), n = 0;
  for (; i < source.length; i++) { if (source[i] === '{') n++; else if (source[i] === '}' && --n === 0) break; }
  return source.slice(debut, i + 1);
}

test('travail sur chantier : porte chantier_commande, montant rendu par le serveur', async () => {
  const src = fs.readFileSync(path.join(racine, 'plateau-justice-economie.js'), 'utf8');
  const corps = extraire(src, 'confirmerTravailChantier');
  assert.ok(!/chantier_travailler'/.test(corps), "l'écran ne doit plus appeler chantier_travailler");
  const appels = [], toasts = [];
  const contexte = {
    state: { currentBuilding: 'terrain-1', country: 'republic', char: { name: 'Canari' } },
    document: { getElementById: (id) => id === 'chantier-heures' ? { value: '3' } : { classList: { remove() {} } } },
    COUNTRIES: { republic: { cur: 'FR' } },
    getTerrainState: () => ({ chantier: { tresorerie: 100 } }),
    showToast: (...a) => toasts.push(a), addJournalEntry() {}, updateUI() {},
    constructionExecuterCommande: async (action, p) => { appels.push([action, p]); return appels.length === 1 ? { ok: true, montant: 42 } : null; },
  };
  vm.createContext(contexte);
  vm.runInContext(corps + '\nthis.f = confirmerTravailChantier;', contexte);
  await contexte.f();
  assert.equal(JSON.stringify(appels), JSON.stringify([['travailler', { heures: 3 }]]));
  assert.match(String(toasts.at(-1)[1]), /^\+42 FR/);
  // Refus ou réponse perdue : constructionExecuterCommande a déjà nommé le problème, aucun succès affiché.
  const avant = toasts.length; await contexte.f();
  assert.equal(toasts.length, avant);
});
