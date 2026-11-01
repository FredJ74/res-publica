// Contre-épreuve uniquement : substitue en mémoire le JS de #212, jamais sur disque.
// node --require ./outils/bancs/fixtures/securite-135-client-original.cjs --test outils/bancs/banc-interception-reseau.cjs
// Attendu : seul le nouvel effectif échoue (3 !== 1). Un défaut de chargement ne vaut pas preuve.
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const racine = path.resolve(__dirname, '../../..');
const fichier = path.join(racine, 'plateau-justice-economie.js');
const source = execFileSync('git', ['show', '7c91ef1b0767d6ffc3dfa37be9cbc1c13ab430f1:plateau-justice-economie.js'], {cwd:racine, encoding:'utf8'});
const lire = fs.readFileSync;
fs.readFileSync = function(cible, ...args) {
  if (String(cible) === fichier) return args[0] === 'utf8' ? source : Buffer.from(source);
  return lire.call(this, cible, ...args);
};
