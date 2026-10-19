const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const racine=path.resolve(__dirname,'../..'),{bloc,regles}=require('../generateurs/generer_organisations_regles.cjs');
const source=fs.readFileSync(path.join(racine,'plateau-organisations-quetes.js'),'utf8'),ast=acorn.parse(source,{ecmaVersion:'latest'});
function fonction(nom){const n=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);return source.slice(n.start,n.end);}
test('miroir SQL complet regenere depuis les neuf types reels',()=>{assert.equal(Object.keys(regles()).length,9);assert.ok(fs.readFileSync(path.join(racine,'migrations/20261019130213_organisations_adhesions_grades.sql'),'utf8').includes(bloc()));});
const parcours=[['monterGrade','promouvoir','Bob'],['descendreGrade','retrograder','Bob'],['demanderAdhesion','demander'],['accepterAdhesion','admettre','Bob'],['refuserAdhesion','refuser_demande','Bob'],['accepterInvitationOrga','accepter_invitation'],['refuserInvitationOrga','refuser_invitation']];
for(const [nom,action,cible] of parcours)for(const verdict of [false,true,null])test(`${nom} : ${verdict===null?'ancien contrat absent':verdict?'confirme':'refuse'}`,async()=>{
 const orga={id:'o',nom:'Structure',chef:'Alice',type:'politique',visible:true,caisse:2500.5,membres:[{nom:'Bob',gradeIdx:1,grade:'Militant'}],demandesAdhesion:[{nom:'Bob'}],invitationsEnvoyees:[{nom:'Alice'}]};
 const c=vm.createContext({state:{char:{name:'Alice'},country:'republic',day:4,organisations:[orga]},TYPES_ORGANISATIONS:regles(),saves:[],messages:[],courriers:[]});
 c.getOrgaById=()=>c.state.organisations[0];c.getMesOrgasPays=()=>[];c.showToast=(...args)=>c.messages.push(args);c.addJournalEntry=()=>{};c.updateUI=()=>{};c.ouvrirGestionMembres=()=>{};c.ouvrirDemandesAdhesion=()=>{};
 c.sauvegarderOrga=o=>c.saves.push(o);c.sbSendMail=async(...args)=>c.courriers.push(args);
 c.organisationEssayerCommande=async(id,a,p)=>{assert.equal(a,action);assert.equal(id,'o');assert.deepEqual(Object.keys(p),cible?['nom']:[]);
  if(verdict===true)c.state.organisations=[{...orga,caisse:4500.5,membres:[{nom:'Bob',gradeIdx:2,grade:'Cadre'},{nom:'Alice',gradeIdx:0,grade:'Sympathisant'}]}];return verdict;};
 vm.runInContext(fonction(nom),c);await c[nom]('o',cible);
 assert.equal(c.saves.length,verdict===null?1:0);
 if(verdict===false){assert.equal(c.messages.length,0);assert.equal(c.courriers.length,0);assert.equal(c.state.organisations[0].caisse,2500.5);}
 if(verdict===true)assert.equal(c.state.organisations[0].caisse,4500.5);
});
test('transport membres : garde de rejeu commune, nom de RPC explicite',async()=>{
 const stock=new Map(),c=vm.createContext({state:{char:{name:'Alice'}},crypto:{randomUUID:()=> '000000-000000'},localStorage:{getItem:k=>stock.get(k)||null,setItem:(k,v)=>stock.set(k,v),removeItem:k=>stock.delete(k)},console});
 vm.runInContext(fs.readFileSync(path.join(racine,'supabase.js'),'utf8'),c);c.rpAuthUid=()=> 'u';
 for(const [,action,cible] of parcours){c.sbRpcVerdict=async(fn,p)=>{assert.equal(fn,'organisation_commande_membres');assert.equal(p.p_action,action);return {ok:true};};assert.equal((await c.sbOrganisationCommande('o',action,cible?{nom:cible}:{})).ok,true);}
});
