'use strict';
// Santé — « Suites » (Fred, 22/11/2026 au soir, GAME-DESIGN-SANTE-20261122.md, section « Suites »), migration
// 20261123100000_sante_suites, dans un vrai PostgreSQL local (PGlite). Base : socle d'inventaire, socle Santé 20261122230000,
// doublure et migration de la consommation 20261122232000 (en production), puis la doublure de ce lot (copies de production
// à md5 identique) et la migration.
//  - palier 15 des produits de joueur ; repas du Président, de l'hôpital public et de la clinique ;
//  - robustesse sur « se laisser faire », la répression et la rébellion ;
//  - dons de tracts plafonnés ; rachat des marchés (règle commune, réglage MJ) ; confiture du kolkhoze ;
//  - objectif secret « 5 informations à des informateurs différents ».
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261123100000_sante_suites.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', ana: '00000000-0000-0000-0000-000000000002', mj: '00000000-0000-0000-0000-0000000000aa' };

// Empreintes md5 de pg_get_functiondef en PRODUCTION (22/11/2026 au soir) : la doublure doit être identique, octet pour octet.
const EMPREINTES_PROD = {
  'admin_aliment_modifier(text,numeric)': '80885ac9632f9dda0d37e62598d7f742',
  'detention_se_rebeller(integer,integer)': '3218f6204b9377eec2a1f85eb20d5f80',
  'hospitalisation_repas_prendre()': '8b5f74174cd7f545fc49bc60c944e3cc',
  'inventaire_objet_lire_interne(text)': '5712e46b256ae16097e2cf957d91b484',
  'inventaire_place_destinataire_interne(text)': '5a9b45adca50d3b8d2844d5010e2d1b9',
  'inventaire_place_restante(jsonb,integer)': 'a68fedf0b97d77782cfa2a9461c305fd',
  'inventaire_unites_interne(jsonb)': '0ee5f533fb8e64f9a2db216872545c4d',
  'manifestation_reprimer(text,text)': '0719bb352ae2e7dad43914be2922d3b1',
  'objectifs_secrets_eligibles_interne(text)': '49405bd490e85e057abc2d5c53785725',
  'sante_combat_coup_pj_interne(text,integer,integer,integer,text)': 'ec730d822c5cc798ed1c07dd835ca291',
  'sante_facteur_robustesse(integer)': '0e9d5ec534aa53048b0b1ed3879bbebe',
  'sante_gagner_interne(text,integer,text,jsonb)': '826f57163a853d4ca80bb6c386e0cd4a',
  'sante_perte_combat_interne(integer,integer)': 'fa7239a3b283e22dde315e43dd5993b1',
  'sante_repas_appliquer_interne(text,text,text,jsonb)': 'd87ea04188ae02d6fbcf53059b223e1a',
  'sante_repas_joueur_categorie_interne(numeric)': 'e2b1bc161901486e25d840f96e317142',
  'sovarka_foret_rencontre(uuid,text)': '329f54928b6c9f79746cddcd3a64f299',
  'sovarka_repas_presidentiel(text,text[])': '95798456c73aacd27865dcf404a2fc48',
  'tracts_donner_joueur(uuid,integer,bigint,text,integer)': 'd1b39a737f404f07f7b845c509a12fd8'
};
const MARQUES = {
  'hospitalisation_repas_prendre()': ['sante_suites_repas_decl_v1', 'sante_suites_repas_clinique_v1', 'sante_suites_repas_pa_v1', 'sante_suites_repas_hopital_v1'],
  'sovarka_repas_presidentiel(text,text[])': ['sante_suites_president_v1', 'sante_suites_president_pa_v1', 'sante_suites_president_mail_v1'],
  'sovarka_foret_rencontre(uuid,text)': ['sante_suites_subir_v1'],
  'manifestation_reprimer(text,text)': ['sante_suites_repression_v1'],
  'detention_se_rebeller(integer,integer)': ['sante_suites_rebellion_a_v1', 'sante_suites_rebellion_b_v1', 'sante_suites_rebellion_c_v1', 'sante_suites_rebellion_d_v1'],
  'tracts_donner_joueur(uuid,integer,bigint,text,integer)': ['sante_suites_tracts_plafond_v1'],
  'admin_aliment_modifier(text,numeric)': ['sante_suites_rachat_mj_v1'],
  'objectifs_secrets_eligibles_interne(text)': ['sante_suites_obj_informateur_v1'],
  'sante_repas_joueur_categorie_interne(numeric)': ['sante_suites_p15_v1']
};

