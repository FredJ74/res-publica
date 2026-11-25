'use strict';
// Mission du soir du 25/11/2026, bloc 1.2 : les jets encore tirés dans le navigateur passent au serveur, même formule, coût
// payé dans la même transaction que le jet. Migration 20261125500000 dans PGlite, sur un socle minimal qui reprend MOT POUR
// MOT les corps de production de corruption_presse_tenter, scandale_tenter et ordres_chances_lire (ancrages des
// remplacements contrôlés), et une jauges_ordre_executer réduite qui porte le même ancrage.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-jets-serveur-b1b-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125500000_jets_navigateur_serveur.sql';

test('écran : chaque ordre appelle sa porte serveur et garde l’ancien chemin seulement si la fonction est absente', () => {
  const pnj = lire('plateau-pnj.js'), com = lire('plateau-communication.js'), rum = lire('plateau-actions-illegales-rumeurs.js');
  const jus = lire('plateau-justice-economie.js'), pol = lire('plateau-politique.js');
  assert.match(pnj, /sbRpcVerdict\('presse_lobbying_tenter'/);
  assert.match(com, /sbRpcVerdict\('loge_frapper'/);
  assert.match(jus, /sbRpcVerdict\('commissaire_enquete_mener', \{ p_requete:/);
  assert.match(jus, /sbRpcVerdict\('filature_mener', \{ p_requete:/);
  for (const [nom, js] of [['article', pnj], ['loge', com], ['commissaire', jus]]) {
    assert.match(js, /PGRST202/, nom + ' : repli sur l’ancien chemin seulement si la migration n’est pas posée');
  }
  // Corruption et scandale : quand le serveur a payé (paye), l’écran ne repaie pas.
  assert.equal((rum.match(/res\.paye === true/g) || []).length, 2);
  // Censure et dossiers : l’écran lit l’indice et le dossier rendus par le serveur.
  assert.match(pol, /v\.indice_social_serveur/);
  assert.match(pol, /r\.dossier_rang/);
  // Chances réelles : les cinq ordres sont demandés au serveur.
  const cr = lire('plateau-chances-reelles.js');
  for (const fn of ['article', 'etouffer', 'demander_parler_loge', 'corrompre_journaliste', 'fabriquer_scandale']) assert.match(cr, new RegExp("'" + fn + "'"));
});

test('descriptions : plus de pourcentage fixe pour ces ordres, conséquences fidèles au serveur', () => {
  const data = lire('data.js');
  const desc = fn => [...data.matchAll(new RegExp("fn:'" + fn + "'[^\\n]*?desc:(['\"])((?:\\\\.|(?!\\1).)*)\\1", 'g'))].map(m => m[2]);
  for (const fn of ['article', 'etouffer', 'demander_parler_loge', 'corrompre_journaliste', 'fabriquer_scandale']) {
    const ds = desc(fn);
    assert.ok(ds.length > 0, fn + ' : description trouvée');
    for (const d of ds) assert.doesNotMatch(d, /\d+ ?%/, fn + ' : aucun pourcentage écrit en dur');
  }
  for (const d of desc('article')) assert.match(d, /1 PA est pris même si la rédaction refuse/);
  for (const d of desc('etouffer')) assert.match(d, /1 PA est pris même si la rédaction refuse/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

// Corps de production (lus le 25/11/2026), recopiés mot pour mot : ce sont eux que les remplacements contrôlés visent.
const CORRUPTION_PROD = String.raw`CREATE OR REPLACE FUNCTION public.corruption_presse_tenter(p_requete text, p_joueur text, p_affaire_ref text, p_option text, p_malus_isn integer DEFAULT 0, p_instant timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_a    record;
  v_jour date;
  v_taux integer;
  v_jet  integer;
  v_ok   boolean;
  v_r    jsonb; /* crim_corruption_presse_decl_v1 */
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'corruption_presse');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_option NOT IN ('etouffer', 'favorable') OR COALESCE(btrim(p_affaire_ref), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT pa, liquide, banque, stats, resources, country, current_city INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  -- L'affaire doit etre eligible MAINTENANT : du jour, et pas encore publiee.
  SELECT * INTO v_a FROM public.corruption_presse_affaires(v_p.country, p_instant) a
   WHERE a.affaire_ref = p_affaire_ref;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'affaire_non_eligible'));
  END IF;

  -- Ressources verifiees AVANT le jet : une reussite ne doit jamais mener a un etat impossible.
  IF COALESCE(v_p.pa, 0) < 2 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;
  IF COALESCE(v_p.liquide, 0) + COALESCE(v_p.banque, 0) < 500 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'));
  END IF;

  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  -- Formule propre a cet ordre : 30 + CHA + floor(INF/4) - malus ISN, borne [5, 85].
  v_taux := LEAST(85, GREATEST(5,
    30 + floor(public.assemblee_stat_base(v_p.stats, 'CHA'))::integer
       + floor(GREATEST(0, COALESCE(CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number'
               THEN (v_p.resources ->> 'inf')::numeric END, 0)) / 4)::integer
       - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0)))));
  IF EXISTS (SELECT 1 FROM public.corruptions_presse WHERE affaire_ref = p_affaire_ref AND corrupteur = p_joueur) THEN /* crim_corruption_presse_v1 */
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente'));
  END IF;
  v_r := public.crim_corrompre_pnj_interne(p_joueur, 'corrompre_journaliste', v_taux,
           jsonb_build_object('min', 5, 'max', 85, 'pnj', 'journaliste', 'affaire_ref', p_affaire_ref));
  v_jet := ceil((v_r ->> 'jet')::numeric)::integer; v_taux := (v_r ->> 'taux')::integer;
  v_ok := coalesce((v_r ->> 'reussi')::boolean, false);

  -- Une seule tentative par affaire et par corrupteur : c'est l'insertion qui fait foi, donc aussi
  -- contre le double-clic et la concurrence. La TRACE existe que le journaliste accepte ou refuse.
  INSERT INTO public.corruptions_presse (affaire_ref, affaire_type, affaire_pj, corrupteur, option,
                                         reussite, jet, taux, pays, jour_paris)
  VALUES (p_affaire_ref, v_a.affaire_type, v_a.affaire_pj, p_joueur, p_option,
          v_ok, v_jet, v_taux, v_p.country, v_jour)
  ON CONFLICT (affaire_ref, corrupteur) DO NOTHING;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente'));
  END IF;

  -- Trace fouillable par « Mener une enquete », en reussite comme en refus. Aucune rumeur n'est
  -- creee ici : le jeu enregistre le fait, son exploitation viendra des systemes d'enquete.
  BEGIN
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
    VALUES ('corrpresse-' || md5(p_affaire_ref || '|' || p_joueur), p_joueur, v_a.affaire_pj,
            CASE WHEN v_ok THEN 'corruption_presse' ELSE 'corruption_presse_refusee' END,
            v_p.country, v_p.current_city,
            0, 0, false);
  EXCEPTION WHEN OTHERS THEN
    NULL;   -- la trace detaillee reste dans corruptions_presse : un echec ici n'annule pas l'acte
  END;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', v_ok, 'jet', v_jet, 'taux', v_taux, 'denonce', coalesce((v_r ->> 'denonce')::boolean, false), /* crim_corruption_presse_retour_v1 */
    'option', p_option, 'affaire_ref', p_affaire_ref, 'affaire_pj', v_a.affaire_pj,
    'resume', v_a.resume,
    'pa', CASE WHEN v_ok THEN 2 ELSE 0 END, 'cout', CASE WHEN v_ok THEN 500 ELSE 0 END));
END;
$function$;`;

const SCANDALE_PROD = String.raw`CREATE OR REPLACE FUNCTION public.scandale_tenter(p_requete text, p_joueur text, p_cible text, p_accusation text, p_malus_isn integer DEFAULT 0, p_instant timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_c    record;
  v_jour date;
  v_taux integer;
  v_jet  integer;
  v_id   bigint;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'scandale');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur OR COALESCE(btrim(p_accusation), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT pa, liquide, banque, career, poste, country, current_city INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;
  SELECT country INTO v_c FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;

  -- Ressources verifiees AVANT le jet : une acceptation ne doit jamais conduire a un etat impossible.
  IF COALESCE(v_p.pa, 0) < 3 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;
  IF COALESCE(v_p.liquide, 0) + COALESCE(v_p.banque, 0) < 800 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'));
  END IF;

  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;
  -- La tentative quotidienne est consommee ici, avant meme le jet : refus de la redaction compris.
  INSERT INTO public.scandales_tentatives (auteur, jour_paris, cible)
  VALUES (p_joueur, v_jour, p_cible)
  ON CONFLICT (auteur, jour_paris) DO NOTHING;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente_aujourdhui'));
  END IF;

  v_taux := public.scandale_taux(v_p.career, v_p.poste, p_malus_isn);
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'accepte', false, 'jet', v_jet, 'taux', v_taux));
  END IF;

  INSERT INTO public.scandales_presse (auteur, cible, pays, ville, accusation, jour_paris)
  VALUES (p_joueur, p_cible, v_c.country, v_p.current_city, btrim(p_accusation), v_jour)
  RETURNING id INTO v_id;
  UPDATE public.scandales_tentatives SET accepte = true WHERE auteur = p_joueur AND jour_paris = v_jour;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'accepte', true, 'jet', v_jet, 'taux', v_taux,
    'scandale_id', v_id, 'pa', 3, 'cout', 800));
END;
$function$;`;

// ordres_chances_lire de 20261125130000 (appliquée) : on en extrait le corps tel quel.
const MIG130 = lire('migrations/20261125130000_ordres_chances_reelles.sql');
const extraire = (sql, debut, fin) => { const i = sql.indexOf(debut); const j = sql.indexOf(fin, i); return sql.slice(i, j + fin.length); };
const CHANCES_LIRE = extraire(MIG130, 'CREATE OR REPLACE FUNCTION public.ordres_chances_lire', 'END $$;');
const BORNE = extraire(MIG130, 'CREATE OR REPLACE FUNCTION public.crim_taux_borne_interne', '$$;');
const BORNEE = extraire(MIG130, 'CREATE OR REPLACE FUNCTION public.crim_chance_bornee_interne', 'END $$;');

const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, pa integer DEFAULT 20, liquide numeric DEFAULT 0, arg numeric DEFAULT 0,
  country text DEFAULT 'republic', current_city text DEFAULT 'capitale', current_building text, career text, poste jsonb,
  stats jsonb DEFAULT '{"CHA":13}', resources jsonb DEFAULT '{"inf":0,"dis":50}', excommunie jsonb);
CREATE TABLE comptes_bancaires (id text PRIMARY KEY, personnage text, banque text, solde numeric, updated_at timestamptz);
CREATE VIEW personnages AS SELECT d.*, coalesce((SELECT solde FROM comptes_bancaires c WHERE c.personnage = d.name AND c.banque = 'nationale'), 0) AS banque FROM personnages_donnees d;
CREATE TABLE ordres_couts (fn text, pa integer, cost integer, PRIMARY KEY (fn, pa, cost));
INSERT INTO ordres_couts VALUES ('article',1,500),('etouffer',1,1000),('demander_parler_loge',1,0),('corrompre_journaliste',2,500),
  ('fabriquer_scandale',3,800),('mener_enquete',2,250),('organiser_filature',2,150),('censurer_media',2,0),('consulter_dossiers_gouv',2,0);
CREATE TABLE tribune_articles_etouffes (id text PRIMARY KEY, cible_type text, cible_value text, cible_label text, country text,
  created_at timestamptz DEFAULT now(), expire_le timestamptz);
CREATE TABLE chronique_nationale (id text PRIMARY KEY, country text, type text, city text, personnages jsonb, libelle text, data jsonb,
  source_ref text, created_at timestamptz DEFAULT now());
CREATE TABLE organisations (id text PRIMARY KEY, data text, country_origine text);
CREATE TABLE blocus (pays text, ville text, batiment text, fn text);
CREATE TABLE caisses (id text PRIMARY KEY, data jsonb);
CREATE TABLE caisses_inst (id text PRIMARY KEY, solde numeric);
CREATE TABLE requetes (acteur text, requete text, action text, resultat jsonb, PRIMARY KEY (acteur, requete));
CREATE TABLE indices_villes (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE actions_tracables (id text PRIMARY KEY, auteur text, cible text, type_action text, country text, city text, jour integer,
  jour_expiration integer, decouvert boolean DEFAULT false);
CREATE TABLE corruptions_presse (affaire_ref text, affaire_type text, affaire_pj text, corrupteur text, option text, reussite boolean,
  jet integer, taux integer, pays text, jour_paris date, PRIMARY KEY (affaire_ref, corrupteur));
CREATE TABLE scandales_tentatives (auteur text, jour_paris date, cible text, accepte boolean, PRIMARY KEY (auteur, jour_paris));
CREATE TABLE scandales_presse (id bigserial PRIMARY KEY, auteur text, cible text, pays text, ville text, accusation text, jour_paris date);
CREATE TABLE commissaire_actes (quoi text, cible text);

CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION exiger_acteur(p text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION accueil_ordre_paye_interne(a text, f text, p integer) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION blocus_ordre_refuse_interne(a text, f text) RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM personnages_donnees p JOIN blocus b ON b.pays = p.country AND b.ville = p.current_city
                  AND b.batiment = p.current_building AND b.fn = f WHERE p.name = a) $$;
CREATE FUNCTION crim_stat_interne(p_nom text, p_cle text, p_defaut numeric) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT CASE
      WHEN p_cle = 'dis' AND jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric
      WHEN p_cle <> 'dis' AND coalesce(d.stats ->> p_cle, '') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN (d.stats ->> p_cle)::numeric END
    FROM personnages_donnees d WHERE d.name = p_nom), p_defaut) $$;
CREATE FUNCTION assemblee_stat_base(s jsonb, c text) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$ SELECT coalesce((s ->> c)::numeric, 8) $$;
CREATE FUNCTION crime_malus_isn_interne(p_pays text, p_ville text) RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN v <= 20 THEN 0 WHEN v <= 40 THEN 5 WHEN v <= 60 THEN 10 WHEN v <= 80 THEN 15 ELSE 25 END
    FROM (SELECT coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM indices_villes WHERE id = p_pays || '_' || coalesce(p_ville, 'capitale')), 30) AS v) x $$;
CREATE FUNCTION scandale_taux(p_career text, p_poste jsonb, p_malus_isn integer) RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT GREATEST(5, 35 + CASE WHEN p_career = 'press' THEN 15 WHEN COALESCE(p_poste ->> 'id', '') = 'min_info' THEN 10 ELSE 0 END
    - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0))))::integer $$;
CREATE FUNCTION climat_nom_ville_interne(p_pays text, p_ville text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays WHEN 'republic' THEN CASE p_ville WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie' WHEN 'ville_b' THEN 'Montrouge' END
                     ELSE CASE p_ville WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' END END $$;
CREATE FUNCTION achat_requete_ouvrir_interne(a text, r uuid, act text, prm jsonb) RETURNS jsonb LANGUAGE sql AS $$
  SELECT resultat || '{"rejeu":true}'::jsonb FROM requetes WHERE acteur = a AND requete = r::text $$;
CREATE FUNCTION achat_requete_clore_interne(a text, r uuid, act text, prm jsonb, res jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO requetes VALUES (a, r::text, act, res);
  RETURN res || jsonb_build_object('paie', (SELECT jsonb_build_object('pa', pa, 'liquide', liquide, 'arg', arg) FROM personnages_donnees WHERE name = a)); END $$;
CREATE FUNCTION assemblee_requete_ouvrir(r text, a text, act text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT resultat || '{"rejeu":true}'::jsonb FROM requetes WHERE acteur = a AND requete = r $$;
CREATE FUNCTION assemblee_requete_clore(r text, res jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO requetes VALUES (mon_personnage(), r, 'assemblee', res); RETURN res; END $$;
-- payer_ordre_interne réduite : tarif déclaré exact, PA, fonds (liquide puis nationale), blocus.
CREATE FUNCTION payer_ordre_interne(p_acteur text, p_fn text, p_pa integer, p_cost integer) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE d record; v_s numeric; v_l numeric;
BEGIN
  IF blocus_ordre_refuse_interne(p_acteur, p_fn) THEN RETURN jsonb_build_object('ok', false, 'raison', 'blocus_syndical'); END IF;
  IF NOT EXISTS (SELECT 1 FROM ordres_couts WHERE fn = p_fn AND pa = p_pa AND cost = p_cost) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  SELECT * INTO d FROM personnages_donnees WHERE name = p_acteur FOR UPDATE;
  SELECT coalesce(solde, 0) INTO v_s FROM comptes_bancaires WHERE personnage = p_acteur AND banque = 'nationale';
  IF d.pa < p_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF d.liquide + coalesce(v_s, 0) < p_cost THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  v_l := least(d.liquide, p_cost);
  UPDATE personnages_donnees SET pa = pa - p_pa, liquide = liquide - v_l, arg = arg - p_cost WHERE name = p_acteur;
  IF p_cost > v_l THEN UPDATE comptes_bancaires SET solde = solde - (p_cost - v_l) WHERE personnage = p_acteur AND banque = 'nationale'; END IF;
  RETURN jsonb_build_object('ok', true, 'pa_preleves', p_pa, 'montant_preleve', p_cost);
END $$;
CREATE FUNCTION batiment_caisse_mouvement(p_pays text, p_ville text, p_building text, p_souscle text, p_delta numeric,
  p_stock_cle text DEFAULT NULL, p_stock numeric DEFAULT 0, p_stock_max numeric DEFAULT NULL, p_exiger_existant boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_id text := p_pays || '_' || p_ville || '_' || p_building || '/' || p_souscle;
BEGIN
  IF p_building IS NULL OR NOT EXISTS (SELECT 1 FROM caisses WHERE id = v_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente'); END IF;
  UPDATE caisses SET data = jsonb_build_object('caisse', (data ->> 'caisse')::numeric + p_delta) WHERE id = v_id;
  RETURN jsonb_build_object('ok', true);
END $$;
CREATE FUNCTION acteur_poste_courant() RETURNS TABLE (nom text, poste_id text, poste_city text, pays text) LANGUAGE sql STABLE AS $$
  SELECT name, poste ->> 'id', poste ->> 'city', country FROM personnages_donnees WHERE name = mon_personnage() $$;
CREATE FUNCTION caisse_refus_autorite(p_caisse text, p_pays text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT NULL::text $$;
CREATE FUNCTION caisse_institution_mouvement(p_caisse text, p_delta numeric, p_x boolean) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM caisses_inst WHERE id = p_caisse AND solde + p_delta >= 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  UPDATE caisses_inst SET solde = solde + p_delta WHERE id = p_caisse; RETURN jsonb_build_object('ok', true);
END $$;
CREATE FUNCTION commissaire_jet_interne(p_ordre text, p_cible text, p_benediction boolean) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_taux integer := coalesce(nullif(current_setting('banc.taux_commissaire', true), '')::integer, 50); v_roll integer := floor(random() * 100)::integer + 1;
BEGIN RETURN jsonb_build_object('ok', true, 'abouti', v_roll <= v_taux, 'taux', v_taux, 'jet', v_roll); END $$;
CREATE FUNCTION commissaire_enqueter(p_cible text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO commissaire_actes VALUES ('enquete', p_cible); RETURN jsonb_build_object('ok', true, 'decision', 'enquete_ouverte'); END $$;
CREATE FUNCTION filature_deplacements(p_cible text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO commissaire_actes VALUES ('filature', p_cible); RETURN jsonb_build_object('ok', true, 'deplacements', '[]'::jsonb); END $$;
CREATE FUNCTION indice_ville_ajuster_interne(p_pays text, p_ville text, p_cle text, p_delta integer) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_pays IS DISTINCT FROM 'republic' THEN RETURN; END IF;
  UPDATE indices_villes SET data = data || jsonb_build_object(p_cle, greatest(0, least(100, coalesce((data ->> p_cle)::integer, 50) + p_delta))) WHERE id = p_pays || '_' || p_ville; END $$;
CREATE FUNCTION corruption_presse_affaires(p text, i timestamptz) RETURNS TABLE (affaire_ref text, affaire_type text, affaire_pj text, resume text)
  LANGUAGE sql AS $$ SELECT 'aff1', 'jugement', 'Cible', 'Une affaire' $$;
CREATE FUNCTION crim_corrompre_pnj_interne(a text, acte text, t numeric, prm jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_t integer := crim_taux_borne_interne(t, 0, 100, '{}'::jsonb, securite_malus_lieu_interne(a)); v_j integer := floor(random() * 100)::integer + 1;
BEGIN RETURN jsonb_build_object('taux', v_t, 'jet', v_j, 'reussi', v_j <= v_t, 'denonce', false); END $$;
CREATE FUNCTION securite_malus_lieu_interne(a text) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT 0 $$;
CREATE FUNCTION se_cacher_chances() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":false}'::jsonb $$;
-- jauges_ordre_executer réduite : deux ordres, paiement, puis l'ancrage de production.
CREATE FUNCTION jauges_ordre_executer(p_ordre text, p_requete uuid, p_contexte jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $function$
DECLARE a public.personnages_donnees; pa_cout integer; argent_cout integer:=0; paiement jsonb; publication jsonb; v_detecte boolean;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
  CASE p_ordre
  WHEN 'censurer_media' THEN
    pa_cout:=2; v_detecte:=(a.country IS DISTINCT FROM 'soviet') AND random()<0.30;
    publication:=jsonb_build_object('scandale',v_detecte,'media',btrim(p_contexte->>'media'));
  WHEN 'consulter_dossiers_gouv' THEN
    pa_cout:=2;
  ELSE RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');
  END CASE;
  IF pa_cout IS NOT NULL THEN
    paiement:=public.payer_ordre_interne(a.name,p_ordre,pa_cout,argent_cout);
    IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
  END IF;
  -- Relire après le paiement : aucun snapshot antérieur ne remplace les PA ou soldes.
  SELECT * INTO a FROM public.personnages_donnees WHERE name=a.name FOR UPDATE;
  RETURN coalesce(publication,'{}'::jsonb)||jsonb_build_object('ok',true,'pa',a.pa);
END;$function$;
`;

async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(BORNE); await db.exec(BORNEE); await db.exec(CHANCES_LIRE);
  await db.exec(CORRUPTION_PROD); await db.exec(SCANDALE_PROD);
  await db.exec(`INSERT INTO personnages_donnees (name, pa, liquide, arg, country, current_city, current_building, stats) VALUES
      ('Jo', 20, 5000, 5000, 'republic', 'capitale', 'tribune', '{"CHA":13}'),
      ('Cible', 20, 0, 0, 'soviet', 'capitale', NULL, '{"CHA":8}'),
      ('Com', 20, 0, 0, 'republic', 'capitale', 'commissariat', '{"CHA":8,"PER":13}');
    UPDATE personnages_donnees SET poste = '{"id":"commissaire","city":"capitale"}' WHERE name = 'Com';
    INSERT INTO caisses VALUES ('republic_capitale_tribune/redaction', '{"caisse":0}');
    INSERT INTO caisses_inst VALUES ('republic_commissariat_capitale', 1000);
    INSERT INTO indices_villes VALUES ('republic_capitale', '{"social":50,"isn":70}'), ('republic_ville_a', '{"social":50}'), ('republic_ville_b', '{"social":5}');`);
  await db.exec(lire(MIG));
  return db;
}
const moi = (db, qui) => db.query("SELECT set_config('banc.moi', $1, false)", [qui]);
const un = async (db, sql, p = []) => (await db.query(sql, p)).rows[0];
const uuid = () => require('node:crypto').randomUUID();

test('article favorable : réussite = 1 PA + 500 à la rédaction + chronique ; échec = 1 PA seulement ; rejeu sans double effet', async () => {
  const db = await base(); await moi(db, 'Jo');
  const vus = { succes: 0, echec: 0 };
  for (let i = 0; i < 60 && (!vus.succes || !vus.echec); i++) {
    // PA et argent remis à niveau : dix réussites de suite (75 % chacune) épuisaient les 5 000 et faisaient échouer le
    // banc au hasard sur « fonds insuffisants » (25/11).
    await db.exec("UPDATE personnages_donnees SET pa = 20, liquide = 5000, arg = 5000 WHERE name = 'Jo'");
    const avant = await un(db, "SELECT pa, liquide FROM personnages_donnees WHERE name = 'Jo'");
    const caisseAvant = Number((await un(db, "SELECT data->>'caisse' c FROM caisses")).c);
    const req = uuid();
    const r = (await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'article', 'pj', 'Cible', 'Cible', 'Un <angle>') r", [req])).r;
    assert.equal(r.ok, true); assert.equal(r.taux, 75, 'CHA 13 : 75 % (même formule que l’écran)');
    const apres = await un(db, "SELECT pa, liquide FROM personnages_donnees WHERE name = 'Jo'");
    assert.equal(apres.pa, avant.pa - 1, '1 PA pris dans les deux cas');
    const caisse = Number((await un(db, "SELECT data->>'caisse' c FROM caisses")).c);
    if (r.succes) {
      vus.succes++;
      assert.equal(Number(apres.liquide), Number(avant.liquide) - 500); assert.equal(caisse, caisseAvant + 500); assert.equal(r.cout, 500);
      const c = await un(db, 'SELECT * FROM chronique_nationale WHERE id = $1', ['chronique-lobbying_article_favorable-' + req]);
      assert.equal(c.country, 'soviet', 'pays de la cible, pas du demandeur');
      assert.match(c.libelle, /Un &lt;angle&gt;/, 'angle échappé');
    } else {
      vus.echec++;
      assert.equal(Number(apres.liquide), Number(avant.liquide), 'échec : aucun argent'); assert.equal(caisse, caisseAvant); assert.equal(r.cout, 0);
    }
    const rejeu = (await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'article', 'pj', 'Cible', 'Cible', 'Un <angle>') r", [req])).r;
    assert.equal(rejeu.rejeu, true);
    assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa, apres.pa, 'le rejeu ne repaie pas');
  }
  assert.ok(vus.succes && vus.echec, 'les deux issues ont été observées');
});

test('étouffement : 7 jours, puis l’article contre la même cible part de 10 % ; refus avant le jet sans fonds ni PA', async () => {
  const db = await base(); await moi(db, 'Jo');
  let r;
  do { r = (await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'etouffer', 'pays', 'soviet', 'Sovarka', NULL) r", [uuid()])).r; } while (!r.succes);
  assert.equal(r.taux, 70);
  const e = await un(db, "SELECT round(extract(epoch FROM expire_le - now()) / 86400) j FROM tribune_articles_etouffes");
  assert.equal(Number(e.j), 7);
  const a = (await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'article', 'pays', 'soviet', 'Sovarka', 'x') r", [uuid()])).r;
  assert.equal(a.taux, 10, 'base 10 si un étouffement protège la cible');
  await db.exec("UPDATE personnages_donnees SET liquide = 100 WHERE name = 'Jo'");
  const f = (await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'etouffer', 'pj', 'Cible', 'Cible', NULL) r", [uuid()])).r;
  assert.equal(f.raison, 'fonds_insuffisants');
  const pa = (await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa;
  await db.exec("UPDATE personnages_donnees SET liquide = 5000, pa = 0 WHERE name = 'Jo'");
  assert.equal((await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'article', 'pj', 'Cible', 'Cible', 'x') r", [uuid()])).r.raison, 'pa_insuffisants');
  assert.ok(pa >= 0);
  assert.equal((await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'article', 'pj', 'Cible', 'Cible', '  ') r", [uuid()])).r.raison, 'angle_requis');
});

test('article : sans caisse de rédaction, l’argent est rendu (comme l’écran) ; excommunié : −2 CHA', async () => {
  const db = await base(); await moi(db, 'Jo');
  await db.exec("DELETE FROM caisses; UPDATE personnages_donnees SET excommunie = '{\"le\":1}' WHERE name = 'Jo'");
  let r;
  do { r = (await un(db, "SELECT presse_lobbying_tenter($1::uuid, 'article', 'pj', 'Cible', 'Cible', 'x') r", [uuid()])).r; } while (!r.succes);
  assert.equal(r.taux, 71, '75 + 2 × (11 − 13)');
  assert.equal(r.redaction_ok, false); assert.equal(r.cout, 0);
  assert.equal(Number((await un(db, "SELECT liquide FROM personnages_donnees WHERE name = 'Jo'")).liquide), 5000, 'argent rendu');
});

test('loge : 1 PA, réponse à 95 %, rejeu sans double prélèvement', async () => {
  const db = await base(); await moi(db, 'Jo');
  const req = uuid();
  const r = (await un(db, 'SELECT loge_frapper($1::uuid) r', [req])).r;
  assert.equal(r.ok, true); assert.equal(r.taux, 95); assert.equal(typeof r.reponse, 'boolean');
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa, 19);
  await un(db, 'SELECT loge_frapper($1::uuid) r', [req]);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa, 19);
});

test('corruption d’un journaliste : malus ISN lu au serveur (celui de l’écran ignoré), accord payé dans la fonction', async () => {
  const db = await base(); await moi(db, 'Jo');
  // ISN 70 à Luthécia → malus 15 ; l’écran annonce 0 : ignoré. 30 + 13 + 0 − 15 = 28.
  let r, n = 0;
  do {
    await db.exec('DELETE FROM corruptions_presse; DELETE FROM requetes');
    r = (await un(db, "SELECT corruption_presse_tenter($1, 'Jo', 'aff1', 'etouffer', 0) r", ['c' + (n++)])).r;
    assert.equal(r.taux, 28);
  } while (!r.reussi && n < 80);
  assert.equal(r.reussi, true); assert.equal(r.paye, true); assert.equal(r.cout, 500);
  assert.equal(r.paie.pa, 18);
  assert.equal(Number((await un(db, "SELECT data->>'caisse' c FROM caisses")).c), 500, 'versé à la rédaction');
  const chance = (await un(db, "SELECT ordres_chances_lire(ARRAY['corrompre_journaliste','fabriquer_scandale','article','etouffer','demander_parler_loge']) r")).r;
  assert.deepEqual(chance.chances, { corrompre_journaliste: 28, fabriquer_scandale: 20, article: 75, etouffer: 70, demander_parler_loge: 95 });
});

test('corruption refusée : rien n’est prélevé ; blocus : refus avant le jet', async () => {
  const db = await base(); await moi(db, 'Jo');
  let r, n = 0;
  do {
    // Une tentative acceptée paie 2 PA : on repart de 20 PA avant chaque essai, sinon un accord tiré avant le refus
    // (28 % de chances par essai) faisait lire 18 PA et échouer le banc au hasard (signalé par Fred, 25/11).
    await db.exec("DELETE FROM corruptions_presse; DELETE FROM requetes; UPDATE personnages_donnees SET pa = 20 WHERE name = 'Jo'");
    r = (await un(db, "SELECT corruption_presse_tenter($1, 'Jo', 'aff1', 'etouffer', 0) r", ['d' + (n++)])).r;
    if (!r.reussi) assert.equal(r.pa, 0, 'refus : aucun PA annoncé');
  } while (r.reussi && n < 80);
  assert.equal(r.reussi, false); assert.equal(r.paye, false);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa, 20);
  await db.exec("INSERT INTO blocus VALUES ('republic', 'capitale', 'tribune', 'corrompre_journaliste'); DELETE FROM corruptions_presse");
  assert.equal((await un(db, "SELECT corruption_presse_tenter('b1', 'Jo', 'aff1', 'etouffer', 0) r")).r.raison, 'blocus_syndical');
});

test('scandale : malus ISN du serveur, acceptation payée (3 PA, 800 à la rédaction), refus gratuit', async () => {
  const db = await base(); await moi(db, 'Jo');
  let r, n = 0;
  do {
    await db.exec('DELETE FROM scandales_tentatives; DELETE FROM requetes');
    r = (await un(db, "SELECT scandale_tenter($1, 'Jo', 'Cible', 'Il ment', 0) r", ['s' + (n++)])).r;
    assert.equal(r.taux, 20, '35 − 15 (ISN 70 lu au serveur)');
    if (!r.accepte) assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Jo'")).pa, 20, 'refus : rien de prélevé');
  } while (!r.accepte && n < 120);
  assert.equal(r.paye, true); assert.equal(r.cout, 800); assert.equal(r.paie.pa, 17);
  assert.equal(Number((await un(db, "SELECT data->>'caisse' c FROM caisses")).c), 800);
});

test('enquête et filature : caisse du commissariat et 2 PA pris AVANT le jet, une seule fois par requête ; sans trace = infructueuse', async () => {
  const db = await base(); await moi(db, 'Com');
  const r = (await un(db, "SELECT commissaire_enquete_mener($1::uuid, 'Cible', false) r", [uuid()])).r;
  assert.equal(r.sans_trace, true); assert.equal(r.abouti, false); assert.equal(r.paye, true);
  assert.equal(Number((await un(db, "SELECT solde FROM caisses_inst")).solde), 750);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Com'")).pa, 18);
  await db.exec("INSERT INTO actions_tracables VALUES ('t1', 'Cible', NULL, 'vol', 'republic', 'capitale', 1, 9, false)");
  await db.exec("SELECT set_config('banc.taux_commissaire', '100', false)");
  const req = uuid();
  const e = (await un(db, "SELECT commissaire_enquete_mener($1::uuid, 'Cible', false) r", [req])).r;
  assert.equal(e.abouti, true); assert.equal(e.decision, 'enquete_ouverte');
  await un(db, "SELECT commissaire_enquete_mener($1::uuid, 'Cible', false) r", [req]);
  assert.equal(Number((await un(db, "SELECT solde FROM caisses_inst")).solde), 500, 'rejeu : pas de second prélèvement');
  await db.exec("SELECT set_config('banc.taux_commissaire', '0', false)");
  const f = (await un(db, "SELECT filature_mener($1::uuid, 'Cible', false) r", [uuid()])).r;
  assert.equal(f.abouti, false, 'échec : la filature est payée quand même, plus de relance gratuite');
  assert.equal(Number((await un(db, "SELECT solde FROM caisses_inst")).solde), 350);
  assert.equal((await un(db, "SELECT count(*)::int n FROM commissaire_actes WHERE quoi = 'filature'")).n, 0);
  await db.exec("UPDATE personnages_donnees SET current_city = 'ville_a' WHERE name = 'Com'");
  assert.equal((await un(db, "SELECT filature_mener($1::uuid, 'Cible', false) r", [uuid()])).r.raison, 'hors_juridiction');
  await db.exec("UPDATE personnages_donnees SET current_city = 'capitale'; UPDATE caisses_inst SET solde = 10");
  assert.equal((await un(db, "SELECT filature_mener($1::uuid, 'Cible', false) r", [uuid()])).r.raison, 'caisse_institution_insuffisante');
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Com'")).pa, 14, 'caisse vide : aucun PA pris');
});

test('censure : −8 à l’indice social des villes de Républia après paiement ; dossiers : tirage du serveur', async () => {
  const db = await base(); await moi(db, 'Jo');
  const c = (await un(db, "SELECT jauges_ordre_executer('censurer_media', $1::uuid, '{\"media\":\"La Tribune\"}') r", [uuid()])).r;
  assert.equal(c.ok, true); assert.equal(c.indice_social, -8); assert.equal(c.indice_social_serveur, true);
  const iv = (await db.query("SELECT id, (data->>'social')::int s FROM indices_villes ORDER BY id")).rows.map(x => x.s);
  assert.deepEqual(iv, [42, 42, 0], 'borne à 0');
  await db.exec("UPDATE personnages_donnees SET pa = 0 WHERE name = 'Jo'");
  await un(db, "SELECT jauges_ordre_executer('censurer_media', $1::uuid, '{\"media\":\"X\"}') r", [uuid()]);
  assert.equal((await un(db, "SELECT (data->>'social')::int s FROM indices_villes WHERE id = 'republic_capitale'")).s, 42, 'paiement refusé : indice intact');
  await db.exec("UPDATE personnages_donnees SET pa = 200 WHERE name = 'Jo'");
  const rangs = new Set();
  for (let i = 0; i < 40; i++) rangs.add((await un(db, "SELECT jauges_ordre_executer('consulter_dossiers_gouv', $1::uuid, '{}') r", [uuid()])).r.dossier_rang);
  assert.ok([...rangs].every(x => Number.isInteger(x) && x >= 0 && x <= 5) && rangs.size > 2);
});

test('migration rejouable : les marques empêchent un second raccord', async () => {
  const db = await base();
  await db.exec(lire(MIG));
  const d = (await un(db, "SELECT pg_get_functiondef('corruption_presse_tenter(text,text,text,text,integer,timestamptz)'::regprocedure) d")).d;
  assert.equal(d.split('jets_b1b_paie_v1').length - 1, 1);
});
