'use strict';
// Mission du soir du 25/11/2026, bloc 4.5 : remise à zéro du 19/12 (préparée, jamais exécutée). Banc du script généré.
// Garde-fous (phrase, date, tables à vérifier, tables inconnues non vides), relevé des comptes de
// la bêta (comptes de test exclus), effacement de l'état vivant seulement, offre des testeurs, achats premium gardés.
// Mission de fin de soirée du 25/11/2026 (1.1) : tous les personnages disparaissent ; blocus et climat vidés ; remise à
// l'état initial des tables mixtes, table par table (bloc « RÉINITIALISATIONS »), éprouvée sur des tables réduites.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-remise-a-zero-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const SCRIPT = 'historique/preparations-lancement/remise-a-zero-20261219.sql';

test('script généré à jour, transaction unique, jamais de CASCADE, aucune table premium payée effacée', () => {
  execFileSync('python3', [path.join(root, 'outils/lancement/generer-remise-a-zero.py'), '--verifier'], { encoding: 'utf8' });
  const s = lire(SCRIPT);
  assert.match(s, /^BEGIN;$/m); assert.match(s, /^COMMIT;$/m);
  assert.doesNotMatch(s.replace(/^--.*$/gm, ''), /CASCADE/i);
  const vider = /\) AS garder, (ARRAY\[[^\]]*\])::text\[\] AS vider/.exec(s) || /(ARRAY\[[^\]]*\])::text\[\] AS vider/.exec(s);
  for (const t of ['premium_achats', 'premium_abonnements', 'premium_droits', 'administrateurs', 'comptes_test', 'ordres_couts'])
    assert.doesNotMatch(vider[1], new RegExp("'" + t + "'"), t + ' ne doit jamais être vidée');
  for (const t of ['personnages', 'personnages_donnees', 'crim_affaires', 'publicites_joueurs']) assert.match(vider[1], new RegExp("'" + t + "'"));
  assert.ok(fs.existsSync(path.join(root, 'docs/premium/REMISE-A-ZERO-20261219.md')), 'procédure documentée');
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF; END $$;
CREATE TABLE personnages (name text PRIMARY KEY, user_id uuid);
CREATE TABLE personnages_donnees (name text PRIMARY KEY);
CREATE TABLE journaux (id text PRIMARY KEY, cree_par text REFERENCES personnages_donnees(name) ON DELETE SET NULL);
CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, auteur text);
CREATE TABLE comptes_test (personnage text PRIMARY KEY);
CREATE TABLE administrateurs (user_id uuid PRIMARY KEY);
CREATE TABLE ordres_couts (fn text PRIMARY KEY);
CREATE TABLE premium_produits (produit text PRIMARY KEY);
CREATE TABLE premium_achats (id uuid PRIMARY KEY);
CREATE TABLE premium_droits (id bigserial PRIMARY KEY, user_id uuid, produit text REFERENCES premium_produits, cible text, source text, note text);
INSERT INTO premium_produits VALUES ('personnalisation_local'), ('campagne_publicite_courte');
INSERT INTO personnages VALUES ('Olga', '00000000-0000-0000-0000-000000000001'), ('Olga2', '00000000-0000-0000-0000-000000000001'),
  ('Ivan', '00000000-0000-0000-0000-000000000002'), ('Arnie', '00000000-0000-0000-0000-000000000003'), ('PNJ', NULL);
