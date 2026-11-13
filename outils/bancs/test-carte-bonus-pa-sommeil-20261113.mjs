// Garde-fou (13/11/2026) : le bonus de sommeil d'un plat acheté au comptoir est crédité par le
// serveur dans la vente ; l'écran ne fait plus de second appel, et la carte l'écrit en clair.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const racine = new URL('../../', import.meta.url);
const src = fs.readFileSync(new URL('plateau-actions-illegales-rumeurs.js', racine), 'utf8');
const debut = src.indexOf('async function commanderProduitCommerce(');
const fin = src.indexOf('\n}\n', debut);
const commande = src.slice(debut, fin);
assert.ok(debut > 0 && fin > debut);
assert.doesNotMatch(commande, /pa_bonus_differe_crediter/, "l'écran ne crédite plus le bonus après la vente");
assert.doesNotMatch(src, /k\.toUpperCase\(\)\)\.join/, 'plus de « +3 PADIFFERE » à la carte');

const migration = fs.readdirSync(new URL('migrations/', racine)).find(f => f.includes('commerce_comptoir_bonus_pa_serveur'))
  || fs.readdirSync(new URL('historique/migrations-appliquees/', racine)).find(f => f.includes('commerce_comptoir_bonus_pa_serveur'));
assert.ok(migration, 'migration du crédit serveur présente');

// Libellés : la fonction réelle, chargée seule.
const d = src.indexOf('function libelleEffetsCommerce(');
const f = src.indexOf('\nfunction nomProduitCommerce(', d);
const ctx = { texteCommerceMenu: (k, fr) => fr };
vm.createContext(ctx);
vm.runInContext(src.slice(d, f), ctx);
assert.equal(ctx.libelleEffetsCommerce({ hp: 10, moral: 1, paDiffere: 3 }), '+10 Santé, +1 Moral, +3 PA au prochain sommeil');
assert.equal(ctx.libelleEffetsCommerce({ moral: 2 }, ' '), '+2 Moral');
assert.equal(ctx.libelleEffetsCommerce({}), '');
console.log('test-carte-bonus-pa-sommeil-20261113 : OK');
