'use strict';
// Santé — médecin de terrain, « Montrer un objet », vues en plein air (Fred, 22/11/2026, GAME-DESIGN-SANTE-20261122.md,
// points 12, 14, 17, 22) : migration 20261122234000 dans un vrai PostgreSQL local (PGlite), après le socle 20261122230000.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const SOCLE = 'migrations/20261122230000_sante_socle.sql', MIGRATION = 'migrations/20261122234000_medecin_montrer.sql';
const U = { doc: '00000000-0000-0000-0000-000000000001', arnie: '00000000-0000-0000-0000-000000000002', zoe: '00000000-0000-0000-0000-000000000003' };
const TROUSSE = { id: 'mil-1', name: 'Trousse de premiers secours', type: 'soin', produitMilitaire: 'trousse_secours', usageUnique: true };
const LETTRE = { id: 'l-1', name: 'Lettre scellée', desc: 'Une lettre au sceau du Tsar.', imageUrl: 'images/lettre.png', icon: 'ti-mail' };

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/medecin-montrer-pglite-socle.sql.txt'));
  for (const [n, u] of [['Docteur Vlad', U.doc], ['Arnie', U.arnie], ['Zoé', U.zoe]]) await db.query('INSERT INTO personnages VALUES ($1,$2)', [n, u]);
  const ici = { country: 'soviet', city: 'ville_b', b: 'hopital-krasnov', r: 'accueil' };
  await db.query(`INSERT INTO personnages_donnees (name, user_id, career, country, current_city, current_building, current_room, pa, hp, moral, liquide, inventory)
    VALUES ('Docteur Vlad', $1, 'doctor', $2, $3, $4, $5, 10, 90, 50, 0, $6),
           ('Arnie', $7, 'worker', $2, $3, $4, $5, 20, 40, 50, 30, $8),
           ('Zoé', $9, 'worker', $2, $3, 'bar', 'salle', 20, 60, 50, 500, '[]')`,
    [U.doc, ici.country, ici.city, ici.b, ici.r, JSON.stringify([TROUSSE, LETTRE]), U.arnie, JSON.stringify([LETTRE]), U.zoe]);
  await db.query("INSERT INTO comptes_bancaires VALUES ('cb-arnie', 'Arnie', 'nationale', 100)");
  await db.query("INSERT INTO personnages_maladies (nom, cle) VALUES ('Arnie', 'grippe'), ('Arnie', 'gueule_de_bois')");
  await db.exec(lire(SOCLE));
  await db.exec(lire(MIGRATION));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const fiche = (db, n) => db.query('SELECT pa, hp, liquide, inventory FROM personnages_donnees WHERE name = $1', [n]).then(r => r.rows[0]);
const evenements = async (db, uid) => { await en(db, uid); return (await un(db, 'SELECT personnage_evenements_lire() r')).evenements; };

test('la migration se rejoue, ne touche aucune Santé et déclare les deux tarifs', async () => {
  const db = await base();
  await db.exec(lire(MIGRATION));
  assert.equal((await fiche(db, 'Arnie')).hp, 40);
  const t = (await db.query("SELECT fn, pa, cost FROM ordres_couts WHERE fn LIKE 'medecin_%' ORDER BY fn")).rows;
  assert.deepEqual(t, [{ fn: 'medecin_diagnostiquer', pa: 1, cost: 0 }, { fn: 'medecin_soigner', pa: 2, cost: 0 }]);
  for (const m of ['plein_air_inspecter_v1', 'plein_air_desinstaller_lire_v1', 'plein_air_desinstaller_v1'])
    assert.equal(Number(await un(db, "SELECT count(*) r FROM pg_proc WHERE prosrc LIKE '%' || $1 || '%'", [m])), 1, m);
});

