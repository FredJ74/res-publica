'use strict';
// Règles d'accès des forums (Fred, 24/11/2026, mission Purge B.1 ; GAME-DESIGN-FORUMS.md) : migration
// 20261124110000_forums_acces_purge dans un vrai PostgreSQL local (PGlite), sur les définitions de production recopiées
// (fixtures/forums-acces-pglite-socle.sql.txt). Chaque épreuve montre aussi le défaut AVANT la migration.
//  - Bernard (Sovarka, chez lui) ne lit plus la Présidence, le Gouvernement ni la Presse de Républia ;
//  - à l'étranger : forum national et sous-forums du pays visité en lecture seule ; ceux de son pays en écriture ;
//  - forum local de la ville de domicile toujours accessible (même domicile hors de son pays) ; ville visitée en écriture ;
//  - la publication serveur (forum_publication_jauges_interne) suit les mêmes règles ; migration rejouable.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261124110000_forums_acces_purge.sql';
async function base({ migrer = true, deuxFois = false } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/forums-acces-pglite-socle.sql.txt'));
  await db.exec(`
    INSERT INTO personnages_donnees (name, country, current_city, nationalite, domicile, career) VALUES
      ('Bernard', 'soviet', 'capitale', 'soviet', '{"country":"soviet","city":"ville_b"}', NULL),
      ('Tom', 'soviet', 'ville_b', 'republic', '{"country":"republic","city":"capitale"}', 'press'),
      ('Ana', 'republic', 'capitale', 'republic', '{"country":"soviet","city":"ville_a"}', NULL);
    INSERT INTO forum_topics (id, forum_id, title, author, country, time, views, replies) VALUES
      ('t-presse-rep', 'presse', 'Presse de Républia', 'X', 'republic', '01/11/2026 10:00', 1, 0),
      ('t-local-staro', 'local_ville_a', 'Starovka', 'Y', 'soviet', '01/11/2026 10:00', 1, 0);`);
  if (migrer) { await db.exec(lire(MIGRATION)); if (deuxFois) await db.exec(lire(MIGRATION)); }
  return db;
}
async function en(db, nom) { await db.query("SELECT set_config('rp.moi', $1, false)", [nom]); }
async function lit(db, forum, pays) { return (await db.query('SELECT forum_lecture_autorisee($1,$2) AS v', [forum, pays])).rows[0].v; }
async function ecrit(db, forum, pays) { return (await db.query('SELECT forum_ecriture_autorisee($1,$2) AS v', [forum, pays])).rows[0].v; }
async function publier(db, nom, message) {
  return (await db.query("SELECT forum_publication_jauges_interne($1, gen_random_uuid(), $2::jsonb) AS r", [nom, JSON.stringify(message)])).rows[0].r;
}

test('Bernard (Sovarka) : plus aucun sous-forum national de Républia — défaut montré avant', async () => {
  const avant = await base({ migrer: false });
  await en(avant, 'Bernard');
  assert.equal(await lit(avant, 'presse', 'republic'), true, 'défaut de production reproduit');
  assert.equal(await lit(avant, 'presidence', 'republic'), true);
  const db = await base();
  await en(db, 'Bernard');
  for (const f of ['national', 'presidence', 'assemblee', 'gouvernement', 'presse']) {
    assert.equal(await lit(db, f, 'republic'), false, f + ' de Républia');
    assert.equal(await lit(db, f, 'soviet'), true, f + ' de Sovarka');
    assert.equal(await ecrit(db, f, 'soviet'), true, f + ' de Sovarka en écriture');
  }
  assert.equal(await lit(db, 'local_ville_b', 'soviet'), true, 'Krasnov, ville de domicile');
  assert.equal(await lit(db, 'local_capitale', 'soviet'), true, 'Novomirsk, ville où il se trouve');
  assert.equal(await lit(db, 'local_ville_b', 'republic'), false, 'Montrouge (même identifiant de ville) : jamais');
  assert.equal(await lit(db, 'international', 'republic'), true, 'international inchangé');
});

