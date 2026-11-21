// Banc : lot de Krasnov, point 7 — école et énigme de Krasnov (Fred, 20/11/2026). Migration 20261121060000.
const test = require('node:test'); const assert = require('node:assert'); const fs = require('fs'); const path = require('path'); const vm = require('vm');
const racine = path.join(__dirname, '..', '..'); const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261121060000_krasnov_ecole_enigme.sql');

test('École : stage de survie (3 PA, 25 PSK à la mairie, +4 VOL 24 h), ordres de l’université retirés', () => {
  assert.match(sql, /payer_ordre\(p_acteur, 'stage_survie_foret', 3, 25\)/);
  assert.match(sql, /salaire_caisse_de\('maire', 'soviet', 'ville_b'\)/);
  assert.match(sql, /'deltas', jsonb_build_object\('VOL', 4\)/);
  const ctx = { console }; ctx.globalThis = ctx; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W=WORLD;globalThis.__B=BUILDINGS;globalThis.__o=ordresDeclaresDeLaPiece;', ctx);
  const k = ctx.__W.soviet.ville_b.buildingContext;
  assert.strictEqual(JSON.stringify(ctx.__o(ctx.__B.universite.rooms.amphi, k.universite, 'amphi').map(o => o.fn)), JSON.stringify(['stage_survie_foret']));
  assert.ok(!ctx.__o(ctx.__B.universite.rooms.salle_reunion, k.universite, 'salle_reunion').some(o => o.fn === 'recruter_etud'));
  const hall = k['musee-novomirsk'].roomOverrides.hall;
  assert.strictEqual(JSON.stringify(hall.orders.map(o => o.fn)), JSON.stringify(['acheter_guide_baies_musee', 'repondre_enigme_krasnov']));
  assert.ok(hall.persons.some(p => p.profilId === 'directeur_musee_krasnov'));
});

test('Guide : une lecture par semaine, vendu au musée avec sa feuille, plus au marché', () => {
  assert.match(sql, /lu_le > now\(\) - interval '7 days'\) THEN \/\* guide_hebdo_v1 \*\//);
  assert.match(sql, /payer_ordre\(p_acteur, 'acheter_guide_baies_musee', 0, 10\)/);
  assert.match(sql, /krasnov_feuille_objet_interne\(\)/);
  assert.match(sql, /UPDATE public\.commerces_dotations SET carte = carte - 'guide_baies_krasnov'/);
  assert.match(lire('plateau-sovarka-provinces.js'), /v\.raison === 'deja_lu_cette_semaine'/);
});

test('Énigme : feuille requise, réponse « graisse d’ours », résolution attachée au personnage, distinction et liste', () => {
  assert.match(sql, /IF v_norm !~ 'graisse' OR v_norm !~ '\\mours\\M' THEN/);
  assert.match(sql, /RETURN jsonb_build_object\('ok', false, 'raison', 'pas_de_feuille'\)/);
  assert.match(sql, /INSERT INTO public\.enigmes_resolues \(personnage, enigme, distinction\)/);
  assert.match(sql, /WHEN p_objet->>'type' = 'feuille_enigme_krasnov'\s+THEN EXISTS \(SELECT 1 FROM public\.enigmes_resolues/);
  const m = lire('plateau-enigme-krasnov.js');
  assert.match(m, /Ici commence l’énigme de ' \+ ville \+ ' : saurez-vous la résoudre… \?/);
  assert.match(m, /Alors notre organisation n’a plus lieu d’exister/);
  assert.match(m, /bloc\.id = 'inv-enigmes'/);
  assert.match(m, /À Krasnov, on a les plus belles femmes du pays !/);
});

test('Chaîne de dialogues : institutrice, apicultrice, batiouchka, marchande, directeur', () => {
  const p = lire('api/_pnj-personnalites.js');
  assert.match(p, /il ne reste plus qu'une chose à espérer : que l'on puisse continuer à manger du miel/);
  assert.match(p, /il est revenu des bois le visage lacéré, avec dix bocaux/);
  assert.match(p, /se serait évité bien de la peine en allant simplement au marché/);
  assert.match(p, /'directeur_musee_krasnov':/);
  assert.match(lire('api/_pnj-profils.js'), /un ours tue en donne dix pots/);
});