async function doublure() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec('ALTER TABLE personnages_donnees ALTER COLUMN detention_qhs DROP DEFAULT; ALTER TABLE personnages_donnees ALTER COLUMN detention_qhs TYPE jsonb USING NULL');
  await db.exec(lire('migrations/20261122230000_sante_socle.sql'));
  await db.exec(lire('outils/bancs/fixtures/sante-consommation-pglite-socle.sql.txt'));
  await db.exec(lire('migrations/20261122232000_sante_consommation.sql'));
  await db.exec(lire('outils/bancs/fixtures/sante-suites-pglite.sql.txt'));
  return db;
}
async function base({ hp = 50, moral = 50, pa = 20 } = {}) {
  const db = await doublure();
  await db.query('INSERT INTO personnages VALUES ($1,$2), ($3,$4)', ['Tom Tom', U.tom, 'Ana', U.ana]);
  await db.query(`INSERT INTO personnages_donnees (name, user_id, country, current_city, current_building, current_room, hp, moral, pa)
                  VALUES ('Tom Tom', $1, 'soviet', 'capitale', 'palais-presidentiel', 'salle_reception', $3, $4, $5),
                         ('Ana', $2, 'soviet', 'capitale', 'palais-presidentiel', 'salle_reception', $3, $4, $5)`, [U.tom, U.ana, hp, moral, pa]);
  await db.query('INSERT INTO administrateurs (user_id) VALUES ($1)', [U.mj]);
  await db.exec('SET check_function_bodies = on');
  await db.exec(lire(MIGRATION));
  await en(db, U.tom);
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
const r = async (db, sql, p) => (await un(db, sql, p)).r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const fiche = (db, nom = 'Tom Tom') => un(db, 'SELECT hp, moral, pa, bonus_pa_differe, hospitalisation, liquide FROM personnages_donnees WHERE name=$1', [nom]);
const poser = (db, champs, nom = 'Tom Tom') => {
  const cles = Object.keys(champs);
  return db.query(`UPDATE personnages_donnees SET ${cles.map((k, i) => `${k}=$${i + 2}`).join(', ')} WHERE name=$1`, [nom, ...cles.map(k => champs[k])]);
};

test('doublure identique à la production (md5), migration rejouable, marques posées une fois, aucune Santé ni PA modifiés', async () => {
  const db = await doublure();
  const md5 = await db.query(`SELECT p.oid::regprocedure::text s, md5(pg_get_functiondef(p.oid)) m FROM pg_proc p
                               WHERE pronamespace = 'public'::regnamespace AND p.oid::regprocedure::text = ANY($1)`, [Object.keys(EMPREINTES_PROD)]);
  assert.deepEqual(Object.fromEntries(md5.rows.map(x => [x.s, x.m])), EMPREINTES_PROD);
  await db.query('INSERT INTO personnages VALUES ($1,$2)', ['Tom Tom', U.tom]);
  await db.query(`INSERT INTO personnages_donnees (name, user_id, hp, pa, moral) VALUES ('Tom Tom', $1, 37, 11, 80)`, [U.tom]);
  await db.exec('SET check_function_bodies = on');
  await db.exec(lire(MIGRATION));
  await db.exec(lire(MIGRATION));
  assert.deepEqual(await un(db, "SELECT hp, pa, moral FROM personnages_donnees WHERE name = 'Tom Tom'"), { hp: 37, pa: 11, moral: 80 });
  for (const [f, marques] of Object.entries(MARQUES)) {
    const d = await r(db, 'SELECT pg_get_functiondef($1::regprocedure) r', ['public.' + f]);
    for (const m of marques) assert.equal(d.split(m).length - 1, 1, f + ' ' + m);
  }
});

test('point 2 : palier 15 et plus = menu (+5 Santé, +3 PA différés), réglable ; contrainte élargie', async () => {
  const db = await base();
  assert.equal(await r(db, 'SELECT sante_repas_joueur_categorie_interne(15) r'), 'joueur_p15');
  assert.equal(await r(db, 'SELECT sante_repas_joueur_categorie_interne(14.99) r'), 'joueur_p10');
  assert.equal(await r(db, 'SELECT sante_repas_joueur_categorie_interne(9) r'), 'joueur_p5');
  const v = await r(db, "SELECT sante_repas_appliquer_interne('Tom Tom', 'joueur_p15', 'test') r");
  assert.equal(v.gain, 5); assert.equal(v.pa_differe, 3);
  assert.deepEqual([(await fiche(db)).hp, (await fiche(db)).bonus_pa_differe], [55, 3]);
  await db.query("INSERT INTO sante_repas_categories (cle, categorie, libelle) VALUES ('plat_joueur_test', 'joueur_p15', 'Plat de joueur')");
  await db.query("UPDATE sante_parametres SET valeur = 20 WHERE cle = 'repas_joueur_p15_prix_min'");
  assert.equal(await r(db, 'SELECT sante_repas_joueur_categorie_interne(15) r'), 'joueur_p10');
  // Point 1 : la page du MJ ne dit plus « Snack ».
  assert.equal((await db.query("SELECT 1 FROM sante_parametres WHERE libelle ILIKE '%snack%'")).rows.length, 0);
});

test('point 3 : repas de l\'hôpital public (+4 / +2, gratuit, hospitalisés seulement) et de la clinique (+5 / +4, 30 FR)', async () => {
  const db = await base();
  await poser(db, { country: 'republic', current_city: 'capitale', current_building: 'dispensaire-public', current_room: 'chambre_1', pa: 5 });
  assert.equal((await r(db, 'SELECT hospitalisation_repas_prendre() r')).raison, 'non_hospitalise');
  await poser(db, { hospitalisation: JSON.stringify({ regime: 'pa0', jour: 1, lieu: 'hopital' }) });
  const h = await r(db, 'SELECT hospitalisation_repas_prendre() r');
  assert.equal(h.ok, true, JSON.stringify(h));
  assert.deepEqual([h.cout, h.bonus_lendemain, h.sante_gain, h.hp], [0, 2, 4, 54]);
  let f = await fiche(db);
  assert.deepEqual([f.hp, f.pa, f.liquide, f.hospitalisation.repasBonus], [54, 4, 1000, 2]);
  assert.equal((await r(db, 'SELECT hospitalisation_repas_prendre() r')).raison, 'repas_deja_pris');
  // Patient de la clinique : +5 Santé, +4 PA au prochain sommeil, 30 FR.
  await poser(db, { hp: 50, pa: 5, current_building: 'clinique-privee', hospitalisation: JSON.stringify({ regime: 'pa0', jour: 1, lieu: 'clinique' }) }, 'Ana');
  await en(db, U.ana);
  const c = await r(db, 'SELECT hospitalisation_repas_prendre() r');
  assert.deepEqual([c.ok, c.cout, c.bonus_lendemain, c.sante_gain, c.hp], [true, 30, 4, 5, 55]);
  f = await fiche(db, 'Ana');
  assert.deepEqual([f.hp, f.liquide, f.hospitalisation.repasBonus], [55, 970, 4]);
  // Client d'une nuitée (non hospitalisé) : +5 Santé, +4 PA différés, 30 FR. Moral 80 : gain ×1,5.
  await poser(db, { hp: 50, moral: 80, pa: 10, bonus_pa_differe: 0, hospitalisation: null, country: 'republic', current_city: 'capitale',
    current_building: 'clinique-privee', current_room: 'chambre_2' }, 'Tom Tom');
  await db.query("INSERT INTO clinique_nuitees (personnage, country, city, room_id, prix) VALUES ('Tom Tom', 'republic', 'capitale', 'chambre_2', 200)");
  await db.query(`INSERT INTO locations_actives (id, country, data) VALUES ('republic:clinique-privee:chambre_2:capitale', 'republic',
                  '{"locataire": "Tom Tom", "reservationClinique": "true", "roomId": "chambre_2"}')`);
  await en(db, U.tom);
  const n = await r(db, 'SELECT hospitalisation_repas_prendre() r');
  assert.deepEqual([n.ok, n.mode, n.cout, n.bonus_lendemain, n.sante_gain, n.hp], [true, 'nuitee', 30, 4, 8, 58]);
  f = await fiche(db);
  assert.deepEqual([f.bonus_pa_differe, f.pa, f.liquide], [4, 9, 970]);
});

test('point 3 : repas du Président, +5 Santé et +3 PA différés pour chacun, réglables', async () => {
  const db = await base();
  await db.query(`INSERT INTO cycles_electoraux VALUES ('soviet_president', '{"eluId": "Tom Tom"}')`);
  await poser(db, { moral: 80 }, 'Ana');
  const v = await r(db, "SELECT sovarka_repas_presidentiel('req-1', ARRAY['Ana']) r");
  assert.equal(v.ok, true, JSON.stringify(v));
  assert.deepEqual([v.hp, v.bonus_pa_differe, v.cout, v.moral], [55, 3, 60, 52]);
  const a = await fiche(db, 'Ana');
  assert.deepEqual([a.hp, a.bonus_pa_differe, a.moral], [58, 3, 82]); // Moral 80 au moment du repas : 5 × 1,5 → 8 (arrondi)
  const mail = await un(db, 'SELECT corps FROM mails_test');
  assert.match(mail.corps, /\(\+5 Santé selon votre Moral, \+2 Moral, \+5 INF, \+3 PA au prochain Dormir\)\./);
  // Réglable : Santé 7, PA 2 le lendemain.
  await db.query("UPDATE sante_parametres SET valeur = 7 WHERE cle = 'repas_president_sante'");
  await db.query("UPDATE sante_parametres SET valeur = 2 WHERE cle = 'repas_president_pa'");
  await db.query('DELETE FROM sovarka_repas_presidentiels');
  await poser(db, { hp: 50, bonus_pa_differe: 0 });
  const w = await r(db, "SELECT sovarka_repas_presidentiel('req-2', NULL) r");
  assert.deepEqual([w.hp, w.bonus_pa_differe], [57, 2]);
});

async function foret(db, hp, pa) {
  for (const n of ['Tom Tom', 'Ana']) await poser(db, { country: 'soviet', current_city: 'ville_b', current_building: 'zone-production', current_room: 'foret_vue_3', hp, pa }, n);
  await db.query("INSERT INTO groupes_pj_adhesions VALUES ('Ana', 'Tom Tom')");
  await db.query("INSERT INTO sovarka_foret_rencontres (bucheron, statut, pnj_id, creature, vue) VALUES ('Tom Tom', 'en_attente', 'ours-1', 'ours', 3)");
}
test('point 7 : se laisser faire face à une bête — robustesse et 1 Santé par PA perdu, pour chaque membre', async () => {
  let db = await base();
  await foret(db, 100, 20);
  let v = await r(db, "SELECT sovarka_foret_rencontre(gen_random_uuid(), 'subir') r");
  assert.equal(v.ok, true, JSON.stringify(v));
  assert.deepEqual(v.victimes, ['Ana', 'Tom Tom']);
  assert.equal(v.pa, 4); // Santé 100 : 20 × 0,8 = 16 PA perdus
  for (const n of ['Tom Tom', 'Ana']) assert.deepEqual([(await fiche(db, n)).pa, (await fiche(db, n)).hp], [4, 84], n);
  assert.deepEqual(v.pertes.find(p => p.nom === 'Ana'), { nom: 'Ana', pa: 4, pa_perdus: 16, sante_perdue: 16 });
  db = await base();
  await foret(db, 10, 20);
  v = await r(db, "SELECT sovarka_foret_rencontre(gen_random_uuid(), 'subir') r");
  assert.equal(v.pa, 0); // Santé 10 : facteur 1,24, borné aux 20 PA restants
  assert.deepEqual([(await fiche(db)).pa, (await fiche(db)).hp], [0, 0]);
});

test('point 7 : répression et rébellion — perte de Santé multipliée par la robustesse (plancher 1)', async () => {
  const db = await base();
  await poser(db, { country: 'republic', current_city: 'capitale', hp: 100, stats: JSON.stringify({ VOL: 12 }) });
  await poser(db, { country: 'republic', current_city: 'capitale', hp: 10 }, 'Ana');
  await db.query("INSERT INTO indices_villes VALUES ('republic_capitale', '{}')");
  const m = await r(db, "SELECT manifestation_reprimer('capitale', 'Grève') r");
  assert.equal(m.ok, true, JSON.stringify(m));
  assert.equal((await fiche(db)).hp, 92);          // 10 × 0,8
  assert.equal((await fiche(db, 'Ana')).hp, 1);     // 10 × 1,24 = 12, plancher 1
  // Rébellion réussie (jet 1) puis matée (jet 100), à Santé 100.
  await db.query("INSERT INTO detentions_test VALUES ('Tom Tom', 'republic', 'capitale')");
  await poser(db, { hp: 100, pa: 10 });
  await db.query(`SELECT set_config('rp.crim_jets', '{"rebellion": 1, "degats": 5}', false)`);
  const a = await r(db, 'SELECT detention_se_rebeller(1, 0) r');
  assert.deepEqual([a.ok, a.reussi, a.hp, a.sante_perdue], [true, true, 92, 8]);
  await poser(db, { hp: 100 });
  await db.query(`SELECT set_config('rp.crim_jets', '{"rebellion": 100}', false)`);
  const b = await r(db, 'SELECT detention_se_rebeller(1, 0) r');
  assert.deepEqual([b.ok, b.reussi, b.hp, b.sante_perdue], [true, false, 80, 20]); // 25 × 0,8
  await poser(db, { hp: 30 });
  const c = await r(db, 'SELECT detention_se_rebeller(1, 0) r');
  assert.equal(c.hp, 30 - Math.round(25 * (1.3 + (1.0 - 1.3) * 30 / 50)));
});

test('point 9 : don de tracts soumis au plafond du destinataire (refus destinataire_plein avec la place)', async () => {
  const db = await base();
  await poser(db, { inventory: JSON.stringify([{ name: 'Tracts', type: 'tract', cible: 'Parti X', quantite: 20 }]) });
  await poser(db, { inventory: JSON.stringify([{ name: 'Bois', qty: 95 }]), capacite_inventaire: 100 }, 'Ana');
  const refus = await r(db, "SELECT tracts_donner_joueur(gen_random_uuid(), 0, (SELECT inventory_revision FROM personnages_donnees WHERE name='Tom Tom'), 'Ana', 10) r");
  assert.deepEqual([refus.ok, refus.raison, refus.place, refus.demande, refus.destinataire], [false, 'destinataire_plein', 5, 10, 'Ana']);
  assert.equal((await un(db, "SELECT inventory->0->>'quantite' q FROM personnages_donnees WHERE name='Tom Tom'")).q, '20');
  const ok = await r(db, "SELECT tracts_donner_joueur(gen_random_uuid(), 0, (SELECT inventory_revision FROM personnages_donnees WHERE name='Tom Tom'), 'Ana', 5) r");
  assert.equal(ok.ok, true, JSON.stringify(ok));
  // Le sas compte : plus rien ne passe.
  const plein = await r(db, "SELECT tracts_donner_joueur(gen_random_uuid(), 0, (SELECT inventory_revision FROM personnages_donnees WHERE name='Tom Tom'), 'Ana', 1) r");
  assert.deepEqual([plein.raison, plein.place], ['destinataire_plein', 0]);
});

test('point 11 : rachat de tous les produits du marché de Krasnov = round(prix × 0,7), au moins 1 d\'écart ; chemise 17 ; réglage MJ', async () => {
  const db = await base();
  const lignes = Object.fromEntries((await db.query('SELECT cle, prix_vente, prix_rachat FROM marche_krasnov_produits')).rows.map(l => [l.cle, [l.prix_vente, l.prix_rachat]]));
  assert.deepEqual(lignes, {
    fruits_legumes: [2, 1], oeufs: [3, 2], viande: [3, 2], sucre: [2, 1], cereales: [2, 1], poisson: [2, 1], textile: [2, 1], bouteille_eau: [2, 1],
    graisse_ours: [16, 11], confiture: [10, 7], pain_noir: [8, 6], goulash: [13, 9], chemise: [17, 12], tenue_ninja: [32, 22], masque_carnaval: [20, 14] });
  assert.match((await un(db, "SELECT effet FROM marche_krasnov_produits WHERE cle='fruits_legumes'")).effet, /un zakouski/);
  assert.equal(await r(db, 'SELECT marches_prix_rachat_interne(1) r'), 0);
  // Le rachat ne se saisit pas hors règle.
  await db.query("UPDATE marche_krasnov_produits SET prix_vente = 40, prix_rachat = 39 WHERE cle = 'tenue_ninja'");
  assert.equal((await un(db, "SELECT prix_rachat FROM marche_krasnov_produits WHERE cle='tenue_ninja'")).prix_rachat, 28);
  // Réglage MJ journalisé : taux 0,5 → tous les rachats réalignés.
  await en(db, U.mj);
  assert.equal((await r(db, "SELECT admin_aliment_modifier('marches_rachat_taux', 1.5) r")).raison, 'valeur_invalide');
  assert.equal((await r(db, "SELECT admin_aliment_modifier('marches_rachat_taux', 0.5) r")).ok, true);
  assert.equal((await un(db, "SELECT prix_rachat FROM marche_krasnov_produits WHERE cle='graisse_ours'")).prix_rachat, 8);
  assert.equal((await un(db, "SELECT count(*)::int n FROM admin_journal WHERE action = 'aliment_modifier'")).n, 1);
  // Caisse et dotation du marché ; ancien paramètre « pour mémoire » retiré.
  assert.equal((await un(db, "SELECT valeur FROM aliments_parametres WHERE cle='marche_krasnov_dotation'")).valeur, '1000');
  assert.equal((await un(db, "SELECT (data->>'solde')::int s FROM caisses_batiments WHERE id='soviet_marche_ville_b'")).s, 1000);
  assert.equal((await db.query("SELECT 1 FROM aliments_parametres WHERE cle='marche_krasnov_decote_rachat_pct'")).rows.length, 0);
  // Kolkhoze de Starovka : confiture à 10 PSK, prix fixe.
  assert.equal((await un(db, "SELECT data#>>'{parametres,prixVente,kolkhoze_confiture_airelles}' p FROM entreprises WHERE id='tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka'")).p, '10');
  assert.equal((await un(db, "SELECT prix_fixe FROM recettes_commerce WHERE id='kolkhoze_confiture_airelles'")).prix_fixe, '10');
  assert.equal((await un(db, "SELECT parametres#>>'{prixVente,kolkhoze_confiture_airelles}' p FROM commerces_dotations")).p, '10');
});

test('point 13 : obj_informateur = 5 informations achetées à des informateurs différents (serveur)', async () => {
  const db = await base();
  await poser(db, { archetype: 'criminel', informateurs: JSON.stringify([{ id: 1 }, { id: 2 }, { id: 3 }]) });
  const elig = async () => (await r(db, "SELECT objectifs_secrets_eligibles_interne('Tom Tom') r"));
  assert.ok(!(await elig()).includes('obj_informateur'), 'l’ancienne règle (2 informateurs recrutés) ne compte plus');
  for (const i of ['barman', 'barman', 'portier', 'chauffeur', 'concierge']) await db.query("INSERT INTO informateurs_achats (acteur, informateur, montant) VALUES ('Tom Tom', $1, 50)", [i]);
  assert.ok(!(await elig()).includes('obj_informateur'), '4 informateurs différents seulement');
  await db.query("INSERT INTO informateurs_achats (acteur, informateur, montant) VALUES ('Ana', 'docker', 50), ('Tom Tom', 'docker', 50)");
  assert.ok((await elig()).includes('obj_informateur'));
  await poser(db, { archetype: 'ambitieux' });
  assert.ok(!(await elig()).includes('obj_informateur'));
});
