// Juge de l'énigme du musée (décision de Fred, 01/11/2026) : l'ordre n'est visible et utilisable que
// pendant l'enquête, tant que l'autorisation du coffre n'est pas obtenue (même principe que
// « Présenter une autorisation judiciaire » à la Banque Nationale).
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

function charger(enigme1) {
  const src = lire('plateau-enigme-portrait.js');
  const c = { toasts: [], couts: 0, state: { char: { enigme1 } } };
  c.showToast = (...x) => c.toasts.push(x);
  c.deduireCoutOrdre = async () => { c.couts++; return { ok: false }; };
  c.signalerRefusCout = () => {};
  vm.createContext(c);
  const e = src.indexOf('function enigme1EtapeActive(');
  vm.runInContext(src.slice(e, src.indexOf('// Renvoie l', e)), c);
  // Jusqu'au prélèvement seulement : la suite (fenêtre du juge) n'est pas l'objet de ce test.
  const d = src.indexOf('async function doDemanderJugeInstruction(');
  vm.runInContext(src.slice(d, src.indexOf('  const dossier =', d)) + '}', c);
  return c;
}

test('hors enquête ou après autorisation : refus nommé, aucun coût', async () => {
  for (const e of [undefined, { etape: 'resolue' }, { etape: 'declenchee', autorisationCoffre: true }]) {
    const c = charger(e);
    await c.doDemanderJugeInstruction(1, 0);
    assert.equal(c.couts, 0);
    assert.equal(c.toasts.length, 1);
  }
});

test('pendant l\'enquête : le juge reçoit (le coût est demandé)', async () => {
  for (const etape of ['declenchee', 'relancee']) {
    const c = charger({ etape });
    await c.doDemanderJugeInstruction(1, 0);
    assert.equal(c.couts, 1);
  }
});

test('l\'écran masque l\'ordre hors enquête', () => {
  assert.match(lire('plateau-politique.js'),
    /o\.fn !== 'demander_juge_instruction' \|\| \(\s*\['declenchee', 'relancee'\]\.includes\(state\.char\?\.enigme1\?\.etape\) &&\s*!state\.char\?\.enigme1\?\.autorisationCoffre/);
});
