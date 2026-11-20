// Banc : lot de Krasnov, point 6 — supporters en Sovarka (Fred, 20/11/2026). Migration 20261120360000.
const test = require('node:test'); const assert = require('node:assert'); const fs = require('fs'); const path = require('path'); const vm = require('vm');
const racine = path.join(__dirname, '..', '..'); const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120360000_supporters_sovarka_manifestation.sql');

test('Serveur : manifestation « en faveur » seulement, cible président du club ou maire, mécanisme du syndicat', () => {
  assert.match(sql, /IF p_cible NOT IN \('president_club', 'maire'\) THEN RETURN jsonb_build_object\('ok', false, 'raison', 'cible_invalide'\)/);
  assert.match(sql, /current_building = 'stade' AND current_room = 'siege_supporters'/);
  assert.match(sql, /< 10 THEN\s+RETURN jsonb_build_object\('ok', false, 'raison', 'club_trop_petit'/);
  assert.match(sql, /SET pa = pa - 2, updated_at = now\(\)\s+WHERE x\.name = ANY \(v_noms\) AND x\.country = 'soviet' AND x\.current_city = v_ville AND coalesce\(x\.pa, 0\) > 3/);
  assert.match(sql, /v_effet := public\.syndicat_etat_effet_pop\(v_taux\);/);   // perte de POP sous 50 % comprise
  assert.match(sql, /FROM public\.presidents_clubs WHERE id = v_club\.id/);
  assert.match(sql, /FROM public\.cycles_electoraux WHERE id = 'soviet_maire_' \|\| v_ville/);
  assert.match(sql, /deja_manifeste_aujourdhui/);
  assert.match(sql, /achat_requete_ouvrir_interne\(a, p_requete, 'supporters_sovarka_manifester', prm\)/);
});

test('Écran : plus de boycott en Sovarka, la manifestation ouvre le choix de la cible', () => {
  const ctx = { console }; ctx.globalThis = ctx; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W=WORLD;globalThis.__B=BUILDINGS;globalThis.__o=ordresDeclaresDeLaPiece;', ctx);
  const salle = ctx.__B.stade.rooms.siege_supporters;
  for (const v of ['capitale', 'ville_a', 'ville_b']) {
    const fns = ctx.__o(salle, ctx.__W.soviet[v].buildingContext.stade, 'siege_supporters').map(o => o.fn);
    assert.ok(!fns.includes('organiser_boycott'), v);
    // Novomirsk garde sa décision antérieure : aucune manifestation au club du Dynamo.
    assert.strictEqual(fns.includes('organiser_manifestation'), v !== 'capitale', v);
  }
  assert.ok(ctx.__o(salle, ctx.__W.republic.capitale.buildingContext?.stade, 'siege_supporters').some(o => o.fn === 'organiser_boycott'));   // Républia inchangée
  const q = lire('plateau-organisations-quetes.js');
  assert.match(q, /if \(state\.country === 'soviet'\) \{ ouvrirManifestationSupportersSovarka\(\); return; \}/);
  assert.match(q, /sbRpcVerdict\('supporters_sovarka_manifester', \{ p_requete: requete, p_cible: cible \}\)/);
  assert.match(q, /En Sovarka, les supporters ne boycottent pas/);
});
