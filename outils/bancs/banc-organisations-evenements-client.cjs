const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const racine=path.resolve(__dirname,'../..'),source=fs.readFileSync(path.join(racine,'plateau-organisations-quetes.js'),'utf8'),ast=acorn.parse(source,{ecmaVersion:'latest'});
function fonction(nom){const n=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);return source.slice(n.start,n.end);}
for(const action of ['inviter','declencher_election'])for(const ok of [false,true])test(`${action} : ${ok?'confirme':'refuse'} sans ecriture legacy ni double paiement`,async()=>{
 const orga={id:'o',chef:'Alice',nom:'Structure',visible:false};const c=vm.createContext({state:{char:{name:'Alice'},organisations:[orga]},messages:[],commandes:[],document:{getElementById:id=>({value:id==='invite-orga-select'?'Bob':'Motivation',classList:{remove(){},contains:()=>false}})}});
 c.getOrgaById=()=>orga;c.equipementsCollectifsContexte=()=>c.state.char;c.equipementsCollectifsContexteValide=p=>p===c.state.char;
 c.showToast=(...a)=>c.messages.push(a);c.addJournalEntry=()=>{};c.updateUI=()=>{};c.commercePjActualiserPersonnage=async()=>true;
 c.deduireCoutOrdre=c.sbSendMail=c.sauvegarderOrga=c.sbCreateTopic=()=>{throw Error('ancien chemin interdit');};
 c.organisationEssayerCommande=async(id,a,p)=>{assert.equal(a,action);assert.deepEqual(Object.keys(p),action==='inviter'?['nom']:['motivation']);c.commandes.push(a);return ok;};
 const nom=action==='inviter'?'envoyerInvitationOrga':'confirmerDeclenchementElection';vm.runInContext(fonction(nom),c);await c[nom]('o',999,999);
 assert.equal(c.commandes.length,1);assert.equal(c.messages.length,ok?1:0);
});
test('PA non relus : transaction confirmee, indisponibilite affichee sans delta local',async()=>{
 const c=vm.createContext({state:{char:{name:'Alice'},pa:10},document:{getElementById:()=>({value:'Motif',classList:{remove(){},contains:()=>false}})},messages:[]});
 c.getOrgaById=()=>({id:'o'});c.equipementsCollectifsContexte=()=>c.state.char;c.equipementsCollectifsContexteValide=()=>true;c.organisationEssayerCommande=async()=>true;c.commercePjActualiserPersonnage=async()=>false;c.updateUI=()=>{};c.showToast=(...args)=>c.messages.push(args);
 vm.runInContext(fonction('confirmerDeclenchementElection'),c);await c.confirmerDeclenchementElection('o',1,0);assert.equal(c.state.pa,10);assert.match(c.messages[0][1],/indisponible/);
});
test('transport : nouvelle RPC explicite, aucune valeur de cout acceptee de l interface',async()=>{
 const stock=new Map(),c=vm.createContext({state:{char:{name:'Alice'}},crypto:{randomUUID:()=> '000000-000000'},localStorage:{getItem:k=>stock.get(k)||null,setItem:(k,v)=>stock.set(k,v),removeItem:k=>stock.delete(k)}});
 vm.runInContext(fs.readFileSync(path.join(racine,'supabase.js'),'utf8'),c);c.rpAuthUid=()=> 'u';
 for(const action of ['inviter','declencher_election']){c.sbRpcVerdict=async(fn,p)=>{assert.equal(fn,'organisation_commande_evenement');assert.equal(p.p_action,action);return {ok:true};};assert.equal((await c.sbOrganisationCommande('o',action,action==='inviter'?{nom:'Bob'}:{motivation:'Motif'})).ok,true);}
});
test('couts electoraux : les deux ordres existants sont toujours 1 PA et 0 FR',()=>{
 const buildings=vm.runInNewContext(fs.readFileSync(path.join(racine,'data.js'),'utf8')+';BUILDINGS',{}, {timeout:5000});
 const couts=[];function visiter(o){if(!o||typeof o!=='object')return;if(['declencher_election_club','declencher_election_syndicat'].includes(o.fn))couts.push(o);for(const v of Object.values(o))visiter(v);}visiter(buildings);
 for(const fn of ['declencher_election_club','declencher_election_syndicat']){const lignes=couts.filter(o=>o.fn===fn);assert.ok(lignes.length>0);assert.ok(lignes.every(o=>o.pa===1&&o.cost===0));}
});
