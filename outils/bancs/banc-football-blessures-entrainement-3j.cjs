'use strict';
// #309 : test local du vrai handler, sans session, sans requête ni débit.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const js=fs.readFileSync(path.join(root,'plateau-organisations-quetes.js'),'utf8');
const sql=fs.readFileSync(path.join(root,'migrations/20261104002000_football_entrainement_blessure_serveur_3j.sql'),'utf8');
const debut=js.indexOf('async function confirmerEntrainement(');
const fin=js.indexOf('async function doConseilEntraineurAdjoint(',debut);
assert.ok(debut>=0&&fin>debut,'handler entraînement manquant');
const code=js.slice(debut,fin);
function contexte(reponse) {
 const toasts=[], appels={ecritures:0,sauvegardes:0,actualisations:0,refus:0};
 const etat={char:{name:'PJ test',performance:{defense:4}},country:'republic',day:44,pa:18,hp:85};
 const modal={classList:{remove:()=>{}},innerHTML:''};
 const c={
   state:etat,document:{getElementById:()=>modal},
   sbFootballEntrainementConsommer:async()=>reponse,
   sbAppliquerBlessureSportive:async()=>{appels.ecritures++;throw Error('écriture cliente interdite');},
   sauvegarderPersonnageImmediat:()=>appels.sauvegardes++,
   updateUI:()=>appels.actualisations++,
   showToast:(...args)=>toasts.push(args),
   signalerRefusCout:()=>appels.refus++,
   doTenueEntrainement:()=>{},
   LABELS_PERF:{defense:'Défense'},console
 };
 vm.createContext(c);vm.runInContext(code,c);
 return {c,etat,toasts,appels};
}
test('blessure grave 3 jours décidée par le serveur, aucun deuxième débit PV',async()=>{
 const r={ok:true,pa:16,jour:44,nb:1,blesse:true,blessure:{gravite:'grave',jusquauJour:47},duree:3,degatsPV:30,hp:55};
 const {c,etat,appels,toasts}=contexte(r);
 await c.confirmerEntrainement('defense',2,0);
 assert.deepEqual(etat.char.blessureSportive,r.blessure);
 assert.equal(etat.hp,55);assert.equal(etat.pa,16);
 assert.equal(appels.ecritures,0);assert.equal(appels.sauvegardes,0);
 assert.match(toasts.at(-1)[1],/3 jour/);
});
test('blessure légère 2 jours affichée selon résultat serveur',async()=>{
 const r={ok:true,pa:16,jour:44,nb:1,blesse:true,blessure:{gravite:'legere',jusquauJour:46},duree:2,degatsPV:15,hp:70};
 const {c,etat,appels}=contexte(r);
 await c.confirmerEntrainement('defense',2,0);
 assert.equal(etat.char.blessureSportive.jusquauJour,46);
 assert.equal(etat.hp,70);assert.equal(appels.ecritures,0);
});
test('entraînement sans blessure conserve progression et deux PA',async()=>{
 const {c,etat,appels}=contexte({ok:true,pa:16,jour:44,nb:1,blesse:false,blessure:null,duree:0,degatsPV:0,hp:null});
 await c.confirmerEntrainement('defense',2,0);
 assert.equal(etat.char.performance.defense,6);
 assert.equal(etat.pa,16);assert.equal(etat.hp,85);
 assert.equal(appels.sauvegardes,1);assert.equal(appels.ecritures,0);
});
test('ancienne réponse incomplète : pas de tirage de secours',async()=>{
 const {c,etat,toasts,appels}=contexte({ok:true,pa:16,jour:44,nb:1});
 await c.confirmerEntrainement('defense',2,0);
 assert.equal(etat.char.performance.defense,4);assert.equal(appels.ecritures,0);
 assert.match(toasts.at(-1)[0],/indisponible/i);
});
test('durée frauduleuse supérieure à 3 refusée côté affichage',async()=>{
 const {c,etat,toasts,appels}=contexte({ok:true,pa:16,jour:44,nb:1,blesse:true,
   blessure:{gravite:'grave',jusquauJour:54},duree:10,degatsPV:30,hp:55});
 await c.confirmerEntrainement('defense',2,0);
 assert.equal(etat.char.blessureSportive,undefined);assert.equal(appels.ecritures,0);
 assert.match(toasts.at(-1)[0],/indisponible/i);
});
test('paiement refusé : aucune blessure et aucune progression',async()=>{
 const {c,etat,appels}=contexte({ok:false,raison:'pa_insuffisants'});
 await c.confirmerEntrainement('defense',2,0);
 assert.equal(etat.char.performance.defense,4);assert.equal(appels.refus,1);
 assert.equal(appels.ecritures,0);
});
test('la RPC valide l’intégralité des décisions de blessure',()=>{
 assert.match(sql,/v_blesse := random\(\) < 0\.05/);
 assert.match(sql,/v_grave := random\(\) < 0\.30/);
 assert.match(sql,/v_duree := CASE WHEN v_grave THEN 3 ELSE 2 \+ floor\(random\(\) \* 2\)::integer END/);
 assert.match(sql,/UPDATE public\.personnages_donnees[\s\S]*?blessure_sportive = v_blessure,[\s\S]*?hp = greatest\(1/);
 assert.match(sql,/RETURN jsonb_build_object\('ok', true,[\s\S]*?'blesse', v_blesse/);
 assert.doesNotMatch(code,/Math\.random|sbAppliquerBlessureSportive\(/);
});
test('blessures de match hors périmètre conservées',()=>{
 assert.match(js,/function tenterBlessureLive\(/);
 assert.match(js,/type: 'blessure', joueur, blessure:/);
 assert.match(js,/async function notifierCompositionsEtBlessures\(/);
});
