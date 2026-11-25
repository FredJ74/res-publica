'use strict';
// Mission du soir du 25/11/2026, bloc 1A (audit des chances, points 1.1, 1.3, 1.4) : description ↔ serveur.
//  • Chaque ordre touché : la chance lue avant le clic (ordres_chances_lire) est celle que l'ordre utilise pour trancher.
//  • Règles tranchées par Fred : fraudes (2 / 1 / 3 jours), contrebande (plafond 85 %, douane sur échec et réussite, saisie
//    sur un échec repéré), évasion et rébellion (règle du serveur gardée), écouter les rumeurs chez Galina (Novomirsk),
//    inspecter les cargaisons au quai de Novomirsk, visiter un détenu (sans jet, contrôlé par le serveur).
//  • Écran : descriptions alignées, plus de pourcentage écrit en dur, « Mobiliser les membres » hors police.
// Vrai PostgreSQL local (PGlite). Les fonctions raccordées sont reproduites AVEC LEURS LIGNES D'ANCRAGE EXACTES, relevées en
// production le 25/11/2026 au soir (pg_get_functiondef, lecture seule) ; les briques voisines sont des doublures pilotées.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-audit-chances-soir-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125400000_audit_chances_regles_lieux.sql', MIG_VISITE = 'migrations/20261125410000_visiter_prisonnier.sql';

// ── Écran ────────────────────────────────────────────────────────────────────────────────────────────────────────
function ordres(fn) {
  const re = new RegExp("\\{fn: *'" + fn + "'[^\\n]*", 'g');
  return lire('data.js').match(re) || [];
}
function desc(ligne) { const m = /desc: *'((?:[^'\\]|\\.)*)'/.exec(ligne); return m ? m[1].replace(/\\'/g, "'") : ''; }

