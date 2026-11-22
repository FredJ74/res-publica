'use strict';
// Pays d'un poste (Fred, 22/11/2026, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie B, points 15 et 16) : migration
// 20261123120000_postes_pays dans un vrai PostgreSQL local (PGlite), sur les définitions de production recopiées.
// Un personnage en voyage garde son poste dans SON pays (registre postes_attribues) et n'obtient jamais aucun pouvoir
// du pays où il se trouve. Chaque épreuve montre aussi le défaut AVANT la migration.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261123120000_postes_pays.sql';
const U = { arnie: '00000000-0000-0000-0000-00000000000a', sasha: '00000000-0000-0000-0000-00000000000b',
  ivan: '00000000-0000-0000-0000-00000000000c', remi: '00000000-0000-0000-0000-00000000000d',
  dora: '00000000-0000-0000-0000-00000000000e', moustafa: '00000000-0000-0000-0000-00000000000f' };
const KRASNOV = ['soviet', 'ville_b'], LUTHECIA = ['republic', 'capitale'], MONTROUGE = ['republic', 'ville_b'];

// La migration entière ne s'applique pas sur un socle partiel : on exécute les fonctions uniques et les portes réécrites,
// puis uniquement les remplacements contrôlés dont la fonction existe dans le socle (les autres sont comptés en production).
function migrationPourSocle(sql, existantes) {
  const [tete, reste] = sql.split('-- 3. Remplacements contrôlés');
  const appels = [...reste.matchAll(/SELECT pg_temp\.rp_remplacer\('public\.([^']+)'::regprocedure,[\s\S]*?, '(pp_[a-z0-9_]+)'\);/g)];
  const retenus = appels.filter(a => existantes.has(a[1].split('(')[0])).map(a => a[0]);
  return { sql: tete + '\n' + retenus.join('\n'), retenus: retenus.length, total: appels.length };
}

async function base({ migrer = true } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/postes-pays-pglite-socle.sql.txt'));
  const fiches = [
    // nom, uid, position (pays, ville), nationalité, poste
    ['Arnie', U.arnie, KRASNOV, 'republic', { id: 'min_def', city: null, name: 'Ministre de la Defense' }],
    ['Sasha', U.sasha, LUTHECIA, 'soviet', { id: 'min_def', city: null, name: 'Ministre de la Défense de la Patrie' }],
    ['Ivan', U.ivan, MONTROUGE, 'soviet', { id: 'juge', city: 'ville_b', name: 'Juge' }],
    ['Rémi', U.remi, KRASNOV, 'republic', { id: 'juge', city: 'ville_b', name: 'Juge' }],
    ['Dora', U.dora, KRASNOV, 'republic', { id: 'directeur_entrepot', city: 'ville_b', name: "Directeur de l'Entrepôt" }],
    ['Moustafa', U.moustafa, KRASNOV, 'republic', { id: 'president', city: null, name: 'Président' }],
    ['Ben', null, MONTROUGE, 'republic', { id: 'capitaine_port', city: null, name: 'Commandant du Port' }],
    ['Vince', null, ['republic', 'caserne'], 'republic', { id: 'lieutenant', name: 'Lieutenant', compagnieId: 'compagnie-republic-1', sectionId: 'compagnie-republic-1-s1' }],
    ['Kolia', null, LUTHECIA, 'soviet', { id: 'commissaire', city: 'capitale', name: 'Commissaire' }],
  ];
  for (const [n, u, [pays, ville], nat, poste] of fiches) {
    if (u) await db.query('INSERT INTO personnages VALUES ($1,$2)', [n, u]);
    await db.query('INSERT INTO personnages_donnees (name, user_id, country, nationalite, current_city, poste) VALUES ($1,$2,$3,$4,$5,$6)',
      [n, u, pays, nat, ville, JSON.stringify(poste)]);
  }
  await db.exec(`
    INSERT INTO postes_attribues (id, country, poste_id, city, titulaire, source) VALUES
      ('republic_min_def_national', 'republic', 'min_def', NULL, 'Arnie', 'candidature_autorite_pnj'),
      ('soviet_min_def_national', 'soviet', 'min_def', NULL, 'Sasha', 'nomination'),
      ('soviet_juge_ville_b', 'soviet', 'juge', 'ville_b', 'Ivan', 'nomination'),
      ('republic_juge_ville_b', 'republic', 'juge', 'ville_b', 'Rémi', 'nomination'),
      ('republic_directeur_entrepot_ville_b', 'republic', 'directeur_entrepot', 'ville_b', 'Dora', 'nomination'),
      ('republic_capitaine_port_national', 'republic', 'capitaine_port', NULL, 'Ben', 'tirage_au_sort_candidature'),
      ('republic_directeur_entrepot_ville_a', 'republic', 'directeur_entrepot', 'ville_a', 'Ben', 'candidature_autorite_pnj'),
      ('soviet_commissaire_capitale', 'soviet', 'commissaire', 'capitale', 'Kolia', 'nomination');
    INSERT INTO cycles_electoraux (id, country, poste_id, city, data) VALUES
      ('republic_president', 'republic', 'president', NULL, '{"eluId": "Moustafa"}'),
      ('soviet_president', 'soviet', 'president', NULL, '{"eluId": null}');
    INSERT INTO compagnies_militaires (id, data) VALUES
      ('compagnie-republic-1', '{"pays": "republic", "sections": [{"id": "compagnie-republic-1-s1", "lieutenantNom": "Vince"}]}'),
      ('compagnie-soviet-1', '{"pays": "soviet", "sections": []}');
    INSERT INTO titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES
      ('republic_juge_capitale', 'republic', 'juge', 'capitale', 'Juge Honoré');
    INSERT INTO entrepots_par_ville VALUES ('republic', 'ville_b', 'entrepot-montrouge'), ('soviet', 'ville_b', 'entrepot-krasnov');
    INSERT INTO commandes_militaires (id, pays, statut) VALUES ('cmd-sov', 'soviet', 'en_cours'), ('cmd-rep', 'republic', 'en_cours');`);
  if (migrer) await migrer_(db);
  return db;
}
async function migrer_(db) {
  const fns = new Set((await db.query("SELECT proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace")).rows.map(r => r.proname));
  const m = migrationPourSocle(lire(MIGRATION), fns);
  await db.exec(m.sql);
  return m;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0]?.r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const placer = (db, nom, [pays, ville]) => db.query('UPDATE personnages_donnees SET country = $2, current_city = $3 WHERE name = $1', [nom, pays, ville]);
const erreur = async (db, sql) => { try { await db.query(sql); return null; } catch (e) { return e.message; } };

test('la migration se rejoue ; 66 remplacements comptés en production, ceux du socle appliqués avec leur marque', async () => {
  const db = await base({ migrer: false });
  const m = await migrer_(db);
  assert.equal(m.total, 66);
  assert.ok(m.retenus >= 11, 'remplacements éprouvés ici : ' + m.retenus);
  await migrer_(db);
  for (const [fn, marque] of [['juge_moi', 'pp_juge_moi'], ['piratage_titulaire_interne', 'pp_piratage'], ['effort_commande_annuler', 'pp_effort_annuler'],
    ['personnages_poste_perdu', 'pp_poste_perdu'], ['militaire_inspection_perimetre', 'pp_inspection'], ['entrepot_du_directeur', 'pp_entrepot_dir']]) {
    const n = Number(await un(db, "SELECT (length(prosrc) - length(replace(prosrc, $2, ''))) / length($2) r FROM pg_proc WHERE proname = $1", [fn, marque]));
    assert.equal(n, 1, fn + ' : ' + marque + ' une seule fois après deux passages');
  }
  const totalMarques = (lire(MIGRATION).match(/'pp_[a-z0-9_]+'\);/g) || []).length;
  assert.equal(totalMarques, 66);
});

