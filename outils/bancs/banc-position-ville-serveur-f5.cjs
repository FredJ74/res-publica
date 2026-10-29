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
const a=nav.indexOf('async function executerVoyage(');
const b=nav.indexOf('\n// Dialogue scripte de Mireille',a);
assert.ok(a>=0&&b>a,'moteur transport existant');
const voyage=nav.slice(a,b);
assert.match(voyage,/await sbSavePersonnage\(state\)/,'voyage attend la persistance');
assert.match(voyage,/if \(!positionConfirmee\) \{[^]*?return;/,'échec interdit annonce de succès');
assert.ok(voyage.indexOf('await sbSavePersonnage(state)')<voyage.indexOf("showToast('Bienvenue"),'confirmation avant message arrivée');
console.log('OK - voyage n’annonce pas arrivée sans réponse de sauvegarde');
