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
test('L5 : inventaire long et tableau financier restent consultables sans mutation',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await p.evaluate(()=>{document.getElementById('postes-body').innerHTML='<div class="char-sheet-grid"><section class="cs-section">Liquide : 0 FR</section><section class="cs-section">Banque : 15000 FR</section></div><div class="hg-inventaire-ligne"><div>Objet</div><div><div class="hg-inventaire-nom">Un objet avec un intitulé particulièrement long et une quantité confirmée</div></div><button>Déposer</button><button>Détruire</button></div><table style="width:900px"><tbody>'+Array.from({length:100},(_,i)=>'<tr><td>Objet '+i+'</td><td>0 FR</td></tr>').join('')+'</tbody></table>';document.getElementById('modal-postes').classList.add('open');});
 await p.waitForTimeout(100);assert.equal(await p.locator('.hg-table-defilante').count(),1);assert.equal(await p.locator('tr').count(),100);assert.equal(await p.locator('.cs-section').first().innerText(),'Liquide : 0 FR');assert.equal(await p.locator('.cs-section').last().innerText(),'Banque : 15000 FR');assert.ok(await p.locator('.hg-table-defilante').evaluate(e=>e.clientWidth<=innerWidth));await p.setViewportSize({width:1440,height:900});await p.waitForTimeout(100);assert.equal(await p.locator('.hg-table-defilante').count(),0,'DOM bureau restauré');assert.equal(await p.locator('tr').count(),100);
}));
test('L8 : retour, panne et deux appareils bloquent le premier ordre sans le rejouer',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await p.evaluate(()=>{window.ordres=0;window.lectures=0;window.loadCharacter=async()=>{lectures++;return true;};const b=document.createElement('button');b.id='ordre-fixture';b.style.cssText='position:fixed;left:20px;top:120px;z-index:30';b.textContent='Ordre';b.onclick=()=>ordres++;document.body.append(b);window.dispatchEvent(new StorageEvent('storage',{key:'respublica_char_Fixture'}));});
 await p.locator('#ordre-fixture').click();await p.waitForTimeout(60);assert.equal(await p.evaluate(()=>ordres),0);assert.equal(await p.evaluate(()=>lectures),1);await p.locator('#ordre-fixture').click();assert.equal(await p.evaluate(()=>ordres),1);
 await p.evaluate(()=>{window.loadCharacter=async()=>false;window.dispatchEvent(new Event('offline'));});await p.context().setOffline(true);await p.waitForTimeout(60);await p.locator('#ordre-fixture').click();assert.equal(await p.evaluate(()=>ordres),1);assert.ok(await p.locator('#hg-reprise').isVisible());
 await p.evaluate(()=>{window.loadCharacter=async()=>new Promise(r=>window.finReprise=r);});await p.context().setOffline(false);await p.waitForTimeout(100);await p.locator('#ordre-fixture').click();assert.equal(await p.evaluate(()=>ordres),1);await p.evaluate(()=>finReprise(true));await p.waitForTimeout(60);assert.equal(await p.locator('#hg-reprise').isVisible(),false);assert.equal(await p.evaluate(()=>ordres),1);
}));
test('L4 : création réelle dans les six langues, explications et caractéristiques conservées',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);const html=fs.readFileSync(path.join(R,'index.html'),'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');await p.setContent(html);
 for(const f of ['i18n/i18next.min.js','i18n/resources.js','i18n/i18n-init.js','data.js','creation.js'])await p.addScriptTag({url:o+'/'+f});
 await p.evaluate(()=>{G.country='republic';G.name='Fixture mobile';});
 for(const langue of ['fr','en','es','zh-TW','ru','ko']){await p.evaluate(l=>changerLangueRP(l),langue);await p.evaluate(()=>{goTo(0);document.getElementById('connexion-panel').style.display='none';ouvrirConnexionCompte();});assert.ok(await p.locator('#connexion-email').isVisible());for(const n of [1,2,3,4,5,7,8])await p.evaluate(n=>goTo(n),n);await p.evaluate(()=>goTo(6));assert.equal(await p.locator('.srow').count(),6);assert.equal(await p.locator('.sex').count(),6,'explications En jeu conservées');assert.ok(await p.locator('.sbtn').first().evaluate(e=>e.getBoundingClientRect().width>=44));const avant=await p.evaluate(()=>({...G.freeStats}));await p.locator('.sbtn').nth(1).click();assert.notDeepEqual(await p.evaluate(()=>({...G.freeStats})),avant);await p.locator('.sbtn').first().click();assert.deepEqual(await p.evaluate(()=>({...G.freeStats})),avant);assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));}
 await p.setViewportSize({width:1440,height:900});await p.waitForTimeout(500);const apres=await p.screenshot();await p.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));await p.addStyleTag({content:temoin.fichiers['style.css']});await p.waitForTimeout(500);assert.ok(apres.equals(await p.screenshot()),'création bureau 1440 identique');
}));
test('L7 : rapport et décisions réels respectent les droits fournis par le serveur',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);const acorn=require('../vercel/node_modules/acorn'),s=fs.readFileSync(path.join(R,'plateau-politique.js'),'utf8');const arbre=acorn.parse(s,{ecmaVersion:'latest'});const js=arbre.body.filter(n=>n.type==='FunctionDeclaration'&&['ouvrirPanneauCombat','htmlDecisionsCombat'].includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');
 await p.addScriptTag({content:`window.contexteGroupePj=()=>({});window.contexteGroupePjValide=()=>true;window.escapeHtmlText=s=>String(s);window.showToast=()=>{};window.fixtureCombat={id:1,statut:'en_cours',contrat_combat:2,round_courant:5,peut_decider:false,rounds:[{round:5,mes_pa_perdus:0,adversaires_tombes:0}],lieu:{ville:'Fixture'},mon_effectif_actuel:3,mon_effectif_initial:3};window.sbMilitaireBatailleEtat=async()=>({ok:true,bataille:fixtureCombat});`+js});
 await p.evaluate(()=>ouvrirPanneauCombat(1));assert.equal(await p.locator('#postes-body button').count(),1);assert.match(await p.locator('#postes-body').innerText(),/chef conserve/);assert.doesNotMatch(await p.locator('#postes-body').innerHTML(),/deciderCombat/);
 await p.evaluate(()=>{fixtureCombat.peut_decider=true;return ouvrirPanneauCombat(1);});assert.equal(await p.locator('#postes-body button').count(),3);assert.ok(await p.locator('.hg-rapport-combat').evaluate(e=>e.scrollWidth<=e.clientWidth+1));await p.evaluate(()=>{fixtureCombat.mon_groupe_replie=true;return ouvrirPanneauCombat(1);});assert.equal(await p.locator('#postes-body button').count(),0);
}));
test('L9 : portraits réels différés dans le panneau fermé puis demandés à son ouverture',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667),demandes=[];p.on('request',r=>{if(r.url().includes('portrait-fixture'))demandes.push(r.url());});
 const acorn=require('../vercel/node_modules/acorn'),s=fs.readFileSync(path.join(R,'plateau-multijoueur.js'),'utf8');const n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='renderPersonsList');
 await p.addScriptTag({content:`var state={country:'republic',currentCity:'capitale',currentBuilding:'fixture',char:null};var ARCHETYPES=[],PNJ_AVATAR={default:{}},COUNTRIES={republic:{}},RP_STATUTS_JUDICIAIRES={};var appliquerRemplacantCodetenu=x=>x,filtrerPnjPostesPourvus=x=>x,getSimulesPresents=()=>[],getGroupeHtmlPourPiece=()=>'',chargerVraisJoueursPresents=()=>{},encodePnjSafe=p=>encodeURIComponent(JSON.stringify(p)),marqueurMutinHtml=()=>'',marqueursJudiciairesHtml=()=>'';`+s.slice(n.start,n.end)});
 await p.evaluate(()=>{document.getElementById('vue-rue').classList.remove('active');document.getElementById('vue-batiment').classList.add('active');renderPersonsList(Array.from({length:20},(_,i)=>({name:'Fixture '+i,job:'default',role:'Personne',photoUrl:'/portrait-fixture-'+i+'.webp'})));});await p.waitForTimeout(150);assert.equal(demandes.length,0,'aucune image de ce panneau fermé demandée');assert.equal(await p.locator('#persons-list img[loading=lazy]').count(),20);await p.locator('[data-hg-panneau=personnes]').click();await p.waitForTimeout(500);assert.ok(demandes.length>0,'les images deviennent éligibles à leur affichage');
}));
