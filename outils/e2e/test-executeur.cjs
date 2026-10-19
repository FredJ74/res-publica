// Tests de l'EXECUTEUR : fixtures locales et Chromium, aucune session Supabase reelle.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http');
const {proxyNavigateur,configuration,comparer,diagnostic,resumerReseau,preuve,Joueur,campagne,hash}=require('./luthecia.cjs');
const {lancerChromium}=require('../bancs/fixtures/chromium-cdp.cjs');
const env=()=>({HG_E2E_BASE_URL:'https://res-publica.vercel.app/',HG_E2E_EMAIL:'test@example.invalid',HG_E2E_PASSWORD:'mot-de-passe-factice',HG_E2E_PERSONNAGE:'Test Fixture',HG_E2E_UID:'uid-test',HG_E2E_AUTORISATION_JSON:JSON.stringify({comptesReservesAuxTests:true,autoriseParResponsable:true,origine:'https://res-publica.vercel.app',backend:'https://jxpwoosmmhohoihxpbuc.supabase.co',comptes:[{personnage:'Test Fixture',uid:'uid-test'}]})});
function configActe(etape,autorisation={}){const e=env(),a=JSON.parse(e.HG_E2E_AUTORISATION_JSON);Object.assign(a,{economieIsolee:true,entreprises:['fixture'],scenarios:['achat']},autorisation);e.HG_E2E_AUTORISATION_JSON=JSON.stringify(a);e.HG_E2E_PLAN_JSON=JSON.stringify([etape]);return e;}
const clic={type:'clic',scenario:'achat',selecteur:'#achat',rpc:'acheter_produit_commerce',handlerSHA256:hash('acheter()'),attendu:{delta:{liquide:-25,pa:0},rpc:{ok:true},uiTexte:'Commande confirmee'}};
test('aucune configuration : bloque, aucune authentification ni navigateur',async()=>{const d=fs.mkdtempSync(path.join(os.tmpdir(),'hg-prevol-test-'));try{const r=await campagne({env:{},dossier:d});assert.equal(r.statut,'BLOQUE');assert.equal(r.visites.length,0);assert.ok(r.blocages.includes('HG_E2E_PASSWORD'));assert.equal(JSON.parse(fs.readFileSync(path.join(d,'rapport.json'))).mode,'authentifie-demande');}finally{fs.rmSync(d,{recursive:true});}});
test('compte present sans autorisation explicite : bloque',()=>{const e=env();e.HG_E2E_AUTORISATION_JSON='{}';assert.equal(configuration(e).bloque,true);});
test('identite et origine explicitement autorisees',()=>{assert.equal(configuration(env()).comptes[0].nom,'Test Fixture');});
for(const [nom,modif]of Object.entries({origine:e=>e.HG_E2E_BASE_URL='https://autre.invalid/',http:e=>e.HG_E2E_BASE_URL='http://res-publica.vercel.app/',identite:e=>e.HG_E2E_PERSONNAGE='Joueur ordinaire',duree:e=>e.HG_E2E_MAX_MINUTES='100',secretURL:e=>e.HG_E2E_BASE_URL='https://test:secret@res-publica.vercel.app/'}))test('refuse '+nom,()=>{const e=env();modif(e);assert.throws(()=>configuration(e));});
test('acte economique refuse sans ressources isolees',()=>assert.throws(()=>configuration(configActe(clic,{economieIsolee:false})),/RESSOURCES/));
test('acte refuse sans contre-preuve serveur',()=>assert.throws(()=>configuration(configActe({...clic,attendu:{}})),/VERIFICATION/));
test('acte refuse sans verdict serveur attendu',()=>assert.throws(()=>configuration(configActe({...clic,attendu:{delta:{liquide:-25},uiTexte:'Commande confirmee'}})),/VERDICT/));
test('clic sensible lie a un handler exact et un scenario autorise',()=>{assert.equal(configuration(configActe(clic)).plan.length,1);assert.throws(()=>configuration(configActe({...clic,scenario:'election'})),/ACTE/);assert.throws(()=>configuration(configActe({...clic,handlerSHA256:''})),/HANDLER/);});
test('deux comptes doivent etre distincts et complets',()=>{const e=env();e.HG_E2E_INVITE_EMAIL='second@example.invalid';assert.throws(()=>configuration(e),/SECOND_COMPTE/);});
test('montants nuls, stocks et inventaire compares, pas de faux succes',()=>{const a={liquide:25,pa:1,inventory:[],entreprises:{fixture:{stockProduits:{vin:2}}}},b={liquide:0,pa:0,inventory:[{nom:'objet'}],entreprises:{fixture:{stockProduits:{vin:1}}}};comparer(a,b,{delta:{liquide:-25,pa:-1},stocks:{fixture:{vin:-1}},inventaireChange:true});assert.throws(()=>comparer(a,a,{delta:{liquide:-25}}),/DELTA/);assert.throws(()=>comparer(a,a,{stocks:{fixture:{vin:-1}}}),/STOCK/);assert.throws(()=>comparer(a,a,{inventaireChange:true}),/INVENTAIRE/);});
test('journaux sans URL complete, query, messages, JWT, email ou corps de requete',()=>{const secret='eyJhbGciOiJIUzI1NiJ9.secret.signature mot-de-passe-factice test@example.invalid';const r={...resumerReseau('https://example.invalid/rest/v1/rpc/acheter?token='+secret,403),...diagnostic(secret)};assert.equal(r.operation,'rpc:acheter');const texte=JSON.stringify(r);for(const mot of secret.split(' '))assert.ok(!texte.includes(mot));assert.ok(!texte.includes('token'));const p=preuve({inventory:[{nom:secret}],entreprises:{fixture:{caisse:123}}});assert.ok(!JSON.stringify(p).includes(secret));});
// Ce test navigue par clics dans une petite page de fixture, jamais dans un faux jeu connecte.
test('Chromium reel : clic humain, position serveur, divergence et changement de personnage',async()=>{
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-robot-test-'));let chrome,browser;
 const serveur=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html');res.end(`<!doctype html><style>.modal-overlay{display:none}.modal-overlay.open{display:block}</style><div id="modal-postes" class="modal-overlay"><button class="modal-close" onclick="document.getElementById('modal-postes').classList.remove('open')">Fermer</button><div id="postes-body"></div></div><div id="vue-batiment" class="active"><div id="piece-nom">Accueil</div><div id="piece-image"></div><div id="pieces-tabs"><button class="piece-tab" onclick="state.currentRoom='bureau';server.current_room='bureau';document.getElementById('piece-nom').textContent='Bureau'">Bureau</button></div><button onclick="doOrder('consulter_carte_commerce')">Consulter</button><button id="clic" onclick="document.body.dataset.clique='oui'">Ouvrir</button></div><script>
window.state={char:{name:'Test Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'office-notarial',currentRoom:'accueil',liquide:0,pa:5,hp:70,moral:50};
window.doOrder=()=>{document.getElementById('modal-postes').classList.add('open');document.getElementById('postes-body').innerHTML=['champagne_luthecia','cocktail_luthecia'].map(id=>'<div><b>'+id+'</b> 25 FR — Stock : 0<div><button disabled>Commander</button><button disabled>Produire</button><button onclick="ouvrirFicheProduitCommerce(\\'brasserie\\',\\'hotel-republica\\',\\'bar\\',\\''+id+'\\')">Fiche produit</button></div></div>').join('');};
window.ouvrirFicheProduitCommerce=()=>{document.getElementById('postes-body').textContent='Fiche test';};
window.SUPABASE_URL='https://jxpwoosmmhohoihxpbuc.supabase.co';window.rpAuthUid=()=> 'uid-test';
window.server={user_id:'uid-test',arg:0,liquide:0,pa:5,hp:70,moral:50,resources:{inf:2},inventory:[],current_building:'office-notarial',current_room:'accueil'};window.sbGet=async()=>[server];</script>`);});
 try{
  await new Promise(r=>serveur.listen(0,'127.0.0.1',r));
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync);assert.ok(executable,'Chromium requis, pas de skip');
  chrome=await lancerChromium({executable,profil});browser=await require('playwright').chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
  const context=await browser.newContext(),page=await context.newPage();await page.goto('http://127.0.0.1:'+serveur.address().port);
  const conf=configuration(env()),rapport={visites:[],catalogues:[]},j=new Joueur(page,conf.comptes[0],conf,rapport,new AbortController().signal);
  assert.equal((await j.serveur()).liquide,0);await j.observer();assert.equal(rapport.visites.length,1);
  const debut=Date.now();await j.clic(page.locator('#clic'));assert.ok(Date.now()-debut>=1950,'pause humaine minimale');assert.equal(await page.locator('body').getAttribute('data-clique'),'oui');
  await j.piece('office-notarial','bureau');assert.equal((await j.serveur()).current_room,'bureau');
  await page.evaluate(()=>{state.currentBuilding=server.current_building='hotel-republica';state.currentRoom=server.current_room='bar';});
  await j.catalogue();assert.equal(rapport.catalogues[0].articles.length,2);assert.equal(rapport.catalogues[0].articles[0].stock,0);assert.equal(rapport.catalogues[0].articles[0].prix,25);
  await page.evaluate(()=>{state.liquide=999;});await assert.rejects(()=>j.observer(),/MIROIR_CLIENT_SERVEUR/);
  await page.evaluate(()=>{state.char.name='Autre joueur';});await assert.rejects(()=>j.clic(page.locator('#clic')),/IDENTITE/);
 }finally{try{await browser?.close();}finally{try{await chrome?.arreter();}finally{serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});}}}
});

test('simule : clic financier confronte verdict, effet serveur et UI',async()=>{
 const conf=configuration(configActe(clic)),r={actes:[],actesEnCours:[]};let argent=50,envoye=0,options,resolve;
 const page={locator:()=>({count:async()=>1,getAttribute:async()=> 'acheter()',click:async o=>{envoye++;options=o;argent-=25;resolve({ok:()=>true,json:async()=>({ok:true})});}}),getByText:()=>({first:()=>({isVisible:async()=>false,waitFor:async()=>{}})}),waitForResponse:()=>new Promise(r=>{resolve=r;})};
 const j=new Joueur(page,conf.comptes[0],conf,r,new AbortController().signal);j.rythme=async()=>{};j.identite=async()=>({});j.serveur=async()=>({liquide:argent,pa:5,inventory:[],entreprises:{}});
 await j.acte({...clic,doubleClic:true});assert.equal(envoye,1);assert.equal(options.clickCount,2);assert.equal(r.actes.length,1);assert.equal(r.actesEnCours.length,0);assert.equal(r.actes[0].apres.liquide,25);
});
test('simule : reponse perdue execute une seule requete, sans rejeu automatique',async()=>{
 const conf=configuration(configActe(clic)),r={actes:[],actesEnCours:[]};let argent=50,executions=0,route,abandon=false,retire=false;
 const page={route:async(m,f)=>{route=f;},unroute:async()=>{retire=true;},locator:()=>({count:async()=>1,getAttribute:async()=> 'acheter()',click:async()=>route({request:()=>({url:()=>conf.autorisation.backend+'/rest/v1/rpc/acheter_produit_commerce'}),fetch:async o=>{assert.equal(o.maxRetries,0);executions++;argent-=25;},abort:async()=>{abandon=true;}})}),getByText:()=>({first:()=>({isVisible:async()=>false,waitFor:async()=>{}})})};
 const j=new Joueur(page,conf.comptes[0],conf,r,new AbortController().signal);j.rythme=async()=>{};j.identite=async()=>({});j.serveur=async()=>({liquide:argent,pa:5,inventory:[],entreprises:{}});
 await j.acte({...clic,panne:'perdre-reponse'});assert.equal(executions,1);assert.ok(abandon&&retire);assert.equal(r.actes.length,1);
});
test('simule : handler different refuse avant tout clic, journal conserve pour reconciliation',async()=>{
 const conf=configuration(configActe(clic)),r={actes:[]};let clics=0,sauves=0;
 const page={locator:()=>({count:async()=>1,getAttribute:async()=> 'autre()',click:async()=>{clics++;}})};
 const j=new Joueur(page,conf.comptes[0],conf,r,new AbortController().signal);j.serveur=async()=>({inventory:[],entreprises:{}});j.sauver=()=>{sauves++;};
 await assert.rejects(()=>j.acte(clic),/HANDLER_UI_MODIFIE/);assert.equal(clics,0);assert.equal(sauves,1);assert.equal(r.actesEnCours.length,1);
});

test('position de rue : contrat serveur existant, building null et noeud exact',async()=>{
 const conf=configuration(env());let r={ok:true,country:'republic',city:'capitale',building:null,street:'luthecia-hotel-de-ville'};
 const j=new Joueur({evaluate:async()=>r},conf.comptes[0],conf,{},new AbortController().signal);j.identite=async()=>({});
 await j.positionRue('luthecia-hotel-de-ville');r={...r,street:'autre'};await assert.rejects(()=>j.positionRue('luthecia-hotel-de-ville'),/POSITION_RUE/);
 r={...r,street:'luthecia-hotel-de-ville',building:'office-notarial'};await assert.rejects(()=>j.positionRue('luthecia-hotel-de-ville'),/POSITION_RUE/);
});

test('proxy reutilise sans fuite ni contournement TLS',()=>{assert.equal(proxyNavigateur({}),undefined);const p=proxyNavigateur({HTTPS_PROXY:'http://nom:valeur-factice@proxy.invalid:8080'});assert.equal(p.server,'http://proxy.invalid:8080');assert.equal(p.username,'nom');assert.equal(p.password,'valeur-factice');assert.throws(()=>proxyNavigateur({HTTPS_PROXY:'file:///tmp/proxy'}),/PROTOCOLE/);});

test('oracles invalides refuses au prevol avant toute action financiere',()=>{assert.throws(()=>configuration(configActe({...clic,attendu:{delta:{liquide:'-25'},uiTexte:'OK',rpc:{ok:true}}})),/DELTA_INVALIDE_AVANT_ACTION/);assert.throws(()=>configuration(configActe({...clic,attendu:{...clic.attendu,stocks:{tiers:{vin:-1}}}})),/ENTREPRISE_ORACLE_NON_AUTORISEE/);assert.throws(()=>configuration(configActe({...clic,attendu:{...clic.attendu,stocks:{fixture:{vin:-0.5}}}})),/DELTA_STOCK/);});