test('diagnostic : proposition, accord, paiement serveur, Santé et maladies au médecin et au patient seulement', async () => {
  const db = await base();
  await en(db, U.arnie);
  assert.equal((await un(db, "SELECT medecin_proposer('Docteur Vlad', 'diagnostic', 10) r")).raison, 'reserve_aux_medecins');
  await en(db, U.doc);
  assert.equal((await un(db, "SELECT medecin_proposer('Zoé', 'diagnostic', 10) r")).raison, 'pas_au_meme_endroit');
  const p = await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 50) r");
  assert.equal(p.ok, true); assert.equal(p.monnaie, 'PSK');
  assert.equal((await fiche(db, 'Docteur Vlad')).pa, 10, 'rien de prélevé à la proposition');
  assert.equal((await fiche(db, 'Arnie')).liquide, 30);
  const evP = await evenements(db, U.arnie);
  assert.equal(evP.length, 1); assert.equal(evP[0].cle, 'medecin_proposition');
  assert.match(evP[0].texte, /Docteur Vlad vous propose un diagnostic pour 50 PSK/);
  assert.equal(evP[0].params.id, p.id);
  assert.equal((await un(db, 'SELECT medecin_propositions_lire() r')).propositions.length, 1);
  const r = await un(db, 'SELECT medecin_repondre($1, true) r', [p.id]);
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(Number(r.paye), 50);
  assert.equal(r.diagnostic.sante, 40);
  assert.deepEqual(r.diagnostic.maladies.map(m => [m.nom, m.medicament_nom]), [['Grippe', 'Antigrippal'], ['Gueule de bois', 'Aspirine']]);
  const a = await fiche(db, 'Arnie'), d = await fiche(db, 'Docteur Vlad');
  assert.equal(a.liquide, 0, '30 en liquide puis 20 en banque');
  assert.equal(Number(await un(db, "SELECT solde r FROM comptes_bancaires WHERE id='cb-arnie'")), 80);
  assert.equal(d.liquide, 50); assert.equal(d.pa, 9, '1 PA de diagnostic'); assert.equal(a.hp, 40, 'un diagnostic ne soigne pas');
  const evPatient = await evenements(db, U.arnie), evMedecin = await evenements(db, U.doc);
  assert.equal(evPatient[0].cle, 'medecin_diagnostic');
  assert.match(evPatient[0].texte, /Santé 40\. Maladies en cours : Grippe \(se soigne avec : Antigrippal\) ; Gueule de bois \(se soigne avec : Aspirine\)\./);
  assert.equal(evMedecin[0].cle, 'medecin_diagnostic_resultat');
  assert.match(evMedecin[0].texte, /Votre diagnostic de Arnie \(50 PSK, −1 PA\) : Santé 40\./);
  assert.equal((await evenements(db, U.zoe)).length, 0, 'personne d’autre ne voit le nom des maladies');
  await en(db, U.arnie);
  assert.equal((await un(db, 'SELECT medecin_repondre($1, true) r', [p.id])).raison, 'proposition_close', 'pas deux fois');
});

