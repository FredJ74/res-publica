'use strict';
// Mission de nuit du 25/11/2026, bloc 4 (4.3) : la chance affichée (« Vos chances réelles : X % ») est identique à celle que le
// serveur utilise pour trancher l'ordre, sur au moins un ordre de chaque famille : crime (explosifs), rumeur, combat
// (neutraliser, trois modes), se cacher, vol (subtiliser des explosifs, bloc 3).
// Vrai PostgreSQL local (PGlite). Les quatre fonctions raccordées sont reproduites en réduction AVEC LEURS LIGNES D'ANCRAGE
// EXACTES (relevées en production le 25/11 : chaque motif du raccord y apparaît une fois) ; les briques communes sont celles
// des migrations ou des doublures pilotées par table (brouillard, hommes armés, cachette, cible).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-chances-reelles-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG3 = 'migrations/20261125120000_subtiliser_explosifs_description.sql', MIG4 = 'migrations/20261125130000_ordres_chances_reelles.sql';

test('écran : chances lues au serveur, aucune formule côté navigateur, repli silencieux sans la migration', () => {
  const js = lire('plateau-chances-reelles.js');
  assert.match(js, /sbRpc\('ordres_chances_lire'/);
  assert.match(js, /Vos chances réelles : /);
  assert.doesNotMatch(js, /Math\.(min|max)\([^)]*(DIS|dis|CHA|ISN)/, 'aucun calcul de chance');
  assert.match(js, /catch \(_\) \{ r = null; \}/);
  assert.match(lire('plateau.html'), /plateau-chances-reelles\.js/);
  assert.match(lire('plateau-criminalite.js'), /ordres_chances_lire', \{ p_fns: \['neutraliser'\], p_cible/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, career text,
  reputation_criminelle integer DEFAULT 0, resources jsonb DEFAULT '{}', stats jsonb DEFAULT '{}', pa integer DEFAULT 10, inventory jsonb DEFAULT '[]');
CREATE TABLE crim_parametres (cle text PRIMARY KEY, valeur numeric);
INSERT INTO crim_parametres VALUES ('crim_dis_pivot', 50), ('crim_dis_tranche', 3), ('explosifs_base', 35), ('explosifs_min', 5), ('explosifs_max', 75),
  ('explosifs_carriere', 15), ('explosifs_cache', 10), ('explosifs_int_pivot', 8), ('explosifs_int_pas', 2), ('explosifs_officiel', 30),
  ('rumeur_taux_base', 60), ('rumeur_taux_min', 10), ('rumeur_taux_max', 90), ('detection_cache', 20), ('detection_masque', 10), ('detection_min', 5);
CREATE TABLE infractions (id text PRIMARY KEY, libelle text, detect_rate integer);
INSERT INTO infractions VALUES ('acheter_bombe_illegale', 'x', 55);
CREATE TABLE indices_villes (id text PRIMARY KEY, data jsonb);
CREATE TABLE banc (nom text PRIMARY KEY, mode text DEFAULT 'decouvert', gardes integer DEFAULT 0, brouillard boolean DEFAULT false, cacher integer DEFAULT 40);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION crim_param_interne(p_cle text, p_defaut numeric DEFAULT 0) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT valeur FROM crim_parametres WHERE cle = p_cle), p_defaut) $$;
CREATE FUNCTION crim_bonus_dis_interne(p_dis numeric) RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT greatest(0, trunc((coalesce(p_dis, 50) - crim_param_interne('crim_dis_pivot', 50)) / crim_param_interne('crim_dis_tranche', 3)))::integer $$;
CREATE FUNCTION crim_stat_interne(p_nom text, p_cle text, p_defaut numeric) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT CASE WHEN p_cle = 'dis' AND jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric
      WHEN p_cle <> 'dis' AND coalesce(d.stats ->> p_cle, '') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN (d.stats ->> p_cle)::numeric END
    FROM personnages_donnees d WHERE d.name = p_nom), p_defaut) $$;
