'use strict';
// Mission de nuit du 26/11/2026, étape 1 : l'ordre « Contrebande portuaire » est supprimé (décision de Fred du 26/11/2026).
// La contrebande se joue par fausse déclaration au fret du port. Migration 20261126230000 dans PGlite, sur une copie de la
// ligne de production de ordres_chances_audit_interne ; écran : l'ordre n'existe plus nulle part.
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-suppression-contrebande-pglite-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261126230000_suppression_contrebande_portuaire.sql';

test('écran : plus d’ordre contrebande_port (data.js, routeur, navigation, chances, détection, traductions, coûts)', () => {
  for (const f of ['data.js', 'plateau-router.js', 'plateau-chances-reelles.js', 'plateau-core.js', 'i18n/orders-resources.js',
    'baseline/seeds/95_a-regenerer/ordres_couts.sql', 'baseline/seeds/95_a-regenerer/infractions.sql']) {
    assert.doesNotMatch(lire(f), /contrebande_port/, f);
  }
  assert.doesNotMatch(lire('plateau-navigation.js'), /async function doContrebandePort|crime_contrebande/);
  assert.doesNotMatch(lire('i18n/toast-resources.js'), /smugglingSucceeded/);
  // Ce qui reste : corrompre un douanier, inspecter les cargaisons, le poisson « de l'autre rive », le fret déclaré.
  const data = lire('data.js');
  for (const fn of ['corrompre_douanier', 'inspecter_cargaisons', 'contrebande_poissonniere', 'expedier_colis']) assert.match(data, new RegExp("fn:'" + fn + "'"), fn);
  assert.match(lire('i18n/toast-resources.js'), /"Contrebande détectée !": "smugglingDetected"/, 'toast de l’inspection conservé');
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, inventory jsonb, inventory_revision bigint DEFAULT 0);
INSERT INTO personnages_donnees VALUES
  ('Ivan', '[{"id": "a", "type": "pain"}, {"id": "b", "type": "contrebande", "name": "Cargaison de contrebande"}, {"id": "c", "type": "bois"}]', 4),
  ('Olga', '[{"id": "d", "type": "pain"}]', 7), ('Vide', NULL, 0);
CREATE TABLE crim_parametres (cle text PRIMARY KEY, valeur numeric);
INSERT INTO crim_parametres VALUES ('contrebande_gain', 500), ('contrebande_gain_soviet', 100), ('incendie_min', 5);
CREATE TABLE ordres_couts (fn text PRIMARY KEY, pa integer, cost integer);
INSERT INTO ordres_couts VALUES ('contrebande_port', 3, 0), ('contrebande_poissonniere', 1, 0), ('corrompre_douanier', 2, 150);
CREATE TABLE infractions (id text PRIMARY KEY, libelle text);
INSERT INTO infractions VALUES ('contrebande_port', 'Delit mineur'), ('corrompre_douanier', 'Delit mineur');
CREATE TABLE infractions_alias (alias text, infraction_id text REFERENCES infractions(id));
CREATE TABLE dossiers_judiciaires_actes (id serial, infraction_id text REFERENCES infractions(id));
INSERT INTO dossiers_judiciaires_actes (infraction_id) VALUES ('corrompre_douanier');
CREATE FUNCTION crim_contrebande_taux_interne(p_nom text) RETURNS integer LANGUAGE sql AS $f$ SELECT 50 $f$;
CREATE FUNCTION crim_contrebande_gain_interne(p_pays text) RETURNS numeric LANGUAGE sql AS $f$ SELECT 500::numeric $f$;
CREATE FUNCTION crime_contrebande(p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE sql AS $f$ SELECT '{}'::jsonb $f$;
CREATE FUNCTION fraude_chance_interne(a text, t text) RETURNS integer LANGUAGE sql AS $f$ SELECT 63 $f$;
-- Copie réduite de la production : la ligne retirée est recopiée telle que pg_get_functiondef la rend (relevé du 26/11).
CREATE FUNCTION public.ordres_chances_audit_interne(a text, f text) RETURNS integer LANGUAGE plpgsql STABLE AS $function$
BEGIN
  CASE f
    WHEN 'bourrer_urnes' THEN RETURN public.fraude_chance_interne(a, 'bourrage_urnes');
    WHEN 'contrebande_port' THEN RETURN greatest(0, public.crim_contrebande_taux_interne(a) - coalesce(public.securite_malus_lieu_interne(a), 0));
    WHEN 'tentative_evasion' THEN RETURN public.detention_evasion_taux_interne(a, false);
    ELSE RETURN NULL;
  END CASE;
END $function$;`;

test('serveur : fonctions supprimées, ligne d’audit retirée, réglages, coût et barème effacés, cargaisons retirées ; rejouable', async () => {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG));
  const un = async q => (await db.query(q)).rows[0];
  for (const f of ['crime_contrebande(integer,integer)', 'crim_contrebande_taux_interne(text)', 'crim_contrebande_gain_interne(text)']) {
    assert.equal((await un(`SELECT to_regprocedure('public.${f}') IS NULL AS absente`)).absente, true, f);
  }
  const def = (await un("SELECT pg_get_functiondef('public.ordres_chances_audit_interne(text,text)'::regprocedure) AS d")).d;
  assert.match(def, /contrebande_supprimee_v1/); assert.doesNotMatch(def, /contrebande_port|crim_contrebande/);
  assert.equal((await un("SELECT ordres_chances_audit_interne('Ivan', 'bourrer_urnes') AS t")).t, 63, 'les autres ordres répondent');
  assert.equal((await un("SELECT ordres_chances_audit_interne('Ivan', 'contrebande_port') AS t")).t, null);
  assert.deepEqual((await db.query('SELECT cle FROM crim_parametres ORDER BY cle')).rows.map(r => r.cle), ['incendie_min']);
  assert.deepEqual((await db.query('SELECT fn FROM ordres_couts ORDER BY fn')).rows.map(r => r.fn), ['contrebande_poissonniere', 'corrompre_douanier']);
  assert.deepEqual((await db.query('SELECT id FROM infractions ORDER BY id')).rows.map(r => r.id), ['corrompre_douanier']);
  const ivan = await un("SELECT inventory, inventory_revision FROM personnages_donnees WHERE name = 'Ivan'");
  assert.deepEqual(ivan.inventory.map(o => o.id), ['a', 'c'], 'seule la cargaison est retirée, ordre conservé');
  assert.equal(Number(ivan.inventory_revision), 5);
  assert.equal(Number((await un("SELECT inventory_revision FROM personnages_donnees WHERE name = 'Olga'")).inventory_revision), 7, 'inventaire sans contrebande intact');
  await db.exec(lire(MIG));   // rejouable : la marque empêche un second remplacement
  assert.equal(Number((await un("SELECT inventory_revision FROM personnages_donnees WHERE name = 'Ivan'")).inventory_revision), 5);
});

test('serveur : version de production inattendue → la migration s’arrête sans rien supprimer', async () => {
  const db = new PGlite(); await db.exec(SOCLE);
  await db.exec(`CREATE OR REPLACE FUNCTION public.ordres_chances_audit_interne(a text, f text) RETURNS integer LANGUAGE sql AS $f$ SELECT 1 $f$`);
  await assert.rejects(db.exec(lire(MIG)), /ligne contrebande_port introuvable/);
  await db.exec('ROLLBACK');
  assert.equal((await db.query("SELECT to_regprocedure('public.crime_contrebande(integer,integer)') IS NOT NULL AS la")).rows[0].la, true);
});
