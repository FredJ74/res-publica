'use strict';
// Climat — décisions de Fred du 21/11/2026 sur les quatre questions (migration 20261121130000), éprouvées dans un vrai
// PostgreSQL local (PGlite, en mémoire) : la production est en pause (goulag), rien n'y est écrit ni lu.
// PGlite : PGLITE_DIR=<dossier contenant node_modules/@electric-sql/pglite> (la CI l'installe dans un dossier temporaire).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
const { PGlite } = charger('@electric-sql/pglite');

const H = 3600e3;
// Calendrier de départ (jours relatifs à aujourd'hui, minuit heure de Paris, comme avant la décision Q1).
const GRAINE = `
  CREATE OR REPLACE FUNCTION pg_temp.j(n integer) RETURNS timestamptz LANGUAGE sql AS $$
    SELECT public.climat_minuit_interne((now() AT TIME ZONE 'Europe/Paris')::date + n) $$;
  -- Brouillard en cours à Luthécia : immobile ; rien d'autre avant sa fin + 48 h.
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode, alerte_le) VALUES
    (100, 'brouillard', 'republic', 'capitale', now() - interval '1 hour', now() + interval '5 hours', 'M0', now() - interval '2 days');
  -- Brouillard déjà annoncé dans 1 jour (sans heure) : annoncé de nouveau, avec l'heure.
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode, alerte_le) VALUES
    (101, 'brouillard', 'republic', 'ville_a', pg_temp.j(1), pg_temp.j(1) + interval '6 hours', 'M1', now());
  -- Deux brouillards le même mois dans la même ville : un seul reste.
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode) VALUES
    (102, 'brouillard', 'republic', 'ville_b', pg_temp.j(4), pg_temp.j(4) + interval '6 hours', 'M2'),
    (103, 'brouillard', 'republic', 'ville_b', pg_temp.j(25), pg_temp.j(25) + interval '6 hours', 'M2');
  -- Crue propagée (3 villes) aux jours 10, 12, 14 : doit rester à sa date.
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode, lieux) VALUES
    (110, 'crue', 'republic', 'ville_b', pg_temp.j(10), pg_temp.j(10) + interval '6 hours', 'T9', '[{"batiment":"zone-production","nom":"la zone"}]'),
    (111, 'crue', 'republic', 'capitale', pg_temp.j(12), pg_temp.j(12) + interval '6 hours', 'T9', '[]'),
    (112, 'crue', 'republic', 'ville_a', pg_temp.j(14), pg_temp.j(14) + interval '6 hours', 'T9', '[]');
  -- Brouillard qui tombe pendant la crue : il cède la place (reporté après la crue + 48 h).
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode) VALUES
    (113, 'brouillard', 'republic', 'capitale', pg_temp.j(11), pg_temp.j(11) + interval '6 hours', 'M3');
  -- Orage propagé qui chevauche la crue : décalé en bloc après elle.
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode) VALUES
    (120, 'orage', 'republic', 'ville_b', pg_temp.j(13), pg_temp.j(13) + interval '6 hours', 'T9'),
    (121, 'orage', 'republic', 'ville_a', pg_temp.j(15), pg_temp.j(15) + interval '6 hours', 'T9');
  -- Sovarka : blizzard (24 h) et brouillard le même jour : le blizzard garde sa date.
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode) VALUES
    (130, 'blizzard', 'soviet', 'ville_a', pg_temp.j(6), pg_temp.j(7), 'mandat-1'),
    (131, 'brouillard', 'soviet', 'capitale', pg_temp.j(6), pg_temp.j(6) + interval '6 hours', 'M4');
  INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode, alerte_le) VALUES
    (132, 'brouillard', 'soviet', 'ville_b', pg_temp.j(1), pg_temp.j(1) + interval '6 hours', 'M5', now() - interval '1 day');
  SELECT setval('climat_evenements_id_seq', 1000);
`;

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/climat-pglite-socle.sql.txt'));
  await db.exec(GRAINE);
  await db.exec(lire('migrations/20261121130000_climat_horaire_cadence_catastrophe_sacs.sql'));
  return db;
}
const lignes = async (db, sql, p) => (await db.query(sql, p)).rows;
const ev = async (db, id) => (await lignes(db, 'SELECT * FROM climat_evenements WHERE id = $1', [id]))[0];