CREATE FUNCTION crim_carriere_interne(p_nom text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT career FROM personnages_donnees WHERE name = p_nom $$;
CREATE FUNCTION crim_batiment_officiel_interne(p_batiment text) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_batiment IN ('mairie', 'commissariat'), false) $$;
CREATE FUNCTION crim_explosifs_taux_interne(p_dis numeric, p_int numeric, p_cache boolean, p_carriere text, p_officiel boolean)
RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT round(crim_param_interne('explosifs_base', 35) + crim_bonus_dis_interne(p_dis)
         + crim_param_interne('explosifs_int_pas', 2) * (coalesce(p_int, 8) - crim_param_interne('explosifs_int_pivot', 8))
         + CASE WHEN p_cache THEN crim_param_interne('explosifs_cache', 10) ELSE 0 END
         + CASE WHEN p_carriere = 'criminal_c' THEN crim_param_interne('explosifs_carriere', 15) ELSE 0 END
         - CASE WHEN p_officiel THEN crim_param_interne('explosifs_officiel', 30) ELSE 0 END)::integer $$;
CREATE FUNCTION crim_rumeur_taux_interne(p_dis numeric, p_cha numeric) RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT (crim_param_interne('rumeur_taux_base', 60) + crim_bonus_dis_interne(p_dis) + 2 * greatest(0, floor(coalesce(p_cha, 8)) - 8))::integer $$;
CREATE FUNCTION crim_neutraliser_taux_interne(p_mode text, p_stat numeric, p_crim boolean, p_per numeric, p_cache boolean, p_gilet boolean)
RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT (20 + 2 * p_stat + CASE WHEN p_crim THEN 15 ELSE 0 END - coalesce(p_per, 8) / 2 + CASE WHEN p_cache THEN 10 ELSE 0 END
          - CASE WHEN p_gilet THEN CASE WHEN p_mode = 'feu' THEN 20 ELSE 5 END ELSE 0 END)::integer $$;
