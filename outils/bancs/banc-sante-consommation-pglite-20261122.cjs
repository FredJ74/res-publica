'use strict';
// Santé — consommation (Fred, 22/11/2026, après-midi, GAME-DESIGN-SANTE-20261122.md, points 7 à 11), migration
// 20261122232000, dans un vrai PostgreSQL local (PGlite) : socle Santé chargé avant, fonctions de production recopiées.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261122232000_sante_consommation.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', ana: '00000000-0000-0000-0000-000000000002' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec('ALTER TABLE personnages_donnees ALTER COLUMN detention_qhs DROP DEFAULT; ALTER TABLE personnages_donnees ALTER COLUMN detention_qhs TYPE jsonb USING NULL');
  await db.exec(lire('migrations/20261122230000_sante_socle.sql'));
  await db.exec(lire('outils/bancs/fixtures/sante-consommation-pglite-socle.sql.txt'));
  await db.query('INSERT INTO personnages VALUES ($1,$2), ($3,$4)', ['Tom Tom', U.tom, 'Ana', U.ana]);
  await db.query(`INSERT INTO personnages_donnees (name, user_id, country, current_city, current_building, current_room, hp, moral, pa)
                  VALUES ('Tom Tom', $1, 'republic', 'capitale', 'mairie-capitale', 'hall_mairie', 50, 50, 10),
                         ('Ana', $2, 'republic', 'capitale', 'mairie-capitale', 'hall_mairie', 50, 50, 10)`, [U.tom, U.ana]);
  await db.exec(lire(MIGRATION));
  await en(db, U.tom);
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const fiche = (db, nom = 'Tom Tom') => db.query('SELECT hp, moral, pa, bonus_pa_differe FROM personnages_donnees WHERE name=$1', [nom]).then(r => r.rows[0]);
const poser = (db, champs, nom = 'Tom Tom') => {
  const cles = Object.keys(champs);
  return db.query(`UPDATE personnages_donnees SET ${cles.map((k, i) => `${k}=$${i + 2}`).join(', ')} WHERE name=$1`, [nom, ...cles.map(k => champs[k])]);
};

const FONCTIONS = {
  'maladie_verre_interne(text)': ['sante_conso_alcool'],
  'tournee_cloturer_boire(text)': ['sante_conso_tournee'],
  'commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)': ['sante_conso_cvp_a', 'sante_conso_cvp_b', 'sante_conso_cvp_c'],
  'consommer_sur_place_commerce(text,text,text,text)': ['sante_conso_sp_a', 'sante_conso_sp_b', 'sante_conso_sp_c'],
  'inventaire_consommer(text,integer,jsonb)': ['sante_conso_inv_a', 'sante_conso_inv_b'],
  'restaurant_diner_servir(bigint)': ['sante_conso_rd_a', 'sante_conso_rd_b', 'sante_conso_rd_c', 'sante_conso_rd_d'],
  'diner_commerce_servir_interne(text,bigint)': ['sante_conso_dc_a', 'sante_conso_dc_b', 'sante_conso_dc_c', 'sante_conso_dc_d'],
  'service_etage_commander(uuid,text)': ['sante_conso_se_a', 'sante_conso_se_b', 'sante_conso_se_c'],
  'hotel_service_etage_commander()': ['sante_conso_hse_a', 'sante_conso_hse_b', 'sante_conso_hse_c'],
  'marche_krasnov_manger(uuid,text)': ['sante_conso_mk_a', 'sante_conso_mk_b', 'sante_conso_mk_c', 'sante_conso_mk_d', 'sante_conso_mk_e'],
  'pa_repos_nocturne(text)': ['sante_conso_nuit_a', 'sante_conso_nuit_b'],
  'clinique_nuitee_marquer_repos()': ['sante_conso_clin_t1', 'sante_conso_clin_t2'],
  'clinique_nuitee_consommer()': ['sante_conso_clin_c1', 'sante_conso_clin_c2', 'sante_conso_clin_c3'],
  'recevoir_soin(text,text,text,text,text,integer)': ['sante_conso_soin_a', 'sante_conso_soin_b', 'sante_conso_soin_c', 'sante_conso_soin_d',
    'sante_conso_soin_e', 'sante_conso_soin_f', 'sante_conso_soin_g'],
  'ordre_generique_executer(text,integer,integer)': ['sante_conso_og_a', 'sante_conso_og_b', 'sante_conso_og_c']
};

