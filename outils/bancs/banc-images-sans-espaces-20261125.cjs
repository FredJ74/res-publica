'use strict';
// Mission de jour du 25/11/2026, bloc 1.9 (décision de Fred, suite de la Purge E.2) : toutes les images dont le nom contient
// des espaces sont renommées (espaces → « _ », accents retirés, extension .webp en minuscules, faute « Starkova » corrigée),
// avec réécriture de l'ancienne adresse dans vercel.json et mise à jour des références. Correspondance :
// outils/bancs/fixtures/images-espaces-renommees-20261125.json.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MAP = JSON.parse(lire('outils/bancs/fixtures/images-espaces-renommees-20261125.json'));

test('plus aucune image suivie dont le nom contient un espace', () => {
  const suivies = execFileSync('git', ['-c', 'core.quotepath=off', 'ls-files', '-z', 'images'], { cwd: R, encoding: 'utf8' }).split('\0').filter(Boolean);
  assert.deepEqual(suivies.filter(p => path.basename(p).includes(' ')), []);
  assert.ok(Object.keys(MAP).length >= 38);
});

test('nouveaux fichiers présents, anciennes adresses réécrites, aucune référence active à un ancien nom', () => {
  const v = JSON.parse(lire('vercel.json'));
  const actifs = ['data.js', 'plateau-rue-centrale.js', 'plateau-navigation.js', 'plateau-personnage.js'].map(lire).join('\n').normalize('NFC');
  for (const [ancien, nouveau] of Object.entries(MAP)) {
    assert.ok(fs.existsSync(path.join(R, nouveau)), nouveau);
    assert.doesNotMatch(nouveau, /[ ^À-ÿ]/, 'nom sûr : ' + nouveau);
    assert.ok(v.rewrites.some(r => r.source === '/' + encodeURI(ancien.normalize('NFC')) && r.destination === '/' + nouveau), 'réécriture : ' + ancien);
    assert.ok(!actifs.includes(ancien.normalize('NFC')), 'référence active : ' + ancien);
  }
});
