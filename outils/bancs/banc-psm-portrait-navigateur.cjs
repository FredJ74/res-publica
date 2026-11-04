// Chromium réel local ; vrai rendu des cartes et du composant avatar du dialogue.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const {chromium}=require('../e2e/node_modules/playwright');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(root,f),'utf8');
function extraire(f,noms){const s=lire(f);return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
for(const largeur of[390,1280])test(`portrait PSM dans présence et composant du dialogue à ${largeur}px`,async()=>{
 const serveur=http.createServer((req,res)=>{
  if(req.url==='/'){res.setHeader('Content-Type','text/html');return res.end('<!doctype html><div id="persons-list"></div><div id="pnj-avatar-container"></div>');}
  if(req.url==='/images/port-sainte-marie-commissariat-brigadier-accueil.webp'){res.setHeader('Content-Type','image/webp');return res.end(fs.readFileSync(path.join(root,req.url)));}
  res.writeHead(404);res.end();
 });
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-psm-portrait-'));let nav,browser;
 try{
  await new Promise((r,j)=>{serveur.once('error',j);serveur.listen(0,'127.0.0.1',r);});
  nav=await lancerChromium({executable:process.env.HG_CHROMIUM||'/usr/bin/chromium',profil});browser=await chromium.connectOverCDP('http://127.0.0.1:'+nav.port);
  const page=await browser.contexts()[0].newPage();await page.setViewportSize({width:largeur,height:700});
  await page.goto('http://127.0.0.1:'+serveur.address().port);
  await page.addScriptTag({content:'var state={country:"republic",currentCity:"ville_a",currentBuilding:"commissariat-local",currentRoom:"accueil_loc",char:null};'+lire('data.js')});
  await page.addScriptTag({content:extraire('plateau-navigation.js',['getBuildingContext'])+'\n'+extraire('plateau-multijoueur.js',['personnesNormalesDeLaPiece','renderPersonsList'])+'\n'+extraire('plateau-pnj.js',['getPnjAvatar'])});
  await page.addScriptTag({content:`var PNJ_AVATAR={policier:{color:'#fff',icon:'ti-user'},default:{color:'#fff',icon:'ti-user'}};
   var marqueurMutinHtml=()=>'',marqueursJudiciairesHtml=()=>'';var appliquerRemplacantCodetenu=p=>p,filtrerPnjPostesPourvus=p=>p,getSimulesPresents=()=>[],getGroupeHtmlPourPiece=()=>'',chargerVraisJoueursPresents=()=>{},encodePnjSafe=p=>encodeURIComponent(JSON.stringify(p));`});
  await page.evaluate(()=>{
   const p=personnesNormalesDeLaPiece('commissariat-local','accueil_loc');renderPersonsList(p);
   document.getElementById('pnj-avatar-container').innerHTML=getPnjAvatar(p[0]);
  });
  await page.waitForFunction(()=>[...document.querySelectorAll('img')].length===2&&[...document.querySelectorAll('img')].every(i=>i.complete&&i.naturalWidth===320));
  const images=await page.locator('img').evaluateAll(xs=>xs.map(x=>({src:x.getAttribute('src'),position:x.style.objectPosition,width:x.naturalWidth,height:x.naturalHeight})));
  assert.equal(images.length,2);for(const i of images){assert.equal(i.src,'images/port-sainte-marie-commissariat-brigadier-accueil.webp');assert.equal(i.position,'50% 35%');assert.equal(i.height,320);}
  assert.match(lire('plateau-pnj.js'),/avatarEl\) avatarEl.innerHTML = avatarHtml/,'le dialogue conserve son composant commun');
 }finally{
  if(browser)await browser.close();if(nav)await nav.arreter();serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});
 }
});
