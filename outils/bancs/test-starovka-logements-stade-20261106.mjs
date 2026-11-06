import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');

test('Starovka : flèche droite logements vers stade et retour gauche',()=>{
 const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
 const n=vm.runInContext("({logements:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-logements-collectifs'],stade:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-stade']})",ctx);
 assert.equal(n.logements.liens.gauche,'starovka-rue-terrains');
 assert.equal(n.logements.liens.arriere,'starovka-rue-restaurant-boutique');
 assert.equal(n.logements.liens.droite,'starovka-rue-stade');
 assert.match(n.logements.flechesStyle.droite,/right:10px/);
 assert.match(n.logements.flechesStyle.droite,/top:50%/);
 assert.equal(n.stade.liens.gauche,'starovka-rue-logements-collectifs');
 assert.match(n.stade.flechesStyle.gauche,/left:10px/);
 assert.equal(n.stade.image,'images/Sovarka/Starovka/Starovka_rue_stade.webp');
 assert.ok(fs.statSync(path.join(root,n.stade.image)).size>100);
 assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_rue_stade.png')),false);
});
test('Starovka : deux nœuds attestés par la migration',()=>{
 const sql=fs.readFileSync(path.join(root,'migrations/20261106070000_starovka_logements_stade.sql'),'utf8');
 assert.match(sql,/"droite":"starovka-rue-stade"/);
 assert.match(sql,/"gauche":"starovka-rue-logements-collectifs"/);
 assert.match(sql,/"arriere":"starovka-rue-restaurant-boutique"/);
});
