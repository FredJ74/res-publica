'use strict';
// Inventaire en direct, déposer et ramasser avec quantité, capacité par personnage (Fred, 22/11/2026, fin de nuit,
// points 2, 3 et 4), migration 20261122200000, dans un vrai PostgreSQL local (PGlite) sur les définitions de production.
// Cas de Fred : Tom Tom dépose du bois, Arnie le ramasse ; ils dépassaient 100 unités ; le don entre eux.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261122200000_inventaire_direct_capacite.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', arnie: '00000000-0000-0000-0000-000000000002', mj: '00000000-0000-0000-0000-0000000000aa' };
const bois = q => ({ name: 'Bois', icon: 'ti-tree', type: 'matiere_premiere', stackable: true, stackKey: 'bois', qty: q });
const SALLE = 'soviet|ville_b|zone-production|foret_vue_2';

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec(lire(MIGRATION));
  await db.query('INSERT INTO personnages VALUES ($1,$2),($3,$4)', ['Tom Tom', U.tom, 'Arnie', U.arnie]);
  await db.query('INSERT INTO administrateurs VALUES ($1, true)', [U.mj]);
  const ins = 'INSERT INTO personnages_donnees (name, user_id, country, current_city, current_building, current_room, inventory) VALUES ($1,$2,$3,$4,$5,$6,$7)';
  await db.query(ins, ['Tom Tom', U.tom, 'soviet', 'ville_b', 'zone-production', 'foret_vue_2', JSON.stringify([bois(30), { name: 'Hache', type: 'outil' }])]);
  await db.query(ins, ['Arnie', U.arnie, 'soviet', 'ville_b', 'zone-production', 'foret_vue_2', JSON.stringify([bois(90), { name: 'Revolver .38', type: 'arme' }, { name: 'Peau', stackable: true, stackKey: 'peaux', qty: 4 }])]);
  return db;
}
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const inv = async (db, nom) => (await db.query('SELECT inventory FROM personnages_donnees WHERE name = $1', [nom])).rows[0].inventory;
const qte = (i, cle) => i.filter(o => o.stackKey === cle).reduce((n, o) => n + Number(o.qty || 1), 0);
const sol = async db => (await db.query('SELECT id, data FROM objets_abandonnes ORDER BY created_at, id')).rows.map(r => Object.assign(JSON.parse(r.data), { _id: r.id }));
const version = async (db, table, col, cle) => Number(((await db.query(`SELECT version FROM ${table} WHERE ${col} = $1`, [cle])).rows[0] || {}).version || 0);
const deposer = (db, qui, q, salle = ['ville_b', 'zone-production', 'foret_vue_2']) =>
  un(db, "SELECT inventaire_abandonner($1, 0, $2, 'soviet', $3, $4, $5, $6) r", [qui, JSON.stringify({ name: 'Bois', type: 'matiere_premiere', stackKey: 'bois' }), ...salle, q]);

test('déposer 10 puis 5 bois : une seule pile de 15 au sol, le stock de Tom Tom baisse, la pièce et Tom Tom sont prévenus', async () => {
  const db = await base(); await en(db, U.tom);
  const vSalle = await version(db, 'salles_signaux', 'salle', SALLE), vTom = await version(db, 'personnages_signaux', 'personnage', 'Tom Tom');
  const r = await deposer(db, 'Tom Tom', 10);
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(r.qte, 10); assert.equal(r.sol_qte, 10);
  assert.equal(qte(r.inventory, 'bois'), 20, 'inventaire rendu = inventaire en base');
  assert.ok(Number.isSafeInteger(r.revision));
  assert.equal(qte(await inv(db, 'Tom Tom'), 'bois'), 20);
  const r2 = await deposer(db, 'Tom Tom', 5);
  assert.equal(r2.sol_qte, 15); assert.equal(r2.objet_id, r.objet_id, 'la pile grossit');
  const s = await sol(db); assert.equal(s.length, 1); assert.equal(s[0].qty, 15); assert.equal(s[0].name, 'Bois');
  assert.ok(await version(db, 'salles_signaux', 'salle', SALLE) > vSalle, 'la pièce relit le sol');
  assert.ok(await version(db, 'personnages_signaux', 'personnage', 'Tom Tom') > vTom, 'Tom Tom relit son inventaire');
  assert.equal((await deposer(db, 'Tom Tom', 21)).raison, 'quantite_insuffisante', 'jamais plus que ce qu’il possède');
});

