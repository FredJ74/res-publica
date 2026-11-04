'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const core=fs.readFileSync(path.join(root,'plateau-core.js'),'utf8');
const forum=fs.readFileSync(path.join(root,'forum.js'),'utf8');
const refuse=core.slice(core.indexOf('function signalerRefusCout('),core.indexOf('\nfunction signalerRefusPa(',core.indexOf('function signalerRefusCout(')));
const publish=forum.slice(forum.indexOf('async function forumPublierAvecJauges('));
function testRefus(error) {
 const toasts=[],ctx={state:{char:{country:'republic'}},COUNTRIES:{republic:{cur:'FR'}},
   showToast:(...args)=>toasts.push(args),console:{warn(){},error(){}},
   getFondsDisponiblesOrdinaires:()=>0};
 vm.createContext(ctx);vm.runInContext(refuse,ctx);ctx.signalerRefusCout(error);
 return toasts.at(-1);
}
test('une session perdue n est jamais présentée comme un refus territorial ni une erreur de coût',()=>{
 const t=testRefus({raison:'session_perdue',transport:{etat:'session_perdue',envoyee:false}});
 assert.equal(t[0],'Session expirée');
 assert.match(t[1],/Reconnectez-vous/);
});
test('un timeout PostgREST donne une consigne sûre sans nouveau POST automatique',()=>{
 const t=testRefus({raison:'transport_indisponible',transport:{etat:'reseau',http:503,envoyee:true}});
 assert.equal(t[0],'Serveur temporairement indisponible');
 assert.match(t[1],/doublons/);
});
test('un refus de ville ou de texte est expliqué au joueur',()=>{
 assert.equal(testRefus({raison:'forum_inaccessible'})[0],'Forum local non accessible');
 assert.equal(testRefus({raison:'territoire_invalide'})[0],'Forum local non accessible');
 assert.equal(testRefus({raison:'forum_inconnu'})[0],'Forum introuvable');
 assert.equal(testRefus({raison:'publication_vide'})[0],'Publication incomplète');
});
test('publication à PSM : un seul appel serveur au forum local_ville_a',async()=>{
 const calls=[],toasts=[],ctx={currentForumId:'local_ville_a',state:{currentCity:'ville_a'},
 idForumLocal:city=>'local_'+city,showToast:(...a)=>toasts.push(a),
 executerOrdreJaugesServeur:async(...a)=>{calls.push(a);return {topic:'sujet-test',post:'message-test'};}};
 vm.createContext(ctx);vm.runInContext(publish,ctx);
 const r=await ctx.forumPublierAvecJauges(null,'Titre','Texte',[],null,{idOrga:null,authorSecret:false,orgIcon:null});
 assert.equal(r.topic,'sujet-test');assert.equal(calls.length,1);
 assert.equal(calls[0][0],'forum_publier');assert.equal(calls[0][1].forum,'local_ville_a');
 assert.equal(toasts.length,0);
});
test('ville modifiée pendant la composition : aucun RPC ni faux sujet',async()=>{
 const calls=[],toasts=[],ctx={currentForumId:'local_capitale',state:{currentCity:'ville_a'},
 idForumLocal:city=>'local_'+city,showToast:(...a)=>toasts.push(a),
 executerOrdreJaugesServeur:async(...a)=>{calls.push(a);return {topic:'faux',post:'faux'};}};
 vm.createContext(ctx);vm.runInContext(publish,ctx);
 const r=await ctx.forumPublierAvecJauges(null,'Titre','Texte',[],null,{idOrga:null,authorSecret:false,orgIcon:null});
 assert.equal(r,null);assert.equal(calls.length,0);
 assert.equal(toasts[0][0],'Forum local à rouvrir');
});