INSERT INTO personnages_donnees VALUES ('Olga'), ('Ivan');
INSERT INTO journaux VALUES ('tribune', 'Olga');
INSERT INTO crim_affaires (auteur) VALUES ('Olga');
INSERT INTO comptes_test VALUES ('Arnie');
INSERT INTO administrateurs VALUES ('00000000-0000-0000-0000-0000000000aa');
INSERT INTO ordres_couts VALUES ('voler');
INSERT INTO premium_achats VALUES ('00000000-0000-0000-0000-00000000beef');
`;
// Le corps sans le bloc de date (banc joué avant le 19/12), listes « à vérifier » et « réinitialiser » vidées pour l'essai.
function corpsEssai(s, { garderDate = false } = {}) {
  let c = s;
  if (!garderDate) c = c.replace(/DO \$garde\$[\s\S]*?END \$garde\$;/, '');
  return c.replace(/ARRAY\[[^\]]*\]::text\[\] AS a_verifier/, "'{}'::text[] AS a_verifier")
          .replace(/ARRAY\[[^\]]*\]::text\[\] AS reinitialiser/, "'{}'::text[] AS reinitialiser")
          .replace(/-- DÉBUT DES RÉINITIALISATIONS[\s\S]*?-- FIN DES RÉINITIALISATIONS/, '');
}

test('garde-fous : sans la phrase, refus ; avec la phrase, refus avant le 19/12 ; rien n’est effacé', async () => {
  const db = new PGlite(); await db.exec(SOCLE);
  await assert.rejects(db.exec(lire(SCRIPT)), /phrase de confirmation absente/);
  await db.exec('ROLLBACK').catch(() => {});
  if (new Date() < new Date('2026-12-18T23:00:00Z')) {
    await db.exec(`SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026'`);
    await assert.rejects(db.exec(lire(SCRIPT)), /pas avant le 19\/12\/2026/);
    await db.exec('ROLLBACK').catch(() => {});
  }
  assert.equal((await db.query('SELECT count(*)::int n FROM personnages')).rows[0].n, 5);
});

test('garde-fous : aucune table « à vérifier » (décision de Fred), table inconnue non vide refusée, tout ou rien', async () => {
  const s = lire(SCRIPT);
  assert.match(s, /'{}'::text\[\] AS a_verifier|ARRAY\[\]::text\[\] AS a_verifier/, 'plus aucune table « à vérifier »');
  for (const t of ['blocus_ordres_batiments', 'climat_evenements']) assert.match(/(ARRAY\[[^\]]*\])::text\[\] AS vider/.exec(s)[1], new RegExp("'" + t + "'"), t + ' vidée au lancement');
  const db = new PGlite(); await db.exec(SOCLE);
  await db.exec(`CREATE TABLE table_surprise (x int); INSERT INTO table_surprise VALUES (1);`);
  await assert.rejects(db.exec(corpsEssai(s)), /non classées et non vides : table_surprise/);
  await db.exec('ROLLBACK').catch(() => {});
  assert.equal((await db.query('SELECT count(*)::int n FROM crim_affaires')).rows[0].n, 1, 'tout ou rien');
});

test('exécution : état vivant effacé, référentiels, MJ et achats gardés ; offre aux comptes de la bêta, pas aux comptes de test', async () => {
  const db = new PGlite(); await db.exec(SOCLE);
  await db.exec(corpsEssai(lire(SCRIPT)));
  const n = async t => (await db.query(`SELECT count(*)::int n FROM ${t}`)).rows[0].n;
  assert.equal(await n('personnages'), 0); assert.equal(await n('personnages_donnees'), 0); assert.equal(await n('crim_affaires'), 0);
  assert.equal(await n('administrateurs'), 1); assert.equal(await n('ordres_couts'), 1); assert.equal(await n('premium_achats'), 1);
  assert.equal(await n('comptes_test'), 1);
  // Table gardée qui pointe vers une table vidée : vidée par DELETE, la clé met la référence à NULL.
  assert.deepEqual((await db.query('SELECT id, cree_par FROM journaux')).rows, [{ id: 'tribune', cree_par: null }]);
  const b = (await db.query('SELECT user_id::text u, personnages FROM lancement_comptes_beta ORDER BY 1')).rows;
  assert.deepEqual(b.map(x => x.u), ['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002']);
  assert.deepEqual(b[0].personnages, ['Olga', 'Olga2']);
  const o = (await db.query(`SELECT user_id::text u, produit, source FROM premium_droits ORDER BY 1, 2`)).rows;
  assert.equal(o.length, 6);
  assert.ok(o.every(x => x.source === 'offre_lancement'));
  assert.deepEqual(o.filter(x => x.u.endsWith('1')).map(x => x.produit), ['campagne_publicite_courte', 'campagne_publicite_courte', 'personnalisation_local']);
  // Rejouée par erreur : aucune seconde offre.
  await db.exec(`INSERT INTO personnages VALUES ('Nouveau', '00000000-0000-0000-0000-000000000009')`);
  await db.exec(corpsEssai(lire(SCRIPT)));
  assert.equal((await db.query(`SELECT count(*)::int n FROM premium_droits WHERE user_id = '00000000-0000-0000-0000-000000000001'`)).rows[0].n, 3);
});