test('Q1 : heure de début au hasard (heure pleine), durée conservée, alerte avec l’heure exacte', async () => {
  const db = await base();
  const futurs = await lignes(db, `SELECT id, type, debut, fin, debut_prevu, extract(minute FROM debut AT TIME ZONE 'Europe/Paris') AS mi,
                                         extract(hour FROM debut AT TIME ZONE 'Europe/Paris') AS h FROM climat_evenements WHERE NOT annule AND now() < debut`);
  assert.ok(futurs.length >= 9);
  for (const e of futurs) {
    assert.equal(Number(e.mi), 0, `${e.id} : heure pleine`);
    const duree = (new Date(e.fin) - new Date(e.debut)) / H;
    assert.equal(duree, e.type === 'blizzard' ? 24 : 6, `${e.id} : durée`);
  }
  assert.ok(new Set(futurs.map(e => Number(e.h))).size > 1, 'les heures varient');
  // Le brouillard en cours ne bouge pas.
  const enCours = await ev(db, 100);
  assert.ok(new Date(enCours.debut) < new Date());
  // Déjà annoncé et imminent, sans conflit (132, Sovarka) : il a eu son préavis, il garde date, heure et annonce.
  const b132 = await ev(db, 132);
  assert.notEqual(b132.alerte_le, null);
  assert.equal(new Date(b132.debut).getUTCMinutes() + new Date(b132.debut).getUTCSeconds(), 0);
  // Annoncé mais en conflit avec le brouillard en cours (101) : déplacé, à annoncer de nouveau, au moins 48 h plus tard.
  const b101 = await ev(db, 101);
  assert.equal(b101.alerte_le, null);
  assert.ok(+new Date(b101.debut) >= Date.now() + 48 * H);
  // Aucun événement non annoncé ne commence moins de 48 h après maintenant.
  const tot = await lignes(db, "SELECT id FROM climat_evenements WHERE NOT annule AND alerte_le IS NULL AND debut > now() AND debut < now() + interval '48 hours'");
  assert.deepEqual(tot, [], 'jamais sans préavis de 48 h');
  const txt = (await lignes(db, 'SELECT climat_texte_alerte_interne(e) t FROM climat_evenements e WHERE id = 102'))[0].t;
  assert.match(txt, /^Brouillard annoncé à Montrouge le \d\d\/\d\d à \d\d h 00 \(heure du jeu\)\. Consigne brouillard\./);
  // Publication 48 h avant : l'article porte le jour ET l'heure dans sa clé.
  await db.exec("INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode) VALUES (140, 'orage', 'soviet', 'ville_b', date_trunc('hour', now()) + interval '49 hours', date_trunc('hour', now()) + interval '55 hours', 'Y')");
  await db.query('SELECT climat_alertes_publier_interne()');
  const art = await lignes(db, "SELECT id, texte FROM journal_articles_en_attente WHERE id LIKE 'climat-140-%'");
  assert.equal(art.length, 1);
  assert.match(art[0].id, /^climat-140-\d{12}$/);
  assert.match(art[0].texte, / à \d\d h 00 \(heure du jeu\)\./);
  // Nouveaux événements : créés directement avec une heure au hasard.
  for (let i = 0; i < 40; i++) await db.query("SELECT climat_creer_interne('orage', 'soviet', 'ville_b', (now() AT TIME ZONE 'Europe/Paris')::date + 90, 'X', 'mj')");
  const heures = await lignes(db, "SELECT DISTINCT extract(hour FROM debut AT TIME ZONE 'Europe/Paris') h FROM climat_evenements WHERE periode = 'X'");
  assert.ok(heures.length >= 10, 'tirage uniforme sur 24 heures (au moins 10 heures distinctes sur 40 tirages)');
});

