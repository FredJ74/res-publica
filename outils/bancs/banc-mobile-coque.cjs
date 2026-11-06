// HTML/CSS et présentation réels ; aucun serveur de jeu, identité ou ordre.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {execFileSync}=require('node:child_process');
const {chromium}=require('../e2e/node_modules/playwright');
const R=path.resolve(__dirname,'../..'),base='728010c8';
const lecture=(f,ancien)=>ancien?execFileSync('git',['show',base+':'+f],{cwd:R}):fs.readFileSync(path.join(R,f));
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
test('L2 : lieux tactiles et clavier réutilisent le clic existant, une seule fois',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);
 await p.evaluate(()=>{window.entrees=0;const scene=document.createElement('div');scene.id='rc-scene';const zone=document.createElement('div');zone.className='rc-zone';zone.setAttribute('aria-label','Lieu de test');zone.tabIndex=0;zone.onclick=()=>entrees++;scene.append(zone);document.getElementById('rue-image').append(scene);});
 await p.locator('.hg-lieux-tactiles summary').click();await p.locator('.hg-lieux-tactiles button').click();assert.equal(await p.evaluate(()=>entrees),1);
 await p.locator('.rc-zone').focus();await p.keyboard.press('Enter');assert.equal(await p.evaluate(()=>entrees),2);
 await p.evaluate(()=>{document.getElementById('rc-scene').remove();});await p.locator('.hg-lieux-tactiles button').click();assert.equal(await p.evaluate(()=>entrees),2,'une scène périmée ne déplace personne');
}));
test('L2 : pièces et actions accessibles en paysage',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,852,393);await p.evaluate(()=>{document.getElementById('vue-rue').classList.remove('active');document.getElementById('vue-batiment').classList.add('active');document.getElementById('pieces-tabs').innerHTML=Array.from({length:8},(_,i)=>'<button class="piece-tab">Pièce '+i+'</button>').join('');});
 await p.locator('.piece-tab').last().scrollIntoViewIfNeeded();await p.locator('.piece-tab').last().click();assert.ok(await p.locator('#piece-image').evaluate(e=>e.getBoundingClientRect().width)>800);
 await p.locator('#vue-batiment .sortir-btn').scrollIntoViewIfNeeded();assert.ok(await p.locator('#vue-batiment .sortir-btn').isVisible());
}));
test('L3 : longue modale, focus, fermeture existante et retour sans action métier',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);
 await p.locator('[data-hg-panneau=menu]').focus();
 await p.evaluate(()=>{const m=document.getElementById('modal-postes');m.querySelector('.modal-close').onclick=()=>m.classList.remove('open');document.getElementById('postes-body').innerHTML='<div class="cpj-dialogue">'+('<p>Lecture</p>'.repeat(40))+'<input id="audit-saisie"><button id="audit-fin">Fin</button></div>';m.classList.add('open');});
 await p.waitForTimeout(100);assert.ok(await p.locator('#modal-postes .modal-box').getAttribute('aria-modal'));
 await p.locator('#audit-saisie').focus();await p.setViewportSize({width:375,height:350});await p.waitForTimeout(150);assert.ok(await p.locator('#modal-postes .modal-box').evaluate(e=>e.getBoundingClientRect().bottom<=innerHeight));
 assert.equal(await p.locator('#audit-saisie').evaluate(e=>getComputedStyle(e).fontSize),'16px');
 await p.locator('#audit-fin').focus();await p.keyboard.press('Tab');assert.ok(await p.locator('#modal-postes .modal-close').evaluate(e=>e===document.activeElement));
 await p.keyboard.press('Escape');assert.equal(await p.locator('#modal-postes').evaluate(e=>e.classList.contains('open')),false);
 assert.ok(await p.locator('[data-hg-panneau=menu]').evaluate(e=>e===document.activeElement));
}));
test('L3 : chat paysage contenu dans l’écran, fenêtres au-dessus des flèches',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,852,393);await p.evaluate(()=>{document.getElementById('chat-piece-panel').style.display='flex';});
 assert.ok(await p.locator('#chat-piece-panel').evaluate(e=>e.getBoundingClientRect().top>=0));
}));