// Empreintes md5 de pg_get_functiondef en PRODUCTION (22/11/2026) : la doublure doit être identique, octet pour octet.
const EMPREINTES_PROD = {"boisson_alcoolisee_interne(text)":"98498c0dc905c50f33220bcb2f878e4b","boisson_bue_recette_interne(text,text)":"5b6c8a6f804f85a0f4a54781fce79fed","boisson_objet_interne(jsonb)":"9afc86bc68f545bd57d5093ba5162ee2","clinique_nuitee_consommer()":"fe7e70aaa3b15e8d0a3a70800d58c082","clinique_nuitee_marquer_repos()":"15095d8686fcbe3c0d6986477126bf8c","commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)":"45cfc0cd9d60d2956741b0aa737ee87c","consommer_sur_place_commerce(text,text,text,text)":"f2971299c5795c8f74da317de9cc5cf4","diner_commerce_servir_interne(text,bigint)":"c913ccfe9ec1f2e500724a10ebc5e5aa","hotel_service_etage_commander()":"5f5bdfa1e84753c98c91cd041e0482ee","inventaire_consommer(text,integer,jsonb)":"3006a203a28743b1a0871256e29b6ef1","logement_sommeil_interne(text)":"ef6b081279805197770541c195dff3e3","maladie_verre_interne(text)":"9fb2b8a6a09e3683b8ff934ee068660c","marche_krasnov_manger(uuid,text)":"4d4fa74503e112afe9f331074a5f7d06","ordre_generique_executer(text,integer,integer)":"af5d3bf27dec813e55c8b453594d2130","pa_bonus_differe_crediter(text,text)":"fb4518591334b8177a6f2ffa38c0fcca","pa_repos_nocturne(text)":"c9652796f2693914b2b435c8130a0cb8","recevoir_soin(text,text,text,text,text,integer)":"f68c864451453db16499904b91b1f60a","repas_differe_crediter_interne(text,text,text)":"2ef2c8aed0a7f0c29aefd57dcebd5bb8","restaurant_diner_servir(bigint)":"04b198bc8d8144a513da4b9e00c9a486","service_etage_commander(uuid,text)":"9368d603027eb1a893883cf6361202bf","tournee_cloturer_boire(text)":"0adb310aa8719ef10d22f648df20eb17"};
test('doublure : les 21 fonctions recopiées sont identiques à la production (md5 de pg_get_functiondef)', async () => {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec('ALTER TABLE personnages_donnees ALTER COLUMN detention_qhs DROP DEFAULT; ALTER TABLE personnages_donnees ALTER COLUMN detention_qhs TYPE jsonb USING NULL');
  await db.exec(lire('migrations/20261122230000_sante_socle.sql'));
  await db.exec(lire('outils/bancs/fixtures/sante-consommation-pglite-socle.sql.txt'));
  for (const [f, h] of Object.entries(EMPREINTES_PROD))
    assert.equal(await un(db, `SELECT md5(pg_get_functiondef('public.${f}'::regprocedure)) r`), h, f);
});

