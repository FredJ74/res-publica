// Banc : lot de Krasnov, point 8 — radar de Krasnov (Fred, 20/11/2026). Migrations 20261121010000 et 20261121020000.
const test = require('node:test'); const assert = require('node:assert'); const fs = require('fs'); const path = require('path'); const vm = require('vm');
const racine = path.join(__dirname, '..', '..'); const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261121020000_krasnov_radar_polonium_secrets.sql');

test('Secret du colonel : attaché au personnage, acquis définitivement, carnet privé', () => {
  assert.match(sql, /CREATE TABLE IF NOT EXISTS public\.personnages_secrets \(\s+personnage text NOT NULL, cle text NOT NULL/);
  assert.match(sql, /REVOKE ALL ON public\.personnages_secrets FROM anon, authenticated;/);
  assert.match(sql, /FROM public\.personnages_secrets s WHERE s\.personnage = public\.mon_personnage\(\)/);
  assert.match(sql, /Phrase de passe : « Demander au colonel des nouvelles de notre ami de Luthécia »/);
});

test('Sources : habitué selon le palier d’informateur, Kalachnikov toujours', () => {
  assert.match(sql, /v_chance := CASE WHEN v_niveau >= 3 THEN 100 WHEN v_niveau = 2 THEN 50 WHEN v_niveau = 1 THEN 25 ELSE 10 END;/);
  assert.match(sql, /IF p_source = 'kalachnikov' THEN v_appris := true;/);
  assert.match(sql, /\('soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge'\)/);
});

test('Colonel : 2 PA, 50 %, 150 PSK seulement en cas de succès, dénonciation sur 98-100', () => {
  assert.match(sql, /IF NOT EXISTS \(SELECT 1 FROM public\.personnages_secrets WHERE personnage = p_acteur AND cle = 'colonel_polonium'\)/);
  assert.match(sql, /payer_ordre\(p_acteur, 'acheter_polonium_colonel', 2, 0\)/);
  assert.match(sql, /IF v_roll > 50 THEN\s+IF v_roll >= 98 THEN/);
  assert.match(sql, /crime_tracer_interne\(p_acteur, 'acheter_polonium', 'station radar de Krasnov'\)/);
  assert.match(sql, /payer_ordre\(p_acteur, 'polonium_colonel_paiement', 0, 150\)/);
  assert.match(sql, /WHERE m\.id = 'poison:polonium'/);
});

test('Écran : ordre du colonel caché sans le secret, sources raccordées, carnet dans l’inventaire', () => {
  const ctx = { console }; ctx.globalThis = ctx; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W=WORLD;globalThis.__B=BUILDINGS;', ctx);
  const colonel = ctx.__B['station-radar-krasnov'].rooms.salle_ecoute.orders.find(o => o.fn === 'acheter_polonium_colonel');
  assert.ok(colonel && colonel.secret === 'colonel_polonium' && colonel.pa === 2);
  assert.ok(ctx.__W.soviet.ville_b.buildingContext['cafe-tabac-cheminots-montrouge'].orders.some(o => o.fn === 'offrir_verre_habitue_krasnov' && o.pa === 1 && o.cost === 5));
  assert.ok(ctx.__W.soviet.capitale.buildingContext.armurerie.orders.some(o => o.fn === 'demander_fournisseur_kalachnikov'));
  assert.ok(ctx.__B['port-starovka'].rooms.quai_principal.orders.some(o => o.fn === 'interroger_ganbaatar_polonium'));
  assert.match(lire('plateau-politique.js'), /\.filter\(o => !o\.secret \|\| \(typeof rpSecretConnu === 'function' && rpSecretConnu\(o\.secret\)\)\)/);
  const s = lire('plateau-secrets.js');
  assert.match(s, /Je ne suis pas une balance/);
  assert.match(s, /« Je ne connais personne à Luthécia, camarade\. »/);
  assert.match(s, /bloc\.id = 'inv-secrets'/);
  assert.match(lire('plateau.html'), /<script src="plateau-secrets\.js\?v=/);
  const r = lire('plateau-router.js');
  for (const fn of ['offrir_verre_habitue_krasnov', 'demander_fournisseur_kalachnikov', 'interroger_ganbaatar_polonium', 'acheter_polonium_colonel'])
    assert.ok(r.includes("fn === '" + fn + "'"), fn);
});
