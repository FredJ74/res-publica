'use strict';
// Mission du soir du 25/11/2026, bloc 4 (décisions de Fred) : PREMIUM, LE SOCLE. Migration 20261125700000 dans PGlite.
// Bêta = comportement actuel (tout gratuit) ; hors bêta : plafonds gratuits 2 / 4, bureau à 3, options refusées sans droit ;
// prix MJ jamais sous 2 € ; achat → droit (idempotent, montant vérifié) ; abonnement = toutes les options + un renouvellement
// d'image par semaine, non cumulable ; publicité extérieure une fois par jour, jamais aux abonnés, éteinte par défaut ;
// publicités de joueurs (rue, cinéma de Montrouge) ; tarifs 4,99 € / 7,99 € de la presse retirés.
// Les fonctions raccordées sont des doublures portant les ANCRAGES EXACTS de la production (lus le 25/11/2026).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-premium-socle-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125700000_premium_socle.sql';

test('migration : en-tête (appliquée ou non), contrôles, aucun prix écrit en dur, plancher de 2 €', () => {
  const m = lire(MIG);
  assert.match(m.split('\n')[0], /(NON APPLIQUÉE|APPLIQUÉE en production)/);
  assert.match(m, /Contrôles en lecture après application/);
  assert.match(m, /prix_centimes IS NULL OR prix_centimes >= 200/);
  // Les ancrages $a$…$a$ recopient l'ancien code de production (ce qui est remplacé) : hors de ces ancrages, aucun tarif.
  const corps = m.replace(/^--.*$/gm, '').replace(/\$a\$[\s\S]*?\$a\$/g, '');
  assert.doesNotMatch(corps, /\b(499|799)\b|0,99|4,99|7,99/, 'aucun tarif en dur');
  assert.doesNotMatch(corps, /stripe/i);
  assert.doesNotMatch(corps, /goulag/i);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = { olga: '00000000-0000-0000-0000-000000000001', ivan: '00000000-0000-0000-0000-000000000002',
  mj: '00000000-0000-0000-0000-0000000000aa', arnie: '00000000-0000-0000-0000-000000000004' };

const SOCLE = `
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('test.uid', true), '')::uuid $f$;
CREATE TABLE personnages (name text PRIMARY KEY, user_id uuid);
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text);
CREATE TABLE admins (user_id uuid PRIMARY KEY);
CREATE TABLE admin_journal (id bigserial PRIMARY KEY, admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE TABLE comptes_test (personnage text PRIMARY KEY);
CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE entreprises_constantes (cle text PRIMARY KEY, valeur text);
INSERT INTO entreprises_constantes VALUES ('types_commerce_max_base', '3'), ('references_max_base', '10');
CREATE TABLE bureaux_option_premium (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), acheteur text NOT NULL, pays text NOT NULL, ville text NOT NULL,
  batiment text NOT NULL, piece text NOT NULL, achetee_le timestamptz NOT NULL DEFAULT now(), paiement text NOT NULL DEFAULT 'gratuit_beta',
  UNIQUE (acheteur, pays, ville, batiment, piece));
CREATE TABLE logements_premium (pays text, ville text, batiment text, piece text, active_par text, chambres integer, PRIMARY KEY (pays, ville, batiment, piece));
CREATE TABLE publicites_premium_presse (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), acheteur_user_id uuid, personnage text, formule text,
  prix_centimes integer NOT NULL, instructions text, assistance_ia boolean, mode_beta_gratuit boolean NOT NULL DEFAULT false, etat text,
  CONSTRAINT publicites_premium_presse_check CHECK (((formule = 'cinq') AND (prix_centimes = 499)) OR ((formule = 'dix') AND (prix_centimes = 799))));
CREATE OR REPLACE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql STABLE AS $f$ SELECT current_setting('test.service', true) = '1' $f$;
CREATE OR REPLACE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $f$ SELECT name FROM personnages WHERE user_id = auth.uid() LIMIT 1 $f$;
CREATE OR REPLACE FUNCTION admin_exiger() RETURNS void LANGUAGE plpgsql AS $f$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()) THEN RAISE EXCEPTION 'reserve_admin'; END IF; END $f$;
CREATE OR REPLACE FUNCTION est_compte_test(p text) RETURNS boolean LANGUAGE sql STABLE AS $f$ SELECT EXISTS (SELECT 1 FROM comptes_test WHERE personnage = p) $f$;
CREATE OR REPLACE FUNCTION local_jouissance_interne(a text, p text, v text, b text, r text) RETURNS boolean LANGUAGE sql AS $f$ SELECT true $f$;
CREATE OR REPLACE FUNCTION logement_info_interne(p text, v text, b text, r text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT CASE WHEN b = 'appart' THEN '{"base":"salon","type":"petit","premium":false,"premium_possible":true}'::jsonb END $f$;
CREATE OR REPLACE FUNCTION logement_role_interne(n text, i jsonb) RETURNS text LANGUAGE sql AS $f$ SELECT 'titulaire' $f$;
CREATE OR REPLACE FUNCTION fonds_types_max(p_proprietaire text) RETURNS integer LANGUAGE sql STABLE AS $f$
  select greatest(1, coalesce((select valeur::integer from entreprises_constantes where cle = 'types_commerce_max_base'), 3)) $f$;
CREATE OR REPLACE FUNCTION fonds_references_max(p_proprietaire text) RETURNS integer LANGUAGE sql STABLE AS $f$
  select greatest(1, coalesce((select valeur::integer from entreprises_constantes where cle = 'references_max_base'), 4)) $f$;
-- Doublures portant les ancrages exacts de la production.
CREATE OR REPLACE FUNCTION fonds_definir_types(p_acteur text, p_fonds_id text, p_types text[]) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v_data jsonb; v_max integer;
BEGIN
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id;
  v_max := public.fonds_types_max(v_data ->> 'proprietaire');
  IF array_length(p_types, 1) > v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'trop_de_types', 'maximum', v_max); END IF;
  RETURN jsonb_build_object('ok', true, 'maximum', v_max);
END $f$;
CREATE OR REPLACE FUNCTION fonds_reference_creer(p_acteur text, p_fonds_id text, p_generique_id text, p_recette_id text, p_nom text, p_description text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v_data jsonb; v_n integer;
BEGIN
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id;
  v_n := (SELECT count(*) FROM jsonb_object_keys(coalesce(v_data->'references', '{}'::jsonb)));
  IF v_n >= public.fonds_references_max(v_data->>'proprietaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_references_atteint',
                              'maximum', public.fonds_references_max(v_data->>'proprietaire'),
                              'references', v_n);
  END IF;
  RETURN jsonb_build_object('ok', true);
END $f$;
CREATE OR REPLACE FUNCTION public.equipements_emplacements_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE i jsonb;
BEGIN
  i := public.logement_info_interne(p_pays, p_ville, p_batiment, p_piece);
  IF i IS NOT NULL THEN
    IF (i->>'premium')::boolean THEN RETURN CASE WHEN (i->>'chambre')::integer > 0 THEN 6 ELSE 3 END; END IF;
    RETURN CASE WHEN i->>'type' = 'grand' THEN 5 ELSE 3 END;
  END IF;
  RETURN CASE WHEN EXISTS (SELECT 1 FROM public.bureaux_option_premium b
                            WHERE b.pays = p_pays AND b.ville = p_ville AND b.batiment = p_batiment AND b.piece = p_piece
                              AND public.local_jouissance_interne(b.acheteur, p_pays, p_ville, p_batiment, p_piece))
              THEN 6 ELSE 3 END;
END $function$;
CREATE OR REPLACE FUNCTION public.equipement_option_premium_activer()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF EXISTS (SELECT 1 FROM public.bureaux_option_premium WHERE acheteur = v_moi AND pays = d.country AND ville = d.current_city
               AND batiment = d.current_building AND piece = d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'option_deja_active'); END IF;
  -- Beta : gratuite. Le paiement de l'option premium sera branche ici.
  INSERT INTO public.bureaux_option_premium (acheteur, pays, ville, batiment, piece)
  VALUES (v_moi, d.country, d.current_city, d.current_building, d.current_room);
  RETURN jsonb_build_object('ok', true, 'emplacements',
    public.equipements_emplacements_interne(d.country, d.current_city, d.current_building, d.current_room));
END; $function$;
CREATE OR REPLACE FUNCTION public.logement_premium_activer()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); d record; i jsonb; r text;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_logement'); END IF;
  -- Bêta : gratuite. Le paiement de l'option sera branché ici lors de la session premium.
  INSERT INTO public.logements_premium (pays, ville, batiment, piece, active_par, chambres)
  VALUES (d.country, d.current_city, d.current_building, i->>'base', v_moi, 1) ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'base', i->>'base');
END $function$;
CREATE OR REPLACE FUNCTION public.publicite_premium_creer_beta(p_personnage text, p_formule text, p_instructions text, p_assistance boolean DEFAULT true)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Session requise'; END IF;
 IF p_formule NOT IN ('cinq','dix') THEN RAISE EXCEPTION 'Formule invalide'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE user_id=auth.uid() AND name=p_personnage) THEN RAISE EXCEPTION 'Personnage non autorise'; END IF;
 INSERT INTO public.publicites_premium_presse(acheteur_user_id,personnage,formule,prix_centimes,instructions,assistance_ia,mode_beta_gratuit,etat)
 VALUES(auth.uid(),p_personnage,p_formule,CASE WHEN p_formule='cinq' THEN 499 ELSE 799 END,trim(p_instructions),coalesce(p_assistance,true),true,'brouillon') RETURNING id INTO v_id;
 RETURN v_id;
END $function$;
INSERT INTO personnages VALUES ('Olga', '${U.olga}'), ('Ivan', '${U.ivan}'), ('MJ', '${U.mj}'), ('Arnie', '${U.arnie}');
INSERT INTO personnages_donnees VALUES ('Olga', 'republic', 'ville_b', 'centre-affaires', 'bureau_1'), ('Ivan', 'republic', 'ville_b', 'cinema-montrouge', 'salle_1'),
  ('MJ', 'republic', 'capitale', 'mairie', 'hall'), ('Arnie', 'republic', 'ville_b', 'rue', 'rue');
INSERT INTO admins VALUES ('${U.mj}');
INSERT INTO comptes_test VALUES ('Arnie');
INSERT INTO entreprises VALUES ('fonds-olga', '{"proprietaire":"pj:Olga","references":{"a":1,"b":1,"c":1,"d":1}}'),
  ('fonds-olga2', '{"proprietaire":"pj:Olga","references":{}}');
`;

async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG));
  return db;
}
async function en(db, uid, sql, service = false) {
  await db.exec(`SELECT set_config('test.uid', '${uid || ''}', false), set_config('test.service', '${service ? '1' : '0'}', false)`);
  const r = await db.query(sql);
  const v = r.rows[0] && Object.values(r.rows[0])[0];
  return v;
}

