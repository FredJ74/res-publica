const test=require('node:test'),assert=require('node:assert/strict');
const F=require('../../finances-exactes.js');
function fixture(){
 let ctx={uid:'uid',personnage:'Alice',session:'s1'},n=0;
 const m=new Map(),appliques=[],envoyes=[];
 const f={appliques,envoyes,m,contexte:c=>ctx=c};
 const etat={version:2,personnage:'Alice',revision:'1',arg:'5.50',liquide:'0.00',banque:null,comptes:[]};
 f.resultat={ok:true,etat};
 f.envoyer=async p=>{envoyes.push(p);return f.resultat;};
 f.options={contexte:()=>ctx,stockage:{getItem:k=>m.get(k)??null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)},envoyer:p=>f.envoyer(p),appliquer:e=>appliques.push(e),uuid:()=>String(++n)};
 f.controleur=F.creerControleur(f.options);return f;
}
test('intentions immuables et double clic mutualise',async()=>{
 const f=fixture();let resolve;f.envoyer=p=>{f.envoyes.push(p);return new Promise(r=>resolve=r);};
 const a={montant:'5.50'};const p=f.controleur.lancer('deposer',a);a.montant='500.00';
 const p2=f.controleur.lancer('deposer',{montant:'5.50'});assert.equal(p,p2);
 assert.equal(f.envoyes[0].arguments.montant,'5.50');assert.equal(f.m.size,1);
 resolve(f.resultat);await p;assert.equal(f.appliques.length,1);assert.equal(f.m.size,0);
});
test('reponse perdue : reprise apres fermeture avec UUID et corps identiques',async()=>{
 const f=fixture();f.envoyer=async p=>{f.envoyes.push(p);throw Error('reseau');};
 await assert.rejects(f.controleur.lancer('deposer',{montant:'5.50'}));
 assert.equal(f.m.size,1);const copie=JSON.parse(JSON.stringify(f.envoyes[0]));
 await assert.rejects(f.controleur.lancer('retirer',{montant:'1.00'}),/precedente/);
 f.envoyer=async p=>{f.envoyes.push(p);return f.resultat;};
 const reouvert=F.creerControleur(f.options);await reouvert.reprendre();
 assert.deepEqual(f.envoyes[1],copie);assert.equal(f.m.size,0);
});
test('reponse invalide, somme binaire ou fraction de centime : aucun miroir local ecrit',async()=>{
 for(const arg of [5.5,'5.505',undefined]){
  const f=fixture();f.resultat.etat.arg=arg;
  await assert.rejects(f.controleur.lancer('deposer',{}),/non_confirme/);
  assert.equal(f.appliques.length,0);assert.equal(f.m.size,1);
 }
});
test('reponse tardive d un ancien personnage ou d une ancienne session ignoree',async()=>{
 for(const ctx of [{uid:'uid',personnage:'Bob',session:'s1'},{uid:'uid',personnage:'Alice',session:'s2'}]){
  const f=fixture();let resolve;f.envoyer=()=>new Promise(r=>resolve=r);
  const p=f.controleur.lancer('deposer',{});f.contexte(ctx);resolve(f.resultat);await p;
  assert.equal(f.appliques.length,0);
 }
});
test('invalidation du miroir pendant une requete empeche un ancien retour de l ecraser',async()=>{
 const f=fixture();let resolve;f.envoyer=()=>new Promise(r=>resolve=r);
 const p=f.controleur.lancer('deposer',{});f.controleur.invalider();resolve(f.resultat);await p;
 assert.equal(f.appliques.length,0);
});
test('stockage indisponible : aucune operation financiere envoyee',()=>{
 const f=fixture();f.options.stockage.setItem=()=>{throw Error('stockage');};const c=F.creerControleur(f.options);
 assert.throws(()=>c.lancer('deposer',{}),/stockage/);assert.equal(f.envoyes.length,0);
});