test('migration : chaque raccord une seule fois, rejouable, aucune Santé touchée, plus aucun +5/+10 en dur', async () => {
  const db = await base();
  assert.deepEqual(await fiche(db), { hp: 50, moral: 50, pa: 10, bonus_pa_differe: 0 });
  await db.exec(lire(MIGRATION));
  assert.equal((await fiche(db)).hp, 50);
  for (const [f, marques] of Object.entries(FONCTIONS)) {
    const d = await un(db, `SELECT pg_get_functiondef('public.${f}'::regprocedure) r`);
    for (const m of marques) assert.equal(d.split(m).length, m === 'sante_conso_nuit_b' ? 3 : 2, f + ' ' + m); // nuit_b : les deux RETURN de réussite
  }
  const t = await un(db, "SELECT pg_get_functiondef('public.tournee_cloturer_boire(text)'::regprocedure) r");
  assert.ok(!t.includes('coalesce(hp,100)+5'));
  for (const f of ['clinique_nuitee_consommer()', 'clinique_nuitee_marquer_repos()'])
    assert.ok(!(await un(db, `SELECT pg_get_functiondef('public.${f}'::regprocedure) r`)).includes('COALESCE(hp,0)+10'), f);
  assert.equal(await un(db, "SELECT count(*)::int r FROM marche_krasnov_produits WHERE effet LIKE '%Santé%'"), 3);
});

test('alcool : 1er verre +1, 2e 0, 3e −2 (perte non modulée), même compteur que la gueule de bois', async () => {
  const db = await base();
  await db.query("SELECT maladie_verre_interne('Tom Tom')");
  assert.equal((await fiche(db)).hp, 51);
  await db.query("SELECT maladie_verre_interne('Tom Tom')");
  assert.equal((await fiche(db)).hp, 51);
  await db.query("SELECT maladie_verre_interne('Tom Tom')");
  assert.equal((await fiche(db)).hp, 49);
  assert.equal(await un(db, "SELECT n r FROM verres_du_jour WHERE nom='Tom Tom'"), 3);
  assert.equal(await un(db, "SELECT count(*)::int r FROM maladies_tirages_test WHERE maladie='gueule_de_bois'"), 1, 'tirage au 3e verre, inchangé');
  // Moral 20 : le 3e verre retire toujours 2 ; le 1er d'Ana (Moral 80) rend 2 (1 × 1,5 arrondi).
  await poser(db, { moral: 20 });
  await db.query("SELECT maladie_verre_interne('Tom Tom')");
  assert.equal((await fiche(db)).hp, 47);
  await poser(db, { moral: 80 }, 'Ana');
  await db.query("SELECT maladie_verre_interne('Ana')");
  assert.equal((await fiche(db, 'Ana')).hp, 52);
});

test('alcool : une bière au comptoir d’un commerce PNJ est comptée ; le café ne donne rien', async () => {
  const db = await base();
  let r = await un(db, "SELECT commerce_vendre_produit('Tom Tom', 'bar', '[{\"produit\":\"biere_pression\",\"qte\":1}]'::jsonb) r");
  assert.equal(r.ok, true); assert.equal(r.hp, 51); assert.equal(r.moral, 52, 'Moral de la recette appliqué par le serveur');
  r = await un(db, "SELECT commerce_vendre_produit('Tom Tom', 'bar', '[{\"produit\":\"cafe_boisson\",\"qte\":1}]'::jsonb) r");
  assert.equal(r.hp, 51);
  assert.equal(await un(db, "SELECT n r FROM verres_du_jour WHERE nom='Tom Tom'"), 1);
});