test('bêta (réglage par défaut) : comportement actuel, tout gratuit', async () => {
  const db = await base();
  assert.equal((await en(db, U.olga, `SELECT fonds_definir_types('Olga', 'fonds-olga', ARRAY['a','b','c'])`)).ok, true);
  assert.equal((await en(db, U.olga, `SELECT fonds_reference_creer('Olga', 'fonds-olga', 'g', 'r', 'n', 'd')`)).ok, true, '5e article accepté');
  const b = await en(db, U.olga, `SELECT equipement_option_premium_activer()`);
  assert.equal(b.ok, true); assert.equal(b.emplacements, 6);
  assert.equal(await en(db, U.olga, `SELECT paiement FROM bureaux_option_premium`), 'gratuit_beta');
  const d = await en(db, U.olga, `SELECT premium_droits_lire()`);
  assert.equal(d.beta, true); assert.equal(d.abonne, false);
  assert.ok(d.produits.every(p => p.prix_fixe === false && p.prix_centimes === undefined), 'aucun prix rendu tant qu’il n’est pas fixé');
  assert.ok(await en(db, U.olga, `SELECT publicite_premium_creer_beta('Olga', 'cinq', 'Venez chez Olga, la meilleure soupe', true)`));
  assert.equal(await en(db, U.olga, `SELECT prix_centimes FROM publicites_premium_presse`), 0, 'plus de 4,99 € écrit en dur');
  assert.equal((await en(db, U.olga, `SELECT premium_achat_preparer('commerce_premium', 'fonds-olga')`)).raison, 'inclus_pendant_la_beta');
});

