// Chromium local uniquement. Aucun compte, aucune authentification ou donnée de production.
'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const acorn=require('acorn');
const {lancerChromium}=require('../bancs/fixtures/chromium-cdp.cjs');
const R=path.resolve(__dirname,'../..');
function selection(fichier,noms){
 const source=fs.readFileSync(path.join(R,fichier),'utf8'),ast=acorn.parse(source,{ecmaVersion:'latest'}),vus=new Set();
 const code=ast.body.filter(n=>{
  const ids=n.type==='FunctionDeclaration'?[n.id.name]:n.type==='VariableDeclaration'?n.declarations.map(d=>d.id.name):[];
  const garde=ids.some(id=>noms.includes(id));if(garde)ids.forEach(id=>vus.add(id));return garde;
 }).map(n=>source.slice(n.start,n.end)).join('\n');
 for(const nom of noms)assert.ok(vus.has(nom),'source réelle manquante : '+fichier+' / '+nom);
 return code;
}
const justice=selection('plateau-justice-economie.js',['PRIX_TERRAIN','NIVEAUX_CONSTRUCTION','palierProposable','DUREE_INSTRUCTION_PERMIS','TYPES_PRET','getTerrainState','ouvrirModalConstruire','doDeposerDemandePermis','getTauxPret','pretBancaireDisponibilite','ouvrirModalPretBancaire','getBuildingIdCommissariat','getBuildingIdCentreMultimodal','getBuildingIdDispensaire','getBuildingIdTribunal','getCaisseLocaleId']);
const sources=[fs.readFileSync(path.join(R,'data.js'),'utf8'),fs.readFileSync(path.join(R,'plateau-chantiers.js'),'utf8'),
 selection('plateau-immobilier.js',['PERMIS_COOLDOWN_REFUS_JOURS','PERMIS_STATUT_INSTRUCTION','PERMIS_STATUT_LEGACY_ATTENTE','permisEnInstruction','cooldownRefusActif','verdictNouvelleDemandePermis']),justice,
 selection('plateau-pnj.js',['ACOMPTE_COMPROMIS','PLAFOND_PRET_COMPROMIS','SURFACE_TERRAINS','terrainOrdreDisponible','doSignerCompromis']),
 fs.readFileSync(path.join(R,'plateau-construction-commandes.js'),'utf8'),
 selection('plateau-politique.js',['CATEGORIES_BUDGET_MAIRIE','getBuildingIdPourCategorieBudget','renderRoomActions','ouvrirMenuOrdresTerrain','expliquerAchatTerrainBloque']),selection('plateau-router.js',['doOrder'])];
