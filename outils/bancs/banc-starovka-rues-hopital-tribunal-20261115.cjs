#!/usr/bin/env node
'use strict';
// Parcours validé par Fred, Starovka : lycée -> hôpital -> tribunal/artisanat -> bureaux.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = p => fs.readFileSync(path.join(root, p), 'utf8');
const rue = lire('plateau-rue-centrale.js');
const sql = lire('migrations/20261115163000_starovka_hopital_tribunal_artisanal_rues.sql');
function bloc(noeud) {
  const start = rue.indexOf("    '" + noeud + "': {");
  assert.ok(start >= 0, 'Nœud inexistant : ' + noeud);
  const next = rue.indexOf("\n    '", start + 8);
  return rue.slice(start, next > 0 ? next : undefined);
}
const lycee = bloc('starovka-rue-lycee-commissariat');
const hopital = bloc('starovka-rue-hopital');
const tribunal = bloc('starovka-rue-tribunal-artisanal');
const bureaux = bloc('starovka-rue-bureaux-caserne');
assert.match(lycee, /gauche: 'starovka-rue-hopital'/);
assert.match(hopital, /droite: 'starovka-rue-lycee-commissariat'/);
assert.match(hopital, /gauche: 'starovka-rue-tribunal-artisanal'/);
assert.match(tribunal, /droite: 'starovka-rue-hopital'/);
assert.match(tribunal, /gauche: 'starovka-rue-bureaux-caserne'/);
assert.match(bureaux, /droite: 'starovka-rue-tribunal-artisanal'/);
assert.match(bureaux, /toutDroit: 'starovka-rue-magasin-chasse'/);
assert.match(hopital, /buildingId: 'dispensaire-public-v'/);
assert.match(tribunal, /buildingId: 'tribunal-local'/);
assert.match(tribunal, /buildingId: 'centre-artisanal'/);
for (const p of ['Starovka_rue_hopital.webp', 'Starovka_rue_tribunal_centre_artisanal.webp']) {
  assert.match(rue, new RegExp(p.replace(/\./g,'\\.')));
  const f = path.join(root, 'images/Sovarka/Starovka', p);
  assert.ok(fs.existsSync(f), 'WebP manquant : '+p);
  const b=fs.readFileSync(f);
  assert.equal(b.toString('ascii',0,4),'RIFF');
  assert.equal(b.toString('ascii',8,16),'WEBPVP8 ');
}
for (const n of ['starovka-rue-hopital','starovka-rue-tribunal-artisanal']) assert.ok(sql.includes(n));
for (const b of ['dispensaire-public-v','tribunal-local','centre-artisanal']) assert.ok(sql.includes(b));
console.log('Starovka : 4 noeuds, 6 trajets aller-retour, 3 bâtiments et 2 WebP VP8 conformes.');