test('hors bêta : plafonds gratuits 2 / 4, options refusées sans droit, achat sous prix non fixé refusé', async () => {
  const db = await base();
  await db.exec(`UPDATE premium_parametres SET valeur = '0' WHERE cle = 'beta_tout_gratuit'`);
  const t = await en(db, U.olga, `SELECT fonds_definir_types('Olga', 'fonds-olga', ARRAY['a','b','c'])`);
  assert.equal(t.ok, false); assert.equal(t.maximum, 2);
  const r = await en(db, U.olga, `SELECT fonds_reference_creer('Olga', 'fonds-olga', 'g', 'r', 'n', 'd')`);
  assert.equal(r.raison, 'plafond_references_atteint'); assert.equal(r.maximum, 4);
  assert.equal((await en(db, U.olga, `SELECT equipement_option_premium_activer()`)).raison, 'option_premium_requise');
  await db.exec(`UPDATE personnages_donnees SET current_building = 'appart', current_room = 'salon' WHERE name = 'Olga'`);
  assert.equal((await en(db, U.olga, `SELECT logement_premium_activer()`)).raison, 'option_premium_requise');
  await assert.rejects(en(db, U.olga, `SELECT publicite_premium_creer_beta('Olga', 'cinq', 'Venez chez Olga, la meilleure soupe', true)`), /Option premium requise/);
  assert.equal((await en(db, U.olga, `SELECT premium_achat_preparer('commerce_premium', 'fonds-olga')`)).raison, 'prix_non_fixe');
  assert.equal((await en(db, U.olga, `SELECT publicite_joueur_creer('rue', 'commerce', 'Chez Olga', 'La soupe la plus chaude de Montrouge.')`)).raison, 'option_premium_requise');
});

