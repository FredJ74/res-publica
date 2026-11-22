'use strict';
// Santé — maladies, MST, escort, médicaments, fontaines (Fred, 22/11/2026, GAME-DESIGN-SANTE-20261122.md, points 4, 5, 6,
// 13 et 20), migration 20261122233000 sur le socle 20261122230000, dans un vrai PostgreSQL local (PGlite).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const SOCLE = 'migrations/20261122230000_sante_socle.sql';
const MIGRATION = 'migrations/20261122233000_sante_maladies_medicaments.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', ana: '00000000-0000-0000-0000-000000000002', mj: '00000000-0000-0000-0000-0000000000aa' };
// Texte exact de Fred (GAME-DESIGN-SANTE-20261122.md, point 5).
const TEXTE_MST = n => "Ces 10 derniers jours, vous avez eu des relations avec " + n
  + " partenaires. L'un d'eux ou l'une d'elles vous a transmis une MST. −10 points de Santé.";

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec(lire('outils/bancs/fixtures/sante-maladies-pglite.sql.txt'));
  await db.query('INSERT INTO personnages VALUES ($1,$2), ($3,$4)', ['Tom Tom', U.tom, 'Ana Ana', U.ana]);
  await db.query('INSERT INTO administrateurs VALUES ($1, true)', [U.mj]);
  await db.query(`INSERT INTO personnages_donnees (name, user_id, hp, moral, liquide, country, current_city, current_building, current_room)
    VALUES ('Tom Tom', $1, 80, 50, 10000, 'republic', 'capitale', 'usine-pharmaceutique-luthecia', 'salle_production'),
           ('Ana Ana', $2, 80, 50, 10000, 'soviet', 'capitale', 'pharmacie-officielle-novomirsk', 'comptoir_pharmacie')`, [U.tom, U.ana]);
  await db.query("INSERT INTO pnj_membres VALUES ('e1','Lola','Tom Tom'), ('e2','Mia','Tom Tom'), ('e3','Zoé','Tom Tom'), ('e4','Iris','Tom Tom')");
  await db.exec(lire(SOCLE));
  await db.exec(lire(MIGRATION));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const hp = (db, nom) => un(db, 'SELECT hp r FROM personnages_donnees WHERE name = $1', [nom || 'Tom Tom']);
const amour = async (db, escort) => { await en(db, U.tom); return un(db, 'SELECT escort_intimite(gen_random_uuid(), $1) r', [escort]); };

test('la migration se rejoue, ne touche aucune Santé et pose le catalogue', async () => {
  const db = await base();
  assert.equal(await hp(db), 80);
  await db.exec(lire(MIGRATION));
  assert.equal(await hp(db), 80);
  const p = (await db.query('SELECT cle, perte_sante, guerison_spontanee FROM maladies_parametres ORDER BY cle')).rows;
  assert.deepEqual(Object.fromEntries(p.map(r => [r.cle, r.perte_sante])),
    { coup_de_chaleur: 5, grippe: 10, gueule_de_bois: 3, intoxication: 10, mst: 10 });
  const mst = (await db.query("SELECT * FROM maladies_parametres WHERE cle = 'mst'")).rows[0];
  assert.equal(mst.contagieuse, false); assert.equal(mst.guerison_spontanee, false); assert.equal(mst.medicament, 'antibiotique');
  assert.deepEqual(mst.deltas, { CHA: -2 });
  // Un réglage du MJ n'est pas écrasé par un rejeu.
  await en(db, U.mj);
  assert.equal((await un(db, `SELECT admin_maladie_modifier('grippe', '{"perte_sante": 7}') r`)).ok, true);
  await db.exec(lire(MIGRATION));
  assert.equal(await un(db, "SELECT perte_sante r FROM maladies_parametres WHERE cle = 'grippe'"), 7);
});

