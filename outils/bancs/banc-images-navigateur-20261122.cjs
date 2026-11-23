// Plateau réel et fragments de présentation réels ; aucune session ni RPC de production.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {avecJeu,page,R}=require('./mobile-navigateur.cjs');
const acorn=require('../vercel/node_modules/acorn');
const lire=f=>fs.readFileSync(path.join(R,f),'utf8');
function fonction(f,nom){const s=lire(f),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);assert.ok(n,nom);return s.slice(n.start,n.end);}
const nav=lire('plateau-navigation.js');
// Isoler le bloc qui choisit et affiche le fond, sans exécuter une entrée de pièce métier.
const a=nav.indexOf('  const empireRoomImg ='),b=nav.indexOf('  // Le décor personnalisé doit rester entier',a);
assert.ok(a>0&&b>a);const image=nav.slice(a,b);
for(const w of [320,390,1280])test(`images PSM, portrait du cabinet et retour confirmé, neuf langues, ${w}px`,{timeout:90000},async()=>avecJeu(async(browser,origine)=>{
 const p=await page(browser,origine,w,900,false,{texteMinimum:true});let requetesMetier=0;
 p.on('request',r=>{if(r.method()!=='GET')requetesMetier++;});
 await p.context().route('**/images/**',route=>{
  const u=new URL(route.request().url());if(u.origin!==origine)return route.abort();
  const f=path.join(R,decodeURIComponent(u.pathname));
  try{const body=fs.readFileSync(f),ext=path.extname(f);return route.fulfill({status:200,contentType:ext==='.webp'?'image/webp':ext==='.png'?'image/png':ext==='.svg'?'image/svg+xml':'image/jpeg',body});}catch{return route.fulfill({status:404,body:''});}
 });
 await p.addScriptTag({content:`var state={country:'republic',currentCity:'ville_a',char:null,pa:70,arg:200,dis:45};var appelsImages=0;var navigationInterieureRendu=null;
 function sbRpc(){appelsImages++;throw Error('RPC interdite');} function sbRpcVerdict(){appelsImages++;throw Error('RPC interdite');}
 var PNJ_AVATAR={default:{},chef_cabinet:{}};var RP_STATUTS_JUDICIAIRES={};
 var appliquerRemplacantCodetenu=x=>x,filtrerPnjPostesPourvus=x=>x,getSimulesPresents=()=>[],getGroupeHtmlPourPiece=()=>'',chargerVraisJoueursPresents=()=>{},encodePnjSafe=p=>encodeURIComponent(JSON.stringify(p)),marqueurMutinHtml=()=>'',marqueursJudiciairesHtml=()=>'';
 function getLocationPourRoom(){return null;} function applyEmpireTheme(){} function buildCityTabs(){}
 `});
 for(const f of ['data.js','plateau-variantes-pieces.js','plateau-images.js'])await p.addScriptTag({url:origine+'/'+f});
 await p.addScriptTag({content:fonction('plateau-navigation.js','getBuildingContext')+'\n'+fonction('plateau-multijoueur.js','personnesNormalesDeLaPiece')+'\n'+fonction('plateau-multijoueur.js','renderPersonsList')+'\n'+fonction('plateau-navigation.js','afficherPositionNavigationConfirmee')});
 await p.evaluate(fragment=>{
  window.dessinerImage=new Function('buildingId','roomId',`const ctx=getBuildingContext(buildingId),room=BUILDINGS[buildingId].rooms?.[roomId]||ctx?.roomsExtra?.[roomId],roomOverride=ctx?.roomOverrides?.[roomId];`+fragment+';return imgUrl;');
  window.enterBuilding=(id)=>{state.currentBuilding=id;};window.enterRoom=(id,r)=>{state.currentRoom=r;return dessinerImage(id,r);};
  window.retourImage={};
  document.querySelectorAll('.vue').forEach(e=>e.classList.remove('active'));document.getElementById('vue-batiment').classList.add('active');
  const champ=document.createElement('input');champ.id='images-saisie';champ.value='Brouillon conservé';document.body.appendChild(champ);
 },image);
 const resultat=await p.evaluate(async()=>{
  const langues=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'],images=new Set();let rendus=0;
  for(const langue of langues){document.documentElement.lang=langue;document.documentElement.dir=langue==='ar'?'rtl':'ltr';
   state.country='republic';state.currentCity='ville_a';
   for(const id of WORLD.republic.ville_a.buildings){const ctx=getBuildingContext(id)||{},b=BUILDINGS[id];for(const r of Object.keys({...b.rooms,...ctx.roomsExtra})){
    if(ctx.roomsExclues?.includes(r))continue;state.currentBuilding=id;state.currentRoom=r;const avant=JSON.stringify(state);
    const u=dessinerImage(id,r);if(u)images.add(u);if(JSON.stringify(state)!==avant)throw Error('état modifié');rendus++;
   }}
   state.currentCity='capitale';state.currentBuilding='palais-gouvernement';state.currentRoom='bureaux';
   const chef=personnesNormalesDeLaPiece('palais-gouvernement','bureaux').find(p=>p.job==='chef_cabinet');if(!chef)throw Error('chef absent');renderPersonsList([chef]);
   const portrait=document.querySelector('#persons-list img');portrait.loading='eager';await Promise.race([portrait.decode().catch(e=>{throw Error('portrait '+portrait.src+' : '+e.message)}),new Promise((_,rej)=>setTimeout(()=>rej(Error('portrait : attente de décodage')),5000))]);if(!portrait.naturalWidth)throw Error('portrait non décodé');
   // La confirmation officielle désigne le Centre Multimodal, même après une ancienne rue visitée.
   const id=WORLD.republic.capitale.buildings.find(id=>id.includes('multinodal'));
   const r=Object.keys(BUILDINGS[id].rooms)[0];state.currentCity='ville_a';window.rueCentraleDerniersNoeuds={'republic|capitale':{noeudId:'luthecia-palais-gouvernement'}};
   afficherPositionNavigationConfirmee({country:'republic',currentCity:'capitale',currentBuilding:id,currentRoom:r,group:[],pa:70});
   if(state.currentBuilding!==id||state.currentRoom!==r)throw Error('arrivée ailleurs que le Centre Multimodal');
   images.add(dessinerImage(id,r));
  }
  const distantes=[...images].filter(u=>/^https?:/.test(u));
  if(distantes.length!==1||!distantes[0].startsWith('https://images.unsplash.com/photo-1555848962-6e79363ec58f'))throw Error('nouvelle image distante inattendue');
  for(const url of images){if(/^https?:/.test(url))continue;const img=new Image();img.src=url;await Promise.race([img.decode().catch(e=>{throw Error(url+' : '+e.message)}),new Promise((_,rej)=>setTimeout(()=>rej(Error('image : '+url)),5000))]);if(!img.naturalWidth)throw Error('image non décodée : '+url);}
  return{rendus,imagesLocales:images.size-distantes.length,images:images.size,distantesNonDecodees:distantes.length,pa:state.pa,arg:state.arg,saisie:document.getElementById('images-saisie').value,rpc:appelsImages,largeur:document.documentElement.scrollWidth,viewport:innerWidth};
 });
 assert.ok(resultat.rendus>500);assert.ok(resultat.images>60);assert.equal(resultat.pa,70);assert.equal(resultat.arg,200);assert.equal(resultat.saisie,'Brouillon conservé');assert.equal(resultat.rpc,0);assert.equal(requetesMetier,0);
 assert.ok(resultat.largeur<=resultat.viewport+1,JSON.stringify(resultat));
 console.log(JSON.stringify({viewport:w,...resultat,personnage_connecte:false}));
 await p.close();
}));
