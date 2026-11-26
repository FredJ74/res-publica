'use strict';
// Mission de fin de soirée du 25/11/2026, point 1.5 (décision de Fred) : le ticket du cinéma de Montrouge se vend au cinéma,
// auprès d'une caissière visible sur l'image du hall (le PNJ suit l'image). Simone Aiguillard : placée au hall, portrait
// recadré de cette image, fiche DeepSeek ; migration 20261125850000 (miroir serveur du casting et lieu de vente du ticket).
// Le jeu ne dit jamais où trouver un souvenir : ni la fiche, ni data.js ne parlent du ticket.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-cinema-caissiere-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125850000_cinema_montrouge_caissiere.sql';

test('Simone Aiguillard : au hall du cinéma de Montrouge, portrait recadré, fiche DeepSeek, scène', async () => {
  const ctx = vm.createContext({ console, state: { country: 'republic', currentCity: 'ville_b' } });
  vm.runInContext(lire('data.js'), ctx);
  const hall = vm.runInContext("BUILDINGS['cinema-montrouge'].rooms.salle", ctx);
  assert.equal(hall.imageUrl, 'images/montrouge/montrouge-cinema-accueil.jpg', 'le PNJ suit l’image du hall (caissière au guichet)');
  assert.equal(hall.persons.length, 1);
  const c = hall.persons[0];
  assert.equal(c.name, 'Simone Aiguillard (PNJ)'); assert.equal(c.profilId, 'simone_aiguillard'); assert.equal(c.job, 'commercant');
  assert.ok(fs.existsSync(path.join(root, c.photoUrl)), 'portrait présent'); assert.doesNotMatch(c.photoUrl, /[^A-Za-z0-9_./-]/);
  assert.ok(vm.runInContext("WORLD.republic.ville_b.buildings.includes('cinema-montrouge')", ctx));
  const { profilsPersonnalites } = await import(path.join(root, 'api/_pnj-personnalites.js'));
  const f = profilsPersonnalites().simone_aiguillard;
  assert.ok(f, 'fiche'); assert.equal(f.nom, 'Simone Aiguillard');
  const tout = JSON.stringify(f);
  assert.match(tout, /Montrouge/); assert.match(tout, /caisse/i);
  // « souvenir partagé avec le joueur » (règle commune PAS_INVENTER) n'est pas un objet souvenir : on l'écarte avant le contrôle.
  assert.doesNotMatch(tout.replace(/ni souvenir partagé avec le joueur/g, ''), /souvenir|ticket/i, 'la fiche ne révèle pas où trouver un souvenir');
  assert.match(lire('api/_pnj-scenes-generes.js'), /"piece": "Hall",\n    "personnes": \[\n      "Simone Aiguillard"\n    \]/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

test('migration : la caissière au miroir du casting, le ticket vendu au guichet du cinéma ; rejouable', async () => {
  const db = new PGlite();
  await db.exec(`
    CREATE TABLE pnj_lieux_metiers (pays text NOT NULL, ville text NOT NULL, building_id text NOT NULL, room_id text NOT NULL, nom text NOT NULL,
      job text NOT NULL DEFAULT 'default', rel text NOT NULL DEFAULT 'neutral', PRIMARY KEY (pays, ville, building_id, room_id, nom));
    CREATE TABLE souvenirs_objets (cle text PRIMARY KEY, nom text, ville_nom text, pays text, ville text, batiment text, piece text, pnj text, prix numeric, achetable boolean);
    INSERT INTO souvenirs_objets VALUES ('souv_montrouge_ticket_cinema', 'Ticket du cinéma de Montrouge', 'Montrouge', 'republic', 'ville_b', 'marche', 'marche_ext', 'Josette Betterave', 10, true),
      ('souv_psm_mug', 'Mug', 'Port-Sainte-Marie', 'republic', 'ville_a', 'marche-psm', 'etals', 'Bastien Leroux', 20, true);`);
  await db.exec(lire(MIG));
  await db.exec(lire(MIG));
  assert.deepEqual((await db.query("SELECT nom, job, rel FROM pnj_lieux_metiers WHERE building_id = 'cinema-montrouge' AND room_id = 'salle'")).rows,
    [{ nom: 'Simone Aiguillard', job: 'commercant', rel: 'neutral' }]);
  assert.deepEqual((await db.query("SELECT batiment, piece, pnj, prix::int AS prix FROM souvenirs_objets WHERE cle = 'souv_montrouge_ticket_cinema'")).rows,
    [{ batiment: 'cinema-montrouge', piece: 'salle', pnj: 'Simone Aiguillard', prix: 10 }], 'même prix, nouveau lieu');
  assert.equal((await db.query("SELECT pnj FROM souvenirs_objets WHERE cle = 'souv_psm_mug'")).rows[0].pnj, 'Bastien Leroux', 'les autres souvenirs ne bougent pas');
});
