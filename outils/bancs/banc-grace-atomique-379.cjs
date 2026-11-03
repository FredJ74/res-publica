'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const sql=fs.readFileSync(path.join(root,'migrations/20261103133000_grace_presidentielle_transactionnelle_379.sql'),'utf8');
const source=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
const start=source.indexOf('async function confirmerGrace(');
const end=source.indexOf('\nfunction ouvrirModalNationaliser()',start);
assert.ok(start>=0&&end>start);
const fn=source.slice(start,end);
function scene(verdict){
 const calls=[],state={pop:50,pa:10,day:1,prisonniers:[{nom:'Cible',jourFin:6}]};
 const ctx={state,console,
  exigerPoste:()=>true,
  document:{getElementById:()=>({classList:{remove:()=>{}}})},
  sbRpcVerdict:async (name,args)=>{calls.push(['rpc',name,args]);return verdict;},
  appliquerPaiementServeur:v=>{calls.push(['paiement']);state.pa=v.pa;},
  adopterJaugeServeur:(k,v)=>{calls.push(['jauge']);state[k]=v;},
  updateUI:()=>calls.push(['ui']),
  showToast:(...x)=>calls.push(['toast',...x]),
  addJournalEntry:(...x)=>calls.push(['journal',...x]),
  addExternalEvent:(...x)=>calls.push(['event',...x])};
 vm.createContext(ctx);vm.runInContext(fn,ctx);
 return {calls,state,run:()=>vm.runInContext("confirmerGrace('g1','Cible',true,2,0)",ctx)};
}
test('verdict refuse : aucun paiement client ni effet sur les jauges',async()=>{
 const s=scene({ok:false,raison:'pa_insuffisants'});await s.run();
 assert.equal(s.calls[0][1],'grace_presidentielle_decider');
 assert.equal(s.calls[0][2].p_demande_id,'g1');
 assert.equal(s.calls[0][2].p_accepte,true);
 assert.ok(!s.calls.some(x=>['paiement','jauge','event','journal'].includes(x[0])));
});
test('réponse perdue : aucune décision annoncée',async()=>{
 const s=scene(null);await s.run();
 assert.ok(!s.calls.some(x=>['paiement','jauge','event'].includes(x[0])));
});
test('rejeu confirmé : aucun effet supplémentaire',async()=>{
 const s=scene({ok:true,rejoue:true,statut:'acceptee'});await s.run();
 assert.ok(!s.calls.some(x=>['paiement','jauge','event'].includes(x[0])));
});
test('acceptation : copie seulement les chiffres du serveur et annonce une fois',async()=>{
 const s=scene({ok:true,rejoue:false,accepte:true,libere:true,condamne:'Cible',pop_delta:5,pop:55,pa:8});
 await s.run();
 assert.equal(s.state.pop,55);assert.equal(s.state.pa,8);
 assert.equal(s.calls.filter(x=>x[0]==='event').length,1);
});
test('contrat SQL : autorité, dossier verrouillé, transaction QHS et anti-rejeu',()=>{
 for(const needle of [
 "public.exiger_poste('president')","FROM public.demandes_grace",
 "FOR UPDATE","v_dossier.statut <> 'attente'",
 "payer_ordre_interne(v_president,'gracier',2,0)",
 "detention_clore_interne(v_condamne,'grace_presidentielle',NULL)",
 "SET resources = jsonb_set","WHERE id=p_demande_id AND statut='attente'",
 "REVOKE ALL ON FUNCTION public.presidence_gracier(text,integer)"
 ])assert.ok(sql.includes(needle),needle);
 assert.ok(!fn.includes('sbMajDemandeGrace('));
 assert.ok(!fn.includes('deduireCoutOrdre('));
 assert.ok(!fn.includes('state.pop ='));
});