async function dormir(db, lieu, nom = 'Tom Tom') {
  await poser(db, lieu, nom);
  return un(db, 'SELECT pa_repos_nocturne($1) r', [nom]);
}
test('sommeil : chambre +5, bâtiment +3, dehors +2, hôpital +5, clinique +7 ; une fois par jour ; réveil appelé', async () => {
  const cas = [
    [{ current_building: 'hotel-republica', current_room: 'chambres' }, 'chambre', 5],
    [{ current_building: 'mairie-capitale', current_room: 'hall_mairie' }, 'batiment', 3],
    [{ current_building: 'hotel-republica', current_room: 'accueil' }, 'batiment', 3],
    [{ current_building: null, current_room: null, current_street: 'rue-1' }, 'dehors', 2],
    [{ country: 'soviet', current_city: 'ville_b', current_building: 'zone-production', current_room: 'foret_vue_2' }, 'dehors', 2],
    [{ current_building: 'dispensaire-public', current_room: 'chambre' }, 'hopital', 5],
    [{ current_building: 'clinique-privee', current_room: 'chambre_3' }, 'clinique', 7],
    [{ current_building: 'clinique-privee', current_room: 'reception_clinique' }, 'batiment', 3]
  ];
  for (const [lieu, attendu, gain] of cas) {
    const db = await base();
    const r = await dormir(db, lieu);
    assert.equal(r.ok, true, JSON.stringify(r));
    assert.equal(r.sante_sommeil.lieu, attendu, JSON.stringify(lieu));
    assert.equal(r.sante_sommeil.gain, gain, attendu);
    assert.equal((await fiche(db)).hp, 50 + gain);
    assert.deepEqual(r.evenements_reveil, []);
    const bis = await un(db, "SELECT pa_repos_nocturne('Tom Tom') r");
    assert.equal(bis.raison, 'deja_repose');
    assert.equal((await fiche(db)).hp, 50 + gain, 'aucun second gain');
  }
});

test('sommeil : son propre logement est une chambre ; Moral 80 → ×1,5 ; événements du réveil renvoyés', async () => {
  const db = await base();
  await db.query("INSERT INTO logements_test VALUES ('republic','ville_b','logements-montrouge','appartement_3','Tom Tom')");
  await db.query(`CREATE OR REPLACE FUNCTION public.sante_reveil_interne(p_nom text) RETURNS jsonb LANGUAGE sql AS
    $$ SELECT jsonb_build_array(jsonb_build_object('cle', 'test', 'texte', 'Réveil de ' || p_nom)) $$`);
  await poser(db, { moral: 80 });
  const r = await dormir(db, { current_city: 'ville_b', current_building: 'logements-montrouge', current_room: 'appartement_3' });
  assert.equal(r.sante_sommeil.lieu, 'chambre'); assert.equal(r.sante_sommeil.gain, 8, '5 × 1,5 = 7,5 → 8');
  assert.equal(r.evenements_reveil[0].texte, 'Réveil de Tom Tom');
  assert.equal(r.logement.pa, 1, 'le PA du logement reste compté par pa_repos_nocturne');
});

test('sommeil : patient hospitalisé à l’hôpital +5, nuitée de clinique +7 une seule fois (déclencheur puis consommation)', async () => {
  let db = await base();
  let r = await dormir(db, { current_building: 'dispensaire-public-v', current_room: 'chambre', current_city: 'ville_a',
    hospitalisation: { regime: 'pa0', jour: 2, lieu: 'dispensaire' } });
  assert.equal(r.hospitalisation, true); assert.equal(r.sante_sommeil.lieu, 'hopital'); assert.equal((await fiche(db)).hp, 55);

  db = await base();
  await db.query("INSERT INTO clinique_nuitees (personnage, country, city, room_id, prix) VALUES ('Tom Tom','republic','capitale','chambre_2',150)");
  await db.query(`INSERT INTO locations_actives VALUES ('republic:clinique-privee:chambre_2:capitale', 'republic',
    '{"locataire":"Tom Tom","reservationClinique":"true"}')`);
  r = await dormir(db, { current_building: 'clinique-privee', current_room: 'chambre_2' });
  const f = await fiche(db);
  assert.equal(f.hp, 57, '+7, pas +7 deux fois ni +10'); assert.equal(f.moral, 53, 'Moral de la nuitée inchangé');
  assert.equal(r.sante_sommeil.lieu, 'clinique');
  const c = await un(db, 'SELECT clinique_nuitee_consommer() r');
  assert.equal(c.rejeu, true); assert.equal((await fiche(db)).hp, 57);
});

