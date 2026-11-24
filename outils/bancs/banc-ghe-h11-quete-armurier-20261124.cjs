'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.11 : la quête « Une affaire mystérieuse » de Sovarka précise dans son texte
// quel « Armurier Militaire » elle vise (nom du PNJ et lieu), sans changer sa mécanique.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIGRATION = 'migrations/20261124144000_ghe_h11_quete_armurier_militaire.sql';
test('H.11 — le PNJ nommé est bien l’armurier de la caserne de Novomirsk', () => {
  const d = lire('data.js');
  assert.match(d, /'Armurier Militaire \(PNJ\)': 'Sergent Bogdan Zatvorov \(PNJ\)'/);
  assert.match(d, /\['caserne-militaire', 'armurerie_militaire', 'Sergent Bogdan Zatvorov \(PNJ\)'/);
  assert.match(d, /name: "Caserne centrale de Novomirsk"/);
});
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
test('H.11 — texte précisé, mécanique intacte, autres pays intacts, rejouable (PGlite)', { skip: !PGlite && 'PGlite absent (PGLITE_DIR)' }, async () => {
  const db = new PGlite();
  await db.exec(`CREATE TABLE public.quetes_actives (id text PRIMARY KEY, country text, titre text, description text, etape_actuelle int,
      nb_etapes_total int, building_id text, room_id text, pnj_actif text, statut text);
    INSERT INTO public.quetes_actives VALUES
      ('quete-1790260995706', 'soviet', 'Une affaire mystérieuse', 'Une étrange rumeur circule dans la ville.', 1, 4, 'caserne-militaire', 'armurerie_militaire', 'Armurier Militaire', 'active'),
      ('quete-1789329409723', 'republic', 'Une affaire mystérieuse', 'Une étrange rumeur circule dans la ville.', 1, 2, 'stade', 'buvette', 'Tenancier de Buvette', 'active');`);
  await db.exec(lire(MIGRATION)); await db.exec(lire(MIGRATION));
  const q = Object.fromEntries((await db.query('SELECT * FROM quetes_actives')).rows.map(r => [r.country, r]));
  assert.equal(q.soviet.description, 'Une étrange rumeur circule dans la ville. L’« Armurier Militaire » à trouver est le Sergent Bogdan Zatvorov, à l’Armurerie Militaire de la Caserne centrale de Novomirsk.'.replace(/’/g, "'"));
  assert.deepEqual([q.soviet.pnj_actif, q.soviet.building_id, q.soviet.room_id, q.soviet.etape_actuelle, q.soviet.nb_etapes_total, q.soviet.statut],
    ['Armurier Militaire', 'caserne-militaire', 'armurerie_militaire', 1, 4, 'active']);
  assert.equal(q.republic.description, 'Une étrange rumeur circule dans la ville.');
});