// Tables mixtes réduites aux colonnes que le bloc de réinitialisation lit ou écrit (types de la production du 25/11).
const MIXTES = `
CREATE TABLE drogues_stocks_dealers (dealer text, produit text, stock int, jour int);
CREATE TABLE niveaux_prison (id text PRIMARY KEY, data jsonb);
CREATE TABLE kolkhoze_caisse (pays text, ville text, cle text, qte int, objet jsonb);
CREATE TABLE enigme_tresor_tsars (acteur text, etape text);
CREATE TABLE murs_titres (id text PRIMARY KEY, proprietaire text, offre jsonb, updated_at timestamptz);
CREATE TABLE murs_loyers (titre_id text PRIMARY KEY REFERENCES murs_titres(id));
CREATE TABLE medicaments_stocks (pays text, medicament text, quantite int DEFAULT 0);
CREATE TABLE ports_stock (pays text, cle text, qte int);
CREATE TABLE pnj_membres (id text PRIMARY KEY, proprietaire_pj text, leader_pj text, proprietaire_institution text);
CREATE TABLE pnj_possessions (id bigserial PRIMARY KEY, pnj_id text REFERENCES pnj_membres(id) ON DELETE CASCADE);
CREATE TABLE pnj_soldats_metier (pnj_id text PRIMARY KEY REFERENCES pnj_membres(id) ON DELETE CASCADE);
CREATE TABLE postes_attribues (id text PRIMARY KEY, titulaire text);
CREATE TABLE organisations (id text PRIMARY KEY, data text);
CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb);
CREATE TABLE sovarka_locaux (piece text PRIMARY KEY, entreprise_id text, demande_id text);
CREATE TABLE terrains_etat (id text PRIMARY KEY, proprietaire text, coproprietaire text, niveau_construction text, valeur_totale int, data text, updated_at timestamptz);
CREATE TABLE assemblee_sieges (id text PRIMARY KEY, pnj_nom text, endormi boolean, endormi_ts timestamptz, endormi_par text, updated_at timestamptz);
CREATE TABLE budgets_clubs (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE budgets_municipaux (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE marche_krasnov_stock (cle text PRIMARY KEY, qte int);
CREATE TABLE caisses_batiments (id text PRIMARY KEY, data jsonb, updated_at timestamptz DEFAULT now());
CREATE TABLE batiments_etat (id text PRIMARY KEY, country text, city text, building_id text, data jsonb, updated_at timestamptz DEFAULT now());
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF; END $$;
CREATE TABLE budgets_nationaux (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE ports_commerce (pays text PRIMARY KEY, nom text NOT NULL, caisse_id text NOT NULL, entrepots text[] NOT NULL DEFAULT '{}',
  taux_douane numeric NOT NULL DEFAULT 10, repartition jsonb NOT NULL DEFAULT '{}'::jsonb, prix_cession jsonb NOT NULL DEFAULT '{}'::jsonb,
  prix_export jsonb NOT NULL DEFAULT '{}'::jsonb, quotas_import jsonb NOT NULL DEFAULT '{}'::jsonb, quotas_export jsonb NOT NULL DEFAULT '{}'::jsonb,
  dotation_jour numeric NOT NULL DEFAULT 0, pnj_couvre_deficit boolean NOT NULL DEFAULT false, modifie_par text, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE admin_journal (admin_user_id uuid, admin_libelle text, action text, parametres jsonb, resultat jsonb, ok boolean);
CREATE OR REPLACE FUNCTION admin_exiger() RETURNS void LANGUAGE sql AS $f$ SELECT $f$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT NULL::uuid $f$;
INSERT INTO drogues_stocks_dealers VALUES ('Brume', 'estadine', 2, 9);
INSERT INTO niveaux_prison VALUES ('republic_capitale', '{"niveau": 40}');
INSERT INTO kolkhoze_caisse VALUES ('soviet', 'ville_b', 'oeufs', 12, '{}');
INSERT INTO enigme_tresor_tsars VALUES ('Olga', 'carte');
INSERT INTO murs_titres VALUES ('cafe-1', 'Olga', '{"prix": 9000}', now()), ('cafe-2', 'commune', NULL, now());
INSERT INTO murs_loyers VALUES ('cafe-1');
INSERT INTO medicaments_stocks VALUES ('republic', 'antidote', 7);
INSERT INTO ports_stock VALUES ('republic', 'bois', 300);
INSERT INTO pnj_membres VALUES ('soldat-1', NULL, 'Vince', 'militaire'), ('militant-1', 'Arnie', NULL, NULL), ('garde-1', NULL, NULL, 'garde');
INSERT INTO pnj_possessions (pnj_id) VALUES ('soldat-1'), ('garde-1');
INSERT INTO pnj_soldats_metier VALUES ('soldat-1'), ('garde-1');
INSERT INTO postes_attribues VALUES ('republic_maire_capitale', 'Olga');
INSERT INTO organisations VALUES ('orga_1', '{"nom": "La Main Noire", "fondateur": "Olga", "membres": ["Olga"]}'),
  ('orga_dockers', '{"nom": "Dockers", "chefEstPnj": true, "membres": ["Ivan"], "demandesAdhesion": ["Olga"], "caisse": 900}');
INSERT INTO entreprises VALUES ('bar-olga', '{"proprietaire": "pj:Olga"}'),
  ('salon-pnj', '{"proprietaire": "PNJ Salon", "country": "republic", "type": "salon-coiffure", "caisse": 9, "stockMatieres": {"textile": 0}, "stockProduits": {"coupe": 1}, "historique": [1]}'),
  ('garage-pnj', '{"proprietaire": "PNJ Garage", "country": "soviet", "type": "garage", "caisse": 20000, "stockMatieres": {"metal": 0, "textile": 3}, "stockProduits": {"voiture": 3}}');
INSERT INTO budgets_nationaux VALUES ('soviet', '{"refectoire": {"rations": 4}, "reserveJour": 900, "tauxNational": 25, "tauxMunicipal": 30, "tauxMainOeuvre": 12,
  "lotsMilitaires": {"radio": [{"lot": "dotation-initiale", "qte": 2}, {"lot": "achat-beta", "qte": 5}], "tente": [{"lot": "achat-beta", "qte": 1}]},
  "caserneMatieres": {"viande": 7}, "stockArmurerieMilitaire": {"radio": 7, "tente": 1}, "derniereDistribJourReel": "2026-11-20", "couvreFeu": {"actif": true}}', now());
INSERT INTO ports_commerce VALUES ('republic', 'Port de Port-Sainte-Marie', 'republic_port-sainte-marie', '{entrepot}', 22, '{"a": 1}', '{"bois": 4}', '{}', '{}', '{}', 500, true, 'Olga', now());
INSERT INTO sovarka_locaux VALUES ('bureau_1', 'bar-olga', 'dem-1'), ('salon', 'salon-pnj', NULL);
INSERT INTO terrains_etat VALUES ('t1', 'Olga', 'Ivan', 'fondations', 33000,
  '{"city": "capitale", "surface": 2150, "valeur_totale": 25800, "constructionAutorisee": true, "pnj": null, "permis": {"statut": "valide"}, "chantier": {"x": 1}, "occupationInitialisee": true}', now());
INSERT INTO assemblee_sieges VALUES ('s1', 'Gamma 1', true, now(), 'Olga', now());
INSERT INTO budgets_clubs VALUES ('club_1', '{"caisse": 4200, "salaires": {"joueur": 50}, "historique": [1], "derniereSubventionJour": 9}', now());
INSERT INTO budgets_municipaux VALUES ('republic_capitale', '{"key": "republic_capitale", "tauxFoncier": 0.2, "derniereMaj": 3, "indices": {"a": 1}}', now());
INSERT INTO marche_krasnov_stock VALUES ('oeufs', 0), ('caviar', 4);
INSERT INTO caisses_batiments VALUES ('republic_assemblee', '{"solde": 123456, "historique": [1]}', now()), ('soviet_mairie-capitale', '{"solde": 77}', now()),
  ('republic_commissariat_ville_a', '{"solde": 113636}', now()), ('soviet_inconnue_ville_b', '{"solde": 5}', now()), ('narco_mairie-capitale', '{"solde": 7992}', now());
INSERT INTO batiments_etat VALUES ('republic_ville_a_entrepot-logistique-psm', 'republic', 'ville_a', 'entrepot-logistique-psm', '{"entrepot": {"stock": {"bois": 1}}}', now()),
  ('republic_capitale_banque', 'republic', 'capitale', 'banque', '{"x": 1}', now());
`;

