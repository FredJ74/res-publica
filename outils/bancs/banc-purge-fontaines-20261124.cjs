'use strict';
// Mission « Purge » du 24/11/2026, bloc F (images de fontaines) et D.5 (pas de fontaine à Starovka).
// F.1 : la fontaine de Luthécia est déplacée du parvis de l'Hôtel de Ville vers la place du Formulaire de la Liberté, un lieu
//       où l'on entre ; « Puiser de l'eau » s'y fait dans la pièce ; l'ancien emplacement est redirigé.
// D.5 : pas de fontaine à Starovka (désactivée, aucun renvoi dans le vide).
// F.2 : les images de Montrouge et de Port-Sainte-Marie sont branchées sur les fontaines déjà en base.
// Partie PGlite (migration 20261124130000) : PGLITE_DIR=<dossier de @electric-sql/pglite> ; partie statique sans dépendance.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const existe = f => fs.existsSync(path.join(root, f));

test('F.1 et F.2 : chaque image de fontaine citée par une migration existe (sauf Novomirsk, en attente ; Starovka retirée)', () => {
  const sql = ['migrations/20261122161000_points_eau_une_fontaine_par_ville.sql', 'migrations/20261124130000_fontaine_luthecia_place_formulaire.sql']
    .map(lire).join('\n');
  const images = [...new Set(sql.match(/images\/fontaines\/[a-z0-9-]+\.webp/g))];
  const attendues = ['images/fontaines/luthecia-fontaine-place-formulaire-liberte.webp', 'images/fontaines/montrouge-fontaine-place-du-rail.webp',
    'images/fontaines/psm-fontaine-place-armes.webp'];
  for (const f of attendues) { assert.ok(images.includes(f), f + ' citée'); assert.ok(existe(f), f + ' présente'); }
  const enAttente = ['images/fontaines/novomirsk-fontaine-place-peuple.webp'];   // F.3 : pas encore d'image, rien à créer
  const retirees = ['images/fontaines/luthecia-fontaine-hotel-de-ville.webp', 'images/fontaines/starovka-fontaine-mairie.webp'];
  for (const f of images) if (!attendues.includes(f) && !enAttente.includes(f) && !retirees.includes(f)) assert.fail('image inattendue ' + f);
  for (const f of enAttente) assert.ok(!existe(f), f + ' : en attente (ne pas inventer d\'image)');
});

