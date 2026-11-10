// Regressions : /api/chat n'effectue aucune remise d'objets ; son prompt ne doit
// pas faire croire que parler a un PNJ alimente l'inventaire du PJ.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { construirePromptSysteme, profilExiste } from '../../api/_pnj-profils.js';

const source = readFileSync(new URL('../../api/chat.js', import.meta.url), 'utf8');
assert.match(source, /return res\.status\(200\)\.json\(\{ reponse:/);
assert.doesNotMatch(source, /inventaire_(?:ajouter|remettre|sauver)|objet_trouve_reclamer|objet_acheter|pnj_objet_transferer/);

for (const id of ['jodie_moitout', 'jodie_moitout_autruche']) {
  assert.ok(profilExiste(id), 'Profil absent : ' + id);
  const systeme = construirePromptSysteme(id, 'fr');
  assert.ok(systeme);
  assert.match(systeme, /OBJETS ET REMISES/);
  assert.match(systeme, /ne d[ée]clare JAMAIS avoir remis/);
  assert.match(systeme, /Seule une action de jeu effectivement confirm[ée]e/);
}
// La meme contrainte s'applique a tous les profils, pas seulement a Jodie.
for (const id of ['jeremy']) {
  assert.ok(profilExiste(id));
  assert.match(construirePromptSysteme(id, 'fr'), /OBJETS ET REMISES/);
}
console.log('PNJ : garde anti-remise fictive OK (textuel, sans appel IA)');
// IMPORTANT : ce banc controle le prompt, pas le comportement probabiliste de DeepSeek.