test('déposer : le lieu est celui du serveur (écran en retard refusé, rue refusée)', async () => {
  const db = await base(); await en(db, U.tom);
  assert.equal((await deposer(db, 'Tom Tom', 1, ['ville_b', 'zone-production', 'foret_vue_3'])).raison, 'pas_sur_place');
  await db.query("UPDATE personnages_donnees SET current_building = NULL, current_room = NULL, current_street = 'krasnov-place-ours' WHERE name = 'Tom Tom'");
  assert.equal((await deposer(db, 'Tom Tom', 1)).raison, 'lieu_invalide');
});

test('ramasser : plafonné à la pile et à la place libre, le reste demeure au sol ; plus jamais au-delà de 100', async () => {
  const db = await base(); await en(db, U.tom); await deposer(db, 'Tom Tom', 20);
  const id = (await sol(db))[0]._id;
  await en(db, U.arnie);                         // Arnie porte 90 bois + 1 revolver + 4 peaux = 95 : place 5
  const trop = await un(db, 'SELECT objet_abandonne_ramasser($1, 12) r', [id]);
  assert.equal(trop.ok, false); assert.equal(trop.raison, 'place_insuffisante'); assert.equal(trop.place, 5); assert.equal(trop.dispo, 20);
  assert.equal((await un(db, 'SELECT objet_abandonne_ramasser($1, 21) r', [id])).raison, 'quantite_invalide');
  const vSalle = await version(db, 'salles_signaux', 'salle', SALLE);
  const ok = await un(db, 'SELECT objet_abandonne_ramasser($1, 5) r', [id]);
  assert.equal(ok.ok, true, JSON.stringify(ok)); assert.equal(ok.qte, 5); assert.equal(ok.reste, 15); assert.equal(ok.place, 0);
  assert.equal(qte(ok.inventory, 'bois'), 95);
  assert.equal(ok.inventory.filter(o => o.stackKey === 'bois').length, 1, 'fusion dans la pile existante');
  assert.equal(ok.inventory.find(o => o.stackKey === 'bois').name, 'Bois', 'l’objet garde son nom');
  assert.equal((await sol(db))[0].qty, 15);
  assert.ok(await version(db, 'salles_signaux', 'salle', SALLE) > vSalle, 'Tom Tom voit la pile diminuer aussitôt');
  const plein = await un(db, 'SELECT objet_abandonne_ramasser($1, 1) r', [id]);
  assert.equal(plein.raison, 'inventaire_plein'); assert.equal(plein.place, 0);
  assert.equal((await un(db, 'SELECT objet_abandonne_ramasser($1) r', [id])).raison, 'inventaire_plein', 'forme historique : refus, plus de surcharge');
  assert.equal(qte(await inv(db, 'Arnie'), 'bois'), 95);
});

test('capacité propre au personnage : réglée par un MJ seulement, prise par le ramassage et l’ancienne forme', async () => {
  const db = await base(); await en(db, U.tom); await deposer(db, 'Tom Tom', 20);
  const id = (await sol(db))[0]._id;
  await en(db, U.arnie);
  await assert.rejects(db.query('SELECT admin_inventaire_capacite_fixer($1, 150) r', ['Arnie']), /autorite_administrateur_requise/);
  await en(db, U.mj);
  const vArnie = await version(db, 'personnages_signaux', 'personnage', 'Arnie');
  assert.equal((await un(db, 'SELECT admin_inventaire_capacite_fixer($1, 0) r', ['Arnie'])).raison, 'capacite_invalide');
  const f = await un(db, 'SELECT admin_inventaire_capacite_fixer($1, 120) r', ['Arnie']);
  assert.deepEqual([f.ok, f.avant, f.capacite, f.porte], [true, 100, 120, 95]);
  assert.equal((await un(db, 'SELECT admin_inventaire_capacite_lire($1) r', ['Arnie'])).capacite, 120);
  assert.ok(await version(db, 'personnages_signaux', 'personnage', 'Arnie') > vArnie, 'Arnie voit sa nouvelle capacité aussitôt');
  assert.equal(Number((await db.query("SELECT count(*) n FROM admin_journal WHERE action = 'inventaire_capacite_fixer'")).rows[0].n), 1);
  await en(db, U.arnie);
  assert.equal(await un(db, 'SELECT inventaire_place_restante(inventory) r FROM personnages_donnees WHERE name = $1', ['Arnie']), 25, 'forme à un argument = capacité du joueur connecté');
  const r = await un(db, 'SELECT objet_abandonne_ramasser($1) r', [id]);
  assert.equal(r.ok, true); assert.equal(r.qte, 20); assert.equal(r.place, 5);
  assert.equal((await sol(db)).length, 0, 'pile entièrement ramassée');
  const etat = await un(db, 'SELECT inventaire_reception_etat($1) r', ['Arnie']);
  assert.equal(etat.capacite, 120); assert.equal(etat.place, 5);
  // Dépôt serveur commun (achat, coupe, butin) : plafonné à la capacité du personnage servi.
  const dep = await un(db, 'SELECT inventaire_deposer_interne($1, $2) r', ['Arnie', JSON.stringify(bois(40))]);
  assert.equal(dep.ok, true); assert.equal(dep.qte, 5);
  const dep2 = await un(db, 'SELECT inventaire_deposer_interne($1, $2) r', ['Tom Tom', JSON.stringify(bois(500))]);
  assert.equal(dep2.qte, 100 - 11, 'Tom Tom (capacité 100, porte 10 bois et 1 hache) : 89 bois de plus');
});

