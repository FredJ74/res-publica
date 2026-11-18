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
// Juge Arkadi Prigovorov et greffière d'audience Bayarma Namsaraeva, recadrés du décor (Fred, 18/11/2026) ; plus de Dulma Tsyrenova.
const audience = ctx.roomOverrides.salle_audience_locale.persons;
assert.deepEqual(Array.from(audience, p => p.name), ['Arkadi Prigovorov (PNJ)', 'Bayarma Namsaraeva (PNJ)']);
assert.equal(audience[0].job, 'juge'); assert.equal(audience[1].role, 'Greffière');
for (const [p, f] of [[audience[0], 'arkadi-prigovorov'], [audience[1], 'bayarma-namsaraeva']]) {
  const photo = p.photo || p.photoUrl || p.imageUrl || p.portrait;
  assert.match(String(photo), new RegExp('Starovka_portrait_tribunal-local_' + f + '\\.webp$'));
  assert.ok(fs.existsSync(path.join(root, photo)));
}
assert.ok(!fs.existsSync(path.join(root, 'images/Sovarka/Starovka/Starovka_portrait_tribunal-local_dulma-tsyrenova.webp')));
console.log('OK : tribunal de Starovka, trois décors, juge et greffière d\'audience');

// Centre artisanal (accueil + Box 1 à 3) et PNJ adaptés aux images (16/11/2026, soir).
const centre = c.W.soviet.ville_a.buildingContext['centre-artisanal'];
for (const [piece, f] of Object.entries({ travees: 'accueil', echoppe_facade: 'box_1', atelier_milieu: 'box_2', reserve_arriere: 'box_3' })) {
  const url = centre.roomOverrides[piece].imageUrl;
  assert.equal(url, 'images/Sovarka/Starovka/Starovka_centre_artisanal_' + f + '.webp');
  assert.equal(fs.readFileSync(path.join(root, url)).subarray(12, 16).toString('ascii'), 'VP8 ');
}
const noms = Array.from(centre.roomOverrides.travees.persons, p => p.name);
assert.deepEqual([...noms], ['Saryuna Dorjieva (PNJ)']); // Fred, 18/11/2026 : seule la réceptionniste reste
const greffiere = ctx.roomOverrides.greffe.persons[0];
assert.equal(greffiere.name, 'Oyuna Tsybikova (PNJ)');
for (const p of [centre.roomOverrides.travees.persons[0], greffiere]) assert.ok(fs.existsSync(path.join(root, p.photoUrl)));
assert.ok(!/Starovka/.test(c.W.soviet.ville_b.buildingContext['centre-artisanal'].roomOverrides.travees.imageUrl));
assert.ok(fs.readFileSync(path.join(root, 'i18n/sovarka-roles-resources.js'), 'utf8').includes('["Greffière","Court clerk"'));
console.log('OK : centre artisanal de Starovka, réceptionniste et greffière');
