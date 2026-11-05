import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : descendre de maisons-ferme à pétrole-ferme et remonter',()=>{
 const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
 const n=vm.runInContext(`({ferme:RUE_CENTRALE_NOEUDS.soviet['starovka-maisons-ferme'],petrole:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-petrole-ferme'],haut:RC_FLECHE_HAUT,bas:RC_FLECHE_BAS})`,ctx);
 assert.equal(n.ferme.liens.arriere,'starovka-rue-petrole-ferme');
 assert.equal(n.ferme.flechesStyle.arriere,n.bas);
 assert.equal(n.ferme.liens.toutDroit,'starovka-rue-hotel');
 assert.equal(n.petrole.liens.toutDroit,'starovka-maisons-ferme');
 assert.equal(n.petrole.flechesStyle.toutDroit,n.haut);
 assert.equal(n.petrole.image,'images/Sovarka/Starovka/Starovka_rue_pétrole_ferme.webp');
 assert.ok(fs.statSync(path.join(root,n.petrole.image)).size>100);
 assert.equal(fs.existsSync(path.join(root,n.petrole.image.replace(/\\.webp$/,'.png'))),false);
});
test('Starovka : migration serveur conserve le parcours de retour',()=>{
 const s=fs.readFileSync(path.join(root,'migrations/20261106003500_starovka_rue_petrole_ferme.sql'),'utf8');
 assert.match(s,/'starovka-maisons-ferme'/);
 assert.match(s,/'starovka-rue-petrole-ferme'/);
 assert.match(s,/"arriere":"starovka-rue-petrole-ferme"/);
 assert.match(s,/"toutDroit":"starovka-maisons-ferme"/);
});
