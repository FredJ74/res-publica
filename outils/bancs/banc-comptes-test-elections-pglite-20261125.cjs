'use strict';
// Mission de jour du 25/11/2026, bloc 1.3 (décision de Fred, A.1) : seuls Arnie, Tom Tom et Bernard Bernardov sont des comptes
// de test ; interrupteur de MJ qui les réintègre dans le dépouillement des élections le temps d'un test (exclus par défaut,
// extinction automatique). Migrations 20261124100000 + 20261125160000 dans PGlite ; repli du traitement de nuit.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-comptes-test-elections-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIGRATION = 'migrations/20261124100000_comptes_test.sql', MIG = 'migrations/20261125160000_comptes_test_elections_interrupteur.sql';

test('aucun nouveau compte marqué ; traitement de nuit : liste des élections, repli sans migration, échec silencieux', async () => {
  assert.doesNotMatch(lire(MIG).replace(/^--.*$/gm, ''), /INSERT INTO public\.comptes_test \(/, 'la migration ne marque personne');
  const src = lire('api/cron-minuit.js');
  const i = src.indexOf('async function comptesTestServeur'), j = src.indexOf('\n}\n', i);
  const code = src.slice(i, j + 2);
  assert.match(code, /comptes_test_noms_elections/); assert.match(code, /'comptes_test_noms'/);
  const essai = async (reponses) => {
    const appels = [];
    const ctx = { SUPABASE_URL: 'http://x', HEADERS_SERVICE: {}, _comptesTestServeur: null, Set, Error, Array,
      fetch: async (url) => { const fn = url.split('/').pop(); appels.push(fn); const r = reponses[fn];
        return r ? { ok: true, json: async () => r } : { ok: false, status: 404, json: async () => ({}) }; } };
    vm.createContext(ctx);
    vm.runInContext('let _comptesTestServeur = null;' + code + ';this.f = comptesTestServeur;', ctx);
    return { liste: [...await ctx.f()].sort(), appels };
  };
  // Sans migration : repli sur la liste des comptes de test.
  assert.deepEqual((await essai({ comptes_test_noms: ['Arnie', 'Tom Tom'] })).liste, ['Arnie', 'Tom Tom']);
  // Avec la migration, interrupteur allumé : liste vide (comptes de test réintégrés).
  const r = await essai({ comptes_test_noms_elections: [], comptes_test_noms: ['Arnie'] });
  assert.deepEqual(r.liste, []); assert.deepEqual(r.appels, ['comptes_test_noms_elections']);
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
  await db.exec(lire(MIG));
  return db;
}


test('interrupteur MJ : exclus par défaut, réintégrés le temps du test, extinction automatique, journalisé, interdit aux joueurs', async () => {
  const db = await base();
  const q = async (sql) => (await db.query(sql)).rows;
  assert.deepEqual((await q('SELECT personnage FROM comptes_test ORDER BY 1')).map(r => r.personnage), ['Arnie', 'Bernard Bernardov', 'Tom Tom']);
  assert.deepEqual((await q('SELECT public.comptes_test_noms_elections() n'))[0].n.sort(), ['Arnie', 'Bernard Bernardov', 'Tom Tom'], 'exclus par défaut');
  // Un joueur ne peut ni lire ni allumer l'interrupteur.
  await db.exec(`SET test.uid = '${U.jean}'; SET ROLE authenticated;`);
  await assert.rejects(db.query('SELECT public.admin_comptes_test_elections_fixer(true, 2)'));
  await assert.rejects(db.query('SELECT public.comptes_test_noms_elections()'));
  await db.exec(`RESET ROLE; SET test.uid = '${U.mj}'; SET ROLE authenticated;`);
  assert.equal((await db.query('SELECT public.admin_comptes_test_elections_fixer(true, 0) r')).rows[0].r.raison, 'duree_invalide');
  const on = (await db.query('SELECT public.admin_comptes_test_elections_fixer(true, 2) r')).rows[0].r;
  assert.equal(on.inclus, true);
  const lu = (await db.query('SELECT public.admin_comptes_test_lire() r')).rows[0].r;
  assert.equal(lu.elections_inclus, true); assert.ok(lu.elections_inclus_jusqu_au);
  await db.exec('RESET ROLE; RESET test.uid;');
  assert.deepEqual((await q('SELECT public.comptes_test_noms_elections() n'))[0].n, [], 'réintégrés le temps du test');
  // Le tirage des candidatures et la marque restent inchangés.
  assert.equal((await q("SELECT public.est_compte_test('Arnie') v"))[0].v, true);
  // Extinction automatique à l'heure choisie.
  await db.exec("UPDATE comptes_test_parametres SET valeur = now() - interval '1 minute'");
  assert.equal((await q('SELECT public.comptes_test_noms_elections() n'))[0].n.length, 3);
  // Extinction manuelle.
  await db.exec(`SET test.uid = '${U.mj}'; SET ROLE authenticated;`);
  await db.query('SELECT public.admin_comptes_test_elections_fixer(true, 5)');
  assert.equal((await db.query('SELECT public.admin_comptes_test_elections_fixer(false) r')).rows[0].r.inclus, false);
  await db.exec('RESET ROLE; RESET test.uid;');
  assert.equal((await q("SELECT count(*)::int n FROM admin_journal WHERE action = 'comptes_test_elections'"))[0].n, 3);
  await db.exec(lire(MIG));   // rejouable
});
