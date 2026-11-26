'use strict';
// Décisions du 26/11/2026, bloc E : la bénédiction exige au serveur un religieux habilité présent dans la pièce ; « Mobiliser
// les membres » trouve le syndicat d'un joueur à l'étranger. Migration 20261126400000 dans PGlite.
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-benediction-religieux-pglite-20261126.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261126400000_benediction_religieux_present.sql';

test('religieux déclarés = religieux de data.js ; écran : motif expliqué ; Mobiliser relit les organisations', () => {
  const data = lire('data.js').replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
  const noms = [...lire(MIG).matchAll(/\('(?:republic|soviet)', '[a-z_]+', '[a-z-]+', '[a-z_]+', '([^']+)', '(?:grand_pretre|pretre|clerc)'\)/g)].map(m => m[1]);
  assert.equal(noms.length, 8);
  for (const n of new Set(noms)) assert.ok(data.includes(n), n + ' : présent dans data.js');
  assert.match(lire('plateau-divers.js'), /v\.raison === 'pas_de_religieux_ici'/);
  const o = lire('plateau-organisations-quetes.js');
  assert.match(o, /async function doMobiliserMembresSyndicat\(\)/);
  assert.match(o, /await chargerOrganisations\(\{ lectureSeule: true \}\)/);
  assert.match(o, /COUNTRIES\[orga\.country_origine \|\| orga\.country \|\| state\.country\]/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text, excommunie jsonb, pa int DEFAULT 10);
INSERT INTO personnages_donnees VALUES ('Ivan', 'soviet', 'capitale', 'kolkhoze-spirituel', 'grange_sainte', NULL, 10),
  ('Olga', 'republic', 'capitale', 'tabernacle-impots', 'parvis', NULL, 10);
CREATE TABLE benedictions (personnage text PRIMARY KEY, accordee_le timestamptz, expire_le timestamptz, consommee_le timestamptz, par text);
CREATE TABLE requetes (a text, r uuid, res jsonb, PRIMARY KEY (a, r));
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('banc.moi', true), '') $f$;
CREATE FUNCTION achat_requete_ouvrir_interne(a text, r uuid, f text, p jsonb) RETURNS jsonb LANGUAGE sql AS $f$ SELECT res FROM requetes WHERE requetes.a = $1 AND requetes.r = $2 $f$;
CREATE FUNCTION achat_requete_clore_interne(a text, r uuid, f text, p jsonb, res jsonb) RETURNS jsonb LANGUAGE sql AS $f$ INSERT INTO requetes VALUES ($1, $2, $5) RETURNING res $f$;
CREATE FUNCTION jets_pa_prelever_interne(a text, f text, n int) RETURNS jsonb LANGUAGE sql AS $f$
  UPDATE personnages_donnees SET pa = pa - n WHERE name = a RETURNING jsonb_build_object('ok', true, 'pa', pa) $f$;
-- Version de production réduite : porte la marque attendue par la garde de la migration.
CREATE FUNCTION benediction_contact_demander(p_requete uuid, p_pnj text) RETURNS jsonb LANGUAGE sql AS $f$ SELECT '{}'::jsonb /* benediction_serveur_v1 */ $f$;`;

test('présence vérifiée avant toute dépense ; nom tolérant au suffixe (PNJ) ; ailleurs, refus', async () => {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG));
  const demander = async (qui, pnj) => { await db.query("SELECT set_config('banc.moi', $1, false)", [qui]);
    return (await db.query('SELECT benediction_contact_demander(gen_random_uuid(), $1) r', [pnj])).rows[0].r; };
  const pa = async n => (await db.query('SELECT pa FROM personnages_donnees WHERE name = $1', [n])).rows[0].pa;
  let r = await demander('Ivan', 'Camarade Pontife Tractorenko (PNJ)');
  assert.equal(r.ok, true); assert.equal(await pa('Ivan'), 9, '1 PA');
  r = await demander('Ivan', 'Kouzma Lapchine');
  assert.equal(r.raison, 'pas_de_religieux_ici', 'le batiouchka officie à Krasnov, pas à Novomirsk'); assert.equal(await pa('Ivan'), 9);
  r = await demander('Olga', 'Père Ception (PNJ)');
  assert.equal(r.raison, 'pas_de_religieux_ici', 'parvis : le Grand Prêtre est dans la nef'); assert.equal(await pa('Olga'), 10);
  await db.exec("UPDATE personnages_donnees SET current_room = 'nef_principale' WHERE name = 'Olga'");
  assert.equal((await demander('Olga', '  père   ception ')).ok, true);
  assert.equal((await db.query("SELECT count(*)::int n FROM religieux_habilites")).rows[0].n, 8);
  await db.exec(lire(MIG));   // rejouable
});
