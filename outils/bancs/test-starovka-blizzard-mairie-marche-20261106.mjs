import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');

test('Starovka : Blizzard vers mairie/marché et retour',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const n=vm.runInContext(`({blizzard:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-blizzard'],mairie:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-mairie-marche'],haut:RC_FLECHE_HAUT,bas:RC_FLECHE_BAS})`,ctx);
  assert.equal(n.blizzard.liens.toutDroit,'starovka-rue-restaurant-boutique');
  assert.equal(n.blizzard.liens.arriere,'starovka-rue-mairie-marche');
  assert.equal(n.blizzard.flechesStyle.toutDroit,n.haut);
  assert.equal(n.blizzard.flechesStyle.arriere,n.bas);
  assert.equal(n.mairie.liens.toutDroit,'starovka-rue-blizzard');
  assert.equal(n.mairie.flechesStyle.toutDroit,n.haut);
  assert.equal(n.mairie.image,'images/Sovarka/Starovka/Starovka_rue_mairie_marché.webp');
  assert.ok(fs.statSync(path.join(root,n.mairie.image)).size>100);
  assert.equal(fs.existsSync(path.join(root,'images/Sovarka/Starovka/Starovka_rue_mairie_marché.png')),false);
});

test('Starovka : migration serveur garde toutes les connexions',()=>{
  const s=fs.readFileSync(path.join(root,'migrations/20261106023000_starovka_blizzard_mairie_marche.sql'),'utf8');
  assert.match(s,/"arriere":"starovka-rue-mairie-marche"/);
  assert.match(s,/"toutDroit":"starovka-rue-blizzard"/);
});
