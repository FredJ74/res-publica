// Regle #57 validee : aucun centime, pas de changement de representation des soldes.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const c=vm.createContext({});vm.runInContext(fs.readFileSync(require.resolve('../../plateau-chantiers.js'),'utf8'),c);
test('tarifs initiaux toujours au franc superieur, sans artefact flottant',()=>{
 for(const [entrepot,chantier] of [[0,0],[1,2],[5,6],[10,11],[15,17],[20,22],[100,110],[1000,1100]])assert.equal(c.prixAchatMateriauChantier(entrepot),chantier);
 for(let p=0;p<10000;p++)assert.equal(c.prixAchatMateriauChantier(p),Number((BigInt(p)*110n+99n)/100n));
});
test('prix proprietaire : francs entiers, jamais arrondi silencieusement',()=>{
 for(const v of [0,1,6,11,17,'0','6','11'])assert.equal(c.constructionFrancsEntiers(v),Number(v));
 for(const v of [1.5,'1.5','1,5','1.00','1e2','-1',-1,'',' 1 ',null,undefined,NaN,Infinity,true,{},Number.MAX_SAFE_INTEGER+1])assert.throws(()=>c.constructionFrancsEntiers(v));
});
test('financement conserve les francs, banque puis liquide, total insuffisant sans debit',()=>{
 for(const [m,b,l]of [[0,0,0],[100,100,0],[100,50,50],[100,0,100],[100,50,49]]){
  const v=c.repartitionFinancementChantier(m,b,l);assert.equal(v.ok,b+l>=m);
  if(v.ok){assert.equal(v.banque+v.liquide,m);assert.equal(v.banque,Math.min(m,b));}else{assert.equal(v.banque,0);assert.equal(v.liquide,0);}
 }
 assert.throws(()=>c.repartitionFinancementChantier(1.5,3,3));
});
test('grands entiers controles, aucune multiplication/division des soldes par 100',()=>{
 assert.equal(c.constructionFrancsEntiers('2000'),2000);
 assert.equal(c.repartitionFinancementChantier(2000,1500,500).liquide,500);
 assert.throws(()=>c.prixAchatMateriauChantier(Number.MAX_SAFE_INTEGER));
 const v=c.repartitionFinancementChantier(Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER);
 assert.equal(v.banque,Number.MAX_SAFE_INTEGER);assert.equal(v.liquide,0);
});