test('les trois fonctions uniques : Arnie à Krasnov garde son poste républicain et n’exerce rien en Sovarka', async () => {
  const db = await base();
  const d = (nom, poste, pays, ville) => un(db, 'SELECT poste_detenu($1,$2,$3,$4) r', [nom, poste, pays, ville || null]);
  assert.equal(await d('Arnie', 'min_def', 'republic'), true);
  assert.equal(await d('Arnie', 'min_def', 'soviet'), false);
  assert.equal(await un(db, "SELECT poste_pays_de('Arnie') r"), 'republic');
  assert.equal(await un(db, "SELECT poste_exerce('Arnie') r"), null, 'à Krasnov, il n’exerce pas');
  await placer(db, 'Arnie', LUTHECIA);
  assert.equal(await un(db, "SELECT poste_exerce('Arnie') r"), 'min_def', 'chez lui, il exerce');
  // Postes élus, grades militaires, ligne orpheline du registre
  assert.equal(await un(db, "SELECT poste_pays_de('Moustafa') r"), 'republic');
  assert.equal(await d('Moustafa', 'president', 'soviet'), false);
  assert.equal(await d('Moustafa', 'president', 'republic'), true);
  assert.equal(await un(db, "SELECT poste_pays_de('Vince') r"), 'republic');
  assert.equal(await d('Vince', 'lieutenant', 'republic'), true);
  assert.equal(await d('Vince', 'lieutenant', 'soviet'), false);
  assert.equal(await d('Ben', 'capitaine_port', 'republic'), true);
  assert.equal(await d('Ben', 'directeur_entrepot', 'republic', 'ville_a'), false, 'ligne orpheline : la fiche porte un autre poste');
  assert.equal(await d('Dora', 'directeur_entrepot', 'republic', 'ville_b'), true);
  assert.equal(await d('Dora', 'directeur_entrepot', 'soviet', 'ville_b'), false, 'même identifiant de ville, autre pays');
  // Aucune ligne du registre ni aucune fiche n'est touchée par la migration
  assert.equal(Number(await un(db, 'SELECT count(*) r FROM postes_attribues')), 8);
  assert.equal(await un(db, "SELECT poste->>'id' r FROM personnages_donnees WHERE name = 'Arnie'"), 'min_def');
});

