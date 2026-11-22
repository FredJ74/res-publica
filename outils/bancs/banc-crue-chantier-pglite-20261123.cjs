'use strict';
// Crue (Fred, 22/11/2026, soir : GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 30 et 31), partie F de la migration
// 20261123150000_tabac_presse_crue, éprouvée dans un vrai PostgreSQL local (PGlite) sur les définitions de production :
// la crue arrête seulement les chantiers de la ville une journée (un jour de retard), sans fermeture de lieu, sans perte de
// stock, sans sacs de sable ; l'état de catastrophe naturelle est en sommeil (réglage MJ).
// PGlite : PGLITE_DIR=<dossier contenant node_modules/@electric-sql/pglite> (la CI l'installe dans un dossier temporaire).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

// La partie F est délimitée dans la migration commune (la partie E a ses propres fixtures et son propre banc).
const DEBUT = '-- ===== PARTIE F : CRUE =====', FIN = '-- ===== FIN PARTIE F =====';
function sectionCrue() {
  const sources = ['migrations/20261123150000_tabac_presse_crue.sql'];
  if (process.env.CRUE_SECTION) sources.unshift(process.env.CRUE_SECTION);   // mise au point
  for (const f of sources) {
    const p = path.isAbsolute(f) ? f : path.join(root, f);
    if (!fs.existsSync(p)) continue;
    const t = fs.readFileSync(p, 'utf8'), a = t.indexOf(DEBUT), b = t.indexOf(FIN);
    if (a >= 0 && b > a && t.slice(a, b).includes('crue_chantier_jour_v1')) return t.slice(a, b + FIN.length);
  }
  throw new Error('partie F introuvable dans la migration');
}

