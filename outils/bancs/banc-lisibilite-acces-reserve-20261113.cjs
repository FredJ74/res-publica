'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const repository=path.resolve(__dirname,'../..'),root=process.env.ACCESS_ASSET_DIR||repository;
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
// Preuve figée sur la PR #880 elle-même (13/11, Claude) : avant = a1ac64a (main avant la fusion), après = 7df7525
// (fusion). L'ancienne comparaison à merge-base(HEAD, origin/main) refusait toute PR ultérieure touchant data.js,
// plateau-navigation.js, api, migrations ou supabase (même défaut que les bancs #849, #852 et #855).
const base=process.env.ACCESS_BASE_REV||'a1ac64affc10eb7064b2cb208ff1d25eed321788',tete='7df7525ea0d19264bda3b054759384831123c4be';
const old=f=>execFileSync('git',['show',base+':'+f],{cwd:repository,encoding:'utf8',maxBuffer:8e6});
const source=read('plateau-acces-reserve.js');
function sansHabillage(s){return s.replace(/^\/\/ Marqueur de présentation[^\n]*\n/m,'').replace(/const accesModal =[\s\S]*?(?=const accesFermer =)/,'');}
test('seul l’adaptateur de présentation change ; textes et fonctions métier restent exacts',()=>{
 assert.equal(sansHabillage(source),sansHabillage(old('plateau-acces-reserve.js')));
 const paths=execFileSync('git',['diff','--name-only',base,tete,'--','data.js','plateau-navigation.js','plateau-router.js','plateau-vehicules.js','plateau-sovarka-droits.js','migrations','api','supabase'],{cwd:repository,encoding:'utf8'});assert.equal(paths,'');
 assert.ok(source.includes('class="acces-reserve-dialogue"'));
});
function fonction(s,name){const start=s.indexOf('function '+name+'(');assert.ok(start>=0,name);return s.slice(start,s.indexOf('\n}',start)+2);}
async function setup(page,original){
 const asset=f=>original?old(f):read(f),html=asset('plateau.html'),start=html.indexOf('<div id="modal-postes"');
 await page.route('**/*',r=>r.abort());
 await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body empire-soviet">'+html.slice(start,html.indexOf('\n\n',start))+'</body></html>');
 await page.addStyleTag({content:asset('style.css')});
 await page.evaluate(()=>{
  window.state={char:{name:'Fixture'},country:'soviet',currentBuilding:'residence-imperiale-novomirsk',pa:20,arg:10000};window.calls=[];window.actions=[];
  window.locale='fr';window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>locale};
  window.NEUTRALISER_MODES={mains:{label:'À mains nues'},arme:{label:'Arme de test'}};window.neutraliserPossedeArme=()=>true;
  window.residence={ok:true,piece_courante:'appartement_1',ma_location:{piece:'appartement_1',prix_nuit:1000,fin:'2026-11-16T12:00',minibar:2},appartements:[{piece:'appartement_1',prix_nuit:1000,libre:true},{piece:'grand_appartement',prix_nuit:1800,libre:false}]};
  window.sbRpcVerdict=async(name,args)=>{calls.push([name,args]);if(name==='residence_etat')return residence;throw Error('Acte serveur inattendu');};
  window.fetch=()=>{throw Error('Réseau inattendu');};
 });
 const veh=asset('plateau-vehicules.js');await page.addScriptTag({content:fonction(veh,'vehModal')+'\n'+veh.slice(veh.indexOf('const vehSection ='),veh.indexOf('const vehChamp ='))});
 const sov=asset('plateau-sovarka-droits.js');await page.addScriptTag({content:fonction(sov,'sovModal')+'\n'+fonction(sov,'sovarkaRerendreFenetre')});
 await page.addScriptTag({content:asset('plateau-acces-reserve.js')});
 await page.evaluate(()=>{
  for(const fn of ['accesForcerPassage','accesCombattreGarde','residenceAgir'])window[fn]=(...args)=>actions.push([fn,args]);
  window.openExample=async(kind)=>{
   state.currentBuilding=kind.startsWith('pavillon')?'pavillon-ambassadeurs-novomirsk':'residence-imperiale-novomirsk';
   if(kind==='residence')accesReserveRefus({raison:'location_requise',piece:'appartement_1'});
   if(kind==='invite')accesReserveRefus({raison:'un_seul_invite',piece:'grand_appartement'});
   if(kind==='pavillon')accesReserveRefus({raison:'acces_dignitaires',piece:'bar'});
   if(kind==='pavillon-info')ouvrirAccesReserveInfo();
   if(kind==='garde')accesAfficherGarde({garde:'Garde de test',taux:60,jet:70,pnj:'garde_acces:fixture'});
   if(kind==='reservation'){accesEtatResidence=null;const saved=residence.ma_location;residence.ma_location=null;await ouvrirResidenceReservation();residence.ma_location=saved;}
   if(kind==='location'){accesEtatResidence=null;await ouvrirResidenceLocation();}
   if(kind==='minibar'){accesEtatResidence=null;await ouvrirResidenceMinibar();}
  };
  window.textes=()=>({title:document.getElementById('postes-modal-title').textContent,body:document.getElementById('postes-body').textContent,buttons:[...document.querySelectorAll('#postes-body button')].map(b=>({text:b.textContent,action:b.getAttribute('onclick')}))});
  window.dimensions=()=>{const box=document.querySelector('#modal-postes .modal-box'),title=document.getElementById('postes-modal-title'),p=document.querySelector('#postes-body p'),note=document.querySelector('#postes-body .cpj-note'),button=document.querySelector('#postes-body button'),style=e=>e?getComputedStyle(e):null;return {title:style(title).fontSize,body:style(p)?.fontSize,line:style(p)?.lineHeight,note:style(note)?.fontSize,button:style(button)?.fontSize,background:style(box).backgroundColor,border:style(box).borderColor,font:style(title).fontFamily,width:box.getBoundingClientRect().width,height:box.getBoundingClientRect().height};};
 });
}
test('Chromium : huit écrans, 320/390/1280 et hauteur réduite, langues existantes, boutons et modales voisines',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 const proofs=[];
 try{for(const [width,height] of [[320,640],[390,780],[1280,900],[390,360]]){
  const page=await browser.newPage({viewport:{width,height}}),before=await browser.newPage({viewport:{width,height}}),errors=[];page.on('pageerror',e=>errors.push(String(e)));await setup(page,false);await setup(before,true);
  for(const kind of ['residence','invite','pavillon','pavillon-info','garde','reservation','location','minibar']){
   for(const lang of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']){
    for(const p of [page,before])await p.evaluate(async({kind,lang})=>{locale=lang;await openExample(kind);},{kind,lang});
    assert.deepEqual(await page.evaluate(()=>textes()),await before.evaluate(()=>textes()),kind+'/'+lang+' : textes/actions identiques');
    const dim=await page.evaluate(()=>dimensions());assert.ok(parseFloat(dim.title)>=30);assert.ok(parseFloat(dim.body)>=17.92-0.01,JSON.stringify({kind,lang,width,dim}));assert.ok(parseFloat(dim.line)/parseFloat(dim.body)>=1.55);assert.ok(parseFloat(dim.line)/parseFloat(dim.body)<=1.65);
    if(dim.note)assert.ok(parseFloat(dim.note)>=17.92-0.01);if(dim.button)assert.ok(parseFloat(dim.button)>=16);
    const oldDim=await before.evaluate(()=>dimensions());for(const key of ['background','border','font'])assert.equal(dim[key],oldDim[key],key);
    const snapshot=await page.evaluate(()=>JSON.stringify({state,calls,actions}));
    const buttons=page.locator('#postes-body button');for(let i=0;i<await buttons.count();i++){
     const b=buttons.nth(i);await b.scrollIntoViewIfNeeded();const rect=await b.boundingBox();assert.ok(rect.height>=44);assert.ok(rect.x>=0&&rect.x+rect.width<=width+1);assert.ok(rect.y>=0&&rect.y+rect.height<=height+1);
    }
    assert.equal(await page.evaluate(()=>JSON.stringify({state,calls,actions})),snapshot);
    if(lang==='fr')for(let i=0;i<await buttons.count();i++){
     const n=await page.evaluate(()=>actions.length);await buttons.nth(i).focus();await page.keyboard.press('Enter');
     assert.equal(await page.evaluate(()=>actions.length),n+1,'une seule action par activation');
     await before.locator('#postes-body button').nth(i).focus();await before.keyboard.press('Enter');
     assert.deepEqual(await page.evaluate(()=>actions.at(-1)),await before.evaluate(()=>actions.at(-1)),'même destinataire et mêmes arguments');
    }
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
    assert.equal(await page.evaluate(()=>{const b=document.querySelector('#modal-postes .modal-box');return b.scrollWidth>b.clientWidth;}),false);
    if(lang==='fr'&&kind==='residence'){
     const count=await page.evaluate(()=>actions.length);await buttons.first().focus();await page.keyboard.press('Enter');assert.equal(await page.evaluate(()=>actions.length),count+1);assert.deepEqual(await page.evaluate(()=>actions.at(-1)),['accesForcerPassage',['appartement_1']]);
     assert.deepEqual(await page.evaluate(()=>({pa:state.pa,arg:state.arg})),{pa:20,arg:10000});
     proofs.push({width,height,before:oldDim,after:dim});
     if(process.env.ACCESS_SCREENSHOTS){fs.mkdirSync(process.env.ACCESS_SCREENSHOTS,{recursive:true});for(const [name,p]of [['avant',before],['apres',page]]){await p.evaluate(()=>document.querySelector('#modal-postes .modal-box').scrollTop=0);await p.screenshot({path:path.join(process.env.ACCESS_SCREENSHOTS,`${name}-${width}-${height}.png`)});}}
    }
    const close=page.locator('#modal-postes .modal-close');await close.focus();await page.keyboard.press('Enter');assert.equal(await page.locator('#modal-postes').evaluate(e=>e.classList.contains('open')),false);
   }
  }
  // Le conteneur partagé reprend exactement le rendu initial après une fenêtre d'accès.
  for(const p of [page,before])await p.evaluate(()=>vehModal('Fenêtre voisine','<p>Autre fenêtre</p><p class="cpj-note">Note voisine</p>'+vehBouton('Autre action','actions.push(["voisine"])',false)));
  assert.deepEqual(await page.evaluate(()=>dimensions()),await before.evaluate(()=>dimensions()));
  await page.evaluate(()=>{window.sovModal=undefined;accesReserveRefus({raison:'location_requise',piece:'appartement_1'});});assert.equal(await page.locator('.acces-reserve-dialogue').count(),1);assert.ok(parseFloat((await page.evaluate(()=>dimensions())).body)>=17.92-0.01);
  assert.deepEqual(errors,[]);await page.close();await before.close();
 }
 if(process.env.ACCESS_SCREENSHOTS)fs.writeFileSync(path.join(process.env.ACCESS_SCREENSHOTS,'mesures.json'),JSON.stringify({base,proofs},null,2)+'\n');
 }finally{await browser.close();}
});
