// Banc : affichage des événements climatiques (Fred, 21/11/2026) — flèches nettes au-dessus de l'effet, alerte discrète
// qui clignote lentement dans les vues de rue uniquement.
const test = require('node:test'); const assert = require('node:assert'); const fs = require('fs'); const path = require('path');
const c = fs.readFileSync(path.join(__dirname, '..', '..', 'plateau-climat.js'), 'utf8');

test('le filtre se pose dans la scène de rue, sous les flèches de navigation', () => {
  assert.match(c, /const hote = doc\.getElementById\('rc-scene'\) \|\| rue;/);
  assert.match(c, /#climat-filtre\{position:absolute;inset:0;pointer-events:none;z-index:3\}/);
  assert.match(c, /#rc-scene \.rc-fleche,#rue-image \.rc-fleche\{position:absolute;z-index:1001\}/);
});

test('alerte « Attention … » : vues de rue seulement, clignotement lent, sans clic', () => {
  for (const t of ['brouillard', 'blizzard', 'orage', 'crue', 'canicule']) assert.ok(c.includes(t + ": 'Attention " + t + "'"), t);
  assert.match(c, /#climat-alerte\{[^}]*pointer-events:none;/);
  assert.match(c, /animation:climatAlerte 4s ease-in-out infinite/);
  assert.match(c, /@keyframes climatAlerte\{0%,100%\{opacity:\.9\}50%\{opacity:\.35\}\}/);
  // Hôte = scène ou image de la rue : rien dans les pièces.
  assert.match(c, /if \(!ev \|\| !hote\) \{ if \(f\) f\.remove\(\); if \(a\) a\.remove\(\); return; \}/);
  assert.match(c, /setInterval\(appliquerFiltre, 1500\)/);
});
