'use strict';
// Mission de nuit du 25/11/2026, bloc 3 : « Subtiliser des explosifs » applique sa description (décision de Fred, 24/11).
// Vrai PostgreSQL local (PGlite) ; les briques du moteur commun dont dépend la migration sont reproduites à l'identique
// (crim_bonus_dis_interne, crim_stat_interne, crime_malus_isn_interne) ou simulées (présence armée, masque/cachette,
// arrestation, stock), pour éprouver la formule et les issues de militaire_subtiliser_tenter avec des jets imposés.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-subtiliser-explosifs-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125120000_subtiliser_explosifs_description.sql';

test('description, libellés et ordre : la promesse correspond à la règle du serveur, sans pourcentage écrit en dur', () => {
  const data = lire('data.js');
  const ligne = data.split('\n').find(l => l.includes("fn:'acheter_bombe_illegale'"));
  assert.ok(ligne, 'ordre présent');
  for (const mot of ['discr', 'réputation criminelle', 'ISN', 'carrière criminelle', 'Sovarka', 'repéré']) assert.ok(ligne.includes(mot), mot);
  assert.doesNotMatch(ligne.match(/desc:'([^']|\\')*'/)[0], /\d+ ?%/, 'aucun pourcentage en dur dans la description');
  assert.match(lire('plateau-core.js'), /acheter_bombe_illegale:\s*\{ jours: 2, amende: 2000, label: "Vol d'explosifs militaires" \}/);
  assert.doesNotMatch(lire('plateau-core.js'), /Achat d'explosifs non enregistr/);
  const m = lire(MIG);
  assert.match(m, /UPDATE public\.infractions SET libelle = 'Vol d''explosifs militaires'/);
  assert.doesNotMatch(m.replace(/^--.*$/gm, ''), /goulag/i);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, career text,
  reputation_criminelle integer DEFAULT 0, resources jsonb DEFAULT '{}', stats jsonb DEFAULT '{}', pa integer DEFAULT 10,
  inventory jsonb DEFAULT '[]', hp integer DEFAULT 100);
CREATE TABLE crim_parametres (cle text PRIMARY KEY, valeur numeric);
INSERT INTO crim_parametres VALUES ('crim_dis_pivot', 50), ('crim_dis_tranche', 3), ('detection_cache', 20), ('detection_masque', 10), ('detection_min', 5);
CREATE TABLE infractions (id text PRIMARY KEY, libelle text, detect_rate integer);
INSERT INTO infractions VALUES ('acheter_bombe_illegale', 'Achat d''explosifs non enregistres', 55);
CREATE TABLE indices_villes (id text PRIMARY KEY, data jsonb);
CREATE TABLE banc_etat (nom text PRIMARY KEY, mode text DEFAULT 'decouvert', gardes integer DEFAULT 0);
CREATE TABLE banc_arrestations (nom text, acte text, motif text, jours integer, qhs boolean);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT current_setting('banc.moi', true) $$;
CREATE FUNCTION crim_param_interne(p_cle text, p_defaut numeric DEFAULT 0) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT valeur FROM crim_parametres WHERE cle = p_cle), p_defaut) $$;
CREATE FUNCTION crim_bonus_dis_interne(p_dis numeric) RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT greatest(0, trunc((coalesce(p_dis, 50) - crim_param_interne('crim_dis_pivot', 50)) / crim_param_interne('crim_dis_tranche', 3)))::integer $$;
CREATE FUNCTION crim_stat_interne(p_nom text, p_cle text, p_defaut numeric) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT CASE WHEN p_cle = 'dis' AND jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric
      WHEN p_cle <> 'dis' AND coalesce(d.stats ->> p_cle, '') ~ '^-?[0-9]+(\\.[0-9]+)?$' THEN (d.stats ->> p_cle)::numeric END
    FROM personnages_donnees d WHERE d.name = p_nom), p_defaut) $$;
CREATE FUNCTION crime_malus_isn_interne(p_pays text, p_ville text) RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN v <= 20 THEN 0 WHEN v <= 40 THEN 5 WHEN v <= 60 THEN 10 WHEN v <= 80 THEN 15 ELSE 25 END
    FROM (SELECT coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM indices_villes WHERE id = p_pays || '_' || coalesce(p_ville, 'capitale')), 30) AS v) x $$;
CREATE FUNCTION securite_malus_lieu_interne(p_acteur text) RETURNS integer LANGUAGE sql AS $$
  SELECT CASE WHEN coalesce((SELECT gardes FROM banc_etat WHERE nom = p_acteur), 0) > 0 THEN least(40, 10 + (SELECT gardes FROM banc_etat WHERE nom = p_acteur)) ELSE 0 END $$;
CREATE FUNCTION crim_mode_action_interne(p_nom text) RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT mode FROM banc_etat WHERE nom = p_nom), 'decouvert') $$;
CREATE FUNCTION crim_peine_jours_interne(p_acte text, p_pays text) RETURNS integer LANGUAGE sql AS $$ SELECT CASE WHEN p_pays = 'soviet' THEN 4 ELSE 2 END $$;
CREATE FUNCTION arrestation_flagrant_interne(p_nom text, p_acte text, p_b boolean, p_src text, p_motif text, p_jours integer, p_qhs boolean, p_retour text)
RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN INSERT INTO banc_arrestations VALUES (p_nom, p_acte, p_motif, p_jours, p_qhs);
  RETURN jsonb_build_object('motif', p_motif, 'jours', p_jours, 'qhs', p_qhs); END $$;
