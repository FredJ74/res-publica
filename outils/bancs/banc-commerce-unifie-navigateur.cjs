// Chromium et assets reels, serveur local ; identite et RPC simulees. Aucun compte de production.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),os=require('node:os');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const racine=path.resolve(__dirname,'../..');
const acorn=require('../vercel/node_modules/acorn');
function fonctions(file,noms){const s=fs.readFileSync(path.join(racine,file),'utf8');return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
const composants=fonctions('plateau-objets.js',['texteSur','ficheEchapper','ficheCommercialeHtml','ficheOfficielleHtml','ficheLignesEffets'])+fonctions('plateau-actions-illegales-rumeurs.js',['actionsCatalogueCommerceHtml','doConsulterCarteCommerce','ouvrirFicheProduitCommerce']);
const scenario=`
(async()=>{try{
const exiger=(v,m)=>{if(!v)throw Error(m);};
for(const type of ['restaurant','bar','marche']){
 data.proprietaire='Bob';await doConsulterCarteCommerce(type,'commerce','salle',0,0);
 let boutons=[...document.querySelectorAll('#postes-body button')];
 exiger(boutons.length===3,'trois actions requises '+type);
 exiger(boutons[0].disabled&&boutons[1].disabled&&!boutons[2].disabled,'droits et stock nul '+type);
 boutons[1].click();exiger(productions===0,'client a produit');
 data.proprietaire='Alice';await doConsulterCarteCommerce(type,'commerce','salle',0,0);
 boutons=[...document.querySelectorAll('#postes-body button')];exiger(!boutons[1].disabled,'production proprietaire');boutons[1].click();exiger(productions===1,'raccordement production');productions=0;
 await ouvrirFicheProduitCommerce(type,'commerce','salle','produit');
 const contenu=document.getElementById('postes-body');exiger(contenu.textContent.includes('Description utile')&&contenu.textContent.includes('Stock : 0')&&contenu.textContent.includes('25 FR')&&contenu.textContent.includes('Consommable'),'informations perdues');
 exiger(getComputedStyle(contenu.firstElementChild.children[0]).backgroundColor==='rgb(37, 45, 56)','ancienne palette');
 exiger(document.documentElement.scrollWidth<=window.innerWidth,'debordement horizontal');
}
document.body.dataset.verdict='OK';
}catch(e){document.body.dataset.verdict='ECHEC';document.body.dataset.erreur=e.message;}})();`;
async function verifier(largeur){
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-rues-'));let chrome,ws,id=0;const pending=new Map();
 const page='<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0}*{box-sizing:border-box}</style><div id="modal-postes"><h1 id="postes-modal-title"></h1><div id="postes-body"></div></div><script>var state={char:{name:"Alice"},country:"republic",currentCity:"capitale"};var COUNTRIES={republic:{cur:"FR"}},BUILDINGS={commerce:{name:"Commerce"}},FICHE_LIBELLES_REGIMES={},FICHE_LIBELLES_CAPACITES={};var recette={label:"Produit",materiaux:{},effets:{hp:5},desc:"Description utile"};var data={proprietaire:"Bob",carte:["produit"],stockProduits:{produit:0},parametres:{prixVente:{produit:25}}},productions=0;function resoudreProduitCommerce(){return recette;}function commercePeutProduire(d){return d.proprietaire===state.char.name;}function recetteAutoriseePourCommerce(){return true;}async function deduireCoutOrdre(){return {ok:true};}async function chargerCommerce(){return data;}function doProduireRecetteCommerceUI(){productions++;}function doCommanderProduitCommerceUI(){throw Error("achat en rupture");}function showToast(){throw Error("toast inattendu");}async function sbObjetFicheOfficielle(){return {resolu:true,generique:"Boisson",famille:"Aliment",aucun_effet:true,consommable:true};}</script><script>'+composants+'</script><script>'+scenario+'</script>';

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
  const cdp=(method,params={})=>new Promise((resolve,reject)=>{chrome.controlerProcessus();const n=++id,timer=setTimeout(()=>{pending.delete(n);reject(Error('Delai DevTools '+method));},15000);pending.set(n,{resolve,reject,timer});try{ws.send(JSON.stringify({id:n,method,params}));}catch(e){clearTimeout(timer);pending.delete(n);reject(e);}});
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
for(const largeur of [1280,390])test(`Chromium ${largeur}px : catalogues, droits et fiches communes`,()=>verifier(largeur));
