// Mission « Purge » (Fred, 24/11/2026), point B.6 : saisie de gauche à droite partout, sauf en arabe.
// Chromium réel, vrai plateau.html et vrai sens-saisie.js : un champ dir="auto" (organisations, forum, élections…),
// un champ ajouté plus tard, une zone éditable du forum et un champ remis à dir="auto" après coup passent tous en
// gauche à droite ; en arabe, tous de droite à gauche ; le texte saisi n'est jamais modifié.
// Lancement : node --test outils/bancs/banc-sens-saisie-navigateur-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page } = require('./mobile-navigateur.cjs');
const R = path.resolve(__dirname, '../..');

test('pages : sens-saisie.js chargé par plateau.html et index.html', () => {
  for (const f of ['plateau.html', 'index.html']) assert.match(fs.readFileSync(path.join(R, f), 'utf8'), /<script src="sens-saisie\.js\?v=/, f);
});

test('champs de saisie : gauche à droite hors arabe, droite à gauche en arabe, quel que soit le premier caractère', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 1280, 860);
  await p.evaluate(() => {
    window.RPPlateauI18n = { language: () => window.__langue || 'fr' };
    document.body.insertAdjacentHTML('beforeend', '<div id="essai"><input id="c1" type="text" dir="auto" value="١٢ مرحبا"><textarea id="c2" dir="auto">123 bonjour</textarea>'
      + '<input id="c3" type="checkbox" dir="auto"><input id="c4" type="text" dir="auto" data-sens-libre></div>');
  });
  await p.addScriptTag({ url: o + '/sens-saisie.js' });
  const sens = () => p.evaluate(() => ['c1', 'c2', 'c3', 'c4', 'c5', 'c6'].map(id => document.getElementById(id)?.getAttribute('dir') ?? null));
  assert.deepEqual((await sens()).slice(0, 4), ['ltr', 'ltr', 'auto', 'auto'], 'champs texte en ltr ; case à cocher et champ libre intacts');
  // Champ ajouté par une fenêtre, zone éditable (éditeur du forum), champ remis à dir="auto" par un autre code.
  await p.evaluate(() => {
    document.getElementById('essai').insertAdjacentHTML('beforeend', '<input id="c5" dir="auto"><div id="c6" contenteditable="true">x</div>');
    document.getElementById('c2').setAttribute('dir', 'auto');
  });
  await p.waitForTimeout(50);
  assert.deepEqual(await sens(), ['ltr', 'ltr', 'auto', 'auto', 'ltr', 'ltr']);
  await p.evaluate(() => { window.__langue = 'ar'; window.rpAppliquerSensSaisie(); });
  assert.deepEqual(await sens(), ['rtl', 'rtl', 'auto', 'auto', 'rtl', 'rtl'], 'arabe : droite à gauche');
  assert.equal(await p.evaluate(() => document.getElementById('c2').value), '123 bonjour', 'texte inchangé');
}));
