// HTML/CSS et présentation réels ; aucun serveur de jeu, identité ou ordre.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {R,temoin,lecture,preuve,avecJeu,page}=require('./mobile-navigateur.cjs');
// Témoin de l'épreuve L1 (bureau 1440), renouvelé le 22/11/2026 : témoin 728010c8-human-gambit dont seuls le bloc HTML
// « PA / Santé / Moral + Argent » et le bloc CSS des jauges sont repris de main (GAME-DESIGN-SANTE-20261122.md, point 14 ;
// différence vérifiée sur capture, bureau et mobile). Renouvelé le 23/11/2026 : le bloc <div id="left"> (panneau de gauche refait,
// GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 16 à 19) et le bloc CSS des jauges sont repris de main ; puis le journal et le chat (points 21 et 22).
// Renouvelé le 24/11/2026 (mission Purge A.6) : jauge des PA et lien « Plus d'informations sur les PA ? » (bloc Ligne 1 → LOCATION
// de plateau.html, règles #hg-jauge-pa et .hg-pa-infos de style.css), repris de la branche.
// Il est servi tel quel : aucune injection, aucun masque, aucune tolérance.
const zlibL1=require('node:zlib'),cryptoL1=require('node:crypto');
const archiveL1=fs.readFileSync(path.join(__dirname,'fixtures/mobile-coque-l1-temoin-728010c8-jauges-20261122.json.gz'));
assert.equal(cryptoL1.createHash('sha256').update(archiveL1).digest('hex'),'9c3df59617569c7fd117499f4e5ce14adf324d1b089629f1998cdaa36b2f117a');
const temoinL1=JSON.parse(zlibL1.gunzipSync(archiveL1));
assert.equal(temoinL1.commit,temoin.commit);
async function pageTemoinL1(b,o){
 const c=await b.newContext({viewport:{width:1440,height:900},hasTouch:false});
 await c.route('**/*',r=>{const url=new URL(r.request().url());if(url.origin!==o)return r.abort();
  if(url.pathname==='/plateau.html')return r.fulfill({contentType:'text/html',body:temoinL1.fichiers['plateau.html'].replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'')});
  return r.continue();});
 const p=await c.newPage();p.setDefaultTimeout(5000);await p.goto(o+'/plateau.html');
 await p.addStyleTag({content:temoinL1.fichiers['style.css']});await p.waitForTimeout(500);return p;
}
// Le libellé « Règles » est devenu « Aide » (aide HRP, PR #720) : texte voulu, sans rapport avec le CSS mobile
// que ces comparaisons surveillent. On l'aligne sur les deux pages avant la capture.
// De même, le bouton « Se déconnecter » du menu (PR #1067, voulu, absent du témoin 728010c) est retiré avant capture.
const memeLibelleAide=async p=>{await p.waitForTimeout(300);await p.evaluate(()=>{const b=document.querySelector('button[onclick="openRulesView()"]');const e=b&&(b.querySelector('span')||b);if(e)e.textContent='Aide';document.getElementById('rp-logout-player')?.remove();});};
// Depuis ce8f4eb (en-tête mobile compact, 17/11/2026), le bouton « Personnage » est masqué sur mobile :
// la bannière d'identité #hg-mobile-brand (plateau-mobile-entete-compact.js) l'actionne, et la sortie du
// bâtiment passe par #hg-mobile-exit. On charge donc ces deux modules comme plateau.html (même ordre).
// Depuis 4701f27b (17/11/2026), la rangée des pièces passe dans l'onglet « Pièces » (plateau-interieurs-mobile.js).
const ENTETE_MOBILE=['plateau-mobile-identite-20261117.js','plateau-mobile-entete-compact.js','plateau-interieurs-mobile.js'];
const pageMobile=async(b,o,w,h)=>{const p=await page(b,o,w,h);for(const f of ENTETE_MOBILE)await p.addScriptTag({url:o+'/'+f});await p.waitForTimeout(200);return p;};
const ACCES={personnage:'#hg-mobile-brand',menu:'[data-hg-panneau=menu]'};
test('L1 : bureau 1440 strictement identique au témoin avant mobile',async()=>avecJeu(async(b,o)=>{
 const a=await pageTemoinL1(b,o),n=await page(b,o,1440,900);
 // Le témoin doit remplacer, pas compléter, la feuille courante.
 await a.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));await a.addStyleTag({content:temoinL1.fichiers['style.css']});await a.addStyleTag({content:temoinL1.fichiers['rue-centrale.css']});await a.waitForTimeout(400);await memeLibelleAide(a);await memeLibelleAide(n);
 const avant=await a.screenshot(),apres=await n.screenshot();preuve('plateau-1440-avant.png',avant);preuve('plateau-1440-apres.png',apres);assert.ok(apres.equals(avant),'pixels du plateau bureau inchangés');
}));
for(const [w,h] of [[375,667],[393,852],[412,915],[852,393],[768,1024]])test(`L1 : coque ${w}×${h}, panneaux uniques et navigation UI sans RPC`,async()=>avecJeu(async(b,o)=>{
 const p=await pageMobile(b,o,w,h);await p.evaluate(()=>{window.appels=0;window.fetch=()=>{appels++;throw Error('réseau interdit');};});
 assert.ok((await p.locator('#center').evaluate(e=>e.getBoundingClientRect().width))>=w-1);
 // Depuis #1059, #rue-image est display:contents sur mobile (ses enfants deviennent des frères flex de #vue-rue) :
 // sa boîte vaut 0 par construction ; c'est la vue rue qui doit occuper toute la largeur.
 assert.equal(await p.locator('#rue-image').evaluate(e=>getComputedStyle(e).display),'contents');
 assert.ok(await p.locator('#vue-rue').evaluate(e=>e.getBoundingClientRect().width)>=w-1);
 // Depuis #1063, en vue rue, le bouton « Présents » est masqué : le bandeau horizontal des présents le remplace.
 assert.equal(await p.locator('[data-hg-panneau=personnes]').isVisible(),false);
 // Un seul accès visible au personnage : la bannière d'identité ; l'ancien bouton reste dans le DOM (masqué).
 assert.equal(await p.locator('[data-hg-panneau=personnage]').isVisible(),false);assert.ok(await p.locator('#hg-mobile-brand').isVisible());
 for(const nom of ['personnage','menu']){await p.locator(ACCES[nom]).click();assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),nom);assert.equal(await p.locator(`[data-hg-panneau=${nom}]`).getAttribute('aria-expanded'),'true');await p.keyboard.press('Escape');assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),null);}
 assert.equal(await p.locator('#left').count(),1);assert.equal(await p.evaluate(()=>appels),0);
 await p.locator('[data-hg-panneau=menu]').click();if(w===375)preuve('mobile-375-menu.png',await p.screenshot());await p.locator('#hg-menu-existant .forum-btn').first().evaluate(e=>e.removeAttribute('onclick'));await p.locator('#hg-menu-existant .forum-btn').first().click();assert.equal(await p.locator('body').getAttribute('data-mobile-panel'),null);
}));
test('L2 : pas de panneau Lieux visibles, zones et clavier actifs',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);
 // Structure réelle de plateau-rue-centrale.js : #rue-centrale-conteneur > .rc-scene > image + zones positionnées en %.
 await p.evaluate(()=>{window.entrees=0;const conteneur=document.createElement('div');conteneur.id='rue-centrale-conteneur';const scene=document.createElement('div');scene.id='rc-scene';scene.className='rc-scene';const photo=document.createElement('div');photo.style.height='200px';const zone=document.createElement('div');zone.className='rc-zone';zone.setAttribute('aria-label','Lieu de test');zone.tabIndex=0;zone.style.left='10%';zone.style.width='40%';zone.onclick=()=>entrees++;scene.append(photo,zone);conteneur.append(scene);document.getElementById('rue-image').append(conteneur);});
 assert.equal(await p.locator('.hg-lieux-tactiles').count(),0,'ancien accordéon supprimé');
 await p.locator('.rc-zone').click();assert.equal(await p.evaluate(()=>entrees),1);
 await p.locator('.rc-zone').focus();await p.keyboard.press('Enter');assert.equal(await p.evaluate(()=>entrees),2);
 await p.evaluate(()=>{document.getElementById('rue-centrale-conteneur').remove();});
 assert.equal(await p.locator('.hg-lieux-tactiles').count(),0,'aucun panneau réinséré');
}));
test('L2 : pièces et actions accessibles en paysage',async()=>avecJeu(async(b,o)=>{
 const p=await pageMobile(b,o,852,393);await p.evaluate(()=>{document.getElementById('vue-rue').classList.remove('active');document.getElementById('vue-batiment').classList.add('active');document.getElementById('pieces-tabs').innerHTML=Array.from({length:8},(_,i)=>'<button class="piece-tab">Pièce '+i+'</button>').join('');});
 // Le joueur ouvre l'onglet « Pièces », choisit la dernière pièce, et la liste se referme.
 assert.equal(await p.locator('#pieces-tabs').isVisible(),false);await p.locator('[data-room-tab="0"]').click();
 await p.locator('.piece-tab').last().scrollIntoViewIfNeeded();await p.locator('.piece-tab').last().click();assert.equal(await p.locator('#hg-room-list').isVisible(),false);assert.ok(await p.locator('#piece-image').evaluate(e=>e.getBoundingClientRect().width)>800);
 // Sortie : bouton compact de l'en-tête, relié au bouton d'origine (masqué sur mobile).
 assert.equal(await p.locator('#vue-batiment .batiment-header>.sortir-btn').isVisible(),false);
 await p.evaluate(()=>{window.sorties=0;document.querySelector('#vue-batiment .sortir-btn').onclick=()=>sorties++;});
 assert.ok(await p.locator('#hg-mobile-exit').isVisible());await p.locator('#hg-mobile-exit').click();assert.equal(await p.evaluate(()=>sorties),1);
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
 const ancien=await page(b,o,1440,900,true);await ancien.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));await ancien.addStyleTag({content:lecture('style.css',true).toString()});const n=await page(b,o,1440,900);await forumFixture(ancien);await forumFixture(n);await memeLibelleAide(ancien);await memeLibelleAide(n);const avant=await ancien.screenshot(),apres=await n.screenshot();preuve('forum-1440-avant.png',avant);preuve('forum-1440-apres.png',apres);assert.ok(avant.equals(apres),'forum bureau identique pixel pour pixel');
}));
test('L6 : boutons historiques et champs dans une poignée ne déclenchent pas de déplacement',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await surface(p);await p.evaluate(()=>{window.commandesToolbar=0;const b=document.createElement('button');b.textContent='Dupliquer fixture';b.id='toolbar-fixture';b.addEventListener('mousedown',()=>commandesToolbar++);document.getElementById('objet-audit').append(b);});
 await p.locator('#toolbar-fixture').tap();assert.equal(await p.evaluate(()=>commandesToolbar),1);assert.equal(await p.evaluate(()=>etatObjet.x),20);await p.locator('#toolbar-fixture').click();assert.equal(await p.evaluate(()=>commandesToolbar),2);assert.equal(await p.evaluate(()=>etatObjet.x),20);
}));
test('L5 : inventaire long et tableau financier restent consultables sans mutation',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await p.evaluate(()=>{document.getElementById('postes-body').innerHTML='<div class="char-sheet-grid"><section class="cs-section">Liquide : 0 FR</section><section class="cs-section">Banque : 15000 FR</section></div><div class="hg-inventaire-ligne"><div>Objet</div><div><div class="hg-inventaire-nom">Un objet avec un intitulé particulièrement long et une quantité confirmée</div></div><button>Déposer</button><button>Détruire</button></div><table style="width:900px"><tbody>'+Array.from({length:100},(_,i)=>'<tr><td>Objet '+i+'</td><td>0 FR</td></tr>').join('')+'</tbody></table>';document.getElementById('modal-postes').classList.add('open');});
 await p.waitForTimeout(100);assert.equal(await p.locator('.hg-table-defilante').count(),1);assert.equal(await p.locator('tr').count(),100);assert.equal(await p.locator('.cs-section').first().innerText(),'Liquide : 0 FR');assert.equal(await p.locator('.cs-section').last().innerText(),'Banque : 15000 FR');assert.ok(await p.locator('.hg-table-defilante').evaluate(e=>e.clientWidth<=innerWidth));await p.setViewportSize({width:1440,height:900});await p.waitForTimeout(100);assert.equal(await p.locator('.hg-table-defilante').count(),0,'DOM bureau restauré');assert.equal(await p.locator('tr').count(),100);
}));
test('L8 : retour, panne et autre onglet bloquent le premier ordre sans le rejouer',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await p.evaluate(()=>{window.ordres=0;window.lectures=0;window.loadCharacter=async()=>{lectures++;return true;};const b=document.createElement('button');b.id='ordre-fixture';b.style.cssText='position:fixed;left:20px;top:120px;z-index:30';b.textContent='Ordre';b.onclick=()=>ordres++;document.body.append(b);window.dispatchEvent(new StorageEvent('storage',{key:'respublica_char_Fixture'}));});
 await p.locator('#ordre-fixture').click();await p.waitForTimeout(60);assert.equal(await p.evaluate(()=>ordres),0);assert.equal(await p.evaluate(()=>lectures),1);await p.locator('#ordre-fixture').click();assert.equal(await p.evaluate(()=>ordres),1);
 await p.evaluate(()=>{window.loadCharacter=async()=>false;window.dispatchEvent(new Event('offline'));});await p.context().setOffline(true);await p.waitForTimeout(60);await p.locator('#ordre-fixture').click();assert.equal(await p.evaluate(()=>ordres),1);assert.ok(await p.locator('#hg-reprise').isVisible());
 await p.evaluate(()=>{window.loadCharacter=async()=>new Promise(r=>window.finReprise=r);});await p.context().setOffline(false);await p.waitForTimeout(100);await p.locator('#ordre-fixture').click();assert.equal(await p.evaluate(()=>ordres),1);await p.evaluate(()=>finReprise(true));await p.waitForTimeout(60);assert.equal(await p.locator('#hg-reprise').isVisible(),false);assert.equal(await p.evaluate(()=>ordres),1);
}));
// L4 (28/11/2026) : captures prises après stabilisation (réseau, images, polices, deux images d'animation), animations et transitions figées.
test('L4 : création réelle dans les six langues, explications et caractéristiques conservées',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);const html=fs.readFileSync(path.join(R,'index.html'),'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');await p.setContent(html);
 for(const f of ['i18n/i18next.min.js','i18n/resources.js','i18n/i18n-init.js','data.js','creation.js'])await p.addScriptTag({url:o+'/'+f});
 await p.evaluate(()=>{G.country='republic';G.name='Fixture mobile';});
 for(const langue of ['fr','en','es','zh-TW','ru','ko']){await p.evaluate(l=>changerLangueRP(l),langue);await p.evaluate(()=>{goTo(0);document.getElementById('connexion-panel').style.display='none';ouvrirConnexionCompte();});assert.ok(await p.locator('#connexion-email').isVisible());for(const n of [1,2,3,4,5,7,8])await p.evaluate(n=>goTo(n),n);await p.evaluate(()=>goTo(6));assert.equal(await p.locator('.srow').count(),6);assert.equal(await p.locator('.sex').count(),6,'explications En jeu conservées');assert.ok(await p.locator('.sbtn').first().evaluate(e=>e.getBoundingClientRect().width>=44));const avant=await p.evaluate(()=>({...G.freeStats}));await p.locator('.sbtn').nth(1).click();assert.notDeepEqual(await p.evaluate(()=>({...G.freeStats})),avant);await p.locator('.sbtn').first().click();assert.deepEqual(await p.evaluate(()=>({...G.freeStats})),avant);assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));}
 await p.setViewportSize({width:1440,height:900});const stable=async()=>{await p.waitForLoadState('networkidle').catch(()=>{});await p.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.complete?(i.decode?i.decode().catch(()=>{}):null):new Promise(r=>{i.onload=i.onerror=r;})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));});await p.waitForTimeout(300);};await stable();const apres=await p.screenshot({animations:'disabled',caret:'hide'});await p.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));await p.addStyleTag({content:temoin.fichiers['style.css']});await stable();const avant=await p.screenshot({animations:'disabled',caret:'hide'});preuve('creation-1440-avant.png',avant);preuve('creation-1440-apres.png',apres);assert.ok(apres.equals(avant),'création bureau 1440 identique');
}));
test('L7 : rapport et décisions réels respectent les droits fournis par le serveur',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);const acorn=require('../vercel/node_modules/acorn'),s=fs.readFileSync(path.join(R,'plateau-politique.js'),'utf8');const arbre=acorn.parse(s,{ecmaVersion:'latest'});const js=arbre.body.filter(n=>n.type==='FunctionDeclaration'&&['ouvrirPanneauCombat','htmlDecisionsCombat','libelleLieuCombat','libelleAdversaireDebout','libelleIssueCombat'].includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');
 await p.addScriptTag({content:`window.contexteGroupePj=()=>({});window.contexteGroupePjValide=()=>true;window.escapeHtmlText=s=>String(s);window.showToast=()=>{};window.fixtureCombat={id:1,statut:'en_cours',contrat_combat:2,round_courant:5,peut_decider:false,rounds:[{round:5,mes_pa_perdus:0,adversaires_tombes:0}],lieu:{ville:'Fixture'},mon_effectif_actuel:3,mon_effectif_initial:3};window.sbMilitaireBatailleEtat=async()=>({ok:true,bataille:fixtureCombat});`+js});
 await p.evaluate(()=>ouvrirPanneauCombat(1));assert.equal(await p.locator('#postes-body button').count(),1);assert.match(await p.locator('#postes-body').innerText(),/chef conserve/);assert.doesNotMatch(await p.locator('#postes-body').innerHTML(),/deciderCombat/);
 await p.evaluate(()=>{fixtureCombat.peut_decider=true;return ouvrirPanneauCombat(1);});assert.equal(await p.locator('#postes-body button').count(),3);preuve('combat-fixture-375.png',await p.screenshot());assert.ok(await p.locator('.hg-rapport-combat').evaluate(e=>e.scrollWidth<=e.clientWidth+1));await p.evaluate(()=>{fixtureCombat.mon_groupe_replie=true;return ouvrirPanneauCombat(1);});assert.equal(await p.locator('#postes-body button').count(),0);
}));
test('L9 : portraits réels différés dans le panneau fermé puis demandés à son ouverture',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667),demandes=[];p.on('request',r=>{if(r.url().includes('portrait-fixture'))demandes.push(r.url());});
 const acorn=require('../vercel/node_modules/acorn'),s=fs.readFileSync(path.join(R,'plateau-multijoueur.js'),'utf8');const n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='renderPersonsList');
 await p.addScriptTag({content:`var state={country:'republic',currentCity:'capitale',currentBuilding:'fixture',char:null};var ARCHETYPES=[],PNJ_AVATAR={default:{}},COUNTRIES={republic:{}},RP_STATUTS_JUDICIAIRES={};var appliquerRemplacantCodetenu=x=>x,filtrerPnjPostesPourvus=x=>x,getSimulesPresents=()=>[],getGroupeHtmlPourPiece=()=>'',chargerVraisJoueursPresents=()=>{},encodePnjSafe=p=>encodeURIComponent(JSON.stringify(p)),marqueurMutinHtml=()=>'',marqueursJudiciairesHtml=()=>'';`+s.slice(n.start,n.end)});
 await p.evaluate(()=>{document.getElementById('vue-rue').classList.remove('active');document.getElementById('vue-batiment').classList.add('active');renderPersonsList(Array.from({length:20},(_,i)=>({name:'Fixture '+i,job:'default',role:'Personne',photoUrl:'/portrait-fixture-'+i+'.webp'})));});await p.waitForTimeout(150);assert.equal(demandes.length,0,'aucune image de ce panneau fermé demandée');assert.equal(await p.locator('#persons-list img[loading=lazy]').count(),20);await p.locator('[data-hg-panneau=personnes]').click();await p.waitForTimeout(500);assert.ok(demandes.length>0,'les images deviennent éligibles à leur affichage');
}));
test('L10 : téléphone masqué ne lit rien, retour visible attend la confirmation',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,393,852);await p.evaluate(()=>{window.lecturesVerrou=0;window.loadCharacter=async()=>{lecturesVerrou++;return true;};Object.defineProperty(document,'hidden',{value:true,configurable:true});document.dispatchEvent(new Event('visibilitychange'));});await p.waitForTimeout(60);assert.equal(await p.evaluate(()=>lecturesVerrou),0);await p.evaluate(()=>{Object.defineProperty(document,'hidden',{value:false,configurable:true});document.dispatchEvent(new Event('visibilitychange'));});await p.waitForTimeout(80);assert.equal(await p.evaluate(()=>lecturesVerrou),1);assert.equal(await p.locator('#hg-reprise').isVisible(),false);
}));

