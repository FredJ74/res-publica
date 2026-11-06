import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : deux flèches à mi-hauteur sur le lycée et retour caserne',()=>{
 const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
 const n=vm.runInContext("({lycee:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-lycee-commissariat'],caserne:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-bureaux-caserne']})",ctx);
 assert.equal(n.lycee.liens.droite,'starovka-rue-mairie-marche');
 assert.equal(n.lycee.liens.gauche,'starovka-rue-bureaux-caserne');
 assert.match(n.lycee.flechesStyle.droite,/top:50%/);
 assert.match(n.lycee.flechesStyle.droite,/right:10px/);
 assert.match(n.lycee.flechesStyle.gauche,/top:50%/);
 assert.match(n.lycee.flechesStyle.gauche,/left:10px/);
 assert.equal(n.caserne.liens.droite,'starovka-rue-lycee-commissariat');
 assert.equal(n.caserne.image,'images/Sovarka/Starovka/Starovka_rue_bureaux_caserne.webp');
 assert.ok(fs.statSync(path.join(root,n.caserne.image)).size>100);
 assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_rue_bureaux_caserne.png')),false);
});
test('Starovka : serveur conserve le retour mairie et ajoute celui de caserne',()=>{
 const sql=fs.readFileSync(path.join(root,'migrations/20261106040000_starovka_lycee_bureaux_caserne.sql'),'utf8');
 assert.match(sql,/"droite":"starovka-rue-mairie-marche"/);
 assert.match(sql,/"gauche":"starovka-rue-bureaux-caserne"/);
 assert.match(sql,/"droite":"starovka-rue-lycee-commissariat"/);
});
