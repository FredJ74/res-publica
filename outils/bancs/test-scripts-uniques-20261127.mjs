// Chasse aux bugs du 27/11/2026 : la page d'accueil chargeait data.js deux fois (reste de la fusion de la Purge du 24/11) ;
// le second chargement levait « Identifier 'COUNTRIES' has already been declared » dans la console des joueurs.
// Aucune page ne charge deux fois le même script.
// Lancer : node --test outils/bancs/test-scripts-uniques-20261127.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('chaque page HTML charge chaque script une seule fois', () => {
  const pages = readdirSync(racine).filter(f => f.endsWith('.html'));
  assert.ok(pages.includes('index.html') && pages.includes('plateau.html'));
  for (const page of pages) {
    const sources = [...readFileSync(path.join(racine, page), 'utf8').matchAll(/<script[^>]+src="([^"?]+)/g)].map(m => m[1]);
    const doublons = sources.filter((s, i) => sources.indexOf(s) !== i);
    assert.deepEqual(doublons, [], page);
  }
});

test('accueil : data.js chargé une fois, avant creation.js qui lit COUNTRIES', () => {
  const html = readFileSync(path.join(racine, 'index.html'), 'utf8');
  assert.equal((html.match(/<script src="data\.js\?/g) || []).length, 1);
  assert.ok(html.indexOf('<script src="data.js?') < html.indexOf('<script src="creation.js?'));
});
