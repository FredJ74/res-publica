// Regressions : /api/chat n'effectue aucune remise d'objets ; son prompt ne doit
// pas faire croire que parler a un PNJ alimente l'inventaire du PJ.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
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
const debut = source.indexOf('export function neutraliserRemiseFictive(');
const fin = source.indexOf('\nexport default async function handler(', debut);
assert.ok(debut >= 0 && fin > debut);
const garde = source.slice(debut, fin).replace('export function', 'function');
const ctx = vm.createContext({});
vm.runInContext(garde + '\nthis.garde=neutraliserRemiseFictive;', ctx);
assert.match(ctx.garde('Je vous remets cette montre suisse.', 'fr'), /ne peux pas vous remettre/);
assert.match(ctx.garde('Tenez le recueil.', 'fr'), /ne peux pas vous remettre/);
assert.equal(ctx.garde('Je vous montre le recueil.', 'fr'), 'Je vous montre le recueil.');
assert.match(ctx.garde('I hand you this book.', 'en'), /cannot hand over/);
assert.match(ctx.garde('Te entrego el libro.', 'es'), /no puedo entregarle/);
assert.match(ctx.garde('我把這本書交給你。', 'zh'), /無法在對話中/);
assert.match(ctx.garde('제가 책을 드릴게요.', 'ko'), /전달할 수는/);
console.log('PNJ : prompt + blocage serveur anti-remise fictive OK (sans appel IA)');
// IMPORTANT : ce banc controle le prompt, pas le comportement probabiliste de DeepSeek.
