'use strict';
// Décisions du 26/11/2026, bloc B (décision n° 7 de Fred) : revenu universel de 45 PSK en Sovarka (150 FR en Républia), versé
// seulement pendant les 10 premiers jours d'un personnage dans les deux empires ; montants et durée réglables par le MJ.
// Migration 20261126100000 dans PGlite, sur salaire_civil_percevoir recopiée MOT POUR MOT de la production (md5
// bb3036b3a6775bd5f2259375282dec29, lue le 26/11/2026 : fixtures/salaire-civil-percevoir-prod-20261126.sql.txt).
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-revenu-universel-pglite-20261126.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261126100000_revenu_universel.sql', PROD = 'outils/bancs/fixtures/salaire-civil-percevoir-prod-20261126.sql.txt';

test('fichiers : migration, copie de production, écran et page MJ', () => {
  const m = lire(MIG);
  assert.match(m.split('\n')[0], /(NON APPLIQUÉE|APPLIQUÉE en production)/);
  assert.match(m, /Contrôles en lecture après application/);
  assert.equal(crypto.createHash('md5').update(lire(PROD)).digest('hex'), 'bb3036b3a6775bd5f2259375282dec29', 'copie fidèle de la production');
  assert.match(lire('plateau-personnage.js'), /revenu_universel_termine: \['Revenu universel terminé'/);
  assert.match(lire('admin.html'), /admin-revenu-universel\.js/);
  assert.match(lire('admin-revenu-universel.js'), /admin_revenu_universel_fixer/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT NULL::uuid $f$;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, nationalite text, country text, poste jsonb, liquide numeric DEFAULT 0, arg numeric DEFAULT 0,
  created_at timestamp DEFAULT now(), updated_at timestamptz);
CREATE TABLE salaires_civils_declares (cle text, categorie text, montant integer, pays text);
INSERT INTO salaires_civils_declares VALUES ('default', 'universel', 150, 'republic'), ('maire', 'poste', 500, 'republic');
CREATE TABLE salaires_civils_verses (id text PRIMARY KEY, personnage text, jour date, origine text, cle text, montant integer);
CREATE TABLE postes_attribues (titulaire text, poste_id text, country text, updated_at timestamptz);
CREATE TABLE cycles_electoraux (poste_id text, country text, data text, updated_at timestamptz);
CREATE TABLE batiments_etat (id text, data jsonb);
CREATE TABLE caisses_batiments (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
INSERT INTO caisses_batiments VALUES ('republic_mairie', '{"solde": 10000}', now());
CREATE TABLE admin_journal (admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('banc.moi', true), '') $f$;
CREATE FUNCTION salaire_ville_du_poste(p text, c text) RETURNS text LANGUAGE sql AS $f$ SELECT c $f$;
CREATE FUNCTION militaire_grade_effectif(p text) RETURNS text LANGUAGE sql AS $f$ SELECT NULL::text $f$;
CREATE FUNCTION batiment_etat_lire(d jsonb) RETURNS jsonb LANGUAGE sql AS $f$ SELECT d $f$;
CREATE FUNCTION salaire_caisse_de(p text, pays text, v text) RETURNS text LANGUAGE sql AS $f$ SELECT 'republic_mairie' $f$;
CREATE FUNCTION admin_exiger() RETURNS void LANGUAGE sql AS $f$ SELECT $f$;
INSERT INTO personnages_donnees (name, nationalite, country, poste, created_at) VALUES
  ('Neuve', 'soviet', 'soviet', NULL, now()),
  ('Ancienne', 'soviet', 'soviet', NULL, now() - interval '12 days'),
  ('Neuf', 'republic', 'republic', NULL, now() - interval '9 days'),
  ('Vieux', 'republic', 'republic', NULL, now() - interval '10 days'),
  ('Maire', 'republic', 'republic', '{"id": "maire", "city": "capitale"}', now() - interval '40 days');
`;
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE); await db.exec(lire(PROD)); await db.exec(lire(MIG));
  return db;
}
const percevoir = async (db, nom) => { await db.query("SELECT set_config('banc.moi', $1, false)", [nom]); return (await db.query('SELECT salaire_civil_percevoir() r')).rows[0].r; };

test('Sovarka : 45 PSK par jour pendant les 10 premiers jours, puis plus rien', async () => {
  const db = await base();
  let r = await percevoir(db, 'Neuve');
  assert.equal(r.ok, true); assert.equal(r.montant, 45); assert.equal(r.origine, 'universel');
  r = await percevoir(db, 'Ancienne');
  assert.equal(r.ok, false); assert.equal(r.raison, 'revenu_universel_termine'); assert.equal(r.jours, 10);
  assert.equal(Number((await db.query("SELECT liquide FROM personnages_donnees WHERE name = 'Ancienne'")).rows[0].liquide), 0);
});

test('Républia : 150 FR jusqu’au dixième jour (création = premier jour), plus au onzième ; un salaire de poste n’est pas touché', async () => {
  const db = await base();
  assert.equal((await percevoir(db, 'Neuf')).montant, 150, 'neuf jours d’ancienneté : dixième jour, encore versé');
  assert.equal((await percevoir(db, 'Vieux')).raison, 'revenu_universel_termine', 'dix jours d’ancienneté : onzième jour');
  const r = await percevoir(db, 'Maire');
  assert.equal(r.ok, true); assert.equal(r.origine, 'poste'); assert.equal(r.montant, 500);
});

test('page MJ : durée et montants réglables, bornes tenues', async () => {
  const db = await base();
  const fixer = async (c, v) => (await db.query('SELECT admin_revenu_universel_fixer($1, $2) r', [c, v])).rows[0].r;
  assert.equal((await fixer('jours', 15)).ok, true);
  assert.equal((await percevoir(db, 'Ancienne')).montant, 45, '12 jours d’ancienneté, durée portée à 15 : versé');
  assert.equal((await fixer('soviet', 60)).ok, true);
  assert.equal((await fixer('republic', 0)).raison, 'valeur_invalide');
  assert.equal((await fixer('jours', 400)).raison, 'valeur_invalide');
  assert.equal((await fixer('khalija', 10)).raison, 'reglage_inconnu');
  const l = (await db.query('SELECT admin_revenu_universel_lire() r')).rows[0].r;
  assert.deepEqual(l.montants, { republic: 150, soviet: 60 }); assert.equal(l.jours, 15);
  // Rejouée, la migration ne change rien (marque déjà posée, ligne de Sovarka gardée).
  await db.exec(lire(MIG));
  assert.equal(Number((await db.query("SELECT montant FROM salaires_civils_declares WHERE cle = 'default' AND pays = 'soviet'")).rows[0].montant), 60);
});
