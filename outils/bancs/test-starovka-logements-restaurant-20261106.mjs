import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : logements → restaurant et retour, terrain préservé',()=>{
 const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
 const x=vm.runInContext(`({logements:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-logements-collectifs'],resto:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-restaurant-boutique'],haut:RC_FLECHE_HAUT,bas:RC_FLECHE_BAS})`,ctx);
 assert.equal(x.logements.liens.gauche,'starovka-rue-terrains');
 assert.equal(x.logements.liens.arriere,'starovka-rue-restaurant-boutique');
 assert.equal(x.logements.flechesStyle.arriere,x.bas);
 assert.equal(x.resto.liens.toutDroit,'starovka-rue-logements-collectifs');
 assert.equal(x.resto.flechesStyle.toutDroit,x.haut);
 assert.equal(x.resto.image,'images/Sovarka/Starovka/Starovka_Rue_restaurant-boutique.webp');
 assert.ok(fs.statSync(path.join(root,x.resto.image)).size>100);
 assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_Rue_restaurant-boutique.png')),false);
});
test('Starovka : migration symétrique et sans nouvelle mécanique',()=>{
 const sql=fs.readFileSync(path.join(root,'migrations/20261106014500_starovka_logements_restaurant.sql'),'utf8');
 assert.match(sql,/"arriere":"starovka-rue-restaurant-boutique"/);
 assert.match(sql,/"toutDroit":"starovka-rue-logements-collectifs"/);
});
