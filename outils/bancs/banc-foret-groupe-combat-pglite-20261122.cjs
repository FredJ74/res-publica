'use strict';
// Forêt de Krasnov, remontées du test de Fred (22/11/2026, fin de nuit, points 5 à 7), migration 20261122210000, dans un vrai
// PostgreSQL local (PGlite). Les fonctions communes du combat sont des copies de production (fixtures), la migration y applique
// ses remplacements contrôlés comme elle le fera en production :
//  - groupe de deux en forêt : coupe du chef (12 bois pour lui seul), coupe du membre (pour lui, jamais de bête) ;
//  - meute de trois loups (8 PA, Loup 1/2/3), combat lancé par le chef où les DEUX frappent, morsure au tiers ;
//  - butin au chef une seule fois (selon les loups abattus), journal du membre (rencontre, issue, butin) ;
//  - rapport par round : une ligne par combattant, chef d'abord, loups nommés, jamais « soldats ».
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }
const UID = { 'Tom Tom': '00000000-0000-0000-0000-000000000001', Arnie: '00000000-0000-0000-0000-000000000002' };
const MIGRATION = 'migrations/20261122210000_foret_groupe_combat_meute.sql';

async function base({ piece = 'foret_vue_3', vol = 30 } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/foret-combat-socle.sql.txt'));
  await db.exec(lire('outils/bancs/fixtures/foret-combat-ouverture.sql.txt'));
  await db.exec(lire(MIGRATION));
  const armes = { 'Tom Tom': [{ name: 'Couteau de poche', type: 'arme' }], Arnie: [{ name: 'Revolver .38', type: 'arme' }] };
  for (const [n, u] of Object.entries(UID)) {
    await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
    await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, pa, stats, inventory)
      VALUES ($1, 'soviet', 'ville_b', 'zone-production', $2, 30, $3, $4)`, [n, piece, JSON.stringify({ VOL: vol, PER: 10, DUP: 10 }), JSON.stringify(armes[n])]);
  }
  await db.query("INSERT INTO groupes_pj_adhesions VALUES ('Arnie', 'Tom Tom')");
  return db;
}
async function appel(db, qui, sql, args = []) {
  await db.query("SELECT set_config('test.uid', $1, false)", [UID[qui]]);
  return (await db.query(sql, args)).rows[0].r;
}
const couper = (db, qui) => appel(db, qui, 'SELECT sovarka_foret_couper(gen_random_uuid()) r');
const qte = async (db, qui, cle) => Number((await db.query(
  "SELECT coalesce(sum((i->>'qty')::int), 0) n FROM personnages_donnees, jsonb_array_elements(inventory) i WHERE name = $1 AND i->>'stackKey' = $2", [qui, cle])).rows[0].n);
const journal = async (db, qui) => (await appel(db, qui, 'SELECT sovarka_foret_journal_lire() r')).evenements;
const meute = async db => (await db.query("SELECT sovarka_foret_faune_creer_interne('Tom Tom', 3, 'meute') r")).rows[0].r;

test('migration rejouable ; chaque raccord commun posé une seule fois', async () => {
  const db = await base();
  await db.exec(lire(MIGRATION));
  const fn = async (sig, marque) => {
    const d = (await db.query(`SELECT pg_get_functiondef('${sig}'::regprocedure) d`)).rows[0].d;
    return d.split(marque).length - 1;
  };
  assert.equal(await fn('militaire_bataille_rapport(bigint,text,text,integer,jsonb,integer,integer)', 'combat_rapport_lignes_v1'), 1);
  assert.equal(await fn('militaire_bataille_appliquer(bigint,jsonb,integer)', 'foret_morsure_v1'), 1);
  assert.equal(await fn('militaire_bataille_combattants(bigint,text)', 'foret_meute_griffes_v1'), 1);
  assert.equal(await fn('militaire_bataille_combattants(bigint,text)', 'combat_mode_ouverture_v1'), 1, 'marque d’installation conservée');
  assert.equal(await fn('combat_ouvrir_interne(text,text,uuid)', 'foret_meute_engagements_v1'), 1);
  assert.equal(await fn('combat_finaliser_interne(bigint)', 'foret_meute_issue_v1'), 1);
  assert.equal(await fn('militaire_bataille_etat(bigint)', 'foret_meute_nom_v1'), 1);
  assert.equal(await fn('sovarka_foret_aller(uuid,text)', 'foret_groupe_membres_v1'), 1);
  assert.equal(await fn('sovarka_foret_rencontre(uuid,text)', 'foret_meute_retrait_v1'), 2);
  assert.equal(await fn('sovarka_foret_lire()', 'foret_groupe_membres_v1'), 1);
});

test('coupe du chef : 12 bois pour lui seul, rien pour le membre ; coupe du membre : pour lui, avec ses PA', async () => {
  const db = await base({ piece: 'foret_vue_1' });
  const c = await couper(db, 'Tom Tom');
  assert.equal(c.ok, true); assert.equal(c.quantite, 12);
  assert.equal(await qte(db, 'Tom Tom', 'bois'), 12, 'aucun doublement');
  assert.equal(await qte(db, 'Arnie', 'bois'), 0);
  const m = await couper(db, 'Arnie');
  assert.equal(m.ok, true, 'le membre n’est plus refusé : ' + m.raison); assert.equal(m.membre, true);
  assert.equal(await qte(db, 'Arnie', 'bois'), 12);
  assert.equal(await qte(db, 'Tom Tom', 'bois'), 12);
  const pa = (await db.query('SELECT name, pa FROM personnages_donnees ORDER BY name')).rows;
  assert.deepEqual(pa, [{ name: 'Arnie', pa: 29 }, { name: 'Tom Tom', pa: 29 }]);
});

test('le membre ne fait jamais surgir de bête ni Olga (fausses alertes permises) ; ses coupes repartent avec le groupe', async () => {
  const db = await base({ piece: 'foret_vue_3' });
  let alertes = 0;
  for (let i = 0; i < 40; i++) {
    await db.exec("DELETE FROM sovarka_foret_visites; UPDATE personnages_donnees SET pa = 30, inventory = '[]' WHERE name = 'Arnie'");
    await db.query("UPDATE personnages_donnees SET current_room = $1 WHERE name = 'Arnie'", [i % 2 ? 'foret_vue_3' : 'foret_vue_4']);
    const a = await couper(db, 'Arnie'), b = await couper(db, 'Arnie');
    assert.equal(a.ok && b.ok, true);
    assert.equal(b.rencontre, undefined, 'jamais de rencontre pour un membre');
    assert.equal(a.quantite + b.quantite, 24);
    if (b.fausse_alerte) alertes++;
  }
  assert.equal(Number((await db.query('SELECT count(*) n FROM sovarka_foret_rencontres')).rows[0].n), 0);
  assert.equal(Number((await db.query('SELECT count(*) n FROM pnj_membres')).rows[0].n), 0);
  assert.ok(alertes > 5 && alertes < 35, 'fausses alertes : ' + alertes);
  // Le chef emmène le groupe ailleurs : les coupes du membre repartent à zéro.
  await db.query("UPDATE personnages_donnees SET current_room = 'foret_clairiere'");
  await appel(db, 'Tom Tom', "SELECT sovarka_foret_aller(gen_random_uuid(), 'enfoncer') r");
  assert.equal(Number((await db.query("SELECT count(*) n FROM sovarka_foret_visites WHERE bucheron = 'Arnie'")).rows[0].n), 0);
});

test('seconde coupe du chef au ravin : une rencontre, et le membre en reçoit le récit ; fausse alerte et Olga aussi', async () => {
  const db = await base({ piece: 'foret_vue_3' });
  await couper(db, 'Tom Tom');
  const r = await couper(db, 'Tom Tom');
  assert.equal(r.rencontre, 'attaque');
  const j = await journal(db, 'Arnie');
  assert.equal(j.length, 1); assert.equal(j[0].cle, 'rencontre'); assert.equal(j[0].params.chef, 'Tom Tom'); assert.equal(j[0].params.nom, r.nom);
  assert.deepEqual(await journal(db, 'Arnie'), [], 'lu une seule fois');
  assert.deepEqual(await journal(db, 'Tom Tom'), [], 'le chef écrit son propre journal à l’écran');
  assert.equal((await couper(db, 'Arnie')).raison, 'rencontre_en_cours', 'la bête est là : le membre ne coupe pas pendant la rencontre');
  // Olga (vue 4) : le membre présent est nourri et le lit dans son journal.
  const o = await base({ piece: 'foret_vue_4' });
  await couper(o, 'Tom Tom');
  const ol = await couper(o, 'Tom Tom');
  assert.equal(ol.rencontre, 'olga'); assert.deepEqual(ol.nourris, ['Arnie', 'Tom Tom']);
  const jo = await journal(o, 'Arnie');
  assert.equal(jo[0].cle, 'olga'); assert.deepEqual(jo[0].params.nourris, ['Arnie', 'Tom Tom']);
  // Fausse alerte du chef (vue 1) : relayée au membre.
  const f = await base({ piece: 'foret_vue_1' });
  let vu = false;
  for (let i = 0; i < 30 && !vu; i++) {
    await f.exec("DELETE FROM sovarka_foret_visites; UPDATE personnages_donnees SET pa = 30, inventory = '[]'");
    await couper(f, 'Tom Tom');
    if ((await couper(f, 'Tom Tom')).fausse_alerte) vu = (await journal(f, 'Arnie')).some(e => e.cle === 'fausse_alerte' && e.params.texte);
  }
  assert.ok(vu, 'fausse alerte du chef relayée');
});

test('la meute = trois loups séparés de 8 PA ; morsure au tiers ; le combat engage les deux joueurs et les trois loups', async () => {
  const db = await base();
  const c = await meute(db);
  assert.equal(c.nom, 'Meute de 3 loups'); assert.deepEqual(c.combattants, ['Loup 1', 'Loup 2', 'Loup 3']);
  const loups = (await db.query("SELECT id, nom, pa, room_id FROM pnj_membres ORDER BY id")).rows;
  assert.deepEqual(loups.map(l => [l.nom, l.pa, l.room_id]), [['Loup 1', 8, 'foret_vue_3'], ['Loup 2', 8, 'foret_vue_3'], ['Loup 3', 8, 'foret_vue_3']]);
  assert.equal((await appel(db, 'Arnie', "SELECT combat_ouvrir($1, 'arme', gen_random_uuid()) r", [c.pnj])).raison, 'chef_de_groupe_requis');
  const o = await appel(db, 'Tom Tom', "SELECT combat_ouvrir($1, 'arme', gen_random_uuid()) r", [c.pnj]);
  assert.equal(o.ok, true, JSON.stringify(o));
  const eng = (await db.query('SELECT camp, personnage, pnj_id, groupe_id FROM batailles_engagements WHERE bataille_id = $1 ORDER BY id', [o.bataille])).rows;
  assert.deepEqual(eng.filter(e => e.camp === 'acteur').map(e => e.personnage).sort(), ['Arnie', 'Tom Tom']);
  const def = eng.filter(e => e.camp === 'defenseur');
  assert.equal(def.length, 3); assert.equal(new Set(def.map(e => e.groupe_id)).size, 3, 'un groupe par loup');
  // Les deux joueurs frappent, chacun avec son arme ; chaque loup frappe une fois, cible tirée pour lui seul.
  const att = (await db.query("SELECT militaire_bataille_actions($1, 'acteur', 1) r", [o.bataille])).rows[0].r;
  assert.deepEqual(att.map(a => a.att_nom).sort(), ['Arnie', 'Tom Tom']);
  assert.equal(att.find(a => a.att_nom === 'Arnie').mode, 'feu'); assert.equal(att.find(a => a.att_nom === 'Arnie').att_arme, 'Revolver .38');
  assert.equal(att.find(a => a.att_nom === 'Tom Tom').att_arme, 'Couteau de poche');
  const mor = (await db.query("SELECT militaire_bataille_actions($1, 'defenseur', 1) r", [o.bataille])).rows[0].r;
  assert.deepEqual(mor.map(a => a.att_nom).sort(), ['Loup 1', 'Loup 2', 'Loup 3']);
  assert.ok(mor.every(a => a.att_bonus === 8), 'griffes de la meute pour chaque loup');
  // Morsure : un coup qui aurait pris 27 PA n'en prend que 9 ; un joueur n'est pas concerné.
  const engLoup = def[1].pnj_id;
  const id = (await db.query('SELECT id FROM batailles_engagements WHERE pnj_id = $1', [engLoup])).rows[0].id;
  assert.equal((await db.query('SELECT sovarka_foret_morsure_interne($1, 27, 0) r', [id])).rows[0].r, 18);
  assert.equal((await db.query('SELECT sovarka_foret_morsure_interne($1, 2, 1) r', [id])).rows[0].r, 1, 'au moins 1 PA');
  const idPj = (await db.query("SELECT id FROM batailles_engagements WHERE personnage = 'Arnie'")).rows[0].id;
  assert.equal((await db.query('SELECT sovarka_foret_morsure_interne($1, 27, 0) r', [idPj])).rows[0].r, 0);
});

async function combattreJusquauBout(db, pnj) {
  const o = await appel(db, 'Tom Tom', "SELECT combat_ouvrir($1, 'arme', gen_random_uuid()) r", [pnj]);
  for (let i = 0; i < 30; i++) {
    const r = (await db.query('SELECT militaire_bataille_round($1) r', [o.bataille])).rows[0].r;
    assert.equal(r.ok, true, JSON.stringify(r));
    if (r.terminee) break;
  }
  return o.bataille;
}

test('combat contre trois loups jusqu’au bout : butin au chef une seule fois, journal du membre, rapport par round', async () => {
  let fait = false;
  for (let essai = 0; essai < 8 && !fait; essai++) {
    const db = await base({ vol: 60 });
    const c = await meute(db);
    await journal(db, 'Arnie');
    const b = await combattreJusquauBout(db, c.pnj);
    const etat = (await db.query('SELECT statut, contexte FROM batailles WHERE id = $1', [b])).rows[0];
    assert.equal(etat.statut, 'terminee');
    const res = etat.contexte.resultat_civil;
    if (res.issue !== 'tues') continue;
    fait = true;
    const morts = Number((await db.query("SELECT count(*) n FROM batailles_engagements WHERE bataille_id = $1 AND etat_final = 'mort'", [b])).rows[0].n);
    assert.equal(res.abattus, morts); assert.equal(res.total, 3);
    assert.equal(await qte(db, 'Tom Tom', 'viande'), 2 * morts, 'viande au chef, sans doublement');
    assert.equal(await qte(db, 'Tom Tom', 'textile'), 3 * morts);
    assert.equal(await qte(db, 'Arnie', 'viande'), 0, 'rien au membre');
    // Rejouer la finalisation ne redonne rien.
    await db.query('SELECT combat_finaliser_interne($1)', [b]);
    await db.query("SELECT sovarka_foret_issue_combat_interne($1, 'Tom Tom', 'tues')", [c.pnj]);
    assert.equal(await qte(db, 'Tom Tom', 'viande'), 2 * morts);
    // Journal du membre : l'issue avec le butin remis au chef et le numéro du combat.
    const j = await journal(db, 'Arnie');
    assert.equal(j.length, 1); assert.equal(j[0].cle, 'combat'); assert.equal(Number(j[0].bataille), b);
    assert.equal(j[0].params.chef, 'Tom Tom'); assert.equal(j[0].params.nom, 'Meute de 3 loups');
    assert.ok(j[0].params.butin.some(o => o.nom === 'Viande' && o.qte === 2 * morts));
    // Rapport par round, vu par le membre : lui et son chef à gauche (chef d'abord), les trois loups à droite.
    const e = await appel(db, 'Arnie', 'SELECT militaire_bataille_etat($1) r', [b]);
    assert.equal(e.ok, true); assert.equal(e.bataille.adversaire_nom, 'Meute de 3 loups');
    for (const r of e.bataille.rounds) {
      const l = r.lignes;
      assert.deepEqual(l.filter(x => x.mien).map(x => x.nom), ['Tom Tom', 'Arnie'], 'chef d’abord');
      assert.deepEqual(l.filter(x => !x.mien).map(x => x.nom), ['Loup 1', 'Loup 2', 'Loup 3'], 'chaque loup garde sa ligne');
      assert.ok(!/soldat/i.test(JSON.stringify(r.adversaire_estime)), 'jamais « soldats » : ' + JSON.stringify(r.adversaire_estime));
    }
    const dernier = e.bataille.rounds[e.bataille.rounds.length - 1];
    assert.equal(dernier.lignes.filter(x => !x.mien && x.etat === 'mort').length, morts);
    const total = e.bataille.rounds.reduce((t, r) => t + r.lignes.filter(x => !x.mien).reduce((s, x) => s + x.perte, 0), 0);
    assert.ok(total > 0 && total <= 24, 'dégâts subis par les loups : ' + total);
  }
  assert.ok(fait, 'au moins une victoire en huit combats');
});

test('issue d’un combat de faune : un loup tué ne fait pas la victoire si d’autres restent debout et que le groupe tombe', async () => {
  const db = await base();
  const c = await meute(db);
  const o = await appel(db, 'Tom Tom', "SELECT combat_ouvrir($1, 'arme', gen_random_uuid()) r", [c.pnj]);
  await db.query("UPDATE batailles_engagements SET sorti_round = 2, etat_final = 'mort' WHERE bataille_id = $1 AND pnj_id = $2", [o.bataille, c.pnj]);
  await db.query("UPDATE batailles_engagements SET sorti_round = 2, etat_final = 'indisponible' WHERE bataille_id = $1 AND personnage IS NOT NULL", [o.bataille]);
  await db.query("UPDATE batailles SET statut = 'terminee' WHERE id = $1", [o.bataille]);
  const v = (await db.query('SELECT combat_finaliser_interne($1) r', [o.bataille])).rows[0].r;
  assert.equal(v.issue, 'defaite');
  assert.equal(await qte(db, 'Tom Tom', 'viande'), 0);
});

test('fuir : les trois loups se retirent et le membre l’apprend ; rencontre à l’arrivée relayée aussi', async () => {
  const db = await base();
  await db.query("UPDATE personnages_donnees SET current_room = 'foret_vue_3'");
  const c = await meute(db);
  await journal(db, 'Arnie');
  const f = await appel(db, 'Tom Tom', "SELECT sovarka_foret_rencontre(gen_random_uuid(), 'fuir') r");
  assert.equal(f.ok, true);
  assert.equal(Number((await db.query("SELECT count(*) n FROM pnj_membres WHERE statut = 'actif'")).rows[0].n), 0);
  assert.equal((await journal(db, 'Arnie'))[0].cle, 'fuite');
  await db.query("UPDATE aliments_parametres SET valeur = 100 WHERE cle = 'foret_rencontre_arrivee_pct'");
  await db.query("UPDATE personnages_donnees SET current_room = 'foret_clairiere'");
  const a = await appel(db, 'Tom Tom', "SELECT sovarka_foret_aller(gen_random_uuid(), 'enfoncer') r");
  assert.equal(a.rencontre, 'attaque'); assert.equal(a.a_l_arrivee, true);
  const j = await journal(db, 'Arnie');
  assert.equal(j[0].cle, 'rencontre'); assert.equal(j[0].params.a_l_arrivee, true);
  void c;
});
