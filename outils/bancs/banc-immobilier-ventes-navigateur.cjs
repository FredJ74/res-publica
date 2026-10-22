// Chromium reel, nouveau catalogue et CSS reels ; serveur et personnage entierement simules.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const racine=path.resolve(__dirname,'../..');
async function scenario(largeur){
 const acorn=require('../vercel/node_modules/acorn'),ns=fs.readFileSync(path.join(racine,'plateau-rue-centrale.js'),'utf8');
 const navSource=acorn.parse(ns,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&['contexteNavigationRue','contexteNavigationRueValide'].includes(n.id.name)).map(n=>ns.slice(n.start,n.end)).join('\n');
 const source=fs.readFileSync(path.join(racine,'plateau-immobilier-ventes.js'),'utf8');
 const page=`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css"><div id="modal-postes" class="modal-overlay"><div class="modal-box"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div></div><script>
 const state={char:{name:'Fixture'},country:'republic',currentBuilding:'office-notarial',currentRoom:'bureau_contrats',pa:5};
 const WORLD={},BUILDINGS={};const rpAuthUid=()=> 'uid-fictif',rpAuthSessionIdentifiant=()=> 'session-fictive';
 let compteur=0,debits=0,finir;const recus=new Set(),ids=[];const showToast=()=>{};
 const rafraichirRuntimeHelvetia=async()=>({pa:4});const sbImmobilierActeEtat=async()=>({ok:true,termine:false});
 const sbImmobilierCatalogue=async()=>({ok:true,offres:[{id:'fonds',bien_id:'x',actif:'fonds',pays:'republic',ville:'capitale',building_id:'batiment',surface:1200,vendeur:'Vendeur1',prix:'380000',disponible:true,regime:'reference'},{id:'murs',bien_id:'x',actif:'murs',pays:'republic',ville:'capitale',building_id:'batiment',surface:1200,vendeur:'Vendeur2',prix:'180000',disponible:true,regime:'libre_pj'}]});
 const sbImmobilierActe=async(id)=>{compteur++;ids.push(id);if(!recus.has(id)){recus.add(id);debits++;return new Promise(r=>finir=r);}return {ok:true};};
 ${navSource}
 ${source}
 const exiger=(x,t)=>{if(!x)throw Error(t);};
 (async()=>{try{
  await ouvrirCatalogueImmobilier();exiger(document.querySelectorAll('.immobilier-offre').length===3,'trois types d offres');
  exiger(document.body.textContent.includes('560000 FR'),'total conjoint exact visible');
  const murs=[...document.querySelectorAll('article')].find(a=>a.textContent.startsWith('Murs / immobilier'));murs.querySelector('button').click();
  exiger(compteur===0,'preparation sans debit');
  const signer=document.querySelector('#postes-body button');exiger(signer.textContent.includes('Signer'),'consentement explicite');
  signer.click();signer.click();exiger(compteur===1,'double clic bloque');finir({ok:false,transport:{etat:'reseau'}});
  await new Promise(r=>setTimeout(r,20));exiger(sessionStorage.length===1,'identifiant conserve apres perte reponse');
  signer.click();await new Promise(r=>setTimeout(r,30));exiger(compteur===2&&debits===1&&ids[0]===ids[1],'reprise de la meme requete');
  exiger(state.pa===4,'PA relus');exiger(sessionStorage.length===0,'recu confirme nettoye');
  const corps=document.querySelector('.modal-box');exiger(corps.getBoundingClientRect().width<=innerWidth,'catalogue dans la largeur');
  document.body.dataset.verdict='OK';
 }catch(e){document.body.dataset.verdict='ECHEC';document.body.dataset.erreur=e.message;}})();</script>`;
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-immobilier-navigateur-')),demandes=new Map();let nav,ws,id=0;
 const serveur=http.createServer((req,res)=>{res.setHeader('Content-Type',req.url==='/style.css'?'text/css':'text/html');res.end(req.url==='/style.css'?fs.readFileSync(path.join(racine,'style.css')):page);});
 try{
  await new Promise(r=>serveur.listen(0,'127.0.0.1',r));
  nav=await lancerChromium({executable:process.env.CHROMIUM_BIN||'/usr/bin/chromium',profil});
  const pages=await fetch('http://127.0.0.1:'+nav.port+'/json/list').then(r=>r.json());ws=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);
  await new Promise((r,j)=>{const t=setTimeout(()=>j(Error('CDP ouverture non confirmee')),7000);ws.onopen=()=>{clearTimeout(t);r();};ws.onerror=()=>{clearTimeout(t);j(Error('CDP refuse'));};});
  ws.onmessage=e=>{const m=JSON.parse(e.data),q=demandes.get(m.id);if(q){clearTimeout(q.t);demandes.delete(m.id);m.error?q.j(Error(JSON.stringify(m.error))):q.r(m.result);}};
  function cdp(method,params={}){return new Promise((r,j)=>{const n=++id,t=setTimeout(()=>{demandes.delete(n);j(Error('CDP delai '+method));},8000);demandes.set(n,{r,j,t});ws.send(JSON.stringify({id:n,method,params}));});}
  await cdp('Emulation.setDeviceMetricsOverride',{width:largeur,height:700,deviceScaleFactor:1,mobile:false});await cdp('Page.navigate',{url:'http://127.0.0.1:'+serveur.address().port});
  for(let i=0;i<200;i++){nav.controlerProcessus();const r=await cdp('Runtime.evaluate',{expression:'JSON.stringify({verdict:document.body?.dataset.verdict,erreur:document.body?.dataset.erreur})',returnByValue:true});const v=JSON.parse(r.result?.value||'{}');if(v.verdict){assert.equal(v.verdict,'OK',v.erreur);return;}await new Promise(r=>setTimeout(r,25));}
  assert.fail('Page sans verdict : initialisation ou assertions non terminees');
 }finally{
  for(const q of demandes.values()){clearTimeout(q.t);q.j(Error('CDP ferme'));}demandes.clear();if(ws){ws.onerror=()=>{};ws.close();}
  try{if(nav)await nav.arreter();}finally{serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});}
 }
}
for(const largeur of [390,1200])test('catalogue notarial, consentement et reprise en Chromium '+largeur+' px — serveur simule',()=>scenario(largeur));
