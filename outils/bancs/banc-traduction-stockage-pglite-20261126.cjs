'use strict';
// Décisions du 26/11/2026, bloc D : stockage privé de la traduction (cache 7 jours, quota quotidien par compte, aucune lecture
// pour anon ni authenticated). Migration 20261126300000 dans PGlite.
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-traduction-stockage-pglite-20261126.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261126300000_traduction_textes_joueurs.sql';
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }
const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role; END IF; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT NULL::uuid $f$;
CREATE TABLE admin_journal (admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE FUNCTION admin_exiger() RETURNS void LANGUAGE sql AS $f$ SELECT $f$;`;
const U = '00000000-0000-0000-0000-000000000001', K1 = 'a'.repeat(64), K2 = 'b'.repeat(64);
test('quota par compte, jamais deux appels payants pour la même clé, cache, interrupteur MJ, droits', async () => {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG));
  const un = async (q, p = []) => (await db.query(q, p)).rows[0];
  assert.deepEqual(await un('SELECT enabled, daily_requests, daily_characters FROM rp_i18n_configuration'), { enabled: true, daily_requests: 200, daily_characters: 120000 });
  const reserver = async (k, n) => (await un('SELECT rp_i18n_budget_reserver($1, $2, $3) r', [U, k, n])).r;
  assert.equal(await reserver(K1, 100), true);
  assert.equal(await reserver(K1, 100), false, 'même clé le même jour : refus');
  assert.equal((await un("SELECT admin_traduction_regler(true, 2, 150) r")).r.ok, true);
  assert.equal(await reserver(K2, 100), false, 'plafond de caractères atteint');
  assert.equal((await un("SELECT admin_traduction_regler(false, 200, 120000) r")).r.ok, true);
  assert.equal(await reserver('c'.repeat(64), 10), false, 'interrupteur coupé');
  assert.equal((await un('SELECT rp_i18n_cache_ecrire($1, $2) r', [K1, 'Hello'])).r, true);
  assert.equal((await un('SELECT rp_i18n_cache_lire($1) r', [K1])).r, 'Hello');
  assert.equal((await un("SELECT has_table_privilege('authenticated', 'rp_i18n_cache', 'SELECT') d")).d, false);
  assert.equal((await un("SELECT has_function_privilege('authenticated', 'rp_i18n_cache_lire(text)', 'EXECUTE') d")).d, false);
  assert.equal((await un("SELECT has_function_privilege('service_role', 'rp_i18n_budget_reserver(uuid,text,integer)', 'EXECUTE') d")).d, true);
  assert.equal((await un("SELECT admin_traduction_regler(true, -1, 10) r")).r.raison, 'valeur_invalide');
  await db.exec(lire(MIG));   // rejouable : réglage du MJ gardé
  assert.equal((await un('SELECT enabled FROM rp_i18n_configuration')).enabled, false, 'interrupteur du MJ gardé');
});
