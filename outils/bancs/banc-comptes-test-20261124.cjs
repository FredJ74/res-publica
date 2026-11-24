'use strict';
// Purge A.1 (Fred, 24/11/2026) : comptes de test marqués en base et exclus des élections et des tirages au sort.
// Migration 20261124100000_comptes_test dans un vrai PostgreSQL local (PGlite) + dépouillement du cron (copie filtrée).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-comptes-test-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIGRATION = 'migrations/20261124100000_comptes_test.sql';

test('la migration ne marque que les trois comptes retenus et ne touche que le tirage des candidatures', () => {
  const m = lire(MIGRATION);
  const noms = [...m.matchAll(/^\s+(?:FROM \(VALUES |)\('([^']+)', '/gm)].map(x => x[1]);
  assert.deepEqual(noms, ['Arnie', 'Tom Tom', 'Bernard Bernardov']);
  assert.deepEqual([...m.matchAll(/rp_remplacer\('([^']+)'/g)].map(x => x[1]), ['public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text)']);
  assert.doesNotMatch(m.replace(/^--.*$/gm, ''), /goulag/i);
});

test('dépouillement du cron : bulletins et candidatures des comptes de test ignorés, blob intact', () => {
  const src = lire('api/cron-minuit.js');
  const extraire = nom => { const i = src.indexOf('function ' + nom); assert.ok(i > 0, nom); let j = src.indexOf('\n}\n', i); return src.slice(i, j + 2); };
  const ctx = {}; vm.createContext(ctx);
  vm.runInContext(extraire('cycleSansComptesTest') + extraire('calculerScoresBaseCycle') + extraire('resoudreScrutinSimple') +
    'function appliquerEffetsTracts(){}', ctx);
  const cycle = { candidats: [{ nom: 'Arnie' }, { nom: 'Jean' }, { nom: 'Lucie' }],
    votes: { Arnie: 'Arnie', 'Tom Tom': 'Arnie', Bob: 'Jean', Zoe: 'Arnie', Max: 'Lucie', Lea: 'Jean' }, votesPNJ: { p1: 'Arnie', p2: 'Lucie' } };
  const test_ = new Set(['Arnie', 'Tom Tom']);
  const copie = ctx.cycleSansComptesTest(cycle, test_);
  const r = ctx.resoudreScrutinSimple(copie, []);
  assert.deepEqual(Object.keys(r.scores).sort(), ['Jean', 'Lucie']);
  assert.equal(r.scores.Jean, 2); assert.equal(r.scores.Lucie, 2);
  assert.equal(Object.keys(cycle.votes).length, 6, 'le cycle enregistré garde tous ses bulletins');
  assert.equal(ctx.cycleSansComptesTest(cycle, new Set()), cycle, 'sans compte de test : cycle inchangé');
  assert.match(src, /resoudreScrutinDepute\(cycleSansComptesTest\(cycle, await comptesTestServeur\(\)\)/);
  assert.match(src, /resoudreScrutinSimple\(cycleSansComptesTest\(cycle, await comptesTestServeur\(\)\)/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.uid', true), '')::uuid $$;
GRANT USAGE ON SCHEMA auth, public TO authenticated, anon;
CREATE TABLE public.personnages_donnees (name text PRIMARY KEY, user_id uuid, country text, poste jsonb, resources jsonb);
CREATE TABLE public.postes_attribues (id text PRIMARY KEY, country text, poste_id text, city text, titulaire text, source text, updated_at timestamptz);
CREATE TABLE public.titulaires_pnj (id text PRIMARY KEY);
CREATE TABLE public.admin_journal (id bigserial PRIMARY KEY, admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE TABLE public.admins (user_id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION public.admin_exiger() RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN IF NOT EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid()) THEN RAISE EXCEPTION 'mj_requis'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.acte_nocturne_revendiquer(a text, b text, c text, d jsonb) RETURNS boolean LANGUAGE sql AS $$ SELECT true $$;
CREATE OR REPLACE FUNCTION public.mail_systeme_envoyer(a text, b text, c text, d text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE OR REPLACE FUNCTION public.candidature_poste_tirage_appliquer(p_pays text, p_poste_id text, p_city text, p_label text, p_candidats text[], p_autorite text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pays text := lower(btrim(coalesce(p_pays,''))); v_gagnant text;
BEGIN
  SELECT d.name INTO v_gagnant FROM public.personnages_donnees d
   WHERE d.name = ANY (p_candidats) AND d.country = v_pays ORDER BY random() LIMIT 1;
  IF v_gagnant IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'gagnant', NULL, 'raison', 'aucun_candidat_eligible');
  END IF;
  RETURN jsonb_build_object('ok', true, 'gagnant', v_gagnant);
END; $function$;`;
const U = { arnie: '00000000-0000-0000-0000-000000000001', jean: '00000000-0000-0000-0000-000000000002', mj: '00000000-0000-0000-0000-0000000000aa' };

async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(`INSERT INTO personnages_donnees (name, user_id, country) VALUES ('Arnie', '${U.arnie}', 'republic'), ('Jean', '${U.jean}', 'republic'),
    ('Bernard Bernardov', '00000000-0000-0000-0000-000000000003', 'soviet'); INSERT INTO admins VALUES ('${U.mj}');`);
  await db.exec(lire(MIGRATION));
  return db;
}

test('marque, reroll, rejouable, tirage sans compte de test, MJ journalisé, aucun accès joueur', async () => {
  const db = await base();
  await db.exec(lire(MIGRATION));
  const q = async (sql) => (await db.query(sql)).rows;
  assert.deepEqual((await q('SELECT personnage FROM comptes_test ORDER BY 1')).map(r => r.personnage), ['Arnie', 'Bernard Bernardov', 'Tom Tom']);
  assert.equal((await q("SELECT public.est_compte_test('Arnie') v"))[0].v, true);
  assert.equal((await q("SELECT public.est_compte_test('Jean') v"))[0].v, false);
  // Reroll sur le compte d'Arnie : toujours un compte de test.
  await db.exec(`INSERT INTO personnages_donnees (name, user_id, country) VALUES ('Arnold', '${U.arnie}', 'republic')`);
  assert.equal((await q("SELECT public.est_compte_test('Arnold') v"))[0].v, true);
  assert.ok((await q('SELECT public.comptes_test_noms() n'))[0].n.includes('Arnold'));
  for (let i = 0; i < 25; i++) {
    const r = (await q("SELECT public.candidature_poste_tirage_appliquer('republic','juge',NULL,'Juge',ARRAY['Arnie','Arnold','Jean'],NULL) r"))[0].r;
    assert.equal(r.gagnant, 'Jean');
  }
  const seul = (await q("SELECT public.candidature_poste_tirage_appliquer('republic','juge',NULL,'Juge',ARRAY['Arnie'],NULL) r"))[0].r;
  assert.equal(seul.gagnant, null);
  // Joueur : ni la table, ni les fonctions.
  await db.exec(`SET test.uid = '${U.jean}'; SET ROLE authenticated;`);
  await assert.rejects(db.query('SELECT * FROM comptes_test'));
  await assert.rejects(db.query("SELECT public.est_compte_test('Arnie')"));
  await assert.rejects(db.query("SELECT public.admin_compte_test_fixer('Jean', true)"));
  await db.exec(`RESET ROLE; SET test.uid = '${U.mj}'; SET ROLE authenticated;`);
  const f = (await db.query("SELECT public.admin_compte_test_fixer('Jean', true) r")).rows[0].r;
  assert.equal(f.marque, true);
  await db.exec('RESET ROLE; RESET test.uid;');
  assert.equal((await q("SELECT count(*)::int n FROM admin_journal WHERE action = 'compte_test_fixer'"))[0].n, 1);
});
