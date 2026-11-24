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
