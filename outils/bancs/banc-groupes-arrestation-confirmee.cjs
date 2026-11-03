// Fonctions réelles extraites : transport simulé, aucune donnée de joueur.
// Depuis le 03/11/2026, l'arrestation en flagrant délit est ouverte par le serveur
// (arrestation_flagrant_choisir et les actes serveur) ; l'écran ne fait qu'adopter la fiche relue.
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),acorn=require('../vercel/node_modules/acorn');
const source=fs.readFileSync('plateau-justice-economie.js','utf8');
const noms=['procederArrestation','choisirFlagrantDelit','adopterArrestationServeur','retirerRecherche','contexteInterceptionJudiciaire','contexteInterceptionJudiciaireValide'];
const code=acorn.parse(source,{ecmaVersion:'latest'}).body.filter(x=>x.type==='FunctionDeclaration'&&noms.includes(x.id.name)).map(x=>source.slice(x.start,x.end)).join('\n');
function jeu(){
 const c=vm.createContext({state:{char:{name:'A'},country:'republic',currentCity:'capitale',day:1,pa:12,arg:500,dis:50,hp:100},session:'s',messages:[],rendus:[],journal:[],appels:0,Date,Number,Array,console,document:{getElementById:()=>null}});
 c.rpAuthUid=()=> 'uid';c.rpAuthSessionIdentifiant=()=>c.session;
 c.showToast=(...x)=>c.messages.push(x);c.updateUI=()=>{};c.addJournalEntry=(...x)=>c.journal.push(x);c.addExternalEvent=()=>{};
 c.afficherPositionNavigationConfirmee=x=>c.rendus.push(x);c.appliquerPaiementServeur=()=>{};
 c.REPLIQUES_CORRUPTION_ARRESTATION={succes:{republic:'ok'},echec:{republic:'non'}};
 c.verdict={ok:true,choix:'reddition',reussi:false,arrestation:{ok:true,detention_id:'d1',jours:2,raison_peine:'Motif officiel'}};
 c.sbRpc=async()=>{c.appels++;return c.verdict;};
 c.frais={userId:'uid',pa:0,recherche:[],estEmprisonne:{detentionId:'d1',raison:'Motif officiel',jours:2,jourFin:3},currentCity:'capitale',currentBuilding:'commissariat',currentRoom:'prison'};
 c.sbLoadPersonnage=async()=>c.frais;
 vm.runInContext('let arrestationAdoptionEnCours=false;\n'+code,c);return c;
}
test('aucune détention avant réponse serveur',async()=>{const c=jeu();let finir;c.sbRpc=()=>new Promise(r=>finir=r);const p=c.procederArrestation('x');assert.equal(c.state.estEmprisonne,undefined);assert.equal(c.rendus.length,0);finir(c.verdict);assert.equal(await p,true);assert.equal(c.state.estEmprisonne.detentionId,'d1');});
test('refus serveur : aucune arrestation annoncée ou simulée',async()=>{const c=jeu();c.sbRpc=async()=>({ok:false,raison:'aucun_flagrant'});assert.equal(await c.procederArrestation('x'),false);assert.equal(c.state.estEmprisonne,undefined);assert.equal(c.rendus.length,0);assert.equal(c.journal.length,0);});
test('réponse perdue : aucune fausse réussite',async()=>{const c=jeu();c.sbRpc=async()=>{throw Error('réseau');};assert.equal(await c.procederArrestation('x'),false);assert.equal(c.rendus.length,0);assert.equal(c.state.estEmprisonne,undefined);});
test('arrestation confirmée mais relecture indisponible : aucune adoption',async()=>{const c=jeu();c.sbLoadPersonnage=async()=>null;assert.equal(await c.procederArrestation('x'),false);assert.equal(c.rendus.length,0);assert.equal(c.state.estEmprisonne,undefined);});
test('double adoption simultanée : une seule relecture',async()=>{const c=jeu();let n=0,finir;c.sbLoadPersonnage=()=>{n++;return new Promise(r=>finir=r);};const p=c.adopterArrestationServeur(c.verdict.arrestation);assert.equal(await c.adopterArrestationServeur(c.verdict.arrestation),false);finir(c.frais);await p;assert.equal(n,1);});
test('immunité militaire : refus nommé, aucune détention',async()=>{const c=jeu();assert.equal(await c.adopterArrestationServeur({ok:false,raison:'immunite_militaire'}),false);assert.ok(c.messages.some(m=>m[0]==='Immunité militaire'));assert.equal(c.state.estEmprisonne,undefined);});
test('fuite réussie : DIS du serveur, aucune détention',async()=>{const c=jeu();c.verdict={ok:true,choix:'fuite',reussi:true,dis:30,hp:100,recherche:[]};assert.equal(await c.choisirFlagrantDelit('fuite'),true);assert.equal(c.state.dis,30);assert.equal(c.state.estEmprisonne,undefined);});
test('aucun jet tiré par l’écran',()=>{for(const n of ['choisirFlagrantDelit','adopterArrestationServeur','procederArrestation']){const f=acorn.parse(source,{ecmaVersion:'latest'}).body.find(x=>x.type==='FunctionDeclaration'&&x.id.name===n);assert.ok(f,n);assert.ok(!source.slice(f.start,f.end).includes('Math.random'),n);}});

test('retrait de recherche tardif : ne touche pas la nouvelle session',async()=>{const c=jeu();vm.runInContext(code,c);c.state.recherche=['ancien'];c.sbRpc=async()=>{c.session='autre';return {ok:true,recherche:[]};};assert.equal(await c.retirerRecherche(['x']),false);assert.deepEqual(c.state.recherche,['ancien']);});
