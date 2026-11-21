'use strict';
// Climat — décisions de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md) : crue sans entrave aux déplacements, gare
// jamais inondée, 12 heures pour crue/orage/canicule/brouillard, aucune exemption, accueil du nouveau personnage.
// Le comportement réel a aussi été essayé en production dans une transaction annulée (gare, durées, accueil unique).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const sql = lire('migrations/20261121070000_climat_douze_heures_gare_accueil.sql');
const client = lire('plateau-climat.js');

test('déplacements : la crue ne bloque que l’entrée dans les lieux tirés, jamais la rue ni le train', () => {
  // Seul effet de navigation de la crue (lot 5) : refus d'ENTRER (mode « piece ») dans un bâtiment inondé.
  const effets = lire('migrations/20261119100000_climat_effets.sql');
  assert.match(effets, /IF p_mode='piece' AND public\.climat_batiment_inonde_interne\(/);
  assert.equal((effets.match(/public\.climat_batiment_inonde_interne\(\(/g) || []).length, 1, 'aucun autre raccord de navigation');
  assert.ok(!/rue_position|navigation_rue_trajet|voyage|train/.test(sql.replace(/^--.*$/gm, '')), 'la migration ne touche ni rue ni train');
});

test('gare jamais tirée : exclue du tirage et interdite dans les zones inondables', () => {
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.climat_lieu_est_gare_interne\(p_batiment text\)/);
  assert.match(sql, /ADD CONSTRAINT climat_zones_jamais_gare CHECK \(NOT public\.climat_lieu_est_gare_interne\(batiment\)\)/);
  assert.match(sql, /AND NOT public\.climat_lieu_est_gare_interne\(batiment\) \/\* climat_gare_jamais_v1 \*\//);
  // Même expression que la fonction SQL, rejouée ici sur les identifiants réels des gares.
  const estGare = b => /(multimodal|multinodal)/.test(b) || /^hall_gare/.test(b) || (/(^|-)gare(-|$)/.test(b) && !/^cafe-/.test(b));
  for (const g of ['psm-centre-multimodal', 'centre-multinodal-montrouge', 'gare-centrale-novomirsk', 'hall_gare_psm']) assert.ok(estGare(g), g);
  for (const b of ['cafe-gare-montrouge', 'marche-psm', 'port-sainte-marie', 'entrepot-logistique-luthecia', 'zone-production']) assert.ok(!estGare(b), b);
  // Aucune zone inondable déclarée n'est une gare.
  const zones = [...lire('migrations/20261118080000_climat_socle.sql').matchAll(/\('republic', '\w+', +'([a-z0-9-]+)'/g)].map(m => m[1]);
  assert.ok(zones.length >= 11);
  for (const z of zones) assert.ok(!estGare(z), z);
});

test('durées : 12 heures pour crue, orage, canicule, brouillard ; blizzard inchangé', () => {
  assert.match(sql, /UPDATE public\.climat_parametres SET duree_heures = 12 WHERE type IN \('crue', 'orage', 'canicule', 'brouillard'\);/);
  assert.match(sql, /UPDATE public\.climat_evenements SET fin = debut \+ interval '12 hours'\n WHERE type IN \('crue', 'orage', 'canicule', 'brouillard'\) AND fin_traitee_le IS NULL/);
  assert.ok(!/blizzard'\)/.test(sql.split('UPDATE public.climat_parametres')[1].split(';')[0]), 'le blizzard reste à 24 h');
  assert.match(sql, /pendant 12 heures\.' \/\* climat_douze_heures_v1 \*\//);
  // Tous les effets lisent la fenêtre debut/fin de l'événement : rien d'autre à raccourcir.
  const effets = lire('migrations/20261119100000_climat_effets.sql');
  for (const f of ['climat_coupure_interne', 'climat_batiment_inonde_interne', 'climat_brouillard_modificateurs_interne'])
    assert.match(effets.split('FUNCTION public.' + f)[1].split('$$;')[0], /now\(\) >= e\.debut AND now\(\) < e\.fin/, f);
  assert.match(lire('migrations/20261118080000_climat_socle.sql'), /now\(\) >= e\.debut AND now\(\) < e\.fin AND c\.bloque_chantiers/);
  assert.match(effets, /fin_traitee_le IS NULL AND now\(\) >= fin/);
  // Textes français des alertes ; les huit autres langues sont confiées à Codex (RELAIS).
  assert.match(client, /seront sous les eaux pendant 12 heures\. Mettez vos biens à l’abri\./);
  assert.match(client, /coupures d’électricité et d’internet attendues pendant 12 heures\./);
});

test('aucune exemption : les effets ne regardent jamais l’âge du personnage', () => {
  const effets = ['migrations/20261119100000_climat_effets.sql', 'migrations/20261119090000_climat_blizzard_grippe.sql',
    'migrations/20261118080000_climat_socle.sql'].map(lire).join('\n');
  assert.ok(!/created_at\s*[<>]/.test(effets), 'aucune condition sur la date de création dans les effets');
  // L'âge ne sert qu'à décider de la fenêtre d'accueil.
  assert.match(sql, /p\.created_at < localtimestamp - interval '24 hours'/);
  assert.equal((sql.match(/created_at/g) || []).length, 2);
});

test('accueil : une seule fois par événement, tenu par le serveur', () => {
  assert.match(sql, /PRIMARY KEY \(personnage, evenement\)/);
  assert.match(sql, /AND NOT EXISTS \(SELECT 1 FROM public\.climat_accueils a WHERE a\.personnage = p_nom AND a\.evenement = ev\.id\)/);
  assert.match(sql, /ON CONFLICT DO NOTHING/);
  assert.match(sql, /GRANT EXECUTE ON FUNCTION public\.climat_accueil_lire\(\), public\.climat_accueil_vu\(bigint\) TO authenticated;/);
  assert.match(client, /global\.sbRpc\('climat_accueil_vu', \{ p_evenement: ev\.id \}\)/);
});

test('client : en cours entre debut et fin, durée restante lisible', () => {
  const ctx = { console, Date, setTimeout, setInterval: () => 0, clearInterval() {}, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(client, ctx);
  const { enCours, dureeRestante } = ctx.RPClimat;
  const t = Date.parse('2026-11-21T10:00:00Z');
  const ev = { debut: '2026-11-21T09:00:00Z', fin: '2026-11-21T15:20:00Z' };
  assert.equal(enCours(ev, t), true);
  assert.equal(enCours(ev, Date.parse('2026-11-21T15:20:00Z')), false, 'fin exclue');
  assert.equal(enCours(ev, Date.parse('2026-11-21T08:59:59Z')), false);
  assert.equal(dureeRestante(ev, t), '5 h 20 min');
  assert.equal(dureeRestante(ev, Date.parse('2026-11-21T15:00:00Z')), '20 min');
});