CREATE FUNCTION caserne_stock_mouvement(p_pays text, p_produit text, p_delta integer, p_x text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT '{"ok": true, "lots": [{"lot": "L1"}]}'::jsonb $$;
CREATE ROLE authenticated; CREATE ROLE anon;`;

async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG));
  return db;
}
async function pj(db, nom, o = {}) {
  await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, career, reputation_criminelle, resources)
    VALUES ($1, $2, $3, 'caserne-militaire', $4, $5, $6)`, [nom, o.pays || 'republic', o.ville || 'capitale', o.carriere || 'civil', o.rep || 0, JSON.stringify({ dis: o.dis ?? 50 })]);
  await db.query('INSERT INTO banc_etat (nom, mode, gardes) VALUES ($1, $2, $3)', [nom, o.mode || 'decouvert', o.gardes || 0]);
}
const chance = async (db, nom) => (await db.query('SELECT crim_subtiliser_chance_interne($1) c', [nom])).rows[0].c;
async function tenter(db, nom, jets) {
  await db.exec(`SET banc.moi = '${nom}'; SET rp.subtiliser_jets = '${JSON.stringify(jets)}';`);
  return (await db.query("SELECT militaire_subtiliser_tenter('republic') r")).rows[0].r;
}

test('formule : 35 de base, DIS, réputation criminelle, carrière criminelle, ISN, Sovarka, dissuasion ; bornes 5-75', async () => {
  const db = await base();
  await pj(db, 'Neutre');                                                   // DIS 50, ISN 30 par défaut (−5)
  assert.deepEqual(await chance(db, 'Neutre'), { taux: 30, base: 35, discretion: 0, reputation: 0, carriere: 0, isn: -5, sovarka: 0, dissuasion: 0 });
  await pj(db, 'Discret', { dis: 80, rep: 45 });                            // +10 DIS, +10 réputation
  assert.equal((await chance(db, 'Discret')).taux, 50);
  await pj(db, 'Truand', { dis: 95, rep: 80, carriere: 'criminal_c' });     // 35+15+15+15−5 = 75 (plafond)
  assert.equal((await chance(db, 'Truand')).taux, 75);
  await db.query(`INSERT INTO indices_villes VALUES ('soviet_capitale', '{"isn": 90}')`);
  await pj(db, 'Camarade', { pays: 'soviet', gardes: 2 });                  // 35 −25 ISN −10 Sovarka −12 gardes → plancher 5
  const c = await chance(db, 'Camarade');
  assert.deepEqual([c.taux, c.isn, c.sovarka, c.dissuasion], [5, -25, -10, -12]);
});

test('issues : un seul jet décide ; seul un échec détecté mène à l’arrestation, au motif « Vol d’explosifs militaires »', async () => {
  const db = await base();
  await pj(db, 'Han');                                                      // chance 30, détection 55
  let r = await tenter(db, 'Han', [30, 99]);
  assert.deepEqual([r.reussite, r.taux, r.jet, r.lot], [true, 30, 30, 'L1']);
  r = await tenter(db, 'Han', [31, 56]);                                    // échec, non repéré
  assert.deepEqual([r.reussite, r.detecte, r.detection, r.arrestation], [false, false, 55, undefined]);
  r = await tenter(db, 'Han', [31, 55]);                                    // échec repéré
  assert.deepEqual([r.reussite, r.detecte, r.arrestation.motif, r.arrestation.qhs], [false, true, 'Vol d\'explosifs militaires', false]);
  assert.equal((await db.query('SELECT count(*)::int n FROM banc_arrestations')).rows[0].n, 1, 'une seule arrestation');
  assert.equal((await db.query("SELECT pa FROM personnages_donnees WHERE name = 'Han'")).rows[0].pa, 4, '2 PA par tentative');
});

test('détection : 55 % de l’infraction, −20 caché, −10 masqué ; QHS en Sovarka au barème militaire', async () => {
  const db = await base();
  await pj(db, 'Ombre', { mode: 'cache_masque' });
  let r = await tenter(db, 'Ombre', [99, 25]);
  assert.deepEqual([r.detection, r.detecte], [25, true]);
  r = await tenter(db, 'Ombre', [99, 26]);
  assert.equal(r.detecte, false);
  await pj(db, 'Sacha', { pays: 'soviet' });
  r = await tenter(db, 'Sacha', [99, 1]);
  assert.deepEqual([r.arrestation.qhs, r.arrestation.jours], [true, 4]);
});

test('la chance renvoyée par l’ordre est celle de la formule (une seule source de vérité)', async () => {
  const db = await base();
  await pj(db, 'Vera', { dis: 71, rep: 25, carriere: 'criminal_c' });
  const c = await chance(db, 'Vera');
  const r = await tenter(db, 'Vera', [100, 100]);
  assert.equal(r.taux, c.taux);
  assert.equal(c.taux, 35 + 7 + 5 + 15 - 5);
});
