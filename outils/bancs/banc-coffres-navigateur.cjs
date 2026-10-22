// Chromium reel, transports de fixture uniquement ; aucun compte ni acces Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright'),acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
function extraire(f,noms){const s=fs.readFileSync(path.join(root,f),'utf8');return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)||n.type==='VariableDeclaration'&&n.declarations.some(d=>noms.includes(d.id.name))).map(n=>s.slice(n.start,n.end)).join('\n');}
test('coffres Chromium : catalogue annuel, objets echappes, quantite stricte, inventaire relu',async()=>{
 const executablePath=process.env.CHROMIUM_BIN||['/usr/bin/chromium','/usr/bin/chromium-browser','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(p=>fs.existsSync(p));assert.ok(executablePath,'Chromium doit etre installe');
 const browser=await chromium.launch({executablePath,headless:true,args:['--no-sandbox']});
 const serveur=require('node:http').createServer((req,res)=>{res.setHeader('Content-Type','text/html; charset=utf-8');res.end('<div id="modal-postes"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div>');});
 try{
  await new Promise((resolve,reject)=>{serveur.once('error',reject);serveur.listen(0,'127.0.0.1',resolve);});
  const page=await browser.newPage();await page.goto('http://127.0.0.1:'+serveur.address().port);
  await page.addScriptTag({content:`window.state={char:{name:'Alice'},country:'republic',currentCity:'capitale',currentBuilding:'banque-nationale',currentRoom:'coffre_privatif'};window.requetes=[];window.messages=[];window.inv=[{name:'Tableau <img src=x>',regime:'individuel',exemplaire:{id:'original-69'},provenance:{notes:['histoire']}}];window.contenu=[];
  window.rpAuthUid=()=> 'fixture';window.rpAuthSessionIdentifiant=()=> 'fixture-session';window.contexteNavigationRue=()=>({uid:'fixture',nom:state.char.name});window.contexteNavigationRueValide=c=>c.nom===state.char.name;
  window.showToast=(...a)=>messages.push(a);window.updateUI=()=>{};window.rafraichirRuntimeHelvetia=async()=>({pa:29});
  window.sbInventaireReceptionEtat=async()=>sbMarquerInventaires({ok:true,inventory:JSON.parse(JSON.stringify(inv)),revision:contenu.length?4:3},sbContexteInventaire());
  window.sbRpcVerdict=async(rpc,args)=>{requetes.push({rpc,args});
   if(rpc==='coffre_catalogue')return {ok:true,offres:[{taille:'S',capacite:50,tarifAnnuel:250},{taille:'M',capacite:100,tarifAnnuel:450},{taille:'L',capacite:150,tarifAnnuel:750},{taille:'XL',capacite:400,tarifAnnuel:1250}],coffres:[{id:'fixture-id',taille:'S',occupation:contenu.length,capacite:50,revisionCoffre:0,tarifAnnuel:250,renouvellementAnnuel:'2027-10-22'}]};
   if(rpc==='coffre_lire')return sbMarquerInventaires({ok:true,coffre:'fixture-id',inventory:JSON.parse(JSON.stringify(inv)),contenu,capacite:50,occupation:contenu.length,revision:3,revisionCoffre:0},sbContexteInventaire());
   if(rpc==='coffre_transferer'){contenu=JSON.parse(JSON.stringify(inv));inv=[];return {ok:true,inventory:['ancien recu']};}
   if(rpc==='coffre_recu')return {ok:true,terminee:false};throw Error('RPC inattendue '+rpc);
  };`});
  await page.addScriptTag({content:extraire('supabase.js',['RP_INVENTAIRE_ORIGINE','sbEmpreinteInventaire','sbContexteInventaire','sbMarquerInventaires','sbAdopterInventaireServeur'])});
  await page.addScriptTag({content:fs.readFileSync(path.join(root,'plateau-banque-nationale.js'),'utf8')});
  await page.evaluate(()=>ouvrirCoffresBancaires());assert.match(await page.locator('#postes-body').innerText(),/250 FR\/an/);assert.doesNotMatch(await page.locator('#postes-body').innerText(),/600/);
  await page.getByRole('button',{name:'Ouvrir',exact:true}).click();await page.waitForSelector('#coffre-q-deposer-0');assert.equal(await page.locator('img').count(),0);
  await page.locator('#coffre-q-deposer-0').fill('1.5');await page.getByRole('button',{name:'Déposer',exact:true}).click();assert.equal(await page.evaluate(()=>requetes.filter(r=>r.rpc==='coffre_transferer').length),0);
  await page.locator('#coffre-q-deposer-0').fill('1');await page.getByRole('button',{name:'Déposer',exact:true}).click();await page.waitForFunction(()=>state.inventory.length===0);
  const actions=await page.evaluate(()=>requetes.filter(r=>r.rpc==='coffre_transferer'));assert.equal(actions.length,1);assert.equal(actions[0].args.p_quantite,1);assert.equal(actions[0].args.p_signature.exemplaire.id,'original-69');assert.deepEqual(actions[0].args.p_signature.provenance,{notes:['histoire']});assert.equal(actions[0].args.p_revision_inventaire,3);
 }finally{await browser.close();if(serveur.listening)await new Promise(resolve=>serveur.close(resolve));}
});
