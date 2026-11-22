'use strict';
// Accueil des nouveaux joueurs (Fred, 22/11/2026, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 23 à 26), migration
// 20261123140000_accueil_interview, dans un vrai PostgreSQL local (PGlite) : état d'interview par personnage, chemins et
// parcours (12 parcours de 3 étapes, ordres présents dans data.js), étapes validées par l'ordre payé ou à la main,
// bulle des PA une seule fois par personnage (mémorisée au serveur), paiement jamais bloqué par l'accueil. Rejouable.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --experimental-vm-modules --test outils/bancs/banc-accueil-interview-pglite-20261123.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIGRATION = 'migrations/20261123140000_accueil_interview.sql';

test('les 36 étapes nomment des ordres qui existent dans data.js ; la migration ne touche que payer_ordre_interne', () => {
  const m = lire(MIGRATION), data = lire('data.js');
  const fns = [...m.matchAll(/^\s+\('(republic|soviet)', '(\w+)', (\d), '(?:[^']|'')*', '(?:[^']|'')*', (NULL|'(\w+)'), '(ordre|manuelle)', (NULL|'(?:[^']|'')*')\)/gm)];
  assert.equal(fns.length, 36, '6 chemins × 3 étapes × 2 pays');
  for (const x of fns) {
    const [, pays, chemin, n, , fn, validation, pnj] = x;
    if (fn) assert.ok(new RegExp('fn: *[\'"]' + fn + '[\'"]').test(data), fn + ' existe dans data.js');
    if (n === '3') assert.notEqual(pnj, 'NULL', 'étape 3 confiée à un PNJ (' + pays + '/' + chemin + ')');
    if (validation === 'ordre') assert.ok(fn, 'une étape « ordre » nomme son ordre');
  }
  assert.deepEqual([...m.matchAll(/rp_remplacer\('([^']+)'/g)].map(x => x[1]), ['public.payer_ordre_interne(text,text,integer,integer,integer)']);
  assert.doesNotMatch(m.replace(/^--.*$/gm, ''), /goulag/i, 'rien du goulag');
  assert.doesNotMatch(m, /^\s*(BEGIN|COMMIT)\s*;/m, 'sans BEGIN/COMMIT');
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const U = { tom: '00000000-0000-0000-0000-000000000001', ivan: '00000000-0000-0000-0000-000000000002', vieux: '00000000-0000-0000-0000-000000000003',
  mj: '00000000-0000-0000-0000-0000000000aa' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/accueil-interview-pglite-socle.sql.txt'));
  await db.exec(`
    INSERT INTO personnages (name, user_id, country) VALUES ('Tom', '${U.tom}', 'republic'), ('Ivan', '${U.ivan}', 'soviet'), ('Vieux', '${U.vieux}', 'republic');
    INSERT INTO personnages_donnees (name, user_id, country, pa) VALUES ('Tom', '${U.tom}', 'republic', 10), ('Ivan', '${U.ivan}', 'soviet', 10), ('Vieux', '${U.vieux}', 'republic', 10);
    INSERT INTO ordres_couts VALUES ('marche_noir', 1, 0), ('falsifier_document', 3, 300), ('calendrier_elections', 0, 0), ('stage_caserne', 3, 0);
    INSERT INTO interviews_jodie (id, personnage, country, transcript, publie, article_titre, article_texte)
      VALUES ('ancienne', 'Vieux', 'republic', '[{"question":"q","reponse":"r"}]', true, 'Titre', 'Texte publié');
    INSERT INTO admins VALUES ('${U.mj}');`);
  await db.exec(lire(MIGRATION));
  return db;
}
async function comme(db, uid, sql, params) {
  await db.exec(`SET test.uid = '${uid}'; SET ROLE authenticated;`);
  try { return (await db.query(sql, params || [])).rows; } finally { await db.exec('RESET ROLE; RESET test.uid;'); }
}
const rpc = async (db, uid, fn, args = '', params) => (await comme(db, uid, `SELECT public.${fn}(${args}) r`, params))[0].r;
const payer = async (db, nom, fn, pa, cost) => (await db.query('SELECT public.payer_ordre_interne($1, $2, $3, $4) r', [nom, fn, pa, cost])).rows[0].r;
const evenements = async (db, nom, cle) => (await db.query('SELECT cle, texte, params FROM personnage_evenements WHERE destinataire = $1 AND cle = $2 ORDER BY id', [nom, cle])).rows;

test('migration rejouable ; 12 parcours de 3 étapes ; interviews existantes intactes (accueil = false)', async () => {
  const db = await base();
  await db.exec(lire(MIGRATION));
  const n = (await db.query('SELECT pays, count(*)::int n FROM accueil_etapes GROUP BY pays ORDER BY pays')).rows;
  assert.deepEqual(n, [{ pays: 'republic', n: 18 }, { pays: 'soviet', n: 18 }]);
  const c = (await db.query('SELECT count(*)::int n FROM accueil_chemins')).rows[0].n;
  assert.equal(c, 12);
  const v = (await db.query("SELECT accueil, publie, article_texte FROM interviews_jodie WHERE id = 'ancienne'")).rows[0];
  assert.deepEqual(v, { accueil: false, publie: true, article_texte: 'Texte publié' });
  assert.equal((await db.query('SELECT count(*)::int n FROM accueil_personnages')).rows[0].n, 0, 'aucune ligne de joueur écrite par la migration');
});

test('point 23/25 : première connexion = interview à ouvrir ; vue une fois, elle reste dans Mes objectifs ; Vera en Sovarka ; déjà interviewé = rien', async () => {
  const db = await base();
  let e = await rpc(db, U.tom, 'accueil_etat');
  assert.equal(e.ok, true);
  assert.equal(e.interview.etat, 'a_faire');
  assert.equal(e.interview.journaliste, 'Jodie Moitout');
  assert.equal(e.interview.ouvrir_auto, true);
  assert.deepEqual(e.chemins.map(c => c.id), ['politique', 'affaires', 'influence', 'crime', 'uniforme', 'belle_vie']);
  assert.equal(e.chemins[4].libelle, "L'uniforme (armée ou police)");
  await rpc(db, U.tom, 'accueil_interview_vue');
  e = await rpc(db, U.tom, 'accueil_etat');
  assert.equal(e.interview.ouvrir_auto, false, 'pas de seconde ouverture automatique');
  assert.equal(e.interview.etat, 'a_faire', 'fermée sans réponse : toujours à faire (Mes objectifs)');
  const i = await rpc(db, U.ivan, 'accueil_etat');
  assert.equal(i.interview.journaliste, 'Vera Pravdina');
  assert.equal(i.interview.journal, 'La Voix de Sovarka');
  const v = await rpc(db, U.vieux, 'accueil_etat');
  assert.equal(v.interview.etat, 'deja_interviewe');
  assert.equal(v.interview.ouvrir_auto, false);
  // Le navigateur ne lit ni n'écrit la table directement.
  await assert.rejects(comme(db, U.tom, 'SELECT * FROM accueil_personnages'));
  await assert.rejects(comme(db, U.tom, "UPDATE accueil_personnages SET etat_interview = 'faite'"));
  await assert.rejects(comme(db, U.tom, "SELECT public.accueil_ordre_paye_interne('Tom', 'marche_noir', 1)"));
  // Sans compte : refus propre.
  assert.equal((await rpc(db, '00000000-0000-0000-0000-0000000000ff', 'accueil_etat')).ok, false);
});

test('point 23/24 : choisir un chemin dépose le parcours ; une seule fois ; mot borné ; ignorer retire l’interview', async () => {
  const db = await base();
  assert.equal((await rpc(db, U.tom, 'accueil_choisir_chemin', "'piraterie', NULL")).raison, 'chemin_inconnu');
  assert.equal((await rpc(db, U.tom, 'accueil_choisir_chemin', "'crime', repeat('x', 400)")).raison, 'mot_trop_long');
  const e = await rpc(db, U.tom, 'accueil_choisir_chemin', "'crime', '  Je connais du monde.  '");
  assert.equal(e.ok, true);
  assert.equal(e.interview.etat, 'article_a_publier');
  assert.equal(e.mot, 'Je connais du monde.');
  assert.deepEqual(e.chemin, { id: 'crime', libelle: 'Le crime' });
  assert.equal(e.etapes.length, 3);
  assert.match(e.etapes[0].lieu, /Armurerie Martinon/);
  assert.equal(e.etapes[2].pnj, 'Pat Hounette');
  assert.equal((await rpc(db, U.tom, 'accueil_choisir_chemin', "'politique', NULL")).raison, 'chemin_deja_choisi');
  assert.equal((await rpc(db, U.tom, 'accueil_choisir_chemin', "'crime', NULL")).ok, true, 'même chemin : idempotent');
  const iv = await rpc(db, U.ivan, 'accueil_ignorer');
  assert.equal(iv.interview.etat, 'ignoree');
  assert.equal(iv.interview.ouvrir_auto, false);
  // La publication (service) passe l'état à « faite » ; elle seule peut écrire.
  await db.query("UPDATE accueil_personnages SET etat_interview = 'faite', interview_id = 'x' WHERE personnage = 'Tom'");
  assert.equal((await rpc(db, U.tom, 'accueil_etat')).interview.etat, 'faite');
});

test('point 24 : l’ordre payé coche son étape (serveur), les autres se cochent à la main ; point 26 : bulle des PA une seule fois', async () => {
  const db = await base();
  await rpc(db, U.tom, 'accueil_etat');
  await rpc(db, U.tom, 'accueil_choisir_chemin', "'crime', NULL");
  const p = await payer(db, 'Tom', 'marche_noir', 1, 0);
  assert.equal(p.ok, true); assert.equal(p.pa, 9);
  let e = await rpc(db, U.tom, 'accueil_etat');
  assert.deepEqual(e.etapes.map(x => x.faite), [true, false, false]);
  assert.equal((await evenements(db, 'Tom', 'accueil_etape')).length, 1);
  const b = await evenements(db, 'Tom', 'accueil_bulle_pa');
  assert.deepEqual(b, [{ cle: 'accueil_bulle_pa', texte: '', params: { pa: 1 } }], 'bulle prévenue par le journal du serveur, sans texte au journal');
  assert.equal(e.bulle_pa.vue, true);
  assert.equal((await payer(db, 'Tom', 'falsifier_document', 3, 300)).ok, true);
  assert.equal((await evenements(db, 'Tom', 'accueil_bulle_pa')).length, 1, 'jamais une seconde bulle');
  assert.equal((await rpc(db, U.tom, 'accueil_bulle_pa_signaler', '2')).montrer, false, 'signalement du navigateur : déjà vue');
  e = await rpc(db, U.tom, 'accueil_etape_valider', '3');
  assert.deepEqual(e.etapes.map(x => x.faite), [true, true, true]);
  assert.equal((await rpc(db, U.tom, 'accueil_etape_valider', '7')).raison, 'etape_inconnue');
  // Un ordre gratuit (0 PA) ne déclenche pas la bulle.
  await rpc(db, U.vieux, 'accueil_etat');
  assert.equal((await payer(db, 'Vieux', 'calendrier_elections', 0, 0)).ok, true);
  assert.equal((await evenements(db, 'Vieux', 'accueil_bulle_pa')).length, 0);
});

test('point 26 : ordre payé hors du paiement commun, signalé par le navigateur : le serveur montre la bulle une fois', async () => {
  const db = await base();
  await rpc(db, U.ivan, 'accueil_etat');
  assert.equal((await rpc(db, U.ivan, 'accueil_bulle_pa_signaler', '0')).raison, 'pa_invalide');
  assert.equal((await rpc(db, U.ivan, 'accueil_bulle_pa_signaler', '99')).raison, 'pa_invalide');
  assert.deepEqual(await rpc(db, U.ivan, 'accueil_bulle_pa_signaler', '2'), { ok: true, montrer: true, pa: 2 });
  assert.equal((await rpc(db, U.ivan, 'accueil_bulle_pa_signaler', '2')).montrer, false);
  assert.equal((await rpc(db, U.ivan, 'accueil_etat')).bulle_pa.vue, true);
});

test('un incident de l’accueil ne fait jamais échouer un paiement ; personnage sans ligne d’accueil : paiement inchangé', async () => {
  const db = await base();
  assert.equal((await payer(db, 'Vieux', 'marche_noir', 1, 0)).ok, true, 'sans ligne d’accueil');
  assert.equal((await db.query("SELECT count(*)::int n FROM accueil_personnages WHERE personnage = 'Vieux'")).rows[0].n, 0);
  await rpc(db, U.tom, 'accueil_etat');
  await rpc(db, U.tom, 'accueil_choisir_chemin', "'crime', NULL");
  await db.exec('ALTER TABLE accueil_etapes RENAME TO accueil_etapes_cassee');
  const p = await payer(db, 'Tom', 'marche_noir', 1, 0);
  assert.equal(p.ok, true); assert.equal(p.pa, 9);
  assert.equal((await db.query("SELECT pa FROM personnages_donnees WHERE name = 'Tom'")).rows[0].pa, 9);
});

test('réglages MJ : lecture et réglage journalisés ; refusés à un joueur ; ouverture automatique coupée par le MJ', async () => {
  const db = await base();
  await assert.rejects(rpc(db, U.tom, 'admin_accueil_parametre_fixer', "'interview_ouverture_auto', 0"));
  const r = await rpc(db, U.mj, 'admin_accueil_parametre_fixer', "'interview_ouverture_auto', 0");
  assert.equal(r.ok, true);
  assert.equal((await db.query("SELECT count(*)::int n FROM admin_journal WHERE action = 'accueil_parametre_fixer'")).rows[0].n, 1);
  assert.equal((await rpc(db, U.tom, 'accueil_etat')).interview.ouvrir_auto, false);
  const l = await rpc(db, U.mj, 'admin_accueil_parametres_lire');
  assert.ok(l.parametres.some(x => x.cle === 'mot_longueur_max'));
});
