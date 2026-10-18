// Chromium reel, composants extraits des sources ; fixture DOM, aucun compte/Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const http=require('node:http'),os=require('node:os');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
function extraire(src,noms){return acorn.parse(src,{ecmaVersion:'latest',sourceType:'script'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>src.slice(n.start,n.end)).join('\n');}
async function navigateur(ancien,largeur){
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
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-bulle-'));
 const serveur=http.createServer((req,res)=>{res.setHeader('Content-Type',req.url==='/style.css'?'text/css':'text/html');res.end(req.url==='/style.css'?fs.readFileSync(path.join(root,'style.css')):page);});
 let navigateurCDP,ws;
 const requetes=new Map();
 const attendre=ms=>new Promise(r=>setTimeout(r,ms));
 async function borne(promesse,ms,message){
  let timer;
  try{return await Promise.race([promesse,new Promise((_,rej)=>{timer=setTimeout(()=>rej(Error(message)),ms);})]);}
  finally{clearTimeout(timer);}
 }
 try{
  await new Promise((r,j)=>{serveur.once('error',j);serveur.listen(0,'127.0.0.1',r);});
  const port=serveur.address().port;
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(p=>fs.existsSync(p));
  if(!executable)throw Error('HG_CHROMIUM_SPAWN : Chromium requis pour cette verification');
  navigateurCDP=await lancerChromium({executable,profil});
  const portCDP=navigateurCDP.port;
  let pageCDP;
  const limitePages=performance.now()+7000;
  while(performance.now()<limitePages){
   navigateurCDP.controlerProcessus();
   const res=await fetch('http://127.0.0.1:'+portCDP+'/json/list',{signal:AbortSignal.timeout(1000)});
   if(!res.ok)throw Error('HG_CHROMIUM_CDP : liste des pages HTTP '+res.status);
   pageCDP=(await res.json()).find(p=>p.type==='page'&&p.webSocketDebuggerUrl);
   if(pageCDP)break;await attendre(50);
  }
  if(!pageCDP)throw Error('HG_CHROMIUM_CDP_TIMEOUT : aucune page DevTools apres initialisation');
  ws=new WebSocket(pageCDP.webSocketDebuggerUrl);
  await borne(new Promise((r,j)=>{ws.onopen=r;ws.onerror=()=>j(Error('HG_CHROMIUM_CDP : connexion WebSocket refusee'));}),7000,'HG_CHROMIUM_CDP_TIMEOUT : ouverture WebSocket');
   let id=0;
   ws.onmessage=e=>{const m=JSON.parse(e.data);const r=requetes.get(m.id);if(r){requetes.delete(m.id);clearTimeout(r.timer);m.error?r.reject(Error(JSON.stringify(m.error))):r.resolve(m.result);}};
   function cdp(method,params={}){return new Promise((resolve,reject)=>{
    navigateurCDP.controlerProcessus();
    const n=++id;const timer=setTimeout(()=>{
     requetes.delete(n);
     try{navigateurCDP.controlerProcessus();reject(Error('HG_CHROMIUM_CDP_TIMEOUT : '+method));}catch(e){reject(e);}
    },7000);
    requetes.set(n,{resolve,reject,timer});
    try{ws.send(JSON.stringify({id:n,method,params}));}catch(e){clearTimeout(timer);requetes.delete(n);reject(e);}
   });}
   const fermerRequetes=()=>{for(const r of requetes.values()){clearTimeout(r.timer);r.reject(Error('HG_CHROMIUM_CDP : connexion interrompue'));}requetes.clear();};
   ws.onclose=fermerRequetes;ws.onerror=fermerRequetes;
   await cdp('Emulation.setDeviceMetricsOverride',{width:largeur,height:700,deviceScaleFactor:1,mobile:false});
   await cdp('Page.navigate',{url:'http://127.0.0.1:'+port});
   let verdict;
   const limiteVerdict=performance.now()+10000;
   while(performance.now()<limiteVerdict){
    const r=await cdp('Runtime.evaluate',{expression:'document.body?.dataset.verdict',returnByValue:true});
    verdict=r.result?.value;if(verdict)break;await attendre(25);
   }
   if(!verdict)throw Error('HG_CHROMIUM_ASSERTION_TIMEOUT : page chargee sans verdict du scenario');
   const r=await cdp('Runtime.evaluate',{expression:'document.documentElement.outerHTML',returnByValue:true});
   return r.result.value;
 }finally{
  for(const r of requetes.values()){clearTimeout(r.timer);r.reject(Error('HG_CHROMIUM_CDP : fermeture du banc'));}
  requetes.clear();
  if(ws){ws.onerror=()=>{};try{if(ws.readyState<2)ws.close();}catch(_){}}
  try{if(navigateurCDP)await navigateurCDP.arreter();}
  finally{
   serveur.closeAllConnections();
   try{await new Promise((r,j)=>serveur.close(e=>e&&e.code!=='ERR_SERVER_NOT_RUNNING'?j(e):r()));}
   finally{fs.rmSync(profil,{recursive:true,force:true,maxRetries:3});}
  }
 }

}
test('reproduction Chromium de la bulle persistante avec les anciens composants',async()=>{
 const html=await navigateur(true,1280);assert.match(html,/data-verdict="ECHEC"/);assert.match(html,/data-erreur="ancienne bulle persistante"/);
});
for(const w of [1280,390])test(`Chromium ${w}px : transitions, modal, evenement tardif et defilement`,async()=>{
 assert.match(await navigateur(false,w),/data-verdict="OK"/);
});
