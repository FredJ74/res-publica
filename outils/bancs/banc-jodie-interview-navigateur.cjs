// Interview de Jodie Moitout reçue par messagerie (clôture Luthécia, 01/11/2026).
// Rendu réel dans Chromium : style.css, renderForumContent/renderMailView (forum.js) et les
// fonctions Jodie de plateau-communication.js, extraites telles quelles. Aucun compte, aucun
// appel distant : l'API /api/jodie-portrait est une fixture qui compte ses appels.
// Vérifie : les cinq questions atteignables, réponses conservées entre les pages et après un
// refus serveur, « Envoyer » visible et cliquable (390 et 1280 px), réponse vide refusée,
// double clic = un seul appel, réponse tardive après sortie de l'écran sans écrasement ni perte.
// Contre-épreuve : la version de main df67186 (sans verrou) lance deux rédactions au double clic.
// Usage : HG_CHROMIUM=<chrome> node outils/bancs/banc-jodie-interview-navigateur.cjs
//         CONTRE=<ref git> … : rejoue le double clic contre une ancienne version (doit échouer).
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{execFileSync}=require('node:child_process');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const {chromium}=require('../e2e/node_modules/playwright');
const acorn=require('../e2e/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
const lire=(f,ref)=>ref?execFileSync('git',['show',ref+':'+f],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,f),'utf8');
function extraire(source,noms){
 return acorn.parse(source,{ecmaVersion:'latest'}).body.filter(n=>
  (n.type==='FunctionDeclaration'&&noms.includes(n.id.name))||
  (n.type==='VariableDeclaration'&&n.declarations.some(d=>noms.includes(d.id.name)))
 ).map(n=>source.slice(n.start,n.end)).join('\n');
}
function code(ref){
 return extraire(lire('forum.js'),['renderForumContent','renderMailView','escapeHtmlText'])+'\n'+
  extraire(lire('plateau-communication.js',ref),['JODIE_QUESTIONS_INTERVIEW','JODIE_PORTRAIT_TITRE_PREFIXE','jodiePortraitOuvrirInterview',
   'jodieInterviewAllerPage','renderJodieInterviewForm','jodiePortraitGenererApercu','renderJodiePortraitPreview']);
}
async function ouvrir(largeur,ref){
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-jodie-'));
 const chrome=await lancerChromium({executable:process.env.HG_CHROMIUM||'/usr/bin/chromium',profil});
 const navigateur=await chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
 const page=await navigateur.contexts()[0].newPage();await page.setViewportSize({width:largeur,height:720});
 await page.route('**/*',r=>r.abort());
 await page.setContent('<style>'+lire('style.css')+'</style><div id="modal-forum" class="modal-overlay open"><div class="modal-box modal-fullscreen"><div class="modal-header">Messagerie</div><div id="forum-body"><div class="forum-layout"><div class="forum-sidebar"><button id="vers-inbox" onclick="mailView=\'inbox\';document.getElementById(\'forum-main\').innerHTML=renderForumContent()">Courrier</button></div><div class="forum-main" id="forum-main"></div></div></div></div></div>');
 await page.addScriptTag({content:`var forumView='mail',mailView='inbox',currentForumId=null,state={char:{name:'Temoin'}},appels=[],toasts=[],reponseApi=null,attente=null;
  function renderMailInbox(){return '<div id="inbox">Boîte de réception</div>';}
  function showToast(t,m,ok){toasts.push({t,m,ok});}
  async function jodiePortraitADejaRefuse(){return false;} async function jodiePortraitDejaPublie(){return false;}
  async function jodiePortraitRefuser(){} async function jodiePortraitPublier(){}
  async function jodiePortraitAppelApi(p){appels.push(JSON.parse(JSON.stringify(p)));if(attente)await attente;return reponseApi||{ok:true,texte:'Portrait de fixture',jeton:'j1'};}
  ${code(ref)}`});
 const fermer=async()=>{await navigateur.close();await chrome.arreter();fs.rmSync(profil,{recursive:true,force:true});};
 return {page,fermer};
}
// Bouton visible dans la fenêtre, après défilement, et premier élément sous son centre.
async function accessible(page,selecteur){
 await page.locator('#forum-main').hover();await page.mouse.wheel(0,20000);await page.waitForTimeout(150);
 return page.locator(selecteur).evaluate(el=>{const r=el.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;
  return r.top>=0&&r.bottom<=innerHeight&&r.width>0&&document.elementFromPoint(x,y)?.closest('button')===el;});
}
const longue=i=>('Réponse '+(i+1)+' ').padEnd(480,'x');
async function remplirCinq(page){
 for(let i=0;i<5;i++){
  assert.match(await page.locator('#forum-main').innerText(),new RegExp('Question '+(i+1)+' sur 5'));
  await page.fill('#jodie-reponse-'+i,longue(i));
  if(i<4){assert.equal(await accessible(page,'button:has-text("Suivant")'),true,'Suivant accessible page '+(i+1));await page.click('button:has-text("Suivant")');}
 }
}

