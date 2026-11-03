'use strict';
// Hotfix P0 : une lecture serveur réussie ne peut être annulée par le localStorage.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const s=fs.readFileSync(path.join(__dirname,'../../plateau-core.js'),'utf8');
const start=s.indexOf('function loadCharacter()');
const end=s.indexOf('\nfunction ',start+25);
assert.ok(start>=0 && end>start,'chargement de personnage présent');
const f=s.slice(start,end);
assert.match(f,/Object\.assign\(state, sbState\)/,'réconciliation serveur');
assert.match(f,/applyCharToState\(state\.char\)/,'restauration de la fiche');
assert.doesNotMatch(f,/positionLocaleVille|positionLocaleCountry/,'aucun override local de ville/pays');
assert.doesNotMatch(f,/state\.currentCity\s*=\s*positionLocale/,'ville locale jamais prioritaire');
console.log('OK - ville et pays issus de la fiche serveur après actualisation');

const nav=fs.readFileSync(path.join(__dirname,'../../plateau-navigation.js'),'utf8');
// Depuis #219/#318, la transaction transport_effectuer remplace le couple
// payer_ordre puis sauvegarde de position. Un test d'un ancien texte n'est pas
// une garantie : les entrées effectives doivent déléguer au même acte serveur.
for(const nom of ['executerVoyage','confirmerTransport']) {
 const acorn=require('../vercel/node_modules/acorn');
 const n=acorn.parse(nav,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);
 assert.ok(n,nom);
 const texte=nav.slice(n.start,n.end);
 assert.match(texte,/return commanderTransportServeur\(mode, empireId, villeId\)/);
 assert.doesNotMatch(texte,/deduireCoutOrdre|sbSavePersonnage|state\.currentCity\s*=/);
}
console.log('OK - les transports utilisent le paiement et la position atomiques du serveur');
