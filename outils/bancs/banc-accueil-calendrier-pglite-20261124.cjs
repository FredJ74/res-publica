'use strict';
// Purge A.2 et A.3 (Fred, 24/11/2026) dans un vrai PostgreSQL local (PGlite) : bienvenue à la première connexion d'un
// nouveau personnage (une fois, mémorisée), temps de jeu cumulé tenu par le serveur (battement de présence), interview
// tirée entre 5 et 10 minutes, repoussée par une conversation avec un PNJ, forcée à 30 minutes, fin de la première heure.
// Rejoue l'arrivée de « Bernard » : rien avant 5 minutes, interview repoussée puis forcée, première heure signalée.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-accueil-calendrier-pglite-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const M = ['migrations/20261123140000_accueil_interview.sql', 'migrations/20261124101000_accueil_bienvenue.sql', 'migrations/20261124102000_accueil_calendrier.sql',
  'migrations/20261124104000_accueil_question.sql', 'migrations/20261124105000_notifications_chat.sql'];

test('les migrations ne touchent ni au goulag ni aux données des joueurs', () => {
  for (const f of M.slice(1)) {
    const m = lire(f).replace(/^--.*$/gm, '');
    assert.doesNotMatch(m, /goulag/i, f);
    assert.doesNotMatch(m, /UPDATE public\.personnages_donnees|DELETE FROM public\.accueil_personnages/, f);
  }
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = { bernard: '00000000-0000-0000-0000-000000000001', vieux: '00000000-0000-0000-0000-000000000002' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/accueil-interview-pglite-socle.sql.txt'));
  await db.exec(`
    ALTER TABLE personnages_donnees ADD COLUMN current_city text, ADD COLUMN created_at timestamp DEFAULT now();
    CREATE TABLE presences (name text PRIMARY KEY, country text, city text, building_id text, room_id text, updated_at timestamptz);
    GRANT SELECT, INSERT, UPDATE ON presences TO authenticated;
    INSERT INTO personnages (name, user_id, country) VALUES ('Vieux', '${U.vieux}', 'republic');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at) VALUES ('Vieux', '${U.vieux}', 'republic', 10, 'capitale', now() - interval '3 days');`);
  for (const f of M) await db.exec(lire(f));
  // Le nouveau venu est créé APRÈS la mise en ligne (rerolls compris).
  await db.exec(`INSERT INTO personnages (name, user_id, country) VALUES ('Bernard', '${U.bernard}', 'soviet');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at) VALUES ('Bernard', '${U.bernard}', 'soviet', 10, 'ville_b', now() + interval '1 second');`);
  return db;
}
async function comme(db, uid, sql) {
  await db.exec(`SET test.uid = '${uid}'; SET ROLE authenticated;`);
  try { return (await db.query(sql)).rows; } finally { await db.exec('RESET ROLE; RESET test.uid;'); }
}
const rpc = async (db, uid, fn) => (await comme(db, uid, `SELECT public.${fn}() r`))[0].r;
// Un battement de présence après « secondes » de jeu continu (le serveur ne crédite que le temps écoulé, borné à 60 s).
async function jouer(db, uid, nom, secondes) {
  for (let t = 0; t < secondes; t += 30) {
    await db.query(`UPDATE accueil_personnages SET battement_le = now() - interval '30 seconds' WHERE personnage = $1 AND battement_le IS NOT NULL`, [nom]);
    await comme(db, uid, `INSERT INTO presences (name, country, city) VALUES ('${nom}', 'soviet', 'ville_b')
      ON CONFLICT (name) DO UPDATE SET updated_at = now()`);
  }
}
const ligne = async (db, nom) => (await db.query('SELECT * FROM accueil_personnages WHERE personnage = $1', [nom])).rows[0];
const evts = async (db, nom, cle) => (await db.query('SELECT count(*)::int n FROM personnage_evenements WHERE destinataire = $1 AND cle = $2', [nom, cle])).rows[0].n;

test('A.2 : bienvenue une seule fois pour le nouveau venu (ville et pays de départ) ; rien pour un ancien ; rejouable', async () => {
  const db = await base();
  for (const f of M.slice(1)) await db.exec(lire(f));
  let e = await rpc(db, U.bernard, 'accueil_etat');
  assert.deepEqual([e.bienvenue.a_voir, e.bienvenue.pays, e.bienvenue.ville, e.bienvenue.signataire], [true, 'soviet', 'ville_b', null]);
  assert.equal(e.interview.ouvrir_auto, false, 'plus d’interview à la connexion');
  await rpc(db, U.bernard, 'accueil_bienvenue_vue');
  e = await rpc(db, U.bernard, 'accueil_etat');
  assert.equal(e.bienvenue.a_voir, false);
  const v = await rpc(db, U.vieux, 'accueil_etat');
  assert.equal(v.bienvenue.a_voir, false, 'personnage d’avant la mise en ligne : pas de bienvenue');
  assert.equal(v.interview.ouvrir_auto, true, 'ancien accueil inchangé');
  assert.equal(v.calendrier.actif, false);
});

test('A.3 : banc de l’arrivée de Bernard — rien avant 5 min, interview repoussée par un PNJ puis forcée à 30 min, heure finie', async () => {
  const db = await base();
  await rpc(db, U.bernard, 'accueil_etat');
  await db.query("UPDATE accueil_personnages SET interview_a = 420 WHERE personnage = 'Bernard'");   // tirage fixé : 7 min
  await jouer(db, U.bernard, 'Bernard', 270);
  let r = await ligne(db, 'Bernard');
  assert.ok(r.secondes_jeu >= 240 && r.secondes_jeu < 300, 'temps cumulé ' + r.secondes_jeu);
  assert.equal(r.interview_due_le, null, 'rien avant 5 minutes');
  // Déconnexion de 10 minutes : le temps ne compte pas, la partie reprend où elle était.
  await db.query("UPDATE accueil_personnages SET battement_le = now() - interval '10 minutes' WHERE personnage = 'Bernard'");
  await comme(db, U.bernard, "UPDATE presences SET updated_at = now() WHERE name = 'Bernard'");
  assert.equal((await ligne(db, 'Bernard')).secondes_jeu, r.secondes_jeu, 'trou de connexion non crédité');
  // Parle à un PNJ peu avant le moment prévu : report de 5 minutes, puis encore, jusqu'à 30 minutes.
  for (let i = 0; i < 6; i++) {
    await rpc(db, U.bernard, 'accueil_pnj_parle');
    await jouer(db, U.bernard, 'Bernard', 150);
    const x = await ligne(db, 'Bernard');
    if (x.secondes_jeu < 1800) assert.equal(x.interview_due_le, null, 'repoussée à ' + x.secondes_jeu + ' s (prévue ' + x.interview_a + ')');
  }
  while ((await ligne(db, 'Bernard')).secondes_jeu < 1800) { await rpc(db, U.bernard, 'accueil_pnj_parle'); await jouer(db, U.bernard, 'Bernard', 60); }
  await jouer(db, U.bernard, 'Bernard', 30);
  r = await ligne(db, 'Bernard');
  assert.ok(r.interview_due_le, 'forcée à 30 minutes malgré la conversation');
  assert.equal(await evts(db, 'Bernard', 'accueil_interview'), 1);
  let e = await rpc(db, U.bernard, 'accueil_etat');
  assert.equal(e.interview.ouvrir_auto, true);
  assert.equal(e.calendrier.premiere_heure, true, 'toujours la première heure');
  await jouer(db, U.bernard, 'Bernard', 1830);
  e = await rpc(db, U.bernard, 'accueil_etat');
  assert.equal(e.calendrier.premiere_heure, false);
  assert.equal(await evts(db, 'Bernard', 'accueil_heure_finie'), 1);
  assert.equal(e.calendrier.secondes_jeu, 3600, 'compteur arrêté à une heure');
});

test('A.3 : sans conversation, interview due entre 5 et 10 minutes ; le moment est tiré une fois ; un autre ne crédite pas', async () => {
  const db = await base();
  await rpc(db, U.bernard, 'accueil_etat');
  await jouer(db, U.bernard, 'Bernard', 60);
  const a = (await ligne(db, 'Bernard')).interview_a;
  assert.ok(a >= 300 && a <= 600, 'tirage ' + a);
  await jouer(db, U.bernard, 'Bernard', 660);
  const r = await ligne(db, 'Bernard');
  assert.equal(r.interview_a, a, 'tiré une seule fois');
  assert.ok(r.interview_due_le);
  // Le battement d'un autre compte n'avance pas le temps de Bernard (règle d'écriture : soi seul ; déclencheur : soi seul).
  const avant = r.secondes_jeu;
  await db.query("UPDATE accueil_personnages SET battement_le = now() - interval '30 seconds' WHERE personnage = 'Bernard'");
  await comme(db, U.vieux, "INSERT INTO presences (name) VALUES ('Bernard') ON CONFLICT (name) DO UPDATE SET updated_at = now()");
  assert.equal((await ligne(db, 'Bernard')).secondes_jeu, avant);
  // Le navigateur ne peut ni lire ni écrire l'état, ni créditer lui-même.
  await assert.rejects(comme(db, U.bernard, "UPDATE accueil_personnages SET secondes_jeu = 3600"));
  await assert.rejects(comme(db, U.bernard, "SELECT public.accueil_temps_crediter_interne('Bernard')"));
});

test('A.5 : la journaliste demande ce que le nouveau veut être, dit qu’il a le temps ; six chemins ; fermée sans réponse = reprenable', async () => {
  const db = await base();
  const e = await rpc(db, U.bernard, 'accueil_etat');
  assert.match(e.interview.question, /ce que vous voulez être/);
  assert.match(e.interview.question, /Si vous ne le savez pas encore, c'est normal : vous avez tout le temps de vous décider\./);
  assert.equal(e.interview.journaliste, 'Vera Pravdina');
  assert.deepEqual(e.chemins.map(c => c.id), ['politique', 'affaires', 'influence', 'crime', 'uniforme', 'belle_vie']);
  const v = await rpc(db, U.vieux, 'accueil_etat');
  assert.match(v.interview.question, /que voulez-vous être, ici \?/);
  // Fermée sans réponse (ouverture notée) : toujours « a_faire », donc dans Mes objectifs.
  await rpc(db, U.bernard, 'accueil_interview_vue');
  assert.equal((await rpc(db, U.bernard, 'accueil_etat')).interview.etat, 'a_faire');
});

test('A.8 : proposition des notifications jamais pendant la première heure ; réglage gardé au serveur', async () => {
  const db = await base();
  await rpc(db, U.bernard, 'accueil_etat');
  let n = await rpc(db, U.bernard, 'notifications_chat_lire');
  assert.deepEqual([n.active, n.proposee, n.a_proposer, n.premiere_heure], [false, false, false, true]);
  await jouer(db, U.bernard, 'Bernard', 3630);
  n = await rpc(db, U.bernard, 'notifications_chat_lire');
  assert.equal(n.a_proposer, true, 'après la première heure');
  n = (await comme(db, U.bernard, 'SELECT public.notifications_chat_fixer(true) r'))[0].r;
  assert.deepEqual([n.active, n.proposee, n.a_proposer], [true, true, false]);
  n = (await comme(db, U.bernard, 'SELECT public.notifications_chat_fixer(false) r'))[0].r;
  assert.equal(n.active, false);
  assert.equal((await rpc(db, U.vieux, 'notifications_chat_lire')).a_proposer, true, 'ancien joueur : proposée au premier message');
  await assert.rejects(comme(db, U.bernard, 'SELECT * FROM notifications_chat'));
});
