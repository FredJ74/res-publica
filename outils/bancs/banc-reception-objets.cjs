// Aucun acces distant : production en VM, transport et inventaire de fixture.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function jeu(){
 const c=vm.createContext({console,state:{char:{name:'Alice'},country:'republic',inventory:[]},uid:'u',jeton:'t'});
 c.rpAuthUid=()=>c.uid;c.rpAuthJeton=()=>c.jeton;
 vm.runInContext(fs.readFileSync(path.join(root,'supabase.js'),'utf8'),c);
 const s=fs.readFileSync(path.join(root,'plateau-communication.js'),'utf8');
 vm.runInContext(s.slice(s.indexOf('// Verifie les objets recus'),s.indexOf('// Lots de tracts transmissibles')),c);
 c.sbGetObjetsRecus=async()=>[{id:'objet-1',expediteur:'Donneur',objet:{name:'Livre',qty:1}}];
 c.recevoirObjetAutomatique=o=>{c.state.inventory.push(o);return 1;};
 c.reclamerReel=c.sbSupprimerObjetRecu;
 c.sbSupprimerObjetRecu=async()=>true;
 return c;
}
for(const changement of ['personnage','compte','session'])test(`lecture tardive/${changement} : aucune reclamation ni contamination`,async()=>{
 const c=jeu();let resolve,n=0;c.sbGetObjetsRecus=()=>new Promise(r=>resolve=r);c.sbSupprimerObjetRecu=async()=>{n++;return true;};
 const p=c.verifierObjetsRecus();
 if(changement==='personnage')c.state.char={name:'Bob'};
 if(changement==='compte')c.uid='autre';
 if(changement==='session')c.jeton='autre';
 resolve([{id:'o',objet:{name:'Livre'}}]);await p;assert.equal(n,0);assert.equal(c.state.inventory.length,0);
});
test('changement pendant reclamation : aucun ajout au nouveau personnage',async()=>{
 const c=jeu();let resolve;c.sbSupprimerObjetRecu=()=>new Promise(r=>resolve=r);
 const p=c.verifierObjetsRecus();await new Promise(r=>setImmediate(r));c.state.char={name:'Bob'};resolve(true);await p;
 assert.equal(c.state.inventory.length,0);
});
test('deux polls simultanes ne reclament pas deux fois dans le meme onglet',async()=>{
 const c=jeu();let resolve,n=0;c.sbGetObjetsRecus=()=>{n++;return new Promise(r=>resolve=r);};
 const a=c.verifierObjetsRecus(),b=c.verifierObjetsRecus();
 assert.equal(n,1);resolve([]);await Promise.all([a,b]);
 c.sbGetObjetsRecus=async()=>[];await c.verifierObjetsRecus();
});
test('une reclamation exige une ligne effectivement supprimee',async()=>{
 const c=jeu();c.sbSupprimerObjetRecu=c.reclamerReel;
 for(const donnees of [[],true,null]){
  c.sbDeleteVerdict=async()=>({ok:true,donnees});
  assert.equal(await c.sbSupprimerObjetRecu('o','Alice'),null);
 }
 let filtre;c.sbDeleteVerdict=async(t,f)=>{assert.equal(t,'objets_recus');filtre=f;return {ok:true,donnees:[{id:'o'}]};};
 assert.ok(await c.sbSupprimerObjetRecu('o','Alice'));assert.ok(filtre.includes('destinataire=eq.Alice'));
});
test('reception nominale et refus : un ajout ou aucun, sans changer les metadonnees',async()=>{
 const c=jeu();await c.verifierObjetsRecus();assert.equal(c.state.inventory[0].name,'Livre');
 c.sbSupprimerObjetRecu=async()=>null;await c.verifierObjetsRecus();assert.equal(c.state.inventory.length,1);
});
test('une panne libere le poll et ne modifie pas la file via un repli',async()=>{
 const c=jeu();c.sbGetObjetsRecus=async()=>{throw Error('reseau');};await c.verifierObjetsRecus();
 c.sbGetObjetsRecus=async()=>[{id:'objet-1',objet:{name:'Livre'}}];await c.verifierObjetsRecus();assert.equal(c.state.inventory.length,1);
});
