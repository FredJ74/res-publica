'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const source=process.env.HG422_CONTRE?require('node:child_process').execFileSync('git',['show',process.env.HG422_CONTRE+':forum.js'],{encoding:'utf8'}):fs.readFileSync('forum.js','utf8');
function scene(){
 const timers=new Set();let num=0;const c=vm.createContext({console:{info(){},warn(){},error(){}},Date,state:{country:'republic',currentCity:'capitale',char:{name:'Alice'},organisations:[{id:'club',chef:'Chef',membres:[{nom:'Alice'}]}]},uid:'u1',session:'s1',document:{getElementById:()=>null},localStorage:{getItem:()=>null,setItem(){}},setTimeout:()=>{timers.add(++num);return num;},clearTimeout:id=>timers.delete(id)});
 c.rpAuthUid=()=>c.uid;c.rpAuthSessionIdentifiant=()=>c.session;
 vm.runInContext(source,c);c.rafraichirVoyantsEtCompteursForum=()=>{};c.get=x=>vm.runInContext(x,c);c.get('getForums()');c.timers=timers;return c;
}
function differer(){let finir;const p=new Promise(r=>finir=r);return{p,finir};}
for(const changement of ['ville','pays','personnage','uid','session','adhesion'])test('réponses privées tardives / '+changement,async()=>{
 const c=scene(),d=differer();c.get("FORUM_TOPICS.org_club=[{id:'t',posts:[]}]");const ancien=c.get('FORUM_TOPICS.org_club[0]');c.sbLoadForumPosts=()=>d.p;
 const lecture=c.loadForumPostsFromSB('t');
 if(changement==='ville')c.state.currentCity='ville_a';
 if(changement==='pays')c.state.country='narco';
 if(changement==='personnage')c.state.char={name:'Autre'};
 if(changement==='uid')c.uid='u2';
 if(changement==='session')c.session='s2';
 if(changement==='adhesion')c.state.organisations=[];
 d.finir([{id:'p',author:'Auteur',content:'Privé'}]);await lecture;
 assert.equal(ancien.posts.length,0,'aucun ancien message ne doit être adopté');
});
test('messages vides confirmés : aucun ancien message privé conservé',async()=>{
 const c=scene();c.get("FORUM_TOPICS.org_club=[{id:'t',posts:[{id:'ancien'}]}]");c.sbLoadForumPosts=async()=>[];
 await c.loadForumPostsFromSB('t');assert.equal(c.get('FORUM_TOPICS.org_club[0].posts.length'),0);
});
test('aller-retour : cache local renouvelé, national conservé dans le même pays',()=>{
 const c=scene();c.get("FORUM_TOPICS.local_capitale=[{id:'local'}];FORUM_TOPICS.national=[{id:'national'}]");c.state.currentCity='ville_a';c.get('getForums()');assert.equal(c.get('FORUM_TOPICS.local_capitale'),undefined);
 c.state.currentCity='capitale';c.get('getForums()');assert.equal(c.get('FORUM_TOPICS.local_capitale'),undefined);assert.equal(c.get('FORUM_TOPICS.national[0].id'),'national');
});
test('perte d’adhésion : purge des sujets, compteurs et voyants privés',()=>{
 const c=scene();c.get("FORUM_TOPICS.org_club=[{id:'prive'}];forumCompteursServeur.org_club=1;forumActiviteCache.org_club='2026-11-03';forumActivite.forums.org_club=true");c.state.organisations=[];c.get('getForums()');
 for(const nom of ['FORUM_TOPICS','forumCompteursServeur','forumActiviteCache','forumActivite.forums'])assert.equal(c.get(nom+'.org_club'),undefined);
});
test('compteurs tardifs après perte d’adhésion ignorés sans nouvelle ouverture',async()=>{
 const c=scene(),d=differer();c.sbCompterSujetsForums=()=>d.p;const p=c.rafraichirCompteursForums();c.state.organisations=[];d.finir({org_club:999,national:1});await p;assert.equal(c.get('forumCompteursServeur.org_club'),undefined);
});
test('activité tardive après déplacement ignorée',async()=>{
 const c=scene(),d=differer();c.get('forumActiviteCurseurEtabli=true');c.sbActiviteForumCibles=()=>d.p;c.sbActiviteForumDepuis=async()=>({parForum:{},curseurTopics:null,curseurPosts:null});const p=c.verifierActiviteForumNonVue();c.state.currentCity='ville_a';d.finir({local_capitale:'2026-11-03T12:00:00Z'});await p;assert.equal(c.get('forumActiviteCache.local_capitale'),undefined);
});
test('sujets : identité changée, réponse ignorée et délai libéré',async()=>{
 const c=scene(),d=differer();c.sbLoadForumTopicsVerdict=()=>d.p;const p=c.loadForumTopicsFromSB('national');c.uid='u2';d.finir({ok:true,donnees:[{id:'ancien',title:'x'}]});await p;assert.equal(c.get('FORUM_TOPICS.national.length'),0);assert.equal(c.timers.size,0);
});
test('ancienne requête terminée ne déverrouille pas la nouvelle lecture',async()=>{
 const c=scene(),a=differer(),b=differer();let i=0;c.sbLoadForumTopicsVerdict=()=>++i===1?a.p:b.p;const p=c.loadForumTopicsFromSB('national');c.uid='u2';c.state.char={name:'Autre'};c.get('getForums()');const autre=c.loadForumTopicsFromSB('national');const ticket=c.get('FORUM_LECTURE_EN_COURS.national');a.finir({ok:true,donnees:[]});await p;assert.equal(c.get('FORUM_LECTURE_EN_COURS.national'),ticket);b.finir({ok:true,donnees:[]});await autre;assert.equal(c.get('FORUM_LECTURE_EN_COURS.national'),undefined);assert.equal(c.timers.size,0);
});
function chargerReel(c){
 const acorn=require('../vercel/node_modules/acorn'),s=fs.readFileSync('plateau-organisations-quetes.js','utf8'),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.id?.name==='chargerOrganisations');assert.ok(n);
 c.document.querySelector=()=>null;vm.runInContext('let RP_ORGANISATIONS_LECTURE=0;\n'+s.slice(n.start,n.end),c);
}
test('adhésions fraîches : réouverture après exclusion, lecture sans élection',async()=>{
 const c=scene();chargerReel(c);let elections=0;c.verifierElectionsOrganisations=()=>elections++;c.sbLoadOrganisations=async()=>[];
 assert.equal(await c.confirmerAdhesionsForums(),true);assert.equal(elections,0);assert.equal(c.get('getForums().org_club'),undefined);
});
test('adhésions fraîches : chargeur normal conserve ses traitements existants',async()=>{
 const c=scene();chargerReel(c);let elections=0;c.verifierElectionsOrganisations=()=>elections++;c.sbLoadOrganisations=async()=>[];
 assert.equal(await c.chargerOrganisations(),true);assert.equal(elections,1);
});
test('adhésions fraîches : changement de compte pendant la lecture, aucune adoption',async()=>{
 const c=scene();chargerReel(c);const d=differer();c.sbLoadOrganisations=()=>d.p;const p=c.confirmerAdhesionsForums();c.uid='u2';d.finir([{id:'prive-autre'}]);assert.equal(await p,false);assert.equal(c.state.organisations[0].id,'club');
});
test('adhésions fraîches : panne ne confirme aucun droit',async()=>{
 const c=scene();chargerReel(c);c.showToast=()=>{};c.sbLoadOrganisations=async()=>{throw Error('réseau');};assert.equal(await c.confirmerAdhesionsForums(),false);
});
for(const situation of ['autorise','hors-ville','tardive','absent'])test('lien direct non préchargé : '+situation,async()=>{
 const c=scene(),d=differer();c.chargerOrganisations=async()=>true;c.showToast=()=>{};c.renderForumModal=()=>{};c.document.getElementById=()=>({classList:{add(){}}});let charges=0,ouverts=0;
 c.sbGet=(_,filtre)=>{assert.match(filtre,/id=eq\.t/);return d.p;};
 c.loadForumTopicsFromSB=async id=>{charges++;assert.equal(id,'national');c.get("FORUM_TOPICS.national=[{id:'t',posts:[]}]");};c.openTopic=id=>{ouverts++;assert.equal(id,'t');};
 const p=c.ouvrirForumSurTopic('t');await new Promise(r=>setImmediate(r));if(situation==='tardive')c.uid='autre';
 d.finir(situation==='absent'?[]:[{id:'t',forum_id:situation==='hors-ville'?'local_ville_a':'national',country:'republic'}]);await p;
 assert.equal(charges,situation==='autorise'?1:0);assert.equal(ouverts,situation==='autorise'?1:0);
});
