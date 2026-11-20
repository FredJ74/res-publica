'use strict';
// Portraits : deux comptes successifs dans le même navigateur gardent chacun leur portrait (bug de Fred du 20/11/2026 :
// Arnie s'affichait avec le portrait de Tom Tom ; en base, les deux portraits étaient distincts et corrects).
// Cause : une clé locale COMMUNE « respublica_photo » servait de repli à l'affichage de son propre portrait.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

function stockage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k),
    key: (i) => Array.from(m.keys())[i] || null, get length() { return m.size; }, _m: m };
}
function fonctions(ls, uid) {
  const sb = lire('supabase.js');
  const debut = sb.indexOf('function rpClePortrait('), fin = sb.indexOf('function sbPayloadPersonnage(');
  const g = { localStorage: ls, rpAuthUid: () => uid.valeur };
  vm.runInNewContext(sb.slice(debut, fin) + ';this.cle=rpClePortrait;this.purger=rpPurgerPortraitsLocaux;', g);
  return g;
}

test('Deux comptes successifs : chacun sa clé, jamais celle de l\'autre', () => {
  const ls = stockage(), uid = { valeur: 'compte-tom' };
  const g = fonctions(ls, uid);
  ls.setItem(g.cle('Tom Tom'), 'data:image/jpeg;TOM');
  uid.valeur = 'compte-arnie';                        // changement de compte dans le même navigateur
  assert.equal(ls.getItem(g.cle('Arnie')), null);     // Arnie ne lit jamais le portrait de Tom Tom
  ls.setItem(g.cle('Arnie'), 'data:image/webp;ARNIE');
  assert.notEqual(g.cle('Arnie'), g.cle('Tom Tom'));
  uid.valeur = 'compte-tom';
  assert.equal(ls.getItem(g.cle('Tom Tom')), 'data:image/jpeg;TOM');
  assert.match(g.cle('Tom Tom'), /^respublica_photo_compte-tom_Tom Tom$/);
  // Purge (déconnexion, changement de compte) : tous les portraits locaux disparaissent.
  ls.setItem('respublica_photo', 'ancien'); ls.setItem('respublica_char', '{}');
  g.purger();
  assert.deepEqual(Array.from(ls._m.keys()), ['respublica_char']);
});

test('Écran : plus aucune clé commune ; mon portrait vient d\'abord du serveur', () => {
  const tout = ['plateau-core.js', 'plateau-multijoueur.js', 'plateau-personnage.js', 'creation.js', 'supabase.js'].map(lire).join('\n');
  assert.doesNotMatch(tout, /getItem\('respublica_photo'\)/);
  assert.doesNotMatch(tout, /setItem\('respublica_photo',/);
  assert.match(lire('plateau-multijoueur.js'), /const photoUrl = char\?\.photoUrl \|\| savedPhoto;/);
  assert.match(lire('plateau-core.js'), /const photoUrl = char\.photoUrl \|\| photoSaved;/);
  assert.match(lire('plateau-core.js'), /if \(typeof rpPurgerPortraitsLocaux === 'function'\) rpPurgerPortraitsLocaux\(\);/);
  assert.match(lire('auth.js'), /rpPurgerCachePersonnage\('déconnexion volontaire'\)/);
});
