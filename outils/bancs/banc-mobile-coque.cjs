// HTML/CSS et présentation réels ; aucun serveur de jeu, identité ou ordre.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const zlib=require('node:zlib'),crypto=require('node:crypto');
const {chromium}=require('../e2e/node_modules/playwright');
const R=path.resolve(__dirname,'../..');
const reference=fs.readFileSync(path.join(__dirname,'fixtures/mobile-temoin-728010c8.json.gz'));
assert.equal(crypto.createHash('sha256').update(reference).digest('hex'),'7d79fac32ee8d3059505c494b18ccc958199698478b9702fc7d7017717f52d3c');
const temoin=JSON.parse(zlib.gunzipSync(reference));
assert.equal(temoin.commit,'728010c844597087e7c4063f72fabbcb2a746723');
const lecture=(f,ancien)=>ancien?Buffer.from(temoin.fichiers[f]):fs.readFileSync(path.join(R,f));
async function avecJeu(f){
 const serveur=http.createServer((q,r)=>{let u=new URL(q.url,'http://localhost');let nom=u.pathname.slice(1),ancien=u.searchParams.has('ancien');
 try{let b=lecture(nom,ancien);if(nom==='plateau.html')b=Buffer.from(b.toString().replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,''));r.setHeader('Content-Type',nom.endsWith('.css')?'text/css':nom.endsWith('.js')?'text/javascript':'text/html');r.end(b);}catch{r.writeHead(404);r.end();}});
 await new Promise(r=>serveur.listen(0,'127.0.0.1',r));const origine='http://127.0.0.1:'+serveur.address().port;
 let b;try{b=await chromium.launch({executablePath:process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync),args:['--no-sandbox']});await f(b,origine);}finally{if(b)await b.close();serveur.closeAllConnections();await new Promise(r=>serveur.close(r));}
}
async function page(b,o,w,h,ancien=false){const c=await b.newContext({viewport:{width:w,height:h},hasTouch:w<1024});await c.route('**/*',r=>r.request().url().startsWith(o+'/')?r.continue():r.abort());const p=await c.newPage();p.setDefaultTimeout(5000);await p.goto(o+'/plateau.html'+(ancien?'?ancien':''));if(ancien){await p.addStyleTag({content:lecture('style.css',true).toString()});}else await p.addScriptTag({url:o+'/plateau-mobile.js'});await p.waitForTimeout(500);return p;}
test('L1 : bureau 1440 strictement identique au témoin avant mobile',async()=>avecJeu(async(b,o)=>{
 const a=await page(b,o,1440,900,true),n=await page(b,o,1440,900);
 // Le témoin doit remplacer, pas compléter, la feuille courante.
 await a.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));await a.addStyleTag({content:lecture('style.css',true).toString()});await a.addStyleTag({content:lecture('rue-centrale.css',true).toString()});await a.waitForTimeout(400);
 assert.ok((await n.screenshot()).equals(await a.screenshot()),'pixels du plateau bureau inchangés');
}));
for(const [w,h] of [[375,667],[393,852],[412,915],[852,393],[768,1024]])test(`L1 : coque ${w}×${h}, panneaux uniques et navigation UI sans RPC`,async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,w,h);await p.evaluate(()=>{window.appels=0;window.fetch=()=>{appels++;throw Error('réseau interdit');};});
 assert.ok((await p.locator('#center').evaluate(e=>e.getBoundingClientRect().width))>=w-1);
 assert.ok(await p.locator('#rue-image').evaluate(e=>e.getBoundingClientRect().width)>100);
 for(const nom of ['personnage','personnes','menu']){await p.locator(`[data-hg-panneau=${nom}]`).click();assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),nom);assert.equal(await p.locator(`[data-hg-panneau=${nom}]`).getAttribute('aria-expanded'),'true');await p.keyboard.press('Escape');assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),null);}
 assert.equal(await p.locator('#left').count(),1);assert.equal(await p.evaluate(()=>appels),0);
 await p.locator('[data-hg-panneau=menu]').click();await p.locator('#hg-menu-existant .forum-btn').first().evaluate(e=>e.removeAttribute('onclick'));await p.locator('#hg-menu-existant .forum-btn').first().click();assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),null);
}));