test('écran : descriptions alignées sur le serveur, aucun pourcentage de réussite écrit en dur dans le texte', () => {
  const attendus = {
    falsifier_listes_electorales: [/2 jours de détention/],
    truquer_depouillement: [/3 jours de détention/],
    bourrer_urnes: [/1 jour de détention/],
    contrebande_port: [/au plus 85 %/, /Réussie ou non, la douane peut vous repérer/, /amende égale au gain/],
    tentative_evasion: [/\+1 jour de détention \(2 en Sovarka\)/, /amende de 500/],
    se_rebeller: [/-15 DIS, \+4 jours de détention/, /ni transfert, ni grilles endommagées/],
    visiter_prisonnier: [/aucun jet/, /une visite par jour et par détenu/, /seuls un avocat inscrit au barreau et le conjoint du détenu/, /conversation privée/],
    voler_materiel_chantier: [/vrai vol/, /agent de sécurité posté sur le chantier le protège/],
    fuite_info: [/Aucun document ne sort des archives/],
    mobiliser: [/organisation syndicale/],
    acheter_ghb: [/aucun jet/], acheter_vipere: [/aucun jet/], emprunter: [/Aucun jet/], campagne_securite: [/Aucun jet/, /3 POP/],
  };
  for (const [fn, motifs] of Object.entries(attendus)) {
    const l = ordres(fn);
    assert.ok(l.length > 0, fn + ' absent de data.js');
    for (const x of l) for (const m of motifs) assert.match(desc(x), m, fn + ' : ' + desc(x));
  }
  for (const fn of ['voler_materiel_chantier', 'lancer_rumeur_cible', 'marchander_vote', 'contrebande_port', 'corrompre_douanier', 'tentative_evasion', 'se_rebeller']) {
    for (const x of ordres(fn)) {
      assert.doesNotMatch(desc(x), /parodique|Succ[eè]s \(\d+ ?%\)|Chance \d+ ?%|[+-]\d+ ?% (modificateur|zone)|DIS\/10|transferement|transfert au QHS|7 jours/i, fn + ' : ' + desc(x));
    }
  }
  assert.match(lire('plateau-politique.js'), /rateAffiche = \(rate !== null && rpChances && typeof rpChances\.sansTauxEcrit === 'function' && rpChances\.sansTauxEcrit\(o\.fn\)\) \? null : rate;/);
  const cr = lire('plateau-chances-reelles.js');
  for (const fn of ['bourrer_urnes', 'falsifier_listes_electorales', 'truquer_depouillement', 'contrebande_port', 'tentative_evasion', 'se_rebeller',
    'ecouter_rumeurs', 'inspecter_cargaisons', 'voler_materiel_chantier', 'fuite_info', 'soins_discrets']) assert.match(cr, new RegExp("'" + fn + "'"));
  assert.doesNotMatch(lire('plateau-personnage.js'), /Math\.max\(5, 30 - malusISN\)/, 'plus de « 30 − ISN » calculé à l\'écran');
  assert.match(lire('plateau-personnage.js'), /ordres_chances_lire', \{ p_fns: \['incendier'\] \}/);
});

test('écran : « Mobiliser les membres » ouvre l\'organisation syndicale, plus l\'intervention de police', () => {
  const r = lire('plateau-router.js');
  assert.match(r, /if \(fn === 'mobiliser'\) \{ doMobiliserMembresSyndicat\(\); return; \}/);
  assert.doesNotMatch(r, /fn === 'mobiliser'\) \{ doMobiliserPolice/);
  const o = lire('plateau-organisations-quetes.js');
  assert.match(o, /function doMobiliserMembresSyndicat\(\) \{[\s\S]*?o\.type === 'syndicale'[\s\S]*?ouvrirOrdresOrga\(orga\.id\);/);
  assert.match(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'), /\('mobiliser',0,0\)/);
});

test('écran : visite au parloir lue et décidée au serveur, repli sans débit', () => {
  const j = lire('plateau-justice-economie.js');
  const bloc = j.slice(j.indexOf('async function ouvrirVisiterPrisonnier'), j.indexOf('function getBudgetInstitution'));
  assert.match(bloc, /sbRpc\('prison_visite_detenus'/);
  assert.match(bloc, /sbRpc\('prison_visiter', \{ p_requete: crypto\.randomUUID\(\), p_detenu: nom \}\)/);
  assert.match(bloc, /ouvrirConversationAvec\(nom\)/);
  assert.match(bloc, /Le parloir est fermé/);
  assert.doesNotMatch(bloc, /deduireCoutOrdre|Visite effectuée|prisonniers_qhs/);
});

test('écran : contrebande, évasion et rébellion disent ce que le serveur renvoie', () => {
  const n = lire('plateau-navigation.js'); const b = n.slice(n.indexOf('async function doContrebandePort'), n.indexOf('async function doBlocusPortuaire'));
  assert.match(b, /v\.repere/); assert.match(b, /v\.saisie > 0/);
  const j = lire('plateau-justice-economie.js');
  assert.match(j, /const joursEv = Number\(r\.jours_ajoutes \|\| 0\);/);
  assert.match(j, /const joursReb = Number\(r\.jours_ajoutes \|\| 0\);/);
  assert.doesNotMatch(j, /\+1 jour de detention, -' \+ amende/);
});

// ── Serveur (PGlite) ─────────────────────────────────────────────────────────────────────────────────────────────
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text,
  career text, reputation_criminelle integer DEFAULT 0, resources jsonb DEFAULT '{}', stats jsonb DEFAULT '{}', pa integer DEFAULT 10,
  inventory jsonb DEFAULT '[]', employes jsonb DEFAULT '[]', requisition jsonb, day integer DEFAULT 10, hp integer DEFAULT 100,
  effets_actifs jsonb DEFAULT '[]', liquide numeric DEFAULT 0, arg numeric DEFAULT 0, est_emprisonne jsonb, domicile jsonb, recherche jsonb);
CREATE TABLE indices_villes (id text PRIMARY KEY, data jsonb);
CREATE TABLE banc (cle text PRIMARY KEY, valeur text);
CREATE TABLE ordres_couts (fn text, pa integer, cost integer);
INSERT INTO ordres_couts VALUES ('mobiliser', 2, 0), ('visiter_prisonnier', 1, 0);
CREATE TABLE ordres_generiques (fn text PRIMARY KEY, taux_reussite integer, toujours_reussi boolean DEFAULT false);
INSERT INTO ordres_generiques VALUES ('fuite_info', 60, false), ('soins_discrets', 95, false);
CREATE TABLE pnj_membres (leader_pj text, statut text, car_int integer);
CREATE TABLE detentions (id text PRIMARY KEY, country text, city text, nom text, raison text, jour_debut integer, jour_fin integer, qhs boolean,
  created_at timestamptz DEFAULT now(), mode_fin text, jour_fin_effective integer, derniere_tentative_evasion date, motifs jsonb);
CREATE TABLE avocats_barreau (nom text, pays text);
CREATE TABLE mariages (id text, conjoint1 text, conjoint2 text, statut text, dissous_at timestamptz);
CREATE TABLE messages_chat (id text PRIMARY KEY, conversation_id text, auteur text, message text, salon boolean, created_at timestamptz);
CREATE TABLE cycles_electoraux (country text, poste_id text, city text, data text);
CREATE TABLE fraudes_electorales (id text, country text, poste_id text, city text, cycle_debut bigint, type text, auteur text, candidat text,
  delta_voix integer, etat text, detectabilite_pct integer, created_at timestamptz);
CREATE TABLE chronique_nationale (id text, country text, type text, city text, personnages jsonb, libelle text, data jsonb);
CREATE TABLE journal_banc (quoi text, qui text, n integer);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION b(p text) RETURNS text LANGUAGE sql AS $$ SELECT valeur FROM banc WHERE cle = p $$;
CREATE FUNCTION crim_param_interne(p_cle text, p_defaut numeric DEFAULT 0) RETURNS numeric LANGUAGE sql STABLE AS $$ SELECT p_defaut $$;
CREATE FUNCTION crime_malus_isn_interne(p_pays text, p_ville text) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT coalesce(b('isn')::integer, 5) $$;
CREATE FUNCTION securite_malus_lieu_interne(p text) RETURNS integer LANGUAGE sql AS $$ SELECT coalesce(b('malus')::integer, 0) $$;
CREATE FUNCTION crime_dis_ajuster_interne(p text, d integer) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION crime_detecter_interne(p_nom text, p_acte text, p_sel boolean, p_r text DEFAULT NULL) RETURNS boolean LANGUAGE sql AS $$
  INSERT INTO journal_banc VALUES ('detecter', p_nom, 1); SELECT coalesce(b('repere')::boolean, false) $$;
CREATE FUNCTION crime_etat_acteur_interne(p text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION payer_ordre(p_nom text, p_fn text, p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE sql AS $$
  INSERT INTO journal_banc VALUES ('payer', p_fn, p_pa); SELECT jsonb_build_object('ok', true, 'pa', 9) $$;
CREATE FUNCTION payer_ordre_interne(p_nom text, p_fn text, p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT payer_ordre(p_nom, p_fn, p_pa, p_cost) $$;
CREATE FUNCTION achat_requete_ouvrir_interne(a text, r uuid, f text, p jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT NULL::jsonb $$;
CREATE FUNCTION achat_requete_clore_interne(a text, r uuid, f text, p jsonb, v jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT v $$;
CREATE FUNCTION detention_active(p_nom text) RETURNS TABLE(id text, country text, city text, jour_debut integer, jour_fin integer, qhs boolean)
LANGUAGE sql STABLE AS $$ SELECT d.id, d.country, d.city, d.jour_debut, d.jour_fin, coalesce(d.qhs, false) FROM detentions d
  WHERE d.nom = p_nom AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL ORDER BY d.created_at DESC LIMIT 1 $$;
CREATE FUNCTION crim_grilles_bonus_interne(p text, v text) RETURNS integer LANGUAGE sql AS $$ SELECT coalesce(b('grilles')::integer, 0) $$;
CREATE FUNCTION crim_corruption_evasion_bonus_interne(n text, d text) RETURNS integer LANGUAGE sql AS $$ SELECT 0 $$;
CREATE FUNCTION crim_peine_jours_interne(a text, p text) RETURNS integer LANGUAGE sql AS $$
  SELECT CASE a WHEN 'rebellion_matee' THEN 4 WHEN 'evasion_echouee' THEN 1 ELSE 2 END * CASE WHEN p = 'soviet' THEN 2 ELSE 1 END $$;
CREATE FUNCTION detention_prolonger_interne(n text, m jsonb, x boolean) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('jours_ajoutes', (m -> 0 ->> 'jours')::integer, 'jour_fin', 20) $$;
CREATE FUNCTION amende_imposer_interne(i text, p text, n text, m integer) RETURNS integer LANGUAGE sql AS $$ SELECT m $$;
CREATE FUNCTION detention_clore_interne(n text, m text) RETURNS void LANGUAGE sql AS $$ UPDATE detentions SET mode_fin = m WHERE nom = n $$;
CREATE FUNCTION recherche_inscrire(e jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok": true}'::jsonb $$;
CREATE FUNCTION prison_grilles_endommager_interne(p text, v text, d integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('degats', d) $$;
CREATE FUNCTION sante_param(c text, d numeric) RETURNS numeric LANGUAGE sql AS $$ SELECT d $$;
CREATE FUNCTION sante_perte_combat_interne(hp integer, p integer) RETURNS integer LANGUAGE sql AS $$ SELECT p $$;
CREATE FUNCTION poste_exerce(n text) RETURNS text LANGUAGE sql AS $$ SELECT b('poste') $$;
CREATE FUNCTION detention_ouvrir_interne(n text, r text, j integer, v text, p text, m jsonb, a text, s text) RETURNS jsonb LANGUAGE sql AS $$
  INSERT INTO journal_banc VALUES ('detention', n, j); SELECT jsonb_build_object('ok', true, 'detention_id', 'd-' || n) $$;
CREATE FUNCTION jour_de_jeu_pays(p text) RETURNS integer LANGUAGE sql AS $$ SELECT 10 $$;
CREATE FUNCTION crim_chance_bornee_interne(p_nom text, p_brut numeric, p_min numeric, p_max numeric, p_brouillard boolean) RETURNS integer
LANGUAGE sql STABLE AS $$ SELECT greatest(p_min, least(p_max, p_brut - securite_malus_lieu_interne(p_nom)))::integer $$;
CREATE FUNCTION crim_corruption_qhs_etat_interne(p text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"detenu_qhs": true, "taux": 40}'::jsonb $$;
CREATE FUNCTION crim_stat_interne(p_nom text, p_cle text, p_defaut numeric) RETURNS numeric LANGUAGE sql STABLE AS $$ SELECT p_defaut $$;
CREATE FUNCTION crim_mode_action_interne(p text) RETURNS text LANGUAGE sql AS $$ SELECT 'decouvert' $$;
CREATE FUNCTION crim_incendie_taux_interne(d numeric, c boolean, k text, bi boolean, o boolean, ca boolean) RETURNS integer LANGUAGE sql AS $$
  SELECT 30 + CASE WHEN bi THEN 15 ELSE 0 END $$;
CREATE FUNCTION inventaire_quantite(i jsonb, k text) RETURNS numeric LANGUAGE sql AS $$
  SELECT count(*) FROM jsonb_array_elements(coalesce(i, '[]')) o WHERE o ->> 'type' = k $$;
CREATE FUNCTION crim_climat_actif_interne(t text, p text, v text) RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;

-- ── Fonctions de production raccordées (lignes d'ancrage exactes) ──
CREATE FUNCTION public.fraude_electorale_tenter(p_type text, p_poste text, p_city text, p_candidat text, p_sens integer DEFAULT 1)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_fn text; v_pa integer; v_base integer; v_jours integer; v_paie jsonb; v_dis numeric; v_taux integer; v_roll integer; v_det jsonb;
BEGIN
  v_moi := public.mon_personnage();
  SELECT country, current_city, resources INTO d FROM public.personnages_donnees WHERE name = v_moi;
  CASE p_type
    WHEN 'falsification_listes' THEN v_fn := 'falsifier_listes_electorales'; v_pa := 2; v_base := 70; v_jours := 20;
    WHEN 'bourrage_urnes' THEN v_fn := 'bourrer_urnes'; v_pa := 1; v_base := 60; v_jours := 1;
    WHEN 'trucage_depouillement' THEN v_fn := 'truquer_depouillement'; v_pa := 2; v_base := 75; v_jours := 20;
    ELSE RETURN jsonb_build_object('ok', false, 'raison', 'fraude_inconnue');
  END CASE;
  v_paie := public.payer_ordre(v_moi, v_fn, v_pa, 0);
  v_dis := coalesce(CASE WHEN jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric END, 50);
  v_taux := greatest(5, least(95, v_base + round((v_dis - 50) / 5)::integer));
  v_roll := coalesce(public.b('jet')::integer, floor(random() * 100)::integer + 1);
  IF v_roll <= v_taux THEN RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux); END IF;
  v_det := public.detention_ouvrir_interne(v_moi, 'x', v_jours, 'capitale', d.country, '[]'::jsonb, v_moi, 'fraude_electorale');
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'jours', v_jours, 'taux', v_taux);
END; $function$;

CREATE FUNCTION public.crime_contrebande(p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN RETURN '{}'::jsonb; END $$;

CREATE FUNCTION public.detention_tenter_evasion(p_pa integer, p_cost integer, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_det record; v_paie jsonb;
  v_ville text; v_pays text; v_isn numeric; v_dup numeric; v_taux integer; v_bonus integer := 0;
  v_jet integer; v_prol jsonb; v_amende integer;
BEGIN
  v_moi := public.mon_personnage();
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_detenu'); END IF;
  v_paie := public.payer_ordre_interne(v_moi, 'tentative_evasion', p_pa, p_cost);

  v_pays := coalesce(v_det.country, p.country, 'republic');
  v_ville := coalesce(v_det.city, p.current_city, 'capitale');
  v_isn := coalesce((SELECT CASE WHEN jsonb_typeof(data -> 'isn') = 'number' THEN (data ->> 'isn')::numeric END
                       FROM public.indices_villes WHERE id = v_pays || '_' || v_ville), 30);
  v_dup := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'DUP') = 'number' THEN (p.stats ->> 'DUP')::numeric END, 8);
  v_taux := greatest(2, least(40, round(10 + (v_dup - 10) * 2 - (v_isn - 45) / 3
                                        + CASE WHEN p_benediction THEN 5 ELSE 0 END)))::integer;
  -- Bonus du déserteur : appliqué APRÈS le plafond ordinaire de 40 %, maximum absolu 90 %.
  IF p.requisition ->> 'statut' = 'deserteur' THEN
    v_bonus := least(50, greatest(0, coalesce(p.day, 1) - coalesce(v_det.jour_debut, coalesce(p.day, 1))) * 10);
    v_taux := least(90, v_taux + v_bonus);
  END IF;
  v_bonus := public.crim_grilles_bonus_interne(v_pays, v_ville); /* crim_grilles_evasion_v1 */
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;
  v_bonus := public.crim_corruption_evasion_bonus_interne(v_moi, v_det.id); /* crim_corruption_evasion_v1 */
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;
  v_jet := 101;
  v_prol := public.detention_prolonger_interne(v_moi, jsonb_build_array(jsonb_build_object('jours', public.crim_peine_jours_interne('evasion_echouee', v_pays) /* crim_bareme_evasion2_v1 */)), false);
  v_amende := public.amende_imposer_interne('e', v_pays, v_moi, 500);
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet, 'amende', v_amende, 'jours_ajoutes', v_prol -> 'jours_ajoutes');
END $function$;

CREATE FUNCTION public.detention_se_rebeller(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_det record; v_paie jsonb; v_pays text; v_vol numeric; v_for numeric; v_taux integer; v_jours integer; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_detenu'); END IF;
  v_paie := public.payer_ordre_interne(v_moi, 'se_rebeller', p_pa, p_cost);
  v_pays := coalesce(v_det.country, p.country, 'republic');
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'VOL') = 'number' THEN (p.stats ->> 'VOL')::numeric END, 8);
  SELECT greatest(0, least(20, coalesce(CASE WHEN jsonb_typeof(e -> 'stats' -> 'FOR') = 'number'
                                             THEN (e -> 'stats' ->> 'FOR')::numeric END, 0)))
    INTO v_for
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes) = 'array' THEN p.employes ELSE '[]'::jsonb END) e
   WHERE e ->> 'job' = 'codetenu' LIMIT 1;
  v_taux := least(60, floor(v_vol * 3 + floor(coalesce(v_for, 0) / 2)))::integer;
  v_jours := public.crim_peine_jours_interne('rebellion_matee', v_pays);
  v_r := public.detention_prolonger_interne(v_moi, jsonb_build_array(jsonb_build_object('jours', v_jours)), false);
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jours_ajoutes', v_r -> 'jours_ajoutes', 'qhs', false, 'grilles', NULL);
END $function$;

CREATE FUNCTION public.rumeur_ecoute_jauges_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a public.personnages_donnees;taux integer;cout_pa integer;source text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur;
 IF a.current_city='capitale'AND a.current_building='hotel-republica'AND a.current_room='restaurant'THEN taux:=95;cout_pa:=0;
 ELSIF a.current_city='capitale'AND a.current_building='hotel-republica'AND a.current_room='bar'THEN taux:=90;cout_pa:=0;source:='Marco';
 ELSIF a.current_city='capitale'AND a.current_building='assemblee'AND a.current_room='couloirs'THEN taux:=70;cout_pa:=1;
 ELSIF a.country='republic'AND a.current_city='ville_a'AND a.current_building='bar-des-pecheurs'AND a.current_room='salle_bar'THEN taux:=85;cout_pa:=0;source:='Marin Dulac';
 ELSIF a.country='republic'AND a.current_city='ville_a'AND a.current_building='capitaine-sauvage'AND a.current_room='salle_principale'THEN taux:=95;cout_pa:=0;
 ELSIF a.country='soviet'AND a.current_city='ville_a'AND a.current_building='hotel-mineur'AND a.current_room='hall_mineur'THEN taux:=90;cout_pa:=0;source:='Aldar Zhamsuev';
 ELSE RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 RETURN jsonb_build_object('ok',true,'taux',taux,'pa_cout',cout_pa,'source_rumeur',source);
END;$function$;

CREATE FUNCTION public.jauges_ordre_executer(p_ordre text, p_requete uuid, p_contexte jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a public.personnages_donnees; v_int numeric; v_taux integer;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage();
  CASE p_ordre
  WHEN 'inspecter_cargaisons' THEN
    IF NOT ((a.current_building='port-sainte-marie' AND a.current_room='quai_principal')
       OR (a.current_building='port-sovarka' AND a.current_room='quai_sovarka')
       OR (a.current_building='port-al-madina' AND a.current_room='quai_al_khalija')) THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
    v_int:=8;
    v_taux:=greatest(5,80+floor(v_int/10)::integer
      +CASE WHEN a.country='soviet' THEN 15 ELSE 0 END);
  END CASE;
  RETURN jsonb_build_object('ok', true, 'taux', v_taux);
END $function$;

CREATE FUNCTION public.election_contester(p_poste text, p_city text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; v_pays text; v_int numeric; v_taux integer;
BEGIN
  v_moi := public.mon_personnage();
  SELECT country, coalesce(CASE WHEN jsonb_typeof(stats -> 'INT') = 'number' THEN (stats ->> 'INT')::numeric END, 8)
    INTO v_pays, v_int FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, least(95, round(60 + 5 * (v_int - 13))::integer));
  RETURN jsonb_build_object('ok', true, 'taux', v_taux);
END $function$;

CREATE FUNCTION public.crime_falsifier(p_doc text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; m record; v_taux integer;
BEGIN
  v_moi := public.mon_personnage();
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, 45 - public.crime_malus_isn_interne(m.country, m.current_city));
  RETURN jsonb_build_object('ok', true, 'taux', v_taux);
END $function$;

CREATE FUNCTION public.crime_voler_materiaux(p_terrain text, p_matiere text, p_pa integer, p_cost integer, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a public.personnages_donnees; v_isn numeric; v_rep integer; v_bonus numeric; v_ville text;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  v_ville := coalesce(a.current_city, 'capitale');
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes WHERE id = a.country || '_' || v_ville), 30);
  v_rep := coalesce(a.reputation_criminelle, 0);
  v_bonus := (coalesce((a.stats ->> 'DUP')::numeric, 8) - 10) * 2 - (v_isn - 45) / 3
             + CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END
             + CASE WHEN p_benediction THEN 5 ELSE 0 END;
  RETURN jsonb_build_object('ok', true, 'bonus', v_bonus, 'chance', greatest(0, least(100, round(50 + v_bonus - public.securite_malus_lieu_interne(a.name)))));
END; $function$;

CREATE FUNCTION public.ordres_chances_lire(p_fns text[], p_cible text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); f text; out jsonb := '{}'::jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOREACH f IN ARRAY coalesce(p_fns[1:30], ARRAY[]::text[]) LOOP
    BEGIN
      IF f = 'se_cacher' THEN
        out := out || jsonb_build_object(f, 80);
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;   -- une chance illisible n'empêche jamais les autres
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'chances', out); /* chances_reelles_v1 */
END $$;
`;

const corps = f => lire(f).replace(/^BEGIN;$/m, '').replace(/^COMMIT;$/m, '');
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(corps(MIG));
  await db.exec(corps(MIG_VISITE));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
const moi = (db, n) => db.exec(`SELECT set_config('banc.moi', '${n}', false)`);
const reglage = (db, cle, v) => db.query('INSERT INTO banc VALUES ($1, $2) ON CONFLICT (cle) DO UPDATE SET valeur = excluded.valeur', [cle, v === null ? null : String(v)]);

test('serveur : migration rejouable, raccords présents, mobiliser à 0 PA', async () => {
  const db = await base();
  await db.exec(corps(MIG));
  for (const [fn, m] of [['fraude_electorale_tenter(text,text,text,text,integer)', 'audit_chances_fraude_jours_v1'],
    ['fraude_electorale_tenter(text,text,text,text,integer)', 'audit_chances_fraude_taux_v1'], ['crime_contrebande(integer,integer)', 'audit_chances_contrebande_v1'],
    ['detention_tenter_evasion(integer,integer,boolean)', 'audit_chances_evasion_v1'], ['detention_tenter_evasion(integer,integer,boolean)', 'crim_grilles_evasion_v1'],
    ['detention_se_rebeller(integer,integer)', 'audit_chances_rebellion_v1'], ['rumeur_ecoute_jauges_interne(text)', 'audit_chances_poissonniere_v1'],
    ['jauges_ordre_executer(text,uuid,jsonb)', 'audit_chances_port_novomirsk_v1'], ['jauges_ordre_executer(text,uuid,jsonb)', 'audit_chances_inspection_v1'],
    ['election_contester(text,text,integer,integer)', 'audit_chances_contester_v1'], ['crime_falsifier(text,integer,integer)', 'audit_chances_falsifier_v1'],
    ['crime_voler_materiaux(text,text,integer,integer,boolean)', 'audit_chances_vol_chantier_v1'], ['ordres_chances_lire(text[],text)', 'audit_chances_soir_v1']]) {
    const r = await un(db, `SELECT position($1 in pg_get_functiondef('public.${fn}'::regprocedure)) > 0 AS ok`, [m]);
    assert.equal(r.ok, true, fn + ' ' + m);
  }
  assert.deepEqual((await db.query("SELECT pa, cost FROM ordres_couts WHERE fn = 'mobiliser'")).rows, [{ pa: 0, cost: 0 }]);
});

test('serveur : fraudes — échec 2 jours (listes), 1 jour (urnes), 3 jours (dépouillement) ; chance lue = chance de l\'ordre', async () => {
  const db = await base();
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, resources) VALUES ('F', 'republic', 'capitale', '{"dis": 65}')`);
  await moi(db, 'F'); await reglage(db, 'jet', 100);
  const lu = (await un(db, "SELECT ordres_chances_lire(ARRAY['bourrer_urnes','falsifier_listes_electorales','truquer_depouillement']) AS r")).r.chances;
  for (const [type, fn, jours] of [['falsification_listes', 'falsifier_listes_electorales', 2], ['bourrage_urnes', 'bourrer_urnes', 1], ['trucage_depouillement', 'truquer_depouillement', 3]]) {
    const v = (await un(db, 'SELECT fraude_electorale_tenter($1, $2, NULL, $3) AS v', [type, 'maire', 'X'])).v;
    assert.equal(v.reussi, false); assert.equal(v.jours, jours, type);
    assert.equal(lu[fn], v.taux, fn);
  }
  assert.equal(lu.bourrer_urnes, 63); assert.equal(lu.falsifier_listes_electorales, 73); assert.equal(lu.truquer_depouillement, 78);
});

test('serveur : contrebande — plafond 85 %, douane sur réussite comme sur échec, saisie sur un échec repéré', async () => {
  const db = await base();
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, resources, stats, inventory) VALUES
    ('C', 'narco', 'capitale', '{"dis": 90}', '{"DUP": 20}', '[{"id": "x1", "type": "contrebande", "name": "Cargaison de contrebande"}, {"id": "y", "type": "pain"}]')`);
  await moi(db, 'C'); await reglage(db, 'isn', 0);
  assert.equal((await un(db, "SELECT crim_contrebande_taux_interne('C') AS t")).t, 85, 'plafond 85');
  assert.equal((await un(db, "SELECT ordres_chances_lire(ARRAY['contrebande_port']) AS r")).r.chances.contrebande_port, 85);
  await reglage(db, 'malus', 10);
  assert.equal((await un(db, "SELECT ordres_chances_lire(ARRAY['contrebande_port']) AS r")).r.chances.contrebande_port, 75, 'dissuasion déduite');
  await reglage(db, 'malus', 0);
  let echecRepere = 0, reussiteRepere = 0;
  await reglage(db, 'repere', true);
  for (let i = 0; i < 60; i++) {
    const v = (await un(db, 'SELECT crime_contrebande(3, 0) AS v')).v;
    assert.equal(v.taux, 85); assert.equal(v.reussi, v.jet <= v.taux);
    assert.equal(v.repere, true, 'la douane est consultée à chaque tentative');
    const nb = (await un(db, "SELECT count(*)::int AS n FROM personnages_donnees, jsonb_array_elements(inventory) o WHERE name = 'C' AND o ->> 'type' = 'contrebande'")).n;
    if (!v.reussi) { echecRepere++; assert.equal(nb, 0, 'échec repéré : contrebande saisie'); assert.ok(v.saisie >= 0); }
    else { reussiteRepere++; assert.ok(nb >= 1, 'réussite repérée : la cargaison reste'); }
  }
  assert.ok(echecRepere > 0 && reussiteRepere > 0, 'les deux issues ont été vues');
  const pain = (await un(db, "SELECT count(*)::int AS n FROM personnages_donnees, jsonb_array_elements(inventory) o WHERE name = 'C' AND o ->> 'type' = 'pain'")).n;
  assert.equal(pain, 1, 'seule la contrebande est saisie');
  const det = (await un(db, "SELECT count(*)::int AS n FROM journal_banc WHERE quoi = 'detecter'")).n;
  assert.equal(det, 60);
});

test('serveur : évasion et rébellion — la chance lue est celle de l\'ordre ; échecs selon la règle gardée', async () => {
  const db = await base();
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, stats, employes) VALUES
    ('E', 'republic', 'capitale', '{"DUP": 16, "VOL": 14}', '[{"job": "codetenu", "stats": {"FOR": 13}}]'),
    ('S', 'soviet', 'capitale', '{"DUP": 9, "VOL": 25}', '[]');
    INSERT INTO indices_villes VALUES ('republic_capitale', '{"isn": 30}'), ('soviet_capitale', '{"isn": 60}');
    INSERT INTO detentions (id, country, city, nom, jour_debut, jour_fin, qhs) VALUES ('d1', 'republic', 'capitale', 'E', 8, 15, false), ('d2', 'soviet', 'capitale', 'S', 8, 15, false);`);
  for (const [n, jEv, jReb] of [['E', 1, 4], ['S', 2, 8]]) {
    await moi(db, n);
    const lu = (await un(db, "SELECT ordres_chances_lire(ARRAY['tentative_evasion','se_rebeller']) AS r")).r.chances;
    const ev = (await un(db, 'SELECT detention_tenter_evasion(3, 0, false) AS v')).v;
    assert.equal(lu.tentative_evasion, ev.taux, n + ' évasion'); assert.equal(ev.jours_ajoutes, jEv); assert.equal(ev.amende, 500);
    await db.exec(`UPDATE detentions SET mode_fin = NULL WHERE nom = '${n}'`);
    const rb = (await un(db, 'SELECT detention_se_rebeller(1, 0) AS v')).v;
    assert.equal(lu.se_rebeller, rb.taux, n + ' rébellion'); assert.equal(rb.jours_ajoutes, jReb); assert.equal(rb.qhs, false); assert.equal(rb.grilles, null);
  }
  await moi(db, 'E');
  const lu = (await un(db, "SELECT ordres_chances_lire(ARRAY['tentative_evasion','se_rebeller']) AS r")).r.chances;
  assert.equal(lu.tentative_evasion, 27); assert.equal(lu.se_rebeller, 48);
  await reglage(db, 'grilles', 30);
  assert.equal((await un(db, "SELECT detention_evasion_taux_interne('E') AS t")).t, 57, 'grilles endommagées : au-delà de 40, au plus 90');
});

