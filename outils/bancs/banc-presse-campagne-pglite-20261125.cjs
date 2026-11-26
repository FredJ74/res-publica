'use strict';
// Publicités de joueurs (décision de Fred, 26/11/2026) : une campagne à la fois par support, deux durées au choix (courte 5 j,
// longue 10 j, réglées par le MJ), prix dégressif ; mêmes règles pour la rue, le cinéma et la presse. Migration 20261125810000 dans PGlite, sur
// une doublure de publicites_premium_presse et de publicite_premium_creer_beta recopiées de la production (25/11/2026).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-presse-campagne-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125810000_presse_campagne_duree_mj.sql';

test('migration et fonction de presse : en-tête, contrôles, durée lue sur la campagne avec repli', () => {
  const m = lire(MIG);
  assert.match(m.split('\n')[0], /NON APPLIQUÉE/);
  assert.match(m, /Contrôles en lecture après application/);
  const f = lire('supabase/edge-functions/publicite-premium/index.ts');
  assert.match(f, /ad\.nb_parutions/);
  assert.match(f, /\(ad\.formule==="dix"\?10:5\)/, 'repli des campagnes anciennes');
  assert.doesNotMatch(f, /ad\.formule==="cinq"\?5:10/, 'plus de durée tirée de la seule formule');
  const ecran = lire('plateau-publicite-premium.js');
  assert.doesNotMatch(ecran, /10 parutions|5 parutions|pub-premium-formule/);
  assert.match(ecran, /name="pub-premium-duree" value="cinq"/); assert.match(ecran, /name="pub-premium-duree" value="dix"/);
  assert.match(lire('plateau-premium.js'), /p_duree: duree/);
  assert.match(lire('admin-premium.js'), /publicite_duree_courte/); assert.match(lire('admin-premium.js'), /publicite_duree_longue/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = '00000000-0000-0000-0000-000000000001', V = '00000000-0000-0000-0000-000000000002';
const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('test.uid', true), '')::uuid $f$;
CREATE TABLE personnages (name text PRIMARY KEY, user_id uuid);
INSERT INTO personnages VALUES ('Olga', '${U}'), ('Ivan', '${V}');
CREATE TABLE premium_parametres (cle text PRIMARY KEY, valeur text NOT NULL, maj_le timestamptz DEFAULT now());
INSERT INTO premium_parametres VALUES ('publicite_joueur_duree_jours', '7');
CREATE TABLE premium_produits (produit text PRIMARY KEY, nature text, libelle text, prix_centimes integer, maj_le timestamptz DEFAULT now());
INSERT INTO premium_produits VALUES ('credit_publicite_presse', 'unite', 'x', NULL), ('credit_publicite_rue', 'unite', 'x', NULL), ('credit_publicite_cinema', 'unite', 'x', NULL);
CREATE TABLE premium_droits (id bigserial PRIMARY KEY, user_id uuid, produit text, cible text, consomme_le timestamptz, revoque_le timestamptz);
CREATE TABLE premium_achats (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), produit text);
CREATE TABLE admin_journal (admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE OR REPLACE FUNCTION admin_exiger() RETURNS void LANGUAGE sql AS $f$ SELECT $f$;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text);
INSERT INTO personnages_donnees VALUES ('Olga', 'republic', 'capitale'), ('Ivan', 'soviet', 'capitale');
CREATE OR REPLACE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $f$ SELECT name FROM personnages WHERE user_id = auth.uid() $f$;
CREATE OR REPLACE FUNCTION premium_jour_interne() RETURNS date LANGUAGE sql STABLE AS $f$ SELECT DATE '2026-11-26' $f$;
CREATE OR REPLACE FUNCTION publicite_joueur_texte_interne(p text, n integer) RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT left(btrim(coalesce(p, '')), n) $f$;
CREATE TABLE publicites_joueurs (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, personnage text, support text, pays text, ville text,
  objet text, titre text, texte text, debut date, fin date, statut text DEFAULT 'active');
CREATE OR REPLACE FUNCTION publicite_joueur_creer(p_support text, p_objet text, p_titre text, p_texte text) RETURNS jsonb LANGUAGE sql AS $f$ SELECT '{}'::jsonb $f$;
CREATE OR REPLACE FUNCTION premium_param_interne(p_cle text, p_defaut text) RETURNS text LANGUAGE sql STABLE AS
  $f$ SELECT coalesce((SELECT valeur FROM premium_parametres WHERE cle = p_cle), p_defaut) $f$;
-- Sans bêta : option offerte seulement si test.option = 'oui' ; sinon une campagne achetée (premium_droits) de la bonne durée.
CREATE OR REPLACE FUNCTION premium_option_source_interne(p_user uuid, p_produit text, p_cible text) RETURNS text LANGUAGE sql AS
  $f$ SELECT CASE WHEN current_setting('test.option', true) = 'oui' THEN 'gratuit_beta' END $f$;
CREATE OR REPLACE FUNCTION premium_unite_utiliser_interne(p_user uuid, p_produit text, p_cible text) RETURNS boolean LANGUAGE plpgsql AS $f$
DECLARE v bigint;
BEGIN SELECT id INTO v FROM premium_droits WHERE user_id = p_user AND produit = p_produit AND consomme_le IS NULL LIMIT 1;
  IF v IS NULL THEN RETURN false; END IF; UPDATE premium_droits SET consomme_le = now() WHERE id = v; RETURN true; END $f$;
CREATE TABLE publicites_premium_presse (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), acheteur_user_id uuid NOT NULL, personnage text NOT NULL,
  formule text NOT NULL, prix_centimes integer NOT NULL, nb_parutions integer, etat text NOT NULL DEFAULT 'brouillon', instructions text,
  assistance_ia boolean NOT NULL DEFAULT true, image_path text, paiement_confirme_le timestamptz, premiere_parution date, derniere_parution date,
  cree_le timestamptz NOT NULL DEFAULT now(), mode_beta_gratuit boolean NOT NULL DEFAULT false, retiree_le timestamptz,
  CONSTRAINT publicites_premium_presse_formule_check CHECK (formule = ANY (ARRAY['cinq'::text, 'dix'::text])),
  CONSTRAINT publicites_premium_presse_prix_check CHECK (prix_centimes = 0 OR prix_centimes >= 200),
  CONSTRAINT programmation_payee CHECK (((etat <> ALL (ARRAY['programmee'::text, 'terminee'::text])) OR (((paiement_confirme_le IS NOT NULL) OR mode_beta_gratuit)
    AND (image_path IS NOT NULL) AND (premiere_parution IS NOT NULL) AND (derniere_parution = (premiere_parution + CASE WHEN (formule = 'cinq'::text) THEN 4 ELSE 9 END))))));
