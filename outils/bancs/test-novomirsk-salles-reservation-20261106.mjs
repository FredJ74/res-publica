import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createContext, runInContext} from 'node:vm';
import {fileURLToPath} from 'node:url';
import {resolve,dirname} from 'node:path';

const base=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const lire=n=>readFileSync(resolve(base,n),'utf8');
const data=createContext({console});
runInContext(lire('data.js')+';this.world=WORLD;',data);
const salles=data.world.soviet.capitale.buildingContext['centre-affaires'].roomsExtra;
const ids=['reunion_grande_a','reunion_grande_b','reunion_moyenne_a','reunion_moyenne_b'];

test('quatre salles et prix: deux grandes 150 PSK, deux moyennes 100 PSK',()=>{
 for(const [index,id] of ids.entries()){
   const r=salles[id];assert.ok(r,id);
   assert.match(r.desc,index<2?/150 PSK\/jour/:/100 PSK\/jour/);
   // Réservation puis « Organiser un événement » (#568, 07/11).
   assert.equal(r.orders.map(o=>o.fn).join(','),'sovarka_reunion_reserver,sovarka_reunion_evenement');
   assert.equal(r.orders[0].pa,0);
   assert.equal(r.orders[0].cost,0,'aucun paiement non atomique via le routeur');
   assert.ok(r.orders[0].label.includes((index<2?150:100)+' PSK'));
 }
});
test('réservation client: jamais de paiement local et appel RPC de salle vérifiée',async()=>{
 const toast=[],payments=[],journal=[],calls=[];
 const state={currentRoom:'reunion_grande_a',currentBuilding:'centre-affaires',country:'soviet',currentCity:'capitale',char:{country:'soviet'}};
 const ctx=createContext({console,state,window:{confirm:()=>true},COUNTRIES:{soviet:{cur:'PSK'}},
    sbRpcVerdict:async(n,args)=>{calls.push([n,args]);return{ok:true,jour:'2026-11-06',montant:150,pa:11,liquide:100,arg:100,solde_national:0};},
    showToast:(...args)=>toast.push(args),appliquerPaiementServeur:v=>payments.push(v),
    addJournalEntry:(...args)=>journal.push(args),updateUI:()=>{}});
 runInContext(lire('plateau-router.js'),ctx);
 await ctx.reserverSalleAffairesNovomirsk();
 assert.equal(calls.length,1);
 assert.equal(calls[0][0],'sovarka_reunion_reserver');
 assert.equal(calls[0][1].p_salle,'reunion_grande_a');
 assert.equal(payments.length,1);
 assert.equal(journal.length,1);
 assert.equal(toast.at(-1)[0],'Réservation confirmée');
});
test('réponse perdue: pas de second débit ni succès inventé; réponse déjà réservée sans débit',async()=>{
 const state={currentRoom:'reunion_moyenne_b',currentBuilding:'centre-affaires',country:'soviet',currentCity:'capitale'};
 const toasts=[],payments=[],calls=[];
 let response=null;
 const ctx=createContext({console,state,window:{confirm:()=>true},
   sbRpcVerdict:async(n,args)=>{calls.push(args.p_salle);return response;},
   showToast:(...x)=>toasts.push(x),appliquerPaiementServeur:v=>payments.push(v),
   updateUI:()=>{}});
 runInContext(lire('plateau-router.js'),ctx);
 await ctx.reserverSalleAffairesNovomirsk();
 assert.equal(payments.length,0);
 assert.equal(toasts.at(-1)[0],'Réponse non confirmée');
 response={ok:true,deja_reservee:true,montant:100};
 await ctx.reserverSalleAffairesNovomirsk();
 assert.equal(payments.length,0);
 assert.equal(toasts.at(-1)[0],'Déjà réservée');
 assert.equal(calls.length,2,'seulement une nouvelle tentative volontaire');
});
test('SQL: tarif serveur non dérivable du client, authentification et verrou transactionnel',()=>{
 const sql=lire('migrations/20261106234000_sovarka_reunions_journalieres.sql');
 assert.match(sql,/v_moi := public\.mon_personnage\(\)/);
 assert.match(sql,/current_room=p_salle/);
 assert.match(sql,/pg_advisory_xact_lock/);
 assert.match(sql,/v_cout := CASE WHEN p_salle LIKE 'reunion_grande_%' THEN 150 ELSE 100 END/);
 assert.match(sql,/payer_ordre_interne\(v_moi,v_fn,0,v_cout\)/);
 assert.match(sql,/caisse_institution_mouvement\(v_caisse,v_cout,true\)/);
 assert.match(sql,/PRIMARY KEY \(jour,salle\)/);
 assert.match(sql,/REVOKE ALL ON FUNCTION .* FROM PUBLIC,anon/);
 assert.match(sql,/GRANT EXECUTE .* TO authenticated/);
});
