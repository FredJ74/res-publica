'use strict';
// Tabac-presse de Krasnov (Fred, 22/11/2026, soir, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 27 à 29) :
// cigarettes fumées depuis l'inventaire, carte postale écrite une fois par le serveur, envoyée et reçue (sas, plafond des
// dons), armoires à souvenirs, revue (+1 ENT 24 h non cumulable). Migration 20261123150000, partie E, dans un vrai
// PostgreSQL local (PGlite) sur les définitions de production.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261123150000_tabac_presse_crue.sql';
// La partie F (crue) a son propre banc et ses propres tables : seule la partie E est jouée ici.
const partieE = () => lire(MIGRATION).split('-- ===== PARTIE F : CRUE =====')[0];
const U = { arnie: '00000000-0000-0000-0000-000000000002', tom: '00000000-0000-0000-0000-000000000001' };
const ENT = 'tabac-presse-soviet-ville_b-tabac-presse-krasnov';

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec(lire('migrations/20261122200000_inventaire_direct_capacite.sql'));
  await db.exec(lire('outils/bancs/fixtures/tabac-presse-pglite-socle.sql.txt'));
  await db.exec(partieE());
  await db.query('INSERT INTO personnages VALUES ($1,$2),($3,$4)', ['Arnie', U.arnie, 'Tom Tom', U.tom]);
  const ins = 'INSERT INTO personnages_donnees (name, user_id, country, current_city, current_building, current_room, inventory, moral) VALUES ($1,$2,$3,$4,$5,$6,$7,50)';
  await db.query(ins, ['Arnie', U.arnie, 'soviet', 'ville_b', 'tabac-presse-krasnov', 'boutique', '[]']);
  await db.query(ins, ['Tom Tom', U.tom, 'soviet', 'ville_b', 'krasnov-mairie', 'hall', '[]']);
  return db;
}
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const fiche = async (db, nom) => (await db.query('SELECT * FROM personnages_donnees WHERE name = $1', [nom])).rows[0];
const acheter = (db, produit) => un(db, "SELECT commerce_vendre_produit_interne('Arnie', $1, $2::jsonb) r", [ENT, JSON.stringify([{ produit, qte: 1 }])]);
const sig = o => JSON.stringify({ name: o.name || '', type: o.type || '', stackKey: o.stackKey || '' });
const envoyer = (db, idx, objet, dest, msg) => un(db, 'SELECT carte_postale_envoyer($1, $2, $3::jsonb, $4, $5) r', ['Arnie', idx, sig(objet), dest, msg]);

test('27 : les cigarettes arrivent dans l’inventaire et se fument quand on veut (+2 Moral, réglable)', async () => {
  const db = await base(); await en(db, U.arnie);
  const v = await acheter(db, 'krasnov_papirossy');
  assert.equal(v.ok, true, JSON.stringify(v));
  const c = v.inventory.find(o => o.type === 'krasnov_papirossy');
  assert.ok(c, 'déposées dans l’inventaire');
  assert.equal(c.name, 'Cigarettes papirossy « Étoile du Nord »');
  assert.equal(c.familleProduitMarche, 'tabac');
  assert.equal((await fiche(db, 'Arnie')).moral, 50, 'aucun effet à l’achat');
  const r = await un(db, 'SELECT inventaire_consommer($1, 0, $2::jsonb) r', ['Arnie', sig(c)]);
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.tabac, true); assert.equal(r.moral, 52); assert.equal(r.effets.moral, 2);
  assert.equal((await fiche(db, 'Arnie')).inventory.length, 0, 'la cigarette est fumée');
  await db.query("UPDATE aliments_parametres SET valeur = 3 WHERE cle = 'papirossy_moral'");
  const c2 = (await acheter(db, 'krasnov_papirossy')).inventory[0];
  assert.equal((await un(db, 'SELECT inventaire_consommer($1, 0, $2::jsonb) r', ['Arnie', sig(c2)])).moral, 55);
  // Le billet de loterie (sans famille) reste un article de comptoir : rien n’arrive dans l’inventaire.
  assert.equal((await acheter(db, 'krasnov_loto_plan')).inventory.length, 0);
});

