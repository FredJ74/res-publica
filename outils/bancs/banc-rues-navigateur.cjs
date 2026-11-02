// Chromium et assets reels, serveur local ; identite et RPC simulees. Aucun compte de production.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),os=require('node:os');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const racine=path.resolve(__dirname,'../..');
const scenario=`
(async()=>{try{
const exiger=(v,m)=>{if(!v)throw Error(m);};
const scenes=[['capitale','luthecia-terrains-lots','luthecia-terrains-artisanal'],['ville_a','psm-terrains-lots','psm-terrains-vente']];
for(const [ville,noeud,parent] of scenes){
 state.currentCity=ville;await afficherNoeudRue('republic',noeud,parent,true);await document.getElementById('rc-image').decode();
 const scene=document.getElementById('rc-scene').getBoundingClientRect(),arrow=document.querySelector('.rc-fleche'),rect=arrow.getBoundingClientRect();
 exiger(Math.abs((rect.left+rect.width/2)-(scene.left+scene.width/2))<2,'fleche non centree '+noeud);
 exiger(Math.abs(scene.bottom-rect.bottom-11)<2,'fleche hors du bas '+noeud);
 exiger(document.elementFromPoint(rect.left+rect.width/2,rect.top+rect.height/2).closest('.rc-fleche')===arrow,'fleche masquee '+noeud);
 arrow.click();await new Promise(r=>setTimeout(r,650));exiger(rueCentraleNoeudActuel===parent,'retour incorrect '+noeud);
}
state.currentCity='ville_a';const images=new Set();
for(const origine of ['psm-carrefour-artisanal-scierie','psm-ecole-phare','psm-tribunal-banque','psm-eglise-cimetiere']){
 await afficherNoeudRue('republic','psm-carrefour-musee',origine,true);await document.getElementById('rc-image').decode();
 images.add(document.getElementById('rc-image').getAttribute('src'));
 const noeud=RUE_CENTRALE_NOEUDS.republic['psm-carrefour-musee'];const zones=[...document.querySelectorAll('.rc-zone')];
 exiger(zones.length===3,'zones perdues '+origine);
 const img=document.getElementById('rc-image').getBoundingClientRect();
 for(let i=0;i<zones.length;i++){
  const z=zones[i].getBoundingClientRect(),attendu=noeud.zonesParArrivee[origine][i];
  exiger(Math.abs((z.left-img.left)/img.width*100-attendu.xPct[0])<1,'zone decalee '+origine);
 }
 exiger(document.querySelectorAll('.rc-fleche').length===4,'directions perdues '+origine);
}
exiger(images.size===4,'les quatre vues doivent rester distinctes');
// Vrais fichiers et vrai sélecteur de variante ; seul l'état locatif est simulé.
for(const piece of ['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve']){
 for(const etat of ['libre','occupee']){
  PIECE_FAMILLES_ETAT.location.etat=()=>etat;
  const url=varianteImagePiece('centre-commercial',piece,'ville_a');
  exiger(etat!=='libre'||url.startsWith('images/port-sainte-marie-'),'image libre PSM masquée '+piece);
  const img=new Image();img.src=url;await img.decode();
  exiger(img.naturalWidth>0&&img.naturalHeight>0,'illustration illisible '+piece+' '+etat);
 }
}
document.body.dataset.verdict='OK';
}catch(e){document.body.dataset.verdict='ECHEC';document.body.dataset.erreur=e.message;}})();`;
async function verifier(largeur){
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-rues-'));let chrome,ws,id=0;const pending=new Map();
 const page='<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/rue-centrale.css"><div id="rue-centrale-conteneur"></div><script>var state={char:{name:"Temoin"},country:"republic",currentCity:"capitale"};async function sbRpc(){return {ok:true};}</script><script src="/data.js"></script><script src="/plateau-variantes-pieces.js"></script><script src="/plateau-rue-centrale.js"></script><script>'+scenario+'</script>';
 const serveur=http.createServer((req,res)=>{const url=req.url.split('?')[0];if(url==='/'){res.setHeader('Content-Type','text/html');res.end(page);return;}
  if(!['/rue-centrale.css','/data.js','/plateau-variantes-pieces.js','/plateau-rue-centrale.js'].includes(url)&&!/^\/images\/[a-z-]+\.(?:webp|png)$/.test(url)){res.writeHead(404);res.end();return;}
  try{res.setHeader('Content-Type',url.endsWith('.js')?'text/javascript':url.endsWith('.css')?'text/css':url.endsWith('.png')?'image/png':'image/webp');res.end(fs.readFileSync(path.join(racine,url.slice(1))));}catch(_){res.writeHead(404);res.end();}});
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
for(const largeur of [1280,390])test(`Chromium ${largeur}px : retours des lots, quatre vues et huit états graphiques PSM`,()=>verifier(largeur));
