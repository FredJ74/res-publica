'use strict';
// Interview d'accueil (Fred, 21/11/2026, point 2), migration 20261122150000, dans un vrai PostgreSQL local (PGlite) :
// avant, un joueur pouvait s'écrire une invitation « de Jodie Moitout » (droit autorise_soi) ; après, seul le
// serveur (compte de service) écrit au nom de Jodie et des autres journalistes d'antenne. Rejouable.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --experimental-vm-modules outils/bancs/banc-interview-accueil-pglite-20261122.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }
const MIGRATION = 'migrations/20261122150000_interview_accueil_invitation_serveur.sql';
const INVITE = "Un portrait pour L'Autruche Entravée ?";
const JOURNALISTES = ['Jodie Moitout', 'Annie Houininon', 'Arthur Lutte', 'Zoïa Glazounova', 'Saran Batbayar', 'Anatoli Kolosov'];

async function base(migrer) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/interview-accueil-pglite-socle.sql.txt'));
  if (migrer) await db.exec(lire(MIGRATION));
  return db;
}
// Écriture « navigateur » : rôle authenticated, personnage Tom Tom, politique RLS mails_envoi.
async function commeJoueur(db, fn) {
  await db.exec("SET test.perso = 'Tom Tom'; SET ROLE authenticated;");
  try { return await fn(); } finally { await db.exec('RESET ROLE; RESET test.perso;'); }
}
const inserer = (db, de) => db.query('INSERT INTO mails (id, from_player, to_player, subject, body) VALUES ($1, $2, $3, $4, $5)',
  ['m-' + Math.random(), de, 'Tom Tom', INVITE, 'faux']).then(() => true, () => false);

test('avant la migration : le navigateur peut se fabriquer une invitation de Jodie (la faille que fermait le verrou du premier jour)', async () => {
  const db = await base(false);
  assert.equal(await commeJoueur(db, () => inserer(db, 'Jodie Moitout')), true);
});

test('après la migration : plus aucune invitation fabriquée par le navigateur, au nom d’aucun journaliste ; le serveur écrit toujours', async () => {
  const db = await base(true);
  for (const j of JOURNALISTES) {
    assert.equal(await commeJoueur(db, () => inserer(db, j)), false, j + ' : écriture navigateur refusée');
    const rpc = await commeJoueur(db, () => db.query('SELECT mail_systeme_envoyer($1, $2, $3, $4) r', [j, 'Tom Tom', INVITE, 'x']));
    assert.equal(rpc.rows[0].r.raison, 'expediteur_non_autorise', j + ' : RPC navigateur refusée');
  }
  // Appel serveur (compte de service = session postgres ici) : l'invitation part.
  const r = (await db.query('SELECT mail_systeme_envoyer($1, $2, $3, $4, $5) r', ['Anatoli Kolosov', 'Tom Tom', 'Un portrait pour La Voix de Sovarka ?', 'corps', '21/11 13h'])).rows[0].r;
  assert.equal(r.ok, true);
  const m = (await db.query('SELECT from_player, to_player, subject, time FROM mails WHERE id = $1', [r.id])).rows[0];
  assert.deepEqual(m, { from_player: 'Anatoli Kolosov', to_player: 'Tom Tom', subject: 'Un portrait pour La Voix de Sovarka ?', time: '21/11 13h' });
  // Le joueur lit bien son courrier (lecture inchangée).
  const lus = await commeJoueur(db, () => db.query('SELECT count(*)::int n FROM mails'));
  assert.equal(lus.rows[0].n, 1);
});

test('rien d’autre ne change : les autres identités gardent leurs droits ; migration rejouable', async () => {
  const db = await base(true);
  await db.exec(lire(MIGRATION));
  const c = (await db.query("SELECT autorise_soi FROM mails_expediteurs_systeme WHERE expediteur = 'Commissariat'")).rows[0];
  assert.equal(c.autorise_soi, true);
  const j = (await db.query("SELECT count(*)::int n FROM mails_expediteurs_systeme WHERE expediteur = 'Jodie Moitout'")).rows[0];
  assert.equal(j.n, 1, 'Jodie reste déclarée (nom connu, jamais « inventé »)');
  await commeJoueur(db, async () => {
    assert.equal(await db.query("INSERT INTO mails (id, from_player, to_player, subject) VALUES ('a', 'Commissariat', 'Tom Tom', 'avis')").then(() => true, () => false), true);
  });
});

async function publier(db, auteur, pays, id) {
  await db.query("INSERT INTO forum_topics VALUES ($1, 'presse', $2, $3, $4)", [id, 'Un jour, un portrait : PJ ' + id, auteur, pays]);
  await db.query('INSERT INTO forum_posts VALUES ($1, $2, $3, $4)', ['p-' + id, id, auteur, 'Un portrait fidèle aux réponses, assez long pour le journal.']);
  return (await db.query('SELECT country, origine FROM journal_articles_en_attente WHERE id = $1', ['jodie-portrait-' + id])).rows[0] || null;
}
test('journal : les portraits signés par un journaliste d’antenne y entrent (avant : Jodie seule) ; un autre auteur, jamais', async () => {
  const avant = await base(false);
  assert.equal(await publier(avant, 'Anatoli Kolosov', 'soviet', 't1'), null, 'avant : portrait de Krasnov perdu pour le journal');
  const db = await base(true);
  assert.deepEqual(await publier(db, 'Jodie Moitout', 'republic', 't0'), { country: 'republic', origine: 'portrait_jodie' }, 'Jodie inchangée');
  assert.deepEqual(await publier(db, 'Anatoli Kolosov', 'soviet', 't1'), { country: 'soviet', origine: 'portrait_jodie' });
  assert.deepEqual(await publier(db, 'Zoïa Glazounova', 'soviet', 't2'), { country: 'soviet', origine: 'portrait_jodie' });
  assert.equal(await publier(db, 'Tom Tom', 'soviet', 't3'), null);
});
