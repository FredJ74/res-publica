import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : haut, droite et bas futur depuis le carrefour pétrole-ferme',()=>{
 const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
 const x=vm.runInContext(`({
  petrole:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-petrole-ferme'],
  terrains:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-terrains'],
  ferme:RUE_CENTRALE_NOEUDS.soviet['starovka-maisons-ferme'],
  haut:RC_FLECHE_HAUT,bas:RC_FLECHE_BAS
 })`,ctx);
 assert.equal(x.petrole.liens.toutDroit,'starovka-maisons-ferme');
 assert.equal(x.petrole.liens.droite,'starovka-rue-terrains');
 assert.equal(x.petrole.liens.arriere,undefined);
 assert.equal(x.petrole.liensEnAttente.arriere,true);
 assert.equal(x.petrole.flechesStyle.arriere,x.bas);
 assert.match(x.petrole.flechesStyle.droite,/right:10px/);
 assert.equal(x.terrains.liens.gauche,'starovka-rue-petrole-ferme');
 assert.equal(x.terrains.liens.arriere,undefined);
 assert.equal(x.terrains.image,'images/Sovarka/Starovka/Starovka_rue_terrains.webp');
 assert.ok(fs.statSync(path.join(root,x.terrains.image)).size>100);
 assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_rue_terrains.png')),false);
 assert.equal(x.ferme.liens.arriere,'starovka-rue-petrole-ferme');
});
test('Starovka : SQL ne déclare pas de destination basse inventée',()=>{
 const sql=fs.readFileSync(path.join(root,'migrations/20261106010000_starovka_petrole_terrains.sql'),'utf8');
 assert.match(sql,/"droite":"starovka-rue-terrains"/);
 assert.match(sql,/"gauche":"starovka-rue-petrole-ferme"/);
 assert.doesNotMatch(sql,/"arriere":/);
});
