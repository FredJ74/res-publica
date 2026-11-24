// Banc isolé de plateau-accueil-progressif.js (PR #1188, repris par la purge A.2/A.3 du 24/11/2026) : sans réseau ni
// navigateur. Depuis la purge, le module n'a plus de minuterie ni de localStorage : le temps de jeu cumulé, le moment de
// l'interview et la fin de la première heure viennent du serveur (accueil_etat → calendrier). Le banc vérifie ce que
// l'écran en fait : bienvenue (texte exact de Fred, croix seule), interview jamais collée à une autre fenêtre, journal du
// jour au badge pendant la première heure puis une seule fenêtre automatique par connexion, conversation PNJ transmise au
// serveur, garde de Luthécia après les 5 minutes de découverte. La dynamique serveur : banc-accueil-calendrier-pglite.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../../plateau-accueil-progressif.js'), 'utf8');
// Noms de ville et de pays : les vraies fonctions du jeu (data.js : VILLES + villeNom ; plateau-core.js : nomPaysAffiche).
const dataJs = fs.readFileSync(path.join(__dirname, '../../data.js'), 'utf8'), coreJs = fs.readFileSync(path.join(__dirname, '../../plateau-core.js'), 'utf8');
const bloc = (src, debut, fin) => { const i = src.indexOf(debut); return src.slice(i, src.indexOf(fin, i) + fin.length); };
const NOMS = vm.runInNewContext(bloc(dataJs, 'const VILLES = {', '\n};') + '\n' + bloc(dataJs, 'function villeNom(', '\n}')
  + '\n' + bloc(coreJs, 'function nomPaysAffiche(', '\n}') + '\n({ villeNom, nomPaysAffiche, VILLES })', {});

function environnement(serveur) {
  let clock = 1e6;
  const elements = new Map(), appels = [];
  const corps = [];
  function element(tag) {
    const el = {
      tag, innerHTML: '', className: '', dataset: {}, attributes: {}, listeners: {}, children: [], style: {},
      classList: { add() {}, remove() {}, contains: () => false },
      setAttribute(k, v) { this.attributes[k] = v; }, removeAttribute() {},
      addEventListener(k, v) { this.listeners[k] = v; },
      querySelector(sel) {
        if (sel === '.hg-bienvenue-croix') { this._croix = this._croix || Object.assign(element('button'), { focus() {} }); return this._croix; }
        return null;
      },
      appendChild(c) { this.children.push(c); },
      remove() { if (this.id) elements.delete(this.id); const i = corps.indexOf(this); if (i >= 0) corps.splice(i, 1); }
    };
    Object.defineProperty(el, 'id', { get() { return this._id; }, set(x) { this._id = x; elements.set(x, this); } });
    return el;
  }
  const doc = {
    head: { appendChild() {} },
    body: { appendChild(el) { const i = corps.indexOf(el); if (i >= 0) corps.splice(i, 1); corps.push(el); }, contains: el => corps.includes(el),
            get lastElementChild() { return corps[corps.length - 1]; } },
    getElementById: id => elements.get(id) || null,
    querySelector(sel) {
      for (const id of ['hg-bienvenue', 'hg-accueil-interview', 'climat-explication']) if (sel.includes('#' + id) && elements.get(id)) return elements.get(id);
      return null;
    },
    createElement: element
  };
  const window = {
    document: doc, state: { country: 'soviet', currentCity: 'ville_b', char: { name: 'Testeur' } },
    villeNom: NOMS.villeNom, nomPaysAffiche: NOMS.nomPaysAffiche,
    setInterval() {}, addEventListener() {},
    sbRpc: async (fn) => { appels.push(fn); return { ok: true }; },
    RPAccueil: { etat: () => serveur }
  };
  const DateFaux = class { static now() { return clock; } };
  class MutationObserver { observe() {} disconnect() {} }
  vm.runInNewContext(source, { window, document: doc, Date: DateFaux, console, setTimeout() {}, MutationObserver, Promise, Object });
  return { ui: window.RPAccueilProgressif, portier: window.RPFenetresAuto, doc, window, appels, avance: ms => { clock += ms; } };
}
const nouveau = (o = {}) => ({ ok: true, personnage: 'Testeur', interview: { etat: 'a_faire', ouvrir_auto: false },
  calendrier: Object.assign({ actif: true, secondes_jeu: 0, premiere_heure: true, interview_due: false, decouverte_finie: false, interview_forcee: false }, o.calendrier || {}),
  bienvenue: Object.assign({ a_voir: true, pays: 'soviet', ville: 'ville_b', signataire: null, portrait: null }, o.bienvenue || {}) });

