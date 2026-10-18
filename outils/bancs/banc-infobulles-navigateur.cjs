// Chromium reel, composants extraits des sources ; fixture DOM, aucun compte/Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {spawn}=require('node:child_process'),http=require('node:http'),os=require('node:os');
const acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
function extraire(src,noms){return acorn.parse(src,{ecmaVersion:'latest',sourceType:'script'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>src.slice(n.start,n.end)).join('\n');}
async function navigateur(ancien,largeur){
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-bulle-'));
 const lire=f=>fs.readFileSync(path.join(root,f),'utf8');
 // Ancien composant exact : il ne nettoyait que la bulle de minimap, pas celle de body.
 const ancienMasquage="function hideBuildingTooltip() { const el=document.getElementById('building-hover-tooltip'); if(el)el.classList.remove('visible'); }";
 const js=(ancien?ancienMasquage:extraire(lire('plateau-navigation.js'),['hideBuildingTooltip']))+'\n'+extraire(lire('plateau-rue-centrale.js'),['afficherTooltipRue','masquerTooltipRue'])+'\n'+extraire(lire('plateau-commerce-pj.js'),['commercePjModale']);
 const page=`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css"><div id="vue-rue" class="active"></div><div id="vue-batiment"></div><div id="building-hover-tooltip"></div><div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><div class="modal-title">Vendre ou donner des matières</div><button>Fermer</button></div><div id="postes-body" class="modal-body"><div class="cpj-ecran cpj-dialogue"><p>Choix de quantité</p><input style="width:100%" value="10"><button>Donner</button><button>Vendre</button><div style="height:800px"></div><button id="action-finale">Confirmer</button></div></div></div></div><script>${js}
commercePjModale('Donner ou vendre des matières',document.getElementById('postes-body').innerHTML);document.getElementById('modal-postes').classList.remove('open');
const erreurs=[];function exiger(c,m){if(!c)throw Error(m);}(async()=>{try{
 afficherTooltipRue({pageX:20,pageY:20},"CENTRE D’AFFAIRES");exiger(!!document.getElementById('rc-tooltip'),'infobulle rue disponible');
 for(let i=0;i<3;i++){
  hideBuildingTooltip();document.getElementById('vue-batiment').classList.add('active');
  exiger(!document.querySelector('#rc-tooltip.visible'),'ancienne bulle persistante');
  afficherTooltipRue({pageX:20,pageY:20},'ancienne scene');exiger(!document.querySelector('#rc-tooltip.visible'),'mousemove tardif ressuscite la bulle');
  document.getElementById('modal-postes').classList.toggle('open');hideBuildingTooltip();
 }
 document.getElementById('vue-batiment').classList.remove('active');afficherTooltipRue({pageX:20,pageY:20},'Rue');exiger(!!document.querySelector('#rc-tooltip.visible'),'bulle legitime masquee');hideBuildingTooltip();
 const source=document.createElement('div');document.body.appendChild(source);
 afficherTooltipRue({pageX:10,pageY:10,currentTarget:source},'Source detruite');source.remove();
 await Promise.resolve();exiger(!document.getElementById('rc-tooltip'),'bulle orpheline apres destruction');
 afficherTooltipRue({pageX:10,pageY:10},'Rue avant modale');
 document.getElementById('modal-postes').classList.add('open');await Promise.resolve();
 exiger(!document.getElementById('rc-tooltip'),'bulle derriere modale persistante');
 const box=document.querySelector('.modal-box');exiger(box.getBoundingClientRect().width<=innerWidth,'debordement horizontal');
 box.scrollTop=box.scrollHeight;const bouton=document.getElementById('action-finale').getBoundingClientRect();exiger(bouton.top>=0&&bouton.bottom<=innerHeight,'action inaccessible apres defilement');
 document.body.dataset.verdict='OK';
}catch(e){document.body.dataset.verdict='ECHEC';document.body.dataset.erreur=e.message;}})();</script>`;
 const serveur=http.createServer((req,res)=>{res.setHeader('Content-Type',req.url==='/style.css'?'text/css':'text/html');res.end(req.url==='/style.css'?fs.readFileSync(path.join(root,'style.css')):page);});
 await new Promise(r=>serveur.listen(0,'127.0.0.1',r));
 try{
  const port=serveur.address().port;
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(p=>fs.existsSync(p));
  if(!executable)throw Error('Chromium requis pour cette verification');
  const p=spawn(executable,['--headless','--no-sandbox','--disable-gpu','--disable-background-networking','--disable-dev-shm-usage','--disable-software-rasterizer','--no-zygote','--disable-extensions','--remote-debugging-port=0','--user-data-dir='+profil,'about:blank'],{detached:true,env:{...process.env,XDG_CONFIG_HOME:profil,XDG_CACHE_HOME:profil}});
  let logs='';let termine=false;let codeSortie=null;
  p.once('exit',code=>{termine=true;codeSortie=code;});
  p.stderr.on('data',b=>logs+=b);p.stdout.resume();
  let ws;
  try{
   const attendre=ms=>new Promise(r=>setTimeout(r,ms));
   // Chromium peut publier son port avant le message stderr (ou sans ce message).
   // Attendre son fichier de readiness plutot que dependre des logs D-Bus/stderr.
   let portCDP=null;
   for(let i=0;i<400&&!portCDP;i++){
    const fichier=path.join(profil,'DevToolsActivePort');
    if(fs.existsSync(fichier)){
     const contenu=fs.readFileSync(fichier,'utf8');
     const port=Number(contenu.trim().split(/\s+/)[0]);
     if(Number.isInteger(port)&&port>0&&port<65536)portCDP=String(port);
    }
    if(!portCDP)portCDP=logs.match(/ws:\/\/127\.0\.0\.1:(\d+)/)?.[1]||null;
    if(termine)break;
    if(!portCDP)await attendre(50);
   }
   if(!portCDP)throw Error('Demarrage Chromium non confirme (exit='+codeSortie+') : '+logs.slice(-500));
   const pages=await fetch('http://127.0.0.1:'+portCDP+'/json/list').then(r=>r.json());
   ws=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);
   await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});
   const requetes=new Map();let id=0;
   ws.onmessage=e=>{const m=JSON.parse(e.data);const r=requetes.get(m.id);if(r){requetes.delete(m.id);clearTimeout(r.timer);m.error?r.reject(Error(JSON.stringify(m.error))):r.resolve(m.result);}};
   function cdp(method,params={}){return new Promise((resolve,reject)=>{const n=++id;const timer=setTimeout(()=>{requetes.delete(n);reject(Error('CDP delai '+method));},7000);requetes.set(n,{resolve,reject,timer});ws.send(JSON.stringify({id:n,method,params}));});}
   await cdp('Emulation.setDeviceMetricsOverride',{width:largeur,height:700,deviceScaleFactor:1,mobile:false});
   await cdp('Page.navigate',{url:'http://127.0.0.1:'+port});
   let verdict;
   for(let i=0;i<80;i++){
    const r=await cdp('Runtime.evaluate',{expression:'document.body?.dataset.verdict',returnByValue:true});
    verdict=r.result?.value;if(verdict)break;await attendre(25);
   }
   if(!verdict)throw Error('Aucun verdict navigateur');
   const r=await cdp('Runtime.evaluate',{expression:'document.documentElement.outerHTML',returnByValue:true});
   return r.result.value;
  }finally{if(ws)ws.close();try{process.kill(-p.pid,'SIGKILL');}catch(_){} }

 }finally{serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true,maxRetries:3});}
}
test('reproduction Chromium de la bulle persistante avec les anciens composants',async()=>{
 const html=await navigateur(true,1280);assert.match(html,/data-verdict="ECHEC"/);assert.match(html,/data-erreur="ancienne bulle persistante"/);
});
for(const w of [1280,390])test(`Chromium ${w}px : transitions, modal, evenement tardif et defilement`,async()=>{
 assert.match(await navigateur(false,w),/data-verdict="OK"/);
});
