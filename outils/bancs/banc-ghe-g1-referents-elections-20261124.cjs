'use strict';
// Mission « Purge » (Fred, 24/11/2026), point G.1 : dans les trois villes de Sovarka, les secrétaires de mairie et les
// officiers des salles des partis sont référents élections (ils expliquent comment se présenter).
//   • chaque PNJ visible (vrai data.js, même résolution d'identifiant que le dialogue) a une fiche qui porte le savoir
//     « comment se présenter » et la consigne de référent (plus « aucune règle du jeu ») ;
//   • les trois listes sont alignées : PNJ_REFERENTS (plateau-pnj.js), migration pnj_referents (lue par le PNJ guide) ;
//   • la migration, jouée deux fois dans un vrai PostgreSQL (PGlite), laisse six référents « élections » en Sovarka.
// Lancement : node --test outils/bancs/banc-ghe-g1-referents-elections-20261124.cjs (PGLITE_DIR pour la partie base).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIGRATION = 'migrations/20261124140000_ghe_g1_referents_elections_sovarka.sql';
// [ville, bâtiment, pièce, nom affiché, profil attendu]
const REFERENTS = [
  ['capitale', 'mairie-capitale', 'hall_mairie', 'Valentina Petchatkina', 'sovarka_valentina_petchatkina'],
  ['capitale', 'mairie-capitale', 'salle_partis', 'Capitaine Igor Balatov', 'capitaine_igor_balatov'],
  ['ville_b', 'mairie', 'accueil_mairie', 'Galina Dokladova', 'galina_dokladova'],
  ['ville_b', 'mairie', 'salle_partis', 'Lieutenant Fiodor Doznaïev', 'lieutenant_fiodor_doznaiev'],
  ['ville_a', 'mairie', 'accueil_mairie', 'Sayana Tsydypova', 'sayana_tsydypova'],
  ['ville_a', 'mairie', 'salle_partis', 'Lieutenant Tsyden Zhalsaraev', 'lieutenant_tsyden_zhalsaraev']
];
function extraire(fichier, debut, mot = 'function ') {
  const s = lire(fichier), i = s.indexOf(mot + debut);
  if (i < 0) throw new Error(debut + ' introuvable dans ' + fichier);
  let j = s.indexOf('{', i), p = 0;
  for (; j < s.length; j++) { if (s[j] === '{') p++; else if (s[j] === '}' && --p === 0) break; }
  return s.slice(i, j + 1);
}
function profilDe(ville, batiment, piece, nom) {
  const ctx = vm.createContext({ console, state: { country: 'soviet', currentCity: ville } });
  vm.runInContext(lire('data.js'), ctx);
  vm.runInContext(extraire('plateau-navigation.js', 'getBuildingContext'), ctx);
  vm.runInContext(extraire('plateau-multijoueur.js', 'personnesNormalesDeLaPiece'), ctx);
  vm.runInContext(extraire('plateau-pnj.js', 'slugPnj'), ctx);
  vm.runInContext(extraire('plateau-pnj.js', 'PNJ_PROFILS_SERVEUR', 'const ') + ';this.PNJ_PROFILS_SERVEUR = PNJ_PROFILS_SERVEUR;', ctx);
  vm.runInContext(extraire('plateau-pnj.js', 'profilServeurDuPnj'), ctx);
  ctx.__a = [batiment, piece, nom];
  return vm.runInContext(`(() => { const [b, p, n] = __a; const l = personnesNormalesDeLaPiece(b, p) || [];
    const x = l.find(q => q && String(q.name).replace(/\\s*\\(PNJ\\)\\s*$/, '') === n); return x ? profilServeurDuPnj(x) : null; })()`, ctx);
}

test('G.1 — les six PNJ visibles ont la fiche de référent élections', async () => {
  const { TOUS_PROFILS } = await import(path.join(R, 'api/_pnj-profils.js'));
  for (const [ville, b, p, nom, id] of REFERENTS) {
    assert.equal(profilDe(ville, b, p, nom), id, nom + ' (' + [ville, b, p].join('/') + ')');
    const f = TOUS_PROFILS[id];
    assert.ok(f, 'fiche ' + id);
    assert.match(f.savoir, /TU ES RÉFÉRENT DES ÉLECTIONS DE SOVARKA/, id);
    assert.match(f.savoir, /« Investir un candidat »/, id);
    assert.match(f.savoir, /obligatoirement son chef/, id);
    assert.doesNotMatch(f.limites, /TU NE CONNAIS AUCUNE REGLE DU JEU/, id + ' : la consigne ordinaire contredirait le savoir');
  }
});

test('G.1 — listes alignées : client, migration (liste lue par le PNJ guide)', () => {
  const pnj = lire('plateau-pnj.js'), liste = extraire('plateau-pnj.js', 'PNJ_REFERENTS', 'const '), m = lire(MIGRATION);
  for (const [, , , , id] of REFERENTS) {
    assert.ok(liste.includes("'" + id + "'"), 'PNJ_REFERENTS ' + id);
    assert.ok(m.includes("'" + id + "'"), 'migration ' + id);
  }
  assert.ok(pnj.length > 0);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
test('G.1 — migration rejouable dans un vrai PostgreSQL', { skip: !PGlite && 'PGlite absent (PGLITE_DIR)' }, async () => {
  const db = new PGlite();
  await db.exec(`CREATE TABLE public.pnj_referents (referent_id text PRIMARY KEY, domaine text NOT NULL, pays text NOT NULL);
    INSERT INTO public.pnj_referents VALUES ('sayana_tsydypova', 'démarches municipales — mairie de Starovka', 'soviet'),
      ('lieutenant_tsyden_zhalsaraev', 'partis de Sovarka — salle des partis de Starovka', 'soviet'),
      ('dugar_tsyrempilov', 'élections de Sovarka — commission électorale de Starovka', 'soviet');`);
  await db.exec(lire(MIGRATION));
  await db.exec(lire(MIGRATION));
  const r = (await db.query("SELECT count(*)::int n FROM pnj_referents WHERE domaine LIKE 'élections (comment se présenter)%'")).rows[0];
  assert.equal(r.n, 6);
  assert.equal((await db.query('SELECT count(*)::int n FROM pnj_referents')).rows[0].n, 7);
});
