'use strict';
// Mission « Purge » du 24/11/2026, bloc D (climat), éprouvé dans un vrai PostgreSQL local (PGlite) sur les définitions de
// production (socles chantier et crue-chantier, complément purge-climat) :
//   D.1 canicule en journée (12 h – 18 h) ; D.2 seules canicule et crue arrêtent les chantiers, blizzard seulement à Starovka ;
//   D.3 l'arrêt s'applique réellement la nuit ; D.4 « Offrir 20 bouteilles d'eau aux ouvriers » ; D.5 pas de canicule à Starovka.
// PGlite : PGLITE_DIR=<dossier contenant node_modules/@electric-sql/pglite> (la CI l'installe dans un dossier temporaire).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const DEBUT = '-- ===== PARTIE F : CRUE =====', FIN = '-- ===== FIN PARTIE F =====';
function sectionCrue() {
  const t = lire('migrations/20261123150000_tabac_presse_crue.sql'), a = t.indexOf(DEBUT), b = t.indexOf(FIN);
  return t.slice(a, b + FIN.length);
}
// Migrations du bloc D, dans l'ordre ; celles qui n'existent pas encore sont ignorées.
const MIGRATIONS = ['20261124131000_canicule_en_journee', '20261124132000_climat_chantiers_canicule_crue_blizzard_starovka',
  '20261124133000_climat_arret_chantier_nuit', '20261124134000_chantier_canicule_eau_ouvriers', '20261124135000_starovka_sans_canicule_ni_fontaine']
  .filter(m => fs.existsSync(path.join(root, 'migrations', m + '.sql')));

