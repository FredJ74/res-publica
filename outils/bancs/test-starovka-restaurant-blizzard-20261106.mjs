import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : restaurant-boutique vers Blizzard et retour',()=>{
 const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
 const x=vm.runInContext(`({restaurant:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-restaurant-boutique'],blizzard:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-blizzard'],haut:RC_FLECHE_HAUT,bas:RC_FLECHE_BAS})`,ctx);
 assert.equal(x.restaurant.liens.toutDroit,'starovka-rue-logements-collectifs');
 assert.equal(x.restaurant.liens.arriere,'starovka-rue-blizzard');
 assert.equal(x.restaurant.flechesStyle.toutDroit,x.haut);
 assert.equal(x.restaurant.flechesStyle.arriere,x.bas);
 assert.equal(x.blizzard.liens.toutDroit,'starovka-rue-restaurant-boutique');
 assert.equal(x.blizzard.flechesStyle.toutDroit,x.haut);
 assert.equal(x.blizzard.image,'images/Sovarka/Starovka/Starovka_rue_blizzard.webp');
 assert.ok(fs.statSync(path.join(root,x.blizzard.image)).size>100);
 assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_rue_blizzard.png')),false);
});
test('Starovka : migration serveur symétrique Blizzard',()=>{
 const sql=fs.readFileSync(path.join(root,'migrations/20261106020000_starovka_restaurant_blizzard.sql'),'utf8');
 assert.match(sql,/"arriere":"starovka-rue-blizzard"/);
 assert.match(sql,/"toutDroit":"starovka-rue-restaurant-boutique"/);
});
