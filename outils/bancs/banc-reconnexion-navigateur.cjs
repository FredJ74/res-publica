const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright');const acorn=require('../vercel/node_modules/acorn');const root=path.resolve(__dirname,'../..');
test('reconnexion integree Chromium : compte different refuse, bon compte synchronise sans relance',async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 try{const page=await browser.newPage();await page.goto('about:blank');
 const src=fs.readFileSync(path.join(root,'plateau-core.js'),'utf8'),f=acorn.parse(src,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='afficherBandeauReconnexion');
 await page.addScriptTag({content:`const state={char:{name:'Fixture'},userId:'uid'};let lectures=0,connexions=0;const rpAuthUid=()=> 'uid';const rpAuthIdentiteMemorisee=()=>({email:'fixture@example.invalid'});const rpAuthSeConnecter=async(e,p,o)=>{connexions++;return {ok:p==='bon-secret'&&o.uidAttendu==='uid',raison:'identite_differente'};};const sbRpc=async()=> 'Fixture';const rpRealitesSynchroniser=async()=>{lectures++;return {ok:true};};const showToast=()=>{};${src.slice(f.start,f.end)};afficherBandeauReconnexion();`});
 await page.locator('input[type=password]').fill('mauvais-secret');await page.locator('button[type=submit]').click();await page.waitForFunction(()=>connexions===1);assert.equal(await page.locator('#bandeau-reconnexion').count(),1);assert.equal(await page.evaluate(()=>lectures),0);
 await page.locator('input[type=password]').fill('bon-secret');await page.locator('button[type=submit]').click();await page.waitForFunction(()=>!document.getElementById('bandeau-reconnexion'));assert.equal(await page.evaluate(()=>lectures),1);
 }finally{await browser.close();}
});
