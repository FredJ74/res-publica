const assert = require('node:assert/strict');
const fs = require('node:fs');
const data = fs.readFileSync('data.js', 'utf8');
const nav = fs.readFileSync('plateau-navigation.js','utf8');
assert.match(data,/function villesDe\(pays\)/);
assert.match(data,/id, nom: t\[id\]\.nom, capitale: t\[id\]\.capitale/);
const start = nav.indexOf('function ouvrirModalTransport(mode)');
assert.ok(start >= 0);
const end = nav.indexOf('async function executerVoyage(',start);
const fn = nav.slice(start,end);
assert.match(fn,/const villes = villesDe\(pays\)/);
assert.match(fn,/ville\.nom/,'afficher le libellé canonique');
assert.doesNotMatch(fn,/ville\.name/,'ancienne propriété inexistant dans villesDe');
console.log('OK destinations multimodales: attribut nom du catalogue canonique');

const bloc = data.slice(data.indexOf("'centre-multimodal-luthecia':"));
assert.ok(bloc.includes("Mireille Guichet (PNJ)"), 'Mireille reste dans les personnages');
assert.ok(!bloc.slice(0,5000).includes("Demander conseil à Mireille"), 'aucun ordre de conseil automatique dans le hall');
