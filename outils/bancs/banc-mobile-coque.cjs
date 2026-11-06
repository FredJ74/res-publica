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
function preuve(nom,b){const d=process.env.HG_MOBILE_PREUVES;if(d){fs.mkdirSync(d,{recursive:true});fs.writeFileSync(path.join(d,nom),b);}}
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
 const avant=await a.screenshot(),apres=await n.screenshot();preuve('plateau-1440-avant.png',avant);preuve('plateau-1440-apres.png',apres);assert.ok(apres.equals(avant),'pixels du plateau bureau inchangés');
}));
for(const [w,h] of [[375,667],[393,852],[412,915],[852,393],[768,1024]])test(`L1 : coque ${w}×${h}, panneaux uniques et navigation UI sans RPC`,async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,w,h);await p.evaluate(()=>{window.appels=0;window.fetch=()=>{appels++;throw Error('réseau interdit');};});
 assert.ok((await p.locator('#center').evaluate(e=>e.getBoundingClientRect().width))>=w-1);
 assert.ok(await p.locator('#rue-image').evaluate(e=>e.getBoundingClientRect().width)>100);
 for(const nom of ['personnage','personnes','menu']){await p.locator(`[data-hg-panneau=${nom}]`).click();assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),nom);assert.equal(await p.locator(`[data-hg-panneau=${nom}]`).getAttribute('aria-expanded'),'true');await p.keyboard.press('Escape');assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),null);}
 assert.equal(await p.locator('#left').count(),1);assert.equal(await p.evaluate(()=>appels),0);
 await p.locator('[data-hg-panneau=menu]').click();if(w===375)preuve('mobile-375-menu.png',await p.screenshot());await p.locator('#hg-menu-existant .forum-btn').first().evaluate(e=>e.removeAttribute('onclick'));await p.locator('#hg-menu-existant .forum-btn').first().click();assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),null);
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
 assert.equal(await p.locator('#audit-saisie').evaluate(e=>getComputedStyle(e).fontSize),'16px');preuve('mobile-375-hauteur-350.png',await p.screenshot());
 await p.locator('#audit-fin').focus();await p.keyboard.press('Tab');assert.ok(await p.locator('#modal-postes .modal-close').evaluate(e=>e===document.activeElement));
 await p.keyboard.press('Escape');assert.equal(await p.locator('#modal-postes').evaluate(e=>e.classList.contains('open')),false);
 assert.ok(await p.locator('[data-hg-panneau=menu]').evaluate(e=>e===document.activeElement));
}));
test('L3 : chat paysage contenu dans l’écran, fenêtres au-dessus des flèches',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,852,393);await p.evaluate(()=>{document.getElementById('chat-piece-panel').style.display='flex';});
 assert.ok(await p.locator('#chat-piece-panel').evaluate(e=>e.getBoundingClientRect().top>=0));
 await p.evaluate(()=>{document.getElementById('chat-piece-panel').style.display='none';const scene=document.createElement('div');scene.className='rc-scene';scene.style.height='180px';scene.innerHTML='<div class="rc-fleche" style="left:30px;top:20px">Flèche fixture</div>';document.getElementById('rue-image').append(scene);document.getElementById('modal-postes').classList.add('open');});
 const point=await p.locator('.rc-fleche').evaluate(e=>{const r=e.getBoundingClientRect();return{x:r.x+20,y:r.y+20};});
 assert.equal(await p.evaluate(p=>document.elementFromPoint(p.x,p.y).closest('.modal-overlay')?.id,point),'modal-postes','la flèche ne traverse pas une fenêtre');
}));
async function surface(p,ancien=false){
 await p.addScriptTag({content:lecture('forum-canvas.js',ancien).toString()});
 await p.evaluate(()=>{const s=document.createElement('div');s.id='surface-audit';s.style.cssText='position:fixed;left:0;top:0;width:350px;height:300px;z-index:2000;background:white';const el=document.createElement('div');el.id='objet-audit';el.style.cssText='position:absolute;left:20px;top:20px;width:100px;height:100px;background:gray';s.append(el);document.body.append(s);window.etatObjet={x:20,y:20,width:100,height:100,minHeight:100};window.controleurAudit=rpCanvasCreateController(s);controleurAudit.attachDrag(el,etatObjet,el);});
}
async function gesteTouch(p){const cd=await p.context().newCDPSession(p);for(const [type,touchPoints] of [['touchStart',[{x:50,y:50}]],['touchMove',[{x:110,y:110}]],['touchEnd',[]]])await cd.send('Input.dispatchTouchEvent',{type,touchPoints});await cd.detach();}
test('L6 contre-épreuve : ancien contrôleur immobile au toucher, contrôleur corrigé mobile et souris',async()=>avecJeu(async(b,o)=>{
 const ancien=await page(b,o,375,667);await surface(ancien,true);await gesteTouch(ancien);assert.equal(await ancien.evaluate(()=>etatObjet.x),20,'ancien défaut réellement reproduit');
 const p=await page(b,o,375,667);await surface(p);await gesteTouch(p);assert.equal(await p.evaluate(()=>etatObjet.x),80);assert.equal(await p.evaluate(()=>etatObjet.y),80);
 await p.mouse.move(110,110);await p.mouse.down();await p.mouse.move(150,150);await p.mouse.up();assert.equal(await p.evaluate(()=>etatObjet.x),120,'souris toujours opérationnelle');
}));
test('L6 : resize, pointeur étranger, annulation et perte de focus ne laissent aucun geste actif',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await surface(p);
 await p.evaluate(()=>{const e=document.getElementById('objet-audit');controleurAudit.attachCornerResize(e,'se',etatObjet,e);e.dispatchEvent(new PointerEvent('pointerdown',{pointerId:7,clientX:50,clientY:50,button:0,isPrimary:true,bubbles:true}));document.dispatchEvent(new PointerEvent('pointermove',{pointerId:8,clientX:200,clientY:200}));});
 assert.equal(await p.evaluate(()=>etatObjet.width),100,'un autre doigt ne redimensionne pas');
 await p.evaluate(()=>document.dispatchEvent(new PointerEvent('pointermove',{pointerId:7,clientX:100,clientY:100})));assert.equal(await p.evaluate(()=>etatObjet.width),150);
 await p.evaluate(()=>{document.dispatchEvent(new PointerEvent('pointercancel',{pointerId:7}));document.dispatchEvent(new PointerEvent('pointermove',{pointerId:7,clientX:200,clientY:200}));});assert.equal(await p.evaluate(()=>etatObjet.width),150,'cancel enlève les écouteurs');
 await p.evaluate(()=>{document.getElementById('objet-audit').dispatchEvent(new PointerEvent('pointerdown',{pointerId:9,clientX:50,clientY:50,button:0,isPrimary:true,bubbles:true}));window.dispatchEvent(new Event('blur'));document.dispatchEvent(new PointerEvent('pointermove',{pointerId:9,clientX:200,clientY:200}));});assert.equal(await p.evaluate(()=>etatObjet.width),150,'blur enlève les écouteurs');
}));
async function forumFixture(p){await p.evaluate(()=>{document.getElementById('forum-body').innerHTML='<div class="forum-layout"><div class="forum-sidebar">'+Array.from({length:15},(_,i)=>'<button>Rubrique '+i+'</button>').join('')+'</div><div class="forum-main" id="forum-main"><div class="forum-topics-header"><span>Sujet</span><span>Auteur</span><span>Dernier</span><span>Vues</span><span>Réponses</span></div><div class="forum-topic-row"><span>Sujet local</span><span>Auteur</span><span>Hier</span><span>10</span><span>2</span></div><div class="forum-post"><div class="forum-post-side">Auteur</div><div class="forum-post-main">Réponse</div></div></div></div>';document.getElementById('modal-forum').classList.add('open');});await p.waitForTimeout(500);}
test('L6 : rubriques, liste et lecture sans débordement mobile ; bureau forum 1440 identique',async()=>avecJeu(async(b,o)=>{
 for(const w of [375,393,412,768,852]){const p=await page(b,o,w,w===852?393:852);await forumFixture(p);assert.ok(await p.locator('#forum-main').evaluate(e=>e.scrollWidth<=e.clientWidth+1));assert.ok(await p.locator('#forum-main').evaluate(e=>e.clientHeight>60));if(w===375)preuve('mobile-375-forum.png',await p.screenshot());await p.close();}
 const ancien=await page(b,o,1440,900,true);await ancien.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));await ancien.addStyleTag({content:lecture('style.css',true).toString()});const n=await page(b,o,1440,900);await forumFixture(ancien);await forumFixture(n);const avant=await ancien.screenshot(),apres=await n.screenshot();preuve('forum-1440-avant.png',avant);preuve('forum-1440-apres.png',apres);assert.ok(avant.equals(apres),'forum bureau identique pixel pour pixel');
}));
test('L6 : boutons historiques et champs dans une poignée ne déclenchent pas de déplacement',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await surface(p);await p.evaluate(()=>{window.commandesToolbar=0;const b=document.createElement('button');b.textContent='Dupliquer fixture';b.id='toolbar-fixture';b.addEventListener('mousedown',()=>commandesToolbar++);document.getElementById('objet-audit').append(b);});
 await p.locator('#toolbar-fixture').tap();assert.equal(await p.evaluate(()=>commandesToolbar),1);assert.equal(await p.evaluate(()=>etatObjet.x),20);await p.locator('#toolbar-fixture').click();assert.equal(await p.evaluate(()=>commandesToolbar),2);assert.equal(await p.evaluate(()=>etatObjet.x),20);
}));
test('L5 : inventaire long et tableau financier restent consultables sans mutation',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await p.evaluate(()=>{document.getElementById('postes-body').innerHTML='<div class="char-sheet-grid"><section class="cs-section">Liquide : 0 FR</section><section class="cs-section">Banque : 15000 FR</section></div><div class="hg-inventaire-ligne"><div>Objet</div><div><div class="hg-inventaire-nom">Un objet avec un intitulé particulièrement long et une quantité confirmée</div></div><button>Déposer</button><button>Détruire</button></div><table style="width:900px"><tbody>'+Array.from({length:100},(_,i)=>'<tr><td>Objet '+i+'</td><td>0 FR</td></tr>').join('')+'</tbody></table>';document.getElementById('modal-postes').classList.add('open');});
 await p.waitForTimeout(100);assert.equal(await p.locator('.hg-table-defilante').count(),1);assert.equal(await p.locator('tr').count(),100);assert.equal(await p.locator('.cs-section').first().innerText(),'Liquide : 0 FR');assert.equal(await p.locator('.cs-section').last().innerText(),'Banque : 15000 FR');assert.ok(await p.locator('.hg-table-defilante').evaluate(e=>e.clientWidth<=innerWidth));await p.setViewportSize({width:1440,height:900});await p.waitForTimeout(100);assert.equal(await p.locator('.hg-table-defilante').count(),0,'DOM bureau restauré');assert.equal(await p.locator('tr').count(),100);
}));
