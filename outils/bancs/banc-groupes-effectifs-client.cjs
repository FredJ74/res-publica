// Fonctions réelles ; transport simulé, pas une connexion Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
function fonctions(f,noms){const s=fs.readFileSync(path.join(root,f),'utf8');return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(x=>x.type==='FunctionDeclaration'&&noms.includes(x.id.name)).map(x=>s.slice(x.start,x.end)).join('\n');}
function jeu(){
 const c=vm.createContext({state:{char:{name:'B'},pa:90},crypto:{randomUUID:()=> 'r1'},session:'s',messages:[],rpc:[],journal:[],storage:new Map()});
 c.rpAuthUid=()=> 'uid';c.rpAuthSessionIdentifiant=()=>c.session;
 c.localStorage={getItem:k=>c.storage.get(k),setItem:(k,v)=>c.storage.set(k,v),removeItem:k=>c.storage.delete(k)};
 c.showToast=(...v)=>c.messages.push(v);c.updateUI=()=>{};c.addJournalEntry=(...v)=>c.journal.push(v);
 c.sbRpcVerdict=async(f,p)=>{c.rpc.push([f,p]);return {ok:true,matricule:'POL-1',pa:1};};
 c.sbLoadPersonnage=async()=>({userId:'uid',pa:7});
 vm.runInContext(fonctions('plateau-multijoueur.js',['contexteGroupePj','contexteGroupePjValide'])+'\nlet effectifServeurEnCours=null;\n'+fonctions('plateau-justice-economie.js',['commanderEffectifServeur','doRecruterPolicier','doRecruterPolicierCynophile','doRecruterDouanier','doRecruterDouanierCynophile','doLicencierDouanier']),c);
 return c;
}
for(const [fn,service,type] of [['doRecruterPolicier','police','standard'],['doRecruterPolicierCynophile','police','cynophile'],['doRecruterDouanier','douane','standard'],['doRecruterDouanierCynophile','douane','cynophile']])test(fn+' utilise un ordre entier et les PA relus',async()=>{
 const c=jeu();assert.equal(await c[fn](99,999),true);assert.equal(c.rpc.length,1);assert.equal(c.rpc[0][0],'force_publique_effectif_acte');assert.equal(c.rpc[0][1].p_service,service);assert.equal(c.rpc[0][1].p_type,type);assert.equal(c.state.pa,7);assert.equal(c.storage.size,0);
});
test('réponse perdue : même reçu au second essai, aucun effet local',async()=>{const c=jeu();c.sbRpcVerdict=async(f,p)=>{c.rpc.push(p);return null;};assert.equal(await c.doRecruterPolicier(),false);assert.equal(await c.doRecruterPolicier(),false);assert.equal(c.rpc[0].p_requete,c.rpc[1].p_requete);assert.equal(c.state.pa,90);assert.equal(c.journal.length,0);});
test('double clic : un seul envoi',async()=>{const c=jeu();let finir;c.sbRpcVerdict=()=>new Promise(r=>finir=r);const p=c.doRecruterPolicier();assert.equal(await c.doRecruterPolicier(),false);finir({ok:true});assert.equal(await p,true);});
test('réponse tardive : autre personnage préservé',async()=>{const c=jeu();let finir;c.sbRpcVerdict=()=>new Promise(r=>finir=r);const p=c.doRecruterPolicier();c.state.char={name:'A'};finir({ok:true});assert.equal(await p,false);assert.equal(c.state.pa,90);assert.equal(c.journal.length,0);});
test('autre session : pas de PA repris',async()=>{const c=jeu();c.sbLoadPersonnage=async()=>{c.session='autre';return {userId:'uid',pa:4};};assert.equal(await c.doRecruterPolicier(),false);assert.equal(c.state.pa,90);});
test('relecture impossible après succès : conserver reçu',async()=>{const c=jeu();c.sbLoadPersonnage=async()=>null;assert.equal(await c.doRecruterPolicier(),false);assert.equal(c.storage.size,1);assert.equal(c.state.pa,90);});
test('pas de stockage durable : aucun ordre envoyé',async()=>{const c=jeu();c.localStorage.setItem=()=>{throw Error('quota');};assert.equal(await c.doRecruterPolicier(),false);assert.equal(c.rpc.length,0);});
test('licenciement : réutilise même porte, puis relit interface',async()=>{const c=jeu();let relu=0;c.ouvrirGererEffectifsDouane=async()=>relu++;await c.doLicencierDouanier('D1');assert.equal(c.rpc[0][1].p_action,'licencier');assert.equal(c.rpc[0][1].p_matricule,'D1');assert.equal(relu,1);});
