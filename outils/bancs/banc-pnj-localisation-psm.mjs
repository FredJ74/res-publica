// Vrai handler/prompts, appels serveur et IA simulés ; aucune session PJ réelle.
import test from 'node:test';import assert from 'node:assert/strict';
import {readFileSync}from'node:fs';import{execFileSync}from'node:child_process';
import chat from '../../api/chat.js';
import{construirePromptSysteme,TOUS_PROFILS}from'../../api/_pnj-profils.js';
import{sceneDialogue}from'../../api/_pnj-localisation.js';
import{SCENES_PNJ}from'../../api/_pnj-scenes-generes.js';
const racine=new URL('../../',import.meta.url),lire=f=>readFileSync(new URL(f,racine),'utf8');
const position={ok:true,country:'republic',city:'ville_a',building:'commissariat-local',room:'bureau_commissaire'};
const prompt=p=>construirePromptSysteme('martial_morvan','fr',null,null,null,null,null,null,null,sceneDialogue(p));
test('scènes : régénération exacte depuis le même moteur de casting que le jeu',()=>{
 const sortie=execFileSync(process.execPath,['outils/generateurs/generer-pnj-lieux-metiers.cjs','--scenes-js'],{cwd:racine,encoding:'utf8'});
 assert.equal(sortie,lire('api/_pnj-scenes-generes.js'));assert.ok(Object.keys(SCENES_PNJ).length>300);
});
test('Morvan : identité, fonction, ville et bureau explicitement dans le prompt',()=>{
 const p=prompt(position);for(const x of['Martial Morvan','Commissaire de Port-Sainte-Marie','Bureau du Commissaire','Port-Sainte-Marie','Républia'])assert.ok(p.includes(x),x);
 assert.match(p,/vous conversez à cet endroit précis/);assert.match(p,/prévaut sur toute ancienne réplique/);assert.match(p,/N'invente aucun autre emplacement/);
 assert.equal(TOUS_PROFILS.martial_morvan.caractere,'Tu parles simplement, comme quelqu\'un qui fait son metier.');
});
for(const [nom,p]of Object.entries({absente:null,refus:{ok:false},incomplete:{ok:true,country:'republic'},inconnue:{...position,room:'fausse'},pays:{...position,country:'pays_inconnu'}}))test('position non confirmée : '+nom,()=>{
 assert.equal(sceneDialogue(p),null);assert.match(prompt(p),/LOCALISATION ACTUELLE NON CONFIRMÉE/);assert.doesNotMatch(prompt(p),/SCÈNE VÉRIFIÉE/);
});
for(const [ville,batiment,piece,nom,profil]of [['capitale','commissariat','accueil_police','Luthécia','gardien_de_la_paix'],['ville_b','commissariat-local','accueil_loc','Montrouge','brigadier_local']])test('autre commissariat : '+nom,()=>{
 const scene=sceneDialogue({...position,city:ville,building:batiment,room:piece});assert.equal(scene.ville,nom);
 const p=construirePromptSysteme(profil,'fr',null,null,null,null,null,null,null,scene);assert.ok(p.includes(nom));assert.match(p,/vous conversez à cet endroit précis/);assert.doesNotMatch(p,/Port-Sainte-Marie/);
});
test('même identifiant de ville dans un autre pays : aucune localisation PSM usurpée',()=>{
 const scene=sceneDialogue({...position,country:'narco'});assert.equal(scene.ville,'Puerto Negro');assert.equal(scene.pays,'El Estado');
 const p=prompt({...position,country:'narco'});assert.match(p,/ville « Puerto Negro »/);assert.match(p,/Ta présence dans cette pièce n'est pas confirmée/);
});
test('mauvaise pièce : ne transforme pas le lieu du visiteur en présence attestée de Morvan',()=>{
 const p=prompt({...position,room:'accueil_loc'});assert.match(p,/Ta présence dans cette pièce n'est pas confirmée/);assert.doesNotMatch(p,/vous conversez à cet endroit précis/);
});
async function appel(question,options={}){
 const old={fetch:globalThis.fetch,key:process.env.DEEPSEEK_API_KEY,error:console.error};let corps;const appels=[];process.env.DEEPSEEK_API_KEY='cle-test';console.error=()=>{};
 globalThis.fetch=async(url,init)=>{const u=new URL(url);appels.push({u,init});
  if(u.pathname==='/auth/v1/user')return new Response(JSON.stringify({id:'uid-test'}));
  if(u.hostname==='api.deepseek.com'){corps=JSON.parse(init.body);return new Response(JSON.stringify({choices:[{message:{content:'Réponse IA simulée'},finish_reason:'stop'}]}));}
  if(u.pathname.endsWith('/rue_position_lire')){assert.deepEqual(JSON.parse(init.body),{});assert.equal(init.headers.Authorization,'Bearer jeton-test');assert.ok(init.signal);if(options.panne)throw Error('réseau');return new Response(JSON.stringify(options.position||position));}
  return new Response(JSON.stringify({ok:false}));
 };
 const res={setHeader(){},status(c){this.code=c;return this},json(v){this.body=v;return this}};
 try{await chat({method:'POST',headers:{authorization:'Bearer jeton-test'},body:{profil:'martial_morvan',lang:'fr',message:question,historique:[{role:'assistant',content:'On est dans la cour derrière la porte verte.'}],...options.body}},res);return{res,corps,appels};}
 finally{globalThis.fetch=old.fetch;console.error=old.error;if(old.key===undefined)delete process.env.DEEPSEEK_API_KEY;else process.env.DEEPSEEK_API_KEY=old.key;}
}
for(const q of['Où sommes-nous ?','Où se trouve votre bureau ?','Quel est votre rôle ?'])test('requête réellement envoyée au fournisseur (réponse simulée) : '+q,async()=>{
 const r=await appel(q);assert.equal(r.res.code,200);assert.equal(r.res.body.reponse,'Réponse IA simulée');assert.equal(r.corps.messages[0].content,prompt(position));assert.match(r.corps.messages[0].content,/prévaut sur toute ancienne réplique/);assert.ok(r.appels.every(a=>a.u.hostname==='api.deepseek.com'||a.u.pathname==='/auth/v1/user'||a.u.pathname.startsWith('/rest/v1/rpc/')));
});
test('position forgée par le navigateur refusée avant lecture et IA',async()=>{
 const r=await appel('Où sommes-nous ?',{body:{position,ville:'capitale'}});assert.equal(r.res.code,400);assert.equal(r.appels.length,0);
});
test('lecture de position en panne : pas de faux lieu ni deuxième moteur de dialogue',async()=>{
 const r=await appel('Où sommes-nous ?',{panne:true});assert.equal(r.res.code,200);assert.match(r.corps.messages[0].content,/LOCALISATION ACTUELLE NON CONFIRMÉE/);assert.doesNotMatch(r.corps.messages[0].content,/SCÈNE VÉRIFIÉE/);
});