test('point 4 : la perte de Santé tombe à la contraction, une seule fois', async () => {
  const db = await base();
  const v = await un(db, "SELECT maladie_contracter_interne('Tom Tom', 'intoxication', 'test') r");
  assert.equal(v.sante_perdue, 10); assert.equal(await hp(db), 70);
  assert.equal(await un(db, "SELECT maladie_contracter_interne('Tom Tom', 'intoxication', 'test') r"), null, 'déjà malade : rien');
  assert.equal(await hp(db), 70);
  await un(db, "SELECT maladie_contracter_interne('Tom Tom', 'gueule_de_bois', 'test') r");
  assert.equal(await hp(db), 67);
  await un(db, "SELECT maladie_contracter_interne('Tom Tom', 'coup_de_chaleur', 'test') r");
  await un(db, "SELECT maladie_contracter_interne('Tom Tom', 'grippe', 'test') r");
  assert.equal(await hp(db), 52, 'perte jamais modulée par le Moral');
  await db.query("UPDATE personnages_donnees SET hp = 4 WHERE name = 'Ana Ana'");
  assert.equal((await un(db, "SELECT maladie_contracter_interne('Ana Ana', 'grippe', 'test') r")).sante_perdue, 4, 'plancher 0');
  assert.equal(await hp(db, 'Ana Ana'), 0);
});

test('point 6 : faire l’amour ne donne plus de Santé, le Moral reste', async () => {
  const db = await base();
  const r = await amour(db, 'Lola');
  assert.equal(r.ok, true); assert.equal(r.gain_hp, 0); assert.equal(r.gain_moral, 15);
  assert.equal(await hp(db), 80);
  assert.equal(await un(db, "SELECT moral r FROM personnages_donnees WHERE name = 'Tom Tom'"), 65);
});

test('point 5 : même escort revue = aucun risque ; MST tirée au 3e partenaire, révélée au réveil avec le texte exact', async () => {
  const db = await base();
  await db.query("UPDATE sante_parametres SET valeur = 0.5 WHERE cle = 'mst_risque_par_partenaire'");
  // La même escort trois fois : un seul partenaire, aucun tirage possible.
  for (let i = 0; i < 3; i++) await amour(db, 'Lola');
  assert.equal(Number(await un(db, "SELECT count(*) r FROM mst_en_attente")), 0);
  assert.equal(Number(await un(db, "SELECT count(*) r FROM escort_relations WHERE client = 'Tom Tom'")), 3, 'chaque relation est tracée');
  // 2e partenaire (Mia, vue deux fois) : risque 50 % à chaque acte ; on force le hasard (setseed) pour que ces deux
  // tirages échouent.
  let graine = 0;
  for (; graine < 1; graine += 0.01) {
    await db.query('SELECT setseed($1)', [graine]);
    if (await un(db, 'SELECT random() r') >= 0.5 && await un(db, 'SELECT random() r') >= 0.5) break;
  }
  await db.query('SELECT setseed($1)', [graine]);
  await amour(db, 'Mia');
  await amour(db, 'Mia');
  assert.equal(Number(await un(db, "SELECT count(*) r FROM mst_en_attente")), 0, 'tirages du 2e partenaire perdus');
  assert.equal(Number(await un(db, "SELECT count(DISTINCT escort) r FROM escort_relations WHERE client = 'Tom Tom'")), 2, 'revoir Mia n’ajoute rien');
  // 3e partenaire : risque 0,5 × 2 = 100 %.
  await amour(db, 'Zoé');
  const att = (await db.query('SELECT * FROM mst_en_attente')).rows;
  assert.equal(att.length, 1); assert.equal(att[0].partenaires, 3); assert.equal(Number(att[0].risque), 1);
  assert.equal(await hp(db), 80, 'rien n’est révélé ni retiré à l’acte');
  assert.equal(Number(await un(db, "SELECT count(*) r FROM personnages_maladies WHERE cle = 'mst'")), 0);
  // Réveil : maladie, perte et journal.
  const rev = await un(db, "SELECT sante_reveil_interne('Tom Tom') r");
  assert.equal(rev.length, 1); assert.equal(rev[0].texte, TEXTE_MST(3));
  assert.equal(await hp(db), 70);
  await en(db, U.tom);
  const ev = (await un(db, 'SELECT personnage_evenements_lire() r')).evenements;
  assert.equal(ev.length, 1); assert.equal(ev[0].cle, 'mst_revelee'); assert.equal(ev[0].texte, TEXTE_MST(3));
  assert.deepEqual(await un(db, "SELECT sante_reveil_interne('Tom Tom') r"), [], 'révélée une seule fois');
  // Malade : −2 CHA, jamais guérie seule, aucun nouveau tirage tant qu'elle dure.
  const eff = await un(db, "SELECT effets_actifs r FROM personnages_donnees WHERE name = 'Tom Tom'");
  assert.deepEqual(eff.find(e => e.maladie === 'mst').deltas, { CHA: -2 });
  assert.ok(await un(db, "SELECT fin > now() + interval '50 years' r FROM personnages_maladies WHERE cle = 'mst'"));
  assert.deepEqual(await un(db, "SELECT maladies_nuit_interne('Tom Tom') r"), [], 'Dormir sans antibiotique : pas de guérison');
  await amour(db, 'Iris');
  assert.equal(Number(await un(db, "SELECT count(*) r FROM mst_en_attente")), 1);
});

