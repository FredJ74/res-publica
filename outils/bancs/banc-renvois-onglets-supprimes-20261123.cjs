'use strict';
// Règle R4 (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md) : rien n'est supprimé sans rediriger ce qui
// l'appelle. Ce banc échoue si un élément du dépôt renvoie encore vers un onglet, une fonction ou un élément supprimé
// par la mission « fiche d'objet unique et panneau de gauche » (points 1, 16 à 19).
//  - onglets « Inventaire » et « Statistiques » de « Mon personnage », onglet « Statistiques » de la fiche (fenêtre) ;
//  - bouton « Mes statistiques », volet Inventaire du panneau de gauche (inv-chevron, inv-items, toggleInventaire) ;
//  - toute fonction appelée par un onclick de plateau.html doit exister dans un script chargé par la page.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

// Fichiers vivants : code du jeu, page, migrations, i18n, API. (historique/ et baseline/ sont des archives.)
function fichiersVivants() {
  const out = [];
  const ok = f => /\.(js|mjs|cjs|html|sql)$/.test(f);
  for (const f of fs.readdirSync(R)) if (ok(f) && fs.statSync(path.join(R, f)).isFile()) out.push(f);
  for (const d of ['migrations', 'i18n', 'api', 'supabase']) {
    const pile = [d];
    while (pile.length) {
      const c = pile.pop(), abs = path.join(R, c);
      if (!fs.existsSync(abs)) continue;
      for (const e of fs.readdirSync(abs, { withFileTypes: true })) {
        if (e.name === 'node_modules' || e.name === 'packed') continue;
        const rel = path.join(c, e.name);
        if (e.isDirectory()) pile.push(rel); else if (ok(e.name)) out.push(rel);
      }
    }
  }
  return out;
}
const FICHIERS = fichiersVivants();
let acorn;
for (const m of ['acorn', '../e2e/node_modules/acorn', '../vercel/node_modules/acorn']) { try { acorn = require(m); break; } catch (_) {} }
// Retire les commentaires sans toucher aux chaînes : analyseur JavaScript pour le code, balises <!-- --> pour le HTML,
// lignes « -- » pour le SQL. Un fichier JavaScript illisible par l'analyseur est gardé entier (plus strict).
function sansCommentaires(s, f) {
  if (/\.(m?js|cjs)$/.test(f || '') && acorn) {
    const zones = [];
    for (const sourceType of ['script', 'module']) {
      try { acorn.parse(s, { ecmaVersion: 'latest', sourceType, allowHashBang: true, allowReturnOutsideFunction: true, onComment: (b, txt, d, e) => zones.push([d, e]) }); break; }
      catch (_) { zones.length = 0; }
    }
    let out = '', i = 0;
    for (const [d, e] of zones) { out += s.slice(i, d); i = e; }
    return out + s.slice(i);
  }
  if (/\.html$/.test(f || '')) return s.replace(/<!--[\s\S]*?-->/g, '');
  if (/\.sql$/.test(f || '')) return s.replace(/^\s*--[^\n]*/gm, '');
  return s;
}

