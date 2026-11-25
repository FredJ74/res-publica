'use strict';
// Mission de nuit du 25/11/2026, bloc 2 : le temps de jeu du calendrier d'accueil compte la présence réelle.
// Cas d'origine : Han Watta Tsé (téléphone Android), 49 minutes de présence, 484 s créditées : la page, masquée par
// l'écran verrouillé, n'envoyait plus de battement, et le premier battement du retour trouvait un trou de plus de 120 s.
// Ce banc simule 50 minutes de présence réelle sur téléphone (10 min de jeu, 35 min d'écran verrouillé, 5 min de jeu)
// dans un vrai PostgreSQL local (PGlite) : avant la migration 20261125110000, environ 15 min ; après, 50 min.
// Une vraie déconnexion (pas de reprise de la page) et une absence de plus d'une heure ne comptent toujours pas.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-accueil-temps-reel-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const M = ['migrations/20261123140000_accueil_interview.sql', 'migrations/20261124101000_accueil_bienvenue.sql', 'migrations/20261124102000_accueil_calendrier.sql',
  'migrations/20261124104000_accueil_question.sql', 'migrations/20261124105000_notifications_chat.sql'];
const CORRECTIF = 'migrations/20261125110000_accueil_temps_page_ouverte.sql';

test('écran : la page revenue au premier plan appelle accueil_reprise, seulement pendant la première heure du calendrier', () => {
  const src = lire('plateau-accueil-progressif.js');
  assert.match(src, /if \(ms > 0 && calendrierActif\(\) && premiereHeure\(\)\) rpc\('accueil_reprise', \{ p_masque_s: Math\.round\(ms \/ 1000\) \}\);/);
  assert.match(src, /addEventListener\('visibilitychange', \(\) => \{ if \(doc\.hidden\) masqueeDepuis = Date\.now\(\); else signalerReprise\(\); \}\)/);
  assert.match(src, /addEventListener\('pageshow', e => \{ if \(e && e\.persisted\) signalerReprise\(\); \}\)/);
  // Repli sans la migration : rpc() avale l'échec (aucun message au joueur).
  assert.match(src, /function rpc\(fn, args\) \{[\s\S]{0,200}\.catch\(\(\) => null\)/);
});

test('la migration ne touche ni au goulag ni aux données des joueurs, et ne rattrape rien', () => {
  const m = lire(CORRECTIF).replace(/^--.*$/gm, '').replace(/\$function\$[\s\S]*?\$function\$/g, '');
  assert.doesNotMatch(m, /goulag/i);
  assert.doesNotMatch(m, /UPDATE public\.(personnages_donnees|accueil_personnages)|DELETE FROM/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté avec PGLITE_DIR', { skip: true }, () => {}); return; }

const HAN = '00000000-0000-0000-0000-000000000003';
async function base(avecCorrectif) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/accueil-interview-pglite-socle.sql.txt'));
  await db.exec(`
    ALTER TABLE personnages_donnees ADD COLUMN current_city text, ADD COLUMN created_at timestamp DEFAULT now();
    CREATE TABLE presences (name text PRIMARY KEY, country text, city text, building_id text, room_id text, updated_at timestamptz);
    GRANT SELECT, INSERT, UPDATE ON presences TO authenticated;`);
  for (const f of M) await db.exec(lire(f));
  if (avecCorrectif) await db.exec(lire(CORRECTIF));
  await db.exec(`INSERT INTO personnages (name, user_id, country) VALUES ('Han', '${HAN}', 'soviet');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at) VALUES ('Han', '${HAN}', 'soviet', 10, 'ville_b', now() + interval '1 second');`);
  await comme(db, 'SELECT public.accueil_etat()');
  await db.query("UPDATE accueil_personnages SET interview_a = 342 WHERE personnage = 'Han'");
  return db;
}
async function comme(db, sql) {
  await db.exec(`SET test.uid = '${HAN}'; SET ROLE authenticated;`);
  try { return (await db.query(sql)).rows; } finally { await db.exec('RESET ROLE; RESET test.uid;'); }
}
const battement = db => comme(db, "INSERT INTO presences (name, country, city) VALUES ('Han', 'soviet', 'ville_b') ON CONFLICT (name) DO UPDATE SET updated_at = now()");
// Le temps passe pour tout : dernier battement et absence mise de côté reculent ensemble.
const reculer = async (db, s) => {
  await db.query(`UPDATE accueil_personnages SET battement_le = battement_le - make_interval(secs => ${s}) WHERE personnage = 'Han' AND battement_le IS NOT NULL`);
  try { await db.query(`UPDATE accueil_personnages SET absence_le = absence_le - make_interval(secs => ${s}) WHERE personnage = 'Han' AND absence_le IS NOT NULL`); } catch (_) {}
};
const remettre = db => db.query(`UPDATE accueil_personnages SET battement_le = now() WHERE personnage = 'Han' AND battement_le IS NOT NULL`);
// Page visible : un battement toutes les 30 s.
async function jouer(db, secondes) { for (let t = 0; t < secondes; t += 30) { await remettre(db); await reculer(db, 30); await battement(db); } }
// Écran verrouillé : rien n'est envoyé pendant « secondes ».
const verrouiller = (db, secondes) => reculer(db, secondes);
const reprise = async (db, masque) => { try { return (await comme(db, `SELECT public.accueil_reprise(${masque | 0}) r`))[0].r; } catch (_) { return null; } };
const secondes = async db => (await db.query("SELECT secondes_jeu FROM accueil_personnages WHERE personnage = 'Han'")).rows[0].secondes_jeu;

test('constat sans le correctif : 50 minutes de présence sur téléphone, environ 15 minutes créditées', async () => {
  const db = await base(false);
  await jouer(db, 600); await verrouiller(db, 2100); assert.equal(await reprise(db, 2100), null, 'accueil_reprise absente : repli silencieux');
  await battement(db); await jouer(db, 300);
  const s = await secondes(db);
  assert.ok(s >= 840 && s <= 960, 'sous-compte reproduit : ' + s + ' s');
});

test('avec le correctif : 50 minutes de présence réelle comptent 50 minutes (reprise avant le battement du retour)', async () => {
  const db = await base(true);
  await battement(db);                                  // premier battement de la page
  await jouer(db, 600);
  await verrouiller(db, 2100);                          // 35 minutes d'écran verrouillé
  assert.deepEqual(await reprise(db, 2100), { ok: true });   // la page revient au premier plan
  await jouer(db, 300);
  const s = await secondes(db);
  assert.ok(s >= 2970 && s <= 3030, '50 minutes attendues : ' + s + ' s');
  const r = (await db.query("SELECT interview_due_le, decouverte_le, heure_finie_le FROM accueil_personnages WHERE personnage = 'Han'")).rows[0];
  assert.ok(r.interview_due_le && r.decouverte_le, 'découverte finie et interview due');
  assert.equal(r.heure_finie_le, null, 'toujours la première heure');
});

test('avec le correctif : le battement du retour arrive avant la reprise ; l’absence est créditée une seule fois', async () => {
  const db = await base(true);
  await battement(db); await jouer(db, 600);
  await verrouiller(db, 2100);
  await battement(db);                                  // le minuteur de 30 s part avant l'événement de visibilité
  const avant = await secondes(db);
  await reprise(db, 2100);
  const apres = await secondes(db);
  assert.ok(apres - avant >= 2100 && apres - avant <= 2101, 'absence créditée : ' + (apres - avant));
  await reprise(db, 5);                                 // deuxième retour sans nouvelle absence : rien de plus
  assert.ok((await secondes(db)) - apres <= 1);
});

test('avec le correctif : une vraie déconnexion et une absence de plus d’une heure ne comptent pas ; l’heure plafonne', async () => {
  const db = await base(true);
  await battement(db); await jouer(db, 300);
  const s0 = await secondes(db);
  await verrouiller(db, 1800); await battement(db);     // onglet fermé puis nouvelle page : aucune reprise
  assert.equal(await secondes(db), s0, 'déconnexion non comptée');
  await reprise(db, 20);                                // la nouvelle page passe 20 s en arrière-plan : seulement ces 20 s
  const s1 = await secondes(db);
  assert.ok(s1 - s0 <= 20, 'l’ancienne absence n’est pas créditée à la nouvelle page : ' + (s1 - s0));
  await verrouiller(db, 3700); await reprise(db, 3700); // page ouverte mais oubliée plus d'une heure
  assert.equal(await secondes(db), s1, 'absence de plus d’une heure non comptée');
  await verrouiller(db, 3500); await reprise(db, 3500); // près d'une heure : comptée, compteur plafonné à 3600
  assert.equal(await secondes(db), 3600);
  // Le navigateur ne peut pas appeler la fonction interne.
  await assert.rejects(comme(db, "SELECT public.accueil_temps_crediter_interne('Han', true)"));
});
