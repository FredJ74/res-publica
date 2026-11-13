// Banc statique : don libre, transaction serveur, séparation des empires et barème cumulatif.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const data=fs.readFileSync('data.js','utf8');
const divers=fs.readFileSync('plateau-divers.js','utf8');
const migration=fs.readFileSync('migrations/20261113183000_kolkhoze_don_libre.sql','utf8');
test('les scripts concernés restent syntaxiquement valides',()=>{
  new vm.Script(data,{filename:'data.js'});
  new vm.Script(divers,{filename:'plateau-divers.js'});
});
test('un don libre sans coût ni PA au Kolkhoze exclusivement',()=>{
  assert.match(data,/label:'Donner au Kolkhoze',\s+pa:0, cost:0/);
  assert.match(data,/label:'Faire un don a l\\'Eglise',\s+pa:1, cost:200/);
  assert.match(divers,/state\.currentBuilding === 'kolkhoze-spirituel'/);
  assert.match(divers,/kolkhoze_donner/);
  assert.match(divers,/Number\.isSafeInteger\(montant\)/);
  assert.match(divers,/donKolkhozeEnCours = true/);
});
test('don débité, encaissé et attribué sur le serveur avec verrouillage',()=>{
  assert.match(migration,/payer_ordre_interne\(v_acteur,'don_kolkhoze_libre',0,1,p_montant\)/);
  assert.match(migration,/caisse_institution_mouvement\('soviet_kolkhoze-spirituel',p_montant,false\)/);
  assert.match(migration,/FOR UPDATE/);
  assert.match(migration,/ENABLE ROW LEVEL SECURITY/);
  assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.kolkhoze_donner\(integer\) TO authenticated/);
  assert.match(migration,/current_building IS DISTINCT FROM 'kolkhoze-spirituel'/);
  assert.match(migration,/current_room IS DISTINCT FROM 'grange_sainte'/);
});
test('200 PSK donnent 5 piété et 3 popularité, plafond 10/6, fractions non avantageuses',()=>{
  const score=x=>[Math.min(10,Math.floor(x/40)),Math.min(6,Math.floor(x*3/200))];
  for (const [montant,attendu] of [[1,[0,0]],[40,[1,0]],[200,[5,3]],[400,[10,6]],[10000,[10,6]]])
    assert.deepEqual(score(montant),attendu);
  let donne=0;let attribue=[0,0];
  for(let i=0;i<200;i++){
    donne++;
    const nouveau=score(donne);
    attribue=[attribue[0]+nouveau[0]-attribue[0],attribue[1]+nouveau[1]-attribue[1]];
  }
  assert.deepEqual(attribue,score(200));
});
