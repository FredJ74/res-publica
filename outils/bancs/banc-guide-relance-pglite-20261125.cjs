'use strict';
// Mission de jour du 25/11/2026, bloc 1.1 (réponses de Fred aux questions de la Purge) : PNJ guide.
// Goût = chemin de l'interview, sinon carrière ; relance de l'interview fermée sans réponse par la journaliste (au plus tôt
// le lendemain, une fois, vers « Mes objectifs ») ; « Ne plus me proposer d'interview d'accueil » coupe la relance pour de
// bon et ne touche à aucune autre interview. Migration 20261125140000 dans PGlite (socle du banc du 24/11).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-guide-relance-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const M = ['migrations/20261123140000_accueil_interview.sql', 'migrations/20261124100000_comptes_test.sql',
  'migrations/20261124101000_accueil_bienvenue.sql', 'migrations/20261124102000_accueil_calendrier.sql', 'migrations/20261124106000_pnj_guide.sql'];
const MIG = 'migrations/20261125140000_guide_gout_relance_interview.sql';

test('écran et API : boutons de la relance, refus serveur, relance publiée sans IA ; aucune autre interview touchée', () => {
  const js = lire('plateau-pnj-guide.js'), api = lire('api/_pnj-guide.js'), m = lire(MIG).replace(/^--.*$/gm, '');
  assert.match(js, /guide-relance-/);
  assert.match(js, /Ne plus me proposer d'interview d'accueil/);
  assert.match(js, /sbRpc|rpc\('accueil_interview_refuser'\)/);
  assert.match(js, /afficherObjectifsSecrets/);
  assert.match(api, /r\.publie === true/);
  assert.doesNotMatch(m, /journal_interview|interviews?_(elu|president)|forum_topics/i, 'seule l\'interview d\'accueil');
  assert.doesNotMatch(m, /goulag/i);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = { bernard: '00000000-0000-0000-0000-000000000001', tom: '00000000-0000-0000-0000-000000000002',
  ivan: '00000000-0000-0000-0000-000000000003', arnie: '00000000-0000-0000-0000-000000000004', olga: '00000000-0000-0000-0000-000000000005' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/accueil-interview-pglite-socle.sql.txt'));
  await db.exec(`
    ALTER TABLE personnages_donnees ADD COLUMN current_city text, ADD COLUMN created_at timestamptz DEFAULT now(),
      ADD COLUMN career text, ADD COLUMN archetype text, ADD COLUMN stats jsonb, ADD COLUMN poste jsonb, ADD COLUMN resources jsonb;
    CREATE TABLE presences (name text PRIMARY KEY, country text, city text, building_id text, room_id text, updated_at timestamptz DEFAULT now());
    CREATE TABLE pnj_referents (referent_id text PRIMARY KEY, domaine text, pays text);
    INSERT INTO pnj_referents VALUES ('kouzma_lapchine', 'religion — Eglise, Krasnov', 'soviet'),
      ('sayana_tsydypova', 'démarches municipales — mairie de Starovka', 'soviet'), ('nathalie_boulot', 'emploi — Bureau National de l''Emploi', 'republic');
    CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb);
    CREATE TABLE cycles_electoraux (id text PRIMARY KEY, country text, poste_id text, data text, city text);
    CREATE TABLE organisations (id text PRIMARY KEY, country_origine text, data text);
    INSERT INTO organisations VALUES ('p1', 'soviet', '{"type":"politique","nom":"Parti du Tracteur Rouge"}');
    INSERT INTO cycles_electoraux VALUES ('c1', 'soviet', 'maire', '{"phase":"campagne"}', 'ville_b');
    CREATE TABLE messages_chat (id text PRIMARY KEY, conversation_id text NOT NULL, auteur text NOT NULL, message text NOT NULL, salon boolean DEFAULT false, created_at timestamptz DEFAULT now());
    -- Commerces de joueurs : Olga (active), Arnie (compte de test), Ivan (inactif : absent depuis 5 jours), un sans stock.
    INSERT INTO personnages (name, user_id, country) VALUES ('Olga', '${U.olga}', 'republic'), ('Arnie', '${U.arnie}', 'republic'), ('Ivan', '${U.ivan}', 'republic');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at) VALUES ('Olga', '${U.olga}', 'republic', 10, 'capitale', now() - interval '30 days'),
      ('Arnie', '${U.arnie}', 'republic', 10, 'capitale', now() - interval '30 days'), ('Ivan', '${U.ivan}', 'republic', 10, 'capitale', now() - interval '30 days');
    INSERT INTO presences (name, updated_at) VALUES ('Olga', now() - interval '1 day'), ('Arnie', now()), ('Ivan', now() - interval '5 days');
    INSERT INTO entreprises VALUES
      ('f-olga', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Olga","enseigne":"La Bonne Table","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale","buildingId":"centre-commercial"},"stockReferences":{"r1":4}}'),
      ('f-olga2', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Olga","enseigne":"Le Comptoir","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale","buildingId":"centre-commercial"},"stockReferences":{}}'),
      ('f-arnie', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Arnie","enseigne":"Chez Toto","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale"},"stockReferences":{"r":9}}'),
      ('f-ivan', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Ivan","enseigne":"Le Samovar","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale"},"stockReferences":{"r":9}}');`);
  for (const f of M) await db.exec(lire(f));
  await db.exec(lire(MIG));
  // Jour de Paris piloté par le banc.
  await db.exec(`CREATE OR REPLACE FUNCTION public.guide_jour_interne() RETURNS date LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('test.jour', true), ''), '2026-12-01')::date $$;`);
  await db.exec(`INSERT INTO personnages (name, user_id, country) VALUES ('Bernard', '${U.bernard}', 'soviet'), ('Tom', '${U.tom}', 'republic');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at, career) VALUES
      ('Bernard', '${U.bernard}', 'soviet', 10, 'ville_b', now() + interval '1 second', 'worker'),
      ('Tom', '${U.tom}', 'republic', 10, 'capitale', now() + interval '1 second', 'business');`);
  return db;
}
async function comme(db, uid, sql) {
  await db.exec(`SET test.uid = '${uid}'; SET ROLE authenticated;`);
  try { return (await db.query(sql)).rows; } finally { await db.exec('RESET ROLE; RESET test.uid;'); }
}
const rpc = async (db, uid, appel) => (await comme(db, uid, `SELECT public.${appel} r`))[0].r;
const jour = (db, j) => db.exec(`SET test.jour = '${j}'`);
async function premiereHeureFinie(db, uid, nom) {
  await rpc(db, uid, 'accueil_etat()');
  await db.query("UPDATE accueil_personnages SET heure_finie_le = now(), secondes_jeu = 3600 WHERE personnage = $1", [nom]);
}
const publier = async (db, id) => (await db.query('SELECT public.guide_publier_service($1, $2) r', [id, 'Un conseil, une piste.'])).rows[0].r;


test('goût : le chemin de l’interview, sinon la carrière, sinon les pistes par défaut', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.tom, 'Tom');
  await premiereHeureFinie(db, U.bernard, 'Bernard');
  await jour(db, '2026-12-01');
  // Tom (affaires) n'a pas donné d'interview : sa carrière « business » donne le goût « affaires ».
  const t = await rpc(db, U.tom, 'guide_reserver()');
  assert.equal(t.piste.gout, 'affaires');
  assert.match(t.piste.cle, /^r_aff_/);
  // Bernard (ouvrier) : « politique » par la carrière.
  const b = await rpc(db, U.bernard, 'guide_reserver()');
  assert.equal(b.piste.gout, 'politique');
  // Un chemin choisi l'emporte sur la carrière.
  await db.exec("DELETE FROM guide_messages; UPDATE accueil_personnages SET chemin = 'belle_vie', chemin_choisi_le = '2026-11-30 10:00+01', etat_interview = 'faite' WHERE personnage = 'Tom'");
  assert.equal((await rpc(db, U.tom, 'guide_reserver()')).piste.gout, 'belle_vie');
  // Carrière inconnue de la table : pistes par défaut.
  await db.exec("DELETE FROM guide_messages; UPDATE personnages_donnees SET career = 'inconnue' WHERE name = 'Bernard'");
  assert.equal((await rpc(db, U.bernard, 'guide_reserver()')).piste.gout, 'defaut');
});