CREATE OR REPLACE FUNCTION public.publicite_premium_creer_beta(p_personnage text, p_formule text, p_instructions text, p_assistance boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Session requise'; END IF;
 IF p_formule NOT IN ('cinq','dix') THEN RAISE EXCEPTION 'Formule invalide'; END IF;
 IF length(trim(coalesce(p_instructions,''))) < 10 OR length(p_instructions)>1500 THEN RAISE EXCEPTION 'Description invalide'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE user_id=auth.uid() AND name=p_personnage) THEN RAISE EXCEPTION 'Personnage non autorise'; END IF;
 IF public.premium_option_source_interne(auth.uid(), 'publicite_joueur', NULL) IS NULL
    AND NOT public.premium_unite_utiliser_interne(auth.uid(), 'credit_publicite_presse', 'presse') THEN
   RAISE EXCEPTION 'Option premium requise'; END IF; /* premium_socle_v1 */
 INSERT INTO public.publicites_premium_presse(acheteur_user_id,personnage,formule,prix_centimes,instructions,assistance_ia,mode_beta_gratuit,etat)
 VALUES(auth.uid(),p_personnage,p_formule,0,trim(p_instructions),coalesce(p_assistance,true),true,'brouillon') RETURNING id INTO v_id;
 RETURN v_id;
END $function$;
-- Deux campagnes de la bêta, programmées sous l'ancienne règle (5 et 10 parutions).
INSERT INTO publicites_premium_presse (acheteur_user_id, personnage, formule, prix_centimes, etat, image_path, mode_beta_gratuit, premiere_parution, derniere_parution)
VALUES ('${V}', 'Ivan', 'cinq', 0, 'programmee', 'a.png', true, DATE '2026-11-10', DATE '2026-11-14'),
       ('${V}', 'Ivan', 'dix', 0, 'programmee', 'b.png', true, DATE '2026-11-01', DATE '2026-11-10');
