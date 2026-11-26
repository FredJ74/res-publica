'use strict';
// Mission de fin de soirée du 25/11/2026 (agent B) : contrebande (amende égale au gain), médaille du Tractorisme au premier
// chant, censure en Sovarka, bénédiction tenue par le serveur, charisme du serveur, demi-effet, visites au commissariat,
// « Mobiliser les membres ». Migration 20261125820000 dans PGlite, sur un socle minimal dont les fonctions visées par les
// remplacements contrôlés portent les ancrages MOT POUR MOT tels que lus en production le 25/11/2026.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-fin-soiree-regles-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125820000_fin_soiree_regles_chances.sql';

test('écran et descriptions : chaque règle est annoncée telle que le serveur l’applique', () => {
  const data = lire('data.js');
  const desc = fn => [...data.matchAll(new RegExp("fn:'" + fn + "'[^\\n]*?desc:(['\"])((?:\\\\.|(?!\\1).)*)\\1", 'g'))].map(m => m[2]);
  const contrebande = desc('contrebande_port');
  assert.equal(contrebande.length, 3);
  for (const d of contrebande) { assert.match(d, /amende égale au gain/); assert.doesNotMatch(d, /saisir/); }
  for (const d of desc('censurer_media')) { assert.match(d, /Sovarka : censure normale, sans effet sur le gouvernement ni sur les indices, et jamais de scandale/); assert.doesNotMatch(d, /parti au pouvoir/); }
  const visites = desc('visiter_prisonnier');
  assert.equal(visites.length, 3, 'QHS, commissariat central et commissariats locaux');
  for (const d of visites) assert.match(d, /seuls un avocat inscrit au barreau et le conjoint du détenu/);
  // L'ordre de visite est déclaré dans les deux gabarits de commissariat.
  const bloc = id => { const i = data.indexOf("\n  '" + id + "': {"); return data.slice(i, data.indexOf("\n  },\n", i)); };
  assert.match(bloc('commissariat'), /fn:'visiter_prisonnier'/);
  assert.match(bloc('commissariat-local'), /fn:'visiter_prisonnier'/);
  // Écran : le chant de la Grange Sainte, la bénédiction et la contrebande passent par le serveur, ancien chemin seulement sans migration.
  const div = lire('plateau-divers.js');
  assert.match(div, /sbRpcVerdict\('tractorisme_chanter_hymne'/);
  assert.match(div, /sbRpcVerdict\('benediction_contact_demander'/);
  assert.equal((div.match(/PGRST202/g) || []).length >= 2, true);
  assert.match(lire('plateau-navigation.js'), /v\.amende_payee/);
  assert.doesNotMatch(lire('plateau-politique.js'), /v\.regime_delta/);
  // Demi-effet : la pastille lit « <ordre>_demi ».
  const cr = lire('plateau-chances-reelles.js');
  assert.match(cr, /r\.chances\[fn \+ '_demi'\]/);
  // Mobiliser : où qu'il soit, son syndicat ; sinon un refus expliqué.
  const orga = lire('plateau-organisations-quetes.js');
  assert.match(orga, /\(state\.organisations \|\| \[\]\)\.find\(estMien\)/);
  assert.match(orga, /Vous n'êtes membre d'aucune organisation syndicale\. Fondez-en une/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

// Corps de production de crime_contrebande (migration 20261125400000, appliquée le 25/11).
const m400 = lire('migrations/20261125400000_audit_chances_regles_lieux.sql');
const CONTREBANDE_PROD = m400.slice(m400.indexOf('CREATE OR REPLACE FUNCTION public.crime_contrebande('),
  m400.indexOf('END; $function$;', m400.indexOf('CREATE OR REPLACE FUNCTION public.crime_contrebande(')) + 'END; $function$;'.length);

const SOCLE = String.raw`
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text,
  pa integer DEFAULT 30, liquide numeric DEFAULT 0, inventory jsonb DEFAULT '[]', excommunie jsonb, effets_actifs jsonb DEFAULT '[]',
  stats jsonb DEFAULT '{}', updated_at timestamptz);
CREATE TABLE comptes_bancaires (id text PRIMARY KEY, personnage text, banque text, solde numeric, updated_at timestamptz);
CREATE TABLE crim_parametres (cle text PRIMARY KEY, valeur numeric);
CREATE TABLE souvenirs_objets (cle text PRIMARY KEY, nom text, ville_nom text, achetable boolean);
INSERT INTO souvenirs_objets VALUES ('souv_novomirsk_medaille', 'Médaille commémorative du Tractorisme', 'Novomirsk', true);
CREATE TABLE organisations (id text PRIMARY KEY, data text);
INSERT INTO organisations VALUES ('parti1', '{"pop": 50}');
CREATE TABLE ordres_generiques (fn text PRIMARY KEY, taux_reussite integer, toujours_reussi boolean DEFAULT false);
INSERT INTO ordres_generiques VALUES ('fuite_info', 60, false), ('soins_discrets', 95, false);
CREATE TABLE requetes (a text, r uuid, act text, res jsonb, PRIMARY KEY (a, r));
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION crim_param_interne(p_cle text, p_defaut numeric DEFAULT 0) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT valeur FROM crim_parametres WHERE cle = p_cle), p_defaut) $$;
CREATE FUNCTION achat_requete_ouvrir_interne(a text, r uuid, act text, prm jsonb) RETURNS jsonb LANGUAGE sql AS $$
  SELECT res FROM requetes WHERE requetes.a = $1 AND requetes.r = $2 $$;
CREATE FUNCTION achat_requete_clore_interne(a text, r uuid, act text, prm jsonb, res jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO requetes VALUES (a, r, act, res); RETURN res; END $$;
CREATE FUNCTION payer_ordre_interne(p_acteur text, p_fn text, p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v integer;
BEGIN SELECT pa INTO v FROM personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v < p_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  UPDATE personnages_donnees SET pa = pa - p_pa WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'pa', v - p_pa); END $$;
CREATE FUNCTION payer_ordre(p_acteur text, p_fn text, p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE sql AS $$
  SELECT payer_ordre_interne(p_acteur, p_fn, p_pa, p_cost) $$;
CREATE FUNCTION jets_pa_prelever_interne(p_acteur text, p_fn text, p_pa integer) RETURNS jsonb LANGUAGE sql AS $$
  SELECT payer_ordre_interne(p_acteur, p_fn, p_pa, 0) $$;
CREATE FUNCTION crim_contrebande_taux_interne(p text) RETURNS integer LANGUAGE sql AS $$ SELECT current_setting('banc.taux')::integer $$;
CREATE FUNCTION securite_malus_lieu_interne(p text) RETURNS integer LANGUAGE sql AS $$ SELECT 0 $$;
CREATE FUNCTION crime_detecter_interne(p text, acte text, b boolean) RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('banc.repere')::boolean $$;
CREATE FUNCTION crime_dis_ajuster_interne(p text, d integer) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION crime_etat_acteur_interne(p text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE OR REPLACE FUNCTION argent_debiter_interne(p_nom text, p_montant numeric, p_poches text DEFAULT 'liquide_puis_nationale'::text)
 RETURNS numeric LANGUAGE plpgsql AS $function$
DECLARE v_m numeric := round(coalesce(p_montant, 0)); v_liq numeric; v_id text; v_solde numeric;
        v_pris_l numeric := 0; v_pris_n numeric := 0;
BEGIN
  IF p_poches IS NULL OR p_poches NOT IN ('liquide', 'liquide_puis_nationale') THEN RAISE EXCEPTION 'poches_invalides'; END IF;
  IF p_nom IS NULL OR v_m <= 0 THEN RETURN 0; END IF;
  SELECT coalesce(liquide, 0) INTO v_liq FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN 0; END IF;
  v_pris_l := least(greatest(v_liq, 0), v_m);
  IF p_poches = 'liquide_puis_nationale' AND v_pris_l < v_m THEN
    SELECT id, coalesce(solde, 0) INTO v_id, v_solde FROM public.comptes_bancaires
     WHERE personnage = p_nom AND banque = 'nationale' ORDER BY id LIMIT 1 FOR UPDATE;
    IF v_id IS NOT NULL THEN v_pris_n := least(greatest(v_solde, 0), v_m - v_pris_l); END IF;
  END IF;
  IF v_pris_l > 0 THEN UPDATE public.personnages_donnees SET liquide = v_liq - v_pris_l, updated_at = now() WHERE name = p_nom; END IF;
  IF v_pris_n > 0 THEN UPDATE public.comptes_bancaires SET solde = solde - v_pris_n, updated_at = now() WHERE id = v_id; END IF;
  RETURN v_pris_l + v_pris_n;
END; $function$;
CREATE FUNCTION inventaire_deposer_interne(p_nom text, p_objet jsonb, p_automatique boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('banc.plein', true) = '1' THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  UPDATE personnages_donnees SET inventory = inventory || jsonb_build_array(p_objet) WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true); END $$;
CREATE FUNCTION souvenir_objet_interne(s souvenirs_objets) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('type', s.cle, 'name', s.nom, 'souvenir', true) $$;
CREATE FUNCTION sovarka_parti_au_pouvoir() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('banc.parti', true), '') $$;
CREATE FUNCTION sovarka_parti_pop_interne(p_parti text, p_delta numeric) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE v numeric;
BEGIN SELECT least(100, greatest(0, coalesce((data::jsonb ->> 'pop')::numeric, 0) + p_delta)) INTO v FROM organisations WHERE id = p_parti;
  UPDATE organisations SET data = jsonb_set(data::jsonb, '{pop}', to_jsonb(v))::text WHERE id = p_parti; RETURN v; END $$;
CREATE TABLE indices_villes (id text PRIMARY KEY, social numeric);
CREATE FUNCTION presse_censure_indice_interne(p_pays text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION indice_ville_ajuster_interne(p_pays text, p_ville text, p_cle text, p_delta numeric) RETURNS void LANGUAGE sql AS $$
  UPDATE indices_villes SET social = social + p_delta WHERE id = p_pays || '_' || p_ville $$;
CREATE TABLE caisses_batiments (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE FUNCTION caisse_institution_mouvement(p_id text, p_delta numeric, p_exiger_existant boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('rp.caisse_interne', true) IS DISTINCT FROM 'on' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_inexistante'); END IF;
  INSERT INTO caisses_batiments VALUES (p_id, jsonb_build_object('solde', p_delta), now())
  ON CONFLICT (id) DO UPDATE SET data = jsonb_build_object('solde', (caisses_batiments.data ->> 'solde')::numeric + p_delta);
  RETURN jsonb_build_object('ok', true); END $$;
CREATE FUNCTION crim_stat_interne(p_nom text, p_stat text, p_def numeric) RETURNS numeric LANGUAGE sql AS $$
  SELECT coalesce((SELECT (stats ->> p_stat)::numeric FROM personnages_donnees WHERE name = p_nom), p_def) $$;
CREATE FUNCTION presse_cha_effectif_interne(p_nom text) RETURNS numeric LANGUAGE sql AS $$ SELECT 0::numeric $$;
CREATE FUNCTION commissaire_jet_interne(t text, c text, b boolean) RETURNS boolean LANGUAGE sql AS $$ SELECT b $$;
CREATE FUNCTION ordres_chances_b1b_interne(a text, f text) RETURNS integer LANGUAGE sql AS $$ SELECT NULL::integer $$;
CREATE FUNCTION ordres_chances_audit_interne(a text, f text) RETURNS integer LANGUAGE sql AS $$ SELECT CASE WHEN f IN ('fuite_info', 'soins_discrets') THEN 40 END $$;
`;

// Fonctions réduites : seules les lignes d'ancrage sont recopiées mot pour mot de la production.
const ANCRES = String.raw`
CREATE FUNCTION public.jauges_ordre_executer(p_ordre text, p_requete uuid, p_contexte jsonb) RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE a record; pa_cout integer; v_detecte boolean; publication jsonb;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage();
    pa_cout:=2; v_detecte:=(a.country IS DISTINCT FROM 'soviet') AND random()<0.30;
    publication:=jsonb_build_object('scandale',v_detecte);
  IF p_ordre='censurer_media' THEN
    PERFORM public.presse_censure_indice_interne(a.country);
    publication:=coalesce(publication,'{}'::jsonb)||jsonb_build_object('indice_social',-8,'indice_social_serveur',a.country='republic');
  END IF;
  RETURN publication;
END $function$;
CREATE FUNCTION public.commissaire_enquete_mener(p_requete uuid, p_cible text, p_benediction boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  RETURN jsonb_build_object('benie', public.commissaire_jet_interne('enquete', p_cible, coalesce(p_benediction, false)));
END $function$;
CREATE FUNCTION public.filature_mener(p_requete uuid, p_cible text, p_benediction boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  RETURN jsonb_build_object('benie', public.commissaire_jet_interne('filature', p_cible, coalesce(p_benediction, false)));
END $function$;
CREATE OR REPLACE FUNCTION public.ordres_chances_lire(p_fns text[], p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); d record; f text; out jsonb := '{}'::jsonb; v jsonb; ci jsonb; m text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building INTO d FROM public.personnages_donnees WHERE name = a;
  FOREACH f IN ARRAY coalesce(p_fns[1:30], ARRAY[]::text[]) LOOP
    BEGIN
      IF f = 'se_cacher' THEN
        NULL;
      ELSIF public.ordres_chances_b1b_interne(a, f) IS NOT NULL THEN
        out := out || jsonb_build_object(f, public.ordres_chances_b1b_interne(a, f)); /* jets_b1b_chances_v1 */
      ELSIF public.ordres_chances_audit_interne(a, f) IS NOT NULL THEN /* audit_chances_soir_v1 */
        out := out || jsonb_build_object(f, public.ordres_chances_audit_interne(a, f));
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;   -- une chance illisible n'empêche jamais les autres
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'chances', out); /* chances_reelles_v1 */
END $function$
;`;

let n = 0;
const req = () => '00000000-0000-4000-8000-' + String(++n).padStart(12, '0');
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE); await db.exec(ANCRES); await db.exec(CONTREBANDE_PROD);
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, liquide, stats) VALUES
    ('Jo', 'republic', 'ville_a', 'port', 'quai', 300, '{"CHA": 12}'),
    ('Ivan', 'soviet', 'capitale', 'kolkhoze-spirituel', 'grange_sainte', 1000, '{"CHA": 10}')`);
  await db.exec(lire(MIG));
  return db;
}
const un = async (db, sql) => (await db.query(sql)).rows[0];
const moi = (db, nom) => db.exec(`SELECT set_config('banc.moi', '${nom}', false)`);

test('contrebande : un échec repéré coûte une amende égale au gain (dans la limite des fonds), la réussite porte sa valeur', async () => {
  const db = await base();
  await moi(db, 'Jo');
  await db.exec("SELECT set_config('banc.taux', '0', false); SELECT set_config('banc.repere', 'true', false)");
  let v = (await un(db, 'SELECT crime_contrebande(3, 0) AS v')).v;
  assert.equal(v.reussi, false); assert.equal(v.repere, true);
  assert.equal(Number(v.amende), 500); assert.equal(Number(v.amende_payee), 300, 'pris dans la limite du liquide');
  assert.equal(Number((await un(db, "SELECT liquide FROM personnages_donnees WHERE name = 'Jo'")).liquide), 0);
  const douane = async id => Number((await un(db, `SELECT data->>'solde' s FROM caisses_batiments WHERE id = '${id}'`))?.s ?? 0);
  assert.equal(await douane('republic_douane'), 300, 'amende versée à la caisse de la douane (Fred, 26/11)');
  // Non repéré : aucune amende.
  await db.exec("UPDATE personnages_donnees SET liquide = 900 WHERE name = 'Jo'; SELECT set_config('banc.repere', 'false', false)");
  v = (await un(db, 'SELECT crime_contrebande(3, 0) AS v')).v;
  assert.equal(Number(v.amende), 0);
  assert.equal(Number((await un(db, "SELECT liquide FROM personnages_donnees WHERE name = 'Jo'")).liquide), 900);
  // Réussite repérée : la cargaison porte sa valeur, aucune amende (la recherche seule).
  await db.exec("SELECT set_config('banc.taux', '100', false); SELECT set_config('banc.repere', 'true', false)");
  v = (await un(db, 'SELECT crime_contrebande(3, 0) AS v')).v;
  assert.equal(v.reussi, true); assert.equal(Number(v.amende), 0);
  assert.equal(Number(v.inventory.find(o => o.type === 'contrebande').valeur), 500);
  // Sovarka : le gain réglé pour Sovarka (100 PSK), compte national entamé après le liquide.
  await moi(db, 'Ivan');
  await db.exec("UPDATE personnages_donnees SET liquide = 40 WHERE name = 'Ivan'; INSERT INTO comptes_bancaires VALUES ('c1', 'Ivan', 'nationale', 1000, now())");
  await db.exec("SELECT set_config('banc.taux', '0', false)");
  v = (await un(db, 'SELECT crime_contrebande(3, 0) AS v')).v;
  assert.equal(Number(v.amende), 100); assert.equal(Number(v.amende_payee), 100);
  assert.equal(Number((await un(db, "SELECT solde FROM comptes_bancaires WHERE id = 'c1'")).solde), 940);
  assert.equal(await douane('soviet_douane'), 100, 'caisse de la douane de Sovarka');
});

test('médaille du Tractorisme : offerte au premier chant à la Grange Sainte de Novomirsk, jamais une seconde fois', async () => {
  const db = await base();
  assert.equal((await un(db, "SELECT achetable FROM souvenirs_objets WHERE cle = 'souv_novomirsk_medaille'")).achetable, false, 'plus vendue au musée');
  await moi(db, 'Jo');
  assert.equal((await un(db, `SELECT tractorisme_chanter_hymne('${req()}') AS v`)).v.raison, 'pas_a_la_grange_sainte');
  await moi(db, 'Ivan');
  let v = (await un(db, `SELECT tractorisme_chanter_hymne('${req()}') AS v`)).v;
  assert.equal(v.ok, true); assert.equal(v.medaille, true);
  assert.equal(v.message, 'Votre voix angélique a touché les dieux du Tractorisme : ils vous offrent la médaille du Tractorisme en remerciement de ce moment d\'intense émotion.');
  assert.equal(v.inventory.filter(o => o.type === 'souv_novomirsk_medaille').length, 1);
  assert.equal(Number(v.pa), 29, '1 PA payé (ordre « prier »)');
  v = (await un(db, `SELECT tractorisme_chanter_hymne('${req()}') AS v`)).v;
  assert.equal(v.ok, true); assert.equal(v.medaille, false, 'deuxième chant : rien');
  assert.equal(v.inventory.filter(o => o.type === 'souv_novomirsk_medaille').length, 1);
  // Rejeu d'une même requête : aucun double paiement.
  const r = req();
  await db.exec(`SELECT tractorisme_chanter_hymne('${r}')`); await db.exec(`SELECT tractorisme_chanter_hymne('${r}')`);
  assert.equal(Number((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Ivan'")).pa), 27);
  // Krasnov n'est pas la Grange Sainte de Novomirsk.
  await db.exec("UPDATE personnages_donnees SET current_city = 'ville_b' WHERE name = 'Ivan'");
  assert.equal((await un(db, `SELECT tractorisme_chanter_hymne('${req()}') AS v`)).v.raison, 'pas_a_la_grange_sainte');
});

test('médaille : inventaire plein au premier chant, la médaille attend le chant suivant', async () => {
  const db = await base();
  await moi(db, 'Ivan');
  await db.exec("SELECT set_config('banc.plein', '1', false)");
  let v = (await un(db, `SELECT tractorisme_chanter_hymne('${req()}') AS v`)).v;
  assert.equal(v.medaille, false); assert.equal(v.medaille_en_attente, true);
  await db.exec("SELECT set_config('banc.plein', '0', false)");
  v = (await un(db, `SELECT tractorisme_chanter_hymne('${req()}') AS v`)).v;
  assert.equal(v.medaille, true);
});

test('censure : en Sovarka aucun effet ni scandale (Fred, 26/11) ; −8 à l’indice social en Républia seulement', async () => {
  const db = await base();
  await db.exec("INSERT INTO indices_villes VALUES ('soviet_capitale', 50), ('republic_capitale', 50)");
  const social = async id => Number((await un(db, `SELECT social FROM indices_villes WHERE id = '${id}'`)).social);
  await moi(db, 'Ivan');
  for (let i = 0; i < 20; i++) {
    const v = (await un(db, `SELECT jauges_ordre_executer('censurer_media', '${req()}', '{}') AS v`)).v;
    assert.equal(v.scandale, false, 'jamais de scandale en Sovarka'); assert.equal(Number(v.indice_social), 0); assert.equal(v.regime_delta, undefined);
  }
  assert.equal(await social('soviet_capitale'), 50, 'aucun indice touché en Sovarka');
  await moi(db, 'Jo');
  const v = (await un(db, `SELECT jauges_ordre_executer('censurer_media', '${req()}', '{}') AS v`)).v;
  assert.equal(Number(v.indice_social), -8); assert.equal(await social('republic_capitale'), 42);
});

test('bénédiction : accordée au serveur (1 PA, 80 %), refusée à l’excommunié, consommée par un seul jet du commissaire', async () => {
  const db = await base();
  await moi(db, 'Jo');
  // Sans bénédiction, la déclaration de l'écran est ignorée.
  assert.equal((await un(db, `SELECT commissaire_enquete_mener('${req()}', 'Cible', true) AS v`)).v.benie, false);
  await db.exec(`UPDATE personnages_donnees SET excommunie = '{"le": 1}' WHERE name = 'Jo'`);
  assert.equal((await un(db, `SELECT benediction_contact_demander('${req()}', 'Abbé') AS v`)).v.raison, 'excommunie');
  await db.exec("UPDATE personnages_donnees SET excommunie = NULL, pa = 200 WHERE name = 'Jo'");
  let benie = false, essais = 0;
  while (!benie && essais < 60) { essais++; benie = (await un(db, `SELECT benediction_contact_demander('${req()}', 'Abbé') AS v`)).v.benie; }
  assert.equal(benie, true);
  assert.equal(Number((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa), 200 - essais, '1 PA par demande');
  assert.equal((await un(db, `SELECT filature_mener('${req()}', 'Cible', false) AS v`)).v.benie, true, 'lue au serveur, pas déclarée par l’écran');
  assert.equal((await un(db, `SELECT commissaire_enquete_mener('${req()}', 'Cible', true) AS v`)).v.benie, false, 'non cumulable : déjà consommée');
  // Expirée : sans effet.
  await db.exec("UPDATE benedictions SET consommee_le = NULL, expire_le = now() - interval '1 minute'");
  assert.equal((await un(db, `SELECT filature_mener('${req()}', 'Cible', false) AS v`)).v.benie, false);
});

test('charisme du serveur : bonus temporaires tenus au serveur compris, effets expirés ignorés, excommunication −2', async () => {
  const db = await base();
  const maintenant = Date.now();
  await db.exec(`UPDATE personnages_donnees SET effets_actifs = '[{"deltas": {"CHA": 2}, "expireA": ${maintenant + 3600000}}, {"deltas": {"CHA": 5}, "expireA": ${maintenant - 1000}}]' WHERE name = 'Jo'`);
  assert.equal(Number((await un(db, "SELECT presse_cha_effectif_interne('Jo') AS c")).c), 14);
  await db.exec(`UPDATE personnages_donnees SET excommunie = '{"le": 1}' WHERE name = 'Jo'`);
  assert.equal(Number((await un(db, "SELECT presse_cha_effectif_interne('Jo') AS c")).c), 12);
});

test('demi-effet : la chance du demi-effet suit le jet d’ordre_generique_executer', async () => {
  const db = await base();
  await moi(db, 'Jo');
  const c = (await un(db, "SELECT ordres_chances_lire(ARRAY['fuite_info', 'soins_discrets', 'se_cacher']) AS r")).r.chances;
  // taux 60 : demi-effet quand 58 < jet ≤ 76, soit 18 chances sur 100 ; taux 95 : 33,5 < jet ≤ 62, soit 29.
  assert.equal(c.fuite_info_demi, 18); assert.equal(c.soins_discrets_demi, 29);
  assert.equal(c.se_cacher_demi, undefined);
  // Vérification exhaustive contre le jet du serveur.
  for (const t of [5, 37, 60, 95, 99]) {
    let partiel = 0;
    for (let r = 1; r <= 100; r++) if (r > 100 - 0.7 * t && r <= 100 - 0.4 * t) partiel++;
    await db.exec(`UPDATE ordres_generiques SET taux_reussite = ${t} WHERE fn = 'fuite_info'`);
    assert.equal((await un(db, "SELECT ordre_generique_demi_chance_interne('fuite_info') AS d")).d, partiel, 'taux ' + t);
  }
});

test('migration rejouable : les marques empêchent un second raccord', async () => {
  const db = await base();
  await db.exec(lire(MIG));
  const d = (await un(db, "SELECT pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure) AS d")).d;
  assert.equal((d.match(/censure_sovarka_sans_effet_v1/g) || []).length, 1);
  const o = (await un(db, "SELECT pg_get_functiondef('public.ordres_chances_lire(text[],text)'::regprocedure) AS d")).d;
  assert.equal((o.match(/demi_effet_v1/g) || []).length, 1);
});
