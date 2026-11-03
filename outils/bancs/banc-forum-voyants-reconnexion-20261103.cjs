'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const forum=fs.readFileSync(path.join(root,'forum.js'),'utf8');
const core=fs.readFileSync(path.join(root,'plateau-core.js'),'utf8');

function between(src,first,last){
 const start=src.indexOf(first),end=src.indexOf(last,start+first.length);
 assert.ok(start>=0 && end>start,first+' end not found');
 return src.slice(start,end);
}
const forumFunctions=[
 between(forum,'function marquerForumRubriqueVisitee(', '// Point d\'entree unique du sondage'),
 between(forum,'function recalculerActiviteForumAgregat(', '// Voyant global'),
 between(forum,'function renderForumNavItem(', 'function renderForumCategorieItems('),
 between(forum,'function renderForumCategorieItems(', 'function toggleSousGroupeForum('),
 between(forum,'function renderCategorieHeader(', '// Extrait de renderForumModal'),
 between(forum,'function rafraichirVoyantsEtCompteursForum(', 'function renderForumModal('),
 between(forum,'function renderForumModal(', 'function canAccessForum(')
].join('\n');
function forumScene(){
 const map=new Map(),dot={style:{}},titre={textContent:'',innerHTML:''},side={innerHTML:''},body={innerHTML:''};
 const forums={
   national:{name:'Forum National',cat:'intra',icon:'ti-flag',private:false},
   presidence:{name:'Présidence',cat:'intra',sousGroupe:'institutions',icon:'ti-flag',private:false},
   presse:{name:'Presse',cat:'intra',icon:'ti-news',private:false},
   international:{name:'International',cat:'inter',icon:'ti-world',private:false},
   ancien:{name:'Ancien',cat:'prive',icon:'ti-lock',private:true}
 };
 const element={'forum-activity-dot':dot,'modal-forum-title':titre,'forum-sidebar':side,'forum-body':body,
   'modal-forum':{classList:{contains:()=>true}}};
 const ctx={
   state:{char:{name:'Joueur de test'}},forumActivite:{forums:{},groupes:{},global:false},
   forumActiviteCache:{},forumView:'list',currentForumId:'national',forumCategorieActive:'intra',
   forumSousGroupeOuvert:false,FORUM_TOPICS:{},mailRubrique:'recus',
   getForums:()=>forums,canAccessForum:id=>id!=='ancien',
   localStorage:{getItem:k=>map.get(k)||null,setItem:(k,v)=>map.set(k,v)},
   document:{getElementById:id=>element[id]||null},
   mailsRecusVisibles:()=>[],renderForumSidebar:()=>'',renderForumContent:()=>'',console
 };
 vm.createContext(ctx);vm.runInContext(forumFunctions,ctx);
 return {ctx,map,dot,titre,side,forums};
}
test('un titre Forum sans point orphelin et un badge global correspondant à une vraie rubrique',()=>{
 const s=forumScene();s.ctx.forumActivite.forums.national=true;
 s.ctx.recalculerActiviteForumAgregat();
 assert.equal(s.dot.style.display,'inline-block');
 s.ctx.renderForumModal();
 assert.equal(s.titre.textContent,'Forum');
 assert.equal(s.titre.innerHTML,'');
 const national=s.ctx.renderForumCategorieItems('intra');
 assert.match(national,/Forum National[\s\S]{0,180}background:#cc2020/);
});
test('lecture efface immédiatement le point, même avec horloge serveur en avance, et tient après polling',()=>{
 const s=forumScene();s.ctx.forumActivite.forums.national=true;
 s.ctx.forumActiviteCache.national='2999-11-03T21:20:00.000Z';
 s.ctx.recalculerActiviteForumAgregat();
 s.ctx.marquerForumRubriqueVisitee('national');
 assert.equal(s.ctx.forumActivite.forums.national,false);
 assert.equal(s.ctx.forumActivite.global,false);
 assert.equal(s.dot.style.display,'none');
 const last=s.map.get('respublica_dernier_passage_forum_Joueur de test_national');
 assert.equal(last,'2999-11-03T21:20:00.000Z');
 assert.equal(s.ctx.forumActiviteCache.national>last,false);
});
test('une alerte institutionnelle descend sur Institutionnels sans toucher aux autres groupes',()=>{
 const s=forumScene();s.ctx.forumActivite.forums.presidence=true;
 s.ctx.recalculerActiviteForumAgregat();
 const html=s.ctx.renderForumCategorieItems('intra');
 assert.match(html,/Institutionnels[\s\S]{0,180}background:#cc2020/);
 assert.equal(s.ctx.forumActivite.groupes.inter||false,false);
});
test('anciens forums et forums privés perdus ne conservent aucun point global',()=>{
 const s=forumScene();s.ctx.forumActivite.forums.disparu=true;
 s.ctx.forumActivite.forums.ancien=true;
 s.ctx.recalculerActiviteForumAgregat();
 assert.equal(s.ctx.forumActivite.global,false);
 assert.equal(s.dot.style.display,'none');
 assert.equal(s.ctx.forumActivite.groupes.prive||false,false);
});

const reconnection=between(core,'function afficherBandeauReconnexion(', '// Repli serveur de loadCharacter()');
class FauxNoeud {
 constructor(tag){this.tag=tag;this.children=[];this.style={};this.attributes={};this.events={};this.classList={contains:()=>false};this.value='';}
 appendChild(n){this.children.push(n);return n;}
 setAttribute(k,v){this.attributes[k]=v;}
 addEventListener(k,cb){this.events[k]=cb;}
 querySelector(selector){if(selector==='form')return this.walk().find(e=>e.tag==='form')||null;return null;}
 walk(){return [this,...this.children.flatMap(x=>x.walk())];}
}
function reconnexionScene(char,cache={}){
 const doc={body:new FauxNoeud('body'),getElementById:()=>null,createElement:t=>new FauxNoeud(t)};
 const ctx={document:doc,state:{char},localStorage:{getItem:k=>cache[k]||null},console,
 rpAuthIdentiteMemorisee:()=>({email:'contact@example.test'})};
 vm.createContext(ctx);vm.runInContext(reconnection,ctx);
 vm.runInContext('afficherBandeauReconnexion()',ctx);
 return doc.body.walk();
}
test('portrait du PJ et vrai bouton de reconnexion distinct, non étiré',()=>{
 const nodes=reconnexionScene({name:'Arnie',photoUrl:'images/arnie.webp'});
 const photo=nodes.find(n=>n.tag==='img');
 assert.ok(photo);assert.equal(photo.src,'images/arnie.webp');
 const zone=nodes.find(n=>n.attributes['aria-label']==='Portrait de Arnie');
 assert.ok(zone);assert.match(zone.style.cssText,/pointer-events:none/);
 const button=nodes.find(n=>n.tag==='button'&&n.textContent==='Me reconnecter');
 assert.ok(button);assert.match(button.style.cssText,/align-self:flex-start/);
 assert.match(button.style.cssText,/flex:none/);
});
test('portrait nominatif en priorité, pas de photo globale d’un autre joueur',()=>{
 const nodes=reconnexionScene({name:'Arnie',photoUrl:'images/arnie.webp'},
   {'respublica_photo_Arnie':'images/arnie-perso.webp',respublica_photo:'images/autre.webp'});
 assert.equal(nodes.find(n=>n.tag==='img').src,'images/arnie-perso.webp');
});
test('sans portrait : silhouette visible, jamais photo d’un autre compte',()=>{
 const nodes=reconnexionScene({name:'Arnie'}, {respublica_photo:'images/autre.webp'});
 assert.equal(nodes.filter(n=>n.tag==='img').length,0);
 assert.ok(nodes.some(n=>n.tag==='span'&&n.textContent==='♟'));
});
test('URL dangereuse ne produit pas de balise image',()=>{
 const nodes=reconnexionScene({name:'Arnie',photoUrl:'javascript:alert(1)'});
 assert.equal(nodes.filter(n=>n.tag==='img').length,0);
});