test('Nouveau : bienvenue au texte exact, croix seule, mémorisée au serveur ; l’interview attend', () => {
  const e = environnement(nouveau());
  e.ui.initialiser(nouveau());
  const b = e.doc.getElementById('hg-bienvenue');
  assert.ok(b);
  assert.match(b.innerHTML, /Bienvenue à Krasnov en Sovarka,/);
  assert.match(b.innerHTML, /Ça doit faire bizarre d&#39;arriver en terre inconnue, mais sache que tu n&#39;es pas seul : on est là pour t&#39;aider\./);
  assert.match(b.innerHTML, /data-bienvenue-signature><\/div>/, 'signature vide (PNJ à créer)');
  assert.equal(e.ui.entretienAutomatiqueAutorise(), false, 'la bienvenue ouverte bloque');
  const key = { key: 'Escape', prevented: false, preventDefault() { this.prevented = true; }, stopPropagation() {} };
  b.listeners.keydown(key);
  assert.equal(key.prevented, true);
  assert.ok(e.doc.getElementById('hg-bienvenue'), 'Échap ne ferme pas la bienvenue');
  b._croix.listeners.click();
  assert.equal(e.doc.getElementById('hg-bienvenue'), null);
  assert.ok(e.appels.includes('accueil_bienvenue_vue'));
});

test('Interview due (serveur) : jamais collée à la fenêtre précédente, sauf forcée à 30 minutes', () => {
  const s = nouveau({ bienvenue: { a_voir: false } });
  const e = environnement(s);
  e.ui.initialiser(s);
  assert.equal(e.ui.entretienAutomatiqueAutorise(), true, 'rien d’ouvert : elle peut paraître');
  // Une fenêtre automatique vient de se fermer : respiration.
  const e2 = environnement(nouveau());
  e2.ui.initialiser(nouveau());
  e2.doc.getElementById('hg-bienvenue')._croix.listeners.click();
  assert.equal(e2.ui.entretienAutomatiqueAutorise(), false);
  e2.avance(3 * 60 * 1000);
  assert.equal(e2.ui.entretienAutomatiqueAutorise(), true);
  const e3 = environnement(nouveau({ calendrier: { interview_forcee: true } }));
  e3.ui.initialiser(nouveau({ calendrier: { interview_forcee: true } }));
  e3.doc.getElementById('hg-bienvenue')._croix.listeners.click();
  assert.equal(e3.ui.entretienAutomatiqueAutorise(), true, 'forcée : seulement la fenêtre ouverte la retarde');
});

test('Une conversation PNJ est transmise au serveur (report de 5 min décidé là-bas)', () => {
  const s = nouveau({ bienvenue: { a_voir: false } });
  const e = environnement(s);
  e.ui.initialiser(s);
  e.ui.noterDiscussionPnj();
  assert.ok(e.appels.includes('accueil_pnj_parle'));
});

test('Journal du jour : badge pendant la première heure, puis une seule fenêtre automatique par connexion', () => {
  const s = nouveau({ bienvenue: { a_voir: false } });
  const e = environnement(s);
  e.ui.initialiser(s);
  let appels = 0;
  e.ui.programmerJournal(() => appels++);
  assert.equal(appels, 0);
  assert.equal(JSON.stringify(e.portier.files().journal), '["journal_du_jour"]');
  const apres = nouveau({ bienvenue: { a_voir: false }, calendrier: { premiere_heure: false } });
  const f = environnement(apres);
  f.ui.initialiser(apres);
  f.ui.programmerJournal(() => appels++);
  assert.equal(appels, 1);
  f.portier.demander('climat', () => appels++);
  assert.equal(appels, 1, 'la seconde attend au badge');
  assert.equal(JSON.stringify(f.portier.files().meteo), '["climat"]');
});

test('Ancien personnage : aucune bienvenue, journal immédiat', () => {
  const ancien = { ok: true, personnage: 'Testeur', interview: { etat: 'faite' }, calendrier: { actif: false, premiere_heure: false }, bienvenue: { a_voir: false } };
  const e = environnement(ancien);
  e.ui.initialiser(ancien);
  assert.equal(e.doc.getElementById('hg-bienvenue'), null);
  let appels = 0;
  e.ui.programmerJournal(() => appels++);
  assert.equal(appels, 1);
});

test('Le code de production raccorde les portes ; plus de temps compté par l’écran', () => {
  const lire = f => fs.readFileSync(path.join(__dirname, '../..', f), 'utf8');
  const plateau = lire('plateau.html'), core = lire('plateau-core.js'), accueil = lire('plateau-accueil-interview.js'), pnj = lire('plateau-pnj.js');
  assert.ok(plateau.indexOf('plateau-accueil-progressif.js') < plateau.indexOf('plateau-accueil-interview.js'));
  assert.match(core, /RPAccueilProgressif\.programmerJournal\(/);
  assert.doesNotMatch(core, /afficherJournalDuJour\(\), 8000/);
  assert.match(accueil, /entretienAutomatiqueAutorise\(\)/);
  assert.match(pnj, /RPAccueilProgressif\?\.noterDiscussionPnj\(\)/);
  const code = source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  assert.doesNotMatch(code, /localStorage/, 'le temps de jeu est tenu par le serveur');
});

test('Quête de Luthécia : le garde attend la fin de la découverte (serveur), la bienvenue et la respiration', () => {
  const s = nouveau();
  const e = environnement(s);
  let garde = 0;
  e.window.queteAccueilAfficherGardeDifferee = () => garde++;
  e.ui.initialiser(s);
  assert.equal(e.ui.queteInitialeAutorisee(), false, 'bienvenue ouverte, découverte pas finie');
  e.doc.getElementById('hg-bienvenue')._croix.listeners.click();
  s.calendrier.decouverte_finie = true;
  assert.equal(e.ui.queteInitialeAutorisee(), false, 'juste après la bienvenue');
  e.avance(3 * 60 * 1000);
  e.ui.verifier();
  assert.ok(garde >= 1, 'garde autorisé après la découverte et la respiration');
  const quete = fs.readFileSync(path.join(__dirname, '../../plateau-quete-accueil.js'), 'utf8');
  assert.match(quete, /gardeAttenteDecouverte: reporter/);
  assert.match(quete, /function queteAccueilAfficherGardeDifferee\(\)/);
});

test('Précision de Fred (24/11) : « Bienvenue à {ville} en {pays}, » pour TOUTES les villes de départ, lues dans les données du jeu', () => {
  assert.doesNotMatch(source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, ''), /const VILLES = |['"]Luthécia|['"]Novomirsk|Human Gambit/, 'aucune ville ni nom du jeu codés en dur dans le module');
  let n = 0;
  for (const pays of ['republic', 'soviet']) for (const ville of Object.keys(NOMS.VILLES[pays])) {
    const etat = nouveau({ bienvenue: { pays, ville } });
    const e = environnement(etat); e.ui.initialiser(etat);
    const titre = e.doc.getElementById('hg-bienvenue').innerHTML.match(/<h2[^>]*>([^<]*)<\/h2>/)[1];
    assert.equal(titre, 'Bienvenue à ' + NOMS.villeNom(pays, ville) + ' en ' + NOMS.nomPaysAffiche(pays) + ',', pays + '/' + ville);
    assert.doesNotMatch(titre, /!/, 'pas de point d’exclamation');
    n++;
  }
  assert.equal(n, 6);
});
