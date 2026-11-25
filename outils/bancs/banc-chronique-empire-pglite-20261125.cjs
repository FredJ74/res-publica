'use strict';
// Mission de jour du 25/11/2026, bloc 2 (décision de Fred) : CHRONIQUE DE L'EMPIRE. Migration 20261125200000 dans PGlite.
// Un acte d'auteur non identifié n'expose jamais son nom ; l'auteur apparaît une fois identifié (ou arrêté / jugé pour cet
// acte) ; filtrage par pays (nationalité du lecteur) ; comptes de test exclus ; plus récent d'abord ; pagination.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-chronique-empire-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125200000_chronique_empire.sql';

test('écran : phrases courtes, auteur seulement s’il est rendu par le serveur, date au format unique', () => {
  const ctx = { window: {}, document: undefined };
  ctx.window = ctx; vm.createContext(ctx);
  // Module sans document : on lit ses phrases par un faux document minimal.
  const docMin = { readyState: 'complete', getElementById: () => null, querySelector: () => null, querySelectorAll: () => [], head: { appendChild() {} }, addEventListener() {} };
  ctx.document = docMin;
  ctx.WORLD = { soviet: { ville_b: { name: 'Krasnov' }, capitale: { name: 'Novomirsk' } } };
  ctx.BUILDINGS = { marche: { name: 'Marché', shortName: 'Marché' } };
  ctx.state = { country: 'soviet', currentCity: 'capitale' };
  vm.runInContext(lire('plateau-chronique-empire.js'), ctx);
  const C = ctx.RPChroniqueEmpire;
  const anonyme = C.phrase({ cat: 'acte', cle: 'fausse_rumeur', ville: 'ville_b', batiment: 'marche', auteur: null, params: { cible: 'Sovarka' } });
  assert.equal(anonyme, 'Une rumeur calomnieuse sur Sovarka circule à Marché, ville_b.'.replace('ville_b', 'ville_b'));
  const nomme = C.phrase({ cat: 'acte', cle: 'voler', ville: 'ville_b', batiment: 'marche', auteur: 'Ivan', params: {} });
  assert.match(nomme, /^<b>Ivan<\/b> a commis un vol à /);
  assert.doesNotMatch(C.phrase({ cat: 'acte', cle: 'voler', ville: 'ville_b', auteur: null, params: {} }), /Ivan|<b>/);
  assert.equal(C.phrase({ cat: 'foret', cle: 'meute', params: { issue: 'vaincu' } }), 'Une meute de loups a surgi dans la forêt de Krasnov. Elle a été repoussée.');
  assert.equal(C.phrase({ cat: 'public', params: { texte: '<script>x</script>' } }), '&lt;script&gt;x&lt;/script&gt;');
  const js = lire('plateau-chronique-empire.js');
  assert.match(js, /formaterHorodatageJournal\(q\)/);
  assert.match(js, /sbRpc\('chronique_empire_lire'/);
  assert.match(lire('plateau.html'), /plateau-chronique-empire\.js/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, nationalite text);
CREATE TABLE comptes_test (personnage text PRIMARY KEY);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION personnage_nationalite(p text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT coalesce(nationalite, country) FROM personnages_donnees WHERE name = p $$;
CREATE FUNCTION est_compte_test(p text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT p IS NOT NULL AND EXISTS (SELECT 1 FROM comptes_test WHERE personnage = p) $$;
CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, acte text, auteur text, cible text, cible_pnj text, pays text, ville text, batiment text, piece text,
  issue text, detecte boolean, identifie boolean, plainte_id text, cree_le timestamptz DEFAULT now(), archivee_le timestamptz);
CREATE TABLE detentions (id text PRIMARY KEY, country text, city text, nom text, raison text, qhs boolean DEFAULT false, motifs jsonb, created_at timestamptz DEFAULT now());
CREATE TABLE jugements (id text PRIMARY KEY, country text, city text, accuse text, motif text, peine text, data jsonb, created_at timestamptz DEFAULT now());
CREATE TABLE plaintes_en_cours (id text PRIMARY KEY, country text, city text, data text, created_at timestamptz DEFAULT now());
CREATE TABLE chronique_nationale (id text PRIMARY KEY, country text, type text, city text, personnages jsonb, libelle text, created_at timestamptz DEFAULT now());
CREATE TABLE climat_evenements (id bigserial PRIMARY KEY, type text, pays text, ville text, debut timestamptz, annule boolean DEFAULT false, alerte_le timestamptz);
CREATE TABLE batailles (id bigserial PRIMARY KEY, pays text, ville text, batiment text, piece text, debut_ts timestamptz, statut text, issue text,
  leader_a text, leader_b text, contexte jsonb);
CREATE TABLE sovarka_foret_rencontres (id bigserial PRIMARY KEY, bucheron text, creature text, statut text, cree_le timestamptz DEFAULT now());
INSERT INTO personnages_donnees VALUES ('Lecteur', 'republic', 'soviet'), ('Rep', 'republic', 'republic'), ('Ivan', 'soviet', 'soviet'), ('Arnie', 'soviet', 'soviet');
INSERT INTO comptes_test VALUES ('Arnie');`;
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG));
  return db;
}
const lireChronique = async (db, qui, args = '') => {
  await db.query("SELECT set_config('banc.moi', $1, false)", [qui]);
  return (await db.query('SELECT chronique_empire_lire(' + args + ') r')).rows[0].r;
};

test('anonymat : un acte non identifié n’expose jamais son auteur ; il apparaît une fois identifié, ou jugé pour cet acte', async () => {
  const db = await base();
  await db.exec(`INSERT INTO crim_affaires (acte, auteur, cible, pays, ville, batiment, detecte, identifie, plainte_id, cree_le) VALUES
    ('voler', 'Ivan', 'Olga', 'soviet', 'ville_b', 'marche', true, false, NULL, now() - interval '3 hours'),
    ('fausse_rumeur', 'Ivan', 'Sovarka', 'soviet', 'ville_b', 'marche', false, false, NULL, now() - interval '2 hours'),
    ('voler', 'Ivan', 'Olga', 'soviet', 'capitale', 'marche', false, false, NULL, now() - interval '1 hours')`);
  let r = await lireChronique(db, 'Lecteur');
  assert.equal(r.pays, 'soviet', 'nationalité du lecteur, pas sa position');
  const actes = r.faits.filter(x => x.cat === 'acte');
  assert.equal(actes.length, 2, 'l’acte ni détecté ni porté en plainte reste inconnu');
  assert.doesNotMatch(JSON.stringify(r), /Ivan/, 'jamais le nom, ni un indice partiel');
  assert.doesNotMatch(JSON.stringify(r), /Olga/, 'la victime n’est pas nommée');
  assert.equal(actes.find(x => x.cle === 'fausse_rumeur').params.cible, 'Sovarka', 'la cible d’une rumeur circule avec elle');
  // Identifié : nommé.
  await db.exec("UPDATE crim_affaires SET identifie = true WHERE acte = 'fausse_rumeur'");
  r = await lireChronique(db, 'Lecteur');
  assert.equal(r.faits.find(x => x.cle === 'fausse_rumeur').auteur, 'Ivan');
  assert.equal(r.faits.find(x => x.cle === 'voler').auteur ?? null, null, 'l’autre acte reste anonyme');
  // Jugé pour CET acte (sa plainte) : nommé ; jugé pour un autre : toujours anonyme.
  await db.exec("UPDATE crim_affaires SET plainte_id = 'affaire-soviet-ville_b-1-abc' WHERE acte = 'voler' AND detecte");
  await db.exec(`INSERT INTO jugements VALUES ('j1', 'soviet', 'ville_b', 'Ivan', 'autre chose', '10 jours', '{"plainte":"affaire-autre"}', now() - interval '10 minutes')`);
  r = await lireChronique(db, 'Lecteur');
  assert.equal(r.faits.find(x => x.cat === 'acte' && x.cle === 'voler').auteur ?? null, null);
  await db.exec(`UPDATE jugements SET data = '{"plainte":"affaire-soviet-ville_b-1-abc"}'`);
  r = await lireChronique(db, 'Lecteur');
  assert.equal(r.faits.find(x => x.cat === 'acte' && x.cle === 'voler').auteur, 'Ivan');
  assert.equal(r.faits.find(x => x.cat === 'verdict').auteur, 'Ivan', 'le verdict est public');
});

test('filtre par pays, comptes de test exclus, plus récent d’abord, pagination, joueur seulement', async () => {
  const db = await base();
  await db.exec(`
    INSERT INTO chronique_nationale VALUES ('n1', 'soviet', 'conference_presse', 'capitale', '[]', 'Le maire annonce de nouveaux bancs.', now() - interval '5 hours'),
      ('n2', 'republic', 'subvention_publique', 'capitale', '[]', 'Subvention à Luthécia.', now() - interval '4 hours'),
      ('n3', 'soviet', 'conference_presse', 'capitale', '["Arnie"]', 'Arnie parle.', now() - interval '3 hours');
    INSERT INTO detentions VALUES ('d1', 'soviet', 'ville_b', 'Ivan', 'Vol d''explosifs militaires', true, '[]', now() - interval '2 hours'),
      ('d2', 'soviet', 'ville_b', 'Arnie', 'Test', false, '[]', now() - interval '90 minutes');
    INSERT INTO climat_evenements (type, pays, ville, debut, alerte_le) VALUES ('blizzard', 'soviet', 'ville_a', now() - interval '1 hour', now() - interval '3 days'),
      ('canicule', 'soviet', 'ville_b', now() + interval '1 day', now());
    INSERT INTO batailles (pays, ville, batiment, debut_ts, statut, leader_a, leader_b, contexte) VALUES
      ('soviet', 'ville_b', 'bar-tabac', now() - interval '30 minutes', 'terminee', 'Ivan', 'PNJ', '{"type":"rixe"}'),
      ('soviet', 'ville_b', 'zone-production', now() - interval '20 minutes', 'terminee', 'Ivan', NULL, '{"type":"faune"}');
    INSERT INTO sovarka_foret_rencontres (bucheron, creature, statut, cree_le) VALUES ('Ivan', 'ours', 'fuite', now() - interval '10 minutes'),
      ('Ivan', 'olga', 'nourri', now() - interval '5 minutes'), ('Arnie', 'meute', 'vaincu', now() - interval '4 minutes');
    INSERT INTO plaintes_en_cours VALUES ('p1', 'soviet', 'ville_b', '{"cible":"Ivan","motif":"Vol","origine":"police"}', now() - interval '6 hours'),
      ('p2', 'soviet', 'ville_b', '{"cible":"Ivan","motif":"Plainte privée","origine":"plainte"}', now() - interval '7 hours');`);
  const r = await lireChronique(db, 'Lecteur');
  const cats = r.faits.map(x => x.cat + ':' + x.cle);
  assert.deepEqual(cats, ['foret:ours', 'bagarre:bagarre', 'climat:blizzard', 'arrestation:qhs', 'public:conference_presse', 'proces:affaire_transmise']);
  assert.doesNotMatch(JSON.stringify(r), /Arnie|Luthécia|Plainte privée/, 'compte de test, autre pays, plainte privée : absents');
  assert.equal(r.faits.find(x => x.cat === 'bagarre').auteur ?? null, null, 'bagarre anonyme');
  const quand = r.faits.map(x => Date.parse(x.quand));
  assert.deepEqual([...quand].sort((a, b) => b - a), quand, 'du plus récent au plus ancien');
  const page2 = await lireChronique(db, 'Lecteur', `'${r.faits[2].quand}'::timestamptz, 2`);
  assert.deepEqual(page2.faits.map(x => x.cat), ['arrestation', 'public']);
  // Un lecteur de Républia ne voit que la Républia.
  const rep = await lireChronique(db, 'Rep');
  assert.deepEqual(rep.faits.map(x => x.ref), ['public-n2']);
  // Ni anonyme ni visiteur sans personnage.
  assert.equal((await lireChronique(db, '')).raison, 'acteur_non_authentifie');
  await assert.rejects(db.query('SET ROLE anon; SELECT chronique_empire_lire();'));
  await db.exec('RESET ROLE');
  await db.exec(lire(MIG));
});
