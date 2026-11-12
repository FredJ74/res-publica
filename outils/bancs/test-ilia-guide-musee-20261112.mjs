// Recette de la visite d'Ilia : GUI, énigme préservée, cinq salles, questions serveur.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {profilsPersonnalites} from '../../api/_pnj-personnalites.js';
import {SCENES_PNJ} from '../../api/_pnj-scenes-generes.js';
const lire = p => readFileSync(new URL('../../'+p, import.meta.url),'utf8');
const IDs=['hall','salle_origines','salle_personnalites_discretes','salle_bataille_fleuve','salle_grand_incendie'];
function monde(){
 const ctx={console};ctx.window=ctx;vm.createContext(ctx);
 vm.runInContext(lire('data.js')+';this.B=BUILDINGS;this.W=WORLD;',ctx);
 return ctx;
}
test('cinq salles, Ilia cliquable, ordre gratuit et énigme des origines conservée',()=>{
 const c=monde(),r=c.B['musee-novomirsk'].rooms;
 for(const id of IDs){
  const room=r[id];
  const ilia=room.persons.find(p=>p.name.includes('Ilia Krioukov'));
  assert.equal(ilia?.guideIlia,true,id);
  assert.match(ilia.photoUrl,/\.webp$/);
  const ordre=room.orders.find(o=>o.fn===(id==='salle_origines'?'tresor_ecouter_guide':'ilia_ecouter_guide'));
  assert.equal(ordre?.pa,0,id);
 }
 assert.ok(r.salle_personnalites_discretes.orders.some(o=>o.fn==='consulter_personnalites_musee'));
 assert.ok(c.W.soviet.ville_b.buildingContext['musee-novomirsk'].roomsExclues.includes('salle_bataille_fleuve'));
});
test('fenêtre lisible dans chacune des cinq salles, contexte et progressions',async()=>{
 const appels=[], modals=[];
 const ctx={console,state:{country:'soviet',currentCity:'capitale',currentBuilding:'musee-novomirsk',currentRoom:'hall'},
   sbRpcVerdict:async(name)=>{appels.push(name);return name==='tresor_tsars_guide'?{ok:true}:{ok:true,salle:'novomirsk:'+ctx.state.currentRoom,ouvert:false,restantes:0};},
   sovModal:(title,html)=>modals.push({title,html}),showToast:()=>{},
   document:{getElementById:()=>null,body:{contains:()=>true}}
 };ctx.window=ctx;vm.createContext(ctx);vm.runInContext(lire('plateau-guide-ilia.js'),ctx);
 for(const salle of IDs){
   ctx.state.currentRoom=salle;await ctx.iliaEcouterGuide(salle==='salle_origines');
   assert.match(modals.at(-1).html,/guide-musee-fiche/);
   assert.match(modals.at(-1).html,/Des questions pour Ilia/);
   assert.ok(modals.at(-1).html.length>700);
 }
 assert.equal(appels.filter(x=>x==='tresor_tsars_guide').length,1,'énigme appelée uniquement aux origines');
 assert.equal(appels.filter(x=>x==='guide_musee_dialogue_lire').length,5);
 ctx.state.currentBuilding='musee-national-republia'; const before=modals.length;
 await ctx.iliaEcouterGuide(false);assert.equal(modals.length,before,'Ilia ne présente pas le musée national');
});
test('profil IA : cinq récits connus, sans révéler l’énigme',()=>{
 const p=profilsPersonnalites().veteran_ilia_krioukov;
 assert.ok(p); const facts=p.savoir;
 for(const str of ['Sergueï IV','Sophia Nouiseteskaïa','Piotr Karassov','Grigori Pirogov']) assert.ok(facts.includes(str),str);
 assert.match(facts,/ne connais pas la solution de l'énigme/);
 const src=lire('api/chat.js');
 assert.match(src,/req\.body\.profil === 'veteran_ilia_krioukov'/);
 assert.match(src,/novomirsk:/);
});
test('scènes serveur connues dans les deux nouvelles salles',()=>{
 for(const room of ['salle_bataille_fleuve','salle_grand_incendie']){
  const scene=SCENES_PNJ[JSON.stringify(['soviet','capitale','musee-novomirsk',room])];
  assert.ok(scene,room);
  assert.ok(scene.personnes.includes('Vétéran Ilia Krioukov'),room);
 }
});
test('l’image du musée n’est plus couverte de paragraphes, sauf autres lieux inchangés',()=>{
 const s=lire('plateau-navigation.js');
 assert.match(s,/panneauMusee\.style\.display/);
 assert.match(s,/buildingId === 'musee-novomirsk'/);
 assert.match(s,/panneauMusee\.style\.display =[\s\S]*\? 'none' : ''/);
 const html=lire('plateau.html');assert.ok(html.includes('plateau-guide-ilia.js'));
 const route=lire('plateau-router.js');
 assert.match(route,/fn === 'tresor_ecouter_guide'[\s\S]{0,130}iliaEcouterGuide\(true\)/);
 assert.match(route,/fn === 'ilia_ecouter_guide'/);
});
test('seuls le lieu et la clé serveur des questions du musée municipal changent',()=>{
 const sql=lire('migrations/20261112234000_ilia_questions_musee_municipal.sql');
 assert.match(sql,/novomirsk:/);
 assert.match(sql,/musee-national-republia/);
 for(const room of IDs) assert.ok(sql.includes("'"+room+"'"));
 assert.ok(!sql.includes('tresor_tsars_guide('));
 assert.ok(!sql.includes('fouiller_lieux('));
});