test('fenêtre glissante : une escort vue il y a plus de 10 jours ne compte plus', async () => {
  const db = await base();
  await db.query("UPDATE sante_parametres SET valeur = 1 WHERE cle = 'mst_risque_par_partenaire'");
  await amour(db, 'Lola');
  await db.query("UPDATE escort_relations SET cree_le = now() - interval '11 days'");
  const r = await un(db, "SELECT mst_relation_interne('Tom Tom', 'e2') r");
  assert.equal(r.partenaires, 1); assert.equal(r.tire, false);
  const r2 = await un(db, "SELECT mst_relation_interne('Tom Tom', 'e3') r");
  assert.equal(r2.partenaires, 2); assert.equal(Number(r2.risque), 1); assert.equal(r2.tire, true);
});

test('l’antibiotique guérit la MST au Dormir', async () => {
  const db = await base();
  await un(db, "SELECT maladie_contracter_interne('Ana Ana', 'mst', 'escort') r");
  await en(db, U.ana);
  assert.equal((await un(db, "SELECT pharmacie_acheter_interne('Ana Ana', 'antibiotique', 1) r")).ok, true);
  const inv = await un(db, "SELECT inventory r FROM personnages_donnees WHERE name = 'Ana Ana'");
  assert.equal(inv[0].name, 'Antibiotique'); assert.equal(inv[0].soigne, 'mst');
  assert.equal((await un(db, "SELECT medicament_prendre(gen_random_uuid(), 'antibiotique') r")).ok, true);
  assert.deepEqual(await un(db, "SELECT maladies_nuit_interne('Ana Ana') r"), ['mst']);
  assert.equal(await un(db, "SELECT motif_fin r FROM personnages_maladies WHERE cle = 'mst'"), 'medicament');
});

