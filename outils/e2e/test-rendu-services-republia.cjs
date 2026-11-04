'use strict';
// Vrai Chromium, vraies définitions/renderer/CSS, identités fictives et aucun RPC.
// Ce banc prouve le rendu et le routage des clics, pas les autorisations en production.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const acorn=require('acorn'),{chromium}=require('playwright');
const {lancerChromium}=require('../bancs/fixtures/chromium-cdp.cjs');
const root=path.resolve(__dirname,'../..');
const lire=f=>fs.readFileSync(path.join(root,f),'utf8');
function fonctions(f,noms){const s=process.env.HG135_CONTRE_RENDER&&f==='plateau-politique.js'?require('node:child_process').execFileSync('git',['show',process.env.HG135_CONTRE_RENDER+':'+f],{cwd:root,encoding:'utf8'}):lire(f),ast=acorn.parse(s,{ecmaVersion:'latest'});
 return noms.map(nom=>{const n=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);assert.ok(n,nom);return s.slice(n.start,n.end);}).join('\n');}

test('greffes et commissariats : clics réels dans les trois villes, deux largeurs',async t=>{
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-services-'));
 const demandes=[],erreurs=[];let chrome,browser;
 const html='<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">'+
 '<link rel="stylesheet" href="/style.css"><div id="action-context-bat"></div><div id="actions-row-bat"></div>'+
 '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header">'+
 '<div id="postes-modal-title"></div></div><div id="postes-body" class="modal-body"></div></div></div>';
 const serveur=http.createServer((req,res)=>{demandes.push(req.url);res.setHeader('Content-Type',req.url==='/style.css'?'text/css':'text/html');res.end(req.url==='/style.css'?lire('style.css'):html);});
 try{
  await new Promise((r,j)=>{serveur.once('error',j);serveur.listen(0,'127.0.0.1',r);});
  const origine='http://127.0.0.1:'+serveur.address().port;
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync);assert.ok(executable,'Chromium requis');
  chrome=await lancerChromium({executable,profil});browser=await chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
  for(const ville of ['capitale','ville_a','ville_b'])for(const largeur of [1280,390])for(const service of ['greffe','commissariat']){
   await t.test(ville+' / '+largeur+' / '+service,async()=>{
    const page=await browser.newPage({viewport:{width:largeur,height:800}});
    page.on('pageerror',e=>erreurs.push(e.message));
    await page.route('**/*',route=>route.request().url().startsWith(origine)?route.continue():route.abort());
    try{
     await page.goto(origine);await page.addScriptTag({content:lire('data.js')});
     await page.addScriptTag({content:fonctions('plateau-politique.js',['renderRoomActions','ouvrirMenuOrdresGreffe','ouvrirMenuOrdresCommissaire'])});
     const attendu=await page.evaluate(({ville,service})=>{
      window.TEST_MODE=false;window.getMalusISN=()=>0;window.clics=[];
      // Ordres capturés : aucun paiement, effet métier ni appel serveur exécuté.
      window.doOrder=(...args)=>clics.push(args);window.showPostRequired=(...args)=>clics.push(['refus-poste',...args]);
      const bid=service==='greffe'?(ville==='capitale'?'tribunal':'tribunal-local'):(ville==='capitale'?'commissariat':'commissariat-local');
      const rid=service==='greffe'?'greffe':'bureau_commissaire';
      window.state={country:'republic',currentCity:ville,currentBuilding:bid,currentRoom:rid,char:{name:'FixtureServices',country:'republic',enigme1:{etape:'declenchee'}},poste:{id:service==='greffe'?'greffier':'commissaire'},pa:100,liquide:100000,arg:100000};
      const room=BUILDINGS[bid].rooms[rid];renderRoomActions(room,bid,rid);
      return ordresDeclaresDeLaPiece(room,WORLD.republic[ville]?.buildingContext?.[bid],rid).map(o=>({fn:o.fn,label:o.label,requiresPost:o.requiresPost}));
     },{ville,service});
     const trouves=[];
     async function verifierBoutons(buttons){
      for(let j=0;j<await buttons.count();j++){
       const b=buttons.nth(j),code=await b.getAttribute('onclick'),texte=await b.textContent();
       const ordre=attendu.find(o=>texte.trim().startsWith(o.label));assert.ok(ordre,'bouton déclaré : '+texte);trouves.push(ordre.fn);
       const m=code?.match(/doOrder\(['"]([^'"]+)/);
       if(m)assert.equal(m[1],ordre.fn);
       else{assert.ok(ordre.requiresPost,'restriction déclarée');assert.match(code,/showPostRequired/);assert.ok(await b.evaluate(e=>e.classList.contains('blocked')));}
       const avant=await page.evaluate(()=>clics.length);await b.click();assert.equal(await page.evaluate(()=>clics.length),avant+1);
      }
     }
     if(service==='greffe'){
      const menus=page.locator('#actions-row-bat > button');assert.equal(await menus.count(),4);
      for(let i=0;i<4;i++){
       await menus.nth(i).click();assert.equal(await page.locator('#modal-postes').evaluate(e=>e.classList.contains('open')),true);
       const box=await page.locator('.modal-box').boundingBox();assert.ok(box.x>=-1&&box.x+box.width<=largeur+1,'modale dans le viewport');
       await verifierBoutons(page.locator('#postes-body button'));
       await page.locator('#modal-postes').evaluate(e=>e.classList.remove('open'));
      }
     }else{
      // Le bureau du commissaire suit maintenant la convention validée au greffe :
      // deux boutons principaux au format normal ouvrent une modale.
      const menus=page.locator('#actions-row-bat > button[onclick^="ouvrirMenuOrdresCommissaire"]');
      assert.equal(await menus.count(),2);
      assert.equal(await page.locator('#actions-row-bat details, #actions-row-bat summary').count(),0);
      for(let i=0;i<2;i++){
       await menus.nth(i).click();
       assert.equal(await page.locator('#modal-postes').evaluate(e=>e.classList.contains('open')),true);
       const box=await page.locator('.modal-box').boundingBox();
       assert.ok(box.x>=-1&&box.x+box.width<=largeur+1,'modale du commissaire dans le viewport');
       assert.equal(await page.locator('#postes-body button').count(),3);
       await verifierBoutons(page.locator('#postes-body button'));
       await page.locator('#modal-postes').evaluate(e=>e.classList.remove('open'));
      }
      await verifierBoutons(page.locator('#actions-row-bat > button:not([onclick^="ouvrirMenuOrdresCommissaire"])'));
      // Les menus ne donnent aucun droit : les sous-ordres réservés restent grisés.
      await page.evaluate(()=>{state.poste=null;renderRoomActions(BUILDINGS[state.currentBuilding].rooms.bureau_commissaire,state.currentBuilding,'bureau_commissaire');});
      for(let i=0;i<2;i++){
       await page.locator('#actions-row-bat > button[onclick^="ouvrirMenuOrdresCommissaire"]').nth(i).click();
       for(const fn of (i===0?['mener_enquete','organiser_filature','organiser_chasse_homme']:['gerer_effectifs_police','recruter_policier','recruter_policier_cynophile'])){
        const label=attendu.find(o=>o.fn===fn).label;
        const ordre=page.locator('#postes-body button').filter({hasText:label});
        assert.equal(await ordre.count(),1);
        assert.ok(await ordre.evaluate(b=>b.classList.contains('blocked')&&b.getAttribute('onclick').includes('showPostRequired')),fn+' refusé au visiteur');
        await page.evaluate(()=>clics=[]);
        await ordre.evaluate(b=>b.click());
        assert.deepEqual(await page.evaluate(()=>clics.map(c=>c[0])),['refus-poste']);
       }
       await page.locator('#modal-postes').evaluate(e=>e.classList.remove('open'));
      }
     }
     assert.deepEqual(trouves.sort(),attendu.map(o=>o.fn).sort(),'chaque ordre déclaré demeure accessible par son vrai bouton');
     if(service==='greffe'){
      const nombres=await page.evaluate(()=>{state.char.enigme1=null;renderRoomActions(BUILDINGS[state.currentBuilding].rooms.greffe,state.currentBuilding,'greffe');return Object.values(window._greffeOrdresGroupes).flatMap(g=>g.entries).map(e=>e.ordre.fn);});
      assert.ok(!nombres.includes('demander_juge_instruction'),'ordre de quête caché hors enquête');
     }
    }finally{await page.close();}
   });
  }
  assert.deepEqual(erreurs,[]);assert.ok(demandes.every(u=>u==='/'||u==='/style.css'||u==='/favicon.ico'));
 }finally{
  try{await browser?.close();}finally{try{await chrome?.arreter();}finally{serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});}}
 }
});
