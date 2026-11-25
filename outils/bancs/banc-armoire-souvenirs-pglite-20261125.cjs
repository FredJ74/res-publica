'use strict';
// Mission de jour du 25/11/2026, bloc 3 (H.9) : armoire à souvenirs, dépôt et collection. Migration 20261125300000 dans PGlite,
// sur des réductions fidèles des fonctions raccordées (lignes d'ancrage relevées en production le 25/11).
// Dépôt, reprise, refus d'un objet hors liste, carte postale valide (et hors liste), collection complète et +1 PA au sommeil,
// absence de cumul, armoire à vider avant déplacement, visiteur (constat au propriétaire), armoire verrouillée.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-armoire-souvenirs-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125300000_armoire_souvenirs_collection.sql';

test('écran : fenêtre de l’armoire installée lue au serveur, 12 emplacements, Déposer / Reprendre, progression', () => {
  const js = lire('plateau-armoire-souvenirs.js');
  assert.match(js, /global\.sbRpc\(fn/); assert.match(js, /rpc\('armoire_lire'/); assert.match(js, /agir\('armoire_deposer'/); assert.match(js, /agir\('armoire_reprendre'/);
  assert.match(js, /\{n\}\/\{total\}/);
  assert.match(lire('plateau-equipements.js'), /ouvrirArmoireInstallee\(/);
  assert.match(lire('plateau.html'), /plateau-armoire-souvenirs\.js/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text,
  inventory jsonb DEFAULT '[]', inventory_revision bigint DEFAULT 0, pa integer DEFAULT 10);
CREATE TABLE equipements_installes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), proprietaire text, pays text, ville text, batiment text, piece text,
  generique_id text, objet jsonb, installe_le timestamptz DEFAULT now(), jouissance_perdue_le timestamptz);
CREATE TABLE serrures (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), statut text, fermee boolean, cible text, armoire_objet text);
CREATE TABLE aliments_parametres (cle text PRIMARY KEY, valeur numeric);
CREATE TABLE jouissances (nom text, piece text);
CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, acte text, auteur text, cible text, details jsonb, maj_le timestamptz);
CREATE TABLE crim_constats (id bigserial PRIMARY KEY, destinataire text, pays text, ville text, batiment text, piece text, titre text, corps text, affaire bigint);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION aliments_param_interne(p text, d numeric) RETURNS numeric LANGUAGE sql STABLE AS $$ SELECT coalesce((SELECT valeur FROM aliments_parametres WHERE cle = p), d) $$;
CREATE FUNCTION local_jouissance_interne(a text, p text, v text, b text, r text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT EXISTS (SELECT 1 FROM jouissances WHERE nom = a AND piece = r) $$;
CREATE FUNCTION equipement_a_moi_interne(p_proprietaire text, p_acteur text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT p_proprietaire = p_acteur $$;
CREATE FUNCTION serrure_cle_detenue_interne(p_acteur text, p_serrure uuid) RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM personnages_donnees d, jsonb_array_elements(d.inventory) e WHERE d.name = p_acteur AND e->>'type' = 'cle_serrure' AND e->>'serrureId' = p_serrure::text) $$;
CREATE FUNCTION achat_requete_ouvrir_interne(a text, r uuid, f text, p jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT NULL::jsonb $$;
CREATE FUNCTION achat_requete_clore_interne(a text, r uuid, f text, p jsonb, v jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT v $$;
CREATE FUNCTION inventaire_deposer_interne(p_nom text, p_objet jsonb, p_auto boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  IF jsonb_array_length((SELECT inventory FROM personnages_donnees WHERE name = p_nom)) >= 3 THEN RETURN '{"ok":false,"raison":"inventaire_plein"}'; END IF;
  UPDATE personnages_donnees SET inventory = inventory || jsonb_build_array(p_objet) WHERE name = p_nom; RETURN '{"ok":true}';
END $$;
CREATE FUNCTION crim_resoudre_interne(p_acte text, p_auteur text, p_cible text, p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE i bigint; BEGIN INSERT INTO crim_affaires (acte, auteur, details) VALUES (p_acte, p_auteur, p) RETURNING id INTO i; RETURN jsonb_build_object('affaire', i, 'issue', 'reussite'); END $$;
CREATE FUNCTION crim_proprietaire_pj_interne(p text) RETURNS text LANGUAGE sql AS $$ SELECT CASE WHEN left(p, 5) = 'orga:' THEN NULL ELSE p END $$;
-- Réductions des trois fonctions raccordées : lignes d'ancrage identiques à la production.
CREATE FUNCTION public.pa_repos_nocturne(p_acteur text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_gain integer := 12; v_logement jsonb := NULL;
BEGIN
    IF v_logement IS NOT NULL THEN v_gain := v_gain + coalesce((v_logement->>'pa')::integer, 0); END IF;
  RETURN jsonb_build_object('ok', true, 'gain', v_gain);
END $function$;
CREATE FUNCTION public.desinstaller_materiel(p_requete uuid, p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); m record; e public.equipements_installes; v_legal boolean;
BEGIN
  SELECT * INTO m FROM public.personnages_donnees WHERE name = a;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id;
  v_legal := public.local_jouissance_interne(a, m.country, m.current_city, m.current_building, m.current_room)
             OR public.equipement_a_moi_interne(e.proprietaire, a);
  DELETE FROM public.equipements_installes WHERE id = e.id;
  RETURN jsonb_build_object('ok', true, 'legal', v_legal);
END $function$;
CREATE FUNCTION public.equipement_desinstaller(p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text := public.mon_personnage(); e public.equipements_installes;
BEGIN
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id;
  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))
     < 1 THEN RETURN '{"ok":false}'; END IF;
  DELETE FROM public.equipements_installes WHERE id = e.id;
  RETURN jsonb_build_object('ok', true);
END $function$;
CREATE FUNCTION public.inventaire_place_restante(p jsonb) RETURNS integer LANGUAGE sql AS $$ SELECT 100 $$;
INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, inventory) VALUES
  ('Proprio', 'republic', 'capitale', 'immeuble', 'salon', '[{"id":"s1","name":"Mug « Port Sainte-Marie »"},{"id":"x1","name":"Caillou"},
    {"name":"Ticket du cinéma de Montrouge","stackable":true,"stackKey":"ticket","qty":2},{"id":"cp1","name":"Carte de Krasnov","familleProduitMarche":"carte_postale","modele":"carte_krasnov_place_ours"}]'),
  ('Visiteur', 'republic', 'capitale', 'immeuble', 'salon', '[]'),
  ('Loin', 'republic', 'capitale', 'marche', 'etal', '[]');
INSERT INTO jouissances VALUES ('Proprio', 'salon');
INSERT INTO equipements_installes (id, proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
  ('00000000-0000-0000-0000-00000000000a', 'Proprio', 'republic', 'capitale', 'immeuble', 'salon', 'armoire_souvenirs', '{"id":"arm-A","name":"Armoire à souvenirs","listeId":1}'),
  ('00000000-0000-0000-0000-00000000000b', 'Proprio', 'republic', 'capitale', 'immeuble', 'salon', 'armoire_souvenirs', '{"id":"arm-B","name":"Armoire à souvenirs","listeId":2}');`;
const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b';
let nreq = 0; const req = () => '00000000-0000-4000-8000-' + String(++nreq).padStart(12, '0');
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG));
  // Liste 2 du banc : un emplacement demande une carte postale (Krasnov), un autre une clé d'objet.
  await db.exec(`INSERT INTO souvenirs_listes VALUES (2, 'Liste du banc');
    INSERT INTO souvenirs_emplacements (liste_id, rang, ville, nom, cle_objet, carte_modele) VALUES
      (2, 1, 'Krasnov', 'Carte postale de Krasnov', NULL, 'carte_krasnov_place_ours'), (2, 2, 'Luthécia', 'Porte-clé du Palais', 'porte_cle_palais_luthecia', NULL)`);
  return db;
}
const en = (db, qui) => db.query("SELECT set_config('banc.moi', $1, false)", [qui]);
const rpc = async (db, qui, sql, p = []) => { await en(db, qui); return (await db.query('SELECT ' + sql + ' r', p)).rows[0].r; };

test('dépôt du souvenir exact, refus hors liste, une unité d’une pile, reprise ; progression lue au serveur', async () => {
  const db = await base();
  let s = await rpc(db, 'Proprio', 'armoire_lire($1)', [A]);
  assert.equal(s.total, 12); assert.equal(s.remplis, 0); assert.equal(s.emplacements.length, 12);
  assert.deepEqual(s.deposables.map(x => x.ref).sort(), ['cp1', 's1', 'ticket'], 'souvenirs de la liste et carte postale');
  assert.equal((await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 'x1'])).raison, 'hors_liste');
  const d = await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 's1']);
  assert.equal(d.ok, true); assert.equal(d.rang, 3); assert.equal(d.remplis, 1);
  assert.equal(d.emplacements.find(e => e.rang === 3).objet, 'Mug « Port Sainte-Marie »');
  const t = await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 'ticket']);
  assert.equal(t.rang, 2);
  assert.equal(t.inventory.find(o => o.stackKey === 'ticket').qty, 1, 'une seule unité quitte la pile');
  assert.equal((await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 'ticket'])).raison, 'emplacement_deja_rempli');
  // Carte postale hors liste : rangée sans compter.
  const c = await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 'cp1']);
  assert.equal(c.rang, null); assert.equal(c.remplis, 2); assert.equal(c.cartes.length, 1);
  // Reprise par le propriétaire : pas d'affaire.
  const id = c.emplacements.find(e => e.rang === 3).contenu;
  const r = await rpc(db, 'Proprio', 'armoire_reprendre($1,$2,$3)', [req(), A, id]);
  assert.equal(r.ok, true); assert.equal(r.remplis, 1); assert.ok(r.inventory.some(o => o.id === 's1'));
  assert.equal((await db.query('SELECT count(*)::int n FROM crim_affaires')).rows[0].n, 0);
  assert.equal((await rpc(db, 'Proprio', 'armoire_reprendre($1,$2,$3)', [req(), A, id])).raison, 'deja_repris');
  // Pas sur place : rien.
  assert.equal((await rpc(db, 'Loin', 'armoire_lire($1)', [A])).raison, 'pas_sur_place');
});

test('carte postale demandée par la liste : elle remplit l’emplacement ; clé d’objet', async () => {
  const db = await base();
  await db.exec(`UPDATE personnages_donnees SET inventory = inventory || '[{"id":"pc","name":"Porte-clé","type":"porte_cle_palais_luthecia"}]' WHERE name = 'Proprio'`);
  const c = await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), B, 'cp1']);
  assert.equal(c.rang, 1, 'la carte remplit l’emplacement de Krasnov');
  const k = await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), B, 'pc']);
  assert.equal(k.rang, 2); assert.equal(k.complete, true, 'liste du banc complète (2/2)');
});

test('collection complète : +1 PA en dormant près de SON armoire ; pas de cumul ; armoire à vider avant tout déplacement', async () => {
  const db = await base();
  const sommeil = async qui => (await db.query("SELECT pa_repos_nocturne($1) r", [qui])).rows[0].r.gain;
  assert.equal(await sommeil('Proprio'), 12);
  // Deux armoires complètes dans la même pièce.
  await db.exec(`INSERT INTO armoires_contenus (armoire_objet, rang, objet) SELECT 'arm-A', rang, jsonb_build_object('name', nom) FROM souvenirs_emplacements WHERE liste_id = 1;
    INSERT INTO armoires_contenus (armoire_objet, rang, objet) SELECT 'arm-B', rang, jsonb_build_object('name', nom) FROM souvenirs_emplacements WHERE liste_id = 2;`);
  assert.equal((await rpc(db, 'Proprio', 'armoire_lire($1)', [A])).complete, true);
  assert.equal(await sommeil('Proprio'), 13, '+1 PA, une seule fois malgré deux armoires complètes');
  assert.equal(await sommeil('Visiteur'), 12, 'pas son armoire');
  await db.exec("UPDATE aliments_parametres SET valeur = 2 WHERE cle = 'armoire_confort_pa'");
  assert.equal(await sommeil('Proprio'), 14, 'réglage MJ');
  // À vider avant déplacement ou désinstallation.
  assert.equal((await rpc(db, 'Proprio', 'equipement_desinstaller($1)', [A])).raison, 'armoire_non_vide');
  assert.equal((await rpc(db, 'Proprio', 'desinstaller_materiel($1,$2)', [req(), A])).raison, 'armoire_non_vide');
  await db.exec("DELETE FROM armoires_contenus WHERE armoire_objet = 'arm-A'");
  assert.equal((await rpc(db, 'Proprio', 'equipement_desinstaller($1)', [A])).ok, true, 'vide : elle se désinstalle');
});

test('visiteur : vide une armoire ouverte (affaire « ramasser », constat) mais n’y dépose rien ; armoire verrouillée', async () => {
  const db = await base();
  const d = await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 's1']);
  const id = d.emplacements.find(e => e.rang === 3).contenu;
  const v = await rpc(db, 'Visiteur', 'armoire_lire($1)', [A]);
  assert.equal(v.acces.proprietaire, false); assert.deepEqual(v.deposables, []);
  await db.exec(`UPDATE personnages_donnees SET inventory = '[{"id":"s9","name":"Poupée traditionnelle de Novomirsk"}]' WHERE name = 'Visiteur'`);
  assert.equal((await rpc(db, 'Visiteur', 'armoire_deposer($1,$2,$3)', [req(), A, 's9'])).raison, 'pas_proprietaire');
  // Verrouillée : ni le visiteur, ni le propriétaire sans clé ; le propriétaire avec une clé.
  await db.exec("INSERT INTO serrures (id, statut, fermee, cible, armoire_objet) VALUES ('00000000-0000-0000-0000-0000000000cc', 'posee', true, 'armoire', 'arm-A')");
  const fermee = await rpc(db, 'Visiteur', 'armoire_lire($1)', [A]);
  assert.equal(fermee.acces.ouvrable, false); assert.equal(fermee.emplacements, undefined, 'rien ne se voit à travers la porte');
  assert.equal((await rpc(db, 'Visiteur', 'armoire_reprendre($1,$2,$3)', [req(), A, id])).raison, 'armoire_fermee_a_cle');
  assert.equal((await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 'ticket'])).raison, 'armoire_fermee_a_cle');
  await db.exec(`UPDATE personnages_donnees SET inventory = inventory || '[{"type":"cle_serrure","serrureId":"00000000-0000-0000-0000-0000000000cc"}]' WHERE name = 'Proprio'`);
  assert.equal((await rpc(db, 'Proprio', 'armoire_deposer($1,$2,$3)', [req(), A, 'ticket'])).ok, true, 'avec une de ses clés');
  // Ouverte : le visiteur la vide ; le propriétaire reçoit un constat (il peut porter plainte pour vol).
  await db.exec("UPDATE serrures SET fermee = false");
  const r = await rpc(db, 'Visiteur', 'armoire_reprendre($1,$2,$3)', [req(), A, id]);
  assert.equal(r.ok, true); assert.ok(r.inventory.some(o => o.id === 's1'));
  const aff = (await db.query("SELECT acte, auteur, cible FROM crim_affaires")).rows;
  assert.deepEqual(aff, [{ acte: 'ramasser', auteur: 'Visiteur', cible: 'Proprio' }]);
  const cst = (await db.query('SELECT destinataire, corps FROM crim_constats')).rows[0];
  assert.equal(cst.destinataire, 'Proprio'); assert.match(cst.corps, /Vous pouvez porter plainte pour vol\./); assert.doesNotMatch(cst.corps, /Visiteur/);
  // Joueur anonyme : aucune fonction.
  await assert.rejects(db.query(`SET ROLE anon; SELECT armoire_lire('${A}');`));
  await db.exec('RESET ROLE');
  await db.exec(lire(MIG));   // rejouable
});
