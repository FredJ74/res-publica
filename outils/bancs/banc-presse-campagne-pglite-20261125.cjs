'use strict';
// Mission de fin de soirée du 25/11/2026, point 2.4 : l'atelier de presse suit le modèle « une campagne à la fois par
// support, durée réglée par le MJ » ; les formules 5 / 10 parutions disparaissent. Migration 20261125810000 dans PGlite, sur
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
  assert.doesNotMatch(ecran, /value="dix"|10 parutions|5 parutions/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = '00000000-0000-0000-0000-000000000001', V = '00000000-0000-0000-0000-000000000002';
const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('test.uid', true), '')::uuid $f$;
CREATE TABLE personnages (name text PRIMARY KEY, user_id uuid);
INSERT INTO personnages VALUES ('Olga', '${U}'), ('Ivan', '${V}');
CREATE TABLE premium_parametres (cle text PRIMARY KEY, valeur text NOT NULL);
INSERT INTO premium_parametres VALUES ('publicite_joueur_duree_jours', '7');
CREATE OR REPLACE FUNCTION premium_param_interne(p_cle text, p_defaut text) RETURNS text LANGUAGE sql STABLE AS
  $f$ SELECT coalesce((SELECT valeur FROM premium_parametres WHERE cle = p_cle), p_defaut) $f$;
CREATE OR REPLACE FUNCTION premium_option_source_interne(p_user uuid, p_produit text, p_cible text) RETURNS text LANGUAGE sql AS $f$ SELECT 'gratuit_beta' $f$;
CREATE OR REPLACE FUNCTION premium_unite_utiliser_interne(p_user uuid, p_produit text, p_cible text) RETURNS boolean LANGUAGE sql AS $f$ SELECT false $f$;
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
const creer = (db, nom) => db.query(`SELECT publicite_premium_creer_beta('${nom}', 'cinq', 'Venez au Café des Arts, le meilleur de Luthécia', true) id`);

test('création : campagne à la durée du MJ ; une seule à la fois ; une campagne finie libère la place ; anciennes lignes valides', async () => {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG));
  await db.exec(`SET test.uid = '${U}'`);
  const id = (await creer(db, 'Olga')).rows[0].id;
  const r = (await db.query(`SELECT formule, nb_parutions FROM publicites_premium_presse WHERE id = '${id}'`)).rows[0];
  assert.deepEqual(r, { formule: 'campagne', nb_parutions: 7 });
  await assert.rejects(creer(db, 'Olga'), /Campagne de presse déjà en cours/);
  // Programmée pour 7 jours : la contrainte accepte première + 6, refuse première + 4.
  await assert.rejects(db.exec(`UPDATE publicites_premium_presse SET etat = 'programmee', image_path = 'c.png', premiere_parution = DATE '2026-11-01', derniere_parution = DATE '2026-11-05' WHERE id = '${id}'`), /programmation_payee/);
  await db.exec(`UPDATE publicites_premium_presse SET etat = 'programmee', image_path = 'c.png', premiere_parution = DATE '2026-11-01', derniere_parution = DATE '2026-11-07' WHERE id = '${id}'`);
  // Campagne finie (dernière parution passée) : une nouvelle campagne est permise ; le MJ a réglé 12 jours.
  await db.exec(`UPDATE premium_parametres SET valeur = '12'`);
  const id2 = (await creer(db, 'Olga')).rows[0].id;
  assert.equal((await db.query(`SELECT nb_parutions FROM publicites_premium_presse WHERE id = '${id2}'`)).rows[0].nb_parutions, 12);
  // Un autre compte n'est pas bloqué par la campagne d'Olga ; les deux campagnes anciennes d'Ivan sont terminées.
  await db.exec(`SET test.uid = '${V}'`);
  assert.ok((await creer(db, 'Ivan')).rows[0].id);
  assert.equal((await db.query(`SELECT count(*)::int n FROM publicites_premium_presse WHERE formule IN ('cinq', 'dix')`)).rows[0].n, 2, 'lignes anciennes intactes');
  // Rejouée, la migration ne change rien (marque déjà posée).
  await db.exec(lire(MIG));
});
