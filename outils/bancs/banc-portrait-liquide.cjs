const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const src=fs.readFileSync(require('node:path').join(__dirname,'../../plateau-core.js'),'utf8');
const a=src.indexOf('function updateUI() {'),b=src.indexOf('\nfunction updateLocationDisplay()',a);
test('le vrai rendu affiche le meme liquide sous le portrait et dans l inventaire, banques distinctes',()=>{
 for(const liquide of [0,5.5,2000]){
  const elements=new Map();const document={getElementById:id=>{
   if(!elements.has(id))elements.set(id,{style:{},querySelector:()=>null});return elements.get(id);
  }};
  const c=vm.createContext({document,state:{char:null,country:'republic',arg:99999,liquide,pa:10,hp:100,moral:75},
   COUNTRIES:{republic:{cur:'FR'}},TEST_MODE:false,PA_MAX:10,verifierObjectifs(){},renderEmployesPanel(){},totalComptesBancaires:()=>8888});
  vm.runInContext(src.slice(a,b),c);c.updateUI();
  assert.equal(elements.get('r-arg').textContent,liquide.toLocaleString('fr-FR')+' FR');
  assert.equal(elements.get('r-arg').textContent,elements.get('inv-liquide').textContent);
  assert.equal(elements.get('inv-banque').textContent,(8888).toLocaleString('fr-FR')+' FR');
 }
});