test('donner : chef → membre et membre → chef ; jamais au-delà de la place du destinataire, dons en route compris ; destinataire prévenu', async () => {
  const db = await base(); await en(db, U.tom);
  const sig = { name: 'Bois', type: 'matiere_premiere', stackKey: 'bois' };
  const vArnie = await version(db, 'personnages_signaux', 'personnage', 'Arnie');
  const trop = await un(db, 'SELECT inventaire_donner($1, $2, 0, $3, 8) r', ['Tom Tom', 'Arnie', JSON.stringify(sig)]);
  assert.equal(trop.ok, false); assert.equal(trop.raison, 'destinataire_plein'); assert.equal(trop.place, 5); assert.equal(trop.destinataire, 'Arnie');
  assert.equal(qte(await inv(db, 'Tom Tom'), 'bois'), 30, 'rien n’a bougé');
  const ok = await un(db, 'SELECT inventaire_donner($1, $2, 0, $3, 3) r', ['Tom Tom', 'Arnie', JSON.stringify(sig)]);
  assert.equal(ok.ok, true); assert.equal(qte(ok.inventory, 'bois'), 27); assert.ok(Number.isSafeInteger(ok.revision));
  assert.ok(await version(db, 'personnages_signaux', 'personnage', 'Arnie') > vArnie, 'Arnie reçoit sans attendre');
  const encore = await un(db, 'SELECT inventaire_donner($1, $2, 0, $3, 3) r', ['Tom Tom', 'Arnie', JSON.stringify(sig)]);
  assert.equal(encore.raison, 'destinataire_plein'); assert.equal(encore.place, 2, 'les 3 bois en route comptent');
  // Membre → chef : Arnie donne son revolver à Tom Tom.
  await en(db, U.arnie);
  const r = await un(db, 'SELECT inventaire_donner($1, $2, 1, $3, 1) r', ['Arnie', 'Tom Tom', JSON.stringify({ name: 'Revolver .38', type: 'arme', stackKey: '' })]);
  assert.equal(r.ok, true, JSON.stringify(r));
  assert.equal(Number((await db.query("SELECT count(*) n FROM objets_recus WHERE destinataire = 'Tom Tom'")).rows[0].n), 1);
});

test('migration rejouable ; raccords posés une seule fois', async () => {
  const db = await base();
  await db.exec(lire(MIGRATION));
  const d = (await db.query("SELECT pg_get_functiondef('public.inventaire_deposer_interne(text,jsonb,boolean)'::regprocedure) d")).rows[0].d;
  assert.equal(d.split('inventaire_capacite_v1').length, 2);
  assert.match(d, /inventaire_place_restante\(v_inv, public\.inventaire_capacite\(p_nom\)\)/);
  const n = Number((await db.query("SELECT count(*) n FROM pg_trigger WHERE tgname IN ('zz_objets_recus_signaux', 'zz_objets_abandonnes_signaux')")).rows[0].n);
  assert.equal(n, 2);
});
