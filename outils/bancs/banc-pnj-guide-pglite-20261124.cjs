'use strict';
// Purge A.10 (Fred, 24/11/2026) : PNJ guide des nouveaux joueurs, migration 20261124106000 dans PGlite.
// Rien pendant la première heure ; au plus un message par jour (deux voix confondues), 3 par voix, 7 jours ; la journaliste
// au plus tôt le lendemain de l'interview (Vera Pravdina en Sovarka, Jodie Moitout en Républia), l'habitant jamais le
// même jour ; référents lus dans pnj_referents (un référent ajouté plus tard apparaît) ; tirage du commerce sans compte
// de test ni commerce inactif, jamais deux fois le même ; « Je me débrouille, merci » coupe tout ; 5 réponses par jour.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-pnj-guide-pglite-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const M = ['migrations/20261123140000_accueil_interview.sql', 'migrations/20261124100000_comptes_test.sql',
  'migrations/20261124101000_accueil_bienvenue.sql', 'migrations/20261124102000_accueil_calendrier.sql', 'migrations/20261124106000_pnj_guide.sql'];

test('les habitants guides existent dans data.js et dans les fiches DeepSeek ; pistes sans nom de parti', () => {
  const m = lire(M[4]), data = lire('data.js'), fiches = lire('api/_pnj-personnalites.js');
  const habitants = [...m.matchAll(/\('(republic|soviet)', '(capitale|ville_a|ville_b)', '([^']+)', '(guide_[a-z_]+)', '([^']+)'\)/g)];
  assert.equal(habitants.length, 6, 'un par ville jouable');
  for (const [, , , nom, profil] of habitants) {
    assert.ok(data.includes("profilId: '" + profil + "'") || data.includes("profilId:'" + profil + "'"), profil + ' placé dans data.js');
    assert.ok(fiches.includes("'" + profil + "'"), profil + ' a sa fiche');
    assert.ok(data.includes(nom.replace(/'/g, '’') + ' (PNJ)') || data.includes(nom + ' (PNJ)'), nom);
  }
  assert.doesNotMatch(m.replace(/^--.*$/gm, ''), /goulag/i);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = { bernard: '00000000-0000-0000-0000-000000000001', tom: '00000000-0000-0000-0000-000000000002',
  ivan: '00000000-0000-0000-0000-000000000003', arnie: '00000000-0000-0000-0000-000000000004', olga: '00000000-0000-0000-0000-000000000005' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/accueil-interview-pglite-socle.sql.txt'));
  await db.exec(`
    ALTER TABLE personnages_donnees ADD COLUMN current_city text, ADD COLUMN created_at timestamptz DEFAULT now(),
      ADD COLUMN career text, ADD COLUMN archetype text, ADD COLUMN stats jsonb, ADD COLUMN poste jsonb, ADD COLUMN resources jsonb;
    CREATE TABLE presences (name text PRIMARY KEY, country text, city text, building_id text, room_id text, updated_at timestamptz DEFAULT now());
    CREATE TABLE pnj_referents (referent_id text PRIMARY KEY, domaine text, pays text);
    INSERT INTO pnj_referents VALUES ('kouzma_lapchine', 'religion — Eglise, Krasnov', 'soviet'),
      ('sayana_tsydypova', 'démarches municipales — mairie de Starovka', 'soviet'), ('nathalie_boulot', 'emploi — Bureau National de l''Emploi', 'republic');
    CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb);
    CREATE TABLE cycles_electoraux (id text PRIMARY KEY, country text, poste_id text, data text, city text);
    CREATE TABLE organisations (id text PRIMARY KEY, country_origine text, data text);
    INSERT INTO organisations VALUES ('p1', 'soviet', '{"type":"politique","nom":"Parti du Tracteur Rouge"}');
    INSERT INTO cycles_electoraux VALUES ('c1', 'soviet', 'maire', '{"phase":"campagne"}', 'ville_b');
    CREATE TABLE messages_chat (id text PRIMARY KEY, conversation_id text NOT NULL, auteur text NOT NULL, message text NOT NULL, salon boolean DEFAULT false, created_at timestamptz DEFAULT now());
    -- Commerces de joueurs : Olga (active), Arnie (compte de test), Ivan (inactif : absent depuis 5 jours), un sans stock.
    INSERT INTO personnages (name, user_id, country) VALUES ('Olga', '${U.olga}', 'republic'), ('Arnie', '${U.arnie}', 'republic'), ('Ivan', '${U.ivan}', 'republic');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at) VALUES ('Olga', '${U.olga}', 'republic', 10, 'capitale', now() - interval '30 days'),
      ('Arnie', '${U.arnie}', 'republic', 10, 'capitale', now() - interval '30 days'), ('Ivan', '${U.ivan}', 'republic', 10, 'capitale', now() - interval '30 days');
    INSERT INTO presences (name, updated_at) VALUES ('Olga', now() - interval '1 day'), ('Arnie', now()), ('Ivan', now() - interval '5 days');
    INSERT INTO entreprises VALUES
      ('f-olga', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Olga","enseigne":"La Bonne Table","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale","buildingId":"centre-commercial"},"stockReferences":{"r1":4}}'),
      ('f-olga2', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Olga","enseigne":"Le Comptoir","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale","buildingId":"centre-commercial"},"stockReferences":{}}'),
      ('f-arnie', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Arnie","enseigne":"Chez Toto","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale"},"stockReferences":{"r":9}}'),
      ('f-ivan', '{"type":"fonds_commerce","statut":"actif","proprietaire":"Ivan","enseigne":"Le Samovar","typesAutorises":["bar-restauration"],"implantation":{"country":"republic","city":"capitale"},"stockReferences":{"r":9}}');`);
  for (const f of M) await db.exec(lire(f));
  // Jour de Paris piloté par le banc.
  await db.exec(`CREATE OR REPLACE FUNCTION public.guide_jour_interne() RETURNS date LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('test.jour', true), ''), '2026-12-01')::date $$;`);
  await db.exec(`INSERT INTO personnages (name, user_id, country) VALUES ('Bernard', '${U.bernard}', 'soviet'), ('Tom', '${U.tom}', 'republic');
    INSERT INTO personnages_donnees (name, user_id, country, pa, current_city, created_at, career) VALUES
      ('Bernard', '${U.bernard}', 'soviet', 10, 'ville_b', now() + interval '1 second', 'worker'),
      ('Tom', '${U.tom}', 'republic', 10, 'capitale', now() + interval '1 second', 'business');`);
  return db;
}
async function comme(db, uid, sql) {
  await db.exec(`SET test.uid = '${uid}'; SET ROLE authenticated;`);
  try { return (await db.query(sql)).rows; } finally { await db.exec('RESET ROLE; RESET test.uid;'); }
}
const rpc = async (db, uid, appel) => (await comme(db, uid, `SELECT public.${appel} r`))[0].r;
const jour = (db, j) => db.exec(`SET test.jour = '${j}'`);
async function premiereHeureFinie(db, uid, nom) {
  await rpc(db, uid, 'accueil_etat()');
  await db.query("UPDATE accueil_personnages SET heure_finie_le = now(), secondes_jeu = 3600 WHERE personnage = $1", [nom]);
}
const publier = async (db, id) => (await db.query('SELECT public.guide_publier_service($1, $2) r', [id, 'Un conseil, une piste.'])).rows[0].r;

test('rien pendant la première heure ; ensuite l’habitant de la ville, une fois par jour ; référent lu en base', async () => {
  const db = await base();
  await rpc(db, U.bernard, 'accueil_etat()');
  assert.equal((await rpc(db, U.bernard, 'guide_reserver()')).raison, 'premiere_heure');
  await premiereHeureFinie(db, U.bernard, 'Bernard');
  await jour(db, '2026-12-01');
  const r = await rpc(db, U.bernard, 'guide_reserver()');
  assert.equal(r.ok, true);
  assert.deepEqual([r.voix, r.pnj, r.profil], ['habitant', 'Fiodor Medvedkine', 'guide_fiodor_medvedkine'], 'pas d’interview : l’habitant de Krasnov');
  assert.equal(r.monde.partis, 1); assert.equal(r.monde.elections_en_cours, 1);
  assert.doesNotMatch(JSON.stringify(r), /Tracteur Rouge/, 'aucun nom de parti transmis à l’IA');
  // Défaut de Sovarka : démarches municipales → référent pris dans pnj_referents.
  assert.equal(r.piste.referent, 'sayana_tsydypova');
  assert.equal((await rpc(db, U.bernard, 'guide_reserver()')).id, r.id, 'même réservation tant qu’elle n’est pas publiée');
  assert.equal((await publier(db, r.id)).ok, true);
  const msg = (await db.query('SELECT conversation_id, auteur, id FROM messages_chat')).rows;
  assert.deepEqual(msg, [{ conversation_id: 'pnj:Fiodor Medvedkine__Bernard', auteur: 'pnj:Fiodor Medvedkine', id: 'guide-' + r.id }]);
  assert.equal((await rpc(db, U.bernard, 'guide_reserver()')).raison, 'deja_ecrit_aujourdhui', 'au plus un par jour');
  // Un référent ajouté plus tard (bloc G) apparaît de lui-même.
  await db.exec("INSERT INTO pnj_referents VALUES ('nouvelle_referente', 'partis de Sovarka — salle des partis de Krasnov', 'soviet')");
  await jour(db, '2026-12-02');
  const r2 = await rpc(db, U.bernard, 'guide_reserver()');
  assert.equal(r2.piste.referent, 'nouvelle_referente');
});

test('Vera Pravdina en Sovarka, Jodie Moitout en Républia, le lendemain de l’interview ; l’habitant jamais le même jour', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.bernard, 'Bernard');
  await premiereHeureFinie(db, U.tom, 'Tom');
  await db.query("UPDATE accueil_personnages SET chemin = 'politique', chemin_choisi_le = '2026-12-01 10:00+01', etat_interview = 'faite'");
  await jour(db, '2026-12-01');
  const memeJour = await rpc(db, U.bernard, 'guide_reserver()');
  assert.equal(memeJour.voix, 'habitant', 'pas la journaliste le jour de l’interview');
  await db.exec('DELETE FROM guide_messages');
  await jour(db, '2026-12-02');
  const v = await rpc(db, U.bernard, 'guide_reserver()');
  assert.deepEqual([v.voix, v.pnj], ['journaliste', 'Vera Pravdina']);
  const j = await rpc(db, U.tom, 'guide_reserver()');
  assert.deepEqual([j.voix, j.pnj], ['journaliste', 'Jodie Moitout']);
  await publier(db, v.id);
  await jour(db, '2026-12-03');
  const h = await rpc(db, U.bernard, 'guide_reserver()');
  assert.equal(h.voix, 'habitant', 'les voix alternent');
});

test('plafonds : 3 par voix, plus rien après 7 jours ; tirage du commerce sans compte de test ni inactif, jamais deux fois', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.tom, 'Tom');
  await db.query("UPDATE accueil_personnages SET chemin = 'belle_vie', chemin_choisi_le = '2026-11-30 10:00+01', etat_interview = 'faite' WHERE personnage = 'Tom'");
  const commerces = [], voix = [];
  for (let d = 1; d <= 8; d++) {
    await jour(db, '2026-12-0' + d);
    const r = await rpc(db, U.tom, 'guide_reserver()');
    if (!r.ok) { voix.push(r.raison); continue; }
    voix.push(r.voix);
    if (r.piste.commerce) commerces.push(r.piste.commerce.id);
    await publier(db, r.id);
  }
  assert.deepEqual(voix.slice(0, 6).sort(), ['habitant', 'habitant', 'habitant', 'journaliste', 'journaliste', 'journaliste']);
  assert.ok(voix.slice(6).every(x => x === 'plus_de_piste' || x === 'personne_n_ecrit'), 'plafond de 3 par voix : ' + voix);
  assert.deepEqual(commerces, ['f-olga'], 'seul commerce actif et hors compte de test, cité une seule fois');
  // 7 jours après l'inscription : plus rien, même les réponses.
  await db.query("UPDATE personnages_donnees SET created_at = now() - interval '8 days' WHERE name = 'Tom'");
  assert.equal((await rpc(db, U.tom, 'guide_reserver()')).raison, 'periode_terminee');
  assert.equal((await rpc(db, U.tom, "guide_reponse_autoriser('Jodie Moitout', 'Merci !')")).raison, 'periode_terminee');
});

test('réponses : 5 par jour et par PNJ, hors plafonds ; « Je me débrouille, merci » coupe tout', async () => {
  const db = await base();
  await premiereHeureFinie(db, U.bernard, 'Bernard');
  await jour(db, '2026-12-01');
  const r = await rpc(db, U.bernard, 'guide_reserver()');
  await publier(db, r.id);
  assert.equal((await rpc(db, U.bernard, "guide_reponse_autoriser('Zinaïda Otcheredova', 'Bonjour')")).raison, 'conversation_inconnue');
  for (let i = 0; i < 5; i++) {
    const a = await rpc(db, U.bernard, "guide_reponse_autoriser('Fiodor Medvedkine', 'Et ensuite <b>?</b>')");
    assert.equal(a.ok, true);
    assert.equal((await db.query('SELECT public.guide_reponse_publier_service($1, $2, $3) r', ['Bernard', 'Fiodor Medvedkine', 'Va voir la mairie.'])).rows[0].r.ok, true);
  }
  assert.equal((await rpc(db, U.bernard, "guide_reponse_autoriser('Fiodor Medvedkine', 'Encore ?')")).raison, 'reponses_epuisees');
  assert.equal((await db.query("SELECT count(*)::int n FROM messages_chat WHERE message LIKE '%&lt;b&gt;%'")).rows[0].n, 5, 'HTML échappé');
  assert.equal((await rpc(db, U.bernard, 'guide_etat_lire()')).a_ecrire, false, 'les réponses ne rouvrent pas le message du jour');
  await rpc(db, U.bernard, 'guide_arreter()');
  await jour(db, '2026-12-02');
  assert.equal((await rpc(db, U.bernard, 'guide_reserver()')).raison, 'arrete');
  assert.equal((await rpc(db, U.bernard, "guide_reponse_autoriser('Fiodor Medvedkine', 'Allô ?')")).raison, 'arrete');
  assert.equal((await rpc(db, U.bernard, 'guide_etat_lire()')).arrete, true);
  // Le joueur ne publie jamais lui-même au nom d'un PNJ, ni ne lit la liste des noms.
  await assert.rejects(comme(db, U.bernard, "SELECT public.guide_publier_service(1, 'x')"));
  await assert.rejects(comme(db, U.bernard, 'SELECT public.guide_noms_interdits()'));
});
