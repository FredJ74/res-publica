'use strict';
// Mission du 27/11/2026 (après-midi), étape 2 : chaque ambassade de Républia et de Sovarka est ouverte, et l'on contrôle
// quels ordres y sont actifs ou grisés. L'Ambassade de Républia à Novomirsk raccorde relations bilatérales, réception
// (Grande Salle du Pavillon) et mécénat aux fonctions de Luthécia ; le transfert d'un détenu reste grisé (Fred, 01/11).
// Partie serveur : migration 20261127150000 dans PGlite (PGLITE_DIR), sur des copies des définitions de production.
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-ambassades-republia-sovarka-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261127150000_ambassade_novomirsk_ordres.sql';
const { BUILDINGS } = Function(lire('data.js') + '\nreturn {BUILDINGS};')();
const politique = lire('plateau-politique.js');

// Toutes les ambassades de Républia et de Sovarka du jeu (bâtiment, pièce, pays de l'ambassade).
const AMBASSADES = [
  ['quartier-ambassades', 'bureau_sovarka', 'soviet', 'Ambassade de Sovarka à Luthécia'],
  ['palais-ambassades-novomirsk', 'bureau_republia_novomirsk', 'republic', 'Ambassade de Républia à Novomirsk'],
];
const DECIDES = ['relations_bilaterales', 'organiser_reception_diplomatique', 'financer_oeuvre_culturelle'];

test('il n’existe pas d’autre ambassade de Républia ou de Sovarka que celles contrôlées ici', () => {
  const trouvees = [];
  for (const [b, bat] of Object.entries(BUILDINGS)) for (const [r, room] of Object.entries(bat.rooms || {})) {
    if (/^Ambassade de (Républia|Sovarka)$/.test(room.name || '')) trouvees.push(b + '/' + r);
  }
  assert.deepEqual(trouvees.sort(), AMBASSADES.map(a => a[0] + '/' + a[1]).sort());
});

for (const [bat, piece, empire, nom] of AMBASSADES) {
  test(nom + ' : ordres décidés actifs et réservés à l’ambassadeur, transfert d’un détenu grisé', () => {
    const ordres = BUILDINGS[bat].rooms[piece].orders;
    const actifs = ordres.filter(o => !o.bientot).map(o => o.fn), grises = ordres.filter(o => o.bientot).map(o => o.fn);
    assert.deepEqual(actifs, DECIDES, nom);
    assert.deepEqual(grises, ['demander_transfert_detenu'], nom);
    for (const o of ordres.filter(o => !o.bientot)) assert.equal(o.requiresPost, 'ambassadeur_local', o.fn);
    // Mêmes coûts qu'à Luthécia (le serveur prélève par payer_ordre avec ces montants).
    const ref = BUILDINGS['quartier-ambassades'].rooms.bureau_sovarka.orders;
    for (const fn of DECIDES) {
      const a = ordres.find(o => o.fn === fn), b = ref.find(o => o.fn === fn);
      assert.deepEqual([a.pa, a.cost], [b.pa, b.cost], fn);
    }
    // L'écran reconnaît le bureau (relations, réception, mécénat) et l'ambassadeur nommé pour ce bureau.
    const carte = vm.runInNewContext('(' + politique.match(/const AMBASSADE_ROOM_EMPIRE_MAP = (\{[^}]+\})/)[1] + ')');
    assert.equal(carte[piece], empire, nom);
  });
}

