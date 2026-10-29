// Fonctions réelles extraites : transport simulé, aucune donnée de joueur.
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),acorn=require('../vercel/node_modules/acorn');
const source=fs.readFileSync('plateau-justice-economie.js','utf8');
const noms=['procederArrestation','enregistrerDetention','contexteInterceptionJudiciaire','contexteInterceptionJudiciaireValide','retirerRecherche'];
const code=acorn.parse(source,{ecmaVersion:'latest'}).body.filter(x=>x.type==='FunctionDeclaration'&&noms.includes(x.id.name)).map(x=>source.slice(x.start,x.end)).join('\n');
function jeu(){
 const c=vm.createContext({state:{char:{name:'A'},country:'republic',currentCity:'capitale',day:1,pa:12,arg:500,poste:{id:'maire'}},session:'s',messages:[],rendus:[],journal:[],appels:0,Date,Number,console});
 c.rpAuthUid=()=> 'uid';c.rpAuthSessionIdentifiant=()=>c.session;
 c.getPeineParActe=()=>({jours:1,label:'Motif officiel',amende:500});c.showToast=(...x)=>c.messages.push(x);c.updateUI=()=>{};c.addJournalEntry=(...x)=>c.journal.push(x);
 c.afficherPositionNavigationConfirmee=x=>c.rendus.push(x);
 c.sbRpc=async()=>{c.appels++;return {ok:true,detention_id:'d1',jour_debut:1,jour_fin:2};};
 c.frais={userId:'uid',pa:0,estEmprisonne:{detentionId:'d1',raison:'Motif officiel',jours:1,jourFin:2},currentCity:'capitale',currentBuilding:'commissariat',currentRoom:'prison'};
 c.sbLoadPersonnage=async()=>c.frais;c.retirerRecherche=async()=>{};
 vm.runInContext('let arrestationHistoriqueEnCours=null;\n'+code,c);c.retirerRecherche=async()=>{};return c;
}
test('aucune détention ni débit avant réponse serveur',async()=>{const c=jeu();let finir;c.sbRpc=()=>new Promise(r=>finir=r);const p=c.procederArrestation('x',false,false);assert.equal(c.state.estEmprisonne,undefined);assert.equal(c.state.arg,500);assert.equal(c.rendus.length,0);finir({ok:true,detention_id:'d1',jour_debut:1,jour_fin:2});assert.equal(await p,true);assert.equal(c.state.estEmprisonne,c.frais.estEmprisonne);assert.equal(c.rendus[0],c.frais);assert.equal(c.state.arg,500);assert.equal(c.state.poste.id,'maire');});
test('refus serveur : aucune arrestation annoncée ou simulée',async()=>{const c=jeu();c.sbRpc=async()=>({ok:false,raison:'refuse'});c.sbLoadPersonnage=async()=>({userId:'uid',pa:12});assert.equal(await c.procederArrestation('x'),false);assert.equal(c.state.estEmprisonne,undefined);assert.equal(c.rendus.length,0);assert.equal(c.journal.length,0);});
test('réponse perdue après commit : relecture seule retrouve la détention',async()=>{const c=jeu();c.sbRpc=async()=>{c.appels++;throw Error('réseau');};assert.equal(await c.procederArrestation('x'),true);assert.equal(c.appels,1);assert.equal(c.rendus[0],c.frais);});
test('réponse perdue et relecture indisponible : aucune fausse réussite',async()=>{const c=jeu();c.sbRpc=async()=>null;c.sbLoadPersonnage=async()=>null;assert.equal(await c.procederArrestation('x'),false);assert.equal(c.rendus.length,0);assert.equal(c.state.estEmprisonne,undefined);});
test('double clic : une seule ouverture de détention',async()=>{const c=jeu();let finir;c.sbRpc=()=>{c.appels++;return new Promise(r=>finir=r);};const p=c.procederArrestation('x');assert.equal(await c.procederArrestation('x'),false);assert.equal(c.appels,1);finir({ok:true,detention_id:'d1'});await p;});
test('changement de personnage pendant ouverture : aucune adoption tardive',async()=>{const c=jeu();c.sbRpc=async()=>{c.state.char={name:'B'};return {ok:true,detention_id:'d1'};};assert.equal(await c.procederArrestation('x'),false);assert.equal(c.state.estEmprisonne,undefined);assert.equal(c.state.prisonniers,undefined);assert.equal(c.rendus.length,0);});
test('changement de session pendant relecture : aucun rendu tardif',async()=>{const c=jeu();c.sbLoadPersonnage=async()=>{c.session='nouvelle';return c.frais;};assert.equal(await c.procederArrestation('x'),false);assert.equal(c.rendus.length,0);});
test('identité incorrecte de la fiche : aucune adoption de position',async()=>{const c=jeu();c.frais.userId='autre';assert.equal(await c.procederArrestation('x'),false);assert.equal(c.rendus.length,0);});
test('pas de transport depuis un identifiant de détention incohérent',async()=>{const c=jeu();c.frais.estEmprisonne.detentionId='autre';assert.equal(await c.procederArrestation('x'),false);assert.equal(c.rendus.length,0);});

test('retrait de recherche tardif : ne touche pas la nouvelle session',async()=>{const c=jeu();vm.runInContext(code,c);c.state.recherche=['ancien'];c.sbRpc=async()=>{c.session='autre';return {ok:true,recherche:[]};};assert.equal(await c.retirerRecherche(['x']),false);assert.deepEqual(c.state.recherche,['ancien']);});
