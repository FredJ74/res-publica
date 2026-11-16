'use strict';
// Banc : décors du Tribunal Populaire de Starovka (images de Fred, 16/11/2026).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const c = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8') + ';this.W=WORLD;this.B=BUILDINGS;', c);

const ctx = c.W.soviet.ville_a.buildingContext['tribunal-local'];
const attendu = {
  salle_audience_locale: 'Starovka_tribunal_salle_audience.webp',
  bureau_magistrats: 'Starovka_tribunal_bureau_magistrats.webp',
  greffe: 'Starovka_tribunal_greffe.webp'
};
for (const [piece, fichier] of Object.entries(attendu)) {
  const url = ctx.roomOverrides[piece].imageUrl;
  assert.equal(url, 'images/Sovarka/Starovka/' + fichier, 'image de ' + piece);
  const entete = fs.readFileSync(path.join(root, url)).subarray(0, 16);
  assert.equal(entete.toString('ascii', 8, 12), 'WEBP');
  assert.equal(entete.toString('ascii', 12, 16), 'VP8 ', 'WebP avec perte attendu pour ' + fichier);
}
// Le gabarit partagé et Krasnov ne changent pas.
assert.ok(!/Starovka/.test(c.B['tribunal-local'].rooms.greffe.imageUrl || ''));
const krasnov = c.W.soviet.ville_b.buildingContext['tribunal-local'];
for (const piece of Object.keys(attendu))
  assert.ok(!/Starovka/.test(krasnov.roomOverrides?.[piece]?.imageUrl || ''), 'Krasnov intact : ' + piece);
// Portrait de la juge.
const juge = ctx.roomOverrides.salle_audience_locale.persons.find(p => p.name === 'Dulma Tsyrenova (PNJ)');
assert.ok(juge, 'juge Dulma Tsyrenova présente');
const photo = juge.photo || juge.photoUrl || juge.imageUrl || juge.portrait;
assert.match(String(photo), /Starovka_portrait_tribunal-local_dulma-tsyrenova\.webp$/);
assert.ok(fs.existsSync(path.join(root, photo)));
console.log('OK : tribunal de Starovka, trois décors et portrait de la juge');
