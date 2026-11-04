// Interface réelle et pilote commun ; RPC/identités/DOM sont exclusivement des fixtures.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const acorn=require('../vercel/node_modules/acorn'),R=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(R,f),'utf8');
function extraire(f,noms){const s=lire(f);return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
const devis=()=>[3,5].map((v,i)=>({modele:'bateau_'+v,passagers:v,fret:v*100,jours:i?10:7,prix_total_fr:i?150000:90000,acompte:i?52500:31500,recette:{bois:i?1800:1200,metal:i?1800:1200,derives_petrochimiques:600},entrepot_psm:{bois:0,metal:0,derives_petrochimiques:0},manquant_psm:{bois:1200,metal:1200,derives_petrochimiques:600}}));
function jeu(){
 const elements=new Map(['postes-modal-title','postes-body','modal-postes'].map(k=>[k,{textContent:'',innerHTML:'',classList:{add(){}}}]));let identite='uid-fixture',jeton='session-fixture';const stockage=new Map(),appels=[],toasts=[];
 const c=vm.createContext({state:{country:'republic',currentCity:'ville_a',currentBuilding:'chantier-naval',currentRoom:'bureau',char:{name:'Fixture'},liquide:100000,arg:200000},window:{confirm:()=>true},document:{getElementById:k=>elements.get(k)},sessionStorage:{getItem:k=>stockage.get(k)||null,setItem:(k,v)=>stockage.set(k,v),removeItem:k=>stockage.delete(k)},crypto:{randomUUID:()=> '10000000-0000-4000-8000-000000000001'},showToast:(...p)=>toasts.push(p),updateUI(){},receptionsInventaireEnCours:new Set()});
 c.sbContexteInventaire=()=>({personnage:c.state.char,generation:0,uid:identite,jeton});
 c.sbAdopterInventaireServeur=v=>Array.isArray(v.inventory);c.signalerRefusCout=v=>toasts.push(['refus',v.raison]);
 c.sbRpcVerdict=async(fn,p)=>{appels.push([fn,p]);if(fn==='chantier_naval_devis')return devis();if(fn==='chantier_naval_mes_commandes')return[];return{ok:true,commande:'commande-fixture',acompte:31500,inventory:[],revision:0,paie:{liquide:68500,arg:168500,pa:30}};};
 vm.runInContext(extraire('plateau-divers.js',['executerReceptionInventaire'])+'\n'+extraire('plateau-core.js',['appliquerPaiementServeur'])+'\n'+lire('plateau-naval.js'),c);
 return{c,elements,stockage,appels,toasts,changer(){identite='autre-uid';jeton='autre-session';c.state.char={name:'Autre'};}};
}
test('deux devis complets, stock nul visible et confirmation explicite',async()=>{
 const j=jeu();await j.c.ouvrirDevisChantierNaval();const h=j.elements.get('postes-body').innerHTML;for(const x of['90','150','35 %','65 %','dérivés','cpj-dialogue'])assert.ok(h.includes(x),x);
 let confirmation;j.c.window.confirm=t=>{confirmation=t;return false;};await j.c.commanderBateauNaval('bateau_3');assert.match(confirmation,/31/);assert.ok(confirmation.includes('\n'));assert.equal(j.appels.filter(x=>x[0]==='chantier_naval_commander').length,0);
});
test('succès : adoption du paiement réel sans delta local ni bateau inventé',async()=>{
 const j=jeu();await j.c.ouvrirDevisChantierNaval();await j.c.commanderBateauNaval('bateau_3');assert.equal(j.c.state.liquide,68500);assert.equal(j.c.state.arg,168500);assert.equal(j.stockage.size,0);assert.equal(j.appels.filter(x=>x[0]==='chantier_naval_commander').length,1);
});
test('double clic en vol : une seule intention transmise',async()=>{
 const j=jeu();await j.c.ouvrirDevisChantierNaval();let finir;const normal=j.c.sbRpcVerdict;j.c.sbRpcVerdict=(fn,p)=>fn==='chantier_naval_commander'?new Promise(r=>{j.appels.push([fn,p]);finir=r;}):normal(fn,p);
 const premier=j.c.commanderBateauNaval('bateau_3');await j.c.commanderBateauNaval('bateau_3');assert.equal(j.appels.filter(x=>x[0]==='chantier_naval_commander').length,1);finir({ok:true,acompte:31500,inventory:[],revision:0,paie:{liquide:68500}});await premier;
});
test('réponse perdue : même UUID conservé au nouvel essai',async()=>{
 const j=jeu();await j.c.ouvrirDevisChantierNaval();const normal=j.c.sbRpcVerdict;let n=0,ids=[];j.c.sbRpcVerdict=async(fn,p)=>{if(fn!=='chantier_naval_commander')return normal(fn,p);ids.push(p.p_requete);if(!n++)return{ok:false,transport:{etat:'confirmation_incertaine',envoyee:true}};return{ok:true,rejeu:true,acompte:31500,inventory:[],revision:0,paie:{liquide:61000,arg:161000}};};
 await j.c.commanderBateauNaval('bateau_3');assert.equal(j.stockage.size,1);assert.ok(j.toasts.some(t=>t[0]==='Confirmation incertaine'));await j.c.commanderBateauNaval('bateau_3');assert.equal(ids[0],ids[1]);assert.equal(j.c.state.liquide,61000);assert.equal(j.stockage.size,0);
});
test('autre personnage : devis ancien rejeté et réponse en vol sans effet',async()=>{
 const j=jeu();await j.c.ouvrirDevisChantierNaval();j.changer();await j.c.commanderBateauNaval('bateau_3');assert.equal(j.appels.filter(x=>x[0]==='chantier_naval_commander').length,0);
 const k=jeu();await k.c.ouvrirDevisChantierNaval();let finir;k.c.sbRpcVerdict=()=>new Promise(r=>finir=r);const p=k.c.commanderBateauNaval('bateau_3');k.changer();finir({ok:true,acompte:31500,inventory:[],revision:0,paie:{liquide:1}});await p;assert.equal(k.c.state.liquide,100000);assert.ok(!k.toasts.some(t=>t[0]==='Commande enregistrée'));
});
test('lecture tardive ou panne : aucune fausse commande ni catalogue d’un autre compte',async()=>{
 const j=jeu();let finir;j.c.sbRpcVerdict=fn=>fn==='chantier_naval_devis'?new Promise(r=>finir=r):Promise.resolve([]);const p=j.c.ouvrirDevisChantierNaval();j.changer();finir(devis());await p;assert.equal(j.elements.get('postes-body').innerHTML,'');
 const k=jeu();k.c.sbRpcVerdict=async()=>({ok:false,transport:{etat:'session_perdue'}});await k.c.ouvrirDevisChantierNaval();assert.ok(k.toasts.some(x=>x[1].includes('session')));
});