test('serveur : écouter les rumeurs chez Galina (Novomirsk), lieux inchangés ailleurs', async () => {
  const db = await base();
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room) VALUES
    ('G', 'soviet', 'capitale', 'poissonniere-novomirsk', 'etal_poissonniere'), ('H', 'republic', 'capitale', 'assemblee', 'couloirs'),
    ('X', 'soviet', 'capitale', 'marche', 'etal')`);
  const g = (await un(db, "SELECT rumeur_ecoute_jauges_interne('G') AS v")).v;
  assert.deepEqual([g.ok, g.taux, g.pa_cout, g.source_rumeur], [true, 95, 0, 'Galina Karpova']);
  const h = (await un(db, "SELECT rumeur_ecoute_jauges_interne('H') AS v")).v;
  assert.deepEqual([h.taux, h.pa_cout, h.source_rumeur], [70, 1, null]);
  assert.equal((await un(db, "SELECT rumeur_ecoute_jauges_interne('X') AS v")).v.raison, 'pas_sur_place');
  await moi(db, 'G');
  assert.equal((await un(db, "SELECT ordres_chances_lire(ARRAY['ecouter_rumeurs']) AS r")).r.chances.ecouter_rumeurs, 95);
});

test('serveur : inspecter les cargaisons au quai de Novomirsk ; contester, falsifier, voler sur un chantier : même chance', async () => {
  const db = await base();
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, stats, reputation_criminelle) VALUES
    ('I', 'soviet', 'capitale', 'port-novomirsk', 'quai_sovarka', '{"INT": 17, "DUP": 14}', 45);
    INSERT INTO pnj_membres VALUES ('I', 'actif', 11);
    INSERT INTO indices_villes VALUES ('soviet_capitale', '{"isn": 51}');`);
  await moi(db, 'I'); await reglage(db, 'malus', 12);
  const v = (await un(db, "SELECT jauges_ordre_executer('inspecter_cargaisons', gen_random_uuid(), '{}') AS v")).v;
  assert.equal(v.ok, true, 'quai de Novomirsk accepté');
  const lu = (await un(db, "SELECT ordres_chances_lire(ARRAY['inspecter_cargaisons','contester_resultats','falsifier_document','voler_materiel_chantier','corrompre_fonct','fuite_info','soins_discrets','incendier','neutraliser']) AS r")).r.chances;
  assert.equal(lu.inspecter_cargaisons, v.taux); assert.equal(v.taux, 96);
  assert.equal(lu.contester_resultats, (await un(db, "SELECT election_contester('maire', NULL, 2, 200) AS v")).v.taux);
  assert.equal(lu.falsifier_document, (await un(db, "SELECT crime_falsifier('faux_contrat', 3, 300) AS v")).v.taux - 12);
  assert.equal(lu.voler_materiel_chantier, Number((await un(db, "SELECT crime_voler_materiaux('t', 'bois', 2, 0) AS v")).v.chance));
  assert.equal(lu.corrompre_fonct, 28);
  assert.equal(lu.fuite_info, undefined, 'en Sovarka, la fuite est un acte sans jet');
  assert.equal(lu.soins_discrets, 38); assert.equal(lu.incendier, 18);
  assert.equal(lu.neutraliser, undefined);
  await db.exec("UPDATE personnages_donnees SET country = 'republic' WHERE name = 'I'");
  assert.equal((await un(db, "SELECT ordres_chances_lire(ARRAY['fuite_info']) AS r")).r.chances.fuite_info, 24);
});

