// node --experimental-vm-modules --test outils/bancs/banc-continuite-municipale.mjs
// Vrais modules de production, registres et transport simules ; aucune ecriture distante.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {fileURLToPath, pathToFileURL} from 'node:url';
import path from 'node:path';
import {lireTitulaireMunicipal, contexteMunicipal} from '../../continuite-municipale.mjs';
import chat from '../../api/chat.js';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
function registre(poste,etat='pnj') {
 const appels=[];
 const lire=async(table,filtre)=>{
  appels.push({table,filtre});
  if(table==='cycles_electoraux')return etat==='vacant'?[]:[{data:JSON.stringify({eluId:etat==='pj'?'Alice':'Le Maire (PNJ)'})}];
  if(table==='postes_attribues')return etat==='pj'?[{titulaire:'Alice',depuis:'2026-10-01T00:00:00Z'}]:[];
  if(table==='personnages')return etat==='pj'?[{name:'Alice'}]:[];
  if(table==='titulaires_pnj')return etat==='pnj'?[{nom_pnj:'Le Maire Adjoint de Luthecia'}]:[];
  throw Error('Lecture inattendue '+table);
 };
 return {lire,appels};
}
function plateau() {
 const rendus=[];
 const ctx=vm.createContext({console,Date,JSON,setTimeout,clearTimeout,
  addEventListener(){},removeEventListener(){},
  state:{country:'republic',currentCity:'capitale',currentBuilding:'mairie-capitale',currentRoom:'bureau_maire'},
  document:{getElementById:()=>null,querySelectorAll:()=>[]},renderPersonsList:liste=>rendus.push(liste)});
 ctx.window=ctx;
 for(const f of ['data.js','plateau-navigation.js','plateau-organisations-quetes.js','plateau-multijoueur.js']){
  const filename=path.join(ROOT,f);
  vm.runInContext(fs.readFileSync(filename,'utf8'),ctx,{filename,importModuleDynamically:s=>import(new URL(s,pathToFileURL(filename)))});
 }
 ctx.renderPersonsList=liste=>rendus.push(liste);
 ctx.personnesReellesDeLaPiece=ctx.personnesNormalesDeLaPiece;
 ctx.getBuildingContext=()=>vm.runInContext("WORLD[state.country]?.[state.currentCity]?.buildingContext?.['mairie-capitale']",ctx);
 ctx.personnesNormalesDeLaPiece=(b,r)=>ctx.getBuildingContext()?.roomOverrides?.[r]?.persons
   ||vm.runInContext(`BUILDINGS['${b}'].rooms['${r}'].persons`,ctx);
 return {ctx,rendus,run:s=>vm.runInContext(s,ctx)};
}
test('accueil de Luthécia : seul le maire est retiré, bureau et gabarit partagés préservés',()=>{
 const j=plateau();
 const origine=j.run("BUILDINGS['mairie-capitale'].rooms.hall_mairie.persons");
 const accueil=j.ctx.personnesReellesDeLaPiece('mairie-capitale','hall_mairie');
 assert.deepEqual(JSON.parse(JSON.stringify(accueil)),JSON.parse(JSON.stringify(origine.filter(p=>p.job!=='maire'))));
 assert.equal(accueil.some(p=>p.job==='maire'),false);
 assert.equal(j.ctx.personnesReellesDeLaPiece('mairie-capitale','bureau_maire').filter(p=>p.job==='maire').length,1);
 assert.equal(origine.filter(p=>p.job==='maire').length,1);
 assert.equal(j.run("WORLD.republic.ville_a.buildingContext?.['mairie-capitale']"),undefined);
 assert.equal(j.run("WORLD.republic.ville_b.buildingContext?.['mairie-capitale']"),undefined);
});
for(const [poste,piece,role] of [['maire','bureau_maire','Secrétaire général de la mairie'],['maire_adjoint','bureau_maire_adjoint','Secrétaire du maire adjoint']]){
 test(`${poste} : PNJ -> PJ -> vacance, meme personne, meme historique`,async()=>{
  const j=plateau();j.ctx.state.currentRoom=piece;
  const p=j.ctx.personnesNormalesDeLaPiece('mairie-capitale',piece)[0];
  const nom=p.name;p.historique=['ancienne conversation'];
  for(const etat of ['pnj','pj','vacant']){
   const r=registre(poste,etat);j.ctx.sbGet=r.lire;
   await j.ctx.ajusterTitrePnjDePoste('mairie-capitale',piece);
   assert.equal(p.role,etat==='pj'?role:p.roleSiPnjTitulaire);
   assert.equal(p.name,nom);assert.equal(p.job,poste);assert.deepEqual(p.historique,['ancienne conversation']);
   assert.ok(r.appels.every(a=>a.filtre.includes('country=eq.republic')));
   assert.equal(j.ctx.personnesNormalesDeLaPiece('mairie-capitale',piece).length,1);
  }
 });
 test(`${poste} : rechargement en mandat PJ, aucun faux titulaire au demarrage`,async()=>{
  for(let i=0;i<2;i++){
   const j=plateau();j.ctx.state.currentRoom=piece;j.ctx.sbGet=registre(poste,'pj').lire;
   const p=j.ctx.personnesNormalesDeLaPiece('mairie-capitale',piece)[0];
   assert.equal(p.role,'Personnel permanent de la mairie');
   await j.ctx.ajusterTitrePnjDePoste('mairie-capitale',piece);assert.equal(p.role,role);
  }
 });
 test(`${poste} : panne et lecture refusee ne valent jamais vacance`,async()=>{
  const j=plateau();j.ctx.state.currentRoom=piece;j.ctx.sbGet=registre(poste,'pj').lire;
  const p=j.ctx.personnesNormalesDeLaPiece('mairie-capitale',piece)[0];
  await j.ctx.ajusterTitrePnjDePoste('mairie-capitale',piece);
  j.ctx.sbGet=async()=>null;
  await j.ctx.ajusterTitrePnjDePoste('mairie-capitale',piece);assert.equal(p.role,p.roleSiTitulaireInconnu);
 });
 test(`${poste} : une carte ne cree ni mandat ni ecriture Supabase`,async()=>{
  const j=plateau();j.ctx.state.currentRoom=piece;const r=registre(poste,'vacant');j.ctx.sbGet=r.lire;
  j.ctx.sbRpc=()=>assert.fail('Aucune mutation de poste autorisee');
  j.ctx.state.poste={id:poste,city:'capitale'};
  await j.ctx.ajusterTitrePnjDePoste('mairie-capitale',piece);
  assert.equal(j.ctx.personnesNormalesDeLaPiece('mairie-capitale',piece)[0].role.includes('Secrétaire'),false);
 });
}
test('cache electoral perime ignore pour les PNJ permanents',async()=>{
 const j=plateau();j.ctx.CYCLES_ELECTORAUX={republic:{maire_capitale:{eluId:'Ancien'}}};
 j.ctx.sbGet=registre('maire','pj').lire;
 const t=await j.ctx.getTitulaireActuel('maire','capitale','republic',{lectureFraiche:true});assert.equal(t.nom,'Alice');
});
test('les autres villes et le visuel de l’adjoint restent inchanges',()=>{
 const j=plateau();const adj=j.run("BUILDINGS['mairie-capitale'].rooms.bureau_maire_adjoint");
 assert.equal(adj.imageUrl,'images/bureau-maire.webp');assert.equal(adj.persons.length,0);
 assert.equal(j.run("WORLD.republic.ville_a.buildingContext?.['mairie-capitale']"),undefined);
 assert.equal(j.run("WORLD.republic.ville_b.buildingContext?.['mairie-capitale']"),undefined);
 assert.equal(j.run("ROOM_IMAGES_EMPIRE.republic['mairie-capitale'].bureau_maire"),'images/bureau-maire-luthecia.webp?v=fe878010');
});
test('lecture ambigue, cycle malforme et attribution orpheline sont refuses',async()=>{
 await assert.rejects(lireTitulaireMunicipal('maire','republic','capitale',async()=>[{},{}]));
 await assert.rejects(lireTitulaireMunicipal('maire','republic','capitale',async()=>[{data:'{'}]));
 await assert.rejects(lireTitulaireMunicipal('maire_adjoint','republic','capitale',async t=>t==='postes_attribues'?[{titulaire:'Absent'}]:[]));
});
test('reponse tardive ignoree apres un changement de pays',async()=>{
 const j=plateau();let resoudre;
 j.ctx.sbGet=()=>new Promise(r=>{resoudre=r;});
 const ancien=j.ctx.ajusterTitrePnjDePoste('mairie-capitale','bureau_maire');
 await new Promise(r=>setTimeout(r,0));
 j.ctx.state.country='soviet';resoudre([]);await ancien;assert.equal(j.rendus.length,0);
});
test('une ancienne lecture ne remplace pas une fonction plus recente',async()=>{
 const j=plateau();let resoudre;
 j.ctx.sbGet=()=>new Promise(r=>{resoudre=r;});
 const ancien=j.ctx.ajusterTitrePnjDePoste('mairie-capitale','bureau_maire');
 await new Promise(r=>setTimeout(r,0));
 j.ctx.sbGet=registre('maire','pj').lire;
 await j.ctx.ajusterTitrePnjDePoste('mairie-capitale','bureau_maire');
 resoudre([]);await ancien;
 assert.equal(j.ctx.personnesNormalesDeLaPiece('mairie-capitale','bureau_maire')[0].role,'Secrétaire général de la mairie');
 assert.equal(j.rendus.length,1);
});
for(const [profil,poste,titre] of [['le_maire_de_luthecia','maire','Secrétaire général de la mairie'],['le_maire_adjoint_de_luthecia','maire_adjoint','Secrétaire du maire adjoint']]){
 for(const etat of ['pnj','pj','vacant','panne'])test(`dialogue ${poste}/${etat} : fonction lue sous le jeton du joueur, historique conserve`,async()=>{
  const saved=globalThis.fetch;const oldKey=process.env.DEEPSEEK_API_KEY;process.env.DEEPSEEK_API_KEY='test-non-secret';
  const appels=[];let prompt,messages;
  const r=registre(poste,etat);
  globalThis.fetch=async(url,opts={})=>{
   const u=new URL(url);appels.push({u,opts});
   if(u.pathname==='/auth/v1/user')return new Response(JSON.stringify({id:'test-user'}));
   if(u.hostname==='api.deepseek.com'){
    const b=JSON.parse(opts.body);prompt=b.messages[0].content;messages=b.messages;
    return new Response(JSON.stringify({choices:[{message:{content:'Bonjour'},finish_reason:'stop'}]}));
   }
   if(u.pathname.includes('/rpc/'))return new Response(JSON.stringify({ok:false}));
   if(etat==='panne')return new Response('{}',{status:503});
   assert.equal(opts.headers.Authorization,'Bearer jeton-de-test');
   assert.equal(opts.method,'GET');
   return new Response(JSON.stringify(await r.lire(u.pathname.split('/').pop(),u.search.slice(1))));
  };
  const req={method:'POST',headers:{authorization:'Bearer jeton-de-test'},body:{profil,message:'Bonjour',historique:[{role:'user',content:'Souvenir ancien'}]}};
  const res={setHeader(){},status(s){this.code=s;return this;},json(v){this.body=v;return this;}};
  try{
   await chat(req,res);assert.equal(res.code,200);assert.ok(prompt.includes('FONCTION MUNICIPALE ACTUELLE'));
   if(etat==='pj'){assert.ok(prompt.includes(titre));assert.ok(prompt.includes('Tu n’exerces aucun pouvoir du poste'));}
   if(etat==='panne')assert.ok(prompt.includes('fonction non vérifiée'));
   assert.ok(messages.some(m=>m.content==='Souvenir ancien'));
   assert.ok(appels.filter(a=>a.u.pathname.startsWith('/rest/v1/')&&!a.u.pathname.includes('/rpc/')).every(a=>a.opts.method==='GET'));
  }finally{globalThis.fetch=saved;if(oldKey===undefined)delete process.env.DEEPSEEK_API_KEY;else process.env.DEEPSEEK_API_KEY=oldKey;}
 });
}
test('les fonctions de secretaire ne sont pas acceptables depuis le payload du navigateur',async()=>{
 const req={method:'POST',headers:{},body:{profil:'le_maire_de_luthecia',message:'Bonjour',fonctionMunicipale:{role:'Maire'}}};
 const res={setHeader(){},status(s){this.code=s;return this;},json(){return this;}};
 await chat(req,res);assert.equal(res.code,400);
});

for(const [poste,piece,titre] of [['maire','bureau_maire','Secrétaire général de la mairie'],['maire_adjoint','bureau_maire_adjoint','Secrétaire du maire adjoint']])test(`${poste} : filtre et tick de presence conservent un seul PNJ et recalculent la vacance`,async()=>{
 const j=plateau();j.ctx.state.currentRoom=piece;j.ctx.sbListTitulairesPostes=async()=>[];
 const p=j.ctx.personnesNormalesDeLaPiece('mairie-capitale',piece)[0];
 j.ctx._titulairesPostes={[poste+'_capitale']:'Alice'};
 assert.equal(j.ctx.filtrerPnjPostesPourvus([p]).length,1);
 j.ctx.sbGet=registre(poste,'pj').lire;await j.ctx.rafraichirTitulairesPostesElectifs();assert.equal(p.role,titre);
 j.ctx.sbGet=registre(poste,'vacant').lire;await j.ctx.rafraichirTitulairesPostesElectifs();assert.equal(p.role,p.roleSiPnjTitulaire);
});
