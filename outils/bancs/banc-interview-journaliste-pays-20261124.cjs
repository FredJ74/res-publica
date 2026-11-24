'use strict';
// Purge A.4 (Fred, 24/11/2026) : l'interview publiée est signée par le journaliste du pays (Vera Pravdina en Sovarka,
// Jodie Moitout en Républia) et la presse est filtrée par pays ; l'article de Bernard est re-signé et reclassé.
// Migration 20261124103000 dans PGlite + filtre du forum (supabase.js).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-interview-journaliste-pays-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIGRATION = 'migrations/20261124103000_interview_journaliste_pays.sql';

test('écran : la presse est un forum filtré par pays', () => {
  const s = lire('supabase.js');
  const i = s.indexOf('function sbForumEstTerritorial'), j = s.indexOf('async function sbLoadForumTopics');
  const ctx = {}; vm.createContext(ctx); vm.runInContext(s.slice(i, j), ctx);
  assert.equal(ctx.sbForumEstTerritorial('presse'), true);
  assert.equal(ctx.sbForumSujetDansPays('presse', 'soviet', 'republic'), false, 'un article de Sovarka ne paraît pas en Républia');
  assert.equal(ctx.sbForumSujetDansPays('presse', 'soviet', 'soviet'), true);
  assert.equal(ctx.sbForumSujetDansPays('sport', 'soviet', 'republic'), true, 'les autres forums ne changent pas');
  assert.doesNotMatch(lire(MIGRATION).replace(/^--.*$/gm, ''), /'Jodie Moitout',NEW\.country/, 'plus de signature en dur');
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
CREATE TABLE accueil_journalistes (pays text PRIMARY KEY, journaliste text, journal text, question text);
INSERT INTO accueil_journalistes VALUES ('republic', 'Jodie Moitout', 'L''Autruche Entravée', 'q'), ('soviet', 'Vera Pravdina', 'La Voix de Sovarka', 'q');
CREATE TABLE interviews_jodie (id text PRIMARY KEY, personnage text, country text, publie boolean DEFAULT false, publie_le timestamptz,
  article_titre text, article_texte text, accueil boolean DEFAULT false, journaliste text);
CREATE TABLE forum_topics (id text PRIMARY KEY, forum_id text, title text, author text, country text, time text, last_post_author text, last_post_time text);
CREATE TABLE forum_posts (id text PRIMARY KEY, topic_id text, author text, content text, time text);
-- Production au 23/11 : l'article de Bernard, signé Jodie Moitout.
INSERT INTO interviews_jodie VALUES ('b', 'Bernard Bernardov', 'soviet', true, now(), 'Bernard, une vocation', 'Texte', true, 'Vera Pravdina');
INSERT INTO forum_topics VALUES ('interview-jodie-b', 'presse', 'Bernard, une vocation', 'Jodie Moitout', 'soviet', 't', 'Jodie Moitout', 't');
INSERT INTO forum_posts VALUES ('interview-jodie-b-article', 'interview-jodie-b', 'Jodie Moitout', 'Texte', 't');
INSERT INTO forum_topics VALUES ('interview-jodie-r', 'presse', 'Un banquier', 'Jodie Moitout', 'republic', 't', 'Jodie Moitout', 't');`;

test('Bernard re-signé Vera Pravdina et rangé en Sovarka ; nouvelle interview de Sovarka signée Vera, de Républia signée Jodie', async () => {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIGRATION));
  await db.exec('CREATE TRIGGER trg_jodie_interview_vers_forum AFTER INSERT OR UPDATE OF article_titre, article_texte, publie, publie_le ON interviews_jodie FOR EACH ROW EXECUTE FUNCTION jodie_interview_vers_forum();');
  await db.exec(lire(MIGRATION));   // rejouable
  const q = async s => (await db.query(s)).rows;
  assert.deepEqual(await q("SELECT author, country, last_post_author FROM forum_topics WHERE id = 'interview-jodie-b'"),
    [{ author: 'Vera Pravdina', country: 'soviet', last_post_author: 'Vera Pravdina' }]);
  assert.equal((await q("SELECT author FROM forum_posts WHERE id = 'interview-jodie-b-article'"))[0].author, 'Vera Pravdina');
  assert.equal((await q("SELECT author FROM forum_topics WHERE id = 'interview-jodie-r'"))[0].author, 'Jodie Moitout', 'Républia inchangée');
  // Une interview publiée en Sovarka, même sans colonne journaliste.
  await db.exec("INSERT INTO interviews_jodie (id, personnage, country, publie, publie_le, article_titre, article_texte) VALUES ('s2', 'Ivan', 'soviet', true, now(), 'Ivan au service', 'Ligne 1\nLigne <2>')");
  assert.deepEqual(await q("SELECT forum_id, author, country FROM forum_topics WHERE id = 'interview-jodie-s2'"), [{ forum_id: 'presse', author: 'Vera Pravdina', country: 'soviet' }]);
  assert.deepEqual(await q("SELECT author, content FROM forum_posts WHERE id = 'interview-jodie-s2-article'"), [{ author: 'Vera Pravdina', content: 'Ligne 1<br>Ligne &lt;2&gt;' }]);
  await db.exec("INSERT INTO interviews_jodie (id, personnage, country, publie, publie_le, article_titre, article_texte) VALUES ('r2', 'Tom', 'republic', true, now(), 'Tom', 'Texte')");
  assert.equal((await q("SELECT author FROM forum_topics WHERE id = 'interview-jodie-r2'"))[0].author, 'Jodie Moitout');
});
