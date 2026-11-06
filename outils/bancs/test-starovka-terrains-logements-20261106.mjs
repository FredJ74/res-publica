import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : terrains vers logements collectifs et retour',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const x=vm.runInContext(`({terrains:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-terrains'],logements:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-logements-collectifs']})`,ctx);
  assert.equal(x.terrains.liens.gauche,'starovka-rue-petrole-ferme');
  assert.equal(x.terrains.liens.droite,'starovka-rue-logements-collectifs');
  assert.equal(x.logements.liens.gauche,'starovka-rue-terrains');
  assert.match(x.terrains.flechesStyle.droite,/right:10px/);
  assert.equal(x.logements.image,'images/Sovarka/Starovka/Starovka_rue_logements collectifs.webp');
  assert.ok(fs.statSync(path.join(root,x.logements.image)).size>100);
  assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_rue_logements collectifs.png')),false);
});
test('Starovka : SQL symétrique et sans destination inventée',()=>{
  const sql=fs.readFileSync(path.join(root,'migrations/20261106013000_starovka_terrains_logements.sql'),'utf8');
  assert.match(sql,/"droite":"starovka-rue-logements-collectifs"/);
  assert.match(sql,/"gauche":"starovka-rue-terrains"/);
});
