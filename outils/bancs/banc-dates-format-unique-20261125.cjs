'use strict';
// Mission de jour du 25/11/2026, bloc 1.5 (décision de Fred) : un seul format de date partout — « 23/11 à 18 h 48 », heure de
// Paris — dans le journal et le chat comme dans le forum et le courrier (Purge B.4).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const extraire = (src, nom) => { const i = src.indexOf('function ' + nom + '('); assert.ok(i >= 0, nom); return src.slice(i, src.indexOf('\n}\n', i) + 2); };

test('journal : « 23/11 à 18 h 48 », heure de Paris (hiver et été), même rendu que le forum', () => {
  const ctx = {}; vm.createContext(ctx);
  vm.runInContext(extraire(lire('plateau-core.js'), 'formaterHorodatageJournal') + extraire(lire('forum.js'), 'rpDecalageParisMs')
    + extraire(lire('forum.js'), 'rpInstantForum') + extraire(lire('forum.js'), 'rpDateLisible'), ctx);
  assert.equal(ctx.formaterHorodatageJournal('2026-11-23T17:48:00Z'), '23/11 à 18 h 48');
  assert.equal(ctx.formaterHorodatageJournal('2026-07-02T06:05:00Z'), '02/07 à 08 h 05');
  assert.equal(ctx.formaterHorodatageJournal(''), null);
  assert.equal(ctx.formaterHorodatageJournal('pas une date'), null);
  for (const iso of ['2026-11-23T17:48:00Z', '2026-03-29T01:30:00Z', '2026-12-31T23:59:00Z'])
    assert.equal(ctx.formaterHorodatageJournal(iso), ctx.rpDateLisible(iso), iso);
});

test('chat et anciennes entrées du journal : même format', () => {
  const chat = lire('plateau-multijoueur.js');
  assert.match(chat, /const heureMsg = m\.created_at \? \(\(typeof formaterHorodatageJournal === 'function' && formaterHorodatageJournal\(m\.created_at\)\)/);
  assert.doesNotMatch(chat, /heureMsg = [^\n]*toLocaleTimeString/);
  assert.match(extraire(lire('plateau-core.js'), 'restaurerJournal'), /\$\{jm\[3\]\}\/\$\{jm\[2\]\} à \$\{h\} h 00/);
});