test('soin : trousse consommée, +12 Santé modulé par le Moral du patient, 2 PA au médecin', async () => {
  const db = await base();
  await en(db, U.doc);
  const etat = await un(db, 'SELECT medecin_etat() r');
  assert.equal(etat.medecin, true); assert.equal(etat.trousses, 1); assert.equal(etat.pa_soin, 2); assert.equal(etat.sante_soin, 12);
  const p = await un(db, "SELECT medecin_proposer('Arnie', 'soin', 0) r");
  await en(db, U.arnie);
  const r = await un(db, 'SELECT medecin_repondre($1, true) r', [p.id]);
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.soin.gain, 12);
  const d = await fiche(db, 'Docteur Vlad');
  assert.equal((await fiche(db, 'Arnie')).hp, 52); assert.equal(d.pa, 8);
  assert.deepEqual(d.inventory.map(o => o.name), ['Lettre scellée'], 'la trousse a quitté l’inventaire');
  assert.match((await evenements(db, U.arnie)).find(e => e.cle === 'medecin_soin').texte, /vous a soigné \(gratuitement\) : Santé 40 → 52 \(\+12\)/);
  // Moral haut : ×1,5 ; Moral bas : ×0,5.
  await db.query(`UPDATE personnages_donnees SET inventory = $1 WHERE name = 'Docteur Vlad'`, [JSON.stringify([{ ...TROUSSE, qty: 2, stackable: true }])]);
  for (const [moral, gain] of [[80, 18], [20, 6]]) {
    await db.query("UPDATE personnages_donnees SET moral = $1, hp = 40 WHERE name = 'Arnie'", [moral]);
    await en(db, U.doc); const q = await un(db, "SELECT medecin_proposer('Arnie', 'soin', 0) r");
    await en(db, U.arnie); const s = await un(db, 'SELECT medecin_repondre($1, true) r', [q.id]);
    assert.equal(s.soin.gain, gain, 'Moral ' + moral);
  }
  assert.deepEqual((await fiche(db, 'Docteur Vlad')).inventory, [], 'une pile de deux trousses s’épuise une à une');
  await en(db, U.doc);
  assert.equal((await un(db, "SELECT medecin_proposer('Arnie', 'soin', 0) r")).raison, 'aucune_trousse');
});

test('refus, fonds insuffisants, départ du médecin : aucun prélèvement', async () => {
  const db = await base();
  await en(db, U.doc);
  const p1 = await un(db, "SELECT medecin_proposer('Arnie', 'soin', 40) r");
  await en(db, U.arnie);
  assert.equal((await un(db, 'SELECT medecin_repondre($1, false) r', [p1.id])).statut, 'refusee');
  let a = await fiche(db, 'Arnie'), d = await fiche(db, 'Docteur Vlad');
  assert.deepEqual([a.liquide, a.hp, d.pa, d.inventory.length], [30, 40, 10, 2]);
  assert.match((await evenements(db, U.doc)).find(e => e.cle === 'medecin_refus').texte, /Arnie refuse votre proposition de soins/);
  await en(db, U.doc);
  const p2 = await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 500) r");
  await en(db, U.arnie);
  assert.equal((await un(db, 'SELECT medecin_repondre($1, true) r', [p2.id])).raison, 'fonds_insuffisants');
  await en(db, U.doc);
  const p3 = await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 10) r");
  await db.query("UPDATE personnages_donnees SET current_building = 'bar', current_room = 'salle' WHERE name = 'Docteur Vlad'");
  await en(db, U.arnie);
  assert.equal((await un(db, 'SELECT medecin_repondre($1, true) r', [p3.id])).raison, 'pas_au_meme_endroit');
  a = await fiche(db, 'Arnie'); d = await fiche(db, 'Docteur Vlad');
  assert.deepEqual([a.liquide, d.liquide, d.pa], [30, 0, 10]);
  assert.equal(Number(await un(db, "SELECT solde r FROM comptes_bancaires WHERE id='cb-arnie'")), 100);
  await en(db, U.doc);
  assert.equal((await un(db, "SELECT medecin_proposer('Arnie', 'soin', -1) r")).raison, 'tarif_invalide');
  assert.equal((await un(db, "SELECT medecin_proposer('Docteur Vlad', 'soin', 0) r")).raison, 'patient_invalide');
});

