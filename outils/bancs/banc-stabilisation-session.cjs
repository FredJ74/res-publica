const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function sommeil(){
 const c=vm.createContext({console,state:{char:{name:'Alice'},country:'republic',pa:5,hp:40},setTimeout,clearTimeout});
 c.messages=[];c.showToast=(...a)=>c.messages.push(a);c.updateUI=()=>{};
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8'),c);return c;
}
test('le vrai motif deja_repose resynchronise les PA sans rejouer les effets',async()=>{
 const c=sommeil();c.sbRpc=async()=>({ok:false,raison:'deja_repose',pa:17});
 assert.equal(await c.doDormir(),false);assert.equal(c.state.pa,17);assert.equal(c.state.hp,40);
 assert.equal(c.messages[0][0],'Repos déjà enregistré');assert.equal(c.messages[0][2],true);
});
test('reponse perdue puis marqueur confirme : exactement deux appels idempotents, aucun soin double',async()=>{
 const c=sommeil();let n=0;c.sbRpc=async fn=>{assert.equal(fn,'pa_repos_nocturne');return ++n===1?null:{ok:false,raison:'deja_repose',pa:0};};
 await c.doDormir();assert.equal(n,2);assert.equal(c.state.pa,0);assert.equal(c.state.hp,40);
 assert.equal(c.messages[0][2],true);
});
test('reponses absentes : resultat annonce indetermine, sans PA ni succes invente',async()=>{
 const c=sommeil();let n=0;c.sbRpc=async()=>{n++;return null;};await c.doDormir();assert.equal(n,2);
 assert.equal(c.state.pa,5);assert.match(c.messages[0][1],/peut avoir été enregistré/);assert.equal(c.messages[0][2],false);
});
test('changement de personnage pendant la confirmation : aucune nouvelle requete',async()=>{
 const c=sommeil();let n=0;c.sbRpc=async()=>{n++;c.state.char={name:'Bob'};return null;};await c.doDormir();assert.equal(n,1);assert.equal(c.state.pa,5);
});
function auth(){
 const c=vm.createContext({console,setTimeout,clearTimeout,localStorage:{getItem:()=>null,setItem(){},removeItem(){}}});
 vm.runInContext(fs.readFileSync(path.join(root,'auth.js'),'utf8'),c);c.rpAuthUid=()=> 'uid';c.rpAuthJeton=()=> 'session';c.rpAuthCleAnon=()=> 'public';
 c.rpAuthEtatCompte=async()=>({ok:true,anonyme:false,confirmee:true});return c;
}
test('mot de passe : seul GoTrue recoit le secret, via PUT authentifie',async()=>{
 const c=auth();let req;c.fetch=async(u,o)=>{req={u,o};return {ok:true};};
 assert.equal((await c.rpAuthChangerMotDePasse('secret-test')).ok,true);assert.match(req.u,/\/auth\/v1\/user$/);
 assert.equal(req.o.method,'PUT');assert.equal(req.o.headers.Authorization,'Bearer session');assert.deepEqual(JSON.parse(req.o.body),{password:'secret-test'});
});
test('mot de passe : session changee pendant lecture, compte anonyme ou secret court refusent tout PUT',async()=>{
 for(const cas of ['session','anonyme','court']){
  const c=auth();let n=0;c.fetch=async()=>{n++;throw Error('interdit');};
  if(cas==='session')c.rpAuthEtatCompte=async()=>{c.rpAuthUid=()=> 'autre';return {ok:true,confirmee:true};};
  if(cas==='anonyme')c.rpAuthEtatCompte=async()=>({ok:true,anonyme:true});
  assert.equal((await c.rpAuthChangerMotDePasse(cas==='court'?'123':'secret-test')).ok,false);assert.equal(n,0);
 }
});
test('compteur PA plus recent pendant la requete : le retour du repos ne l ecrase pas',async()=>{
 const c=sommeil();let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);
 const p=c.doDormir();c.state.pa=3;resolve({ok:false,raison:'deja_repose',pa:17});await p;
 assert.equal(c.state.pa,3);
});
test('historique : borne de 30 entrees, separation par personnage, aucune persistance',()=>{
 const acorn=require('../vercel/node_modules/acorn'),src=fs.readFileSync(path.join(root,'plateau-core.js'),'utf8');
 const noms=['incidentsSessionCourante','noterIncidentSession'];
 const code=acorn.parse(src,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>src.slice(n.start,n.end)).join('\n');
 const bouton={hidden:true};const c=vm.createContext({state:{char:{name:'Alice'}},rpAuthUid:()=> 'u',document:{getElementById:()=>bouton},localStorage:{setItem:()=>assert.fail('pas de stockage permanent')}});
 vm.runInContext('let RP_INCIDENTS_SESSION=[];let RP_INCIDENTS_SCOPE=null;'+code,c);
 for(let i=0;i<40;i++)c.noterIncidentSession('code','Notification '+i);
 assert.equal(c.incidentsSessionCourante().length,30);assert.equal(c.incidentsSessionCourante()[0].titre,'Notification 39');
 c.state.char={name:'Bob'};assert.equal(c.incidentsSessionCourante().length,0);
});
test('HTTP 200 sans JSON exploitable : aucun faux verdict ni rejeu automatique, incident conserve',async()=>{
 const traces=[];let n=0;
 const c=vm.createContext({console,rpAuthJeton:()=> 'test-session',noterIncidentSession:(...x)=>traces.push(x),
  fetch:async()=>{n++;return {ok:true,status:200,json:async()=>{throw Error('corps tronque');}};}});
 vm.runInContext(fs.readFileSync(path.join(root,'supabase.js'),'utf8'),c);
 const r=await c.sbTransportRpc('pa_repos_nocturne',{p_acteur:'Alice'});
 assert.equal(r.etat,'reponse_invalide');assert.equal(r.envoyee,true);assert.equal(n,1);assert.equal(traces[0][0],'rpc_reponse_invalide');
});
function jetonSession(id,nonce){return ['header',Buffer.from(JSON.stringify({session_id:id,nonce})).toString('base64url'),'signature'].join('.');}
test('renouvellement JWT de la meme session : le repos confirme reste applicable',async()=>{
 const c=sommeil();c.atob=s=>Buffer.from(s,'base64').toString('binary');
 vm.runInContext(fs.readFileSync(path.join(root,'auth.js'),'utf8'),c);
 c.localStorage={getItem:()=>null};
 vm.runInContext('RP_AUTH_SESSION='+JSON.stringify({access_token:jetonSession('connexion-1','ancien'),expire_le:Date.now()-1,user:{id:'uid'}}),c);
 assert.equal(c.rpAuthJeton(),null);assert.equal(c.rpAuthSessionIdentifiant(),'session:connexion-1');
 c.sbRpc=async()=>{
  vm.runInContext('RP_AUTH_SESSION='+JSON.stringify({access_token:jetonSession('connexion-1','nouveau'),expire_le:Date.now()+3600000,user:{id:'uid'}}),c);
  return {ok:false,raison:'deja_repose',pa:17};
 };
 await c.doDormir();assert.equal(c.state.pa,17);
});
test('nouvelle connexion meme compte : ancienne reponse toujours ignoree',async()=>{
 const c=sommeil();c.atob=s=>Buffer.from(s,'base64').toString('binary');c.localStorage={getItem:()=>null};
 vm.runInContext(fs.readFileSync(path.join(root,'auth.js'),'utf8'),c);
 const session=id=>({access_token:jetonSession(id,'n'),expire_le:Date.now()+3600000,user:{id:'uid'}});
 vm.runInContext('RP_AUTH_SESSION='+JSON.stringify(session('connexion-1')),c);
 c.sbRpc=async()=>{vm.runInContext('RP_AUTH_SESSION='+JSON.stringify(session('connexion-2')),c);return {ok:false,raison:'deja_repose',pa:17};};
 await c.doDormir();assert.equal(c.state.pa,5);assert.equal(c.messages.length,0);
});

test('reconnexion : le bandeau ne se ferme qu apres une restauration confirmee',()=>{
 const acorn=require('../vercel/node_modules/acorn');
 const src=fs.readFileSync(path.join(root,'plateau-core.js'),'utf8');
 const ast=acorn.parse(src,{ecmaVersion:'latest'});
 const recuperation=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='recupererPersonnageDuCompte');
 const bandeau=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='afficherBandeauReconnexion');
 assert.ok(recuperation&&bandeau,'les deux fonctions doivent exister');
 const f=src.slice(recuperation.start,recuperation.end),b=src.slice(bandeau.start,bandeau.end);
 assert.match(f,/loadCharacter\(\)/,'la fiche doit suivre le chemin nominal de chargement');
 assert.match(f,/return true;/,'la restauration doit confirmer sa reussite');
 assert.match(b,/const restaure = await recupererPersonnageDuCompte\(\)/);
 assert.match(b,/if \(restaure !== true\) throw/,'une fiche introuvable ne valide pas la reconnexion');
 assert.ok(b.indexOf('if (restaure !== true)')<b.indexOf('div.remove();'),'le bandeau ne doit disparaitre qu apres verification');
});