function chantier(o = {}) {
  return Object.assign({ type: 'construction', niveau: 'building', coutTotal: 120000, dureeJours: 24, progressionJours: 1, totalVerse: 120000,
    tresorerie: 60000, coutTravail: 84000, coutMateriaux: 36000, heuresTotales: 1200, heuresFaites: 0, maitreOuvrage: 'Arnie',
    stockMateriaux: { bois: 100, minerai: 50, metal: 34 }, travauxPJ: [], evenements: [], jourTraite: '2000-01-01' }, o);
}
async function base({ jusqua = MIGRATIONS.length, avantMigrations = null } = {}) {
  const db = new PGlite();
  for (const f of ['outils/bancs/fixtures/chantier-pglite-socle.sql.txt', 'outils/bancs/fixtures/chantier-commande-entrepot.sql.txt',
    'migrations/20261121140000_chantier_jour_avance.sql', 'migrations/20261122120000_chantier_heures_ouvertes_commande_nuit.sql',
    'outils/bancs/fixtures/crue-chantier-pglite-socle.sql.txt']) await db.exec(lire(f));
  await db.exec(sectionCrue());
  await db.exec(lire('outils/bancs/fixtures/purge-climat-pglite-complement.sql.txt'));
  await db.query("INSERT INTO terrains_etat VALUES ('republic_terrain-a-batir-3', 'republic', $1, now())",
    [JSON.stringify({ proprietaire: 'Arnie', city: 'capitale', chantier: chantier() })]);
  await db.query(`INSERT INTO personnages_donnees (name, pa, arg, liquide, day, current_city, updated_at, country, poste, current_building, current_room, inventory) VALUES
    ('Arnie', 500, 0, 0, 30, 'capitale', now(), 'republic', NULL, 'terrain-a-batir-3', 'terrain', '[]'),
    ('Bob', 30, 0, 0, 30, 'capitale', now(), 'republic', NULL, 'terrain-a-batir-3', 'terrain', '[{"name":"Bouteille d''eau","type":"bouteille_eau","stackKey":"bouteille_eau","qty":25}]')`);
  if (avantMigrations) await avantMigrations(db);
  for (const m of MIGRATIONS.slice(0, jusqua)) await db.exec(lire('migrations/' + m + '.sql'));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
const heureParis = async (db, id) => (await un(db, "SELECT extract(hour FROM debut AT TIME ZONE 'Europe/Paris')::int h, extract(epoch FROM fin - debut)::int / 3600 d FROM climat_evenements WHERE id = $1", [id]));
// Événement de type donné à Luthécia, décalé en jours de Paris, heure de début et durée en heures.
async function evenement(db, type, jours, { heure = 12, heures = 6, ville = 'capitale', pays = 'republic', effets = true } = {}) {
  return (await un(db, `INSERT INTO climat_evenements (type, pays, ville, debut, fin, periode, alerte_le, effets_le)
    SELECT $1, $5, $6, d, d + make_interval(hours => $3::int), 'T', d - interval '2 days', CASE WHEN $7 THEN d END
      FROM (SELECT climat_minuit_interne((now() AT TIME ZONE 'Europe/Paris')::date + $2::int) + make_interval(hours => $4::int) d) x RETURNING id`,
    [type, jours, heures, heure, pays, ville, effets])).id;
}
const nuit = async db => (await un(db, "SELECT chantier_jour_traiter('republic_terrain-a-batir-3') r")).r;
const lireCh = async db => JSON.parse((await un(db, 'SELECT data FROM terrains_etat')).data).chantier;

test('D.1 avant / après : une canicule créée commençait à une heure au hasard ; elle commence désormais à 12 h et finit à 18 h', async () => {
  const avant = await base({ jusqua: 0 });
  const heures = new Set();
  for (let i = 0; i < 12; i++) heures.add((await heureParis(avant, (await un(avant, "SELECT climat_creer_interne('canicule','republic','capitale', (now() AT TIME ZONE 'Europe/Paris')::date + 10, 'T', 'mj') id")).id)).h);
  assert.ok(heures.size > 1, 'avant : heures au hasard');
  const db = await base({ jusqua: 1 });
  for (let i = 0; i < 6; i++) {
    const id = (await un(db, "SELECT climat_creer_interne('canicule','republic','capitale', (now() AT TIME ZONE 'Europe/Paris')::date + 10, 'T', 'mj') id")).id;
    assert.deepEqual(await heureParis(db, id), { h: 12, d: 6 });
  }
  // Les autres événements gardent leur heure au hasard.
  const autres = new Set();
  for (let i = 0; i < 12; i++) autres.add((await heureParis(db, (await un(db, "SELECT climat_creer_interne('orage','republic','capitale', (now() AT TIME ZONE 'Europe/Paris')::date + 10, 'T', 'mj') id")).id)).h);
  assert.ok(autres.size > 1);
});

test('D.1 : les canicules déjà planifiées passent à 12 h (correction publiée si annoncée) ; un report par l’espacement retombe à 12 h', async () => {
  let ids = {};
  const db = await base({ jusqua: 1, avantMigrations: async d => {
    ids.annoncee = await evenement(d, 'canicule', 3, { heure: 21, effets: false });
    ids.future = await evenement(d, 'canicule', 9, { heure: 4, effets: false });
    await d.query('UPDATE climat_evenements SET alerte_le = NULL WHERE id = $1', [ids.future]);
  } });
  assert.deepEqual(await heureParis(db, ids.annoncee), { h: 12, d: 6 });
  assert.deepEqual(await heureParis(db, ids.future), { h: 12, d: 6 });
  const msg = (await db.query("SELECT texte FROM evenements_globaux WHERE texte LIKE '%canicule annoncée%'")).rows;
  assert.equal(msg.length, 1, 'une seule correction : seule la canicule annoncée en avait une');
  assert.match(msg[0].texte, /de 12 h à 18 h/);
  // Rejouable sans nouvelle correction.
  await db.exec(lire('migrations/20261124131000_canicule_en_journee.sql'));
  assert.equal((await db.query("SELECT texte FROM evenements_globaux WHERE texte LIKE '%canicule annoncée%'")).rows.length, 1);
  // Espacement : une crue en cours bloque le pays ; la canicule non annoncée qui tombe dessus est reportée… à 12 h.
  await db.query('DELETE FROM climat_evenements');
  await evenement(db, 'crue', 3, { heure: 10, heures: 6, effets: false });
  await db.query("UPDATE climat_evenements SET debut = now() - interval '1 hour', fin = now() + interval '5 days', alerte_le = now() - interval '3 days'");
  const c = await evenement(db, 'canicule', 4, { heure: 12, effets: false });
  await db.query('UPDATE climat_evenements SET alerte_le = NULL, debut_prevu = debut WHERE id = $1', [c]);
  assert.equal((await un(db, "SELECT climat_espacer_interne('republic') n")).n, 1);
  const h = await heureParis(db, c);
  assert.deepEqual(h, { h: 12, d: 6 });
  assert.ok((await un(db, 'SELECT debut > now() + interval \'7 days\' ok FROM climat_evenements WHERE id = $1', [c])).ok);
});

test('D.2 avant / après : orage et blizzard arrêtaient les chantiers ; seules canicule et crue les arrêtent', async () => {
  const avant = await base({ jusqua: 1 });
  await evenement(avant, 'orage', 0, { heure: 0, heures: 23 });
  await avant.query("UPDATE climat_evenements SET debut = now() - interval '1 hour', fin = now() + interval '3 hours'");
  assert.equal((await un(avant, "SELECT climat_chantiers_bloques_interne('republic','capitale') b")).b, true, 'avant : l’orage bloquait');
  const db = await base({ jusqua: 2 });
  const p = Object.fromEntries((await db.query('SELECT type, pays, bloque_chantiers b FROM climat_parametres')).rows.map(r => [r.type + '/' + r.pays, r.b]));
  assert.deepEqual(p, { 'blizzard/soviet': false, 'crue/republic': true, 'canicule/republic': true, 'orage/republic': false, 'orage/soviet': false,
    'brouillard/republic': false, 'brouillard/soviet': false });
  for (const type of ['orage', 'blizzard', 'brouillard']) {
    await db.query('DELETE FROM climat_evenements');
    await evenement(db, type, 0, { heure: 0, heures: 23, pays: type === 'blizzard' ? 'soviet' : 'republic', ville: type === 'blizzard' ? 'ville_a' : 'capitale' });
    await db.query("UPDATE climat_evenements SET debut = now() - interval '1 hour', fin = now() + interval '3 hours'");
    const v = type === 'blizzard' ? "('soviet','ville_a')" : "('republic','capitale')";
    assert.equal((await un(db, 'SELECT climat_chantiers_bloques_interne' + v + ' b')).b, false, type + ' ne bloque pas');
  }
  const r = await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r");
  assert.notEqual(r.r.raison, 'chantier_intemperies');
  // Consigne de l'orage : les chantiers continuent.
  const c = (await un(db, "SELECT climat_consigne_interne('orage','republic','capitale') c")).c;
  assert.match(c, /ni de piratage, mais les chantiers continuent\. Débranchez/); assert.doesNotMatch(c, /arrêt/);
});

test('D.2 : le blizzard n’est tiré qu’à Starovka ; les blizzards planifiés ailleurs sont annulés (correction si annoncés)', async () => {
  let ids = {};
  const db = await base({ jusqua: 2, avantMigrations: async d => {
    ids.starovka = await evenement(d, 'blizzard', 2, { pays: 'soviet', ville: 'ville_a', heures: 24, effets: false });
    ids.novomirsk = await evenement(d, 'blizzard', 4, { pays: 'soviet', ville: 'capitale', heures: 24, effets: false });
    ids.krasnov = await evenement(d, 'blizzard', 7, { pays: 'soviet', ville: 'ville_b', heures: 24, effets: false });
    await d.query('UPDATE climat_evenements SET alerte_le = NULL WHERE id = $1', [ids.krasnov]);
  } });
  const an = Object.fromEntries((await db.query('SELECT id, annule FROM climat_evenements')).rows.map(r => [r.id, r.annule]));
  assert.deepEqual([an[ids.starovka], an[ids.novomirsk], an[ids.krasnov]], [false, true, true]);
  assert.equal((await db.query("SELECT 1 FROM evenements_globaux WHERE texte LIKE '%blizzard%est levée%'")).rows.length, 1, 'une correction : Novomirsk était annoncé');
  // Tirage du mandat : seuls des blizzards à Starovka.
  await db.query('DELETE FROM climat_evenements');
  await db.query("INSERT INTO cycles_electoraux VALUES ('soviet', 'president', $1, now())", [JSON.stringify({ dateFinMandat: Date.now() + 40 * 86400000 })]);
  await un(db, 'SELECT climat_planifier_mandat_interne() n');
  const villes = (await db.query("SELECT ville FROM climat_evenements WHERE type = 'blizzard'")).rows.map(r => r.ville);
  assert.deepEqual(villes, ['ville_a']);
  assert.equal((await un(db, "SELECT climat_creer_interne('blizzard','soviet','capitale', (now() AT TIME ZONE 'Europe/Paris')::date + 5, 'T', 'mj') id")).id, null);
  await db.exec(lire('migrations/20261124132000_climat_chantiers_canicule_crue_blizzard_starovka.sql'));
  assert.equal((await un(db, 'SELECT count(*)::int n FROM climat_villes_exclues')).n, 2);
});

test('D.3 avant / après : après une canicule, la nuit du chantier avançait ; désormais elle n’avance pas (un jour de retard)', async () => {
  // Canicule d'hier (heure de Paris), effets JAMAIS posés (effets_le NULL) : l'ordre minuit / pose des effets ne compte pas.
  const avant = await base({ jusqua: 2, avantMigrations: d => evenement(d, 'canicule', -1, { effets: false }) });
  const pa = (await lireCh(avant)).progressionJours;
  await nuit(avant);
  assert.equal((await lireCh(avant)).progressionJours, pa + 1, 'avant : la canicule n’arrêtait pas la nuit');
  const db = await base({ jusqua: 3, avantMigrations: d => evenement(d, 'canicule', -1, { effets: false }) });
  const av = await lireCh(db);
  const r = await nuit(db);
  assert.equal(r.ok, true); assert.equal(r.climat, 'canicule'); assert.equal(r.avance, 0); assert.equal(r.crue, false);
  const c = await lireCh(db);
  assert.equal(c.progressionJours, av.progressionJours); assert.equal(c.tresorerie, av.tresorerie); assert.deepEqual(c.stockMateriaux, av.stockMateriaux);
  assert.deepEqual(c.evenements.map(e => e.cle), ['canicule'], 'ligne « canicule » au journal du chantier');
  assert.equal((await nuit(db)).rejeu, true);
});

test('D.3 : canicule du jour → travail refusé jusqu’à minuit ; crue inchangée ; orage d’hier sans effet la nuit', async () => {
  const db = await base({ jusqua: 3 });
  // Canicule d'aujourd'hui 12 h – 18 h simulée terminée : le travail reste refusé jusqu'à minuit.
  await evenement(db, 'canicule', 0, { heure: 0, heures: 1 });
  await db.query("UPDATE climat_evenements SET debut = now() - interval '2 hours', fin = now() - interval '1 hour' ");
  const memeJour = (await un(db, "SELECT ((now() - interval '2 hours') AT TIME ZONE 'Europe/Paris')::date = (now() AT TIME ZONE 'Europe/Paris')::date ok")).ok;
  if (memeJour) {   // (juste après minuit, la canicule simulée tomberait la veille : contrôle sauté)
    const r = await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r");
    assert.equal(r.r.raison, 'chantier_intemperies');
  }
  await db.query('DELETE FROM climat_evenements');
  await evenement(db, 'crue', -1);
  assert.equal((await nuit(db)).climat, 'crue');
  await db.query('DELETE FROM climat_evenements');
  await db.query("UPDATE terrains_etat SET data = jsonb_set(data::jsonb, '{chantier,jourTraite}', '\"2000-01-01\"')::text");
  await evenement(db, 'orage', -1);
  const r = await nuit(db);
  assert.equal(r.climat, undefined); assert.ok(Number(r.avance) > 0, 'l’orage n’arrête pas le chantier');
});