test('écran : le contrôle « ambassadeur nommé pour ce bureau » lit la carte complète (Luthécia et Novomirsk)', () => {
  const i = politique.indexOf("else if (reqPost === 'ambassadeur_local')");
  const bloc = politique.slice(i, politique.indexOf('}', politique.indexOf('needsPost =', i)));
  assert.match(bloc, /AMBASSADE_ROOM_EMPIRE_MAP\[roomId\]/);
  assert.doesNotMatch(bloc, /const AMBASSADE_ROOM_EMPIRE = /);
  // Repli tant que la migration n'est pas appliquée : un refus nommé, rien de prélevé.
  assert.match(politique, /pas_sur_place: 'Cet ordre ouvrira à Novomirsk dès la mise à jour du serveur\. Rien n\\'a été prélevé\.'/);
  const cat = lire('i18n/toast-bodies-resources.js');
  assert.ok(cat.includes('["Cet ordre ouvrira à Novomirsk dès la mise à jour du serveur. Rien n\'a été prélevé.",'));
  assert.ok(cat.includes('["Réservez d\'abord pour aujourd\'hui la Grande Salle de Réception du Pavillon des Ambassadeurs (« Réserver la réception », dans la salle).",'));
});

test('les autres bureaux de Novomirsk (Al-Khalija, El Estado) restent grisés', () => {
  for (const piece of ['bureau_khalija_novomirsk', 'bureau_estado_novomirsk']) {
    assert.ok(BUILDINGS['palais-ambassades-novomirsk'].rooms[piece].orders.every(o => o.bientot), piece);
  }
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

// Socle réduit : tables et fonctions appelées, définitions de production du 27/11 pour mecenat (inchangée).
const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, current_building text, current_room text, pop integer DEFAULT 0);
CREATE TABLE ambassades_ouvertes (id text PRIMARY KEY, pays_hote text, empire text, data jsonb);
CREATE TABLE reservations_salle_reception (id text PRIMARY KEY, pays_hote text, jour integer, data jsonb, created_at timestamptz DEFAULT now());
CREATE TABLE pavillon_receptions (jour date PRIMARY KEY, acteur text, pays_payeur text, poste_payeur text, caisse_payeur text, montant integer, cree_le timestamptz DEFAULT now());
CREATE TABLE journal (quoi text, val text);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('rp.moi', true), '') $f$;
CREATE FUNCTION payer_ordre(a text, fn text, pa integer, cost integer) RETURNS jsonb LANGUAGE plpgsql AS $f$
BEGIN INSERT INTO journal VALUES ('paie', fn || ':' || pa || ':' || cost); RETURN jsonb_build_object('ok', true, 'pa', pa); END $f$;
CREATE FUNCTION indice_diplomatique_varier_interne(e text, d integer, motif text, a text) RETURNS integer LANGUAGE plpgsql AS $f$
BEGIN INSERT INTO journal VALUES ('indice', e || ':' || d); RETURN 40 + d; END $f$;
CREATE FUNCTION personnage_ajuster_pop_inf(a text, b text, d integer, i integer) RETURNS jsonb LANGUAGE plpgsql AS $f$
BEGIN UPDATE personnages_donnees SET pop = pop + d WHERE name = a; RETURN jsonb_build_object('pop', (SELECT pop FROM personnages_donnees WHERE name = a)); END $f$;
CREATE FUNCTION annonce_publique_interne(p text, t text) RETURNS void LANGUAGE sql AS $f$ INSERT INTO journal VALUES ('annonce', p || ':' || t) $f$;
CREATE FUNCTION empire_nom_interne(e text) RETURNS text LANGUAGE sql AS $f$ SELECT CASE e WHEN 'republic' THEN 'Républia' WHEN 'soviet' THEN 'Sovarka' ELSE e END $f$;
CREATE FUNCTION jour_de_jeu_pays(p text) RETURNS integer LANGUAGE sql AS $f$ SELECT 12 $f$;
CREATE FUNCTION public.ambassade_mecenat(p_empire text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE m jsonb; v_moi text; v_paie jsonb; v_indice integer; v_pop jsonb;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_moi := m ->> 'moi';
  v_paie := public.payer_ordre(v_moi, 'financer_oeuvre_culturelle', 1, 600);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_indice := public.indice_diplomatique_varier_interne(p_empire, 3, 'mecenat_culturel', v_moi);
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, 8, NULL);
  PERFORM public.annonce_publique_interne(m ->> 'hote', 'SOFT POWER : ' || public.empire_nom_interne(p_empire) || ' finance une œuvre culturelle.');
  RETURN jsonb_build_object('ok', true, 'indice', v_indice, 'pop', v_pop -> 'pop', 'paie', v_paie);
END; $function$;
INSERT INTO ambassades_ouvertes VALUES
  ('soviet-republic', 'soviet', 'republic', '{"empire":"republic","ambassadeur":"Hubert"}'),
  ('republic-soviet', 'republic', 'soviet', '{"empire":"soviet","ambassadeur":"Valery"}');
INSERT INTO personnages_donnees (name, country, current_building, current_room) VALUES
  ('Hubert', 'soviet', 'palais-ambassades-novomirsk', 'bureau_republia_novomirsk'),
  ('Valery', 'republic', 'quartier-ambassades', 'bureau_sovarka'),
  ('Olga', 'soviet', 'pavillon-ambassadeurs-novomirsk', 'salle_reception'),
  ('Boris', 'soviet', 'pavillon-ambassadeurs-novomirsk', 'salle_reception'),
  ('Pierre', 'republic', 'quartier-ambassades', 'salle_reception'),
  ('Ivan', 'soviet', 'palais-ambassades-novomirsk', 'accueil_ambassades_novomirsk');`;

async function base() {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG)); return db;
}
async function rpc(db, moi, fn, empire) {
  await db.query("SELECT set_config('rp.moi', $1, false)", [moi]);
  return (await db.query(`SELECT public.${fn}($1) AS r`, [empire])).rows[0].r;
}

test('serveur : l’ambassadeur de Républia agit depuis le Palais de Novomirsk (mécénat), pas ailleurs ; Luthécia inchangée', async () => {
  const db = await base();
  let r = await rpc(db, 'Hubert', 'ambassade_mecenat', 'republic');
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.indice, 43); assert.equal(r.pop, 8);
  const ann = (await db.query("SELECT val FROM journal WHERE quoi = 'annonce'")).rows.map(x => x.val);
  assert.deepEqual(ann, ['soviet:SOFT POWER : Républia finance une œuvre culturelle.']);
  await db.exec("UPDATE personnages_donnees SET current_building = 'quartier-ambassades' WHERE name = 'Hubert'");
  assert.equal((await rpc(db, 'Hubert', 'ambassade_mecenat', 'republic')).raison, 'pas_sur_place');
  assert.equal((await rpc(db, 'Ivan', 'ambassade_mecenat', 'republic')).raison, 'reserve_ambassadeur');
  r = await rpc(db, 'Valery', 'ambassade_mecenat', 'soviet');
  assert.equal(r.ok, true, 'Luthécia : ' + JSON.stringify(r));
  await db.exec("UPDATE personnages_donnees SET current_building = 'palais-ambassades-novomirsk' WHERE name = 'Valery'");
  assert.equal((await rpc(db, 'Valery', 'ambassade_mecenat', 'soviet')).raison, 'pas_sur_place');
});

test('serveur : réception à Novomirsk dans la Grande Salle du Pavillon réservée ce jour par l’ambassadeur ; une seule', async () => {
  const db = await base();
  assert.equal((await rpc(db, 'Hubert', 'ambassade_reception_organiser', 'republic')).raison, 'salle_non_reservee');
  // La réservation gratuite de Luthécia n'existe pas en Sovarka : la salle se réserve au Pavillon (1 500 PSK, institution).
  assert.equal((await rpc(db, 'Hubert', 'ambassade_reserver_salle', 'republic')).raison, 'reservation_au_pavillon');
  await db.exec("INSERT INTO pavillon_receptions (jour, acteur, pays_payeur, poste_payeur, caisse_payeur, montant) VALUES ((now() AT TIME ZONE 'Europe/Paris')::date, 'Autre', 'republic', 'min_ae', 'x', 1500)");
  assert.equal((await rpc(db, 'Hubert', 'ambassade_reception_organiser', 'republic')).raison, 'salle_non_reservee', 'réservée par un autre');
  await db.exec("UPDATE pavillon_receptions SET acteur = 'Hubert'");
  const r = await rpc(db, 'Hubert', 'ambassade_reception_organiser', 'republic');
  assert.equal(r.ok, true, JSON.stringify(r));
  assert.deepEqual([r.invites, r.delta_indice, r.delta_pop], [2, 2, 2], 'Olga et Boris, joueurs de Sovarka présents dans la salle');
  assert.deepEqual((await db.query("SELECT val FROM journal WHERE quoi = 'paie'")).rows.map(x => x.val), ['organiser_reception_diplomatique:2:1200']);
  assert.equal((await rpc(db, 'Hubert', 'ambassade_reception_organiser', 'republic')).raison, 'reception_deja_donnee');
  assert.equal((await db.query('SELECT invites FROM pavillon_receptions')).rows[0].invites, 2);
});

test('serveur : réception de Luthécia inchangée (salle du Quartier, réservation à l’accueil) ; migration rejouable', async () => {
  const db = await base();
  assert.equal((await rpc(db, 'Valery', 'ambassade_reserver_salle', 'soviet')).ok, true);
  const r = await rpc(db, 'Valery', 'ambassade_reception_organiser', 'soviet');
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.invites, 1, 'Pierre');
  assert.equal((await rpc(db, 'Valery', 'ambassade_reception_organiser', 'soviet')).raison, 'reception_deja_donnee');
  await db.exec(lire(MIG));
  const salle = await rpc(db, 'Hubert', 'ambassade_reception_organiser', 'republic');
  assert.equal(salle.raison, 'salle_non_reservee');
});
