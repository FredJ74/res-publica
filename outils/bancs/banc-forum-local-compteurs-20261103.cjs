'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('forum.js','utf8');
const supabase=fs.readFileSync('supabase.js','utf8');
function bloc(src,debut,fin){
  const a=src.indexOf(debut),b=src.indexOf(fin,a+debut.length);
  assert.ok(a>=0 && b>a,debut+' absent');
  return src.slice(a,b);
}
function scene(){
 const state={char:{name:'PJ test'},currentCity:'ville_a',country:'republic',organisations:[]};
 const indicateur={style:{}};
 const ctx={state,WORLD:{republic:{ville_a:{name:'Luthécia'}}},
   forumView:'list',currentForumId:null,forumCategorieActive:'intra',
   forumSousGroupeOuvert:true,FORUM_LECTURE_TERMINEE:{},FORUM_LECTURE_ECHOUEE:{},
   forumActivite:{forums:{local_ville_a:true},groupes:{intra:true},global:true},
   FORUM_TOPICS:{},Date,console,
   htmlPointRougeActivite:()=>'<span class="point-rouge"></span>',
   canAccessForum:()=>true,rafraichirVoyantsEtCompteursForum:()=>{ctx.rafraichissements++},
   rafraichissements:0,sbCompterSujetsForums:async ids=>Object.fromEntries(ids.map(id=>[id,id==='gouvernement'?1:id==='national'?2:0]))};
 vm.createContext(ctx);
 vm.runInContext(bloc(source,'const FORUMS_BASE =','// Alias retro-compatible'),ctx);
 vm.runInContext(bloc(source,'const FORUM_TOPICS =','// Mails inter-joueurs'),ctx);
 vm.runInContext(bloc(source,'function renderForumNavItem(', 'function toggleSousGroupeForum('),ctx);
 return ctx;
}
test('le forum local réel local_ville_a est visible et son alerte consultable',()=>{
 const c=scene();
 const html=vm.runInContext("renderForumCategorieItems('intra')",c);
 assert.match(html,/Forum Local/);
 assert.match(html,/switchForum\('local_ville_a'\)/);
 assert.match(html,/point-rouge/);
 assert.equal((html.match(/Forum Local/g)||[]).length,1);
});
test('les nombres des forums institutionnels sont calculés dès ouverture, indépendamment des clics',async()=>{
 const c=scene();
 await vm.runInContext('rafraichirCompteursForums()',c);
 assert.equal(vm.runInContext("nombreSujetsForum('gouvernement')",c),'1 sujet(s)');
 assert.equal(vm.runInContext("nombreSujetsForum('national')",c),'2 sujet(s)');
 assert.equal(c.rafraichissements,1);
 assert.equal(c.forumActivite.forums.local_ville_a,true,'le préchargement ne marque aucun forum lu');
 const html=vm.runInContext("renderForumCategorieItems('intra')",c);
 assert.match(html,/Le Gouvernement à la Nation[\s\S]{0,330}1 sujet\(s\)/);
});
test('avant confirmation serveur, pas de faux 0 sujet',()=>{
 const c=scene();
 assert.equal(vm.runInContext("nombreSujetsForum('gouvernement')",c),'… sujet(s)');
});
test('les compteurs n’exposent pas les forums inaccessibles',async()=>{
 const c=scene();
 let demandes;
 c.canAccessForum=id=>id!=='gouvernement';
 c.sbCompterSujetsForums=async ids=>{demandes=ids;return Object.fromEntries(ids.map(id=>[id,0]))};
 await vm.runInContext('rafraichirCompteursForums()',c);
 assert.ok(!demandes.includes('gouvernement'));
});
function conteur(reponses){
 const c={console,Set,encodeURIComponent,state:{country:'republic'},sbGet:async (_table,requete)=>{
  const offset=Number((requete.match(/offset=(\d+)/)||[])[1]||0);
  return reponses.slice(offset,offset+200);
 }};
 vm.createContext(c);
 vm.runInContext(bloc(supabase,'function sbForumEstTerritorial(', 'async function sbLoadForumTopicsVerdict('),c);
 return c;
}
test('requête groupée paginée : 205 sujets répartis sans limite de 200',async()=>{
 const data=Array.from({length:205},(_,i)=>({forum_id:i%2?'gouvernement':'national',country:'republic'}));
 const c=conteur(data);
 const resultat=await vm.runInContext("sbCompterSujetsForums(['national','gouvernement','vide'])",c);
 assert.equal(resultat.national,103);
 assert.equal(resultat.gouvernement,102);
 assert.equal(resultat.vide,0);
});
test('panne Supabase : aucune confirmation fausse de 0 sujet',async()=>{
 const c=conteur([]);
 c.sbGet=async()=>null;
 await assert.rejects(vm.runInContext("sbCompterSujetsForums(['gouvernement'])",c),/indisponible/);
});