test('aucun appel vers un onglet supprimé (Inventaire, Statistiques) ni vers le volet Inventaire disparu', () => {
  const interdits = [
    /switchSelfTab\(\s*['"](inventaire|stats)['"]/, /openSelfView\(\s*['"](inventaire|stats)['"]/, /switchCharSheetTab\(\s*['"]stats['"]/,
    /(?<!function\s)toggleInventaire\s*\(/, /['"#]inv-chevron\b/, /getElementById\(\s*['"]inv-items['"]\s*\)\s*\./, /cs-tab-(btn-)?stats/,
    /data-i18n="plateau\.myStats"/, /data-i18n="plateau\.statistics"/, /_ongletSelfActif\s*[!=]==?\s*['"]inventaire['"]/
  ];
  const fautes = [];
  for (const f of FICHIERS) {
    const s = sansCommentaires(lire(f), f);
    for (const re of interdits) {
      const m = s.match(re);
      if (m) fautes.push(f + ' : ' + m[0]);
    }
  }
  assert.deepEqual(fautes, []);
});

test('les onglets de « Mon personnage » dans plateau.html sont exactement SELF_ONGLETS, dans le même ordre', () => {
  const html = lire('plateau.html'), js = lire('plateau-personnage.js');
  const vue = html.slice(html.indexOf('<div id="vue-self"'), html.indexOf('<div id="self-content"'));
  const onglets = [...vue.matchAll(/switchSelfTab\('([a-z]+)',this\)/g)].map(m => m[1]);
  const declares = JSON.parse(js.match(/const SELF_ONGLETS = (\[[^\]]*\]);/)[1].replace(/'/g, '"'));
  assert.deepEqual(onglets, declares);
  assert.deepEqual(declares, ['actions', 'orgas', 'identite']);
  // Les anciennes portes mènent à la nouvelle place.
  assert.match(js, /SELF_ONGLETS_REDIRIGES = \{\s*inventaire: \(\) => \{ if \(typeof ouvrirFenetreInventaire === 'function'\) ouvrirFenetreInventaire\(\); \},\s*stats: \(\) => \{ if \(typeof montrerPanneauPersonnage === 'function'\) montrerPanneauPersonnage\(\); \}/);
  // Aucun rang d'onglet écrit en dur (l'onglet Identité était au rang 3 avant la suppression).
  assert.doesNotMatch(sansCommentaires(js, 'plateau-personnage.js'), /piece-tab'\)\[\d\]/);
});

test('panneau de gauche : ordre décidé par Fred, plus de « Mes statistiques », Argent et Inventaire ouvrent leur fenêtre', () => {
  const html = lire('plateau.html');
  const gauche = html.slice(html.indexOf('<div id="left">'), html.indexOf('<!-- CENTER -->'));
  const rang = cle => { const i = gauche.indexOf(cle); assert.ok(i > 0, 'absent du panneau : ' + cle); return i; };
  const ordre = ['id="char-photo-left"', 'id="char-fullname-left"', 'id="char-arch-left"', 'id="stat-mini-grid"', 'id="r-pa"', 'id="hg-jauge-sante"',
    'id="hg-jauge-moral"', 'id="hg-jauge-influence"', 'id="hg-jauge-popularite"', 'id="hg-jauge-discretion"', 'onclick="ouvrirFenetreArgent()"',
    'onclick="afficherObjectifsSecrets()"', 'data-i18n="plateau.myEmployees"', 'onclick="ouvrirFenetreInventaire()"'].map(rang);
  assert.deepEqual(ordre, ordre.slice().sort((a, b) => a - b), 'ordre du panneau de gauche');
  assert.doesNotMatch(gauche, /openSelfView\(|Mes Statistiques|inventaire-panel|inv-items/);
});

test('chaque onclick de plateau.html appelle une fonction qui existe dans un script de la page', () => {
  const html = lire('plateau.html');
  const scripts = [...html.matchAll(/<script src="([^"?]+)/g)].map(m => m[1]).filter(f => fs.existsSync(path.join(R, f)));
  const enLigne = [...html.matchAll(/<script(?![^>]*\ssrc=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]);
  const source = scripts.map(lire).concat(enLigne).join('\n');
  const definies = new Set([...source.matchAll(/(?:function\s+|global\.|window\.|globalThis\.)([A-Za-z_$][\w$]*)\s*(?:\(|=)/g)].map(m => m[1]));
  for (const m of source.matchAll(/(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/g)) definies.add(m[1]);
  const natifs = new Set(['event', 'document', 'window', 'this', 'if', 'return', 'setTimeout', 'alert', 'confirm', 'history', 'location']);
  const manquantes = new Set();
  for (const m of html.matchAll(/\sonclick="([^"]*)"/g)) {
    for (const a of m[1].matchAll(/(?:^|[;\s(!&|])([A-Za-z_$][\w$]*)\s*\(/g)) {
      const nom = a[1];
      if (natifs.has(nom) || definies.has(nom)) continue;
      if (/\.\s*$/.test(m[1].slice(0, a.index + a[0].indexOf(nom)))) continue;   // méthode d'un objet (x.remove())
      manquantes.add(nom);
    }
  }
  assert.deepEqual([...manquantes].sort(), [], 'onclick vers une fonction inexistante');
});

test('fiche d’objet : les anciens noms restent des alias de la fiche unique ; l’aide pointe la fiche unique', () => {
  const js = lire('plateau-personnage.js');
  assert.match(js, /async function ouvrirDetailObjetInventaire\(idx\) \{ return ouvrirFicheObjet\(idx\); \}/);
  assert.match(js, /function ouvrirDetailObjet\(idx\) \{ return ouvrirFicheObjet\(idx\); \}/);
  assert.equal((js.match(/^(async )?function ouvrirFicheObjet\(/gm) || []).length, 1);
  assert.match(lire('api/_aide-themes.js'), /ancre:'async function ouvrirFicheObjet\('/);
  // Tous les appelants du dépôt atteignent une fonction qui existe.
  for (const f of FICHIERS) {
    const s = sansCommentaires(lire(f), f);
    for (const m of s.matchAll(/\b(ouvrirDetailObjet\w*|ouvrirFicheObjet|ouvrirFenetreInventaire|ouvrirFenetreArgent|ouvrirRepartitionPoints|ouvrirStatsPerso|montrerPanneauPersonnage|rafraichirFenetreInventaireSiOuverte|rafraichirOngletInventaireSiOuvert)\b/g)) {
      assert.match(lire('plateau-personnage.js') + lire('plateau-pnj.js') + lire('plateau-divers.js'), new RegExp('function ' + m[1] + '\\('), f + ' appelle ' + m[1]);
    }
  }
});

test('parcours d’accueil et objectifs : aucune étape ne vise un onglet supprimé', () => {
  const fichiers = FICHIERS.filter(f => /accueil|quete|objectif|organisations-quetes|aide|guide/i.test(f));
  assert.ok(fichiers.length >= 5, 'fichiers d’accueil introuvables');
  for (const f of fichiers) {
    const s = sansCommentaires(lire(f), f);
    assert.doesNotMatch(s, /piece-tab[^'"\n]*(inventaire|stats)|['"](onglet_)?(inventaire|stats)['"]\s*:\s*['"]?(#vue-self|switchSelfTab)/, f);
    assert.doesNotMatch(s, /Mes statistiques|onglet (« )?Inventaire|onglet (« )?Statistiques/i, f);
  }
});
