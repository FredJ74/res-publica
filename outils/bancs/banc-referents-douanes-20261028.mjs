// Vérifie que les deux référents douanes s'appuient sur le constructeur
// de prompt serveur existant plutôt que sur une connaissance fournie par le navigateur.
import assert from 'node:assert/strict';
import { profilExiste, construirePromptSysteme } from '../../api/_pnj-profils.js';

for (const id of ['pascal_paguevite', 'inspecteur_prosper_tampon']) {
  assert.equal(profilExiste(id), true, id + ' introuvable');
  const prompt = construirePromptSysteme(id, 'fr');
  assert.ok(typeof prompt === 'string' && prompt.length > 100, id);
  assert.match(prompt, /caisse sur trois/i);
  assert.match(prompt, /30 %/);
  assert.match(prompt, /trois agents/);
  assert.match(prompt, /non recherchés/);
  assert.match(prompt, /non déclarées/);
}
console.log('OK : référents douanes informés par le prompt serveur commun');
