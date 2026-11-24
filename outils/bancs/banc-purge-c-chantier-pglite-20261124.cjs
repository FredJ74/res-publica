'use strict';
// Mission « Purge », bloc C (Fred, 24/11/2026) : lecture serveur de la fenêtre du chantier
// (migration 20261124120000_chantier_fenetre_lire), éprouvée dans un vrai PostgreSQL local (PGlite) sur les définitions
// de production de chantier_travailler (socle + jour d'avance + heures ouvertes). La lecture ne doit rien écrire et son
// plafond d'heures doit être exactement celui que chantier_travailler accorde ensuite.
// PGlite : PGLITE_DIR=<dossier contenant node_modules/@electric-sql/pglite>.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

// Building de 24 jours comme celui d'Arnie : capacité 84 000 / 70 / 24 = 50 heures par jour.
function chantier(o = {}) {
  return Object.assign({ type: 'construction', niveau: 'building', coutTotal: 120000, dureeJours: 24, progressionJours: 1, totalVerse: 120000,
    tresorerie: 60000, coutTravail: 84000, coutMateriaux: 36000, heuresTotales: 1200, heuresFaites: 0, maitreOuvrage: 'Arnie',
    prixAchatPJ: { bois: 6, minerai: 11, metal: 17 }, stockMateriaux: { bois: 1000, minerai: 1000, metal: 1000 }, travauxPJ: [], evenements: [],
    jourTraite: '2000-01-01' }, o);
}
async function base(ch, { pa = 500, inventaire = [], batiment = 'terrain-a-batir-3', intemperies = false } = {}) {
  const db = new PGlite();
  for (const f of ['outils/bancs/fixtures/chantier-pglite-socle.sql.txt', 'migrations/20261121140000_chantier_jour_avance.sql',
    'outils/bancs/fixtures/chantier-commande-entrepot.sql.txt', 'migrations/20261122120000_chantier_heures_ouvertes_commande_nuit.sql']) await db.exec(lire(f));
  await db.exec(`ALTER TABLE terrains_etat ADD COLUMN IF NOT EXISTS building_id text;
    ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS country text, ADD COLUMN IF NOT EXISTS current_building text,
      ADD COLUMN IF NOT EXISTS inventory jsonb, ADD COLUMN IF NOT EXISTS hospitalisation jsonb;
    CREATE OR REPLACE FUNCTION public.mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('test.acteur', true), '') $$;
    CREATE OR REPLACE FUNCTION public.detention_active(p text) RETURNS TABLE(id int) LANGUAGE sql AS $$ SELECT 1 WHERE p = 'Prisonnier' $$;
    CREATE OR REPLACE FUNCTION public.climat_chantiers_bloques_interne(p text, v text) RETURNS boolean LANGUAGE sql AS $$ SELECT ${intemperies} $$;
    INSERT INTO ressources_economie VALUES ('bois', 5), ('minerai', 10), ('metal', 15) ON CONFLICT DO NOTHING;`);
  await db.query("INSERT INTO terrains_etat (id, country, data, updated_at, building_id) VALUES ('republic_terrain-a-batir-3', 'republic', $1, now(), 'terrain-a-batir-3')",
    [JSON.stringify({ proprietaire: 'Arnie', city: 'capitale', chantier: ch })]);
  await db.query(`INSERT INTO personnages_donnees (name, pa, arg, liquide, day, current_city, updated_at, country, current_building, inventory)
    VALUES ('Tom', $1, 0, 0, 30, 'capitale', now(), 'republic', $2, $3), ('Prisonnier', 10, 0, 0, 30, 'capitale', now(), 'republic', 'terrain-a-batir-3', '[]')`,
    [pa, batiment, JSON.stringify(inventaire)]);
  await db.exec(lire('migrations/20261124120000_chantier_fenetre_lire.sql'));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
async function lireFenetre(db, qui = 'Tom') {
  await db.query("SELECT set_config('test.acteur', $1, false)", [qui]);
  return (await un(db, "SELECT chantier_fenetre_lire('terrain-a-batir-3') r")).r;
}
const instantane = async db => JSON.stringify((await db.query('SELECT (SELECT data FROM terrains_etat) d, (SELECT json_agg(p ORDER BY name) FROM (SELECT name, pa, arg, liquide FROM personnages_donnees) p) p')).rows);
const travailler = async (db, h) => (await un(db, "SELECT chantier_travailler('Tom', 'republic', 'republic_terrain-a-batir-3', $1) r", [h])).r;

test('lecture sans effet : terrain et personnages identiques avant et après', async () => {
  const db = await base(chantier({ heuresFaites: 10 }));
  const avant = await instantane(db);
  const f = await lireFenetre(db);
  assert.equal(f.ok, true);
  assert.equal(await instantane(db), avant);
});

test('jour normal : encore 50 h, plafond = PA, gain au taux du serveur, identique à chantier_travailler', async () => {
  const db = await base(chantier(), { pa: 12 });
  const f = await lireFenetre(db);
  assert.equal(f.travail.capacite, 50); assert.equal(f.travail.restantesJour, 50); assert.equal(f.travail.taux, 70);
  assert.equal(f.travail.max, 12); assert.equal(f.travail.raison, null);
  const r = await travailler(db, 2147483647);
  assert.equal(r.heures, f.travail.max); assert.equal(r.montant, f.travail.max * f.travail.taux);
});

test('jour entamé puis jour d’avance : le plafond suit exactement la règle du serveur', async () => {
  const db = await base(chantier({ heuresFaites: 45, tauxHoraire: 90 }));
  const f = await lireFenetre(db);
  assert.equal(f.travail.restantesJour, 5); assert.equal(f.travail.restantesAvance, 50); assert.equal(f.travail.taux, 90);
  assert.equal(f.travail.max, 55);
  assert.equal((await travailler(db, 2147483647)).heures, 55);
  const g = await lireFenetre(db);
  assert.equal(g.travail.max, 0); assert.equal(g.travail.raison, 'aucune_heure_ouverte'); assert.equal(g.travail.restantesJour, 0);
});

test('trésorerie et PA : le plafond et la raison viennent du serveur', async () => {
  const pauvre = await base(chantier({ tresorerie: 210 }));
  assert.equal((await lireFenetre(pauvre)).travail.max, 3);
  const vide = await base(chantier({ tresorerie: 0 }));
  assert.equal((await lireFenetre(vide)).travail.raison, 'tresorerie_insuffisante');
  const epuise = await base(chantier(), { pa: 0 });
  assert.equal((await lireFenetre(epuise)).travail.raison, 'pa_insuffisants');
});

test('absent, détenu, intempéries : aucune heure, raison nommée', async () => {
  assert.equal((await lireFenetre(await base(chantier(), { batiment: 'rue' }))).travail.raison, 'pas_sur_place');
  assert.equal((await lireFenetre(await base(chantier()), 'Prisonnier')).travail.raison, 'acteur_detenu');
  const crue = await lireFenetre(await base(chantier(), { intemperies: true }));
  assert.equal(crue.travail.max, 0); assert.equal(crue.travail.raison, 'chantier_intemperies');
});

test('matériaux : besoin du jour, prix du propriétaire, plafond = manque, possédé, trésorerie', async () => {
  const db = await base(chantier({ stockMateriaux: { bois: 90, minerai: 0, metal: 34 }, tresorerie: 60, prixAchatPJ: { bois: 6, minerai: 11 } }),
    { inventaire: [{ stackable: true, stackKey: 'bois', qty: 25 }, { stackable: true, stackKey: 'minerai', qty: 40 }] });
  const f = await lireFenetre(db), m = f.materiaux;
  // Jour 2 du cycle du socle : 100 bois, 50 minerai, 34 métal.
  assert.deepEqual([m.bois.besoin, m.bois.stock, m.bois.manque, m.bois.possede, m.bois.prix], [100, 90, 10, 25, 6]);
  assert.equal(m.bois.max, 10);            // ce qui manque
  assert.equal(m.minerai.max, 5);          // la trésorerie (60 / 11)
  assert.equal(m.minerai.maxDon, 40);      // un don ne coûte rien au chantier
  assert.equal(m.metal.prix, 17);          // prix de base + 10 % (15 → 17), comme vendre_materiaux_chantier
  assert.equal(m.metal.max, 0);            // besoin couvert, rien à vendre
  assert.equal(f.accepteMateriaux, true);
});
