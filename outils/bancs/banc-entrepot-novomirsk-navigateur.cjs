// Chromium réel ; rendu/navigation communs, serveur et personnage fictifs explicitement.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const {chromium}=require('../e2e/node_modules/playwright'),{lancerChromium}=require('./fixtures/chromium-cdp.cjs'),acorn=require('../vercel/node_modules/acorn');
const R=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(R,f),'utf8');
function extrait(f,noms){const s=lire(f);return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
for(const width of[390,1280])test('Novomirsk : vraie rue, onglets et catalogue à '+width+'px',async()=>{
 const html='<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/rue-centrale.css"><div id="rue-centrale-conteneur"></div><div id="vue-batiment"></div><div id="pieces-tabs"></div><div id="modal-postes"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div>';
 const allowed=['/rue-centrale.css','/images/rue-entrepot-renseignement-novomirsk.webp'];const server=http.createServer((req,res)=>{
  if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end(html);return;}
  if(!allowed.includes(req.url)){res.writeHead(404);res.end();return;}res.setHeader('Content-Type',req.url.endsWith('.css')?'text/css':'image/webp');res.end(fs.readFileSync(path.join(R,req.url)));
 });let nav,browser;const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-novom-chrome-'));
 try{
  await new Promise((r,j)=>{server.once('error',j);server.listen(0,'127.0.0.1',r);});nav=await lancerChromium({executable:process.env.HG_CHROMIUM||'/usr/bin/chromium',profil});browser=await chromium.connectOverCDP('http://127.0.0.1:'+nav.port);
  const page=await browser.contexts()[0].newPage();await page.setViewportSize({width,height:800});await page.goto('http://127.0.0.1:'+server.address().port);
  await page.addScriptTag({content:'var state={country:"soviet",currentCity:"capitale",currentRoom:null,currentBuilding:null,char:{name:"Fixture"}};'+lire('data.js')});
  await page.addScriptTag({content:lire('plateau-rue-centrale.js')});
  await page.addScriptTag({content:extrait('plateau-navigation.js',['getBuildingContext','renderOngletsPieces'])+'\n'+extrait('plateau-justice-economie.js',['doOuvrirAchatEntrepot'])});
  await page.evaluate(async()=>{
   window.enterBuilding=id=>{window.entreeObservee=id;state.currentBuilding=id;state.currentRoom='accueil';document.getElementById('vue-batiment').classList.add('active');renderOngletsPieces(id,'accueil');};
   // Le mouvement serveur n'est pas exécuté : on observe le raccordement au moteur.
   window.enterRoom=(id,room)=>{window.pieceObservee=room;};
   window.sbGetBatimentEtat=async(p,v,b)=>{if(p!=='soviet'||v!=='capitale'||b!=='entrepot-logistique-novomirsk')throw Error('mauvais entrepôt');return{entrepot:{stock:{bois:5},prixManuel:{bois:6}}};};
   await afficherNoeudRue('soviet','novomirsk-vue-8',null,true);await document.getElementById('rc-image').decode();
  });
  assert.equal(await page.locator('#rc-image').getAttribute('src'),'images/rue-entrepot-renseignement-novomirsk.webp');
  await page.locator('.rc-zone').first().click();await page.waitForFunction(()=>window.entreeObservee==='entrepot-logistique-novomirsk');
  assert.deepEqual(await page.locator('.piece-tab').evaluateAll(xs=>xs.map(x=>x.dataset.piece)),['accueil','salle_ventes','bureau_direction']);
  await page.locator('[data-piece="salle_ventes"]').click();assert.equal(await page.evaluate(()=>window.pieceObservee),'salle_ventes');
  await page.evaluate(async()=>{state.currentRoom='salle_ventes';await doOuvrirAchatEntrepot(0,0);});
  assert.equal(await page.locator('#achat-entrepot-bois').getAttribute('max'),'5');assert.equal(await page.locator('#achat-entrepot-minerai').isDisabled(),true);
  assert.equal(await page.evaluate(()=>trouverNoeudRueCentralePourBatiment('soviet','entrepot-logistique-novomirsk')),'novomirsk-vue-8');
 }finally{
  try{if(browser)await browser.close();}finally{try{if(nav)await nav.arreter();}finally{server.closeAllConnections();await new Promise(r=>server.close(r));fs.rmSync(profil,{recursive:true,force:true});}}
 }
});