test('prix MJ : jamais sous 2 €, réservé au MJ', async () => {
  const db = await base();
  assert.equal((await en(db, U.mj, `SELECT premium_admin_prix_fixer('commerce_premium', 199)`)).raison, 'prix_inferieur_minimum');
  await assert.rejects(en(db, U.olga, `SELECT premium_admin_prix_fixer('commerce_premium', 500)`), /reserve_admin/);
  await assert.rejects(db.exec(`UPDATE premium_produits SET prix_centimes = 150 WHERE produit = 'bureau_six'`), /check/i);
  assert.equal((await en(db, U.mj, `SELECT premium_admin_prix_fixer('commerce_premium', 200)`)).ok, true);
  assert.equal((await en(db, U.mj, `SELECT premium_admin_prix_fixer('commerce_premium', NULL)`)).ok, true, 'un prix peut être retiré');
});

test('achat : préparé par le joueur, confirmé par le serveur seul, montant vérifié, idempotent, remboursable', async () => {
  const db = await base();
  await db.exec(`UPDATE premium_parametres SET valeur = '0' WHERE cle = 'beta_tout_gratuit'; UPDATE premium_produits SET prix_centimes = 300 WHERE produit = 'commerce_premium'`);
  assert.equal((await en(db, U.ivan, `SELECT premium_achat_preparer('commerce_premium', 'fonds-olga')`)).raison, 'reserve_proprietaire_fonds');
  const p = await en(db, U.olga, `SELECT premium_achat_preparer('commerce_premium', 'fonds-olga')`);
  assert.equal(p.ok, true); assert.equal(p.montant_centimes, 300);
  assert.equal((await en(db, U.olga, `SELECT premium_achat_confirmer_service('${p.achat}', 'faux', 'tx1', 300, 'EUR')`)).raison, 'reserve_serveur');
  assert.equal((await en(db, null, `SELECT premium_achat_confirmer_service('${p.achat}', 'faux', 'tx1', 299, 'EUR')`, true)).raison, 'montant_incoherent');
  assert.equal((await en(db, null, `SELECT premium_achat_confirmer_service('${p.achat}', 'faux', 'tx1', 300, 'EUR')`, true)).ok, true);
  assert.equal((await en(db, null, `SELECT premium_achat_confirmer_service('${p.achat}', 'faux', 'tx1', 300, 'EUR')`, true)).deja, true);
  assert.equal(await en(db, null, `SELECT count(*)::int FROM premium_droits`), 1, 'webhook rejoué : un seul droit');
  assert.equal((await en(db, U.olga, `SELECT fonds_definir_types('Olga', 'fonds-olga', ARRAY['a','b','c'])`)).ok, true, 'fonds premium : 3 familles');
  assert.equal((await en(db, U.olga, `SELECT fonds_definir_types('Olga', 'fonds-olga2', ARRAY['a','b','c'])`)).ok, false, 'l’autre fonds reste gratuit');
  assert.equal((await en(db, null, `SELECT premium_achat_rembourser_service('tx1')`, true)).ok, true);
  assert.equal(await en(db, null, `SELECT count(*)::int FROM premium_droits WHERE revoque_le IS NULL`), 0);
});

