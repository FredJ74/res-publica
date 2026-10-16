// node --test outils/bancs/banc-coherence-banques.cjs
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function contexte(){
 const c=vm.createContext({console,setTimeout,clearTimeout,state:{char:{name:'Alice'},country:'republic',arg:100,liquide:20,
  comptesBancaires:{helvetia:{solde:80}},placementsBancaires:[{id:'ancien'}]},rpAuthUid:()=> 'uid'});
 vm.runInContext(fs.readFileSync(path.join(root,'supabase.js'),'utf8'),c);
 const src=fs.readFileSync(path.join(root,'plateau-justice-economie.js'),'utf8');
 let a=src.indexOf('let RP_HELVETIA_VERSION');if(a<0)a=src.indexOf('async function rafraichirRuntimeHelvetia(');
 const b=src.indexOf('async function ouvrirGestionHelvetia(',a);vm.runInContext(src.slice(a,b),c);
 c.construireMapComptesBancaires=rows=>Object.fromEntries(rows.map(r=>[r.banque,r]));
 c.sbLoadPersonnage=async()=>null;return c;
}
test('une panne de lecture bancaire ne devient pas une liste de comptes ou placements vide',async()=>{
 const c=contexte();c.sbGet=async()=>null;
 await assert.rejects(c.sbGetComptesBancaires('Alice'));await assert.rejects(c.sbGetPlacementsBancaires('Alice'));
 await c.rafraichirRuntimeHelvetia();assert.equal(c.state.comptesBancaires.helvetia.solde,80);assert.equal(c.state.placementsBancaires[0].id,'ancien');
});
test('un vrai vide peut effacer un ancien compte, sans modifier les soldes du personnage',async()=>{
 const c=contexte();c.sbGet=async()=>[];await c.rafraichirRuntimeHelvetia();
 assert.equal(Object.keys(c.state.comptesBancaires).length,0);assert.equal(c.state.placementsBancaires.length,0);assert.equal(c.state.arg,100);
});
test('la relecture recopie les zeros et ne transforme pas un champ absent en solde',async()=>{
 const c=contexte();c.sbGet=async()=>[];c.sbLoadPersonnage=async()=>({arg:0,liquide:0});await c.rafraichirRuntimeHelvetia();
 assert.equal(c.state.arg,0);assert.equal(c.state.liquide,0);
 c.sbLoadPersonnage=async()=>({arg:undefined,liquide:null});await c.rafraichirRuntimeHelvetia();assert.equal(c.state.arg,0);assert.equal(c.state.liquide,0);
});
test('reponse bancaire apres changement de personnage : aucune contamination',async()=>{
 const c=contexte();let resolve;c.sbGet=async()=>[];c.sbLoadPersonnage=()=>new Promise(r=>resolve=r);
 const p=c.rafraichirRuntimeHelvetia();c.state.char={name:'Bob'};resolve({arg:0,liquide:0});await p;
 assert.equal(c.state.arg,100);assert.equal(c.state.comptesBancaires.helvetia.solde,80);
});
test('deux relectures terminees dans le desordre gardent la plus recente',async()=>{
 const c=contexte();let resolve;c.sbGet=async()=>[];c.sbLoadPersonnage=()=>new Promise(r=>resolve=r);
 const ancien=c.rafraichirRuntimeHelvetia();c.sbLoadPersonnage=async()=>({arg:50,liquide:10});
 await c.rafraichirRuntimeHelvetia();resolve({arg:100,liquide:20});await ancien;assert.equal(c.state.arg,50);
});
