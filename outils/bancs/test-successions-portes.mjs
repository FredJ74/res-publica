// Garde des successions (03/11/2026) : l'écran ne crée ni ne modifie plus une ligne `successions`.
// L'ouverture passe par succession_ouvrir, la réponse d'un héritier par succession_repondre
// (migration 20261103110000). Ce test rougit si une écriture directe réapparaît.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const racine = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const sansCommentaires = t => t.split('\n').filter(l => !/^\s*\/\//.test(l)).join('\n');
const lire = f => sansCommentaires(readFileSync(join(racine, f), 'utf8'));
function bloc(src, nom) {
  const i = src.indexOf('async function ' + nom + '(');
  assert.ok(i >= 0, 'introuvable : ' + nom);
  let p = 0, k = src.indexOf('{', i);
  for (; k < src.length; k++) { if (src[k] === '{') p++; else if (src[k] === '}' && !--p) break; }
  return src.slice(i, k + 1);
}

test('aucune écriture directe de successions dans les fichiers de l’écran', () => {
  const fichiers = readdirSync(racine).filter(f => f.endsWith('.js'));
  for (const f of fichiers) {
    const src = lire(f);
    assert.ok(!/sb(Insert|Update|Upsert)\(\s*['"]successions['"]/.test(src), f + ' écrit successions');
    assert.ok(!/sbCreerSuccession|sbUpdateSuccession/.test(src), f + ' garde une primitive d’écriture');
  }
});

test('l’ouverture et la réponse passent par leurs portes serveur', () => {
  const src = readFileSync(join(racine, 'plateau-personnage.js'), 'utf8');
  assert.ok(bloc(src, 'ouvrirSuccession').includes("sbRpc('succession_ouvrir'"));
  const rep = bloc(src, 'doRepondreHeritage');
  assert.ok(rep.includes("sbRpc('succession_repondre'"));
  assert.ok(!rep.includes('Date.now()'), 'l’échéance est jugée par le serveur');
});