`;
const creer = (db, nom, duree = 'cinq') => db.query(`SELECT publicite_premium_creer_beta('${nom}', '${duree}', 'Venez au Café des Arts, le meilleur de Luthécia', true) id`);
const base = async () => { const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG)); await db.exec("SET test.option = 'oui'"); return db; };

test('presse : courte (5 j) ou longue (10 j) ; une seule à la fois ; une campagne finie libère la place ; anciennes lignes valides', async () => {
  const db = await base();
  await db.exec(`SET test.uid = '${U}'`);
  const id = (await creer(db, 'Olga')).rows[0].id;
  assert.deepEqual((await db.query(`SELECT formule, nb_parutions FROM publicites_premium_presse WHERE id = '${id}'`)).rows[0], { formule: 'courte', nb_parutions: 5 });
  await assert.rejects(creer(db, 'Olga', 'longue'), /Campagne de presse déjà en cours/);
  await assert.rejects(db.exec(`UPDATE publicites_premium_presse SET etat = 'programmee', image_path = 'c.png', premiere_parution = DATE '2026-11-01', derniere_parution = DATE '2026-11-07' WHERE id = '${id}'`), /programmation_payee/);
  await db.exec(`UPDATE publicites_premium_presse SET etat = 'programmee', image_path = 'c.png', premiere_parution = DATE '2026-11-01', derniere_parution = DATE '2026-11-05' WHERE id = '${id}'`);
  const id2 = (await creer(db, 'Olga', 'dix')).rows[0].id;
  assert.deepEqual((await db.query(`SELECT formule, nb_parutions FROM publicites_premium_presse WHERE id = '${id2}'`)).rows[0], { formule: 'longue', nb_parutions: 10 });
  await assert.rejects(creer(db, 'Olga', '30'), /Durée invalide|déjà en cours/);
  assert.equal((await db.query(`SELECT count(*)::int n FROM publicites_premium_presse WHERE formule IN ('cinq', 'dix')`)).rows[0].n, 2, 'lignes anciennes intactes');
  // Sans option : il faut une campagne achetée de la bonne durée.
  await db.exec(`SET test.uid = '${V}'; SET test.option = 'non'`);
  await assert.rejects(creer(db, 'Ivan', 'longue'), /Option premium requise/);
  await db.exec(`INSERT INTO premium_droits (user_id, produit) VALUES ('${V}', 'campagne_publicite_longue')`);
  assert.ok((await creer(db, 'Ivan', 'longue')).rows[0].id);
  await db.exec(lire(MIG));
});

test('rue et cinéma : même modèle (durée choisie, campagne achetée de la bonne durée) ; ancienne signature retirée', async () => {
  const db = await base();
  assert.equal((await db.query("SELECT to_regprocedure('public.publicite_joueur_creer(text,text,text,text)') IS NULL ok")).rows[0].ok, true);
  await db.exec(`SET test.uid = '${U}'`);
  let r = (await db.query("SELECT publicite_joueur_creer(p_support => 'rue', p_objet => 'commerce', p_titre => 'Café', p_texte => 'Le meilleur café de Luthécia') r")).rows[0].r;
  assert.equal(r.ok, true); assert.equal(r.jours, 5); assert.equal(r.fin, '2026-11-30');
  r = (await db.query("SELECT publicite_joueur_creer('cinema', 'cause', 'Liberté', 'Votez pour la liberté de la presse', 'longue') r")).rows[0].r;
  assert.equal(r.ok, true); assert.equal(r.jours, 10); assert.equal(r.ville, 'ville_b');
  await db.exec(`SET test.uid = '${V}'; SET test.option = 'non'`);
  r = (await db.query("SELECT publicite_joueur_creer('rue', 'cause', 'Tracteur', 'Le tracteur est notre avenir', 'courte') r")).rows[0].r;
  assert.equal(r.raison, 'option_premium_requise'); assert.equal(r.produit, 'campagne_publicite_courte');
});

test('MJ : durées réglables (courte < longue), prix dégressif, anciens crédits par support retirés', async () => {
  const db = await base();
  const fixer = async (c, v) => (await db.query('SELECT premium_admin_parametre_fixer($1, $2) r', [c, v])).rows[0].r;
  assert.equal((await fixer('publicite_duree_courte', '7')).ok, true);
  assert.equal((await fixer('publicite_duree_courte', '10')).raison, 'courte_doit_rester_plus_courte');
  assert.equal((await fixer('publicite_duree_longue', '14')).ok, true);
  const prix = async (p, c) => (await db.query('SELECT premium_admin_prix_fixer($1, $2) r', [p, c])).rows[0].r;
  assert.equal((await prix('campagne_publicite_courte', 700)).ok, true);                      // 1 €/jour sur 7 jours
  assert.equal((await prix('campagne_publicite_longue', 1400)).raison, 'prix_non_degressif');  // 1 €/jour : pas dégressif
  assert.equal((await prix('campagne_publicite_longue', 1200)).ok, true);                      // < 1 €/jour
  assert.equal((await prix('campagne_publicite_courte', 150)).raison, 'prix_inferieur_minimum');
  assert.equal((await db.query("SELECT count(*)::int n FROM premium_produits WHERE produit LIKE 'credit_publicite_%'")).rows[0].n, 0);
});