test('F.1 : le navigateur range « Puiser de l’eau » dans les ordres de la pièce du lieu, et le routeur l’ouvre sans débit local', () => {
  const c = lire('plateau-climat.js'), r = lire('plateau-router.js');
  assert.match(c, /function ordresPointEauDuLieu\(buildingId\)/);
  assert.match(c, /RP_ORDRES_DYNAMIQUES\.push\(ordresPointEauDuLieu\)/);
  assert.match(c, /p\.batiment && p\.batiment === s\.currentBuilding/);
  assert.match(c, /!p\.batiment && p\.noeud === noeud/, 'un point d’eau de lieu ne s’affiche jamais dans la vue de rue');
  const debut = r.indexOf('function doOrder('), ligne = r.indexOf("fn === 'puiser_eau'"), pa = r.indexOf('// PA check', debut);
  assert.ok(debut > 0 && ligne > debut && ligne < pa, 'aiguillage avant tout contrôle ou débit de PA');
  // Le lieu existe bien comme lieu où l'on entre, avec sa pièce « place ».
  assert.match(lire('data.js'), /'place-formulaire-liberte': \{[\s\S]{0,400}rooms: \{\s*place: \{/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie serveur exécutée par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const TOM = '00000000-0000-0000-0000-000000000001';
const MIGRATIONS = ['20261121170000_point_eau_puiser_mairie_krasnov', '20261122161000_points_eau_une_fontaine_par_ville',
  '20261124130000_fontaine_luthecia_place_formulaire', '20261124135000_starovka_sans_canicule_ni_fontaine'];
async function base({ jusqua = MIGRATIONS.length } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/point-eau-pglite-socle.sql.txt'));
  await db.exec(`CREATE TABLE public.rue_noeuds_serveur (country text, city text, noeud text);
    INSERT INTO public.rue_noeuds_serveur VALUES ('soviet','ville_b','krasnov-place-ours'), ('republic','capitale','luthecia-hotel-de-ville'),
      ('republic','capitale','luthecia-stade-multimodal'), ('republic','ville_b','montrouge-vue-7'), ('republic','ville_a','psm-hotel-mairie-place'),
      ('soviet','capitale','novomirsk-vue-1'), ('soviet','ville_a','starovka-rue-mairie-marche');
    INSERT INTO public.rue_sorties_batiments VALUES ('republic','capitale','luthecia-stade-multimodal','place-formulaire-liberte');
    CREATE TABLE public.climat_evenements (id bigserial PRIMARY KEY, type text, pays text, ville text, debut timestamptz, annule boolean DEFAULT false);`);
  for (const m of MIGRATIONS.slice(0, jusqua)) await db.exec(lire('migrations/' + m + '.sql'));
  await db.query("UPDATE personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = NULL, current_street = 'luthecia-hotel-de-ville', pa = 10 WHERE name = 'Tom'");
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
async function comme(db, sql, p) { await db.exec(`SELECT set_config('test.uid', '${TOM}', false)`); return (await db.query(sql, p)).rows[0]; }
let n = 0; const req = () => '00000000-0000-4000-8000-' + String(++n).padStart(12, '0');

test('F.1 avant / après : on puisait sur le parvis de l’Hôtel de Ville ; désormais seulement sur la place, dans le lieu', async () => {
  const avant = await base({ jusqua: 2 });
  assert.equal((await comme(avant, 'SELECT public.point_eau_etat() r')).r.ok, true, 'avant : parvis');
  const db = await base();
  const parvis = (await comme(db, 'SELECT public.point_eau_etat() r')).r;
  assert.equal(parvis.ok, false); assert.equal(parvis.raison, 'pas_de_point_eau');
  // Devant la place (vue de rue) : pas encore dedans, pas de puisage.
  await db.query("UPDATE personnages_donnees SET current_street = 'luthecia-stade-multimodal' WHERE name = 'Tom'");
  assert.equal((await comme(db, 'SELECT public.point_eau_etat() r')).r.ok, false, 'dans la rue, devant la place : non');
  // Dans le lieu : oui, avec le nom et l'image fournis par Fred.
  await db.query("UPDATE personnages_donnees SET current_building = 'place-formulaire-liberte' WHERE name = 'Tom'");
  const e = (await comme(db, 'SELECT public.point_eau_etat() r')).r;
  assert.equal(e.ok, true);
  assert.equal(e.point.id, 'luthecia-fontaine-place-formulaire-liberte');
  assert.equal(e.point.image, 'images/fontaines/luthecia-fontaine-place-formulaire-liberte.webp');
  const p = (await comme(db, 'SELECT public.point_eau_puiser($1, 3) r', [req()])).r;
  assert.equal(p.ok, true); assert.equal(p.quantite, 3);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Tom'")).pa, 9);
  // Un autre lieu de la ville n'est pas une fontaine.
  await db.query("UPDATE personnages_donnees SET current_building = 'mairie-capitale' WHERE name = 'Tom'");
  assert.equal((await comme(db, 'SELECT public.point_eau_etat() r')).r.ok, false);
  // La fontaine de rue de Krasnov reste une fontaine de rue.
  await db.query("UPDATE personnages_donnees SET country = 'soviet', current_city = 'ville_b', current_building = NULL, current_street = 'krasnov-place-ours' WHERE name = 'Tom'");
  assert.equal((await comme(db, 'SELECT public.point_eau_etat() r')).r.ok, true);
});

test('F.1 : redirection de l’ancien emplacement, consigne de canicule, liste du navigateur, une fontaine par ville, rejouable', async () => {
  const db = await base();
  const ancien = await un(db, "SELECT actif, remplace_par FROM climat_points_eau WHERE id = 'luthecia-fontaine-hotel-de-ville'");
  assert.equal(ancien.actif, false); assert.equal(ancien.remplace_par, 'luthecia-fontaine-place-formulaire-liberte');
  // Aucune redirection ne pointe dans le vide.
  assert.equal((await un(db, `SELECT count(*)::int c FROM climat_points_eau p WHERE remplace_par IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM climat_points_eau q WHERE q.id = p.remplace_par AND q.actif)`)).c, 0);
  const c = (await un(db, "SELECT public.climat_consigne_interne('canicule','republic','capitale') c")).c;
  assert.match(c, /la fontaine de la place du Formulaire de la Liberté, à Luthécia/);
  assert.doesNotMatch(c, /Hôtel de Ville/);
  const l = (await un(db, 'SELECT public.climat_points_eau_lister() l')).l;
  const lu = l.points.find(x => x.id === 'luthecia-fontaine-place-formulaire-liberte');
  assert.equal(lu.batiment, 'place-formulaire-liberte'); assert.equal(lu.noeud, 'luthecia-stade-multimodal');
  assert.ok(!l.points.some(x => x.id === 'luthecia-fontaine-hotel-de-ville'));
  assert.equal((await un(db, 'SELECT count(*)::int c FROM (SELECT 1 FROM climat_points_eau WHERE actif GROUP BY pays, ville HAVING count(*) > 1) x')).c, 0);
  await db.exec(lire('migrations/20261124130000_fontaine_luthecia_place_formulaire.sql'));
  assert.equal((await un(db, 'SELECT count(*)::int c FROM climat_points_eau')).c, 7);
});

test('D.5 avant / après : Starovka avait une fontaine sur la place de la mairie ; elle n’en a plus, sans renvoi dans le vide', async () => {
  const avant = await base({ jusqua: 3 });
  await avant.query("UPDATE personnages_donnees SET country = 'soviet', current_city = 'ville_a', current_street = 'starovka-rue-mairie-marche' WHERE name = 'Tom'");
  assert.equal((await comme(avant, 'SELECT public.point_eau_etat() r')).r.ok, true, 'avant : fontaine de Starovka');
  const db = await base();
  await db.query("UPDATE personnages_donnees SET country = 'soviet', current_city = 'ville_a', current_street = 'starovka-rue-mairie-marche' WHERE name = 'Tom'");
  const e = (await comme(db, 'SELECT public.point_eau_etat() r')).r;
  assert.equal(e.ok, false); assert.equal(e.raison, 'pas_de_point_eau');
  const l = (await un(db, 'SELECT public.climat_points_eau_lister() l')).l;
  assert.ok(!l.points.some(x => x.ville === 'ville_a' && x.pays === 'soviet'), 'la liste du navigateur ne la renvoie plus');
  assert.doesNotMatch((await un(db, "SELECT public.climat_consigne_interne('canicule','soviet','ville_a') c")).c || '', /fontaine/);
  assert.equal((await un(db, "SELECT count(*)::int c FROM climat_villes_exclues WHERE type = 'canicule' AND pays = 'soviet' AND ville = 'ville_a'")).c, 1);
  // Aucun renvoi ne pointe dans le vide ; les cinq autres villes gardent leur fontaine.
  assert.equal((await un(db, `SELECT count(*)::int c FROM climat_points_eau p WHERE remplace_par IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM climat_points_eau q WHERE q.id = p.remplace_par AND q.actif)`)).c, 0);
  assert.equal((await un(db, 'SELECT count(DISTINCT (pays, ville))::int c FROM climat_points_eau WHERE actif')).c, 5);
  assert.match(lire('plateau-climat.js'), /sauf Starovka, qui n’en a pas/);
  await db.exec(lire('migrations/20261124135000_starovka_sans_canicule_ni_fontaine.sql'));
});
