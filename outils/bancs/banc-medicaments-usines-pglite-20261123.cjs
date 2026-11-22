'use strict';
// Médicaments, usines d'État et antidote (Fred, 22/11/2026, soir : GAME-DESIGN-SANTE-20261122.md, « Suites », point 8 a à d,
// et point 5 — paiements en liquide), migration 20261123110000 sur l'état de production du 22/11 (socle santé 20261122230000
// et maladies 20261122233000), dans un vrai PostgreSQL local (PGlite).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261123110000_medicaments_usines_antidote.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', ana: '00000000-0000-0000-0000-000000000002',
  dir: '00000000-0000-0000-0000-000000000003', sol: '00000000-0000-0000-0000-000000000004' };
// md5 des définitions de PRODUCTION du 22/11/2026 (pg_get_functiondef) : la doublure doit être identique avant migration.
const MD5_PRODUCTION = {
  'centre_anti_poison_traiter()': 'a24e168eabc549d34c9bd29a712625f4',
  'medicament_prendre(uuid,text)': '74187c4f56db0c997614a547b465e800',
  'militaire_trousse_retirer()': '9e4f47c9832e70009f944d45a5e97a9d',
  'pharmacie_acheter_interne(text,text,integer)': 'd7d2a4b6a4a25945158b0bb9038cd641',
  'pharmacie_etat()': '4791dfd5dc74cf26270899fc827c1b12',
  'produire_medicament(text,text,text)': '782e8f4695a0a9b0db0477779c7b642e',
  'sante_reveil_interne(text)': 'ec1ae4cf45dd92f4f26d2c91991163af',
  'usine_medicaments_etat()': '5cdbdd296770d3563f112e7e4678680f',
  'usine_virer_vers_ministere(numeric)': '353532d386f18696f5453994938d3ced',
  'usine_medicaments_crediter_interne(text,numeric)': 'a44bdaa4784b7bc928e6958ca0387a29',
  'usine_medicaments_chaine_interne(text)': '00df534e6d18dfc2c14d05dbef0bb5af',
  'batiment_caisse_mouvement(text,text,text,text,numeric,text,numeric,numeric,boolean)': '4c57b38afb2e2964e925aeaef7c69d26',
  'caisse_institution_mouvement(text,numeric,boolean)': 'ea33a50b6fc2d797c5a2fd89e6b42473',
  'argent_debiter_interne(text,numeric,text)': '763a0161cf71172049a0c02c4a971504',
  'usine_du_directeur_pays_interne(text,text)': 'aa9990ba6d8f6f982fe1e875831f9bba'
};
const USINE_R = 'republic_capitale_usine-pharmaceutique-luthecia';