test('relance : interview fermée sans réponse → la journaliste écrit le lendemain, une fois, vers « Mes objectifs »', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.bernard, 'Bernard');
  // Fenêtre ouverte le 30/11, fermée sans réponse (toujours « à faire »).
  await db.exec("UPDATE accueil_personnages SET ouverte_auto_le = '2026-11-30 18:00+01', etat_interview = 'a_faire' WHERE personnage = 'Bernard'");
  await jour(db, '2026-11-30');
  const memeJour = await rpc(db, U.bernard, 'guide_reserver()');
  assert.notEqual(memeJour.relance, true, 'pas le jour même');
  await db.exec('DELETE FROM guide_messages');
  await jour(db, '2026-12-01');
  const r = await rpc(db, U.bernard, 'guide_reserver()');
  assert.deepEqual([r.ok, r.publie, r.relance, r.voix, r.pnj], [true, true, true, 'journaliste', 'Vera Pravdina']);
  const msg = (await db.query("SELECT id, auteur, message FROM messages_chat")).rows;
  assert.equal(msg.length, 1);
  assert.equal(msg[0].id, 'guide-relance-' + r.id);
  assert.equal(msg[0].auteur, 'pnj:Vera Pravdina');
  assert.match(msg[0].message, /filé entre les doigts/);
  assert.equal((await rpc(db, U.bernard, 'guide_reserver()')).raison, 'deja_ecrit_aujourdhui', 'compte comme le message du jour');
  // Une seule relance : le lendemain, l'habitant (la journaliste n'a pas d'interview à suivre).
  await jour(db, '2026-12-02');
  const h = await rpc(db, U.bernard, 'guide_reserver()');
  assert.equal(h.voix, 'habitant');
  assert.notEqual(h.relance, true);
  assert.equal((await rpc(db, U.bernard, 'guide_etat_lire()')).interview_en_attente, true, 'l’interview attend dans Mes objectifs');
});

