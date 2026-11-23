'use strict';
// Refonte des informateurs (Fred, 19/11/2026 ; étape K du 22/11/2026), migration 20261122180000, dans un vrai PostgreSQL
// local (PGlite) : barème commun, réponse toujours donnée, argent qui disparaît, aucun nom, traits jamais uniques,
// spécialiste de lieu (24 h, cachés exclus, masqués), généraliste et spécialiste de sujet, habitué du Bar Sever (Voronov),
// « Écouter le barman » devenu payant, anciens informateurs recrutés désactivés sans perte de données, commissaire.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIGRATION = 'migrations/20261122180000_informateurs_refonte.sql';

test('le référentiel de la migration est exactement celui que produit data.js', () => {
  const { lignes } = require(path.join(root, 'outils/generateurs/generer-informateurs-lieux.cjs'));
  // Renommages de PNJ décidés après la migration (mission Novomirsk, bloc 3, 23/11/2026) : la ligne du référentiel serveur
  // garde l'ancien nom jusqu'à la migration finale de renommage (liste du rapport du bloc 3) ; l'écran fait le lien
  // par `aliasInformateur` (data.js). Nouveau nom produit par data.js -> ancien nom encore porté par la migration.
  const RENOMMAGES_EN_ATTENTE = { 'soviet:ville_b:musee-novomirsk:hall:Zoïa Biletova': ['Hôtesse du musée de Krasnov', 'Accueil du musée'] };
  const l = lignes().map(x => RENOMMAGES_EN_ATTENTE[x.id]
    ? Object.assign({}, x, { id: x.id.replace(/[^:]+$/, RENOMMAGES_EN_ATTENTE[x.id][0]), nom: RENOMMAGES_EN_ATTENTE[x.id][0], role: RENOMMAGES_EN_ATTENTE[x.id][1] })
    : x), sql = lire(MIGRATION);
  const q = (s) => s === null || s === undefined ? 'NULL' : "'" + String(s).replace(/'/g, "''") + "'";
  for (const x of l) assert.ok(sql.includes('(' + [x.id, x.pays, x.ville, x.batiment, x.piece, x.nom, x.role, x.profil, x.sujet].map(q).join(', ') + ')'), x.id);
  assert.equal((sql.match(/^\('/gm) || []).length, l.length, 'aucune ligne en trop');
  const profils = new Set(l.map(x => x.profil));
  assert.deepEqual([...profils].sort(), ['generaliste', 'lieu', 'sujet']);
  // Non-informateurs : jamais de magistrat, policier, militaire, religieux, soignant, notaire, guide, journaliste.
  const interdits = /juge|procureur|policier|commissaire|militaire|soldat|commandant de la caserne|pr[êe]tre|m[ée]decin|infirmi|notaire|clerc|guide|journaliste/i;
  for (const x of l) assert.ok(!interdits.test(x.role), 'non-informateur retenu : ' + x.id);
  assert.ok(l.every(x => ['republic', 'soviet'].includes(x.pays)));
  assert.ok(l.some(x => x.id === 'habitue_krasnov' && x.profil === 'generaliste'));
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const UID = { Tom: '00000000-0000-0000-0000-000000000001', Ana: '00000000-0000-0000-0000-000000000002',
  Leo: '00000000-0000-0000-0000-000000000003', Zoe: '00000000-0000-0000-0000-000000000004', Max: '00000000-0000-0000-0000-000000000005' };
const BAR = ['republic', 'capitale', 'hotel-republica', 'bar'];
const RESTO = ['republic', 'capitale', 'hotel-republica', 'restaurant'];

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/informateurs-refonte-socle.sql.txt'));
  await db.exec(lire(MIGRATION));
  const fiche = {
    // Tom : le payeur. Ana et Leo : deux hommes de Montrouge, ouvriers ; Zoe : seule femme, seule médecin, seule de Krasnov.
    Tom: { genre: 'H', origin: 'elite', career: 'business', nat: 'republic', dom: ['republic', 'capitale'] },
    Ana: { genre: 'H', origin: 'worker', career: 'worker', nat: 'republic', dom: ['republic', 'ville_b'] },
    Leo: { genre: 'H', origin: 'worker', career: 'worker', nat: 'republic', dom: ['republic', 'ville_b'] },
    Zoe: { genre: 'F', origin: 'bourgeois', career: 'doctor', nat: 'soviet', dom: ['soviet', 'ville_b'] },
    Max: { genre: 'H', origin: 'elite', career: 'business', nat: 'republic', dom: ['republic', 'capitale'] }
  };
  for (const [n, u] of Object.entries(UID)) {
    const f = fiche[n];
    await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
    await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, liquide, arg, stats, origin, career, nationalite, domicile)
      VALUES ($1, $2, $3, $4, $5, 100, 100, $6, $7, $8, $9, $10)`,
      [n, ...BAR, JSON.stringify({ genre: f.genre }), f.origin, f.career, f.nat, JSON.stringify({ country: f.dom[0], city: f.dom[1] })]);
  }
  await db.query("INSERT INTO comptes_bancaires VALUES ('c-tom', 'Tom', 'nationale', 1000, now())");
  return db;
}
async function appel(db, qui, sql, args = []) {
  await db.query("SELECT set_config('test.uid', $1, false)", [UID[qui]]);
  return (await db.query(sql, args)).rows[0].r;
}
const payer = (db, qui, id, m) => appel(db, qui, 'SELECT informateur_payer(gen_random_uuid(), $1, $2) r', [id, m]);
const lieu = (db, qui, l) => db.query('UPDATE personnages_donnees SET country=$2, current_city=$3, current_building=$4, current_room=$5 WHERE name=$1', [qui, ...l]);
const argent = async (db, qui) => (await db.query("SELECT liquide, arg, (SELECT solde FROM comptes_bancaires WHERE personnage=$1) AS banque FROM personnages_donnees WHERE name=$1", [qui])).rows[0];
const MARCO = 'republic:capitale:hotel-republica:bar:Marco (Barman)';
const NATHALIE = 'republic:capitale:hotel-republica:accueil:Nathalie Ondor';
const LOBBY = 'republic:capitale:hotel-republica:bar:Marc Hantile';

test('migration rejouable ; un seul raccord par marque ; anciens informateurs désactivés sans effacer de données', async () => {
  const db = await base();
  await db.query(`UPDATE personnages_donnees SET informateurs='[{"niveau":2,"label":"Informateur politique","cout":400}]' WHERE name='Max'`);
  await db.exec(lire(MIGRATION));
  for (const [fn, marques] of [['rumeur_ecoute_jauges_interne(text)', ['informateurs_ecoute_payante_v1']],
    ['crim_enquete_taux_interne(bigint,text)', ['informateurs_piste_v1', 'informateurs_taux_v1', 'informateurs_pistes_v1']]]) {
    const d = (await db.query(`SELECT pg_get_functiondef('${fn}'::regprocedure) d`)).rows[0].d;
    for (const m of marques) assert.equal(d.split(m).length, 2, fn + ' ' + m);
  }
  assert.equal((await appel(db, 'Max', 'SELECT informateur_recruter(2, 1, 400) r')).raison, 'informateurs_supprimes');
  assert.equal((await appel(db, 'Max', 'SELECT informateur_interroger(2, 1) r')).raison, 'informateurs_supprimes');
  assert.equal((await db.query('SELECT minuit_informateurs() r')).rows[0].r.payes, 0, 'plus aucun salaire');
  assert.equal((await db.query("SELECT jsonb_array_length(informateurs) n FROM personnages_donnees WHERE name='Max'")).rows[0].n, 1, 'données gardées');
  assert.equal((await db.query("SELECT recrutable FROM pnj_metiers_profils WHERE metier='informateur'")).rows[0].recrutable, false);
  const oc = (await db.query('SELECT fn, pa, cost::int FROM ordres_couts ORDER BY 1, 2')).rows.map(r => r.fn + '/' + r.pa + '/' + r.cost);
  assert.deepEqual(oc, ['ecouter_rumeurs/0/0', 'ecouter_rumeurs/1/0', 'informateur_payer/0/0', 'informateur_salaire_1/0/150', 'interroger_informateur/1/0']);
});

test('barème : hors bornes refusé sans débit ; payer donne toujours une réponse ; l’argent disparaît du jeu', async () => {
  const db = await base();
  for (const m of [19, 51, 0]) assert.equal((await payer(db, 'Tom', MARCO, m)).raison, 'montant_invalide');
  assert.deepEqual(await argent(db, 'Tom'), { liquide: 100, arg: 100, banque: '1000' });
  const paliers = { 20: 'flou', 29: 'flou', 30: 'correct', 44: 'correct', 45: 'premier_choix', 50: 'premier_choix' };
  let total = 0;
  for (const [m, p] of Object.entries(paliers)) {
    const r = await payer(db, 'Tom', MARCO, Number(m));
    assert.equal(r.ok, true); assert.equal(r.palier, p); assert.equal(r.devise, 'FR');
    assert.ok(Array.isArray(r.lignes) && r.lignes.length >= 1 && r.lignes.every(x => typeof x === 'string' && x.length > 5));
    total += Number(m);
  }
  const a = await argent(db, 'Tom');
  assert.equal(a.liquide + Number(a.banque), 1100 - total, 'liquide puis banque');
  const caisses = (await db.query('SELECT count(*)::int n FROM caisses_batiments')).rows[0].n;
  assert.equal(caisses, 0, 'aucune caisse créditée');
  assert.equal((await db.query('SELECT count(*)::int n FROM informateurs_achats')).rows[0].n, 6);
  await db.query("UPDATE personnages_donnees SET liquide=0 WHERE name='Tom'"); await db.query("UPDATE comptes_bancaires SET solde=10");
  assert.equal((await payer(db, 'Tom', MARCO, 45)).raison, 'fonds_insuffisants');
});

test('présence exigée : un informateur d’une autre pièce ou inconnu refuse ; informateurs_ici liste la pièce et le barème', async () => {
  const db = await base();
  assert.equal((await payer(db, 'Tom', NATHALIE, 30)).raison, 'pas_sur_place');
  assert.equal((await payer(db, 'Tom', 'inventé', 30)).raison, 'informateur_inconnu');
  const ici = await appel(db, 'Tom', 'SELECT informateurs_ici() r');
  assert.deepEqual(ici.informateurs.map(i => i.id).sort(), [LOBBY, MARCO].sort());
  assert.equal(ici.bareme.min, 20); assert.equal(ici.bareme.max, 50);
  await lieu(db, 'Tom', ['soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle']);
  const k = await appel(db, 'Tom', 'SELECT informateurs_ici() r');
  assert.deepEqual(k.informateurs.map(i => i.id).sort(), ['habitue_krasnov', 'soviet:ville_b:cafe-tabac-cheminots-montrouge:salle:Grigori Zaitsev']);
  assert.equal(k.bareme.devise, 'PSK');
});

test('spécialiste de lieu : 24 h, cachés exclus, masqué anonyme, 1/2/3 traits, jamais de nom ni de trait unique', async () => {
  const db = await base();
  await lieu(db, 'Tom', ['republic', 'capitale', 'hotel-republica', 'accueil']);
  for (const n of ['Ana', 'Zoe', 'Leo', 'Max']) await db.query("INSERT INTO historique_deplacements (name, country, city, building_id, room_id) VALUES ($1, 'republic', 'capitale', 'hotel-republica', 'accueil')", [n]);
  await db.query("INSERT INTO historique_deplacements (name, country, city, building_id, room_id, created_at) VALUES ('Ana', 'republic', 'capitale', 'tribunal', 'hall', now())");
  await db.query("UPDATE historique_deplacements SET created_at = now() - interval '30 hours' WHERE name = 'Max'");
  await db.query("INSERT INTO caches_pj VALUES ('Leo', 'republic', 'capitale', 'hotel-republica', 'bar')");
  await db.query("INSERT INTO masques_test VALUES ('Zoe')");
  await db.query("INSERT INTO actions_tracables (auteur, type_action, country, city) VALUES ('Leo', 'vol', 'republic', 'capitale')");
  for (const [m, n] of [[20, 1], [30, 2], [45, 3]]) {
    const r = await payer(db, 'Tom', NATHALIE, m);
    const texte = r.lignes.join('\n');
    for (const nom of ['Ana', 'Zoe', 'Leo', 'Max', 'Tom']) assert.ok(!texte.includes(nom), 'nom donné : ' + nom);
    const desc = r.lignes.filter(x => x.startsWith('— quelqu’un'));
    assert.equal(desc.length, 1, 'Ana seule décrite (Leo caché, Max hors 24 h) : ' + texte);
    assert.ok(r.lignes.includes('— un individu masqué'), 'Zoe masquée');
    const traits = desc[0].replace('— quelqu’un : ', '').split(' ; ');
    // Ana : un homme, allure ouvrière, habite Montrouge, républicaine, monde ouvrier — tous partagés ; 3 traits au plus... selon le palier
    assert.equal(traits.length, n, texte);
    if (n === 3) assert.ok(traits.some(t => /^habite|nationalité|milieu|monde ouvrier/.test(t)), 'un trait social au premier choix');
    assert.ok(/On a entendu dire ici qu’un vol a été commis\./.test(texte), 'rumeur réelle de la ville');
  }
  // Traits uniques jamais donnés : Zoe démasquée n'a que des traits uniques (femme, bourgeoise, médecin, Krasnov, sovarkienne).
  await db.query('DELETE FROM masques_test');
  const t = (await db.query("SELECT informateur_traits_interne('Zoe', 3, true) t")).rows[0].t;
  assert.deepEqual(t, [], 'aucun trait qui la désigne seule');
});

test('généraliste : flou banal, correct un fait et un trait, premier choix le fait le plus marquant ; sujet : filtré', async () => {
  const db = await base();
  const r0 = await payer(db, 'Tom', MARCO, 20);
  assert.equal(r0.lignes.length, 1); assert.match(r0.lignes[0], /^« /);
  const r1 = await payer(db, 'Tom', MARCO, 30);
  assert.match(r1.lignes.join(' '), /rien de mieux/, 'aucun fait : réponse banale, jamais d’impasse');
  await db.query("INSERT INTO actions_tracables (auteur, type_action, country, city) VALUES ('Ana', 'consommation_drogue', 'republic', 'capitale'), ('Leo', 'assassinat', 'republic', 'capitale'), ('Zoe', 'vol', 'soviet', 'capitale')");
  for (let i = 0; i < 5; i++) {
    const r = await payer(db, 'Tom', MARCO, 45);
    assert.match(r.lignes[0], /quelqu’un a été assassiné\. Quelqu’un — /, 'le plus marquant, avec un trait');
    assert.ok(!/Leo|Ana/.test(r.lignes[0]));
  }
  const c = await payer(db, 'Tom', MARCO, 30);
  assert.match(c.lignes[0], /(assassiné|drogue)/, 'un fait de la ville, pas d’ailleurs');
  for (let i = 0; i < 4; i++) {
    const s = await payer(db, 'Tom', LOBBY, 45);
    assert.doesNotMatch(s.lignes.join(' '), /assassin|drogue/, 'le lobbyiste ne parle que de politique');
  }
  await db.query("INSERT INTO actions_tracables (auteur, type_action, country, city) VALUES ('Ana', 'corruption', 'republic', 'capitale')");
  assert.match((await payer(db, 'Tom', LOBBY, 45)).lignes[0], /enveloppe/);
});

test('habitué du Bar Sever : généraliste, piste du colonel Voronov au premier choix seulement', async () => {
  const db = await base();
  await lieu(db, 'Tom', ['soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle']);
  const f = await payer(db, 'Tom', 'habitue_krasnov', 7);
  assert.equal(f.palier, 'flou'); assert.equal(f.appris, false);
  assert.equal((await db.query("SELECT count(*)::int n FROM personnages_secrets")).rows[0].n, 0);
  const p = await payer(db, 'Tom', 'habitue_krasnov', 20);
  assert.equal(p.palier, 'premier_choix'); assert.equal(p.appris, true); assert.match(p.lignes[0], /Voronov/);
  assert.equal((await db.query("SELECT cle FROM personnages_secrets WHERE personnage='Tom'")).rows[0].cle, 'colonel_polonium');
  const a = await argent(db, 'Tom');
  assert.equal(a.liquide, 100 - 27, '7 + 20 PSK versés, rien d’autre');
});

test('« Écouter le barman » n’est plus gratuit là où se tient un généraliste ; les tables du restaurant restent gratuites', async () => {
  const db = await base();
  assert.equal((await appel(db, 'Tom', "SELECT rumeur_ecoute_jauges_interne('Tom') r")).raison, 'ecoute_payante');
  await lieu(db, 'Tom', ['republic', 'ville_a', 'bar-des-pecheurs', 'salle_bar']);
  assert.equal((await appel(db, 'Tom', "SELECT rumeur_ecoute_jauges_interne('Tom') r")).raison, 'ecoute_payante');
  await lieu(db, 'Tom', RESTO);
  assert.equal((await appel(db, 'Tom', "SELECT rumeur_ecoute_jauges_interne('Tom') r")).ok, true);
});

test('commissaire : caisse d’abord, fonds propres en dernier ressort ; flou = bonus divisé par deux ; une fois par jour', async () => {
  const db = await base();
  await db.query("INSERT INTO postes_test VALUES ('Max', 'commissaire', 'capitale', 'republic')");
  await db.query("INSERT INTO crim_affaires (id, acte, auteur, pays, ville, plafond_enquete, plainte_id) VALUES (1, 'voler', 'Ana', 'republic', 'capitale', 60, 'p1'), (2, 'voler', 'Ana', 'republic', 'capitale', 60, 'p2'), (3, 'voler', 'Ana', 'republic', 'capitale', 60, 'p3')");
  await db.query(`INSERT INTO caisses_batiments VALUES ('republic_commissariat_capitale', '{"solde": 60}', now())`);
  const taux = async (id) => Number((await db.query('SELECT crim_enquete_taux_interne($1, $2) t', [id, 'Max'])).rows[0].t.taux);
  const avant = await taux(1);
  assert.equal(avant, 30, 'base = plafond / 2');
  assert.equal((await appel(db, 'Tom', 'SELECT crim_informateur_payer(1, 30, gen_random_uuid()) r')).raison, 'reserve_commissaire');
  assert.equal((await appel(db, 'Max', 'SELECT crim_informateur_payer(1, 19, gen_random_uuid()) r')).raison, 'montant_invalide');
  const f = await appel(db, 'Max', 'SELECT crim_informateur_payer(1, 20, gen_random_uuid()) r');
  assert.equal(f.palier, 'flou'); assert.equal(f.source, 'caisse');
  assert.equal(await taux(1), 35, 'flou : une demi-piste (30 + 30 × 0,5 / 3)');
  assert.equal(f.pistes.informateur_palier, 'flou');
  assert.equal((await appel(db, 'Max', 'SELECT crim_informateur_payer(1, 45, gen_random_uuid()) r')).raison, 'informateur_deja_paye_aujourdhui');
  const c = await appel(db, 'Max', 'SELECT crim_informateur_payer(2, 30, gen_random_uuid()) r');
  assert.equal(c.source, 'caisse'); assert.equal(await taux(2), 40, 'correct : piste entière');
  // Caisse à 10 : fonds propres du commissaire.
  const p = await appel(db, 'Max', 'SELECT crim_informateur_payer(3, 45, gen_random_uuid()) r');
  assert.equal(p.source, 'fonds_propres'); assert.equal(p.palier, 'premier_choix');
  assert.ok(!p.ligne.includes('Ana'), 'jamais de nom');
  assert.equal((await argent(db, 'Max')).liquide, 55);
  assert.equal((await db.query("SELECT data->>'solde' s FROM caisses_batiments")).rows[0].s, '10');
});
