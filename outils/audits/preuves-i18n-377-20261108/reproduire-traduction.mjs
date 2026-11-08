// Contre-exemples d'audit : une reproduction réussie indique un DÉFAUT, pas une conformité.
// Fournisseur simulé uniquement. Aucun appel réseau ni secret.
import assert from 'node:assert/strict';
import { traduireTexte } from '../../../api/_traduction.js';
const input={texte:'Votre commande coûte 100 FR et 1 PA, {{name}}.',langueOriginale:'fr',langueCible:'en'};
const r=await traduireTexte(input,async()=>({ok:true,texte:'Your order costs 1000 USD and 9 AP, {{name}}.'}));
assert.equal(r.ok,true,'reproduction : nombres et devise altérés acceptés');
const missing=await traduireTexte(input,async()=>({ok:true,texte:'Your order costs 1000 USD and 9 AP.'}));
assert.equal(missing.ok,false,'contre-épreuve : le garde des placeholders existe bien');
const ctrl=await traduireTexte(input,async()=>({ok:true,texte:'Your order costs 100 FR and 1 AP, {{name}}.\u0000'}));
assert.equal(ctrl.ok,true,'reproduction : contrôle NUL manquant sur réponse fournisseur');
console.log(JSON.stringify({cas:'P2-integrite-traduction',defaut_reproduit:true,source:input.texte,accepte:r.traduit,contre_placeholder_refuse:!missing.ok,controle_nul_accepte:ctrl.ok}));