test('Q2 : brouillard 1 par mois et par ville ; crue à sa date ; un seul épisode à la fois, 48 h d’écart', async () => {
  const db = await base();
  assert.equal((await lignes(db, "SELECT par_periode FROM climat_parametres WHERE type = 'brouillard'")).every(r => r.par_periode === 1), true);
  // Deux brouillards le même mois à Montrouge : le premier reste, l'autre est annulé (jamais supprimé).
  assert.equal((await ev(db, 102)).annule, false);
  assert.equal((await ev(db, 103)).annule, true);
  // La crue garde sa date prévue (aucun décalage).
  for (const id of [110, 111, 112]) { const e = await ev(db, id); assert.equal(+new Date(e.debut), +new Date(e.debut_prevu), `crue ${id} à sa date`); }
  // Brouillard et orage qui tombaient pendant la crue : après elle (+ 48 h), l'orage gardant son écart interne.
  const fCrue = Math.max(...await Promise.all([110, 111, 112].map(async id => +new Date((await ev(db, id)).fin))));
  const o1 = await ev(db, 120), o2 = await ev(db, 121), b = await ev(db, 113);
  assert.ok(+new Date(o1.debut) >= fCrue + 48 * H || +new Date(b.debut) >= fCrue + 48 * H);
  assert.equal(+new Date(o2.debut) - +new Date(o1.debut), +new Date(o2.debut_prevu) - +new Date(o1.debut_prevu), 'orage décalé en bloc');
  // Crue, orage, canicule, blizzard passent avant les brouillards : le blizzard soviétique garde sa date.
  const bz = await ev(db, 130);
  assert.equal(+new Date(bz.debut), +new Date(bz.debut_prevu));
  // Aucun recouvrement d'épisodes dans un pays (fin + 48 h), commencés compris.
  for (const pays of ['republic', 'soviet']) {
    const ep = await lignes(db, `SELECT CASE WHEN c.frequence = 'trimestre_propage' THEN e.type || e.periode ELSE 'ev' || e.id END k,
                                        min(e.debut) d0, max(e.fin) f1 FROM climat_evenements e JOIN climat_parametres c ON c.type = e.type AND c.pays = e.pays
                                  WHERE e.pays = $1 AND NOT e.annule GROUP BY 1 ORDER BY 2`, [pays]);
    for (let i = 1; i < ep.length; i++) assert.ok(+new Date(ep[i].d0) >= +new Date(ep[i - 1].f1) + 48 * H, `${pays} : ${ep[i].k} après ${ep[i - 1].k}`);
  }
  // Recalcul à chaque passage : stable (aucun nouveau décalage quand rien ne change).
  assert.equal((await lignes(db, "SELECT climat_espacer_interne('republic') n"))[0].n, 0);
  // Le planificateur ne crée plus qu'un brouillard par ville et par mois.
  await db.query('SELECT climat_planifier_interne()');
  const parMois = await lignes(db, "SELECT pays, ville, periode, count(*) n FROM climat_evenements WHERE type = 'brouillard' AND NOT annule GROUP BY 1, 2, 3");
  assert.ok(parMois.length > 0 && parMois.every(r => Number(r.n) === 1), JSON.stringify(parMois));
});

test('Q3 : catastrophe naturelle, une seule option : sinistrés non protégés ayant perdu des stocks, à 50 %', async () => {
  const db = await base();
  await db.exec(`
    INSERT INTO personnages VALUES ('Ministre', '00000000-0000-0000-0000-000000000001'), ('Premier', '00000000-0000-0000-0000-000000000002');
    INSERT INTO personnages_donnees (name, country, poste) VALUES ('Ministre', 'republic', '{"id":"min_int"}'), ('Premier', 'republic', '{"id":"pm"}');
    INSERT INTO caisses_batiments VALUES ('republic_gouvernement-pm', '{"solde": 1000}');
    INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode, effets_le, alerte_le)
      VALUES (500, 'crue', 'republic', 'ville_b', now() - interval '8 hours', now() - interval '2 hours', 'Z', now() - interval '8 hours', now() - interval '3 days');
    INSERT INTO entreprises VALUES ('c-protege', '{"caisse": 0}'), ('c-perdu', '{"caisse": 0}'), ('c-vide', '{"caisse": 0}');
    INSERT INTO climat_crue_pertes (evenement, cible, pays, ville, batiment, proprietaire, protege, valeur) VALUES
      (500, 'c-protege', 'republic', 'ville_b', 'zone-production', 'A', true, 0),
      (500, 'c-perdu', 'republic', 'ville_b', 'zone-production', 'B', false, 300),
      (500, 'c-vide', 'republic', 'ville_b', 'zone-production', 'C', false, 0);`);
  await db.query("SELECT set_config('test.uid', '00000000-0000-0000-0000-000000000001', false)");
  const p = (await lignes(db, 'SELECT catastrophe_proposer(500) r'))[0].r;
  assert.equal(p.ok, true); assert.equal(p.sinistres, 1); assert.equal(Number(p.cout), 150);
  const mail = (await lignes(db, "SELECT corps FROM mails_test WHERE destinataire = 'Premier'"))[0].corps;
  assert.match(mail, /1 sinistré\(s\).*indemnisés à 50 % de leurs pertes, soit 150(\.00)?\. Vous restez libre de ne pas la déclarer\./);
  assert.ok(!/sacs de sable|Deux options/.test(mail));
  await db.query("SELECT set_config('test.uid', '00000000-0000-0000-0000-000000000002', false)");
  const etat = (await lignes(db, 'SELECT catastrophe_etat(500) r'))[0].r;
  assert.equal(etat.sinistres, 1); assert.ok(!('cout_sacs' in etat) && !('sinistres_sacs' in etat), 'plus d’option « sacs »');
  const d = (await lignes(db, 'SELECT catastrophe_declarer(500, false) r'))[0].r;   // l'ancien paramètre n'a plus d'effet
  assert.equal(d.ok, true); assert.equal(Number(d.cout), 150);
  const caisses = Object.fromEntries((await lignes(db, 'SELECT id, data FROM entreprises')).map(r => [r.id, Number(r.data.caisse)]));
  assert.deepEqual(caisses, { 'c-protege': 0, 'c-perdu': 150, 'c-vide': 0 }, 'ni le lieu protégé ni le lieu sans stock ne sont indemnisés');
  assert.equal((await ev(db, 500)).type, 'crue');
  assert.equal((await lignes(db, 'SELECT option FROM climat_catastrophes WHERE evenement = 500'))[0].option, 'tous');
  assert.match((await lignes(db, "SELECT texte FROM evenements_globaux WHERE texte LIKE '🏛️%'"))[0].texte, /les sinistrés de la crue sont indemnisés à 50 % des stocks perdus\./);
});