test('portes communes : mon_poste_est_dans, guerre_acteur_poste, acteur_poste_courant, exiger_poste (Arnie à Krasnov puis à Luthécia)', async () => {
  const avant = await base({ migrer: false });
  await en(avant, U.arnie);
  assert.equal(await un(avant, "SELECT mon_poste_est_dans('min_def', 'soviet') r"), true, 'défaut constaté avant la migration');
  assert.equal(await un(avant, "SELECT guerre_acteur_poste('min_def') r"), 'soviet', 'défaut constaté avant la migration');

  const db = await base();
  await en(db, U.arnie);
  assert.equal(await un(db, "SELECT mon_poste_est_dans('min_def', 'soviet') r"), false);
  assert.equal(await un(db, "SELECT mon_poste_est_dans('min_def', 'republic') r"), true, 'il garde son poste républicain');
  assert.equal(await un(db, "SELECT mon_poste_est('min_def') r"), true);
  assert.equal(await un(db, "SELECT guerre_acteur_poste('min_def') r"), null);
  assert.equal(await un(db, "SELECT pays r FROM acteur_poste_courant()"), 'republic');
  assert.match(await erreur(db, "SELECT exiger_poste('min_def')"), /mandat_autre_pays/);
  await placer(db, 'Arnie', LUTHECIA);
  assert.equal(await un(db, "SELECT guerre_acteur_poste('min_def') r"), 'republic');
  assert.equal(await un(db, "SELECT exiger_poste('min_def') r"), 'Arnie');
  // Un Soviétique à Luthécia : idem, dans l'autre sens.
  await en(db, U.sasha);
  assert.equal(await un(db, "SELECT mon_poste_est_dans('min_def', 'republic') r"), false);
  assert.equal(await un(db, "SELECT mon_poste_est_dans('min_def', 'soviet') r"), true);
  assert.equal(await un(db, "SELECT pays r FROM acteur_poste_courant()"), 'soviet');
  assert.equal(await un(db, "SELECT guerre_acteur_poste('min_def') r"), null);
  assert.match(await erreur(db, "SELECT exiger_poste('min_def')"), /mandat_autre_pays/);
});

test('ordres du ministre de la Défense : commande militaire et inspection — rien à l’étranger, tout chez soi', async () => {
  const avant = await base({ migrer: false });
  await en(avant, U.arnie);
  assert.equal((await un(avant, "SELECT effort_commande_annuler('cmd-sov') r")).ok, true, 'défaut : Arnie annulait une commande soviétique');
  assert.equal((await un(avant, 'SELECT militaire_inspection_perimetre() r')).pays, 'soviet', 'défaut : il inspectait l’armée soviétique');

  const db = await base();
  await en(db, U.arnie);
  assert.equal((await un(db, "SELECT effort_commande_annuler('cmd-sov') r")).raison, 'poste_requis');
  assert.equal((await un(db, 'SELECT militaire_inspection_perimetre() r')).raison, 'hors_chaine_d_inspection');
  await placer(db, 'Arnie', LUTHECIA);
  assert.equal((await un(db, "SELECT effort_commande_annuler('cmd-rep') r")).ok, true);
  const insp = await un(db, 'SELECT militaire_inspection_perimetre() r');
  assert.equal(insp.pays, 'republic'); assert.deepEqual(insp.compagnies, ['compagnie-republic-1']);
  await en(db, U.sasha);
  assert.equal((await un(db, "SELECT effort_commande_annuler('cmd-sov') r")).raison, 'poste_requis', 'Sasha à Luthécia');
  assert.equal(await un(db, "SELECT statut r FROM commandes_militaires WHERE id = 'cmd-sov'"), 'en_cours');
});