test('abonnement : toutes les options, un renouvellement d’image par semaine non cumulable, puis à l’unité', async () => {
  const db = await base();
  await db.exec(`UPDATE premium_parametres SET valeur = '0' WHERE cle = 'beta_tout_gratuit'; UPDATE premium_produits SET prix_centimes = 500 WHERE produit = 'abonnement_mensuel'`);
  const p = await en(db, U.olga, `SELECT premium_achat_preparer('abonnement_mensuel', NULL)`);
  assert.equal((await en(db, null, `SELECT premium_achat_confirmer_service('${p.achat}', 'faux', 'sub1', 500, 'EUR')`, true)).ok, true);
  assert.equal((await en(db, U.olga, `SELECT premium_droits_lire()`)).abonne, true);
  assert.equal((await en(db, U.olga, `SELECT fonds_definir_types('Olga', 'fonds-olga2', ARRAY['a','b','c'])`)).ok, true);
  const b = await en(db, U.olga, `SELECT equipement_option_premium_activer()`);
  assert.equal(b.emplacements, 6);
  assert.equal(await en(db, U.olga, `SELECT paiement FROM bureaux_option_premium`), 'abonnement');
  assert.equal((await en(db, null, `SELECT premium_renouvellement_autoriser_service('${U.olga}', 'commerce', 'fonds-olga')`, true)).source, 'abonnement');
  const r2 = await en(db, null, `SELECT premium_renouvellement_autoriser_service('${U.olga}', 'commerce', 'fonds-olga')`, true);
  assert.equal(r2.ok, false); assert.equal(r2.raison, 'renouvellement_a_payer');
  await db.exec(`INSERT INTO premium_droits (user_id, produit, source) VALUES ('${U.olga}', 'renouvellement_image', 'mj')`);
  assert.equal((await en(db, null, `SELECT premium_renouvellement_autoriser_service('${U.olga}', 'commerce', 'fonds-olga')`, true)).source, 'unite');
  // Fin d'abonnement : le bureau revient à 3, les articles déjà créés restent.
  await en(db, null, `SELECT premium_abonnement_maj_service('sub1', 'expire', now() - interval '1 second')`, true);
  assert.equal(await en(db, U.olga, `SELECT equipements_emplacements_interne('republic', 'ville_b', 'centre-affaires', 'bureau_1')`), 3);
  assert.equal((await en(db, U.olga, `SELECT premium_droits_lire()`)).abonne, false);
});

test('publicité extérieure : éteinte par défaut ; une par jour au Dormir, gratuits seulement ; rien sans annonce', async () => {
  const db = await base();
  assert.equal((await en(db, U.ivan, `SELECT premium_pub_externe_dormir()`)).annonce, null);
  await db.exec(`UPDATE premium_parametres SET valeur = '1' WHERE cle = 'pub_externe_active'`);
  assert.equal((await en(db, U.ivan, `SELECT premium_pub_externe_dormir()`)).annonce, null, 'aucune régie : rien');
  assert.equal(await en(db, U.ivan, `SELECT count(*)::int FROM premium_pub_externe_vues`), 0, 'rien n’est compté sans annonce');
  await db.exec(`INSERT INTO premium_pub_externe_annonces (annonceur, texte, actif) VALUES ('Annonceur', 'Bonjour', true)`);
  assert.equal((await en(db, U.ivan, `SELECT premium_pub_externe_dormir()`)).annonce.texte, 'Bonjour');
  assert.equal((await en(db, U.ivan, `SELECT premium_pub_externe_dormir()`)).annonce, null, 'une seule par jour');
  await db.exec(`INSERT INTO premium_abonnements (user_id, statut, fin, fournisseur) VALUES ('${U.olga}', 'actif', now() + interval '10 days', 'faux')`);
  assert.equal((await en(db, U.olga, `SELECT premium_pub_externe_dormir()`)).abonne, true, 'jamais pour un abonné');
});

