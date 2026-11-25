'use strict';
// Mission de jour du 25/11/2026, bloc 1.4 (décision de Fred) : forum du tribunal — les parties à l'affaire et les juges y
// lisent et écrivent où qu'ils soient ; les autres joueurs le lisent sans y écrire. Migrations 20261124110000 (Purge B.1)
// puis 20261125170000 dans PGlite, sur le socle des forums de production (fixtures/forums-acces-pglite-socle.sql.txt).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-forum-tribunal-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125170000_forum_tribunal_parties_juges.sql';

test('écran : droits lus au serveur, lecture seule dite en clair, repli sans la migration', () => {
  const js = lire('forum.js');
  assert.match(js, /sbRpc\('forum_tribunal_droits'/);
  assert.match(js, /function forumTribunalLectureSeule/);
  assert.match(js, /seuls les parties aux affaires et les juges de ce tribunal y écrivent/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

async function base({ migrer = true } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/forums-acces-pglite-socle.sql.txt'));
  await db.exec(`
    ALTER TABLE personnages_donnees ADD COLUMN poste jsonb;
    CREATE TABLE plaintes_en_cours (id text PRIMARY KEY, country text, city text, data text, created_at timestamptz DEFAULT now());
    CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, auteur text, cible text, pays text, ville text, identifie boolean DEFAULT false,
      plainte_id text, archivee_le timestamptz);
    CREATE FUNCTION poste_pays_de(p_nom text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT poste->>'country' FROM personnages_donnees WHERE name = p_nom $$;
    CREATE FUNCTION poste_detenu(p_nom text, p_poste text, p_pays text, p_ville text DEFAULT NULL) RETURNS boolean LANGUAGE sql STABLE AS $$
      SELECT EXISTS (SELECT 1 FROM personnages_donnees WHERE name = p_nom AND poste->>'id' = p_poste AND poste->>'country' = p_pays
        AND (p_ville IS NULL OR poste->>'city' = p_ville)) $$;
    CREATE FUNCTION juge_moi() RETURNS TABLE (nom text, ville text) LANGUAGE sql STABLE AS $$ SELECT NULL::text, NULL::text WHERE false $$;
    INSERT INTO personnages_donnees (name, country, current_city, nationalite, domicile, poste) VALUES
      ('Accuse', 'republic', 'ville_a', 'republic', '{"country":"republic","city":"ville_a"}', NULL),
      ('Plaignante', 'soviet', 'capitale', 'republic', '{"country":"republic","city":"capitale"}', NULL),
      ('Juge', 'soviet', 'ville_b', 'republic', '{"country":"republic","city":"capitale"}', '{"id":"juge","country":"republic","city":"capitale"}'),
      ('Curieux', 'republic', 'capitale', 'republic', '{"country":"republic","city":"capitale"}', NULL),
      ('Lointain', 'soviet', 'ville_a', 'soviet', '{"country":"soviet","city":"ville_a"}', NULL);
    INSERT INTO plaintes_en_cours (id, country, city, data) VALUES
      ('affaire-1', 'republic', 'capitale', '{"cible":"Accuse","auteur":"Plaignante","status":"au_parquet"}');
    INSERT INTO forum_topics (id, forum_id, title, author, country, time, views, replies) VALUES
      ('t-aff', 'tribunal_capitale', '⚖️ [AFFAIRE] Accuse', 'Brigade Criminelle', 'republic', '25/11/2026 10:00', 1, 0);`);
  await db.exec(lire('migrations/20261124110000_forums_acces_purge.sql'));
  if (migrer) await db.exec(lire(MIG));
  return db;
}
const en = (db, nom) => db.query("SELECT set_config('rp.moi', $1, false)", [nom]);
const lit = async (db, f, p) => (await db.query('SELECT forum_lecture_autorisee($1,$2) v', [f, p])).rows[0].v;
const ecrit = async (db, f, p) => (await db.query('SELECT forum_ecriture_autorisee($1,$2) v', [f, p])).rows[0].v;
const publier = async (db, nom, m) => (await en(db, nom), await db.query('SELECT forum_publication_jauges_interne($1, gen_random_uuid(), $2::jsonb) r', [nom, JSON.stringify(m)])).rows[0].r;

test('avant : n’importe qui écrivait au tribunal ; les parties hors de la ville ne pouvaient pas répondre', async () => {
  const avant = await base({ migrer: false });
  await en(avant, 'Curieux');
  assert.equal(await ecrit(avant, 'tribunal_capitale', 'republic'), true, 'défaut reproduit');
  assert.equal((await publier(avant, 'Accuse', { topic: 't-aff', contenu: 'Je suis innocent' })).ok, false, 'partie à Port-Sainte-Marie refusée');
});

test('parties et juges écrivent où qu’ils soient ; les autres lisent seulement ; pays du tribunal respecté', async () => {
  const db = await base();
  for (const nom of ['Accuse', 'Plaignante', 'Juge']) {
    await en(db, nom);
    assert.equal(await lit(db, 'tribunal_capitale', 'republic'), true, nom + ' lit');
    assert.equal(await ecrit(db, 'tribunal_capitale', 'republic'), true, nom + ' écrit, où qu’il soit');
  }
  assert.equal((await publier(db, 'Accuse', { topic: 't-aff', contenu: 'Je suis innocent' })).ok, true, 'réponse depuis Port-Sainte-Marie');
  assert.equal((await publier(db, 'Plaignante', { topic: 't-aff', contenu: 'Audience demain ?' })).ok, true, 'réponse depuis Novomirsk');
  const nouveau = await publier(db, 'Juge', { forum: 'tribunal_capitale', titre: 'Audience du 27/11', contenu: 'Audience à 18 h.', pays: 'republic' });
  assert.equal(nouveau.ok, true, 'le juge ouvre un sujet depuis Krasnov');
  assert.equal((await db.query('SELECT country FROM forum_topics WHERE id = $1', [nouveau.topic])).rows[0].country, 'republic', 'rangé au tribunal de Luthécia');
  for (const nom of ['Curieux', 'Lointain']) {
    await en(db, nom);
    assert.equal(await lit(db, 'tribunal_capitale', 'republic'), true, nom + ' lit (procès suivi à distance)');
    assert.equal(await ecrit(db, 'tribunal_capitale', 'republic'), false, nom + ' n’écrit pas');
  }
  assert.equal((await publier(db, 'Curieux', { topic: 't-aff', contenu: 'Coupable !' })).raison, 'forum_inaccessible', 'même sur place');
  // Le même identifiant de ville dans l'autre pays : la partie n'y écrit pas.
  await en(db, 'Accuse');
  assert.equal(await ecrit(db, 'tribunal_capitale', 'soviet'), false, 'tribunal de Novomirsk : pas partie');
  // Fin de l'affaire : plus partie.
  await db.exec("DELETE FROM plaintes_en_cours");
  assert.equal(await ecrit(db, 'tribunal_capitale', 'republic'), false);
});

test('droits de l’écran ; partie par une affaire criminelle identifiée ; migration rejouable', async () => {
  const db = await base();
  await en(db, 'Lointain');
  await db.exec("INSERT INTO crim_affaires (auteur, cible, pays, ville, identifie, plainte_id) VALUES ('Lointain', 'Curieux', 'soviet', 'ville_a', false, 'p9')");
  assert.equal(await ecrit(db, 'tribunal_ville_a', 'soviet'), false, 'auteur non identifié : pas de droit (rien n’est révélé)');
  await db.exec('UPDATE crim_affaires SET identifie = true');
  assert.equal(await ecrit(db, 'tribunal_ville_a', 'soviet'), true);
  const d = (await db.query('SELECT forum_tribunal_droits() r')).rows[0].r;
  assert.deepEqual(d.tribunaux, [{ pays: 'soviet', ville: 'ville_a' }]);
  assert.equal(d.ici.ecriture, true);
  await en(db, 'Juge');
  const j = (await db.query('SELECT forum_tribunal_droits() r')).rows[0].r;
  assert.deepEqual(j.tribunaux, [{ pays: 'republic', ville: 'capitale' }]);
  assert.equal(j.ici.ecriture, false, 'à Krasnov, le juge de Luthécia n’écrit pas au tribunal de Krasnov');
  await db.exec(lire(MIG));
});