test('à l’étranger : national et sous-forums visités en lecture seule ; son pays en écriture ; locaux', async () => {
  const db = await base();
  await en(db, 'Tom');   // Républia, en visite à Krasnov, domicilié à Luthécia
  for (const f of ['national', 'presse', 'presidence']) {
    assert.equal(await lit(db, f, 'soviet'), true, f + ' visité : lecture');
    assert.equal(await ecrit(db, f, 'soviet'), false, f + ' visité : pas d’écriture');
    assert.equal(await ecrit(db, f, 'republic'), true, f + ' de son pays : écriture depuis l’étranger');
  }
  assert.equal(await ecrit(db, 'local_ville_b', 'soviet'), true, 'Krasnov, ville visitée : écriture');
  assert.equal(await ecrit(db, 'local_capitale', 'republic'), true, 'Luthécia, ville de domicile : écriture depuis l’étranger');
  assert.equal(await lit(db, 'local_ville_b', 'republic'), false, 'Montrouge : ni domicile ni visitée');
  assert.equal(await lit(db, 'local_capitale', 'soviet'), false, 'Novomirsk : pas visitée');
});

test('domicile hors de son pays : le forum local de cette ville reste accessible — défaut montré avant', async () => {
  const avant = await base({ migrer: false });
  await en(avant, 'Ana');
  assert.equal(await lit(avant, 'local_ville_a', 'soviet'), false, 'défaut reproduit');
  assert.equal((await publier(avant, 'Ana', { topic: 't-local-staro', contenu: 'Bonjour' })).raison, 'territoire_invalide');
  const db = await base();
  await en(db, 'Ana');
  assert.equal(await ecrit(db, 'local_ville_a', 'soviet'), true);
  assert.equal((await publier(db, 'Ana', { topic: 't-local-staro', contenu: 'Bonjour' })).ok, true, 'réponse depuis Luthécia');
});

test('publication serveur : le pays d’un sujet de sous-forum national suit le pays affiché ; refus nommés', async () => {
  const avant = await base({ migrer: false });
  await en(avant, 'Tom');
  const rA = await publier(avant, 'Tom', { forum: 'presse', titre: 'Article', contenu: 'Texte', pays: 'republic' });
  assert.equal(rA.ok, true);
  assert.equal((await avant.query('SELECT country FROM forum_topics WHERE id=$1', [rA.topic])).rows[0].country, 'soviet', 'défaut : rangé chez le pays visité');
  const db = await base({ deuxFois: true });
  await en(db, 'Tom');
  const r = await publier(db, 'Tom', { forum: 'presse', titre: 'Article', contenu: 'Texte', pays: 'republic' });
  assert.equal(r.ok, true, JSON.stringify(r));
  assert.equal((await db.query('SELECT country FROM forum_topics WHERE id=$1', [r.topic])).rows[0].country, 'republic');
  assert.equal((await publier(db, 'Tom', { forum: 'presse', titre: 'Article', contenu: 'Texte', pays: 'soviet' })).raison, 'forum_inaccessible', 'presse visitée : lecture seule');
  assert.equal((await publier(db, 'Tom', { forum: 'national', titre: 'Salut', contenu: 'Texte', pays: 'soviet' })).raison, 'forum_inaccessible');
  assert.equal((await publier(db, 'Tom', { forum: 'local_ville_b', titre: 'Salut', contenu: 'Texte', pays: 'soviet' })).ok, true, 'ville visitée');
  await en(db, 'Bernard');
  assert.equal((await publier(db, 'Bernard', { topic: 't-presse-rep', contenu: 'Hop' })).ok, false, 'Bernard ne répond pas à la presse de Républia');
  const d = (await db.query("SELECT pg_get_functiondef('forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure) d")).rows[0].d;
  assert.equal(d.split('purge_b1').length - 1, 3, 'remplacements appliqués une seule fois (migration rejouée)');
});
