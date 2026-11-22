'use strict';
// Lot de Krasnov, étape I (mission de la nuit du 22/11/2026), dans un vrai PostgreSQL local (PGlite) :
//   point 2 : marché unique de Krasnov (acheter / vendre / produire en un seul « Valider », tout ou rien) ;
//   point 3 : une fontaine par ville ; l'eau déjà puisée vendue 2 PSK au marché ;
//   point 9 : « Inspecter la pièce » (1 PA : caméras + personnes cachées), « Désinstaller du matériel » (2 PA, au sol).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const UID = { Nina: '00000000-0000-0000-0000-000000000001', Tom: '00000000-0000-0000-0000-000000000002', Arnie: '00000000-0000-0000-0000-000000000003' };
const MIGRATIONS = ['20261122160000_krasnov_marche_unique', '20261122161000_points_eau_une_fontaine_par_ville', '20261122162000_pieces_inspecter_desinstaller'];

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/krasnov-lot-suite-pglite-socle.sql.txt'));
  for (const m of MIGRATIONS) await db.exec(lire('migrations/' + m + '.sql'));
  for (const [n, u] of Object.entries(UID)) await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
  await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, pa, liquide, inventory) VALUES
    ('Nina', 'soviet', 'ville_b', 'marche', 'marche_ext', 10, 100, $1),
    ('Tom', 'soviet', 'ville_b', 'bureaux', 'bureau_1', 10, 0, '[]'),
    ('Arnie', 'soviet', 'ville_b', 'bureaux', 'bureau_1', 10, 0, '[]')`,
  [JSON.stringify([
    { name: 'Tenue ninja', type: 'tenue_ninja_marche', recette_id: 'tenue_ninja_marche', id: 'n1' },
    { name: 'Tenue ninja', type: 'tenue_ninja_marche', recette_id: 'tenue_ninja_marche', id: 'n2' },
    { name: 'Tenue ninja', type: 'tenue_ninja_marche', recette_id: 'tenue_ninja_marche', id: 'n3', porte_par: 'Nina' },
    { name: 'fruits_legumes', stackable: true, stackKey: 'fruits_legumes', qty: 5 }])]);
  return db;
}
async function appel(db, qui, sql, args = []) {
  await db.query("SELECT set_config('test.uid', $1, false)", [UID[qui]]);
  return (await db.query(sql, args)).rows[0].r;
}
const etat = (db, qui = 'Nina') => appel(db, qui, 'SELECT marche_krasnov_etat() r');
const valider = (db, lignes, qui = 'Nina', req = null) =>
  appel(db, qui, 'SELECT marche_krasnov_valider(coalesce($2::uuid, gen_random_uuid()), $1::jsonb) r', [JSON.stringify(lignes), req]);
const un = async (db, sql, args = []) => (await db.query(sql, args)).rows[0];
const caisse = async db => Number((await un(db, "SELECT data->>'solde' s FROM caisses_batiments WHERE id = 'soviet_marche_ville_b'")).s);
const stock = async (db, cle) => (await un(db, 'SELECT qte FROM marche_krasnov_stock WHERE cle = $1', [cle])).qte;
const perso = (db, n = 'Nina') => un(db, 'SELECT pa, liquide, inventory FROM personnages_donnees WHERE name = $1', [n]);
const qte = (inv, cle) => inv.filter(e => e.stackKey === cle).reduce((s, e) => s + Number(e.qty || 1), 0);

test('point 2 : la fenêtre lit 15 produits, la caisse dotée de 1 000 PSK, les prix de rachat à −25 % et ce que possède le joueur', async () => {
  const db = await base();
  const e = await etat(db);
  assert.equal(e.ok, true); assert.equal(e.ici, true); assert.equal(e.caisse, 1000); assert.equal(e.salaire_pa, 15);
  assert.equal(e.produits.length, 15);
  const p = Object.fromEntries(e.produits.map(x => [x.cle, x]));
  assert.deepEqual([p.confiture.prix_vente, p.pain_noir.prix_vente, p.goulash.prix_vente, p.chemise.prix_vente], [10, 8, 13, 18]);
  assert.deepEqual([p.graisse_ours.prix_vente, p.graisse_ours.prix_rachat], [16, 12]);
  assert.deepEqual([p.oeufs.prix_rachat, p.viande.prix_vente, p.bouteille_eau.prix_vente], [2, 3, 2]);
  for (const x of e.produits) assert.equal(x.prix_rachat, Math.floor(x.prix_vente * 0.75), x.cle + ' : rachat = prix − 25 %');
  assert.deepEqual([p.confiture.unites, p.pain_noir.unites, p.goulash.unites, p.chemise.unites], [4, 5, 3, 2]);
  assert.equal(p.tenue_ninja.possede, 2, 'la tenue portée ne se vend pas');
  assert.equal(p.fruits_legumes.possede, 5);
  assert.equal(p.guide_baies, undefined, 'le guide des baies n’est plus au marché');
  assert.equal((await un(db, "SELECT count(*)::int n FROM graisses_points_vente WHERE id = 'marche-krasnov'")).n, 1, 'ligne conservée (aucune suppression sans validation de Fred)');
});

test('point 2 : acheter, vendre et produire en un seul Valider ; argent, caisse, stock, PA et inventaire suivent', async () => {
  const db = await base();
  const r = await valider(db, [
    { cle: 'bouteille_eau', acheter: 3 }, { cle: 'graisse_ours', acheter: 1 },
    { cle: 'tenue_ninja', vendre: 2 }, { cle: 'confiture', produire: 2 }]);
  assert.equal(r.ok, true, JSON.stringify(r));
  assert.equal(r.depense, 22); assert.equal(r.gain_ventes, 48); assert.equal(r.salaire, 30); assert.equal(r.pa_depenses, 2);
  const n = await perso(db);
  assert.equal(n.pa, 8); assert.equal(Number(n.liquide), 100 - 22 + 48 + 30);
  assert.equal(qte(n.inventory, 'bouteille_eau'), 3); assert.equal(qte(n.inventory, 'graisse_ours'), 1);
  assert.equal(n.inventory.filter(e => e.type === 'tenue_ninja_marche').length, 1, 'la tenue portée reste');
  assert.equal(await caisse(db), 1000 + 22 - 48 - 30);
  assert.deepEqual([await stock(db, 'bouteille_eau'), await stock(db, 'graisse_ours'), await stock(db, 'tenue_ninja')], [27, 9, 4]);
  assert.deepEqual([await stock(db, 'fruits_legumes'), await stock(db, 'sucre'), await stock(db, 'confiture')], [18, 8, 16]);
  // Rejeu de la même demande : aucun second effet.
  const req = '11111111-1111-1111-1111-111111111111';
  await valider(db, [{ cle: 'pain_noir', acheter: 1 }], 'Nina', req);
  const r2 = await valider(db, [{ cle: 'pain_noir', acheter: 1 }], 'Nina', req);
  assert.equal(r2.rejeu, true); assert.equal(qte((await perso(db)).inventory, 'krasnov_pain_noir'), 1);
});

test('point 2 : rien n’est exécuté à moitié ; chaque refus est nommé', async () => {
  const db = await base();
  const avant = JSON.stringify([await perso(db), await caisse(db), await stock(db, 'tenue_ninja')]);
  const r = await valider(db, [{ cle: 'tenue_ninja', vendre: 2 }, { cle: 'masque_carnaval', acheter: 50 }]);
  assert.equal(r.ok, false); assert.equal(r.raison, 'stock_insuffisant'); assert.equal(r.cle, 'masque_carnaval');
  assert.equal(JSON.stringify([await perso(db), await caisse(db), await stock(db, 'tenue_ninja')]), avant, 'la vente n’a pas eu lieu');
  assert.equal((await valider(db, [{ cle: 'graisse_ours', acheter: 9 }])).raison, 'argent_insuffisant');
  await db.query("UPDATE personnages_donnees SET pa = 1 WHERE name = 'Nina'");
  assert.equal((await valider(db, [{ cle: 'confiture', produire: 2 }])).raison, 'pa_insuffisants');
  await db.query("UPDATE personnages_donnees SET pa = 10 WHERE name = 'Nina'");
  assert.equal((await valider(db, [{ cle: 'graisse_ours', produire: 1 }])).raison, 'production_impossible');
  assert.equal((await valider(db, [{ cle: 'tenue_ninja', vendre: 3 }])).raison, 'vous_n_en_avez_pas_assez');
  assert.equal((await valider(db, [{ cle: 'chemise', produire: 11 }])).raison, 'matiere_manquante');
  assert.equal((await valider(db, [])).raison, 'rien_a_faire');
  assert.equal((await valider(db, [{ cle: 'inconnu', acheter: 1 }])).raison, 'produit_inconnu');
  await db.query("UPDATE caisses_batiments SET data = '{\"solde\":0}' WHERE id = 'soviet_marche_ville_b'");
  assert.equal((await valider(db, [{ cle: 'fruits_legumes', vendre: 1 }])).raison, 'caisse_vide');
  assert.equal((await valider(db, [{ cle: 'fruits_legumes', vendre: 1 }, { cle: 'bouteille_eau', acheter: 1 }])).ok, true, 'l’achat renfloue la caisse');
  await db.query("UPDATE personnages_donnees SET inventory = (SELECT jsonb_agg(jsonb_build_object('name','x','id','x'||g)) FROM generate_series(1,100) g) WHERE name = 'Nina'");
  assert.equal((await valider(db, [{ cle: 'bouteille_eau', acheter: 1 }])).raison, 'inventaire_plein');
  assert.equal((await valider(db, [{ cle: 'bouteille_eau', acheter: 1 }], 'Tom')).raison, 'pas_au_marche');
});

test('point 2 : pain noir et fruits = repas brut (+1 PA au prochain Dormir, un par nuit) ; goulash = +2 PA tout de suite', async () => {
  const db = await base();
  await valider(db, [{ cle: 'pain_noir', acheter: 2 }, { cle: 'goulash', acheter: 1 }]);
  const m = (cle) => appel(db, 'Nina', 'SELECT marche_krasnov_manger(gen_random_uuid(), $1) r', [cle]);
  const p = await m('pain_noir');
  assert.equal(p.ok, true); assert.equal(p.bonus_differe, 1);
  assert.equal((await m('fruits_legumes')).raison, 'repas_brut_deja_pris');
  const g = await m('goulash');
  assert.equal(g.ok, true); assert.equal(g.gain_pa, 2); assert.equal(g.pa, 12);
  assert.equal((await m('goulash')).raison, 'pas_dans_l_inventaire');
  assert.equal(qte((await perso(db)).inventory, 'krasnov_pain_noir'), 1);
});

test('point 3 : une fontaine active par ville, sur une vue qui existe ; migration rejouable', async () => {
  const db = await base();
  const r = (await db.query('SELECT pays, ville, count(*)::int n FROM climat_points_eau WHERE actif GROUP BY 1, 2')).rows;
  assert.equal(r.length, 6); assert.ok(r.every(x => x.n === 1));
  for (const m of MIGRATIONS) await db.exec(lire('migrations/' + m + '.sql'));
  assert.equal((await un(db, 'SELECT count(*)::int n FROM climat_points_eau')).n, 6);
  assert.equal((await un(db, 'SELECT count(*)::int n FROM marche_krasnov_produits')).n, 15);
});

test('point 9 : Inspecter la pièce coûte 1 PA, révèle les caméras et débusque les cachés (journal du débusqué)', async () => {
  const db = await base();
  await db.query(`UPDATE personnages_donnees SET stats = '{"PER":40}', inventory = '[{"generique_id":"couinator-3000"}]' WHERE name = 'Tom'`);
  await db.query("INSERT INTO cameras_posees (proprietaire, pays, ville, batiment, piece) VALUES ('Arnie', 'soviet', 'ville_b', 'bureaux', 'bureau_1')");
  await db.query("INSERT INTO caches_pj (personnage, pays, ville, batiment, piece) VALUES ('Arnie', 'soviet', 'ville_b', 'bureaux', 'bureau_1')");
  await db.query("INSERT INTO reglages_test VALUES ('taux_fouille', '100')");
  const r = await appel(db, 'Tom', 'SELECT inspecter_piece() r');
  assert.equal(r.ok, true); assert.equal(r.pa, 9); assert.equal(r.taux, 99);
  assert.equal(r.nb, 1); assert.deepEqual(r.trouves, [{ masque: false, nom: 'Arnie' }]);
  assert.equal((await perso(db, 'Tom')).pa, 9, 'un seul PA pour les deux recherches');
  const ev = (await db.query("SELECT * FROM evenements_test WHERE type = 'debusque'")).rows;
  assert.equal(ev.length, 1); assert.equal(ev[0].nom, 'Arnie'); assert.equal(ev[0].donnees.par, 'Tom');
  await db.query("UPDATE personnages_donnees SET pa = 0 WHERE name = 'Tom'");
  assert.equal((await appel(db, 'Tom', 'SELECT inspecter_piece() r')).raison, 'pa_insuffisants');
  // Dans la rue : caméras seulement.
  await db.query("UPDATE personnages_donnees SET pa = 5, current_building = NULL, current_room = NULL, current_street = 'krasnov-place-ours' WHERE name = 'Tom'");
  const rue = await appel(db, 'Tom', 'SELECT inspecter_piece() r');
  assert.equal(rue.ok, true); assert.equal(rue.piece, false); assert.equal(rue.nb_personnes, 0);
});

test('point 9 : Désinstaller chez soi : 2 PA, l’objet tombe au sol, sans trace ; ailleurs : vol aux règles communes', async () => {
  const db = await base();
  const poser = async (prop, gen = 'ordinateur-complet') => (await un(db, `INSERT INTO equipements_installes (proprietaire, generique_id, objet, pays, ville, batiment, piece)
      VALUES ($1, $2, $3, 'soviet', 'ville_b', 'bureaux', 'bureau_1') RETURNING id`, [prop, gen, JSON.stringify({ name: 'Ordinateur', id: 'o-' + prop })])).id;
  const e1 = await poser('Arnie');
  await db.query("INSERT INTO locaux_test VALUES ('Tom', 'bureaux', 'bureau_1')");
  const l = await appel(db, 'Tom', 'SELECT desinstaller_lire() r');
  assert.equal(l.chez_soi, true); assert.equal(l.materiel[0].legal, true); assert.equal(l.cout_pa, 2);
  const r = await appel(db, 'Tom', 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [e1]);
  assert.equal(r.ok, true); assert.equal(r.legal, true); assert.equal(r.au_sol, true); assert.equal(r.pa, 8);
  const sol = await un(db, 'SELECT * FROM objets_abandonnes WHERE id = $1', [r.objet_sol]);
  assert.equal(sol.room_id, 'bureau_1'); assert.equal(JSON.parse(sol.data).name, 'Ordinateur');
  assert.equal(JSON.parse(sol.data).id, r.objet_sol, 'même forme qu’un objet abandonné : ramassable par son identifiant');
  assert.equal((await un(db, 'SELECT count(*)::int n FROM equipements_installes WHERE id = $1', [e1])).n, 0, 'plus lié à la pièce');
  assert.equal((await un(db, 'SELECT count(*)::int n FROM crim_affaires')).n, 0, 'légal : aucune affaire');

  // Ailleurs (Arnie n'a pas la jouissance du bureau) : vol réussi → au sol, affaire livrée, constat, trace.
  const e2 = await poser('Tom');
  await db.query("INSERT INTO reglages_test VALUES ('temoin', '1')");
  const v = await appel(db, 'Arnie', 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [e2]);
  assert.equal(v.ok, true); assert.equal(v.legal, false); assert.equal(v.au_sol, true); assert.equal(v.pa, 8);
  const f = await un(db, 'SELECT * FROM crim_affaires');
  assert.equal(f.acte, 'cambrioler'); assert.equal(f.details.livre, true); assert.equal(f.details.params.butin_plan.genre, 'materiel');
  assert.match(f.details.params.msg_reussite, /démonté Ordinateur/);
  assert.equal((await un(db, 'SELECT destinataire FROM crim_constats')).destinataire, 'Tom');
  assert.equal((await un(db, "SELECT count(*)::int n FROM evenements_test WHERE type = 'trace_vol'")).n, 1);

  // Échec : le matériel reste en place.
  const e3 = await poser('Tom');
  await db.query("INSERT INTO reglages_test VALUES ('issue', 'echec')");
  const x = await appel(db, 'Arnie', 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [e3]);
  assert.equal(x.au_sol, false);
  assert.equal((await un(db, 'SELECT count(*)::int n FROM equipements_installes WHERE id = $1', [e3])).n, 1);
  // Refus nommés.
  await db.query("INSERT INTO serrures (statut, cible, fermee, armoire_objet) VALUES ('posee', 'armoire', true, 'o-Tom')");
  assert.equal((await appel(db, 'Arnie', 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [e3])).raison, 'armoire_fermee_a_cle');
  await db.query('DELETE FROM serrures');
  await db.query("UPDATE personnages_donnees SET pa = 1 WHERE name = 'Arnie'");
  assert.equal((await appel(db, 'Arnie', 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [e3])).raison, 'pa_insuffisants');
  await db.query("UPDATE personnages_donnees SET current_room = 'bureau_2' WHERE name = 'Arnie'");
  assert.equal((await appel(db, 'Arnie', 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [e3])).raison, 'pas_sur_place');
});
