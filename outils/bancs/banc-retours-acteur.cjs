// Fonctions de production ; transports retardes et personnages exclusivement fictifs.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function bloc(f,nom){const s=fs.readFileSync(path.join(root,f),'utf8'),a=s.indexOf('async function '+nom+'(');assert.ok(a>=0);return s.slice(a,s.indexOf('\n}',a)+2);}
function jeu(){
 const c=vm.createContext({console,state:{char:{name:'Alice'},country:'republic',currentCity:'capitale',currentBuilding:'dispensaire-public',hp:12,pa:5,arg:40,liquide:10,day:1},uid:'u',jeton:'t',setTimeout,clearTimeout});
 c.rpAuthUid=()=>c.uid;c.rpAuthJeton=()=>c.jeton;c.traces=[];
 for(const n of ['showToast','updateUI','addJournalEntry','signalerRefusCout','sauvegarderPersonnageImmediat','switchSelfTab'])c[n]=()=>c.traces.push(n);
 c.deduireCoutOrdre=async()=>({ok:true});
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8'),c);
 return c;
}
function changer(c,type){if(type==='personnage')c.state.char={name:'Bob'};if(type==='compte')c.uid='autre';if(type==='session')c.jeton='autre';}
const reponse={ok:true,hp:50,pa:7,arg:0,liquide:0,gain_hp:10,gain_pa:1};
for(const soin of ['doSoinPublic','doSoinCliniquePrivee']){
 for(const type of ['personnage','compte','session'])test(`${soin}/${type} : apres le cout, aucune RPC pour un autre acteur`,async()=>{
  const c=jeu();let resolve,n=0;c.deduireCoutOrdre=()=>new Promise(r=>resolve=r);c.sbRpc=async()=>{n++;return reponse;};
  const p=c[soin](1,10);changer(c,type);resolve({ok:true});await p;assert.equal(n,0);assert.equal(c.state.hp,12);
 });
 test(`${soin} : retour tardif ignore et succes normal conserve`,async()=>{
  const c=jeu();let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);const p=c[soin](1,10);
  await new Promise(r=>setImmediate(r));c.state.char={name:'Bob'};resolve(reponse);await p;assert.equal(c.state.hp,12);
  c.sbRpc=async()=>reponse;await c[soin](1,10);assert.equal(c.state.hp,50);assert.equal(c.state.arg,0);
 });
}
test('sommeil : reponse de repos tardive ne modifie pas le nouveau personnage',async()=>{
 const c=jeu();let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);const p=c.doDormir();c.state.char={name:'Bob'};
 resolve({ok:true,pa:17});await p;assert.equal(c.state.pa,5);assert.equal(c.state.hp,12);
});
test('sommeil : changement pendant la solde ne declenche pas le salaire pour le nouvel acteur',async()=>{
 const c=jeu();let resolve,n=0;c.localStorage={setItem(){}};c.sbRpc=async()=>{n++;return {ok:true,pa:17};};
 c.sbMilitaireSoldePercevoir=()=>new Promise(r=>resolve=r);const p=c.doDormir();await new Promise(r=>setImmediate(r));
 c.state.char={name:'Bob'};resolve({ok:true,arg:999,liquide:999});await p;assert.equal(n,1);assert.equal(c.state.arg,40);
});
for(const type of ['personnage','compte','session'])test(`Assemblee/${type} : ni reexecution ni application d'une ancienne reponse`,async()=>{
 const c=jeu();vm.runInContext('let _assembleeActionEnVol=false;',c);vm.runInContext(bloc('plateau-assemblee.js','assembleeActionServeur'),c);
 c.assembleeNouvelleRequete=()=> 'requete-fixture';c.assembleeAppliquerEtatServeur=()=>assert.fail('Retour obsolete');
 let resolve,n=0;const p=c.assembleeActionServeur(()=>{n++;return n===1 ? new Promise(r=>resolve=r) : null;});changer(c,type);resolve(null);
 await p;assert.equal(n,1);
});
test('justice : une liberation ancienne ne libere pas le nouveau personnage',async()=>{
 const c=jeu();vm.runInContext(bloc('plateau-justice-economie.js','verifierLiberationPrisonniers'),c);
 c.state.estEmprisonne={jourFin:0,detentionId:'a'};let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);
 const p=c.verifierLiberationPrisonniers();c.state.char={name:'Bob'};c.state.estEmprisonne={jourFin:20,detentionId:'b'};
 resolve({ok:true});await p;assert.equal(c.state.estEmprisonne.detentionId,'b');
});
test('politique : une candidature acceptee pour Alice ne donne pas son poste a Bob',async()=>{
 const c=jeu();vm.runInContext(bloc('plateau-politique.js','postulerPosteAutoritePnj'),c);
 c.POSTES_NOMMES_EXCLUSIFS={};let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);c.document={getElementById:()=>null};
 const p=c.postulerPosteAutoritePnj('maire_adjoint','Adjoint','capitale');c.state.char={name:'Bob'};resolve({ok:true});
 await p;assert.equal(c.state.poste,undefined);
});
test('militaire : lecture tardive ignoree apres changement de compte',async()=>{
 const c=jeu();vm.runInContext('let RP_MIL_ETAT=null; let RP_MIL_LECTURE=0;',c);
 vm.runInContext(bloc('plateau-militaire-terminal.js','milRafraichir'),c);let resolve,n=0;
 c.sbMilitaireTerminalSection=()=>new Promise(r=>resolve=r);c.milRendre=()=>n++;c.milMessage=()=>n++;
 const p=c.milRafraichir();c.uid='autre';resolve({ok:true});await p;assert.equal(n,0);
});
test('Assemblee : succes, zeros et meme cle au rejeu restent fonctionnels',async()=>{
 const c=jeu();vm.runInContext('let _assembleeActionEnVol=false;',c);vm.runInContext(bloc('plateau-assemblee.js','assembleeActionServeur'),c);
 c.assembleeNouvelleRequete=()=> 'rq-fixture';c.assembleeAppliquerEtatServeur=r=>{c.state.arg=r.arg;};
 const cles=[];const r=await c.assembleeActionServeur(rq=>{cles.push(rq);return cles.length===1?null:{ok:true,arg:0};});
 assert.equal(r.ok,true);assert.equal(c.state.arg,0);assert.deepEqual(cles,['rq-fixture','rq-fixture']);
});
test('Assemblee : changement pendant la sauvegarde empeche toute nouvelle commande',async()=>{
 const c=jeu();vm.runInContext('let _assembleeActionEnVol=false;',c);vm.runInContext(bloc('plateau-assemblee.js','assembleeActionServeur'),c);
 let resolve;c.sbSavePersonnage=()=>new Promise(r=>resolve=r);const p=c.assembleeActionServeur(()=>assert.fail('Ancienne intention'));
 c.state.char={name:'Bob'};resolve(true);await p;
});
test('justice : un verdict ne remplace pas une autre detention du meme personnage',async()=>{
 const c=jeu();vm.runInContext(bloc('plateau-justice-economie.js','verifierLiberationPrisonniers'),c);
 c.state.estEmprisonne={jourFin:0,detentionId:'a'};let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);
 const p=c.verifierLiberationPrisonniers();c.state.estEmprisonne={jourFin:20,detentionId:'b'};resolve({ok:true});await p;
 assert.equal(c.state.estEmprisonne.detentionId,'b');
});
test('militaire : deux lectures dans le desordre conservent la plus recente',async()=>{
 const c=jeu();vm.runInContext('let RP_MIL_ETAT=null; let RP_MIL_LECTURE=0;',c);vm.runInContext(bloc('plateau-militaire-terminal.js','milRafraichir'),c);
 let resolve;c.sbMilitaireTerminalSection=()=>new Promise(r=>resolve=r);c.milRendre=()=>{};const p=c.milRafraichir();
 c.sbMilitaireTerminalSection=async()=>({ok:true,version:'recente'});await c.milRafraichir();resolve({ok:true,version:'ancienne'});await p;
 assert.equal(vm.runInContext('RP_MIL_ETAT.version',c),'recente');
});
for(const nom of ['milOrdonnerManger','milOrdonnerDormir','milRejoindre'])test(`militaire/${nom} : ancienne reponse ne vide pas les selections`,async()=>{
 const c=jeu();vm.runInContext("let RP_MIL_MANGER=new Set(['a']);let RP_MIL_DORMIR=new Set(['a']);let RP_MIL_TENTE=new Set(['a']);",c);
 vm.runInContext(bloc('plateau-militaire-terminal.js',nom),c);c.nouvelleCleMilitaire=()=> 'rq-fixture';let resolve;
 for(const n of ['sbMilitaireTerminalManger','sbMilitaireTerminalDormir','sbMilitaireTerminalRejoindre'])c[n]=()=>new Promise(r=>resolve=r);
 c.milRafraichir=()=>assert.fail('Ancienne reponse');const p=c[nom]('a');c.state.char={name:'Bob'};resolve({ok:true});await p;
 assert.equal(vm.runInContext('RP_MIL_MANGER.size+RP_MIL_DORMIR.size+RP_MIL_TENTE.size',c),3);
});