test('L8 : session refusée et authentification hors délai ne déclenchent aucun ordre ni chargement tardif',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);await p.clock.install();
 await p.evaluate(()=>{window.ordres=0;window.lectures=0;window.loadCharacter=async()=>{lectures++;return true;};window.rpAuthAssurerSession=async()=>{throw Error('session refusée');};const b=document.createElement('button');b.id='ordre-auth-fixture';b.textContent='Ordre';b.onclick=()=>ordres++;document.body.append(b);window.dispatchEvent(new StorageEvent('storage',{key:'respublica_char_Fixture'}));b.click();});
 await p.clock.runFor(20);assert.equal(await p.evaluate(()=>lectures),0);assert.equal(await p.evaluate(()=>ordres),0);assert.match(await p.locator('#hg-reprise').innerText(),/État non confirmé/);
 await p.evaluate(()=>{window.rpAuthAssurerSession=()=>new Promise(r=>window.finAuth=r);document.querySelector('#hg-reprise button').click();});await p.clock.runFor(15001);
 assert.equal(await p.evaluate(()=>loadCharacter.generation),1);assert.match(await p.locator('#hg-reprise').innerText(),/État non confirmé/);
 await p.evaluate(()=>finAuth());await p.clock.runFor(20);assert.equal(await p.evaluate(()=>lectures),0,'authentification tardive abandonnée avant le chargeur');assert.equal(await p.evaluate(()=>ordres),0);
 await p.evaluate(()=>{window.rpAuthAssurerSession=async()=>true;document.querySelector('#hg-reprise button').click();});await p.clock.runFor(20);assert.equal(await p.evaluate(()=>lectures),1);assert.equal(await p.locator('#hg-reprise').isVisible(),false);assert.equal(await p.evaluate(()=>ordres),0,'le clic initial reste non rejoué');
}));
