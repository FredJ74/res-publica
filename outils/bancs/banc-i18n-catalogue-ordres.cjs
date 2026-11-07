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
test('237 ordres canoniques ont les mêmes identifiants dans neuf langues',()=>{
 const ref=Object.keys(win.RP_I18N_RESOURCES.fr.translation.orders);
 assert.equal(ref.length,237);
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


test('20 ordres sport et justice : présence réelle, traductions et droits intacts',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["tenue_match","consommer_buvette","choisir_accessoire_club","acheter_accessoire_personnalise","parier_match","consulter_classement_joueurs_club","consulter_palmares","declencher_election_club","organiser_manifestation","organiser_boycott","postuler_president_club","consulter_bureau_president","proposer_transfert","gerer_offres_transfert","sponsoriser_club","consulter_budget_club","gerer_salaires_club","rendre_sentence","falsifier_document","demander_juge_instruction"];
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
   const label=words[fn];
   assert.equal(typeof label,'string',fn);
   const at=source.search(new RegExp('fn\\s*:\\s*\\x27'+fn+'\\x27'));
   assert.ok(at>=0,'fonction absente du jeu '+fn);
   assert.ok(source.slice(at,at+180).includes("label:'"+label+"'"),
     'libellé de référence différent '+fn);
   const original=Object.freeze({fn,label,pa:4,cost:210,requiresPost:'test_role'});
   for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
     const translated=win.RP_I18N_RESOURCES[lang].translation.orders[fn];
     assert.ok(typeof translated==='string' && translated.trim(),lang+'/'+fn);
     assert.equal(win.RPOrderI18n.label(original,engine,lang),translated,lang+'/'+fn);
   }
   assert.equal(original.fn,fn);assert.equal(original.label,label);
   assert.equal(original.pa,4);assert.equal(original.cost,210);
   assert.equal(original.requiresPost,'test_role');
 }
});


test('20 ordres juridiques et économiques : parité source, neuf langues, aucune mutation',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["officialiser_transaction","commerces_fonds_murs","racheter_entreprise","transfert_compromis","acte_officiel_notaire","demander_non_renouvellement_licence","annuler_non_renouvellement_licence","recolter_matiere","defense","temoins_mes_convocations","acte_officiel_juge","archives","avocat_dossiers","greffe_affaires","garde_republicaine","renseignement_militaire","diplomatie_bilaterale","proposer_grace","gerer_budget_justice","deposer_demande_permis"];
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
   const label=words[fn];
   assert.equal(typeof label,'string',fn);
   const matches=[...source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)];
   assert.ok(matches.some(m=>m[2]===fn && m[4]===label),'libellé source non conforme '+fn);
   const original=Object.freeze({fn,label,pa:3,cost:82,requiresPost:'poste_test'});
   for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
     const translated=win.RP_I18N_RESOURCES[lang].translation.orders[fn];
     assert.ok(typeof translated==='string' && translated.trim(),lang+'/'+fn);
     assert.equal(win.RPOrderI18n.label(original,engine,lang),translated,lang+'/'+fn);
   }
   assert.equal(original.fn,fn);assert.equal(original.pa,3);assert.equal(original.cost,82);
   assert.equal(original.requiresPost,'poste_test');assert.equal(original.label,label);
 }
});


test('20 ordres transports et vie sociale : libellés sources et neuf langues',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["prendre_train","prendre_bus_taxi","prendre_bateau","travailler_jardins","laisser_legumes_jardins","prendre_legumes_jardins","acheter_ressources_entrepot","acheter_criee","marchandises_non_reclamees","inspecter_cargaisons","se_syndiquer","greve_lancer","greve_terminer","greve_generale_appeler","greve_generale_retirer","orga_petition","orga_meeting","demander_autorisation_manifester","orga_collecte","organiser_manifestation_syndicat"];
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 const sourceLabels=new Map();
 for(const match of source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)){
  if(!sourceLabels.has(match[2]))sourceLabels.set(match[2],new Set());
  sourceLabels.get(match[2]).add(match[4]);
 }
 for(const fn of ids){
  const label=words[fn];
  assert.ok(sourceLabels.get(fn)?.has(label),'label source absent '+fn);
  const order=Object.freeze({fn,label,cost:99,pa:2,requiresPost:'agent'});
  for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
   const value=win.RP_I18N_RESOURCES[lang].translation.orders[fn];
   assert.ok(value?.trim(),lang+'/'+fn);
   assert.equal(win.RPOrderI18n.label(order,engine,lang),value);
  }
  assert.equal(order.cost,99);assert.equal(order.pa,2);assert.equal(order.requiresPost,'agent');
 }
});

