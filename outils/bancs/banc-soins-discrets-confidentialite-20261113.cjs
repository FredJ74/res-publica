// Régression ciblée : la confidentialité ne baisse plus la Discrétion.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const migration=fs.readFileSync('migrations/20261113014500_soins_discrets_sans_malus_discretion.sql','utf8');
const seed=fs.readFileSync('baseline/seeds/90_socle/ordres_generiques.sql','utf8');
const data=fs.readFileSync('data.js','utf8');
test('Supabase : seule la clé de malus est supprimée',()=>{
  assert.match(migration,/SET effets = effets - 'dis'/);
  assert.match(migration,/WHERE fn='soins_discrets'/);
  assert.match(migration,/effets='\{"hp":30\}'::jsonb/);
  assert.doesNotMatch(migration,/UPDATE public\.personnages_donnees/);
});
test('Le catalogue de reconstruction ne réintroduit pas -2',()=>{
  const l=seed.split('\n').find(s=>s.includes("VALUES ('soins_discrets'"));
  assert.ok(l);
  assert.match(l,/'\{"hp": 30\}'/);
  assert.doesNotMatch(l,/"dis"/);
});
test('Prix, taux, Santé et type gris préservés dans le jeu',()=>{
  const i=data.indexOf("fn:'soins_discrets'");
  assert.ok(i>=0);
  const l=data.slice(i,i+200);
  assert.match(l,/pa:1, cost:800/);
  assert.match(l,/type:'grey'/);
  assert.match(l,/successRate:95/);
  assert.match(l,/\+30 Sante/);
});
