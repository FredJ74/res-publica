const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const racine=path.resolve(__dirname,'../..');
function jeu(stock=new Map()){
 const c=vm.createContext({console:{error(){},warn(){}},state:{char:{name:'Alice'},organisations:[{id:'o',chef:'Alice',nom:'Avant',caisse:1}]},crypto:{randomUUID:()=> '000000-000000'},
 localStorage:{getItem:k=>stock.get(k)||null,setItem:(k,v)=>stock.set(k,v),removeItem:k=>stock.delete(k)},toasts:[],sauvegardes:[],document:{getElementById:id=>({value:'Apres',classList:{remove(){}}})}});
 c.rpAuthUid=()=> 'uid';c.equipementsCollectifsContexte=()=>c.state.char;c.equipementsCollectifsContexteValide=p=>p===c.state.char;
 c.showToast=(...a)=>c.toasts.push(a);c.switchSelfTab=()=>{};
 vm.runInContext(fs.readFileSync(path.join(racine,'supabase.js'),'utf8'),c);
 const s=fs.readFileSync(path.join(racine,'plateau-organisations-quetes.js'),'utf8');
 vm.runInContext(s.slice(s.indexOf('async function organisationEssayerCommande'),s.indexOf('// Charge toutes les organisations depuis Supabase')),c);
 vm.runInContext(s.slice(s.indexOf('async function renommerOrga'),s.indexOf('async function toggleVisibiliteOrga')),c);
 c.getOrgaById=id=>c.state.organisations.find(o=>o.id===id);c.sauvegarderOrga=o=>c.sauvegardes.push(o);
 return c;
}
test('absence du contrat confirmee : ancien chemin transitoire, sans fausse activation',async()=>{
 const c=jeu();c.sbRpcVerdict=async()=>({ok:false,transport:{http:404,code:'PGRST202'}});
 await c.renommerOrga('o');assert.equal(c.sauvegardes.length,1);assert.equal(c.state.organisations[0].nom,'Apres');
});
for(const r of [{ok:false,transport:{http:403,code:'42501'}},{ok:false,transport:{http:503}},{ok:false,transport:{http:404,code:'autre'}},{ok:false,raison:'transport_indisponible'}])test('refus/panne ne declenche aucune sauvegarde legacy '+JSON.stringify(r),async()=>{
 const c=jeu();c.sbRpcVerdict=async()=>r;await c.renommerOrga('o');assert.equal(c.sauvegardes.length,0);assert.equal(c.state.organisations[0].nom,'Avant');assert.ok(c.toasts.every(t=>t[2]===false));
});
test('rejeu confirme : relecture actuelle, jamais le solde contenu dans un ancien recu',async()=>{
 const c=jeu();c.sbRpcVerdict=async()=>({ok:true,rejeu:true,organisation:{id:'o',caisse:1}});
 c.sbGetOrganisationParId=async()=>({id:'o',nom:'Apres',caisse:2001});await c.renommerOrga('o');
 assert.equal(c.state.organisations[0].caisse,2001);assert.equal(c.sauvegardes.length,0);
});
test('ancienne session : reponse non appliquee',async()=>{
 const c=jeu();let finir;c.sbRpcVerdict=()=>new Promise(r=>finir=r);const p=c.renommerOrga('o');
 c.state.char={name:'Bob'};finir({ok:true});await p;assert.equal(c.state.organisations[0].nom,'Avant');assert.equal(c.toasts.length,0);
});
test('reponse perdue et F5 : meme identifiant et une seule commande en vol',async()=>{
 const stock=new Map(),c=jeu(stock);let finir,cle;c.sbRpcVerdict=(fn,p)=>{cle=p.p_requete;return new Promise(r=>finir=r);};
 const p=c.sbOrganisationCommande('o','informations',{nom:'Apres'});
 assert.equal((await c.sbOrganisationCommande('o','informations',{nom:'Autre'})).raison,'commande_en_cours');
 finir({ok:false});await p;
 const d=jeu(stock);d.crypto.randomUUID=()=> '111111-111111';d.sbRpcVerdict=async(fn,p)=>{assert.equal(p.p_requete,cle);return {ok:true};};
 assert.equal((await d.sbOrganisationCommande('o','informations',{nom:'Apres'})).ok,true);assert.equal(stock.size,0);
});
test('stockage indisponible : aucune commande envoyee, aucun repli',async()=>{
 const c=jeu();c.localStorage.setItem=()=>{throw Error('stockage');};c.sbRpcVerdict=()=>{throw Error('ne doit pas partir');};
 await c.renommerOrga('o');assert.equal(c.sauvegardes.length,0);assert.equal(c.state.organisations[0].nom,'Avant');
});
test('transaction confirmee mais relecture en panne : pas de snapshot local invente',async()=>{
 const c=jeu();c.sbRpcVerdict=async()=>({ok:true});c.sbGetOrganisationParId=async()=>null;
 await c.renommerOrga('o');assert.equal(c.state.organisations[0].nom,'Avant');assert.equal(c.sauvegardes.length,0);assert.equal(c.toasts[0][0],'Opération enregistrée');
});
for(const action of ['candidature','vote'])test(`election/${action} : la confirmation serveur precede le rendu`,async()=>{
 const c=jeu(),s=fs.readFileSync(path.join(racine,'plateau-organisations-quetes.js'),'utf8');
 vm.runInContext(s.slice(s.indexOf('async function seProsenterCandidat'),s.indexOf('// Fait avancer toutes les elections')),c);
 c.state.organisations[0].election={enCours:true,phase:action==='vote'?'vote':'candidatures',candidats:[],votes:{}};
 c.state.organisations[0].membres=[{nom:'Alice'}];c.updateUI=()=>{};
 c.sbRpcVerdict=async(fn,p)=>{assert.equal(p.p_action,action);assert.equal(Object.hasOwn(p.p_parametres,'acteur'),false);return {ok:false};};
 if(action==='vote')await c.voterElection('o','Bob');else await c.seProsenterCandidat('o');
 assert.equal(c.sauvegardes.length,0);assert.equal(c.state.organisations[0].election.candidats.length,0);assert.equal(Object.keys(c.state.organisations[0].election.votes).length,0);
 assert.equal(c.toasts[0][2],false);
});
for(const r of [{ok:false,disponible:true},{ok:true,disponible:true,dissoute:'autre'},{ok:true,disponible:true,dissoute:'o'}])test('dissolution : aucun DELETE general apres reponse du nouveau contrat '+JSON.stringify(r),async()=>{
 const c=jeu();c.sbOrganisationCommande=async()=>r;c.sbDeleteVerdict=async()=>{throw Error('repli interdit');};
 assert.equal(await c.sbDeleteOrganisation('o'),r.ok&&r.dissoute==='o');
});
test('lecture organisation texte et jsonb : meme representation, sans tableau accepte',async()=>{
 const c=jeu();for(const data of [{id:'o'},'{"id":"o"}']){c.sbGet=async()=>[{data}];assert.equal((await c.sbGetOrganisationParId('o')).id,'o');}
 c.sbGet=async()=>[{data:[]}];assert.equal(await c.sbGetOrganisationParId('o'),null);
});