CREATE FUNCTION crim_cache_interne(p_nom text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT coalesce((SELECT mode IN ('cache','cache_masque') FROM banc WHERE nom = p_nom), false) $$;
CREATE FUNCTION crim_mode_action_interne(p_nom text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT coalesce((SELECT mode FROM banc WHERE nom = p_nom), 'decouvert') $$;
CREATE FUNCTION crim_objet_porte_interne(p_nom text, p_objet text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT p_nom = 'Cible_Gilet' $$;
CREATE FUNCTION climat_brouillard_modificateurs_interne(p_pays text, p_ville text) RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM banc WHERE brouillard) THEN '{"brouillard": true, "bonus_reussite": 10, "malus_detection": 20}'::jsonb ELSE '{}'::jsonb END $$;
CREATE FUNCTION securite_malus_lieu_interne(p_acteur text) RETURNS integer LANGUAGE sql AS $$
  SELECT CASE WHEN coalesce((SELECT gardes FROM banc WHERE nom = p_acteur), 0) > 0 THEN least(40, 10 + (SELECT gardes FROM banc WHERE nom = p_acteur)) ELSE 0 END $$;
CREATE FUNCTION crime_malus_isn_interne(p_pays text, p_ville text) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT 5 $$;
CREATE FUNCTION se_cacher_chances() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object('ok', true, 'taux', (SELECT cacher FROM banc WHERE nom = mon_personnage())) $$;
CREATE FUNCTION crim_cible_resoudre_interne(p_auteur text, p_cible text) RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN p_cible IN ('Cible', 'Cible_Gilet') THEN jsonb_build_object('ok', true, 'pj', true, 'nom', p_cible, 'per', 12)
              ELSE '{"ok": false, "raison": "cible_absente"}'::jsonb END $$;
-- Réductions des quatre fonctions raccordées : lignes d'ancrage identiques à la production.
CREATE FUNCTION public.crim_resoudre_interne(p_acte text, p_auteur text, p_cible text, p_params jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p jsonb := coalesce(p_params, '{}'::jsonb); a record; v_dis integer := 0; v_taux integer; v_brouillard jsonb := '{}'::jsonb;
BEGIN
  SELECT name, country, current_city INTO a FROM public.personnages_donnees WHERE name = p_auteur;
  IF coalesce((p ->> 'brouillard')::boolean, true) THEN /* crim_brouillard_v1 */
    v_brouillard := coalesce(public.climat_brouillard_modificateurs_interne(a.country, a.current_city), '{}'::jsonb);
  END IF;
    IF coalesce((p ->> 'dissuasion')::boolean, true) THEN v_dis := coalesce(public.securite_malus_lieu_interne(p_auteur), 0); END IF;
    v_taux := greatest(coalesce((p ->> 'min')::numeric, 0), least(coalesce((p ->> 'max')::numeric, 100), (p ->> 'taux')::numeric + CASE WHEN coalesce((v_brouillard ->> 'brouillard')::boolean, false) THEN coalesce((v_brouillard ->> 'bonus_reussite')::numeric, 0) ELSE 0 END /* crim_brouillard_taux_v1 */ - v_dis))::integer;
  RETURN jsonb_build_object('taux', v_taux);
END $function$;
CREATE FUNCTION public.crime_explosifs(p_nom_batiment text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); m record; v_mode text; v_officiel boolean; v_taux integer;
BEGIN
  SELECT current_building, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */ INTO m FROM public.personnages_donnees WHERE name = a;
  v_mode := public.crim_mode_action_interne(a);
  v_officiel := public.crim_batiment_officiel_interne(m.current_building);
  v_taux := public.crim_explosifs_taux_interne(public.crim_stat_interne(a, 'dis', 50), public.crim_stat_interne(a, 'INT', 8),
                                               v_mode IN ('cache', 'cache_masque'), m.career, v_officiel);
  RETURN public.crim_resoudre_interne('utiliser_explosifs', a, NULL, jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('explosifs_min', 5), 'max', public.crim_param_interne('explosifs_max', 75), 'mode', v_mode));
END $$;
CREATE FUNCTION public.rumeur_lancer(p_type text, p_cible text, p_texte text, p_cible_trace text, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); v_dis numeric;
BEGIN
  v_dis := public.crim_stat_interne(v_moi, 'dis', 50);
  RETURN public.crim_resoudre_interne('fausse_rumeur', v_moi, NULL, jsonb_build_object(
    'taux', public.crim_rumeur_taux_interne(v_dis, public.crim_stat_interne(v_moi, 'CHA', 8)),
    'min', public.crim_param_interne('rumeur_taux_min', 10), 'max', public.crim_param_interne('rumeur_taux_max', 90),
    'mode', 'decouvert', 'brouillard', false));
END $$;
CREATE FUNCTION public.crime_neutraliser(p_cible text, p_mode text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); m record; ci jsonb; v_stat text; v_cap integer; v_taux integer; v_cache boolean; v_gilet boolean;
BEGIN
  CASE p_mode WHEN 'mains' THEN v_stat := 'FOR'; v_cap := 65; WHEN 'arme' THEN v_stat := 'DUP'; v_cap := 75; ELSE v_stat := 'PER'; v_cap := 85; END CASE;
  SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */ INTO m FROM public.personnages_donnees WHERE name = a;
  ci := public.crim_cible_resoudre_interne(a, p_cible);
  v_cache := public.crim_cache_interne(a);
  v_gilet := (ci ->> 'pj')::boolean AND public.crim_objet_porte_interne(ci ->> 'nom', 'gilet');
  v_taux := public.crim_neutraliser_taux_interne(p_mode, public.crim_stat_interne(a, v_stat, 8), m.career = 'criminal_c',
                                                 (ci ->> 'per')::numeric, v_cache, v_gilet);
  RETURN public.crim_resoudre_interne('neutraliser', a, p_cible, jsonb_build_object('taux', v_taux, 'min', 0, 'max', v_cap));
END $function$;
-- Doublures du bloc 3 (militaire_subtiliser_tenter est remplacé par la migration).
CREATE FUNCTION crim_peine_jours_interne(p_acte text, p_pays text) RETURNS integer LANGUAGE sql AS $$ SELECT 2 $$;
CREATE FUNCTION arrestation_flagrant_interne(a text, b text, c boolean, d text, e text, f integer, g boolean, h text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION caserne_stock_mouvement(a text, b text, c integer, d text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok": true}'::jsonb $$;
CREATE FUNCTION militaire_subtiliser_tenter(p_pays text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;`;

async function base(avecBloc3 = true) {
  const db = new PGlite();
  await db.exec(SOCLE);
  if (avecBloc3) await db.exec(lire(MIG3));
  await db.exec(lire(MIG4));
  return db;
}
async function pj(db, nom, o = {}) {
  await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, career, reputation_criminelle, resources, stats)
    VALUES ($1, 'republic', 'capitale', $2, $3, $4, $5, $6)`, [nom, o.batiment || 'caserne-militaire', o.carriere || 'civil', o.rep || 0,
    JSON.stringify({ dis: o.dis ?? 50 }), JSON.stringify(o.stats || {})]);
  await db.query('INSERT INTO banc (nom, mode, gardes, brouillard, cacher) VALUES ($1, $2, $3, $4, $5)', [nom, o.mode || 'decouvert', o.gardes || 0, !!o.brouillard, o.cacher ?? 40]);
}
const moi = (db, nom) => db.exec(`SET banc.moi = '${nom}'`);
const chances = async (db, fns, cible) => (await db.query('SELECT ordres_chances_lire($1, $2) r', [fns, cible || null])).rows[0].r;
const q1 = async (db, sql) => (await db.query(sql)).rows[0].r;

test('les quatre fonctions de résolution sont raccordées à la formule partagée', async () => {
  const db = await base();
  for (const f of ['crim_resoudre_interne', 'crime_explosifs', 'rumeur_lancer', 'crime_neutraliser']) {
    const d = (await db.query("SELECT prosrc FROM pg_proc WHERE proname = $1", [f])).rows[0].prosrc;
    assert.match(d, /chances_reelles_v1/, f);
  }
});

const CAS = [
  { nom: 'Neutre', o: {} },
  { nom: 'Truand', o: { dis: 80, carriere: 'criminal_c', stats: { INT: 12, CHA: 14, FOR: 14, DUP: 9, PER: 11 }, mode: 'cache' } },
  { nom: 'Brume', o: { brouillard: true, gardes: 3, stats: { CHA: 10 }, batiment: 'mairie' } },
  { nom: 'Garde', o: { gardes: 30, dis: 59, mode: 'cache_masque', cacher: 12 } }
];

test('crime, rumeur, combat, se cacher et vol : la chance affichée est celle que l’ordre utilise', async () => {
  for (const c of CAS) {
    const db = await base();
    await pj(db, c.nom, c.o);
    await moi(db, c.nom);
    const lu = await chances(db, ['utiliser_explosifs', 'lancer_rumeur_cible', 'se_cacher', 'acheter_bombe_illegale', 'neutraliser'], 'Cible');
    assert.equal(lu.ok, true);
    const ch = lu.chances;
    assert.equal(ch.utiliser_explosifs, (await q1(db, "SELECT crime_explosifs(NULL, NULL) r")).taux, c.nom + ' explosifs');
    assert.equal(ch.lancer_rumeur_cible, (await q1(db, "SELECT rumeur_lancer('pj', 'X', 't', NULL, 1, 0) r")).taux, c.nom + ' rumeur');
    for (const mode of ['mains', 'arme', 'feu'])
      assert.equal(ch.neutraliser[mode], (await q1(db, `SELECT crime_neutraliser('Cible', '${mode}', NULL) r`)).taux, c.nom + ' neutraliser ' + mode);
    assert.equal(ch.se_cacher, c.o.cacher ?? 40, c.nom + ' se cacher');
    assert.equal(ch.acheter_bombe_illegale, (await q1(db, `SELECT crim_subtiliser_chance_interne('${c.nom}') r`)).taux, c.nom + ' subtiliser');
  }
});

test('la cible compte pour le combat ; sans cible ou cible absente, pas de chance inventée ; bloc 3 absent : pas de chance de vol', async () => {
  const db = await base(false);
  await pj(db, 'Han', { stats: { FOR: 12 } });
  await moi(db, 'Han');
  const a = (await chances(db, ['neutraliser'], 'Cible')).chances.neutraliser;
  const b = (await chances(db, ['neutraliser'], 'Cible_Gilet')).chances.neutraliser;
  assert.equal(a.feu - b.feu, 20, 'gilet de la cible : −20 contre une arme à feu');
  assert.deepEqual((await chances(db, ['neutraliser'])).chances, {});
  assert.deepEqual((await chances(db, ['neutraliser'], 'Personne')).chances, {});
  assert.deepEqual((await chances(db, ['acheter_bombe_illegale', 'ordre_inconnu'])).chances, {});
  await db.exec('RESET banc.moi');
  assert.equal((await chances(db, ['se_cacher'])).ok, false, 'personne de connecté');
});
