'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const win={};const ctx=vm.createContext({window:win});
for(const file of ['resources.js','orders-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const engine={t(key,{lng,defaultValue}){return key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue}};
test('97 ordres canoniques ont les mêmes identifiants dans neuf langues',()=>{
 const ref=Object.keys(win.RP_I18N_RESOURCES.fr.translation.orders);
 assert.equal(ref.length,97);
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)) {
  const data=win.RP_I18N_RESOURCES[lang].translation.orders;
  assert.deepEqual(Object.keys(data),ref);
  for(const label of Object.values(data)) assert.ok(label);
 }
});
test('la langue ne modifie pas la commande serveur ni son coût',()=>{
 const source=Object.freeze({fn:'voter_election',label:'Voter',pa:1,cost:0});
 assert.equal(win.RPOrderI18n.label(source,engine,'de'),'Abstimmen');
 assert.equal(win.RPOrderI18n.label(source,engine,'ar'),'التصويت');
 assert.equal(source.label,'Voter');assert.equal(source.pa,1);
});
test('une variation de prix reste canonique sans clé contextuelle',()=>{
 const source=Object.freeze({fn:'louer_local',label:'Louer ce local (800 FR/jour)',cost:800});
 assert.equal(win.RPOrderI18n.label(source,engine,'en'),source.label);
});

test('les 14 nouveaux libellés sont ancrés dans les ordres réellement déclarés',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=[
  'plainte_police','se_justifier','organiser_filature','recruter_policier',
  'consulter_dossier_notarial','gerer_testament','reclamer_heritage',
  'consulter_archives_notariales','consulter_offres_emploi','observer_match',
  'regarder_live','prendre_licence_sportive','emprunter','se_rebeller'
 ];
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
  assert.ok(Object.hasOwn(words,fn),'entrée française manquante '+fn);
  // Le catalogue n'invente pas d'ordre et ne change aucune fonction serveur.
  assert.ok(source.includes("fn:'"+fn+"'") || source.includes('fn:"'+fn+'"'),
   'ordre absent des déclarations du jeu : '+fn);
  const order=Object.freeze({fn,label:words[fn],pa:2,cost:345,requiresPost:'quelconque'});
  for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
   const translated=win.RPOrderI18n.label(order,engine,lang);
   assert.equal(translated,win.RP_I18N_RESOURCES[lang].translation.orders[fn]);
   assert.ok(translated.trim(),'libellé vide '+lang+' '+fn);
  }
  assert.equal(order.label,words[fn]); assert.equal(order.pa,2); assert.equal(order.cost,345);
 }
});

test('tous les libellés pilotes français correspondent exactement aux vrais ordres du socle',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const actual=new Map();
 for(const m of source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)){
  if(!actual.has(m[2]))actual.set(m[2],new Set());
  actual.get(m[2]).add(m[4]);
 }
 const canonical=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const [fn,reference] of Object.entries(canonical)){
  assert.ok(actual.get(fn)?.has(reference),
   'libellé non canonique : '+fn+' → '+JSON.stringify(reference));
 }
});

test('18 ordres complémentaires des parcours essentiels conservent leurs identifiants et les neuf traductions',()=>{
 const ids=[
  'dormir_chambre','consulter_archives_presse','choisir_suite','gerer_commerce',
  'solliciter_audience_president','temoin_deposition','rejoindre_club_supporters',
  'lancer_rumeur_cible','offrir_tournee','registre_assemblee','dossiers_plaintes',
  'gerer_juges','parquet','postuler','ouvrir_enquete','gestion_caserne',
  'emprunter_prive','avocat_barreau'
 ];
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids) {
  assert.ok(Object.hasOwn(words,fn),'ordre absent des ressources : '+fn);
  assert.ok(source.includes("fn:'"+fn+"'") || source.includes('fn:"'+fn+'"'),
   'ordre absent du socle : '+fn);
  const original=Object.freeze({fn,label:words[fn],pa:3,cost:127,requiresPost:'min_def'});
  for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
   const expected=win.RP_I18N_RESOURCES[lang].translation.orders[fn];
   assert.ok(typeof expected==='string' && expected.trim(),'traduction '+lang+'/'+fn);
   assert.equal(win.RPOrderI18n.label(original,engine,lang),expected);
  }
  assert.equal(original.pa,3);assert.equal(original.cost,127);assert.equal(original.requiresPost,'min_def');
 }
});