test('20 ordres immobilier et services sociaux : labels source et contrats inchangés',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["ssm_besoin_aide","ssm_demander_rendezvous","financer_communal","consulter_personnalites_musee","appeler_police_terrain","negocier_squatteurs","signer_compromis","construire_sur_terrain","payer_versement_chantier","travailler_chantier","vendre_materiaux_chantier","diviser_construction","louer_lot_ici","gerer_lot_loue","gerer_fonds_commerce","emprunter_construction","racheter_terrain","organiser_manifestation_spontanee","consulter_devis_chantier_naval","modifier_plan_chantier"];
 const occurrences=[...source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)];
 const words=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
  const original=Object.freeze({fn,label:words[fn],pa:2,cost:95,requiresPost:'owner'});
  assert.ok(occurrences.some(m=>m[2]===fn&&m[4]===original.label),fn);
  for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
    const wanted=win.RP_I18N_RESOURCES[lng].translation.orders[fn];
    assert.ok(typeof wanted==='string'&&wanted.trim(),lng+'/'+fn);
    assert.equal(win.RPOrderI18n.label(original,engine,lng),wanted);
  }
  assert.equal(original.fn,fn);
  assert.equal(original.cost,95);
  assert.equal(original.pa,2);
  assert.equal(original.requiresPost,'owner');
 }
});


test('20 ordres organisations et relations sociales : parité source et opérations immuables',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["orga_pelerinage","orga_excommunier","orga_blocus","orga_dividendes","orga_audit","orga_intimidation","orga_cooptation","orga_reseau","orga_campagne_presse","orga_fake_news","orga_scoop","orga_silence","orga_motion_supporters","orga_hooliganisme","blocus_portuaire","contrebande_port","se_confesser","pelerin","financer_oeuvre_culturelle","relations_bilaterales"];
 const seen=new Map();
 for(const item of source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)){
  if(!seen.has(item[2]))seen.set(item[2],new Set());
  seen.get(item[2]).add(item[4]);
 }
 const fr=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
  const order=Object.freeze({fn,label:fr[fn],pa:4,cost:210,requiresPost:'chef_org'});
  assert.ok(seen.get(fn)?.has(order.label),'non canonique '+fn);
  for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
   const translated=win.RP_I18N_RESOURCES[lng].translation.orders[fn];
   assert.ok(translated?.trim(),lng+'/'+fn);
   assert.equal(win.RPOrderI18n.label(order,engine,lng),translated,lng+'/'+fn);
  }
  assert.equal(order.label,fr[fn]);assert.equal(order.pa,4);assert.equal(order.cost,210);
  assert.equal(order.requiresPost,'chef_org');
 }
});


test('20 ordres industrie et services : labels canoniques et opérations immuables',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["garage_vehicules","garage_reviser","mes_vehicules","salon_coupe","gerer_logement_social","pharmacie_medicaments","station_carburant","tableau_bord_entrepot","fixer_prix_achat_entrepot","vente_directe_usine","fixer_prix_vente_directe","fixer_repartition_production","virement_usine_ministere","produire_carburant","produire_derives_petrochimiques","produire_tabac","produire_medicaments","produire_desinfectant","interroger_renseignement","visiter_prisonnier"];
 const observed=new Map();
 for(const row of source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)){
  if(!observed.has(row[2]))observed.set(row[2],new Set());
  observed.get(row[2]).add(row[4]);
 }
 const fr=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
  const order=Object.freeze({fn,label:fr[fn],pa:3,cost:175,requiresPost:'responsable'});
  assert.ok(observed.get(fn)?.has(order.label),'ordre absent '+fn);
  for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
   const expected=win.RP_I18N_RESOURCES[lng].translation.orders[fn];
   assert.ok(typeof expected==='string'&&expected.trim(),lng+'/'+fn);
   assert.equal(win.RPOrderI18n.label(order,engine,lng),expected,lng+'/'+fn);
  }
  assert.equal(order.fn,fn);assert.equal(order.label,fr[fn]);
  assert.equal(order.pa,3);assert.equal(order.cost,175);assert.equal(order.requiresPost,'responsable');
 }
});


test('20 ordres militaires : labels sources, neuf langues et invariants métier',()=>{
 const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const ids=["nommer_lieutenant","decouvrir_affectation","calepin_campagne","decorer_militaire","demettre_lieutenant","se_presenter_affectation","stage_caserne","retirer_trousse","nommer_capitaine","caisse_caserne","repartir_armement","recruter_compagnie","gerer_detachement","voir_ma_section","entrainer_section","reposer_section","declencher_mutinerie","remonter_renseignement","inspecter_troupes","gerer_budget_caserne"];
 const found=new Map();
 for(const row of source.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)){
  if(!found.has(row[2]))found.set(row[2],new Set());
  found.get(row[2]).add(row[4]);
 }
 const fr=win.RP_I18N_RESOURCES.fr.translation.orders;
 for(const fn of ids){
  const order=Object.freeze({fn,label:fr[fn],cost:199,pa:2,requiresPost:'militaire'});
  assert.ok(found.get(fn)?.has(order.label),fn);
  for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
   const value=win.RP_I18N_RESOURCES[lng].translation.orders[fn];
   assert.ok(typeof value==='string'&&value.trim(),lng+'/'+fn);
   assert.equal(win.RPOrderI18n.label(order,engine,lng),value);
  }
  assert.equal(order.cost,199);assert.equal(order.pa,2);assert.equal(order.requiresPost,'militaire');
 }
});
