#!/usr/bin/env node
// Non-régression Krasnov : Ignat Lykov, images et dialogue (15/11/2026).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = file => fs.readFileSync(path.join(root, file), 'utf8');
const data = lire('data.js');
const pnj = lire('api/_pnj-personnalites.js');
const toast = lire('api/_reaction-habitant.js');
const rue = lire('plateau-rue-centrale.js');
const maison = data.slice(data.indexOf("['maison-krasnov-terrains'"), data.indexOf("['maison-krasnov-terrains'") + 850);
assert.ok(maison.includes("'Ignat Lykov', 'Fonctionnaire à la retraite'"));
assert.ok(maison.includes("'images/Sovarka/Krasnov/Krasnov_maison_ignat_interieur.webp', 'images/Sovarka/Krasnov/Ignat.webp'"));
assert.ok(rue.includes("buildingId: 'maison-krasnov-terrains'"));
assert.ok(pnj.includes("'ignat_lykov':"));
assert.ok(pnj.includes('tu ne le mets JAMAIS dehors'));
assert.ok(toast.includes("'Ignat Lykov': \"Tu es Ignat Lykov, fonctionnaire retraité"));
assert.ok(!maison.includes('vieux trappeur'));
for (const f of ['images/Sovarka/Krasnov/Krasnov_maison_ignat_interieur.webp', 'images/Sovarka/Krasnov/Ignat.webp']) {
  const bytes = fs.readFileSync(path.join(root, f));
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', f);
  assert.equal(bytes.toString('ascii', 8, 12), 'WEBP', f);
  assert.equal(bytes.toString('ascii', 12, 16), 'VP8 ', 'WebP avec perte attendu : ' + f);
}
for (const f of ['images/Krasnov_maison_ignat_interieur.webp', 'images/Ignat.webp']) {
  assert.ok(!fs.existsSync(path.join(root, f)), 'Original racine non supprimé : ' + f);
}
console.log('Ignat Krasnov : décor, portrait VP8, placement et dialogue conformes.');
