'use strict';
// Décisions du 26/11/2026, bloc C (décisions n° 5 et 6 de Fred) : dotations initiales des commerces (PNJ compris) et des caisses
// publiques, réglables dans la page MJ, lues par la remise à zéro du 19/12. Migration 20261126200000 dans PGlite.
// Le bloc de réinitialisation qui les lit est éprouvé par banc-remise-a-zero-pglite-20261125.cjs.
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-dotations-lancement-pglite-20261126.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261126200000_dotations_lancement.sql';

test('fichiers : migration sans écriture de solde, page MJ branchée, procédure à jour', () => {
  const m = lire(MIG);
  assert.match(m.split('\n')[0], /(NON APPLIQUÉE|APPLIQUÉE en production)/);
  assert.doesNotMatch(m.replace(/^--.*$/gm, ''), /UPDATE public\.(caisses_batiments|entreprises)/, 'aucun solde touché par la migration');
  assert.match(lire('admin.html'), /admin-dotations-lancement\.js/);
  assert.match(lire('admin-dotations-lancement.js'), /admin_dotation_caisse_fixer/);
  const r = lire('historique/preparations-lancement/reinitialisations.modele.sql');
  assert.match(r, /lancement_dotations_commerces/); assert.match(r, /lancement_dotations_caisses/);
  assert.match(lire('outils/lancement/classement-complementaire-20261125.csv'), /^admin_journal;garder;/m);
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
CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb);
INSERT INTO entreprises VALUES ('g', '{"type": "garage"}'), ('c', '{"type": "cafe"}');
CREATE TABLE admin_journal (admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE FUNCTION admin_exiger() RETURNS void LANGUAGE sql AS $f$ SELECT $f$;`;

test('défauts, catégories, réglages MJ et bornes', async () => {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG));
  const un = async (q, p = []) => (await db.query(q, p)).rows[0];
  assert.equal((await un("SELECT count(*)::int n FROM lancement_dotations_commerces WHERE type = '*'")).n, 2);
  assert.equal(Number((await un("SELECT montant FROM lancement_dotations_caisses WHERE pays = 'republic' AND categorie = 'gouvernement-min_def'")).montant), 35000);
  for (const [id, cat] of [['republic_commissariat_ville_a', 'commissariat'], ['republic_mairie-capitale', 'mairie-capitale'],
                           ['soviet_gouvernement-min_def', 'gouvernement-min_def'], ['republic_port-sainte-marie', 'port-sainte-marie']])
    assert.equal((await un('SELECT lancement_caisse_categorie($1) c', [id])).c, cat);
  const com = async (...a) => (await un('SELECT admin_dotation_commerce_fixer($1, $2, $3, $4, $5) r', a)).r;
  assert.equal((await com('soviet', 'garage', 5000, 20, 4)).ok, true);
  assert.equal((await com('soviet', 'garage', -1, 20, 4)).raison, 'valeur_invalide');
  assert.equal((await com('narco', 'garage', 1, 1, 1)).raison, 'parametres_invalides');
  assert.equal((await com('soviet', '*', null, null, null)).raison, 'defaut_obligatoire');
  assert.equal((await com('soviet', 'garage', null, null, null)).ok, true, 'champs vides : retour au défaut');
  const cai = async (...a) => (await un('SELECT admin_dotation_caisse_fixer($1, $2, $3) r', a)).r;
  assert.equal((await cai('soviet', 'mairie', 2500)).ok, true);
  assert.equal(Number((await un("SELECT montant FROM lancement_dotations_caisses WHERE pays = 'soviet' AND categorie = 'mairie'")).montant), 2500);
  assert.equal((await cai('republic', '*', null)).raison, 'defaut_obligatoire');
  const l = (await un('SELECT admin_dotations_lancement_lire() r')).r;
  assert.deepEqual(l.types_commerces.sort(), ['cafe', 'garage']);
  assert.ok(l.caisses.length > 40);
  assert.equal((await un("SELECT count(*)::int n FROM admin_journal WHERE action LIKE 'dotation_%'")).n, 3, 'seules les écritures acceptées sont journalisées');
  await db.exec(lire(MIG));   // rejouable : réglages du MJ gardés
  assert.equal(Number((await un("SELECT montant FROM lancement_dotations_caisses WHERE pays = 'soviet' AND categorie = 'mairie'")).montant), 2500);
});
