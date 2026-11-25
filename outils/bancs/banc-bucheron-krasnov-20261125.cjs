'use strict';
// Mission de jour du 25/11/2026, bloc 1.7 (décision de Fred) : un PNJ bûcheron au campement de la forêt de Krasnov (cour de
// l'exploitation forestière), visible sur l'image du lieu ; fiche DeepSeek avec son rôle et « L'ours ne se chasse pas… » ;
// portrait recadré depuis l'image.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('Grigori Toporkov : placé au campement (Krasnov), portrait recadré, fiche DeepSeek', async () => {
  const ctx = vm.createContext({ console, state: { country: 'soviet', currentCity: 'ville_b' } });
  vm.runInContext(lire('data.js'), ctx);
  const p = vm.runInContext("WORLD.soviet.ville_b.buildingContext['zone-production'].roomOverrides.zone_recolte", ctx);
  assert.equal(p.imageUrl, 'images/Sovarka/Krasnov/Krasnov_exploitation_forestiere_cour.webp', 'le PNJ suit l’image de la cour');
  assert.equal(p.persons.length, 1);
  const b = p.persons[0];
  assert.equal(b.name, 'Grigori Toporkov (PNJ)'); assert.equal(b.profilId, 'grigori_toporkov');
  assert.ok(fs.existsSync(path.join(root, b.photoUrl)), 'portrait présent'); assert.doesNotMatch(b.photoUrl, / /);
  const { profilsPersonnalites } = await import(path.join(root, 'api/_pnj-personnalites.js'));
  const f = (typeof profilsPersonnalites === 'function' ? profilsPersonnalites() : profilsPersonnalites).grigori_toporkov;
  assert.ok(f, 'fiche');
  const tout = JSON.stringify(f).replace(/\\n/g, ' ');
  assert.match(tout, /Couper du bois, ça permet de vivre confortablement, sauf si on y laisse un membre dans un combat contre un ours ou des loups…/);
  assert.match(tout, /L'ours ne se chasse pas, c'est l'ours qui vous chasse…/);
  assert.match(lire('api/_pnj-scenes-generes.js'), /Grigori Toporkov/);
});
