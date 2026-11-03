// Navigateur réel, déclarations de forum réelles ; fixtures locales sans compte.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const {lancerChromium}=require('../bancs/fixtures/chromium-cdp.cjs');
test('Chromium : forum local au voyage/retour et organisation réservée aux adhérents',async()=>{
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-forums422-'));let chrome,browser;
 const serveur=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html');res.end('<!doctype html><meta charset="utf-8"><div id="navigation"></div>');});
 try{
  await new Promise(r=>serveur.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+serveur.address().port;
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync);assert.ok(executable,'Chromium requis');
  chrome=await lancerChromium({executable,profil});browser=await require('playwright').chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);const contexte=await browser.newContext({serviceWorkers:'block'});
  await contexte.route('**/*',r=>r.request().url().startsWith(origin+'/')?r.continue():r.abort());const page=await contexte.newPage();await page.goto(origin);
  await page.evaluate(()=>{window.state={country:'republic',currentCity:'capitale',char:{name:'Fixture'},organisations:[{id:'tiers',nom:'Organisation du tiers',chef:'Autre',membres:[]}]};window.WORLD={republic:{capitale:{name:'Luthécia'},ville_a:{name:'Port-Sainte-Marie'}}};});
  await page.addScriptTag({path:path.resolve(__dirname,'../../forum.js')});
  await page.evaluate(()=>{forumSousGroupeOuvert=true;document.getElementById('navigation').innerHTML=renderForumCategorieItems('intra')+renderForumCategorieItems('prive');});
  assert.equal(await page.locator('[onclick="switchForum(\'local_capitale\')"]').count(),1);
  assert.equal(await page.locator('[onclick="switchForum(\'org_tiers\')"]').count(),0);
  await page.evaluate(()=>{FORUM_TOPICS.local_capitale=[{id:'ancien'}];state.currentCity='ville_a';document.getElementById('navigation').innerHTML=renderForumCategorieItems('intra');});
  assert.equal(await page.locator('[onclick="switchForum(\'local_ville_a\')"]').count(),1);assert.equal(await page.locator('[onclick="switchForum(\'local_capitale\')"]').count(),0);
  await page.evaluate(()=>{state.currentCity='capitale';state.organisations[0].membres=[{nom:'Fixture'}];document.getElementById('navigation').innerHTML=renderForumCategorieItems('intra')+renderForumCategorieItems('prive');});
  assert.equal(await page.locator('[onclick="switchForum(\'local_capitale\')"]').count(),1);assert.equal(await page.locator('[onclick="switchForum(\'org_tiers\')"]').count(),1);
  assert.equal(await page.evaluate(()=>FORUM_TOPICS.local_capitale),undefined);
  await page.evaluate(()=>{state.organisations=[];document.getElementById('navigation').innerHTML=renderForumCategorieItems('prive');});assert.equal(await page.locator('[onclick="switchForum(\'org_tiers\')"]').count(),0);
 }finally{
  try{await browser?.close();}finally{try{await chrome?.arreter();}finally{await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});}}
 }
});
