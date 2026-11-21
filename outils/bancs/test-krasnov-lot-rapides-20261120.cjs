// Banc : lot de Krasnov (1re partie), points rapides (Fred, 20/11/2026). GAME-DESIGN-KRASNOV-LOT-20261120.md.
const test = require('node:test'); const assert = require('node:assert'); const fs = require('fs'); const path = require('path'); const vm = require('vm');
const racine = path.join(__dirname, '..', '..'); const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120350000_krasnov_ours_graisse_ecoute.sql');

test('1. Ours tué : 10 pots de graisse d’ours en plus (le bocal existant), jamais en cas de fuite', () => {
  assert.match(sql, /SELECT public\.graisse_objet_interne\('graisse_ours', 10\) WHERE e\.creature = 'ours' AND p_issue <> 'fuite' LOOP/);
  assert.match(sql, /krasnov_graisse_ours_v1/);
});

test('4. Kolkhoze : quantités saisies puis un seul « Donner », tout ou rien, rejeu sans double don', () => {
  assert.match(sql, /FUNCTION public\.kolkhoze_caisse_donner_lot\(p_requete uuid, p_lot jsonb\)/);
  assert.match(sql, /achat_requete_ouvrir_interne\(a, p_requete, 'kolkhoze_caisse_donner_lot', prm\)/);
  assert.match(sql, /v := public\.kolkhoze_caisse_donner_interne\(a, k, q\);/);
  assert.match(sql, /EXCEPTION WHEN SQLSTATE 'HG001'/);
  const p = lire('plateau-sovarka-provinces.js');
  assert.match(p, /data-kol-don="/);
  assert.match(p, /provActe\('kolkhoze_caisse_donner_lot', \{ p_lot: lot \}/);
  assert.doesNotMatch(p, /provJs\('agirCaisseKolkhoze', 'donner:'/);
  assert.match(p, /provJs\('agirCaisseKolkhoze', 'prendre:'/);   // la prise reste par matière
});

test('5. Commissariat : brigadier Matveï Doubov à Krasnov seulement', () => {
  const ctx = { console }; ctx.globalThis = ctx; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W=WORLD;globalThis.__B=BUILDINGS;', ctx);
  const krasnov = ctx.__W.soviet.ville_b.buildingContext['commissariat-local'].roomOverrides.accueil_loc.persons;
  assert.ok(krasnov.some(p => p.name === 'Brigadier Matveï Doubov (PNJ)' && p.role === 'Brigadier de garde' && /Krasnov_portrait_commissariat-local/.test(p.photoUrl)));
  assert.ok(!krasnov.some(p => p.name === 'Brigadier Local (PNJ)'));
  assert.strictEqual(ctx.__B['commissariat-local'].rooms.accueil_loc.persons[0].name, 'Brigadier Local (PNJ)');   // gabarit inchangé
  // Accents des ordres du commissariat : confiés à Codex (le catalogue des infobulles est indexé sur le texte français exact).
});

test('8. Vol des archives d’écoute : PA et détention au journal', () => {
  const p = lire('plateau-sovarka-provinces.js');
  assert.match(p, /const PA_VOL_ARCHIVES_ECOUTE = 2;/);
  assert.match(p, /bagarre avec l’opérateur Sorokine \(−' \+ PA_VOL_ARCHIVES_ECOUTE \+ ' PA\)/);
  assert.match(lire('data.js'), /fn: 'voler_archives_ecoute', label: 'Voler un rapport dans les archives', pa: 2,/);
});

test('8. Vol des archives : moteur commun du vol et vrai combat contre l’opérateur Sorokine', () => {
  const m = lire('migrations/20261121030000_krasnov_radar_sorokine_habitue.sql');
  assert.match(m, /'sovarka-radar-krasnov-sorokine', 'employe', 'Caporal Ilia Sorokine'/);
  assert.match(m, /10, 8, 8, 10, 12, 12, 'station_radar', 'soviet:ville_b:station-radar-krasnov'/);
  assert.match(m, /t := public\.crim_temoin_interne\(a, NULL\);/);
  assert.match(m, /rr := public\.crim_resoudre_interne\('voler_archives_ecoute', a,/);
  assert.match(m, /'combat', true, 'per_victime'/);
  assert.match(m, /IF rr ->> 'issue' = 'combat' THEN rr := public\.crim_combat_ouvrir_interne\(a, rr, t, 'mains', v_req\); END IF;/);
  assert.doesNotMatch(m, /random\(\) < 0\.5/);
  const p = lire('plateau-sovarka-provinces.js');
  assert.match(p, /v\.issue === 'combat' && Number\.isSafeInteger\(Number\(v\.bataille\)\) && typeof ouvrirPanneauCombat === 'function'/);
});
