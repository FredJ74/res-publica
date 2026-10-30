// Banc : signature de l'acte chez le notaire (30/10/2026).
// Défaut signalé par Fred : l'écran annonçait le solde à payer sans permettre de le payer.
// Cause : traiterActeVente prélevait lui-même le solde par deduireCoutOrdre (refusé par le
// serveur, coût non déclaré pour l'ordre) avant d'appeler la porte d'acquisition, qui encaisse
// déjà solde + 1 PA à l'acte (et verse d'abord le prêt accordé).
// Le banc exécute la vraie fonction de plateau-justice-economie.js avec des doublures.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const src = fs.readFileSync(path.join(__dirname, '..', '..', 'plateau-justice-economie.js'), 'utf8');
const debut = src.indexOf('async function traiterActeVente(candidat)');
assert.ok(debut >= 0, 'traiterActeVente introuvable');
let i = src.indexOf('{', debut), prof = 0, fin = -1;
for (; i < src.length; i++) { if (src[i] === '{') prof++; else if (src[i] === '}' && --prof === 0) { fin = i + 1; break; } }
const code = src.slice(debut, fin);

function monter(arg) {
  const appels = { payer: 0, finaliser: [], toasts: [] };
  const ctx = {
    state: { country: 'republic', arg, pa: 5, char: { name: 'Arnie' } },
    COUNTRIES: { republic: { cur: 'FR' } }, BUILDINGS: {}, TEST_MODE: false,
    refuserSiGele: async () => false,
    deduireCoutOrdre: async () => { appels.payer++; return { ok: false, raison: 'cout_non_declare' }; },
    finaliserAchatTerrain: async (...a) => { appels.finaliser.push(a); return { ok: true }; },
    showToast: (t, m, ok) => appels.toasts.push([t, m, ok]),
    document: { getElementById: () => ({ classList: { remove() {} } }) },
    Date,
  };
  vm.createContext(ctx);
  vm.runInContext(code + '\nthis.traiterActeVente = traiterActeVente;', ctx);
  return { ctx, appels };
}

test('compromis avec prêt accordé : signature envoyée au serveur sans solde en poche, aucun prélèvement écran', async () => {
  const { ctx, appels } = monter(500);
  await ctx.traiterActeVente({ id: 'terrain-3', type: 'compromis',
    ts: { compromis: true, compromisPar: 'Arnie', valeur_totale: 33000, acompte: 1000,
          pretDemande: { statut: 'accorde', montant: 30000 } } });
  assert.strictEqual(appels.payer, 0);
  assert.strictEqual(appels.finaliser.length, 1);
  assert.strictEqual(appels.finaliser[0][4], 'compromis');
  assert.ok(appels.toasts.some(t => t[0] === 'Acte signé !'));
});

test('rendez-vous d\'achat direct : la porte serveur décide (rendez-vous, fonds), l\'écran ne paie pas', async () => {
  const { ctx, appels } = monter(0);
  await ctx.traiterActeVente({ id: 'terrain-5', type: 'achatDirect',
    ts: { achatDirect: { demandeur: 'Arnie', prix: 22200, acompte: 1000, dateAchat: 0, dateLimite: 1 } } });
  assert.strictEqual(appels.payer, 0);
  assert.strictEqual(appels.finaliser.length, 1);
  assert.strictEqual(appels.finaliser[0][4], 'achat_direct');
});

test('clause encore en attente : refus nommé avant tout appel', async () => {
  const { ctx, appels } = monter(100000);
  await ctx.traiterActeVente({ id: 'terrain-3', type: 'compromis',
    ts: { compromis: true, compromisPar: 'Arnie', valeur_totale: 33000, acompte: 1000,
          pretDemande: { statut: 'attente_validation' } } });
  assert.strictEqual(appels.finaliser.length, 0);
  assert.strictEqual(appels.payer, 0);
  assert.ok(appels.toasts.some(t => t[0] === 'Clauses en attente'));
});

test('contre-épreuve : le texte ne contient plus de prélèvement du solde par l\'écran', () => {
  assert.ok(!/deduireCoutOrdre\(\{\s*pa:\s*1,\s*cost:\s*solde/.test(code));
  assert.ok(!/state\.arg\s*<\s*solde/.test(code));
});