test('cinq terrains : rendu et formulaires réels dans Chromium, contreparties uniquement en fixtures',async t=>{
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-immobilier135-'));let chrome,browser;const erreurs=[],reseau=[];
 const serveur=http.createServer((req,res)=>{reseau.push(req.method+' '+req.url);res.setHeader('Content-Type','text/html');res.end('<!doctype html><style>.modal-overlay{display:none}.modal-overlay.open{display:block}</style><div id="action-context-bat"></div><div id="actions-row-bat"></div><div id="toast"></div><div id="modal-postes" class="modal-overlay"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div>');});
 try{
  await new Promise(r=>serveur.listen(0,'127.0.0.1',r));
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync);assert.ok(executable,'Chromium requis, aucun test ignoré');
  chrome=await lancerChromium({executable,profil});browser=await require('playwright').chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
  const contexte=await browser.newContext({serviceWorkers:'block'}),page=await contexte.newPage();page.on('pageerror',e=>erreurs.push(e.message));
  await contexte.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'&&route.request().method()==='GET'?route.continue():route.abort('blockedbyclient'));
  await page.goto('http://127.0.0.1:'+serveur.address().port);
  await page.addScriptTag({content:`
   const TEST_MODE=false;
   window.state={char:{name:'Recette fixture',country:'republic'},country:'republic',currentCity:'capitale',currentRoom:'terrain',day:10,pa:100,arg:1000000,liquide:1000000,terrainsState:{}};
   window.mutations=[];
   window.showToast=(titre,texte)=>document.getElementById('toast').textContent=titre+' '+(texte||'');
   window.estTitulaire=ref=>ref===state.char.name;
   window.chargerTerrainState=async id=>getTerrainState(id);
   window.getMalusISN=()=>0;
   window.getIndiceNationalCalcule=()=>40;
   window.finance135Reconcilier=async()=>{};
   for(const nom of ['sbRpc','sbRpcVerdict','sbSavePersonnage','finance135Acquerir','finance135ContracterPret'])window[nom]=(...args)=>{mutations.push(nom);throw Error('MUTATION_INTERDITE_DANS_LA_FIXTURE '+nom);};
  `});
  for(const content of sources)await page.addScriptTag({content});
  async function preparer(numero,etat){
   await page.evaluate(({numero,etat})=>{
    state.currentBuilding='terrain-a-batir-'+numero;state.currentRoom='terrain';state.terrainsState[state.currentBuilding]={pnj:null,dateGeneration:1,...etat};
    document.getElementById('modal-postes').classList.remove('open');document.getElementById('toast').textContent='';
    renderRoomActions(BUILDINGS[state.currentBuilding].rooms.terrain,state.currentBuilding,'terrain');
   },{numero,etat});
  }
  const surfaces=[2150,2300,2300,1850,2750],prix=[25800,27600,27600,22200,33000];
  for(let numero=1;numero<=5;numero++){
   await t.test('lot '+numero+' : achat et clauses du compromis sans signature',async()=>{
    await preparer(numero,{});await page.getByRole('button',{name:'Achat de terrains',exact:false}).click();
    const achat=page.locator('#postes-body [onclick*="acheter_terrain"]');assert.equal(await achat.count(),1);
    assert.ok((await achat.innerText()).includes(surfaces[numero-1]+' m²'));
    assert.equal(await page.evaluate(()=>BUILDINGS[state.currentBuilding].rooms.terrain.orders.find(o=>o.fn==='acheter_terrain').cost),prix[numero-1]);
    // Ne JAMAIS cliquer acheter_terrain : cet ordre engage immédiatement le dépôt.
    await page.locator('#postes-body [onclick*="signer_compromis"]').click();
    await page.locator('#compromis-pret-check').check();await page.locator('#compromis-permis-check').check();
    assert.equal(await page.locator('#compromis-pret-montant').isVisible(),true);assert.equal(await page.locator('#compromis-permis-type option').count(),4);
   });
   await t.test('lot '+numero+' : propriétaire sans permis rejoint la demande existante',async()=>{
    await preparer(numero,{proprietaire:'Recette fixture',constructionAutorisee:false});
    await page.getByRole('button',{name:'Démarrage du chantier',exact:false}).click();
    await page.locator('#postes-body [onclick*="construire_sur_terrain"]').click();
    await page.locator('#modal-postes.open [onclick*="confirmerDepotPermis"]').first().waitFor({timeout:3000});
    assert.equal(await page.locator('#postes-body [onclick*="confirmerDepotPermis"]').count(),4);
   });
   await t.test('lot '+numero+' : construction autorisée et matériaux sans lancement',async()=>{
    await preparer(numero,{proprietaire:'Recette fixture',constructionAutorisee:true});
    await page.evaluate(()=>ouvrirModalConstruire());assert.equal(await page.locator('#postes-body [onclick*="confirmerConstruction"]').count(),4);
    await preparer(numero,{proprietaire:'Recette fixture',chantier:{type:'construction',palier:'hangar',dureeJours:6,progressionJours:0,totalVerse:10500,coutTotal:30000,prixAchatPJ:{bois:6,minerai:11,metal:17}}});
    await page.getByRole('button',{name:'Approvisionner le chantier',exact:true}).click();
    const texte=await page.locator('#postes-body').innerText();for(const tarif of ['bois : 6 FR','minerai : 11 FR','metal : 17 FR'])assert.ok(texte.includes(tarif),texte);
   });
  }
  await t.test('prêt : renvoi au guichet puis formulaire national sans contrat',async()=>{
   await preparer(1,{proprietaire:'Recette fixture'});await page.evaluate(()=>ouvrirModalPretBancaire('nationale','travaux'));
   assert.match(await page.locator('#toast').innerText(),/Rendez-vous à la Banque Nationale/);assert.equal(await page.locator('#modal-postes.open').count(),0);
   await page.evaluate(()=>{state.currentBuilding='banque-nationale';return ouvrirModalPretBancaire('nationale','travaux');});
   assert.equal(await page.locator('#pret-montant').count(),1);assert.equal(await page.locator('#pret-duree').count(),1);
  });
  await t.test('permis : tiers, instruction et carence restent refusés sans prélèvement',async()=>{
   for(const [etat,message]of [
    [{proprietaire:'Autre fixture'},/Accès refusé/],
    [{proprietaire:'Recette fixture',permis:{statut:'instruction'}},/Demande en cours/],
    [{proprietaire:'Recette fixture',permis:{statut:'refuse',jourRefus:10}},/Refus récent/],
    [{proprietaire:'Recette fixture',chantier:{type:'construction'}},/Chantier en cours/],
    [{proprietaire:'Recette fixture',niveau_construction:'hangar'},/Déjà construit/],
    [{proprietaire:'Recette fixture',pnj:'cadavre'},/Un cadavre/],
    [{proprietaire:'Recette fixture',pnj:'squatter_agr'},/Des squatteurs/]
   ]){
    await preparer(1,{constructionAutorisee:false,...etat});await page.evaluate(()=>ouvrirModalConstruire());
    assert.match(await page.locator('#toast').innerText(),message);assert.equal(await page.locator('#modal-postes.open').count(),0);
   }
  });
  await t.test('ancienne branche sans permis : reproduction de l’impasse, aucune demande',async()=>{
   await preparer(1,{proprietaire:'Recette fixture',constructionAutorisee:false});
   const ancien=selection('plateau-justice-economie.js',['ouvrirModalConstruire']).replace('return doDeposerDemandePermis(1, 100);',`showToast('Permis requis','Permis manquant',false); return;`);
   assert.ok(ancien.includes("showToast('Permis requis'"),'la contre-épreuve doit rétablir le défaut');
   await page.addScriptTag({content:ancien});await page.evaluate(()=>ouvrirModalConstruire());
   assert.match(await page.locator('#toast').innerText(),/Permis requis/);assert.equal(await page.locator('#modal-postes.open').count(),0);
  });
  assert.deepEqual(await page.evaluate(()=>mutations),[]);assert.deepEqual(erreurs,[]);
  assert.ok(reseau.every(x=>x.startsWith('GET ')&&!/rest\/|auth\//.test(x)),'aucun backend appelé');
 }finally{
  try{await browser?.close();}finally{try{await chrome?.arreter();}finally{serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});}}
 }
});
