// Mission « Purge » (Fred, 24/11/2026), point A.7 : la fenêtre de candidature montre chaque condition cochée en vert ou
// en rouge, plus les dates de la période. Vrai code de plateau-politique.js et de forum.js (rpDateLisible), extrait et
// exécuté avec un état de jeu simulé ; le serveur (candidature_deposer) reste la seule porte.
// Lancement : node --test outils/bancs/banc-candidature-conditions-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
function bloc(src, debut) {
  const i = src.indexOf(debut);
  assert.ok(i >= 0, debut + ' introuvable');
  let j = src.indexOf('{', i), p = 0;
  for (; j < src.length; j++) { if (src[j] === '{') p++; else if (src[j] === '}' && --p === 0) break; }
  return src.slice(i, j + 1);
}
const POL = lire('plateau-politique.js'), FORUM = lire('forum.js');

function contexte(etat) {
  const c = vm.createContext({ console, Intl, Date, state: etat, TEST_MODE: false,
    WORLD: { republic: { capitale: { name: 'Luthécia' } }, soviet: { ville_b: { name: 'Krasnov' } } },
    COUNTRIES: { republic: { n: 'Républia' }, soviet: { n: 'Sovarka' } },
    maNationalite: () => etat.nationalite, motifNationalite: r => 'motif:' + r,
    POSTES_ELECTIFS: { national: [{ id: 'president', name: 'Président', minInf: 40 }, { id: 'depute', name: 'Député' }], departemental: [], local: [{ id: 'maire', name: 'Maire', minInf: 10 }] },
    CYCLES_ELECTORAUX: {}, getCleCycle: (p, v) => p + (v ? '_' + v : '') });
  vm.runInContext([
    "const ORDRE_DEPOT_CANDIDATURE = { pa: 2 };",
    "function posteEstLocal(id) { return id === 'maire'; }",
    bloc(POL, 'function _presseNomPays('), bloc(POL, 'function candidaturesOuvertes('), bloc(POL, 'function conditionsCandidature('),
    bloc(POL, 'function refusCandidatureLocal('), bloc(POL, 'function htmlPeriodeCandidature('), bloc(POL, 'function escapeHtmlCandidature('),
    bloc(FORUM, 'function rpDecalageParisMs('), bloc(FORUM, 'function rpInstantForum('), bloc(FORUM, 'function rpDateLisible(')
  ].join('\n'), c);
  return c;
}
const MAINTENANT = Date.now();
const cycleOuvert = { candidats: [], dateDebutCandidatures: Date.UTC(2026, 10, 23, 17, 48), dateDebutCampagne: MAINTENANT + 86400000 * 3,
  dateVote: MAINTENANT + 86400000 * 7, dateResultats: MAINTENANT + 86400000 * 8 };

test('toutes les conditions remplies : tout est vert', () => {
  const c = contexte({ char: { name: 'Tom' }, nationalite: 'republic', country: 'republic', currentCity: 'capitale',
    domicile: { country: 'republic', city: 'capitale' }, inf: 50, pa: 10, poste: null });
  const liste = c.conditionsCandidature('president', 'republic', null, c.POSTES_ELECTIFS.national[0], cycleOuvert);
  assert.deepEqual([...liste.map(x => x.cle)], ['nationalite', 'presence', 'domicile', 'influence', 'cumul', 'deja_candidat', 'periode', 'pa']);
  assert.ok(liste.every(x => x.ok), JSON.stringify(liste.filter(x => !x.ok)));
});

test('conditions manquantes : rouges, et le premier refus est nommé', () => {
  const c = contexte({ char: { name: 'Bernard' }, nationalite: 'soviet', country: 'republic', currentCity: 'capitale',
    domicile: { country: 'soviet', city: 'ville_b' }, inf: 5, pa: 1, poste: null });
  const liste = c.conditionsCandidature('maire', 'republic', 'capitale', c.POSTES_ELECTIFS.local[0], { candidats: [{ nom: 'Bernard' }], dateDebutCampagne: MAINTENANT - 1000 });
  const ko = [...liste.filter(x => !x.ok).map(x => x.cle)];
  assert.deepEqual(ko, ['nationalite', 'domicile', 'influence', 'deja_candidat', 'periode', 'pa']);
  assert.match(liste.find(x => x.cle === 'domicile').texte, /domicilié à Luthécia/);
  assert.match(liste.find(x => x.cle === 'influence').texte, /au moins 10 \(vous : 5\)/);
  c.CYCLES_ELECTORAUX.republic = { maire_capitale: { candidats: [], dateDebutCampagne: MAINTENANT + 1e6 } };
  assert.equal(c.refusCandidatureLocal('maire', 'republic', 'capitale').cle, 'nationalite');
});

test('dates de la période au format unique « 23/11 à 18 h 48 »', () => {
  const c = contexte({ char: { name: 'Tom' } });
  const html = c.htmlPeriodeCandidature(cycleOuvert);
  assert.match(html, /<li>Candidatures : du 23\/11 à 18 h 48 au \d{2}\/\d{2} à \d{2} h \d{2}<\/li>/);
  assert.match(html, /<li>Campagne : du /);
  assert.match(html, /<li>Vote : du /);
  assert.match(c.htmlPeriodeCandidature({}), /pas encore fixées/);
});

test('raccords : la fenêtre s’ouvre toujours, montre conditions et dates ; le dépôt refuse avant tout appel', () => {
  const dep = bloc(POL, 'async function deposerCandidature(');
  assert.ok(!/showToast\(/.test(dep), 'plus de refus en cascade avant la fenêtre');
  assert.match(dep, /ouvrirModalCandidature\(posteId, c, poste, cycle, city\)/);
  const modal = bloc(POL, 'function ouvrirModalCandidature(');
  assert.match(modal, /hg-cand-conditions/);
  assert.match(modal, /hg-cond-ok' : 'hg-cond-ko'/);
  assert.match(modal, /htmlPeriodeCandidature\(cycle\)/);
  const conf = bloc(POL, 'async function confirmerCandidature(');
  const iRefus = conf.indexOf('refusCandidatureLocal('), iRpc = conf.indexOf("sbRpc('candidature_deposer'");
  assert.ok(iRefus > 0 && iRpc > iRefus, 'refus local nommé avant la porte serveur');
  const css = lire('style.css');
  assert.match(css, /\.hg-cond-ok \.hg-cond-marque/);
  assert.match(css, /\.hg-cond-ko \.hg-cond-marque/);
});
