// CSS et rendus réels ; courrier/éditeur de fixture. Aucun compte, aucun envoi distant.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
const {chromium}=require('../e2e/node_modules/playwright');
const acorn=require('../e2e/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),source=fs.readFileSync(path.join(root,'forum.js'),'utf8');
const noms=['renderForumContent','renderMailView','renderMailRead','renderMailCompose','replyToMail','escapeHtmlText'];
const code=acorn.parse(source,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>source.slice(n.start,n.end)).join('\n');
async function scenario(largeur,ancien=false){
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-mails-'));let chrome,navigateur;
 try{
  chrome=await lancerChromium({executable:process.env.HG_CHROMIUM||'/usr/bin/chromium',profil});
  navigateur=await chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
  const page=await navigateur.contexts()[0].newPage();await page.setViewportSize({width:largeur,height:720});
  await page.route('**/*',r=>r.abort());
  const css=fs.readFileSync(path.join(root,'style.css'),'utf8');
  await page.setContent('<style>'+css+'</style><div id="modal-forum" class="modal-overlay open"><div class="modal-box modal-fullscreen"><div class="modal-header">Messagerie</div><div id="forum-body"><div class="forum-layout"><div class="forum-sidebar">Courrier</div><div class="forum-main" id="forum-main"></div></div></div></div></div>');
  await page.addScriptTag({content:`var forumView='mail',mailView='read',currentMailId='fiction',mailDefaultTo='',state={char:{name:'Temoin'},contacts:[]},envois=0;
   function getMails(){return [{id:'fiction',to:'Temoin',from:'Jodie Moitout',subject:'Proposition',body:'<p>Texte long de consultation.</p>'.repeat(100),time:'date'}];}
   function extraireActionsMail(corps){return {corps,actions:[]};} function boutonsActionMail(){return '';}
   function sanitizeRichHtml(x){return x;} function formatDateAffichage(){return 'date de fixture';}
   function renderEnvoyerMailEnTantQue(){return '';}
   function renderRichEditor(id){return '<div id="'+id+'" contenteditable="true" style="min-height:1800px">Réponse longue de fixture</div>';}
   function submitMail(){envois++;}
   ${ancien?code.replace("modalForumEl.classList.toggle('forum-mail-scroll', forumView === 'mail');",'// Ancien défaut : classe de défilement absente.'):code}
   document.getElementById('forum-main').innerHTML=renderForumContent();`});
  const accessible=async selecteur=>{
   await page.locator('#forum-main').hover();await page.mouse.wheel(0,20000);await page.waitForTimeout(200);
   return page.locator(selecteur).evaluate(el=>{const r=el.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;return r.top>=0&&r.bottom<=innerHeight&&r.width>0&&document.elementFromPoint(x,y)?.closest('button')===el;});
  };
  const reponse=await accessible('button[data-mail-from]');
  if(ancien)return {reponse};
  assert.equal(reponse,true,'Répondre doit être accessible après lecture du courrier long');
  await page.locator('button[data-mail-from]').click();
  assert.equal(await accessible('.forum-submit-btn'),true,'Envoyer doit rester accessible après réponse longue');
  await page.locator('.forum-submit-btn').click();assert.equal(await page.evaluate(()=>envois),1);
  return {reponse};
 }finally{
  if(navigateur)await navigateur.close();
  if(chrome)await chrome.arreter();
  fs.rmSync(profil,{recursive:true,force:true});
 }
}
for(const largeur of [390,1280])test('courrier long, réponse et Envoyer accessibles — '+largeur,{timeout:45000},()=>scenario(largeur));
test('contre-épreuve : ancien défilement bloqué détecté',{timeout:45000},async()=>{assert.equal((await scenario(1280,true)).reponse,false);});
