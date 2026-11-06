'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const file=name=>fs.readFileSync(path.join(root,name),'utf8');
const data=file('data.js');
const block=data.slice(data.indexOf("  'services-sociaux-montrouge': {"),data.indexOf("  'parking-tribunal-montrouge': {"));
const migration=file('migrations/20261103023000_ssm_rendezvous_logements.sql');
const housing=file('plateau-logements-sociaux.js');
const router=file('plateau-router.js');
const navigation=file('plateau-navigation.js');
const profiles=file('api/_pnj-personnalites.js');
const html=file('plateau.html');

test('Pascale propose un RDV gratuit ; Edwige reprend exactement la demande mairie 1 PA',()=>{
 assert.match(block,/fn:'ssm_demander_rendezvous', label:'Prendre rendez-vous avec Edwige Jacquard', pa:0, cost:0/);
 assert.match(block,/bureau_assistante_sociale:[\s\S]*?fn:'demander_logement_social', label:'Déposer une demande de logement social', pa:1, cost:0/);
 assert.match(router,/if \(fn === 'ssm_demander_rendezvous'\) \{ demanderRendezVousSsm\(\)/);
 assert.match(router,/if \(fn === 'demander_logement_social'\) \{ demanderLogementSocialCommun\(pa, cost\)/);
 assert.match(housing,/sbRpcVerdict\('logement_social_demander', \{ p_type: type \|\| null \}\)/);
});

test('le rendez-vous ne dépend ni du navigateur ni de sa date locale',()=>{
 assert.match(migration,/current_building,v_pj.current_room\)[\s\S]*?services-sociaux-montrouge','accueil'/);
 assert.match(migration,/statement_timestamp\(\) AT TIME ZONE 'Europe\/Paris'/);
 assert.match(migration,/v_rdv date := v_aujourdhui \+ 1/);
 assert.match(migration,/rendezvous_le > demande_le AND rendezvous_le <= demande_le \+ 7/);
 assert.match(migration,/FOR UPDATE/);
 assert.match(migration,/v_actuel.rendezvous_le >= v_aujourdhui/);
 assert.match(migration,/mail_systeme_poser_interne/);
 assert.match(migration,/RAISE EXCEPTION 'ssm_courrier_impossible'/);
 assert.match(migration,/mail_envoye',true/);
 assert.doesNotMatch(migration,/\bUPDATE\s+public\.personnages_donnees\b/i);
});

test('le bureau est bloqué par le SERVEUR sans RDV aujourd hui, même en vérification',()=>{
 assert.match(migration,/navigation_interieure_personnage_interne\(text,text,text,boolean\)/);
 assert.match(migration,/p_piece=''bureau_assistante_sociale''/);
 assert.match(migration,/NOT public\.ssm_rendezvous_valide_interne\(p_nom\)/);
 assert.match(migration,/rendezvous_ssm_requis/);
 assert.match(migration,/rdv.rendezvous_le = \(statement_timestamp\(\) AT TIME ZONE 'Europe\/Paris'\)::date/);
 assert.match(navigation,/rendezvous_ssm_requis:'Le bureau d’Edwige Jacquard/);
 assert.match(migration,/REVOKE ALL ON public.ssm_rendezvous FROM PUBLIC, anon, authenticated, service_role/);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public.ssm_rendezvous_demander\(\) TO authenticated/);
});

test('l adjoint et Edwige utilisent la même RPC, sans attribuer directement un logement',()=>{
 assert.match(migration,/logement_social_demander\(text\)/);
 assert.match(migration,/p.current_building NOT IN \(''mairie'',''mairie-capitale''\)/);
 assert.match(migration,/p.current_room=''bureau_assistante_sociale''/);
 assert.match(migration,/public.ssm_rendezvous_valide_interne\(moi\)/);
 assert.doesNotMatch(migration,/CREATE OR REPLACE FUNCTION public.logement_social_attribuer/);
 assert.match(profiles,/edwige_jacquard/);
 assert.match(profiles,/jardins ouvriers de Montrouge/);
 assert.match(profiles,/Marcel Demine/);
});

test('les quatre scripts SSM restent versionnés après les autres chantiers',()=>{
 for(const name of ['data.js','plateau-navigation.js','plateau-logements-sociaux.js','plateau-router.js']){
  assert.ok(html.includes(name+'?v='),name+' sans version navigateur');
 }
 assert.ok(html.includes('plateau-logements-sociaux.js?v=ssm-rdv-20261103'));
});

test('écran : succès uniquement si serveur confirme ; aucun mail inventé en cas de refus',async()=>{
 const events=[];
 const ctx={console, sbRpcVerdict:async()=>({ok:false,raison:'pas_a_l_accueil'}),
   showToast:(...args)=>events.push(args), addJournalEntry:()=>events.push(['journal'])};
 vm.createContext(ctx);vm.runInContext(housing,ctx);
 await vm.runInContext('demanderRendezVousSsm()',ctx);
 assert.equal(events.length,1);
 assert.match(events[0][1],/Présentez-vous/);
 events.length=0;
 ctx.sbRpcVerdict=async()=>({ok:true,date:'2026-11-04',mail_envoye:true,deja_fixe:false});
 await vm.runInContext('demanderRendezVousSsm()',ctx);
 assert.match(events[0][1],/04\/11\/2026/);
 assert.ok(events.some(e=>e[0]==='journal'));
 events.length=0;
 ctx.sbRpcVerdict=async()=>({ok:true,date:'2026-11-04',deja_fixe:true});
 await vm.runInContext('demanderRendezVousSsm()',ctx);
 assert.match(events[0][1],/déjà fixé/);
 assert.equal(events.length,1,'aucun journal supplémentaire quand le rendez-vous existait');
});

test('DeepSeek : les deux agentes ont un corpus métier, pas le prompt des PNJ ordinaires',()=>{
 const ordinary=profiles.slice(profiles.indexOf('const ORDINAIRES = {'),profiles.indexOf('const RICHES = {'));
 const rich=profiles.slice(profiles.indexOf('const RICHES = {'),profiles.indexOf('const SOCIAUX = {'));
 assert.doesNotMatch(ordinary,/'pascale':/);
 assert.doesNotMatch(ordinary,/'edwige_jacquard':/);
 assert.match(rich,/'pascale':[\s\S]*?savoirs:/);
 assert.match(rich,/'edwige_jacquard':[\s\S]*?savoirs:/);
 assert.match(rich,/Marcel Demine/);
 assert.match(rich,/dépensant 1 PA/);
 assert.match(rich,/aucune démarche ou prestation absente/);
});

test('Besoin d’aide : orientation libre, quatre rubriques et portrait récupéré depuis le PNJ',()=>{
 assert.match(block,/fn:'ssm_besoin_aide', label:'Besoin d’aide \?', pa:0, cost:0/);
 assert.match(router,/if \(fn === 'ssm_besoin_aide'\) \{ ouvrirAidePascaleSsm\(\)/);
 assert.match(housing,/function ouvrirAidePascaleSsm\(rubrique\)/);
 for(const rubrique of ['Se loger','Se nourrir','Se soigner','Trouver du travail'])assert.ok(housing.includes(rubrique),rubrique);
 const begin=housing.indexOf('function ouvrirAidePascaleSsm(rubrique)');
 const implementation=housing.slice(begin);
 assert.ok(implementation.includes("p.name === 'Pascale (PNJ)'"));
 assert.ok(implementation.includes('pnj.photoUrl'));
 assert.ok(implementation.includes("modal.classList.add('open')"));
 assert.doesNotMatch(implementation,/sbRpc|deduireCoutOrdre|appliquerPaiementServeur/);
 const mockModal={classList:{add:()=>{}},innerHTML:''};
 const mockTitle={textContent:''};
 const mockBody={innerHTML:''};
 const ctx={
   document:{getElementById:id=>({'modal-postes':mockModal,'postes-modal-title':mockTitle,'postes-body':mockBody})[id]},
   BUILDINGS:{'services-sociaux-montrouge':{rooms:{accueil:{persons:[{name:'Pascale (PNJ)',photoUrl:'images/personnages/portrait-de-pascale.webp'}]}}}},
   console
 };
 vm.createContext(ctx);vm.runInContext(housing,ctx);
 vm.runInContext('ouvrirAidePascaleSsm()',ctx);
 assert.equal(mockTitle.textContent,'Besoin d’aide ?');
 assert.match(mockBody.innerHTML,/portrait-de-pascale.webp/);
 for(const rubrique of ['Se loger','Se nourrir','Se soigner','Trouver du travail'])assert.ok(mockBody.innerHTML.includes(rubrique),rubrique);
 vm.runInContext("ouvrirAidePascaleSsm('logement')",ctx);
 assert.match(mockBody.innerHTML,/Edwige Jacquard/);
 assert.match(mockBody.innerHTML,/Retour aux rubriques/);
});
