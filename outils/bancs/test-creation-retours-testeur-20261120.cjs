'use strict';
// Retours d'un testeur (20/11/2026).
//  1. Inscription : un message « adresse invalide » restait affiché pendant que le joueur corrigeait son adresse ; toute saisie
//     l'efface désormais (inscription et connexion) ; caractères invisibles d'un copier-coller retirés avant le contrôle.
//     Vérifié dans Chrome le 20/11 : « jean.dupont@gmail » → message ; saisie « jean.dupont@gmail.com » → message effacé.
//  2. Création : les modificateurs de caractéristiques affichent le nom complet traduit et la description en infobulle
//     (clés existantes creation.stats.<CLE>.name / .description, neuf langues) au lieu de l'abréviation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const js = fs.readFileSync(path.join(racine, 'creation.js'), 'utf8');

function extraire(nom) {
  const i = js.indexOf('function ' + nom + '(');
  assert.ok(i >= 0, nom);
  let p = js.indexOf('{', i), n = 0, j = p;
  for (; j < js.length; j++) { if (js[j] === '{') n++; else if (js[j] === '}' && --n === 0) break; }
  return js.slice(i, j + 1);
}

test('Modificateurs : nom complet, signe moins typographique, description en infobulle, aucune abréviation', () => {
  const noms = { VOL: 'Volonté', DUP: 'Duplicité', CHA: 'Charisme', ENT: 'Entregent' };
  const ctx = { t: (k) => { const m = /^creation\.stats\.(\w+)\.(name|description)$/.exec(k); return m ? (m[2] === 'name' ? noms[m[1]] : 'Décrit « ' + m[1] + ' » & co') : k; } };
  vm.createContext(ctx);
  vm.runInContext([extraire('rpEchapperAttribut'), extraire('htmlModificateurStat'), extraire('htmlModificateursStats')].join('\n'), ctx);
  const html = vm.runInContext("htmlModificateursStats({VOL:2,DUP:2},{ENT:-1})", ctx);
  assert.match(html, /<strong title="Décrit « VOL » &amp; co">\+2 Volonté<\/strong>/);
  assert.match(html, /<span style="color:#8a4020" title="Décrit « ENT » &amp; co">−1 Entregent<\/span>/);
  assert.doesNotMatch(html, /\b(VOL|DUP|ENT)\b(?! »)/);
  assert.doesNotMatch(js, /`<strong>\+\$\{v\} \$\{k\}<\/strong>`/);
  assert.doesNotMatch(js, /\$\{v\} \$\{k\}<\/span>/);
});

test('Inscription et connexion : la saisie efface le message précédent ; invisibles retirés avant le contrôle', () => {
  assert.match(js, /\['auth-email', 'auth-msg'\], \['auth-mdp', 'auth-msg'\], \['connexion-email', 'connexion-msg'\], \['connexion-mdp', 'connexion-msg'\]/);
  assert.match(js, /champ\.addEventListener\('input', \(\) => effacerMessageIdentifiants\(zone\)\)/);
  const n = (js.match(/\.replace\(\/\[\\u200B-\\u200D\\u2060\\uFEFF\]\/g, ''\)\.trim\(\)/g) || []).length;
  assert.equal(n, 2);
  const ctx = { document: { getElementById: (id) => champs[id] } };
  const champs = { 'auth-msg': { textContent: 'Cette adresse e-mail ne semble pas valide.', style: { display: 'block' }, removeAttribute() {} } };
  vm.createContext(ctx);
  vm.runInContext(extraire('effacerMessageIdentifiants'), ctx);
  vm.runInContext("effacerMessageIdentifiants('auth-msg')", ctx);
  assert.equal(champs['auth-msg'].textContent, '');
  assert.equal(champs['auth-msg'].style.display, 'none');
});

test('Catalogue français : noms accentués des caractéristiques', () => {
  const res = fs.readFileSync(path.join(racine, 'i18n/resources.js'), 'utf8');
  assert.match(res, /VOL: \{ name: "Volonté"/);
  assert.match(res, /DUP: \{ name: "Duplicité"/);
});
