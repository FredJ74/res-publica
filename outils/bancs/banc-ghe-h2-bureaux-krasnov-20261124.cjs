'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.2 : bureaux du centre d'affaires de Krasnov, loyer de départ 30 PSK par
// jour, réglable par le maire entre 0 et 40. Vrai PostgreSQL (PGlite) : la migration passe les bureaux au loyer
// d'ouverture (40) à 30, n'écrase ni un loyer choisi par le maire ni un bureau exploité, et se rejoue sans effet.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIGRATION = 'migrations/20261124141000_ghe_h2_bureaux_krasnov_loyer_30.sql';
test('H.2 — la porte du maire borne déjà le loyer entre 0 et le plafond ; décision consignée', () => {
  assert.match(lire('migrations/20261106133000_sovarka_droits_exploiter.sql'), /p_loyer < 0 OR p_loyer > l\.plafond/);
  assert.match(lire('GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md'), /loyer de départ 30 PSK par jour, réglable par le maire\s+entre 0 et 40/);
  assert.match(lire('data.js'), /loyer fixé par le maire, 40 PSK par jour au plus/);
});
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
test('H.2 — migration : 30 PSK au départ, rien d’écrasé, rejouable', { skip: !PGlite && 'PGlite absent (PGLITE_DIR)' }, async () => {
  const db = new PGlite();
  await db.exec(`CREATE TABLE public.sovarka_locaux (pays text NOT NULL DEFAULT 'soviet', ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
      label text NOT NULL, origine text NOT NULL, loyer integer NOT NULL DEFAULT 0, plafond integer NOT NULL DEFAULT 100, demande_id text,
      PRIMARY KEY (pays, ville, batiment, piece), CHECK (plafond BETWEEN 0 AND 100 AND loyer BETWEEN 0 AND plafond));
    CREATE TABLE public.exploitants (ville text, batiment text, piece text, nom text);
    CREATE FUNCTION public.sovarka_exploitant_interne(p_ville text, p_batiment text, p_piece text) RETURNS text LANGUAGE sql AS
      $$ SELECT nom FROM public.exploitants WHERE ville = p_ville AND batiment = p_batiment AND piece = p_piece $$;
    INSERT INTO public.sovarka_locaux (ville, batiment, piece, label, origine, loyer, plafond, demande_id) VALUES
      ('ville_b', 'centre-affaires', 'bureau_1', 'B1', 'centre', 40, 40, NULL), ('ville_b', 'centre-affaires', 'bureau_2', 'B2', 'centre', 40, 40, NULL),
      ('ville_b', 'centre-affaires', 'bureau_3', 'B3', 'centre', 25, 40, NULL), ('ville_b', 'centre-affaires', 'bureau_4', 'B4', 'centre', 40, 40, NULL),
      ('ville_b', 'centre-commercial', 'box_1', 'Box', 'centre', 20, 20, NULL);
    INSERT INTO public.exploitants VALUES ('ville_b', 'centre-affaires', 'bureau_4', 'Arnie');`);
  await db.exec(lire(MIGRATION));
  await db.exec(lire(MIGRATION));
  const l = Object.fromEntries((await db.query('SELECT piece, loyer FROM sovarka_locaux')).rows.map(r => [r.piece, r.loyer]));
  assert.deepEqual(l, { bureau_1: 30, bureau_2: 30, bureau_3: 25, bureau_4: 40, box_1: 20 });
});
