// Chromium réel, interface navale réelle ; serveur et identité exclusivement fixtures.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const {chromium}=require('../e2e/node_modules/playwright');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const R=path.resolve(__dirname,'../..');
for(const largeur of [390,1280])test(`catalogue naval Chromium ${largeur}px : devis, blocage et bateau physique`,async()=>{
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-naval-ui-'));let chrome,browser,server;
 try{
  server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/css');res.end(fs.readFileSync(path.join(R,'style.css')));});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  chrome=await lancerChromium({executable:process.env.CHROMIUM||'/usr/bin/chromium',profil});
  browser=await chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
  const page=await browser.newPage({viewport:{width:largeur,height:850}});
  await page.setContent(`<link rel="stylesheet" href="http://127.0.0.1:${server.address().port}/style.css"><div class="modal-overlay" id="modal-postes"><div class="modal-box"><div id="postes-modal-title"></div><div class="modal-body" id="postes-body"></div></div></div>`);
  await page.addScriptTag({content:`var state={country:'republic',currentCity:'ville_a',currentBuilding:'chantier-naval',char:{name:'Fixture'}};
var ctx={personnage:state.char,uid:'fixture',jeton:'fixture',generation:0};function sbContexteInventaire(){return ctx;}function showToast(){throw Error('Toast inattendu');}
async function sbRpcVerdict(f){if(f==='chantier_naval_devis')return [3,5].map((n,i)=>({modele:'bateau_'+n,passagers:n,fret:n*100,jours:i?10:7,prix_total_fr:i?150000:90000,acompte:i?52500:31500,recette:{bois:1200,metal:1200,derives_petrochimiques:600},entrepot_psm:{bois:0,metal:0,derives_petrochimiques:0},manquant_psm:{bois:1200,metal:1200,derives_petrochimiques:600}}));return [{modele:'bateau_3',jours:1,total:7,etat:'bloque_matieres',verse:39857,prix_total:90000},{modele:'bateau_5',jours:10,total:10,etat:'acheve',verse:150000,prix_total:150000,bateau_id:'identifiant-unique-fixture',bateau:{passagers:5,fret:500}}];}`});
  await page.addScriptTag({path:path.join(R,'plateau-naval.js')});
  await page.evaluate(()=>ouvrirDevisChantierNaval());
  assert.equal(await page.locator('#postes-body button').count(),2);
  const texte=await page.locator('#postes-body').innerText();
  for(const valeur of ['7 jours effectifs','10 jours effectifs','Bloqué : matériaux insuffisants','identifiant-unique-fixture','5 places, 500 unités de fret','navigation privée non encore activée'])assert.ok(texte.includes(valeur),valeur);
  assert.ok(await page.locator('#modal-postes').evaluate(e=>e.classList.contains('open')));
  assert.ok(await page.locator('.modal-box').evaluate(e=>e.getBoundingClientRect().width<=innerWidth),'aucun débordement horizontal');
  // Refuser explicitement la confirmation ne doit appeler aucun moteur d'achat.
  page.once('dialog',d=>d.dismiss());await page.locator('#postes-body button').first().click();
 }finally{if(browser)await browser.close();try{if(chrome)await chrome.arreter();}finally{if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}fs.rmSync(profil,{recursive:true,force:true});}}
});