test('serveur : visiter un détenu — cette prison, une visite par jour, QHS réservé à l\'avocat et à la famille, conversation privée', async () => {
  const db = await base();
  await db.exec(`INSERT INTO personnages_donnees (name, country, current_city, current_building) VALUES
    ('Visiteur', 'republic', 'ville_a', 'commissariat-local'), ('Avocate', 'republic', 'qhs', 'qhs-prison'), ('Epoux', 'republic', 'qhs', 'qhs-prison'),
    ('Curieux', 'republic', 'qhs', 'qhs-prison'), ('Detenu', 'republic', 'ville_a', 'commissariat-local'), ('Caid', 'republic', 'qhs', 'qhs-prison'),
    ('Ailleurs', 'republic', 'capitale', 'commissariat');
    INSERT INTO detentions (id, country, city, nom, raison, qhs) VALUES ('p1', 'republic', 'ville_a', 'Detenu', 'Vol', false), ('p2', 'republic', 'qhs', 'Caid', 'Meurtre', true);
    INSERT INTO avocats_barreau VALUES ('Avocate', 'republic');
    INSERT INTO mariages VALUES ('m1', 'Caid', 'Epoux', 'actif', NULL);`);
  const visiter = async (n, d) => { await moi(db, n); return (await un(db, 'SELECT prison_visiter(gen_random_uuid(), $1) AS v', [d])).v; };
  await moi(db, 'Visiteur');
  const liste = (await un(db, 'SELECT prison_visite_detenus() AS v')).v;
  assert.deepEqual(liste.detenus.map(x => x.nom), ['Detenu'], 'seuls les détenus de cette prison');
  const v1 = await visiter('Visiteur', 'Detenu');
  assert.equal(v1.ok, true); assert.equal(v1.conversation, 'Detenu__Visiteur');
  assert.equal((await un(db, "SELECT message FROM messages_chat WHERE conversation_id = 'Detenu__Visiteur'")).message, 'Visite au parloir.');
  assert.equal((await visiter('Visiteur', 'Detenu')).raison, 'deja_visite_aujourdhui');
  assert.equal((await visiter('Ailleurs', 'Detenu')).raison, 'pas_dans_cette_prison');
  assert.equal((await visiter('Curieux', 'Caid')).raison, 'qhs_avocat_famille');
  assert.equal((await visiter('Avocate', 'Caid')).ok, true);
  assert.equal((await visiter('Epoux', 'Caid')).ok, true);
  assert.equal((await visiter('Detenu', 'Caid')).raison, 'visiteur_detenu');
  const payes = (await un(db, "SELECT count(*)::int AS n, min(n) AS pa FROM journal_banc WHERE quoi = 'payer' AND qui = 'visiter_prisonnier'"));
  assert.equal(payes.n, 3, 'payé seulement pour les visites acceptées'); assert.equal(payes.pa, 1);
  await moi(db, 'Curieux');
  const l2 = (await un(db, 'SELECT prison_visite_detenus() AS v')).v.detenus;
  assert.deepEqual(l2.map(x => [x.nom, x.autorise]), [['Caid', false]]);
  const priv = (await un(db, "SELECT has_function_privilege('anon', 'public.prison_visiter(uuid,text)', 'EXECUTE') AS a, has_function_privilege('authenticated', 'public.prison_visiter(uuid,text)', 'EXECUTE') AS b")).a;
  assert.equal(priv, false);
});