function chantier(o = {}) {
  return Object.assign({ type: 'construction', niveau: 'building', coutTotal: 120000, dureeJours: 24, progressionJours: 1, totalVerse: 120000,
    tresorerie: 60000, coutTravail: 84000, coutMateriaux: 36000, heuresTotales: 1200, heuresFaites: 0, maitreOuvrage: 'Arnie',
    stockMateriaux: { bois: 100, minerai: 50, metal: 34 }, travauxPJ: [], evenements: [], jourTraite: '2000-01-01' }, o);
}
async function base({ migrer = true } = {}) {
  const db = new PGlite();
  for (const f of ['outils/bancs/fixtures/chantier-pglite-socle.sql.txt', 'outils/bancs/fixtures/chantier-commande-entrepot.sql.txt',
    'migrations/20261121140000_chantier_jour_avance.sql', 'migrations/20261122120000_chantier_heures_ouvertes_commande_nuit.sql',
    'outils/bancs/fixtures/crue-chantier-pglite-socle.sql.txt']) await db.exec(lire(f));
  await db.query("INSERT INTO terrains_etat VALUES ('republic_terrain-a-batir-3', 'republic', $1, now())",
    [JSON.stringify({ proprietaire: 'Arnie', city: 'capitale', chantier: chantier() })]);
  await db.query(`INSERT INTO personnages_donnees (name, pa, arg, liquide, day, current_city, updated_at, country, poste) VALUES
    ('Arnie', 500, 0, 0, 30, 'capitale', now(), 'republic', NULL),
    ('Ministre', 30, 0, 0, 30, 'capitale', now(), 'republic', '{"id":"min_int"}'),
    ('Premier', 30, 0, 0, 30, 'capitale', now(), 'republic', '{"id":"pm"}')`);
  if (migrer) await db.exec(sectionCrue());
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
// Crue à Luthécia (capitale), décalée en jours de Paris par rapport à aujourd'hui, heure de début et durée données.
async function crue(db, jours, { heure = 10, minutes = 360, lieux = '[{"batiment":"entrepot-logistique-luthecia","nom":"l\'entrepôt logistique"}]' } = {}) {
  return (await un(db, `INSERT INTO climat_evenements (type, pays, ville, debut, fin, periode, lieux, alerte_le, effets_le)
    SELECT 'crue', 'republic', 'capitale', d, d + make_interval(secs => $2::float8 * 60), 'T', $3::jsonb, d - interval '2 days', d
      FROM (SELECT climat_minuit_interne((now() AT TIME ZONE 'Europe/Paris')::date + $1::int) + make_interval(hours => $4::int) d) x RETURNING id`,
    [jours, minutes, lieux, heure])).id;
}
const nuit = async db => (await un(db, "SELECT chantier_jour_traiter('republic_terrain-a-batir-3') r")).r;
const lireCh = async db => JSON.parse((await un(db, 'SELECT data FROM terrains_etat')).data).chantier;
const nouvelleJournee = db => db.query("UPDATE terrains_etat SET data = jsonb_set(data::jsonb, '{chantier,jourTraite}', '\"2000-01-01\"')::text");

test('avant / après : la crue fermait les lieux de la zone inondable ; elle ne ferme plus rien', async () => {
  const avant = await base({ migrer: false });
  await crue(avant, 0, { heure: 0, minutes: 48 * 60 });
  assert.equal((await un(avant, "SELECT climat_batiment_inonde_interne('republic','capitale','entrepot-logistique-luthecia') f")).f, true);
  const db = await base();
  const id = await crue(db, 0, { heure: 0, minutes: 48 * 60 });
  assert.equal((await un(db, "SELECT climat_batiment_inonde_interne('republic','capitale','entrepot-logistique-luthecia') f")).f, false);
  const j = (await un(db, 'SELECT climat_evenement_json_interne(e) j FROM climat_evenements e WHERE id = $1', [id])).j;
  assert.deepEqual(j.lieux, []); assert.deepEqual(j.lieux_proteges, []); assert.equal(j.chantiers_arretes, true);
  assert.match(j.consigne, /jour de retard/);
  assert.doesNotMatch(j.consigne, /sac|fermé|perdent/);
  const alerte = (await un(db, 'SELECT climat_texte_alerte_interne(e) t FROM climat_evenements e WHERE id = $1', [id])).t;
  assert.match(alerte, /^Crue annoncée à Luthécia le /); assert.doesNotMatch(alerte, /zone inondable/);
});

test('la nuit qui suit le jour de la crue, le chantier n’avance pas : un jour de retard, rien de payé ni consommé', async () => {
  const db = await base();
  const id = await crue(db, -1);                       // crue d'hier (heure de Paris), terminée
  const avant = await lireCh(db);
  const r = await nuit(db);
  assert.equal(r.ok, true); assert.equal(r.crue, true); assert.equal(r.avance, 0); assert.equal(Number(r.evenement), Number(id));
  const c = await lireCh(db);
  assert.equal(c.progressionJours, avant.progressionJours, 'aucune avance');
  assert.equal(c.tresorerie, avant.tresorerie, 'aucun salaire ni commande payés');
  assert.deepEqual(c.stockMateriaux, avant.stockMateriaux, 'aucun matériau consommé');
  assert.equal(c.jourTraite, (await un(db, "SELECT ((now() AT TIME ZONE 'Europe/Paris')::date)::text j")).j);
  assert.deepEqual(c.evenements.map(e => e.cle), ['crue']);
  assert.equal((await nuit(db)).rejeu, true, 'rejeu de la même nuit sans effet');
  // La nuit d'après (la crue a maintenant deux jours) : le chantier reprend normalement.
  await db.query("UPDATE climat_evenements SET debut = debut - interval '1 day', fin = fin - interval '1 day'");
  await nouvelleJournee(db);
  const r2 = await nuit(db);
  assert.notEqual(r2.crue, true);
  assert.equal((await lireCh(db)).progressionJours, avant.progressionJours + 1, 'avance normale le lendemain');
});

test('une crue d’une autre ville, annulée ou non annoncée ne retarde rien ; bloque_chantiers faux (MJ) non plus', async () => {
  for (const reglage of ["UPDATE climat_evenements SET ville = 'ville_a'", 'UPDATE climat_evenements SET annule = true',
    'UPDATE climat_evenements SET alerte_le = NULL', "UPDATE climat_parametres SET bloque_chantiers = false WHERE type = 'crue'"]) {
    const db = await base();
    await crue(db, -1);
    await db.query(reglage);
    const r = await nuit(db);
    assert.notEqual(r.crue, true, reglage);
    assert.equal((await lireCh(db)).progressionJours, 2, reglage);
  }
});

test('le jour de la crue, le travail des joueurs sur les chantiers de la ville est refusé jusqu’à minuit', async () => {
  const db = await base();
  // Crue commencée aujourd'hui à minuit et déjà terminée : les chantiers restent arrêtés jusqu'à ce soir minuit.
  await crue(db, 0, { heure: 0, minutes: 0.01 });
  const r = await un(db, "SELECT chantier_travailler('Arnie', 'republic', 'republic_terrain-a-batir-3', 5) r");
  assert.equal(r.r.ok, false); assert.equal(r.r.raison, 'chantier_intemperies');
  assert.equal((await un(db, "SELECT climat_chantiers_bloques_interne('republic','ville_a') b")).b, false, 'autre ville libre');
  // Une crue d'hier, terminée : plus d'arrêt aujourd'hui.
  await db.query("UPDATE climat_evenements SET debut = debut - interval '1 day', fin = fin - interval '1 day'");
  assert.equal((await un(db, "SELECT climat_chantiers_bloques_interne('republic','capitale') b")).b, false);
  // Les autres événements gardent leur durée : un orage terminé ne bloque plus.
  await db.query(`INSERT INTO climat_evenements (type, pays, ville, debut, fin, periode, alerte_le) VALUES
    ('orage', 'republic', 'capitale', now() - interval '3 hours', now() - interval '1 minute', 'T', now() - interval '2 days')`);
  assert.equal((await un(db, "SELECT climat_chantiers_bloques_interne('republic','capitale') b")).b, false);
  await db.query("UPDATE climat_evenements SET fin = now() + interval '1 hour' WHERE type = 'orage'");
  assert.equal((await un(db, "SELECT climat_chantiers_bloques_interne('republic','capitale') b")).b, true, 'orage en cours : inchangé');
});

test('aucune perte de stock ni lieu protégé ; aucun courrier au ministre tant que la catastrophe dort', async () => {
  const db = await base();
  const id = await crue(db, 0, { heure: 0, minutes: 48 * 60 });
  await db.query(`INSERT INTO entreprises VALUES ('ent-1', '{"country":"republic","city":"capitale","buildingId":"entrepot-logistique-luthecia",
    "proprietaire":"pj:Arnie","stockMatieres":{"bois":100},"stockProduits":{"pain":10}}', now())`);
  const n = (await un(db, 'SELECT climat_crue_appliquer_interne(e) n FROM climat_evenements e WHERE id = $1', [id])).n;
  assert.equal(n, 0);
  const d = (await un(db, "SELECT data FROM entreprises WHERE id = 'ent-1'")).data;
  assert.deepEqual(d.stockMatieres, { bois: 100 }); assert.deepEqual(d.stockProduits, { pain: 10 });
  assert.equal(Number((await un(db, 'SELECT count(*) n FROM climat_crue_pertes')).n), 0);
  assert.equal(Number((await un(db, 'SELECT count(*) n FROM courriers_crue_test')).n), 0);
});

test('sacs de sable retirés : pose refusée, plus en vente, plus cités, plus vérifiés comme parade', async () => {
  const db = await base();
  await db.query("SELECT set_config('test.acteur', 'Arnie', false)");
  const r = (await un(db, 'SELECT sacs_sable_poser(gen_random_uuid()) r')).r;
  assert.deepEqual(r, { ok: false, raison: 'sacs_retires' });
  assert.equal(Number((await un(db, "SELECT count(*) n FROM climat_boutiques WHERE 'sac_de_sable' = ANY (cles)")).n), 0);
  assert.equal((await un(db, "SELECT count(*)::int n FROM climat_boutiques WHERE id = 'chasse-peche-psm'")).n, 0, 'boutique sans article supprimée');
  assert.deepEqual((await un(db, "SELECT cles FROM climat_boutiques WHERE id = 'armurerie-luthecia'")).cles, ['groupe_electrogene', 'bidon_carburant']);
  assert.equal(Number((await un(db, "SELECT count(*) n FROM climat_lieux_vente WHERE cle = 'sac_de_sable'")).n), 0);
  assert.equal((await un(db, "SELECT climat_objet_interne('sac_de_sable', 1) o")).o, null);
  assert.equal(Number((await un(db, "SELECT count(*) n FROM climat_parades_verifier_interne() WHERE cle = 'sac_de_sable'")).n), 0);
  assert.equal(Number((await un(db, "SELECT count(*) n FROM climat_lieux_vente WHERE cle = 'groupe_electrogene'")).n), 1, 'autres parades intactes');
});

test('état de catastrophe naturelle : en sommeil par défaut ; le réglage MJ le réveille', async () => {
  const db = await base();
  const id = await crue(db, 0, { heure: 0, minutes: 48 * 60 });
  await db.query("SELECT set_config('test.acteur', 'Ministre', false)");
  for (const appel of ['catastrophe_proposer($1)', 'catastrophe_etat($1)', 'catastrophe_declarer($1, true)']) {
    const r = (await un(db, 'SELECT ' + appel + ' r', [id])).r;
    assert.deepEqual(r, { ok: false, raison: 'catastrophe_en_sommeil' }, appel);
  }
  const m = (await un(db, `SELECT admin_climat_parametre_modifier('crue', 'republic', '{"catastrophe_active": true}') r`)).r;
  assert.equal(m.ok, true);
  assert.equal((await un(db, "SELECT catastrophe_active FROM climat_parametres WHERE type = 'crue'")).catastrophe_active, true);
  const p = (await un(db, 'SELECT catastrophe_proposer($1) r', [id])).r;
  assert.equal(p.ok, true); assert.equal(p.premier_ministre, true);
  assert.equal((await un(db, 'SELECT catastrophe_etat($1) r', [id])).r.ok, true);
  // Réveillée, la crue écrit de nouveau au ministre de l'Intérieur.
  await db.query('DELETE FROM courriers_crue_test');
  await un(db, 'SELECT climat_crue_appliquer_interne(e) n FROM climat_evenements e WHERE id = $1', [id]);
  assert.equal((await un(db, 'SELECT destinataire FROM courriers_crue_test')).destinataire, 'Ministre');
});

test('migration rejouable : deuxième passage sans erreur, chaque raccord posé une seule fois', async () => {
  const db = await base();
  await db.exec(sectionCrue());
  const compte = async (fn, marque) => {
    const d = (await un(db, 'SELECT pg_get_functiondef($1::regprocedure) d', [fn])).d;
    return d.split(marque).length - 1;
  };
  assert.equal(await compte('chantier_jour_traiter(text)', 'crue_chantier_jour_v1'), 1);
  assert.equal(await compte('catastrophe_proposer(bigint)', 'catastrophe_en_sommeil_v1'), 1);
  assert.equal(await compte('catastrophe_declarer(bigint,boolean)', 'catastrophe_en_sommeil_v1'), 1);
  assert.equal(await compte('catastrophe_etat(bigint)', 'catastrophe_en_sommeil_v1'), 1);
  assert.equal(await compte('admin_climat_parametre_modifier(text,text,jsonb)', 'catastrophe_active_v1'), 1);
  assert.equal(await compte('climat_consigne_interne(text,text,text)', 'crue_consigne_v2'), 1);
  assert.equal(await compte('climat_parades_verifier_interne()', 'crue_sans_sacs_v1'), 1);
});