test('point 13 : un seul ordre, le producteur choisit le médicament ; mêmes matières, même salaire ; vendu au comptoir', async () => {
  const db = await base();
  await en(db, U.tom);
  const meds = (await un(db, 'SELECT usine_medicaments_etat() r')).medicaments.map(m => m.medicament).sort();
  assert.deepEqual(meds, ['antibiotique', 'antigrippal', 'antinauseeux', 'aspirine', 'sels_rehydratation']);
  for (const m of ['antibiotique', 'aspirine']) {
    const r = await un(db, "SELECT produire_medicament('Tom Tom', 'republic', $1) r", [m]);
    assert.equal(r.ok, true); assert.equal(r.produits, 10); assert.equal(Number(r.salaire), 84);
  }
  assert.equal((await un(db, "SELECT produire_medicament('Tom Tom', 'republic', 'antibiotique') r")).raison, 'matiere_insuffisante', '12 plantes : 2 × 5');
  assert.equal((await un(db, "SELECT produire_medicament('Tom Tom', 'republic', 'potion') r")).raison, 'medicament_inconnu');
  const usine = await un(db, "SELECT batiment_etat_lire(data) r FROM batiments_etat WHERE id = 'republic_capitale_usine-pharmaceutique-luthecia'");
  assert.equal(usine.usine.stockMatieres.plantes, 2); assert.ok(Math.abs(usine.usine.caisse - (367.56 - 168)) < 1e-6);
  assert.equal(usine.usine.venteDirecte.medicaments, 50, 'la ressource générique n’est pas touchée');
  assert.equal(Number(await un(db, "SELECT liquide r FROM personnages_donnees WHERE name = 'Tom Tom'")), 10168);
  // Au comptoir de l'usine : dotation du jour (5 = 20 × 0,25) + stock produit (10).
  await db.query("UPDATE personnages_donnees SET current_room = 'salle_ventes' WHERE name = 'Tom Tom'");
  const etat = await un(db, 'SELECT pharmacie_etat() r');
  const ab = etat.medicaments.find(m => m.medicament === 'antibiotique');
  assert.equal(ab.restant, 15); assert.equal(ab.prix, 44, 'même règle de prix que les autres');
  const r = await un(db, "SELECT pharmacie_acheter_interne('Tom Tom', 'antibiotique', 10) r");
  assert.equal(r.ok, true); assert.equal(r.restant, 5);
  assert.equal(await un(db, "SELECT quantite r FROM medicaments_stocks WHERE pays = 'republic' AND medicament = 'antibiotique'"), 0, 'le stock produit part en premier');
  const usine2 = await un(db, "SELECT batiment_etat_lire(data) r FROM batiments_etat WHERE id = 'republic_capitale_usine-pharmaceutique-luthecia'");
  assert.ok(Math.abs(usine2.usine.caisse - (367.56 - 168 + 440)) < 1e-6, 'la recette revient à l’usine');
  // Sovarka : même ordre, salaire du pays, pas sur place hors de l'usine.
  await en(db, U.ana);
  assert.equal((await un(db, "SELECT produire_medicament('Ana Ana', 'soviet', 'antibiotique') r")).raison, 'pas_sur_place');
});

test('point 20 : les fontaines donnent une eau potable sans aucun tirage de maladie', async () => {
  const db = await base();
  await db.query("UPDATE personnages_donnees SET current_building = NULL, current_room = NULL, current_street = 'luthecia-hotel-de-ville', pa = 10 WHERE name = 'Tom Tom'");
  await en(db, U.tom);
  await db.query("UPDATE maladies_parametres SET risques = risques || '{\"aliment_avarie\":100,\"plat_avarie\":100}'");
  const r = await un(db, 'SELECT point_eau_puiser(gen_random_uuid(), 3) r');
  assert.equal(r.ok, true); assert.equal(r.quantite, 3);
  assert.equal(Number(await un(db, 'SELECT count(*) r FROM personnages_maladies')), 0);
  const eau = (await un(db, "SELECT inventory r FROM personnages_donnees WHERE name = 'Tom Tom'"))[0];
  assert.equal(eau.stackKey, 'bouteille_eau'); assert.equal(eau.boisson, undefined); assert.equal(eau.familleProduitMarche, undefined);
  assert.doesNotMatch(await un(db, "SELECT pg_get_functiondef('point_eau_puiser(uuid,integer)'::regprocedure) r"), /maladie/);
  assert.equal(Number(await un(db, 'SELECT count(*) r FROM climat_points_eau WHERE actif')), 6);
});