test('réinitialisations : chaque table mixte revient à son état initial (1.1, fin de soirée du 25/11)', async () => {
  const s = lire(SCRIPT);
  const bloc = /-- DÉBUT DES RÉINITIALISATIONS([\s\S]*?)-- FIN DES RÉINITIALISATIONS/.exec(s)[1];
  const reinit = /(ARRAY\[[^\]]*\])::text\[\] AS reinitialiser/.exec(s)[1].match(/'[a-z0-9_]+'/g).map(x => x.slice(1, -1));
  for (const t of reinit) assert.match(bloc, new RegExp('-- ▸ ' + t + ' :'), t + ' : une entrée par table à réinitialiser');
  const db = new PGlite(); await db.exec(MIXTES); await db.exec(lire('migrations/20261126200000_dotations_lancement.sql'));
  await db.exec('BEGIN'); await db.exec(bloc); await db.exec('COMMIT');
  const n = async t => (await db.query(`SELECT count(*)::int n FROM ${t}`)).rows[0].n;
  for (const t of ['drogues_stocks_dealers', 'niveaux_prison', 'kolkhoze_caisse', 'enigme_tresor_tsars', 'murs_loyers',
                   'medicaments_stocks', 'ports_stock', 'postes_attribues']) assert.equal(await n(t), 0, t + ' vidée');
  assert.deepEqual((await db.query('SELECT id FROM pnj_membres ORDER BY id')).rows.map(r => r.id), ['garde-1'], 'PNJ des joueurs retirés');
  assert.deepEqual((await db.query('SELECT pnj_id FROM pnj_soldats_metier')).rows.map(r => r.pnj_id), ['garde-1'], 'métier suit par cascade');
  assert.equal(await n('pnj_possessions'), 0, 'aucune possession reprise');
  const o = (await db.query('SELECT id, data FROM organisations')).rows;
  assert.deepEqual(o.map(r => r.id), ['orga_dockers'], 'organisations des joueurs retirées');
  const d = JSON.parse(o[0].data);
  assert.deepEqual([d.membres, d.demandesAdhesion, d.caisse, d.nom], [[], [], 0, 'Dockers']);
  const ent = Object.fromEntries((await db.query('SELECT id, data FROM entreprises')).rows.map(r => [r.id, r.data]));
  assert.deepEqual(Object.keys(ent).sort(), ['garage-pnj', 'salon-pnj'], 'commerces des joueurs retirés');
  // Décision n° 5 (26/11) : tous les commerces restants repartent de la dotation du MJ (type, sinon « * » du pays).
  assert.equal(ent['salon-pnj'].caisse, 2000); assert.deepEqual(ent['salon-pnj'].stockMatieres, { textile: 10 });
  assert.deepEqual(ent['salon-pnj'].stockProduits, { coupe: 6 }); assert.deepEqual(ent['salon-pnj'].historique, []);
  assert.equal(ent['garage-pnj'].caisse, 600); assert.deepEqual(ent['garage-pnj'].stockMatieres, { metal: 10, textile: 10 });
  assert.deepEqual((await db.query('SELECT piece, entreprise_id, demande_id FROM sovarka_locaux ORDER BY piece')).rows,
    [{ piece: 'bureau_1', entreprise_id: null, demande_id: null }, { piece: 'salon', entreprise_id: 'salon-pnj', demande_id: null }]);
  assert.deepEqual((await db.query("SELECT proprietaire, offre FROM murs_titres ORDER BY id")).rows,
    [{ proprietaire: 'commune', offre: null }, { proprietaire: 'commune', offre: null }]);
  const t = (await db.query('SELECT proprietaire, coproprietaire, niveau_construction, valeur_totale, data FROM terrains_etat')).rows[0];
  assert.deepEqual([t.proprietaire, t.coproprietaire, t.niveau_construction, t.valeur_totale], [null, null, null, null]);
  assert.deepEqual(JSON.parse(t.data), { city: 'capitale', surface: 2150, valeur_totale: 25800, constructionAutorisee: true, pnj: null });
  assert.deepEqual((await db.query('SELECT pnj_nom, endormi, endormi_par FROM assemblee_sieges')).rows, [{ pnj_nom: 'Gamma 1', endormi: false, endormi_par: null }]);
  assert.deepEqual((await db.query('SELECT data FROM budgets_clubs')).rows[0].data, { caisse: 0, salaires: { joueur: 50 }, historique: [] });
  assert.deepEqual((await db.query('SELECT data FROM budgets_municipaux')).rows[0].data, { key: 'republic_capitale', tauxFoncier: 0.05, indices: { a: 1 } });
  const m = Object.fromEntries((await db.query('SELECT cle, qte FROM marche_krasnov_stock')).rows.map(r => [r.cle, r.qte]));
  assert.equal(m.oeufs, 10); assert.equal(m.bouteille_eau, 30); assert.equal(m.caviar, undefined); assert.equal(Object.keys(m).length, 15);
  const c = Object.fromEntries((await db.query('SELECT id, data FROM caisses_batiments')).rows.map(r => [r.id, r.data]));
  // Décision n° 6 (26/11) : toutes les caisses publiques de Républia et de Sovarka repartent de leur dotation (catégorie, sinon « * »).
  assert.deepEqual(c.republic_assemblee, { solde: 5000 }, 'Républia : montant arbitré le 05/10');
  assert.deepEqual(c['soviet_mairie-capitale'], { solde: 1500 }, 'Sovarka : dotation par catégorie');
  assert.deepEqual(c.republic_commissariat_ville_a, { solde: 200 }, 'catégorie sans la ville');
  assert.deepEqual(c.soviet_inconnue_ville_b, { solde: 60 }, 'catégorie inconnue : « * » du pays');
  assert.deepEqual(c['narco_mairie-capitale'], { solde: 7992 }, 'empires fermés : non touchés');
  const bn = (await db.query("SELECT data FROM budgets_nationaux WHERE id = 'soviet'")).rows[0].data;
  assert.deepEqual(bn, { tauxNational: 2, reserveJour: 0, refectoire: {}, caserneMatieres: {}, tauxMunicipal: 10, tauxMainOeuvre: 10,
    lotsMilitaires: { radio: [{ lot: 'dotation-initiale', qte: 2 }], tente: [] }, stockArmurerieMilitaire: { radio: 2, tente: 0 } }, 'budget national : valeurs de départ');
  const pc = (await db.query('SELECT taux_douane, repartition, prix_cession, dotation_jour, pnj_couvre_deficit, modifie_par, entrepots FROM ports_commerce')).rows[0];
  assert.deepEqual(pc, { taux_douane: '10', repartition: {}, prix_cession: {}, dotation_jour: '0', pnj_couvre_deficit: true, modifie_par: null, entrepots: ['entrepot'] }, 'port : valeurs de départ');
  const b = Object.fromEntries((await db.query('SELECT id, data FROM batiments_etat')).rows.map(r => [r.id, r.data]));
  assert.equal(b['republic_ville_a_entrepot-logistique-psm'].entrepot.stock.bois, 750, 'entrepôt : stock décidé');
  assert.equal(b['republic_capitale_entrepot-logistique-luthecia'].entrepot.stock.metal, 200);
  assert.deepEqual(b.republic_capitale_banque, { x: 1 }, 'bâtiment sans état initial décrit : gardé');
});