test('repas : menu au comptoir à Moral 80 (+8 Santé, +3 PA différés) puis à Moral 20 (+3, +3) ; Moral de la recette', async () => {
  const db = await base();
  await poser(db, { moral: 80 });
  let r = await un(db, "SELECT commerce_vendre_produit('Tom Tom', 'resto', '[{\"produit\":\"menu_gastronomique_1\",\"qte\":1}]'::jsonb) r");
  let f = await fiche(db);
  assert.equal(f.hp, 58); assert.equal(f.bonus_pa_differe, 3); assert.equal(f.moral, 81); assert.equal(r.hp, 58); assert.equal(r.bonus_pa_differe, 3);
  await poser(db, { moral: 20, hp: 50, bonus_pa_differe: 0 });
  await db.query("SELECT commerce_vendre_produit('Tom Tom', 'resto', '[{\"produit\":\"menu_gastronomique_1\",\"qte\":1}]'::jsonb)");
  f = await fiche(db);
  assert.equal(f.hp, 53, '5 × 0,5 = 2,5 → 3'); assert.equal(f.bonus_pa_differe, 3, 'PA différés jamais modulés');
});

test('repas : barème complet (plat, sandwich, snack, recette inconnue de la table → catégorie de la recette, boisson 0)', async () => {
  const db = await base();
  const essai = async (produit) => {
    await poser(db, { hp: 50, bonus_pa_differe: 0 });
    await db.query("SELECT commerce_vendre_produit('Tom Tom', 'r', $1::jsonb)", [JSON.stringify([{ produit, qte: 1 }])]);
    const f = await fiche(db); return [f.hp - 50, f.bonus_pa_differe];
  };
  assert.deepEqual(await essai('boeuf_bourguignon'), [4, 2]);
  assert.deepEqual(await essai('sandwich'), [3, 1]);
  assert.deepEqual(await essai('pirojki_sovarka'), [1, 0]);
  assert.deepEqual(await essai('nouveau_plat'), [4, 2]);
  assert.deepEqual(await essai('cafe_boisson'), [0, 0]);
  assert.equal(await un(db, "SELECT sante_repas_categorie_interne('sever_tartine_salo') r"), 'sandwich');
  assert.equal(await un(db, "SELECT sante_repas_categorie_interne('krasnov_pain_noir') r"), 'sandwich');
});

test('repas gastronomique (vente « service ») : effet du plat réellement servi', async () => {
  const db = await base();
  const r = await un(db, "SELECT commerce_vendre_produit('Tom Tom', 'resto', '[{\"produit\":\"boeuf_bourguignon\",\"qte\":1}]'::jsonb, 'service', 'repas_gastronomique', 0, 120) r");
  assert.equal(r.sante.categorie, 'plat'); assert.equal(r.hp, 54); assert.equal((await fiche(db)).bonus_pa_differe, 2);
});

