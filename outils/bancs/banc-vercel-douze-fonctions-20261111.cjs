'use strict';
// L'offre Vercel du projet n'accepte pas plus de 12 fonctions serveur par déploiement : au-delà,
// le déploiement échoue et la production n'est plus mise à jour (incident du 11/11/2026, api/aide.js).
// Un module partagé se nomme api/_xxx.js (non déployé comme fonction) et passe par une fonction existante.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const racine = path.resolve(__dirname, '../..');

test('au plus 12 fonctions serveur dans api/', () => {
  const fonctions = fs.readdirSync(path.join(racine, 'api')).filter(f => /\.(js|mjs|cjs|ts)$/.test(f) && !f.startsWith('_'));
  assert.ok(fonctions.length <= 12, fonctions.length + ' fonctions : ' + fonctions.join(', '));
});

test("l'aide HRP passe par /api/chat (redirection et délégation)", () => {
  const v = JSON.parse(fs.readFileSync(path.join(racine, 'vercel.json'), 'utf8'));
  assert.ok((v.rewrites || []).some(r => r.source === '/api/aide' && r.destination === '/api/chat?mode=aide'));
  const chat = fs.readFileSync(path.join(racine, 'api/chat.js'), 'utf8');
  assert.match(chat, /req\.query\.mode === 'aide'\) return handlerAide\(req, res\)/);
  assert.ok(!fs.existsSync(path.join(racine, 'api/aide.js')));
});