test('publicités de joueurs : rue (une par jour), cinéma de Montrouge, texte nettoyé, une campagne à la fois', async () => {
  const db = await base();
  const c = await en(db, U.olga, `SELECT publicite_joueur_creer('rue', 'commerce', '<b>Chez Olga</b>', 'La soupe la plus chaude de Montrouge <script>.')`);
  assert.equal(c.ok, true);
  assert.equal((await en(db, U.olga, `SELECT publicite_joueur_creer('rue', 'cause', 'Encore', 'Une seconde campagne de rue.')`)).raison, 'campagne_deja_en_cours');
  assert.doesNotMatch(await en(db, null, `SELECT titre || texte FROM publicites_joueurs`), /[<>]/);
  assert.equal((await en(db, U.olga, `SELECT publicite_joueur_tirer('rue')`)).publicite, null, 'jamais sa propre publicité');
  await db.exec(`UPDATE personnages_donnees SET current_building = 'rue' WHERE name = 'Ivan'`);
  assert.equal((await en(db, U.ivan, `SELECT publicite_joueur_tirer('rue')`)).publicite.annonceur, 'Olga');
  assert.equal((await en(db, U.ivan, `SELECT publicite_joueur_tirer('rue')`)).publicite, null, 'une par jour');
  assert.equal((await en(db, U.olga, `SELECT publicite_joueur_creer('cinema', 'cause', 'Votez Olga', 'Pour une soupe gratuite dans chaque cantine.')`)).ok, true);
  assert.equal((await en(db, U.ivan, `SELECT publicite_joueur_tirer('cinema')`)).publicite, null, 'hors du cinéma : rien');
  await db.exec(`UPDATE personnages_donnees SET current_building = 'cinema-montrouge' WHERE name = 'Ivan'`);
  assert.equal((await en(db, U.ivan, `SELECT publicite_joueur_tirer('cinema')`)).publicite.titre, 'Votez Olga');
  // Comptes de test : leurs publicités ne sont montrées à personne.
  assert.equal((await en(db, U.arnie, `SELECT publicite_joueur_creer('rue', 'commerce', 'Chez Arnie', 'Ouvert jour et nuit, ou presque.')`)).ok, true);
  await db.exec(`DELETE FROM publicites_joueurs_vues; UPDATE publicites_joueurs SET statut = 'retiree' WHERE personnage = 'Olga'`);
  await db.exec(`UPDATE personnages_donnees SET current_building = 'rue' WHERE name = 'Ivan'`);
  assert.equal((await en(db, U.ivan, `SELECT publicite_joueur_tirer('rue')`)).publicite, null);
});

test('offre de lancement : crédits à l’unité utilisables hors bêta', async () => {
  const db = await base();
  await db.exec(`UPDATE premium_parametres SET valeur = '0' WHERE cle = 'beta_tout_gratuit';
    INSERT INTO premium_droits (user_id, produit, source) VALUES ('${U.olga}', 'credit_publicite_rue', 'offre_lancement'),
      ('${U.olga}', 'credit_publicite_presse', 'offre_lancement'), ('${U.olga}', 'personnalisation_local', 'offre_lancement')`);
  assert.equal((await en(db, U.olga, `SELECT publicite_joueur_creer('rue', 'commerce', 'Chez Olga', 'La soupe la plus chaude de Montrouge.')`)).ok, true);
  assert.ok(await en(db, U.olga, `SELECT publicite_premium_creer_beta('Olga', 'cinq', 'Venez chez Olga, la meilleure soupe', true)`));
  await assert.rejects(en(db, U.olga, `SELECT publicite_premium_creer_beta('Olga', 'cinq', 'Une deuxième annonce, refusée', true)`), /Option premium requise/);
  const s = await en(db, null, `SELECT premium_personnalisation_autoriser_service('${U.olga}', 'personnalisation_local', 'fonds-olga')`, true);
  assert.equal(s.ok, true); assert.equal(s.source, 'offre');
  assert.equal(await en(db, null, `SELECT cible FROM premium_droits WHERE produit = 'personnalisation_local'`), 'fonds-olga', 'attachée au premier usage');
  assert.equal((await en(db, null, `SELECT premium_personnalisation_autoriser_service('${U.olga}', 'personnalisation_local', 'fonds-olga2')`, true)).ok, false);
});