test('produits de joueur : palier 5 à 9,99 (+3/+1), 10 et plus (+4/+2), sous 5 rien ; sur place et inventaire', async () => {
  const db = await base();
  await db.query(`INSERT INTO entreprises VALUES ('fonds-1', '{"typesAutorises":["bar-restauration"],"references":{
    "ref-a":{"nom":"Rocher","prixVente":7,"recette_id":"chocolat_generique","generique_id":"encas-a-emporter"},
    "ref-b":{"nom":"Ballotin","prixVente":15,"recette_id":"chocolat_generique","generique_id":"encas-a-emporter"},
    "ref-c":{"nom":"Bonbon","prixVente":3,"recette_id":"chocolat_generique","generique_id":"encas-a-emporter"},
    "ref-d":{"nom":"Chocolat chaud","prixVente":12,"recette_id":"cafe_boisson","generique_id":"boisson"}}}')`);
  const surPlace = async (ref) => {
    await poser(db, { hp: 50, bonus_pa_differe: 0 });
    const r = await un(db, "SELECT consommer_sur_place_commerce($1, 'Tom Tom', 'fonds-1', $2) r", ['req-' + ref, ref]);
    assert.equal(r.ok, true, JSON.stringify(r));
    const f = await fiche(db); return [f.hp - 50, f.bonus_pa_differe, r.effets.hp];
  };
  assert.deepEqual(await surPlace('ref-a'), [3, 1, 3]);
  assert.deepEqual(await surPlace('ref-b'), [4, 2, 4]);
  assert.deepEqual(await surPlace('ref-c'), [0, 0, 0]);
  assert.deepEqual(await surPlace('ref-d'), [0, 0, 0]);
  // Inventaire : un produit de joueur acheté (provenance) et une barquette du marché (plat).
  const maintenant = Date.now();
  await poser(db, { hp: 50, bonus_pa_differe: 0, pa: 10, inventory: JSON.stringify([
    { name: 'Rocher', type: 'ref-a', recette_id: 'chocolat_generique', generique_id: 'encas-a-emporter', familleProduitMarche: 'aliment',
      dateAchat: maintenant, provenance: { fondsId: 'fonds-1', referenceId: 'ref-b' } },
    { name: 'Barquette', type: 'carbonade_frites_marche', familleProduitMarche: 'aliment', dateAchat: maintenant }]) });
  let r = await un(db, "SELECT inventaire_consommer('Tom Tom', 0, '{\"name\":\"Rocher\",\"type\":\"ref-a\"}'::jsonb) r");
  let f = await fiche(db);
  assert.equal(r.sante.categorie, 'joueur_p10'); assert.equal(f.hp, 54); assert.equal(f.bonus_pa_differe, 2); assert.equal(f.pa, 10, 'plus de +1 PA immédiat');
  r = await un(db, "SELECT inventaire_consommer('Tom Tom', 0, '{\"name\":\"Barquette\",\"type\":\"carbonade_frites_marche\"}'::jsonb) r");
  f = await fiche(db);
  assert.equal(r.sante.categorie, 'plat'); assert.equal(f.hp, 58); assert.equal(f.bonus_pa_differe, 4);
});

test('dîner d’affaires : menu servi à chacun des deux convives, Moral et INF inchangés, champagne compté', async () => {
  const db = await base();
  await db.query(`INSERT INTO entreprises VALUES ('resto', '{"stockProduits":{"menu_gastronomique_1":1,"menu_gastronomique_2":5,"champagne_luthecia":4}}')`);
  await db.query(`INSERT INTO invitations_diner (inviteur, invite, country, city, building_id, room_id, statut, contrat_restaurant)
                  VALUES ('Tom Tom', 'Ana', 'republic', 'capitale', 'mairie-capitale', 'hall_mairie', 'acceptee', 'commerce_v1')`);
  await poser(db, { moral: 80 });
  const r = await un(db, "SELECT diner_commerce_servir_interne('Tom Tom', 1) r");
  assert.equal(r.ok, true, JSON.stringify(r));
  const t = await fiche(db), a = await fiche(db, 'Ana');
  assert.equal(t.hp, 50 + 8 + 2, 'menu ×1,5 (8) + 1er verre ×1,5 (2)'); assert.equal(t.bonus_pa_differe, 3); assert.equal(t.moral, 82);
  assert.equal(a.hp, 50 + 5 + 1); assert.equal(a.bonus_pa_differe, 3); assert.equal(a.moral, 52);
});

