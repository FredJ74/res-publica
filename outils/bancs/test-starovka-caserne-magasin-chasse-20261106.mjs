import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');

test('Starovka : flèche haute à gauche vers magasin de chasse, retour en bas',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const n=vm.runInContext("({caserne:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-bureaux-caserne'],chasse:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-magasin-chasse'],bas:RC_FLECHE_BAS})",ctx);
  assert.equal(n.caserne.liens.droite,'starovka-rue-lycee-commissariat');
  assert.equal(n.caserne.liens.toutDroit,'starovka-rue-magasin-chasse');
  assert.match(n.caserne.flechesStyle.toutDroit,/top:10px/);
  assert.match(n.caserne.flechesStyle.toutDroit,/left:43%/);
  assert.equal(n.chasse.liens.arriere,'starovka-rue-bureaux-caserne');
  assert.equal(n.chasse.flechesStyle.arriere,n.bas);
  assert.equal(n.chasse.image,'images/Sovarka/Starovka/Starkova_rue_magasin chasse.webp');
  assert.ok(fs.statSync(path.join(root,n.chasse.image)).size>100);
});

test('Starovka : SQL serveur préserve le lien vers le lycée',()=>{
 const s=fs.readFileSync(path.join(root,'migrations/20261106044500_starovka_caserne_magasin_chasse.sql'),'utf8');
 assert.match(s,/"droite":"starovka-rue-lycee-commissariat"/);
 assert.match(s,/"toutDroit":"starovka-rue-magasin-chasse"/);
 assert.match(s,/"arriere":"starovka-rue-bureaux-caserne"/);
});