async function base({ migrer = true } = {}) {
  const db = new PGlite();
  for (const f of ['outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt', 'outils/bancs/fixtures/sante-maladies-pglite.sql.txt',
    'migrations/20261122230000_sante_socle.sql', 'migrations/20261122233000_sante_maladies_medicaments.sql',
    'outils/bancs/fixtures/medicaments-usines-pglite.sql.txt']) await db.exec(lire(f));
  await db.query('INSERT INTO personnages VALUES ($1,$2), ($3,$4), ($5,$6), ($7,$8)',
    ['Tom Tom', U.tom, 'Ana Ana', U.ana, 'Dir Dir', U.dir, 'Sol Sol', U.sol]);
  await db.query(`INSERT INTO personnages_donnees (name, user_id, hp, moral, liquide, arg, country, current_city, current_building, current_room, poste)
    VALUES ('Tom Tom', $1, 80, 50, 1000, 1000, 'republic', 'capitale', 'usine-pharmaceutique-luthecia', 'salle_ventes', NULL),
           ('Ana Ana', $2, 80, 50, 1000, 1000, 'soviet', 'capitale', 'pharmacie-officielle-novomirsk', 'comptoir_pharmacie', NULL),
           ('Dir Dir', $3, 80, 50, 0, 0, 'republic', 'capitale', 'usine-pharmaceutique-luthecia', 'bureau_direction', '{"id":"directeur_pharma"}'),
           ('Sol Sol', $4, 80, 50, 0, 0, 'republic', 'capitale', 'caserne-militaire', 'infirmerie', NULL)`, [U.tom, U.ana, U.dir, U.sol]);
  if (migrer) await db.exec(lire(MIGRATION));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const serveur = (db, on) => db.query("SELECT set_config('test.serveur', $1, false)", [on ? 'on' : '']);
const nuit = async db => { await serveur(db, true); const r = await un(db, 'SELECT usines_etat_nuit() r'); await serveur(db, false); return r; };
const nouvelleNuit = db => db.exec('DELETE FROM medicaments_pnj_passes; DELETE FROM antipoison_reapprovisionnements; DELETE FROM usines_reversements');
const usine = async (db, id = USINE_R) => (await un(db, 'SELECT batiment_etat_lire(data) r FROM batiments_etat WHERE id = $1', [id])).usine;
const fixerUsine = (db, id, patch) => db.query(
  "UPDATE batiments_etat SET data = to_jsonb((batiment_etat_lire(data) || jsonb_build_object('usine', (batiment_etat_lire(data)->'usine') || $2::jsonb))::text) WHERE id = $1",
  [id, JSON.stringify(patch)]);
const arrondi = x => Math.round(Number(x) * 100) / 100;
const stock = async (db, pays, med) => (await db.query('SELECT quantite, quantite_pnj FROM medicaments_stocks WHERE pays = $1 AND medicament = $2', [pays, med])).rows[0]
  || { quantite: 0, quantite_pnj: 0 };
const caisse = async (db, id) => arrondi(await un(db, "SELECT (data->>'solde')::numeric r FROM caisses_batiments WHERE id = $1", [id]));

test('la doublure est identique à la production ; la migration se rejoue sans toucher aux joueurs', async () => {
  const db = await base({ migrer: false });
  const r = (await db.query(`SELECT p.oid::regprocedure::text s, md5(pg_get_functiondef(p.oid)) m FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public'`)).rows;
  const vus = Object.fromEntries(r.map(x => [x.s, x.m]));
  for (const [s, m] of Object.entries(MD5_PRODUCTION)) assert.equal(vus[s], m, s + ' diffère de la production');
  const avant = (await db.query('SELECT name, hp, liquide, inventory FROM personnages_donnees ORDER BY name')).rows;
  await db.exec(lire(MIGRATION));
  await db.exec(lire(MIGRATION));
  assert.deepEqual((await db.query('SELECT name, hp, liquide, inventory FROM personnages_donnees ORDER BY name')).rows, avant);
  const cat = (await db.query('SELECT medicament FROM medicaments_catalogue_interne() ORDER BY 1')).rows.map(x => x.medicament);
  assert.deepEqual(cat, ['antibiotique', 'antidote', 'antigrippal', 'antinauseeux', 'aspirine', 'sels_rehydratation']);
});

test('8a : la trousse de premiers secours consomme des Médicaments (recette réglable)', async () => {
  const db = await base();
  await en(db, U.sol);
  const v = await un(db, 'SELECT militaire_trousse_retirer() r');
  assert.equal(v.ok, true);
  assert.deepEqual(v.restant, { textile: 2, medicaments: 0, desinfectant: 2 });
  assert.equal((await un(db, "SELECT inventory r FROM personnages_donnees WHERE name = 'Sol Sol'"))[0].produitMilitaire, 'trousse_secours');
  const sans = await un(db, 'SELECT militaire_trousse_retirer() r');
  assert.equal(sans.ok, false); assert.equal(sans.raison, 'ingredients_insuffisants', 'plus de Médicaments : plus de trousse');
  await db.query("UPDATE budgets_nationaux SET data = jsonb_set(data, '{caserneMatieres,medicaments}', '5')");
  await db.query("UPDATE sante_parametres SET valeur = 2 WHERE cle = 'trousse_medicaments'");
  assert.equal((await un(db, 'SELECT militaire_trousse_retirer() r')).restant.medicaments, 3);
});

test('8b : production des PNJ — sans matière aucune boîte, puis avec ; plafond ; une passe par nuit', async () => {
  const db = await base();
  await db.query("UPDATE sante_parametres SET valeur = 0 WHERE cle = 'antipoison_stock_cible'"); // aucun rachat par les centres ici
  await fixerUsine(db, USINE_R, { stockMatieres: { plantes: 0, alcool: 2 } });
  await nuit(db);
  for (const m of ['antinauseeux', 'aspirine', 'antigrippal', 'sels_rehydratation', 'antibiotique', 'antidote']) assert.equal((await stock(db, 'republic', m)).quantite_pnj, 0, m);
  assert.equal((await un(db, 'SELECT count(*)::int r FROM medicaments_pnj_passes')), 2);
  // Matière : 5 médicaments × 20 boîtes × 5/10 = 50 plantes ; antidote 10 boîtes × 15/10 = 15 plantes.
  await nouvelleNuit(db);
  await fixerUsine(db, USINE_R, { stockMatieres: { plantes: 100, alcool: 2 } });
  const r = await nuit(db);
  assert.equal(r.ok, true);
  for (const m of ['antinauseeux', 'aspirine', 'antigrippal', 'sels_rehydratation', 'antibiotique']) assert.equal((await stock(db, 'republic', m)).quantite_pnj, 20, m);
  assert.equal((await stock(db, 'republic', 'antidote')).quantite_pnj, 10);
  assert.equal((await usine(db)).stockMatieres.plantes, 35, '100 − 50 − 15');
  // Rejouée la même nuit : rien de plus.
  await nuit(db);
  assert.equal((await stock(db, 'republic', 'aspirine')).quantite_pnj, 20);
  // Plafond du stock PNJ (50) : 20 + 20 + 10.
  await fixerUsine(db, USINE_R, { stockMatieres: { plantes: 1000, alcool: 2 } });
  await nouvelleNuit(db); await nuit(db); await nouvelleNuit(db); await nuit(db);
  assert.equal((await stock(db, 'republic', 'aspirine')).quantite_pnj, 50);
  // Matière insuffisante : partage au prorata (même part des besoins pour chacun).
  await db.query("UPDATE medicaments_stocks SET quantite_pnj = 0 WHERE pays = 'republic'");
  await fixerUsine(db, USINE_R, { stockMatieres: { plantes: 11, alcool: 2 } });
  await nouvelleNuit(db); await nuit(db);
  const parts = await Promise.all(['antinauseeux', 'aspirine', 'antigrippal', 'sels_rehydratation'].map(m => stock(db, 'republic', m)));
  assert.ok(parts.every(s => s.quantite_pnj === parts[0].quantite_pnj && s.quantite_pnj > 0), JSON.stringify(parts));
  assert.ok((await usine(db)).stockMatieres.plantes >= 0);
});

test('8b et 8c : boîtes des joueurs vendues en premier, recette à l’usine, paiement en liquide seulement', async () => {
  const db = await base();
  await db.query("INSERT INTO medicaments_stocks (pays, medicament, quantite, quantite_pnj) VALUES ('republic', 'aspirine', 2, 5)");
  const caisseAvant = (await usine(db)).caisse;
  await en(db, U.tom);
  const v = await un(db, "SELECT pharmacie_acheter_interne('Tom Tom', 'aspirine', 3) r");
  assert.equal(v.ok, true); assert.equal(v.de_joueurs, 2); assert.equal(v.de_pnj, 1); assert.equal(v.prix, 44);
  assert.deepEqual(await stock(db, 'republic', 'aspirine'), { quantite: 0, quantite_pnj: 4 });
  assert.equal(Math.round(((await usine(db)).caisse - caisseAvant) * 100) / 100, 132, 'tout à la caisse de l’usine (comptoir de Luthécia : plus rien de perdu)');
  assert.equal(Number(await un(db, "SELECT liquide r FROM personnages_donnees WHERE name = 'Tom Tom'")), 868);
  // Liquide insuffisant : refus, même avec de l'argent en banque.
  await db.query("UPDATE personnages_donnees SET liquide = 10 WHERE name = 'Tom Tom'");
  await db.query("INSERT INTO comptes_bancaires (personnage, banque, solde) VALUES ('Tom Tom', 'nationale', 5000)");
  const refus = await un(db, "SELECT pharmacie_acheter_interne('Tom Tom', 'aspirine', 1) r");
  assert.equal(refus.ok, false); assert.equal(refus.raison, 'fonds_insuffisants');
  assert.equal(Number(await un(db, "SELECT solde r FROM comptes_bancaires WHERE personnage = 'Tom Tom'")), 5000);
  // Sovarka : la recette va à l'usine (plus à l'entreprise du point de vente).
  await db.query("INSERT INTO medicaments_stocks (pays, medicament, quantite, quantite_pnj) VALUES ('soviet', 'aspirine', 0, 3)");
  const sov = (await usine(db, 'soviet_capitale_usine-pharmaceutique-luthecia')).caisse;
  await en(db, U.ana);
  assert.equal((await un(db, "SELECT pharmacie_acheter_interne('Ana Ana', 'aspirine', 1) r")).ok, true);
  assert.equal((await usine(db, 'soviet_capitale_usine-pharmaceutique-luthecia')).caisse - sov, 44);
  assert.equal(Number(await un(db, "SELECT (data->>'caisse')::numeric r FROM entreprises WHERE id = 'pharmacie-soviet-capitale'")), 0);
  // Fenêtre du comptoir : restant = joueurs + PNJ, antidote listé, nettement plus cher.
  await en(db, U.tom);
  await db.query("UPDATE personnages_donnees SET liquide = 1000 WHERE name = 'Tom Tom'");
  const etat = await un(db, 'SELECT pharmacie_etat() r');
  const asp = etat.medicaments.find(m => m.medicament === 'aspirine'), ant = etat.medicaments.find(m => m.medicament === 'antidote');
  assert.equal(asp.restant, 4); assert.equal(ant.prix, 132); assert.equal(etat.medicaments.at(-1).medicament, 'antidote');
});

test('8c : fonds de roulement — l’excédent au-delà de 5 000 est reversé chaque nuit à la tutelle ; virement du directeur', async () => {
  const db = await base();
  await fixerUsine(db, USINE_R, { caisse: 7350.5, stockMatieres: { plantes: 0 } });
  const minfin = await caisse(db, 'republic_gouvernement-min_fin');
  const r = await nuit(db);
  const det = r.reversements.detail.find(d => d.usine === USINE_R);
  assert.equal(Number(det.verse), 2350.5); assert.equal(det.tutelle, 'republic_gouvernement-min_fin');
  assert.equal((await usine(db)).caisse, 5000);
  // Le pôle tabac (7 200) aussi ; la raffinerie (2 655,12) garde tout.
  assert.equal((await usine(db, 'republic_ville_a_pole-tabac-alcools-psm')).caisse, 5000);
  assert.equal((await usine(db, 'republic_ville_b_raffinerie-montrouge')).caisse, 2655.12);
  assert.equal(await caisse(db, 'republic_gouvernement-min_fin'), arrondi(minfin + 2350.5 + 2200));
  // Rejouée la même nuit : rien.
  await fixerUsine(db, USINE_R, { caisse: 6000 });
  await nuit(db);
  assert.equal((await usine(db)).caisse, 6000, 'un seul reversement automatique par jour');
  // Le MJ règle le fonds de roulement.
  await db.query("UPDATE sante_parametres SET valeur = 1000 WHERE cle = 'usine_fonds_roulement'");
  await nouvelleNuit(db); await nuit(db);
  assert.equal((await usine(db)).caisse, 1000);
  // Virement volontaire : réservé au directeur, sur place, borné par la caisse.
  await en(db, U.tom);
  assert.equal((await un(db, 'SELECT usine_virer_vers_ministere(100) r')).raison, 'reserve_directeur');
  await en(db, U.dir);
  const etat = await un(db, 'SELECT usine_tutelle_etat() r');
  assert.equal(etat.ok, true); assert.equal(Number(etat.fonds_roulement), 1000); assert.equal(etat.tutelle, 'min_fin');
  assert.equal((await un(db, 'SELECT usine_virer_vers_ministere(5000) r')).raison, 'caisse_insuffisante');
  assert.equal(await un(db, "SELECT pa r FROM personnages_donnees WHERE name = 'Dir Dir'"), 30, 'refus : PA rendu');
  const avant = await caisse(db, 'republic_gouvernement-min_fin');
  const v = await un(db, 'SELECT usine_virer_vers_ministere(400) r');
  assert.equal(v.ok, true); assert.equal(v.tutelle, 'republic_gouvernement-min_fin');
  assert.equal((await usine(db)).caisse, 600);
  assert.equal(await caisse(db, 'republic_gouvernement-min_fin'), arrondi(avant + 400));
  assert.equal(await un(db, "SELECT count(*)::int r FROM usines_reversements WHERE mode = 'volontaire' AND acteur = 'Dir Dir'"), 1);
  await serveur(db, false); await en(db, U.tom);
  assert.equal((await un(db, 'SELECT usines_etat_nuit() r')).raison, 'reserve_au_serveur');
});

test('8d : antidote produit, acheté, pris ; poison annulé au réveil, MST toujours révélée', async () => {
  const db = await base();
  await db.query("UPDATE sante_parametres SET valeur = 1 WHERE cle = 'mst_risque_par_partenaire'");
  // Produit par un joueur : 15 plantes pour 10 antidotes.
  await db.query("UPDATE personnages_donnees SET current_room = 'salle_production' WHERE name = 'Tom Tom'");
  await fixerUsine(db, USINE_R, { stockMatieres: { plantes: 20, alcool: 2 } });
  await en(db, U.tom);
  const etatUsine = await un(db, 'SELECT usine_medicaments_etat() r');
  assert.equal(etatUsine.medicaments.find(m => m.medicament === 'antidote').matiere_par_pa, 15);
  const p = await un(db, "SELECT produire_medicament('Tom Tom', 'republic', 'antidote') r");
  assert.equal(p.ok, true); assert.equal(p.produits, 10); assert.equal(p.matiere_consommee, 15);
  assert.equal((await usine(db)).stockMatieres.plantes, 5);
  assert.equal((await un(db, "SELECT produire_medicament('Tom Tom', 'republic', 'antidote') r")).raison, 'matiere_insuffisante');
  // Acheté au comptoir (132 FR).
  await db.query("UPDATE personnages_donnees SET current_room = 'salle_ventes', poison_actif = '{\"actif\": true, \"palier\": \"partielle\"}' WHERE name = 'Tom Tom'");
  const a = await un(db, "SELECT pharmacie_acheter_interne('Tom Tom', 'antidote', 1) r");
  assert.equal(a.ok, true); assert.equal(a.paye, 132);
  assert.equal(a.inventory.find(i => i.stackKey === 'medicament_antidote').name, 'Antidote');
  // MST en attente (révélation au même réveil).
  await db.query("INSERT INTO mst_en_attente (nom, partenaires, risque) VALUES ('Tom Tom', 3, 1)");
  // Pris : rien ne change avant le réveil.
  const pr = await un(db, "SELECT medicament_prendre(gen_random_uuid(), 'antidote') r");
  assert.equal(pr.ok, true);
  assert.equal((await un(db, "SELECT medicament_prendre(gen_random_uuid(), 'antidote') r")).raison, 'antidote_deja_pris');
  assert.equal((await un(db, "SELECT poison_actif r FROM personnages_donnees WHERE name = 'Tom Tom'")).actif, true);
  const rev = await un(db, "SELECT sante_reveil_interne('Tom Tom') r");
  assert.deepEqual(rev.map(e => e.cle), ['antidote_poison_neutralise', 'mst_revelee']);
  assert.equal(rev[1].texte, "Ces 10 derniers jours, vous avez eu des relations avec 3 partenaires. L'un d'eux ou l'une d'elles vous a transmis une MST. −10 points de Santé.");
  assert.equal(await un(db, "SELECT poison_actif r FROM personnages_donnees WHERE name = 'Tom Tom'"), null);
  assert.equal(await un(db, "SELECT hp r FROM personnages_donnees WHERE name = 'Tom Tom'"), 70, 'seule la MST retire de la Santé');
  // Sans empoisonnement, l'antidote ne se prend pas.
  await db.query("UPDATE personnages_donnees SET inventory = inventory || '[{\"stackKey\":\"medicament_antidote\",\"qty\":1,\"name\":\"Antidote\"}]' WHERE name = 'Tom Tom'");
  assert.equal((await un(db, "SELECT medicament_prendre(gen_random_uuid(), 'antidote') r")).raison, 'pas_empoisonne');
});

test('8d : centre antipoison sans stock refuse, soigne après le rachat nocturne ; prix en liquide à la caisse de la structure', async () => {
  const db = await base();
  await db.query("UPDATE personnages_donnees SET current_building = 'clinique-privee', current_room = 'chambre_1', poison_actif = '{\"actif\": true}' WHERE name = 'Tom Tom'");
  await fixerUsine(db, USINE_R, { stockMatieres: { plantes: 0 } });
  await en(db, U.tom);
  const refus = await un(db, 'SELECT centre_anti_poison_traiter() r');
  assert.equal(refus.ok, false); assert.equal(refus.raison, 'plus_d_antidote');
  assert.equal(refus.message, 'Plus d’antidote, réapprovisionnement en attente.'.replace('’', "'"));
  assert.equal(Number(await un(db, "SELECT liquide r FROM personnages_donnees WHERE name = 'Tom Tom'")), 1000, 'rien de prélevé');
  // Nuit sans antidote au stock national : rien.
  let r = await nuit(db);
  assert.equal(r.antipoison.centres.find(c => c.centre === 'republic_capitale_clinique-privee').raison, 'rupture');
  // Des antidotes de joueurs au stock national : la clinique (caisse 178) en rachète un (132), le dispensaire (3 410) cinq.
  await db.query("INSERT INTO medicaments_stocks (pays, medicament, quantite, quantite_pnj) VALUES ('republic', 'antidote', 8, 0) ON CONFLICT (pays, medicament) DO UPDATE SET quantite = 8");
  const caisseUsine = (await usine(db)).caisse;
  await nouvelleNuit(db);
  r = await nuit(db);
  const cli = r.antipoison.centres.find(c => c.centre === 'republic_capitale_clinique-privee');
  const dis = r.antipoison.centres.find(c => c.centre === 'republic_capitale_dispensaire-public');
  assert.equal(cli.achetes, 1); assert.equal(dis.achetes, 5);
  assert.equal(await caisse(db, 'republic_dispensaire_capitale'), 3410 - 5 * 132);
  assert.equal(Math.round(((await usine(db)).caisse - caisseUsine) * 100) / 100, 6 * 132);
  assert.equal((await stock(db, 'republic', 'antidote')).quantite, 2);
  // Liquide insuffisant : refus avant tout prélèvement.
  await db.query("UPDATE personnages_donnees SET liquide = 100 WHERE name = 'Tom Tom'");
  await db.query("INSERT INTO comptes_bancaires (personnage, banque, solde) VALUES ('Tom Tom', 'nationale', 5000)");
  assert.equal((await un(db, 'SELECT centre_anti_poison_traiter() r')).raison, 'fonds_insuffisants');
  // Soin : 1 antidote consommé, 150 versés à la caisse de la clinique.
  await db.query("UPDATE personnages_donnees SET liquide = 1000 WHERE name = 'Tom Tom'");
  const v = await un(db, 'SELECT centre_anti_poison_traiter() r');
  assert.equal(v.ok, true); assert.equal(v.antidotes_restants, 0);
  assert.equal(Number(v.liquide), 850);
  const sante = (await un(db, "SELECT batiment_etat_lire(data) r FROM batiments_etat WHERE id = 'republic_capitale_clinique-privee'")).sante;
  assert.equal(sante.antidotes, 0); assert.equal(Number(sante.caisse), 178 - 132 + 150);
  if (!v.gueri) assert.equal((await un(db, 'SELECT centre_anti_poison_traiter() r')).raison, 'plus_d_antidote');
});