test('service d’étage : Républia = plat du jour ; Grand Hôtel = plat commandé ; marché de Krasnov ; Se nourrir = sandwich', async () => {
  const db = await base();
  const id = await un(db, "SELECT id r FROM personnages_donnees WHERE name='Tom Tom'");
  await db.query("INSERT INTO hotel_nuitees (personnage_id, country, city, building_id) VALUES ($1, 'republic', 'capitale', 'hotel-republica')", [id]);
  await db.query("INSERT INTO ordres_couts VALUES ('service_etage', 0, 150)");
  await poser(db, { current_building: 'hotel-republica', current_room: 'chambres' });
  let r = await un(db, 'SELECT hotel_service_etage_commander() r');
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.hp, 54); assert.equal(r.bonus_pa, 2); assert.equal(r.moral, 51);
  await poser(db, { hp: 50, bonus_pa_differe: 0 });
  r = await un(db, "SELECT service_etage_commander('00000000-0000-0000-0000-00000000000a', 'menu_gastronomique_2') r");
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.hp, 55); assert.equal(r.sante.categorie, 'menu');
  // Marché de Krasnov
  await poser(db, { hp: 50, bonus_pa_differe: 0, pa: 10, inventory: JSON.stringify([{ name: 'Goulash', stackKey: 'krasnov_goulash', qty: 1 },
    { name: 'Pain', stackKey: 'krasnov_pain_noir', qty: 1 }, { name: 'Fruits', stackKey: 'fruits_legumes', qty: 1 }]) });
  r = await un(db, "SELECT marche_krasnov_manger('00000000-0000-0000-0000-00000000000b', 'goulash') r");
  let f = await fiche(db);
  assert.equal(r.sante.categorie, 'plat'); assert.equal(f.hp, 54); assert.equal(f.bonus_pa_differe, 2); assert.equal(f.pa, 10, 'plus de +2 PA immédiats');
  r = await un(db, "SELECT marche_krasnov_manger('00000000-0000-0000-0000-00000000000c', 'pain_noir') r");
  f = await fiche(db);
  assert.equal(r.sante.categorie, 'sandwich'); assert.equal(f.hp, 57); assert.equal(f.bonus_pa_differe, 3);
  r = await un(db, "SELECT marche_krasnov_manger('00000000-0000-0000-0000-00000000000d', 'fruits_legumes') r");
  assert.equal(r.raison, 'repas_brut_deja_pris', 'un seul repas brut par nuit, inchangé');
  // Se nourrir (marché central de Luthécia)
  await poser(db, { hp: 50, bonus_pa_differe: 0, current_building: 'marche', current_room: 'marche_ext' });
  r = await un(db, 'SELECT sante_se_nourrir(0, 8) r');
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.hp, 53); assert.equal(r.bonus_pa_differe, 1);
  assert.equal((await un(db, 'SELECT sante_se_nourrir(0, 3) r')).raison, 'cout_non_declare');
  await poser(db, { current_building: 'mairie-capitale' });
  assert.equal((await un(db, 'SELECT sante_se_nourrir(0, 8) r')).raison, 'pas_sur_place');
});

test('soins : public +8 +1 PA une fois par jour, clinique +15 +2 PA, urgence +25, sans trace +15 (modulés par le Moral)', async () => {
  const db = await base();
  await db.query(`INSERT INTO batiments_etat (id, data) VALUES ('republic_capitale_dispensaire-public', '{"sante":{"stockMatieres":{"desinfectant":5}}}'),
    ('republic_capitale_clinique-privee', '{"sante":{"stockMatieres":{"desinfectant":5,"medicaments":5}}}')`);
  let r = await un(db, "SELECT recevoir_soin('Tom Tom','republic','capitale','dispensaire-public','public',25) r");
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.hp, 58); assert.equal(r.gain_hp, 8); assert.equal(r.pa, 11);
  assert.equal((await un(db, "SELECT recevoir_soin('Tom Tom','republic','capitale','dispensaire-public','public',25) r")).raison, 'deja_soigne_aujourdhui');
  await poser(db, { moral: 80 });
  r = await un(db, "SELECT recevoir_soin('Tom Tom','republic','capitale','clinique-privee','clinique',100) r");
  assert.equal(r.gain_hp, 23, '15 × 1,5 = 22,5 → 23'); assert.equal(r.hp, 81); assert.equal(r.pa, 13);
  await poser(db, { moral: 50, hp: 50, current_building: 'clinique-privee', current_room: 'reception_clinique' });
  r = await un(db, "SELECT ordre_generique_executer('soins_urgence', 0, 500) r");
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.hp, 75, 'jamais de majoration critique');
  await poser(db, { hp: 50 });
  await db.query("UPDATE ordres_generiques SET toujours_reussi = true WHERE fn = 'soins_discrets'");
  r = await un(db, "SELECT ordre_generique_executer('soins_discrets', 1, 800) r");
  assert.equal(r.hp, 65);
});