test('présence : rue, forêt et cachette (visible pour son groupe seulement)', async () => {
  const db = await base();
  await db.query("UPDATE personnages_donnees SET current_building = 'zone-production', current_room = 'foret_vue_3' WHERE name IN ('Docteur Vlad', 'Arnie')");
  await en(db, U.doc);
  assert.equal((await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 0) r")).ok, true, 'en forêt');
  await db.query("UPDATE personnages_donnees SET current_building = NULL, current_room = NULL, current_street = 'krasnov-place-ours' WHERE name IN ('Docteur Vlad', 'Arnie')");
  assert.equal((await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 0) r")).ok, true, 'dans la rue');
  await db.query("INSERT INTO caches_pj VALUES ('Arnie')");
  assert.equal((await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 0) r")).raison, 'pas_au_meme_endroit');
  await db.query("INSERT INTO groupes_pj_adhesions VALUES ('Arnie', 'Docteur Vlad')");
  assert.equal((await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 0) r")).ok, true, 'membre de mon groupe');
});

test('montrer un objet : nom, image et description à l’autre ; rien ne change de main ; une ligne au journal des deux', async () => {
  const db = await base();
  await en(db, U.arnie);
  assert.equal((await un(db, "SELECT objet_montrer('Zoé', 0, 'Lettre scellée') r")).raison, 'pas_au_meme_endroit');
  const r = await un(db, "SELECT objet_montrer('Docteur Vlad', 0, 'Lettre scellée') r");
  assert.equal(r.ok, true);
  assert.equal((await fiche(db, 'Arnie')).inventory.length, 1); assert.equal((await fiche(db, 'Docteur Vlad')).inventory.length, 2);
  const evA = await evenements(db, U.arnie), evD = await evenements(db, U.doc);
  assert.equal(evA[0].cle, 'objet_montre_envoye'); assert.equal(evA[0].texte, 'Vous montrez « Lettre scellée » à Docteur Vlad.');
  assert.equal(evD[0].cle, 'objet_montre'); assert.equal(evD[0].texte, 'Arnie vous montre : Lettre scellée.');
  assert.deepEqual([evD[0].params.nom, evD[0].params.image, evD[0].params.desc], ['Lettre scellée', 'images/lettre.png', 'Une lettre au sceau du Tsar.']);
  await en(db, U.arnie);
  assert.equal((await un(db, "SELECT objet_montrer('Docteur Vlad', 5, 'Couronne') r")).raison, 'objet_introuvable');
  await db.query("INSERT INTO masques_pj VALUES ('Arnie')");
  await un(db, "SELECT objet_montrer('Docteur Vlad', 0, 'Lettre scellée') r");
  assert.equal((await evenements(db, U.doc))[0].texte, 'Un personnage masqué vous montre : Lettre scellée.');
});

test('vues en plein air : inspecter et désinstaller refusés en forêt, permis dans une pièce ; paliers des jauges', async () => {
  const db = await base();
  await en(db, U.doc);
  assert.equal((await un(db, 'SELECT inspecter_piece() r')).ok, true, 'pièce ordinaire');
  await db.query("UPDATE personnages_donnees SET current_building = 'zone-production', current_room = 'foret_vue_1' WHERE name = 'Docteur Vlad'");
  assert.equal((await un(db, 'SELECT inspecter_piece() r')).raison, 'plein_air');
  assert.equal((await un(db, 'SELECT desinstaller_lire() r')).raison, 'plein_air');
  assert.equal((await un(db, "SELECT desinstaller_materiel(gen_random_uuid(), gen_random_uuid()) r")).raison, 'plein_air');
  assert.equal((await fiche(db, 'Docteur Vlad')).pa, 9, 'aucun PA pris par le refus');
  for (const [b, r, attendu] of [['port-sainte-marie', 'quai_nord', true], ['ferme-krasnov', 'cour_ferme', true], ['stade', 'terrain', true],
                                  ['parc-botanique-national', 'serre', true], ['ferme-krasnov', 'etable', false], ['stade', 'vestiaires', false]])
    assert.equal(await un(db, "SELECT piece_plein_air_interne('republic', 'capitale', $1, $2) r", [b, r]), attendu, b + '/' + r);
  const pal = await un(db, 'SELECT sante_paliers_lire() r');
  assert.deepEqual([Number(pal.moral_seuil_haut), Number(pal.moral_seuil_bas), Number(pal.moral_mult_haut)], [75, 25, 1.5]);
});
