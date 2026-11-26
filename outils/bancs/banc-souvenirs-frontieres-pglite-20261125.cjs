'use strict';
// Mission du soir du 25/11/2026, bloc 3 : souvenirs achetables sur place (3.1), listes 2 à 4 et armoires fabriquées (3.2),
// frontières des empires fermés (3.3). Migrations 20261125300000 puis 20261125600000 dans PGlite, sur des réductions fidèles des
// fonctions raccordées (lignes d'ancrage relevées en production le 25/11 au soir).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-souvenirs-frontieres-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG_ARMOIRE = 'migrations/20261125300000_armoire_souvenirs_collection.sql';
const MIG = 'migrations/20261125600000_souvenirs_achat_listes_frontieres.sql';

const LISTES = {
  2: ['Tampon encreur officiel « Approuvé — en trois exemplaires »', 'Carte postale « Montrouge, place du Rail — ici, même les statues sont à l\'heure »',
    'Bocal de sel des marais', 'Ticket n° 1 de la file d\'attente de la Distribution Collective, encadré', 'Bonnet en laine de renne de la ferme',
    'Guide des baies sauvages', 'Maracas rouges du carnaval', 'Mignonnette de rhum « Puerto Negro »', 'Bougie votive peinte', 'Sachet d\'épices du souk',
    'Flacon de sable de l\'oasis', 'Porte-clés en forme de derrick doré'],
  3: ['Carte postale « Luthécia — la liberté, en trois exemplaires et dûment tamponnée »', 'Sifflet de chef de gare du musée du Rail',
    'Carte postale « Port-Sainte-Marie, sous la protection de Notre-Dame de la Mer »', 'Médaille commémorative du Tractorisme',
    'Carte postale « Starovka — ici, la chaleur est dans les cœurs »', 'Casque miniature de fondeur des hauts-fourneaux', 'Foulard rouge brodé',
    'Dé en os des tripots du port', 'Statuette du saint protecteur de la ville', 'Théière miniature ciselée', 'Datte en sucre dans sa boîte dorée',
    'Fiole décorative scellée « pétrole brut »'],
  4: ['Formulaire vierge de la Liberté, encadré', 'Carte postale « Bons baisers de Montrouge, la ville qui ne déraille jamais »',
    'Bouée miniature « Port-Sainte-Marie »', 'Exemplaire relié de La Voix de Sovarka', 'Bois de renne sculpté',
    'Pendentif « L\'ours ne se chasse pas » (fausse griffe d\'ours)', 'Affiche du carnaval', 'Boussole de contrebandier', 'Chapelet de perles noires',
    'Babouches brodées miniatures', 'Chameau en peluche « Oasis City »', 'Casque de chantier pétrolier dédicacé']
};
const FERMEES = ['Ciudad Roja', 'Puerto Negro', 'Villa Sangre', 'Al Madina', 'Oasis City', 'Al-Petrol'];

test('écran : aucun lieu de souvenir côté navigateur ; ordre dynamique lu au serveur ; frontière et armoire', () => {
  const js = lire('plateau-souvenirs.js');
  assert.match(js, /rpc\('souvenirs_ici'\)/); assert.match(js, /rpc\('souvenir_acheter'/);
  assert.match(js, /RP_ORDRES_DYNAMIQUES\.push\(ordresSouvenirs\)/);
  assert.match(lire('plateau-router.js'), /fn === 'acheter_souvenir'/);
  assert.match(lire('plateau.html'), /plateau-souvenirs\.js/);
  // Le jeu n'indique jamais où trouver un souvenir : aucun fichier servi au navigateur ne cite un lieu de vente.
  const servis = fs.readdirSync(root).filter(f => /\.(js|html)$/.test(f))
    .concat(fs.readdirSync(path.join(root, 'api')).filter(f => f.endsWith('.js')).map(f => 'api/' + f));
  for (const f of servis) {
    const t = lire(f);
    assert.doesNotMatch(t, /souv_[a-z]+_[a-z_]+/, f + ' ne doit citer aucune clé de souvenir (lieux secrets)');
  }
  // Guide et aide : ni « souvenir » associé à un lieu dans les thèmes d'aide.
  assert.doesNotMatch(lire('api/_aide-themes.js'), /Acheter un souvenir|souvenirs_ici/);
  assert.match(lire('plateau-navigation.js'), /frontiere_fermee:'Frontière fermée, ouverture au premier trimestre 2027'/);
  const arm = lire('plateau-armoire-souvenirs.js');
  assert.match(arm, /Cette ville ouvrira ses portes au premier trimestre 2027\./);
  assert.match(arm, /e\.ville_fermee/);
  for (const v of FERMEES) assert.ok(arm.includes("'" + v + "'"), v);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text,
  inventory jsonb DEFAULT '[]', inventory_revision bigint DEFAULT 0, pa integer DEFAULT 10, liquide numeric DEFAULT 0, arg numeric DEFAULT 0);
CREATE TABLE equipements_installes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), proprietaire text, pays text, ville text, batiment text, piece text,
  generique_id text, objet jsonb, installe_le timestamptz DEFAULT now(), jouissance_perdue_le timestamptz);