test('Q4 : un sac protège entièrement pour une crue ; règle du 19/11 effacée', async () => {
  const db = await base();
  await db.exec(`
    INSERT INTO personnages VALUES ('Patron', '00000000-0000-0000-0000-000000000003');
    INSERT INTO personnages_donnees (name, country, current_city, current_building, pa, inventory)
      VALUES ('Patron', 'republic', 'ville_b', 'zone-production', 10, '[{"stackKey":"sac_de_sable","qty":2}]');
    INSERT INTO entreprises VALUES
      ('protege', '{"country":"republic","city":"ville_b","buildingId":"zone-production","proprietaire":"pj:Patron","stockProduits":{"bois":100}}'),
      ('expose', '{"country":"republic","city":"ville_b","buildingId":"entrepot-logistique-montrouge","proprietaire":"pj:Autre","stockProduits":{"bois":100}}');`);
  await db.query("SELECT set_config('test.uid', '00000000-0000-0000-0000-000000000003', false)");
  const r1 = (await lignes(db, 'SELECT sacs_sable_poser(gen_random_uuid()) r'))[0].r;
  assert.equal(r1.ok, true); assert.equal(r1.protege, true);
  const pj = (await lignes(db, "SELECT pa, inventory FROM personnages_donnees WHERE name = 'Patron'"))[0];
  assert.equal(pj.pa, 9, '1 PA'); assert.equal(pj.inventory[0].qty, 1, 'un seul sac consommé');
  const r2 = (await lignes(db, 'SELECT sacs_sable_poser(gen_random_uuid()) r'))[0].r;
  assert.equal(r2.raison, 'deja_protege');
  assert.equal((await lignes(db, "SELECT inventory FROM personnages_donnees WHERE name = 'Patron'"))[0].inventory[0].qty, 1, 'rien consommé au refus');
  // Crue sur les deux lieux : le lieu protégé garde tout, l'autre perd 20 %.
  await db.exec(`INSERT INTO climat_evenements (id, type, pays, ville, debut, fin, periode, lieux) VALUES (600, 'crue', 'republic', 'ville_b', now(), now() + interval '6 hours', 'Z',
                   '[{"batiment":"zone-production","nom":"z"},{"batiment":"entrepot-logistique-montrouge","nom":"e"}]')`);
  await db.query('SELECT climat_crue_appliquer_interne(e) FROM climat_evenements e WHERE id = 600');
  const st = Object.fromEntries((await lignes(db, 'SELECT id, data FROM entreprises')).map(r => [r.id, r.data.stockProduits.bois]));
  assert.deepEqual(st, { protege: 100, expose: 80 });
  // Plus aucune trace de la règle proportionnelle.
  assert.equal((await lignes(db, "SELECT count(*) n FROM pg_proc WHERE proname IN ('climat_sacs_reste_pct_interne', 'climat_sacs_poses_interne')"))[0].n, 0);
  assert.equal((await lignes(db, "SELECT count(*) n FROM aliments_parametres WHERE cle IN ('sac_protection_pct', 'sacs_plafond')"))[0].n, 0);
  assert.equal((await lignes(db, "SELECT count(*) n FROM information_schema.columns WHERE table_name = 'climat_protections' AND column_name = 'sacs'"))[0].n, 0);
  const m = lire('migrations/20261121130000_climat_horaire_cadence_catastrophe_sacs.sql').replace(/^--.*$/gm, '');
  assert.ok(!/sacs_reste|sac_protection_pct\b(?!', 'sacs_plafond)/.test(m.split('DROP FUNCTION')[0]), 'aucune fonction réécrite n’utilise l’ancienne règle');
});