test('titulaires d’un pays : gouvernement, juge, cible du piratage, PNJ de repli — lus dans le registre, pas sur la position', async () => {
  const avant = await base({ migrer: false });
  assert.deepEqual((await avant.query("SELECT nom FROM assemblee_gouvernement_actuel('soviet')")).rows.map(r => r.nom), ['Arnie', 'Moustafa'], 'défaut : le ministre et le président républicains en voyage');
  assert.equal(await un(avant, "SELECT piratage_titulaire_interne('min_def', 'soviet') r"), 'Arnie');

  const db = await base();
  assert.deepEqual((await db.query("SELECT nom FROM assemblee_gouvernement_actuel('soviet')")).rows.map(r => r.nom), ['Sasha']);
  assert.deepEqual((await db.query("SELECT nom FROM assemblee_gouvernement_actuel('republic')")).rows.map(r => r.nom), ['Arnie', 'Moustafa']);
  assert.equal(await un(db, "SELECT piratage_titulaire_interne('min_def', 'soviet') r"), 'Sasha');
  assert.equal(await un(db, "SELECT piratage_titulaire_interne('min_def', 'republic') r"), 'Arnie');
  assert.equal(await un(db, "SELECT justice_juge_titulaire('soviet', 'ville_b') r"), 'Ivan', 'juge de Krasnov, en voyage à Montrouge');
  assert.equal(await un(db, "SELECT justice_juge_titulaire('republic', 'ville_b') r"), 'Rémi', 'juge de Montrouge, en voyage à Krasnov');
  assert.equal(await un(db, "SELECT admin_pnj_titulaire('republic', 'juge', 'capitale') r"), 'Juge Honoré');
  assert.equal(await un(db, "SELECT admin_pnj_titulaire('republic', 'juge', 'ville_b') r"), null, 'Rémi est titulaire, même à Krasnov');
  assert.equal(await un(db, "SELECT crim_qhs_pays_mandat_interne('Arnie') r"), 'republic');
});

test('justice et entrepôt : un juge, un commissaire, un directeur en voyage n’ont aucune autorité dans la ville homonyme', async () => {
  const avant = await base({ migrer: false });
  assert.equal(await un(avant, "SELECT sovarka_greffe_autorite_interne('Rémi') r"), true, 'défaut : juge républicain à la greffe soviétique');
  assert.equal((await avant.query("SELECT * FROM entrepot_du_directeur('Dora')")).rows[0]?.batiment, 'entrepot-krasnov', 'défaut');
  await en(avant, U.remi);
  assert.equal((await avant.query('SELECT * FROM juge_moi()')).rows[0]?.pays, 'soviet', 'défaut : Rémi juge de Krasnov');

  const db = await base();
  assert.equal(await un(db, "SELECT sovarka_greffe_autorite_interne('Rémi') r"), false);
  assert.equal(await un(db, "SELECT sovarka_greffe_autorite_interne('Ivan') r"), true, 'Ivan garde la greffe de son pays');
  assert.equal((await db.query("SELECT * FROM entrepot_du_directeur('Dora')")).rows.length, 0);
  await placer(db, 'Dora', MONTROUGE);
  assert.equal((await db.query("SELECT * FROM entrepot_du_directeur('Dora')")).rows[0].batiment, 'entrepot-montrouge');
  await en(db, U.remi);
  assert.equal((await db.query('SELECT * FROM juge_moi()')).rows.length, 0);
  await placer(db, 'Rémi', MONTROUGE);
  assert.deepEqual((await db.query('SELECT * FROM juge_moi()')).rows[0], { nom: 'Rémi', pays: 'republic', ville: 'ville_b' });
  assert.equal(await un(db, "SELECT crim_force_ordre_interne('Kolia') r"), false, 'commissaire soviétique à Luthécia');
  await placer(db, 'Kolia', ['soviet', 'capitale']);
  assert.equal(await un(db, "SELECT crim_force_ordre_interne('Kolia') r"), true);
});

test('un poste perdu à l’étranger efface sa ligne du registre (le déclencheur ne filtrait que sur la position)', async () => {
  const avant = await base({ migrer: false });
  await avant.query("UPDATE personnages_donnees SET poste = NULL WHERE name = 'Arnie'");
  assert.equal(Number(await un(avant, "SELECT count(*) r FROM postes_attribues WHERE titulaire = 'Arnie'")), 1, 'défaut : ligne orpheline');
  const db = await base();
  await db.query("UPDATE personnages_donnees SET poste = NULL WHERE name = 'Arnie'");
  assert.equal(Number(await un(db, "SELECT count(*) r FROM postes_attribues WHERE titulaire = 'Arnie'")), 0);
  assert.equal(Number(await un(db, "SELECT count(*) r FROM postes_attribues WHERE titulaire = 'Sasha'")), 1);
});