CREATE TABLE serrures (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), statut text, fermee boolean, cible text, armoire_objet text);
CREATE TABLE aliments_parametres (cle text PRIMARY KEY, valeur numeric);
CREATE TABLE jouissances (nom text, piece text);
CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, acte text, auteur text, cible text, details jsonb, maj_le timestamptz);
CREATE TABLE crim_constats (id bigserial PRIMARY KEY, destinataire text, pays text, ville text, batiment text, piece text, titre text, corps text, affaire bigint);
CREATE TABLE actions_recues (acteur text, requete uuid, action text, resultat jsonb, PRIMARY KEY (acteur, requete));
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION aliments_param_interne(p text, d numeric) RETURNS numeric LANGUAGE sql STABLE AS $$ SELECT coalesce((SELECT valeur FROM aliments_parametres WHERE cle = p), d) $$;
CREATE FUNCTION local_jouissance_interne(a text, p text, v text, b text, r text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT EXISTS (SELECT 1 FROM jouissances WHERE nom = a AND piece = r) $$;
CREATE FUNCTION equipement_a_moi_interne(p_proprietaire text, p_acteur text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT p_proprietaire = p_acteur $$;
CREATE FUNCTION serrure_cle_detenue_interne(p_acteur text, p_serrure uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
-- Rejeu des requêtes comme en production : même requête, même réponse.
CREATE FUNCTION achat_requete_ouvrir_interne(a text, r uuid, f text, p jsonb) RETURNS jsonb LANGUAGE sql AS $$
  SELECT resultat || jsonb_build_object('rejeu', true) FROM actions_recues WHERE acteur = a AND requete = r $$;
CREATE FUNCTION achat_requete_clore_interne(a text, r uuid, f text, p jsonb, v jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO actions_recues VALUES (a, r, f, v);
  RETURN v || (SELECT jsonb_build_object('inventory', inventory, 'paie', jsonb_build_object('liquide', liquide)) FROM personnages_donnees WHERE name = a); END $$;
CREATE FUNCTION inventaire_place_restante(p jsonb) RETURNS integer LANGUAGE sql AS $$ SELECT 3 - jsonb_array_length(coalesce(p, '[]')) $$;
CREATE FUNCTION inventaire_deposer_interne(p_nom text, p_objet jsonb, p_auto boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  IF jsonb_array_length((SELECT inventory FROM personnages_donnees WHERE name = p_nom)) >= 3 THEN RETURN '{"ok":false,"raison":"inventaire_plein"}'; END IF;
  UPDATE personnages_donnees SET inventory = inventory || jsonb_build_array(p_objet || jsonb_build_object('id', 'obj-' || md5(random()::text))) WHERE name = p_nom; RETURN '{"ok":true}';
END $$;
CREATE FUNCTION argent_debiter_interne(p_nom text, p_montant numeric, p_poches text) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE l numeric; BEGIN SELECT liquide INTO l FROM personnages_donnees WHERE name = p_nom;
  UPDATE personnages_donnees SET liquide = liquide - least(l, p_montant) WHERE name = p_nom; RETURN least(l, p_montant); END $$;
CREATE FUNCTION crim_resoudre_interne(p_acte text, p_auteur text, p_cible text, p jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION crim_proprietaire_pj_interne(p text) RETURNS text LANGUAGE sql AS $$ SELECT p $$;
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
  RETURN jsonb_build_object('ok', true, 'legal', v_legal);
END $function$;
CREATE FUNCTION public.equipement_desinstaller(p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text := public.mon_personnage(); e public.equipements_installes;
BEGIN
  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))
     < 1 THEN RETURN '{"ok":false}'; END IF;
  RETURN jsonb_build_object('ok', true);
END $function$;
-- Réductions des deux fonctions raccordées par 20261125600000 : lignes d'ancrage identiques à la production.
CREATE FUNCTION public.transport_effectuer(p_mode text, p_pays text, p_ville text, p_requete uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE moi text;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL THEN
 RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
 UPDATE public.personnages_donnees SET country=p_pays,current_city=p_ville,current_building='centre-multinodal-luthecia',current_room='hall_gare' WHERE name=moi;
 RETURN jsonb_build_object('ok',true,'pays',p_pays,'ville',p_ville);
END $function$;
CREATE FUNCTION public.acheter_produit_manufacture(p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_inv jsonb; v_enc int := 3;
BEGIN
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = p_acteur;
  v_inv := v_inv || jsonb_build_array(jsonb_build_object(
    'type', p_produit, 'name', p_produit, 'encombrement', v_enc,
    'desc', 'Acheté à l''atelier.'));
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'inventory', v_inv);
END; $function$;
INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, liquide) VALUES
  ('Touriste', 'republic', 'ville_a', 'marche-psm', 'etals', 100),
  ('Fauche', 'republic', 'ville_a', 'marche-psm', 'etals', 5),
  ('Krasnovien', 'soviet', 'ville_b', 'musee-novomirsk', 'hall', 50),
  ('Ailleurs', 'republic', 'capitale', 'marche', 'marche_ext', 100);
INSERT INTO jouissances VALUES ('Touriste', 'salon');`;
let nreq = 0; const req = () => '00000000-0000-4000-8000-' + String(++nreq).padStart(12, '0');
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG_ARMOIRE));
  await db.exec(lire(MIG));
  return db;
}
const en = (db, qui) => db.query("SELECT set_config('banc.moi', $1, false)", [qui]);
const rpc = async (db, qui, sql, p = []) => { await en(db, qui); return (await db.query('SELECT ' + sql + ' r', p)).rows[0].r; };

test('3.2 listes 2, 3, 4 mot pour mot ; toutes à clé ou carte ; cartes postales existantes ; guide des baies réutilisé', async () => {
  const db = await base();
  for (const [id, noms] of Object.entries(LISTES)) {
    const r = (await db.query('SELECT nom FROM souvenirs_emplacements WHERE liste_id = $1 ORDER BY rang', [Number(id)])).rows.map(x => x.nom);
    assert.deepEqual(r, noms, 'liste ' + id);
  }
  assert.equal((await db.query('SELECT count(*)::int n FROM souvenirs_emplacements WHERE cle_objet IS NULL AND carte_modele IS NULL')).rows[0].n, 0);
  const cartes = (await db.query('SELECT liste_id, carte_modele FROM souvenirs_emplacements WHERE carte_modele IS NOT NULL ORDER BY 1, rang')).rows;
  assert.deepEqual(cartes.map(c => c.liste_id + ':' + c.carte_modele), ['2:carte_montrouge_place_rail', '3:carte_luthecia_institutions',
    '3:carte_psm_notre_dame_mer', '3:carte_starovka_hiver', '4:carte_montrouge_touristique']);
  assert.equal((await db.query("SELECT cle_objet FROM souvenirs_emplacements WHERE liste_id = 2 AND rang = 6")).rows[0].cle_objet, 'guide_baies_krasnov');
  // Toute clé de souvenir citée par une liste est un objet défini ; ceux des villes fermées ne se vendent nulle part.
  assert.equal((await db.query("SELECT count(*)::int n FROM souvenirs_emplacements e WHERE cle_objet LIKE 'souv_%' AND NOT EXISTS (SELECT 1 FROM souvenirs_objets s WHERE s.cle = e.cle_objet AND s.nom = e.nom)")).rows[0].n, 0);
  const f = (await db.query("SELECT count(*)::int n, bool_or(achetable) a FROM souvenirs_objets WHERE ville_nom = ANY($1)", [FERMEES])).rows[0];
  assert.equal(f.n, 24); assert.equal(f.a, false);
  assert.equal((await db.query('SELECT count(*)::int n FROM souvenirs_objets WHERE achetable')).rows[0].n, 18);
});

test('3.1 achat sur place : seul ce qui se vend dans la pièce ; idempotent ; liquide ; refus nommés sans révéler le lieu', async () => {
  const db = await base();
  const ici = await rpc(db, 'Touriste', 'souvenirs_ici()');
  assert.deepEqual(ici.souvenirs.map(s => s.cle).sort(), ['souv_psm_mug', 'souv_psm_sel']);
  assert.equal(ici.souvenirs[0].devise, 'FR');
  assert.equal(JSON.stringify(ici).includes('batiment'), false, 'aucun lieu rendu');
  assert.deepEqual((await rpc(db, 'Ailleurs', 'souvenirs_ici()')).souvenirs, [], 'rien au marché de Luthécia');
  const r1 = req();
  const a = await rpc(db, 'Touriste', 'souvenir_acheter($1,$2)', [r1, 'souv_psm_mug']);
  assert.equal(a.ok, true); assert.equal(a.paye, 20); assert.equal(Number(a.paie.liquide), 80);
  const mug = a.inventory.find(o => o.type === 'souv_psm_mug');
  assert.equal(mug.name, 'Mug « Port Sainte-Marie »'); assert.equal(mug.souvenir, true);
  const b = await rpc(db, 'Touriste', 'souvenir_acheter($1,$2)', [r1, 'souv_psm_mug']);
  assert.equal(b.rejeu, true);
  assert.equal(Number((await db.query("SELECT liquide FROM personnages_donnees WHERE name = 'Touriste'")).rows[0].liquide), 80, 'rejeu : pas de second paiement');
  // Vendu ailleurs, inconnu, ou ville fermée : même refus.
  for (const cle of ['souv_luthecia_palais', 'souv_nimporte', 'souv_ciudad_masque'])
    assert.equal((await rpc(db, 'Touriste', 'souvenir_acheter($1,$2)', [req(), cle])).raison, 'pas_vendu_ici', cle);
  assert.equal((await rpc(db, 'Fauche', 'souvenir_acheter($1,$2)', [req(), 'souv_psm_sel'])).raison, 'fonds_insuffisants');
  const k = await rpc(db, 'Krasnovien', 'souvenir_acheter($1,$2)', [req(), 'souv_krasnov_insigne']);
  assert.equal(k.devise, 'PSK'); assert.equal(k.ok, true);
  // Réglage MJ du prix.
  await db.exec("UPDATE souvenirs_objets SET prix = 33 WHERE cle = 'souv_psm_sel'");
  assert.equal((await rpc(db, 'Touriste', 'souvenir_acheter($1,$2)', [req(), 'souv_psm_sel'])).paye, 33);
  // Joueur anonyme : rien.
  await assert.rejects(db.query('SET ROLE anon; SELECT souvenirs_ici();'));
  await db.exec('RESET ROLE');
  await assert.rejects(db.query('SET ROLE authenticated; SELECT * FROM souvenirs_objets;'), 'la table des lieux est secrète');
  await db.exec('RESET ROLE');
});

test('3.1 armoire : le souvenir acheté remplit son emplacement ; un nom réécrit ne suffit plus ; carte postale de la liste', async () => {
  const db = await base();
  await db.exec(`INSERT INTO equipements_installes (id, proprietaire, pays, ville, batiment, piece, generique_id, objet) VALUES
    ('00000000-0000-0000-0000-00000000000a', 'Touriste', 'republic', 'ville_a', 'marche-psm', 'etals', 'armoire_souvenirs', '{"id":"arm-1","listeId":1}'),
    ('00000000-0000-0000-0000-00000000000c', 'Touriste', 'republic', 'ville_a', 'marche-psm', 'etals', 'armoire_souvenirs', '{"id":"arm-3","listeId":3}');
    INSERT INTO jouissances VALUES ('Touriste', 'etals');`);
  const a = await rpc(db, 'Touriste', 'souvenir_acheter($1,$2)', [req(), 'souv_psm_mug']);
  const mug = a.inventory.find(o => o.type === 'souv_psm_mug');
  await db.exec(`UPDATE personnages_donnees SET inventory = inventory || '[{"id":"faux","name":"Poupée traditionnelle de Novomirsk"},
    {"id":"cp","name":"Carte","familleProduitMarche":"carte_postale","modele":"carte_psm_notre_dame_mer"}]' WHERE name = 'Touriste'`);
  const d = await rpc(db, 'Touriste', 'armoire_deposer($1,$2,$3)', [req(), '00000000-0000-0000-0000-00000000000a', mug.id]);
  assert.equal(d.ok, true); assert.equal(d.rang, 3);
  assert.equal((await rpc(db, 'Touriste', 'armoire_deposer($1,$2,$3)', [req(), '00000000-0000-0000-0000-00000000000a', 'faux'])).raison, 'hors_liste',
    'un objet qui porte seulement le nom ne remplit pas l’emplacement');
  const c = await rpc(db, 'Touriste', 'armoire_deposer($1,$2,$3)', [req(), '00000000-0000-0000-0000-00000000000c', 'cp']);
  assert.equal(c.rang, 3, 'la carte de Notre-Dame de la Mer remplit l’emplacement de Port-Sainte-Marie (liste 3)');
  // 3.3 : les emplacements des villes fermées sont signalés.
  const s = await rpc(db, 'Touriste', 'armoire_lire($1)', ['00000000-0000-0000-0000-00000000000c']);
  assert.deepEqual(s.emplacements.filter(e => e.ville_fermee).map(e => e.ville), FERMEES);
});

test('3.2 armoire fabriquée : une des quatre listes au hasard, gardée sur l’objet', async () => {
  const db = await base();
  const vus = new Set();
  for (let i = 0; i < 40; i++) {
    await db.exec("UPDATE personnages_donnees SET inventory = '[]' WHERE name = 'Ailleurs'");
    const v = (await db.query("SELECT acheter_produit_manufacture('Ailleurs', 'republic', 'armoire_souvenirs') r")).rows[0].r;
    const o = v.inventory[0];
    assert.equal(o.name, 'Armoire à souvenirs'); assert.match(o.id, /^armoire_souvenirs_/); assert.ok([1, 2, 3, 4].includes(o.listeId));
    vus.add(o.listeId);
  }
  assert.ok(vus.size >= 3, 'tirage au hasard parmi les listes : ' + [...vus]);
  const autre = (await db.query("SELECT acheter_produit_manufacture('Ailleurs', 'republic', 'meuble') r")).rows[0].r;
  assert.equal(autre.inventory.at(-1).listeId, undefined, 'les autres produits ne changent pas');
});

test('3.3 frontières fermées : voyage refusé avec le message ; aucune écriture de position dans une ville fermée', async () => {
  const db = await base();
  for (const [p, v] of [['narco', 'capitale'], ['narco', 'ville_a'], ['narco', 'ville_b'], ['khalija', 'capitale'], ['khalija', 'ville_a'], ['khalija', 'ville_b']]) {
    const r = await rpc(db, 'Ailleurs', 'transport_effectuer($1,$2,$3,$4)', ['avion', p, v, req()]);
    assert.equal(r.ok, false); assert.equal(r.raison, 'frontiere_fermee'); assert.equal(r.message, 'Frontière fermée, ouverture au premier trimestre 2027');
  }
  assert.equal((await rpc(db, 'Ailleurs', 'transport_effectuer($1,$2,$3,$4)', ['train', 'republic', 'ville_b', req()])).ok, true, 'Républia reste ouverte');
  await assert.rejects(db.query("UPDATE personnages_donnees SET country = 'khalija', current_city = 'ville_b' WHERE name = 'Ailleurs'"), /frontiere_fermee/);
  await assert.rejects(db.query("INSERT INTO personnages_donnees (name, country, current_city) VALUES ('Nouveau', 'narco', 'capitale')"), /frontiere_fermee/);
  // Ouvrir une ville = supprimer sa ligne.
  await db.exec("DELETE FROM frontieres_fermees WHERE pays = 'narco' AND ville = 'capitale'");
  assert.equal((await rpc(db, 'Ailleurs', 'transport_effectuer($1,$2,$3,$4)', ['avion', 'narco', 'capitale', req()])).ok, true);
  await db.exec(lire(MIG));   // rejouable
});