test('dix ordres de démocratie, élections et parlement sont traduits sans modifier leurs commandes',()=>{
 const ids=[
  'contester_resultats','falsifier_listes_electorales','bourrer_urnes',
  'truquer_depouillement','consulter_mandats_maires','observer_debats',
  'voter_loi','projet_loi','amender_projet','marchander_vote'
 ];
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
  assert.ok(source.includes("fn:'"+fn+"'") || source.includes('fn:"'+fn+'"'),'ordre métier absent '+fn);
  const order=Object.freeze({fn,label:words[fn],pa:2,cost:70,requiresPost:'depute'});
  for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
   assert.equal(win.RPOrderI18n.label(order,engine,lang),win.RP_I18N_RESOURCES[lang].translation.orders[fn]);
  }
  assert.equal(order.label,words[fn]);
  assert.equal(order.pa,2);assert.equal(order.cost,70);assert.equal(order.requiresPost,'depute');
 }
});

test('20 ordres civiques complémentaires ont des libellés stables en neuf langues',()=>{
 const ids=['consulter_catalogue_manufactures','bne_passer_annonce','gestion_manifestations',
  'demandes_naturalisation','gerer_couvre_feu','gerer_chef_douanes','subvention_min_int',
  'pilotage_fiscal_budgetaire','gestion_qhs','mobilisation_nationale','activer_cessez_le_feu',
  'censurer_media','commanditer_sondage','proposer_treve','calendrier_elections',
  'seance_parlementaire','reveiller_depute','consulter_lobbyiste','demander_divorce','gerer_ambassades'];
 const canonical=win.RP_I18N_RESOURCES.fr.translation.orders;
 for (const id of ids) {
   const original=Object.freeze({fn:id,label:canonical[id],pa:7,cost:431,requiresPost:'poste_test'});
   for (const lang of Object.keys(win.RP_I18N_LANGUAGES)) {
     const translated=win.RPOrderI18n.label(original,engine,lang);
     assert.equal(translated,win.RP_I18N_RESOURCES[lang].translation.orders[id],lang+':'+id);
     assert.ok(translated.trim());
   }
   assert.equal(original.fn,id);
   assert.equal(original.label,canonical[id]);
   assert.equal(original.pa,7);
   assert.equal(original.cost,431);
   assert.equal(original.requiresPost,'poste_test');
 }
});


test('20 ordres gouvernement, presse et économie : labels source exacts et contrats intacts',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=[
  "article",
  "etouffer",
  "recruter_informateur_pnj",
  "escort_piege",
  "gestion_premier_ministre",
  "postes_par_decret",
  "pouvoirs_exceptionnels",
  "adresse_a_la_nation",
  "gracier",
  "effort_national",
  "reception_etat",
  "banquet_diplo",
  "nommer_ministre_pm",
  "revoquer_ministre_pm",
  "declencher_vote_confiance",
  "consulter_dossiers_gouv",
  "fuite_info",
  "subvention",
  "gestion_industrielle_portuaire",
  "preempter_entreprise"
];
 const originalLabels=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
   const label=originalLabels[fn];
   assert.equal(typeof label,'string',fn);
   // Correspondance littérale avec les déclarations, sans dépendre du coût ou du poste.
   assert.ok(source.includes("fn:'"+fn+"', label:'"+label+"'") ||
     source.includes("fn:'"+fn+"',        label:'"+label+"'") ||
     new RegExp("fn\\s*:\\s*['\\\"]"+fn+"['\\\"]\\s*,\\s*label\\s*:\\s*['\\\"]"+label.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+"['\\\"]").test(source),
     'libellé français absent de data.js pour '+fn);
   const order=Object.freeze({fn,label,pa:3,cost:175,requiresPost:'president'});
   for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
     const expected=win.RP_I18N_RESOURCES[lang].translation.orders[fn];
     assert.ok(typeof expected==='string' && expected.trim(),lang+'/'+fn);
     assert.equal(win.RPOrderI18n.label(order,engine,lang),expected,lang+'/'+fn);
   }
   assert.equal(order.label,label);assert.equal(order.pa,3);assert.equal(order.cost,175);
   assert.equal(order.requiresPost,'president');
 }
});
