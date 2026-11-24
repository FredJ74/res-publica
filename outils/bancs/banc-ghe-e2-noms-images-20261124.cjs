'use strict';
// Mission « Purge » (Fred, 24/11/2026), point E.2 : les vraies fautes dans les noms d'images sont corrigées (acceuil →
// accueil, EPHAD → EHPAD, amabassades → ambassades), fichier par fichier, avec redirection de l'ancienne adresse (vercel.json)
// et de toutes les références actives. Aucune référence en base (relevé du 24/11/2026). Pas de renommage en masse.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const RENOMMAGES = {
  'images/Sovarka/Novomirsk/Novomirsk_Commissariat_acceuil.webp': 'images/Sovarka/Novomirsk/Novomirsk_Commissariat_accueil.webp',
  'images/Sovarka/Novomirsk/Novomirsk_hopital_acceuil.webp': 'images/Sovarka/Novomirsk/Novomirsk_hopital_accueil.webp',
  'images/Sovarka/Novomirsk/Novomirsk_hopital_EPHAD.webp': 'images/Sovarka/Novomirsk/Novomirsk_hopital_EHPAD.webp',
  'images/Sovarka/Krasnov/Krasnov_hopital_EPHAD.webp': 'images/Sovarka/Krasnov/Krasnov_hopital_EHPAD.webp',
  'images/Sovarka/Novomirsk/Novomirsk_amabassades_Republia.webp': 'images/Sovarka/Novomirsk/Novomirsk_ambassades_Republia.webp'
};
test('E.2 — fichiers renommés, anciennes adresses redirigées, aucune référence active à l’ancien nom', () => {
  const vercel = JSON.parse(lire('vercel.json'));
  const actifs = ['data.js', 'plateau-rue-centrale.js', 'plateau-navigation.js', 'plateau-personnage.js'].filter(f => fs.existsSync(path.join(R, f))).map(lire).join('\n');
  for (const [ancien, nouveau] of Object.entries(RENOMMAGES)) {
    assert.ok(fs.existsSync(path.join(R, nouveau)), 'nouveau fichier : ' + nouveau);
    assert.ok(!fs.existsSync(path.join(R, ancien)), 'ancien fichier encore là : ' + ancien);
    assert.ok(vercel.rewrites.some(r => r.source === '/' + ancien && r.destination === '/' + nouveau), 'redirection : ' + ancien);
    assert.ok(!actifs.includes(ancien), 'référence active à l’ancien nom : ' + ancien);
    assert.ok(actifs.includes(nouveau), 'nouveau nom utilisé : ' + nouveau);
  }
  // Aucune autre image suivie ne porte encore ces fautes.
  const toutes = [];
  (function parcourir(d) { for (const e of fs.readdirSync(path.join(R, d), { withFileTypes: true })) {
    const p = d + '/' + e.name; if (e.isDirectory()) parcourir(p); else toutes.push(p); } })('images');
  assert.deepEqual(toutes.filter(p => /acceuil|EPHAD|amabassade/.test(p)), []);
});