test('28 : carte écrite une fois par le serveur, envoyée au sas du destinataire, signée ; refus nommés', async () => {
  const db = await base(); await en(db, U.arnie);
  const carte = (await acheter(db, 'carte_krasnov_place_ours')).inventory[0];
  assert.equal(carte.etatCarte, 'vierge');
  assert.match(carte.desc, /sous la pluie d'automne/);
  assert.equal(carte.modele, 'carte_krasnov_place_ours');
  assert.equal((await envoyer(db, 0, carte, 'Tom Tom', '   ')).raison, 'message_vide');
  assert.equal((await envoyer(db, 0, carte, 'Arnie', 'Bonjour')).raison, 'destinataire_invalide');
  assert.equal((await envoyer(db, 0, carte, 'Personne', 'Bonjour')).raison, 'destinataire_introuvable');
  assert.equal((await envoyer(db, 0, carte, 'Tom Tom', 'x'.repeat(501))).raison, 'message_trop_long');
  // Plafond commun des dons : Tom Tom n'a plus de place (inventaire plein).
  await db.query("UPDATE personnages_donnees SET inventory = $1 WHERE name = 'Tom Tom'", [JSON.stringify([{ name: 'Bois', stackable: true, stackKey: 'bois', qty: 100 }])]);
  assert.equal((await envoyer(db, 0, carte, 'Tom Tom', 'Bonjour')).raison, 'destinataire_plein');
  assert.equal((await fiche(db, 'Arnie')).inventory.length, 1, 'refus : la carte reste chez Arnie');
  await db.query("UPDATE personnages_donnees SET inventory = '[]' WHERE name = 'Tom Tom'");
  const r = await envoyer(db, 0, carte, 'Tom Tom', '  Grosses bises de Krasnov !  ');
  assert.equal(r.ok, true, JSON.stringify(r));
  assert.equal((await fiche(db, 'Arnie')).inventory.length, 0, 'la carte a quitté Arnie');
  const recu = (await db.query("SELECT expediteur, data FROM objets_recus WHERE destinataire = 'Tom Tom'")).rows;
  assert.equal(recu.length, 1); assert.equal(recu[0].expediteur, 'Arnie');
  const o = JSON.parse(recu[0].data);
  assert.equal(o.etatCarte, 'ecrite'); assert.equal(o.auteur, 'Arnie'); assert.equal(o.destinataireInitial, 'Tom Tom');
  assert.equal(o.message, 'Grosses bises de Krasnov !'); assert.equal(o.imageUrl, carte.imageUrl, 'recto conservé');
  assert.match(o.dateEnvoi, /^\d\d\/\d\d\/\d{4} à \d\d:\d\d$/);
  // Une carte écrite ne se réécrit jamais, même revenue chez Arnie.
  await db.query("UPDATE personnages_donnees SET inventory = jsonb_build_array($1::jsonb) WHERE name = 'Arnie'", [JSON.stringify(o)]);
  assert.equal((await envoyer(db, 0, o, 'Tom Tom', 'Encore')).raison, 'carte_deja_ecrite');
  // L'ancien chemin (don avec mutations du navigateur) ne peut plus écrire une carte.
  const vierge = (await acheter(db, 'carte_krasnov_place_ours')).inventory.find(x => x.etatCarte === 'vierge');
  const idx = (await fiche(db, 'Arnie')).inventory.findIndex(x => x.etatCarte === 'vierge');
  const d = await un(db, 'SELECT inventaire_donner($1, $2, $3, $4::jsonb, 1, $5::jsonb) r',
    ['Arnie', 'Tom Tom', idx, sig(vierge), JSON.stringify({ etatCarte: 'ecrite', auteur: 'Faux', message: 'piraté', dateEnvoi: 'x' })]);
  assert.equal(d.ok, true, JSON.stringify(d));
  assert.equal(d.objet.etatCarte, 'vierge'); assert.equal(d.objet.message, undefined); assert.equal(d.objet.auteur, undefined);
  // Un tiers ne peut pas envoyer au nom d’Arnie.
  await en(db, U.tom);
  await assert.rejects(envoyer(db, 0, o, 'Tom Tom', 'usurpation'), /acteur_non_authentifie/);
});

test('28 : armoires à souvenirs — cartes vierges ou écrites et revues lues acceptées', async () => {
  const db = await base();
  const ok = async o => un(db, 'SELECT souvenir_utilisable_interne($1, $2::jsonb) r', ['Arnie', JSON.stringify(o)]);
  assert.equal(await ok({ familleProduitMarche: 'carte_postale', etatCarte: 'vierge' }), true);
  assert.equal(await ok({ familleProduitMarche: 'carte_postale', etatCarte: 'ecrite' }), true);
  assert.equal(await ok({ type: 'revue_chasse_peche_tracteurs', lue: true }), true);
  assert.equal(await ok({ type: 'revue_chasse_peche_tracteurs' }), false, 'revue non lue');
  assert.equal(await ok({ type: 'feuille_enigme_krasnov' }), false, 'règle de l’énigme inchangée');
  await db.query("INSERT INTO enigmes_resolues (personnage, enigme) VALUES ('Arnie', 'krasnov')");
  assert.equal(await ok({ type: 'feuille_enigme_krasnov' }), true);
});

test('29 : revue — +1 ENT 24 h à l’achat, non cumulable ni prolongée, gardée lue avec le numéro du mois', async () => {
  const db = await base(); await en(db, U.arnie);
  const t0 = Date.now();
  const v = await acheter(db, 'revue_chasse_peche_tracteurs');
  const revue = v.inventory[0];
  assert.equal(revue.lue, true); assert.match(revue.name, /numéro de \S+ \d{4}$/); assert.match(revue.numero, /^\d{4}-\d\d$/);
  assert.equal(revue.bonusIntegrationVille, undefined, 'plus de bonus permanent');
  let e = (await fiche(db, 'Arnie')).effets_actifs.filter(x => x.cle === 'revue_chasse_peche_ent');
  assert.equal(e.length, 1); assert.equal(e[0].deltas.ENT, 1);
  const fin = Number(e[0].expireA);
  assert.ok(Math.abs(fin - t0 - 24 * 3600e3) < 60e3, 'expire 24 h après l’achat');
  const v2 = await acheter(db, 'revue_chasse_peche_tracteurs');
  assert.equal(v2.inventory.length, 2, 'la seconde revue rejoint la collection');
  assert.equal(v2.inventory[1].bonusEntApplique, false);
  e = (await fiche(db, 'Arnie')).effets_actifs.filter(x => x.cle === 'revue_chasse_peche_ent');
  assert.equal(e.length, 1, 'ni augmenté'); assert.equal(Number(e[0].expireA), fin, 'ni prolongé');
  // Bonus échu : un nouvel achat le rouvre pour 24 h.
  await db.query("UPDATE personnages_donnees SET effets_actifs = jsonb_build_array(jsonb_build_object('cle','revue_chasse_peche_ent','deltas',jsonb_build_object('ENT',1),'expireA',1)) WHERE name='Arnie'");
  await acheter(db, 'revue_chasse_peche_tracteurs');
  e = (await fiche(db, 'Arnie')).effets_actifs.filter(x => x.cle === 'revue_chasse_peche_ent');
  assert.equal(e.length, 1); assert.ok(Number(e[0].expireA) > Date.now() + 23 * 3600e3);
});

test('migration rejouable (partie E) et marques uniques posées', async () => {
  const db = await base();
  await db.exec(partieE());
  for (const [fn, marque] of [['commerce_vendre_produit_interne', 'produit_marche_livrer_v1'], ['commerce_vendre_produit_interne', 'produit_marche_livrer_fin_v1'],
    ['inventaire_consommer', 'tabac_fumer_v1'], ['inventaire_consommer', 'tabac_fumer_effet_v1'], ['inventaire_donner', 'carte_postale_ecrite_serveur_v1']]) {
    const d = await un(db, "SELECT pg_get_functiondef(p.oid) r FROM pg_proc p WHERE proname = $1", [fn]);
    assert.equal(d.split(marque).length - 1, 1, fn + ' : ' + marque + ' une seule fois');
  }
});