test('relance : une interview ignorée revient dans « Mes objectifs »', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.tom, 'Tom');
  await rpc(db, U.tom, 'accueil_ignorer()');
  await db.exec("UPDATE accueil_personnages SET ouverte_auto_le = '2026-11-30 12:00+01' WHERE personnage = 'Tom'");
  await jour(db, '2026-12-01');
  const r = await rpc(db, U.tom, 'guide_reserver()');
  assert.deepEqual([r.relance, r.pnj], [true, 'Jodie Moitout']);
  assert.equal((await db.query("SELECT etat_interview FROM accueil_personnages WHERE personnage = 'Tom'")).rows[0].etat_interview, 'a_faire');
});

test('« Ne plus me proposer d’interview d’accueil » : plus de relance, interview retirée, rien d’autre touché', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.bernard, 'Bernard');
  await db.exec("UPDATE accueil_personnages SET ouverte_auto_le = '2026-11-30 18:00+01', etat_interview = 'a_faire' WHERE personnage = 'Bernard'");
  const avant = (await db.query("SELECT count(*)::int n FROM information_schema.columns WHERE table_name <> 'accueil_personnages' AND column_name LIKE 'interview%refus%'")).rows[0].n;
  const ref = await rpc(db, U.bernard, 'accueil_interview_refuser()');
  assert.equal(ref.ok, true);
  assert.equal((await db.query("SELECT etat_interview FROM accueil_personnages WHERE personnage = 'Bernard'")).rows[0].etat_interview, 'ignoree');
  const s = await rpc(db, U.bernard, 'guide_etat_lire()');
  assert.deepEqual([s.interview_refusee, s.interview_en_attente, s.arrete], [true, false, false], 'le guide continue');
  for (const j of ['2026-12-01', '2026-12-02', '2026-12-03']) {
    await jour(db, j);
    const r = await rpc(db, U.bernard, 'guide_reserver()');
    assert.notEqual(r.relance, true, 'aucune relance le ' + j);
    if (r.ok && r.id) await publier(db, r.id);
  }
  assert.equal(avant, 0, 'le refus n’existe que pour l’interview d’accueil');
  // Un visiteur anonyme ne peut pas refuser à la place du joueur.
  await assert.rejects(db.query("SET ROLE anon; SELECT public.accueil_interview_refuser();"));
  await db.exec('RESET ROLE');
});
