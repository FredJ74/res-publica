// Chromium local, module et horloge reels, transports/serveur simules. Aucun Supabase.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),os=require('node:os');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const racine=path.resolve(__dirname,'../..'),acorn=require('../vercel/node_modules/acorn');
function extraire(f,noms){const s=fs.readFileSync(path.join(racine,f),'utf8');return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
function pageRealites(){return `<!doctype html><meta charset="utf-8"><button id="sortir" onclick="sortie()"><span>Sortir</span></button><button id="carte" onclick="coordonnees(event)">Carte</button><input id="case" type="checkbox" onclick="caseLue=this.checked"><input id="message" onkeydown="if(event.key===\'Enter\')messageLu=this.value"><div id="game-time"></div><div id="journal"></div><script>
var state={char:{name:'Alice'},country:'republic',currentCity:'capitale',currentBuilding:'mairie',currentRoom:'hall',hp:100,pa:8,arg:2000,liquide:300};
var compteurs={lectures:0,commandes:0,mutations:0},intervalles=[],serveur={coma:false},dernierRefus=null,positionLue=null,caseLue=false,messageLu=null;function coordonnees(e){positionLue=[e.clientX,e.clientY,e.ctrlKey];}
window.setInterval=(fn,delai)=>{intervalles.push({fn,delai});return intervalles.length;};
function rpAuthUid(){return 'uid';}function rpAuthSessionIdentifiant(){return 'session';}async function rpAuthAssurerSession(){}
async function sbViderSauvegardeDifferee(){}
async function sbLoadPersonnage(){compteurs.lectures++;return {userId:'uid',char:{name:'Alice',journal:serveur.coma?[{text:'Attaque constatee par le serveur'}]:[]},country:'republic',currentCity:'capitale',currentBuilding:'mairie',currentRoom:'hall',hp:serveur.coma?0:100,pa:serveur.coma?0:8,arg:2000,liquide:300,hospitalisation:serveur.coma?{dateFinParis:'2099-01-01'}:null};}
function updateUI(opts){if(!opts?.lecture)throw Error('lecture transformee en sauvegarde');}function updateLocationDisplay(){}function showToast(){}
function restaurerJournal(char){document.getElementById('journal').textContent=(char.journal||[]).map(e=>e.text).join(' ');}
async function sortie(){compteurs.commandes++;if(serveur.coma){dernierRefus='hospitalisation';await rpRealitesSynchroniser({domaines:false});return;}compteurs.mutations++;state.currentBuilding=null;}
</script><script>${fs.readFileSync(path.join(racine,'plateau-realites.js'),'utf8')}</script><script>${extraire('plateau-core.js',['startClock','syncRealTime','updateClock','formatDateHeureJeu'])}</script><script>
document.addEventListener('DOMContentLoaded',async()=>{try{
 const exiger=(v,m)=>{if(!v)throw Error(m);},attendre=()=>new Promise(r=>setTimeout(r,0));startClock();
 // Une heure virtuelle : les seuls minuteurs actifs executent l'horloge visuelle reelle.
 for(let minute=0;minute<60;minute++){for(const t of intervalles)t.fn();await attendre();}
 exiger(compteurs.lectures===0,'requete au repos');exiger(state.hp===100,'etat inactif modifie');
 serveur.coma=true;for(const t of intervalles)t.fn();await attendre();exiger(state.hp===100,'attaque appliquee sans interaction');
 document.querySelector('#sortir span').click();
 for(let i=0;i<50&&dernierRefus===null;i++)await attendre();
 exiger(dernierRefus==='hospitalisation','refus serveur non recu');exiger(compteurs.commandes===1&&compteurs.mutations===0,'mutation malgre refus');exiger(state.hp===0&&state.pa===0,'synchronisation apres attaque');
 exiger(document.getElementById('journal').textContent.includes('Attaque'),'journal non actualise');
 document.getElementById('carte').dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,clientX:142,clientY:52,ctrlKey:true}));
 for(let i=0;i<50&&!positionLue;i++)await attendre();exiger(JSON.stringify(positionLue)==='[142,52,true]','coordonnees de carte perdues');
 document.getElementById('case').click();for(let i=0;i<50&&!caseLue;i++)await attendre();exiger(caseLue&&document.getElementById('case').checked,'activation native checkbox perdue');
 document.getElementById('message').value='Bonjour';document.getElementById('message').dispatchEvent(new KeyboardEvent('keydown',{bubbles:true,cancelable:true,key:'Enter'}));
 for(let i=0;i<50&&!messageLu;i++)await attendre();exiger(messageLu==='Bonjour','entree clavier perdue');
 const total=compteurs.lectures;for(let minute=0;minute<60;minute++)for(const t of intervalles)t.fn();await attendre();exiger(compteurs.lectures===total,'polling reapparu apres action');
 document.body.dataset.verdict='OK';
}catch(e){document.body.dataset.verdict='ECHEC';document.body.dataset.erreur=e.stack||e.message;}});
</script>`;}
async function verifier(largeur){
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-realites-'));let chrome,ws,id=0;const pending=new Map();
 const page=pageRealites();

 const serveur=http.createServer((req,res)=>{const url=req.url.split('?')[0];if(url==='/'){res.setHeader('Content-Type','text/html');res.end(page);return;}
  if(!['/rue-centrale.css','/plateau-rue-centrale.js'].includes(url)&&!/^\/images\/rue-[a-z-]+\.webp$/.test(url)){res.writeHead(404);res.end();return;}
  try{res.setHeader('Content-Type',url.endsWith('.js')?'text/javascript':url.endsWith('.css')?'text/css':'image/webp');res.end(fs.readFileSync(path.join(racine,url.slice(1))));}catch(_){res.writeHead(404);res.end();}});
 const pause=ms=>new Promise(r=>setTimeout(r,ms));
 try{
  await new Promise((r,j)=>{serveur.once('error',j);serveur.listen(0,'127.0.0.1',r);});
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(p=>fs.existsSync(p));assert.ok(executable,'Chromium requis');chrome=await lancerChromium({executable,profil});
  let cible;const limite=performance.now()+7000;
  while(performance.now()<limite){chrome.controlerProcessus();const r=await fetch('http://127.0.0.1:'+chrome.port+'/json/list',{signal:AbortSignal.timeout(1000)});if(!r.ok)throw Error('Pages DevTools HTTP '+r.status);cible=(await r.json()).find(p=>p.type==='page'&&p.webSocketDebuggerUrl);if(cible)break;await pause(50);}
  assert.ok(cible,'Page DevTools absente');ws=new WebSocket(cible.webSocketDebuggerUrl);
  await new Promise((r,j)=>{const timer=setTimeout(()=>j(Error('Delai WebSocket DevTools')),7000);ws.onopen=()=>{clearTimeout(timer);r();};ws.onerror=()=>{clearTimeout(timer);j(Error('Connexion DevTools refusee'));};});
  ws.onmessage=e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);clearTimeout(p.timer);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}};
  const interrompre=()=>{for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Connexion DevTools interrompue'));}pending.clear();};ws.onclose=interrompre;ws.onerror=interrompre;
  const cdp=(method,params={})=>new Promise((resolve,reject)=>{chrome.controlerProcessus();const n=++id,timer=setTimeout(()=>{pending.delete(n);reject(Error('Delai DevTools '+method));},7000);pending.set(n,{resolve,reject,timer});try{ws.send(JSON.stringify({id:n,method,params}));}catch(e){clearTimeout(timer);pending.delete(n);reject(e);}});
  await cdp('Emulation.setDeviceMetricsOverride',{width:largeur,height:900,deviceScaleFactor:1,mobile:false});await cdp('Page.navigate',{url:'http://127.0.0.1:'+serveur.address().port});
  let resultat;const fin=performance.now()+15000;
  while(performance.now()<fin){const r=await cdp('Runtime.evaluate',{expression:'JSON.stringify({verdict:document.body?.dataset.verdict,erreur:document.body?.dataset.erreur})',returnByValue:true});resultat=JSON.parse(r.result.value||'{}');if(resultat.verdict)break;await pause(50);}
  assert.equal(resultat?.verdict,'OK',resultat?.erreur||'Scenario navigateur sans verdict');
 }finally{
  for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Fermeture du banc'));}pending.clear();
  if(ws){ws.onerror=()=>{};try{ws.close();}catch(_){}}
  try{if(chrome)await chrome.arreter();}finally{serveur.closeAllConnections();try{await new Promise((r,j)=>serveur.close(e=>e&&e.code!=='ERR_SERVER_NOT_RUNNING'?j(e):r()));}finally{fs.rmSync(profil,{recursive:true,force:true,maxRetries:3});}}
 }
}
test('Chromium : zero requete au repos, etat conserve puis refus et synchro au clic (serveur simule)',()=>verifier(1280));