for(const largeur of [390,1280])test('cinq questions, réponses conservées, Envoyer accessible — '+largeur,{timeout:60000},async()=>{
 const {page,fermer}=await ouvrir(largeur);
 try{
  await page.evaluate(()=>jodiePortraitOuvrirInterview());
  await remplirCinq(page);
  // Retour en arrière : les réponses déjà saisies sont toujours là.
  for(let i=3;i>=0;i--){await page.click('button:has-text("Précédent")');assert.equal(await page.inputValue('#jodie-reponse-'+i),longue(i));}
  for(let i=0;i<4;i++)await page.click('button:has-text("Suivant")');
  assert.equal(await page.inputValue('#jodie-reponse-4'),longue(4));
  assert.equal(await accessible(page,'button:has-text("Envoyer mes réponses")'),true,'Envoyer visible et cliquable');
  await page.click('button:has-text("Envoyer mes réponses")');
  await page.waitForFunction(()=>mailView==='jodie-preview');
  const a=await page.evaluate(()=>appels);
  assert.equal(a.length,1);assert.equal(a[0].action,'apercu');assert.deepEqual(a[0].reponses,[0,1,2,3,4].map(longue));
  assert.match(await page.locator('#forum-main').innerText(),/Portrait de fixture/);
 }finally{await fermer();}
});

test('réponse vide refusée sans appel serveur ; refus serveur nommé, réponses intactes',{timeout:60000},async()=>{
 const {page,fermer}=await ouvrir(1280);
 try{
  await page.evaluate(()=>jodiePortraitOuvrirInterview());
  await remplirCinq(page);
  await page.click('button:has-text("Précédent")');await page.fill('#jodie-reponse-3','   ');await page.click('button:has-text("Suivant")');
  await page.click('button:has-text("Envoyer mes réponses")');
  assert.equal(await page.evaluate(()=>appels.length),0);
  assert.equal(await page.evaluate(()=>toasts.at(-1).t),'Réponses incomplètes');
  await page.click('button:has-text("Précédent")');await page.fill('#jodie-reponse-3',longue(3));await page.click('button:has-text("Suivant")');
  await page.evaluate(()=>{reponseApi={ok:false,error:'Jodie est indisponible.'};});
  await page.click('button:has-text("Envoyer mes réponses")');
  await page.waitForFunction(()=>toasts.length>=2);
  assert.deepEqual(await page.evaluate(()=>[toasts.at(-1).m,mailView]),['Jodie est indisponible.','jodie-interview']);
  assert.deepEqual(await page.evaluate(()=>window._jodieInterviewReponses),[0,1,2,3,4].map(longue));
  assert.equal(await accessible(page,'button:has-text("Envoyer mes réponses")'),true);
 }finally{await fermer();}
});

async function doubleClic(ref){
 const {page,fermer}=await ouvrir(1280,ref);
 try{
  await page.evaluate(()=>{window._jodieInterviewReponses=['a','b','c','d','e'];window._jodieInterviewPage=4;mailView='jodie-interview';
   document.getElementById('forum-main').innerHTML=renderForumContent();let ouvrirPorte;attente=new Promise(r=>{ouvrirPorte=r;});window.ouvrirPorte=ouvrirPorte;});
  await page.evaluate(()=>{jodiePortraitGenererApercu();jodiePortraitGenererApercu();});
  await page.evaluate(()=>window.ouvrirPorte());
  await page.waitForFunction(()=>mailView==='jodie-preview');
  return await page.evaluate(()=>appels.length);
 }finally{await fermer();}
}
test('double clic sur Envoyer : une seule rédaction demandée',{timeout:60000},async()=>{assert.equal(await doubleClic(process.env.CONTRE),1);});

test('réponse tardive après sortie de l écran : pas d écrasement, aperçu retrouvé à la réouverture',{timeout:60000},async()=>{
 const {page,fermer}=await ouvrir(1280);
 try{
  await page.evaluate(()=>{window._jodieInterviewReponses=['a','b','c','d','e'];window._jodieInterviewPage=4;mailView='jodie-interview';
   document.getElementById('forum-main').innerHTML=renderForumContent();let o;attente=new Promise(r=>{o=r;});window.ouvrirPorte=o;});
  await page.evaluate(()=>{jodiePortraitGenererApercu();});
  await page.click('#vers-inbox');
  await page.evaluate(()=>window.ouvrirPorte());
  await page.waitForFunction(()=>toasts.length>=1);
  assert.equal(await page.evaluate(()=>mailView),'inbox');
  assert.equal(await page.locator('#inbox').count(),1,'la boîte de réception reste affichée');
  await page.evaluate(()=>jodiePortraitOuvrirInterview());
  assert.equal(await page.evaluate(()=>mailView),'jodie-preview');
  assert.equal(await page.evaluate(()=>appels.length),1,'aucune nouvelle rédaction');
 }finally{await fermer();}
});
