'use strict';
// Mission de jour du 25/11/2026, bloc 1.2 (décision de Fred, D.4) : les 20 bouteilles d'eau offertes aux ouvriers lèvent
// l'arrêt de canicule du chantier pour la JOURNÉE EN COURS seulement ; si la canicule continue, le chantier s'arrête de nouveau
// le lendemain (et l'eau peut y être offerte de nouveau). Réglage MJ canicule_eau_leve_arret = 1 par défaut.
// Socle du banc de la Purge (bloc D) + migration 20261125150000, dans PGlite.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-canicule-eau-journee-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('écran : textes « aujourd’hui seulement », réglage lu au serveur', () => {
  const js = lire('plateau-climat.js');
  assert.match(js, /ils reprennent le travail aujourd’hui seulement, et le chantier s’arrête de nouveau demain si la canicule continue/);
  assert.match(js, /r\.leve_arret \? 'aide' : 'aide_sans_levee'/);
});
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
  '20261124133000_climat_arret_chantier_nuit', '20261124134000_chantier_canicule_eau_ouvriers', '20261124135000_starovka_sans_canicule_ni_fontaine', '20261124136000_bouteille_eau_sovarka']
  .filter(m => fs.existsSync(path.join(root, 'migrations', m + '.sql'))).concat(['20261125150000_canicule_eau_journee']);

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

const comme = async (db, qui, sql, p) => { await db.query("SELECT set_config('test.acteur', $1, false)", [qui]); return (await db.query(sql, p)).rows[0].r; };
let nreq = 0; const req = () => '00000000-0000-4000-8000-' + String(++nreq).padStart(12, '0');
const bouteilles = async (db, qui) => Number((await un(db, "SELECT inventaire_quantite(inventory, 'bouteille_eau') q FROM personnages_donnees WHERE name = $1", [qui])).q);


const decalerHier = db => db.exec(`UPDATE climat_evenements SET debut = debut - interval '1 day', fin = fin - interval '1 day';
  UPDATE terrains_etat SET data = jsonb_set(data::jsonb, '{chantier,evenements}', (SELECT coalesce(jsonb_agg(CASE WHEN e->>'cle' = 'eau_offerte'
    THEN jsonb_set(e, '{date}', to_jsonb((((now() AT TIME ZONE 'Europe/Paris')::date) - 1)::text)) ELSE e END), '[]'::jsonb)
    FROM jsonb_array_elements(data::jsonb->'chantier'->'evenements') e))::text`);
const canicule = async db => { const id = await evenement(db, 'canicule', 0, { heure: 0, heures: 1 });
  // Début borné au minuit du jour (heure de Paris) : lancé entre minuit et une heure, « now() − 1 h » tombait la veille et
  // le banc échouait selon l'heure (CI du 26/11 à 00 h 20).
  await db.query(`UPDATE climat_evenements SET debut = greatest(now() - interval '1 hour',
      (date_trunc('day', now() AT TIME ZONE 'Europe/Paris') AT TIME ZONE 'Europe/Paris') + interval '1 second'),
    fin = now() + interval '5 hours' WHERE id = $1`, [id]); return id; };

test('par défaut, l’eau lève l’arrêt aujourd’hui : travail accepté, et la nuit de ce jour le chantier avance', async () => {
  const db = await base();
  assert.equal(Number((await un(db, "SELECT valeur FROM aliments_parametres WHERE cle = 'canicule_eau_leve_arret'")).valeur), 1, 'réglage MJ à 1 par défaut');
  await canicule(db);
  assert.equal((await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r")).r.raison, 'chantier_intemperies');
  const ok = await comme(db, 'Bob', 'SELECT chantier_canicule_offrir_eau($1, $2) r', [req(), 'terrain-a-batir-3']);
  assert.equal(ok.ok, true); assert.equal(ok.leve_arret, true);
  assert.equal((await comme(db, 'Bob', 'SELECT chantier_climat_etat($1) r', ['terrain-a-batir-3'])).eau_offerte.par, 'Bob');
  assert.equal((await comme(db, 'Bob', 'SELECT chantier_canicule_offrir_eau($1, $2) r', [req(), 'terrain-a-batir-3'])).raison, 'deja_offerte', 'une fois par jour');
  assert.notEqual((await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r")).r.raison, 'chantier_intemperies');
  await decalerHier(db);   // minuit passé : la nuit traite la journée de la canicule et de l'eau
  const r = await nuit(db);
  assert.equal(r.climat, undefined); assert.ok(Number(r.avance) > 0);
});

test('la canicule continue le lendemain : l’arrêt revient, l’eau d’hier ne compte plus, on peut en offrir de nouveau', async () => {
  const db = await base();
  await canicule(db);
  assert.equal((await comme(db, 'Bob', 'SELECT chantier_canicule_offrir_eau($1, $2) r', [req(), 'terrain-a-batir-3'])).ok, true);
  await decalerHier(db);
  await canicule(db);   // la canicule continue aujourd'hui
  assert.equal((await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r")).r.raison, 'chantier_intemperies', 'arrêt de nouveau');
  assert.equal((await comme(db, 'Bob', 'SELECT chantier_climat_etat($1) r', ['terrain-a-batir-3'])).eau_offerte, null);
  // Nuit de demain (journée d'aujourd'hui) sans eau : arrêt.
  const etat = JSON.parse((await un(db, 'SELECT data FROM terrains_etat')).data);
  const demain = (await un(db, "SELECT (((now() AT TIME ZONE 'Europe/Paris')::date) + 1)::text j")).j;
  const sansEau = (await un(db, "SELECT chantier_crue_jour_interne('republic_terrain-a-batir-3', 'republic', $1::jsonb, 'chantier', $2) r", [JSON.stringify(etat), demain])).r;
  assert.equal(sansEau.climat, 'canicule');
  // Bob a encore 5 bouteilles : il lui en faut 20. Il en reprend, et offre de nouveau aujourd'hui.
  await db.query(`UPDATE personnages_donnees SET inventory = '[{"name":"Bouteille d''eau","type":"bouteille_eau","stackKey":"bouteille_eau","qty":20}]' WHERE name = 'Bob'`);
  assert.equal((await comme(db, 'Bob', 'SELECT chantier_canicule_offrir_eau($1, $2) r', [req(), 'terrain-a-batir-3'])).ok, true);
  assert.notEqual((await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r")).r.raison, 'chantier_intemperies');
  const etat2 = JSON.parse((await un(db, 'SELECT data FROM terrains_etat')).data);
  assert.equal((await un(db, "SELECT chantier_crue_jour_interne('republic_terrain-a-batir-3', 'republic', $1::jsonb, 'chantier', $2) r", [JSON.stringify(etat2), demain])).r, null, 'eau du jour : la nuit avance');
});

test('réglage MJ remis à 0 : l’eau n’est qu’un geste inscrit, le chantier reste arrêté', async () => {
  const db = await base();
  await db.query("UPDATE aliments_parametres SET valeur = 0 WHERE cle = 'canicule_eau_leve_arret'");
  await canicule(db);
  assert.equal((await comme(db, 'Bob', 'SELECT chantier_canicule_offrir_eau($1, $2) r', [req(), 'terrain-a-batir-3'])).leve_arret, false);
  assert.equal((await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'terrain-a-batir-3', 1) r")).r.raison, 'chantier_intemperies');
  // Migration rejouable.
  await db.exec(lire('migrations/20261125150000_canicule_eau_journee.sql'));
});
