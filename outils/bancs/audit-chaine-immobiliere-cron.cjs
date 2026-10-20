#!/usr/bin/env node
// Audit reproductible, effets reseau simules uniquement. Aucun appel HTTP possible.
'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path'),crypto=require('node:crypto');
const acorn=require('../vercel/node_modules/acorn'),root=path.resolve(__dirname,'../..');
const lire=f=>fs.readFileSync(path.join(root,f),'utf8'),copie=x=>JSON.parse(JSON.stringify(x));
function declarations(f,choix){const s=lire(f);return acorn.parse(s,{ecmaVersion:'latest',sourceType:'module'}).body.map(n=>n.type==='ExportNamedDeclaration'?n.declaration:n).filter(n=>n&&(n.type==='FunctionDeclaration'||n.type==='VariableDeclaration')&&(!choix||choix(n))).map(n=>s.slice(n.start,n.end)).join('\n');}
const constantes=new Set(['CHANTIER_SEUILS_SERVEUR','TAUX_HORAIRE_SERVEUR','ENTREPOTS_PAR_VILLE_SERVEUR','SEQUENCE_METAL_SERVEUR','MATERIAUX_SERVEUR','PRETS_GELES_AVANT']);
function moteur(){const c=vm.createContext({console:{error(){},warn(){},log(){}},HEADERS_SERVICE:{},ECHECS_PASSE:[],signalerEchec:()=>{},Date});vm.runInContext(declarations('api/_referentiels-generes.js',n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='RESSOURCES_ECONOMIE_SERVEUR'))+'\n'+declarations('api/cron-minuit.js',n=>n.type==='FunctionDeclaration'||n.declarations.some(d=>constantes.has(d.id.name))),c);c.jourParisISO=()=> '2026-10-20';return c;}
const observations=[];function noter(id,c,texte,nature='anomalie_reproduite'){assert.ok(c,id+' : constat non reproduit');observations.push({id,resultat:nature,constat:texte});}
function chantier(){return {type:'construction',niveau:'hangar',dureeJours:6,progressionJours:0,coutTotal:30000,totalVerse:30000,tresorerie:30000,coutTravail:21000,coutMateriaux:9000,heuresFaites:0,stockMateriaux:{bois:0,minerai:0,metal:0}};}
function decorChantier({echec=false,termine=false,concurrence=false}={}){const c=moteur(),ch=chantier();if(concurrence){ch.totalVerse=21000;ch.tresorerie=21000;}if(termine){ch.progressionJours=6;ch.tresorerie=0;}
 const terrain={id:'republic_audit-parcelle',country:'republic',data:JSON.stringify({proprietaire:'AuditeurA',city:'capitale',chantier:ch})},entrepot={entrepot:{stock:{bois:1000,minerai:1000,metal:1000},reserveMilitaire:{bois:1000,minerai:1000,metal:1000}}};let caisse=0,mails=0,autreApport=false;
 c.sbGet=async table=>table==='terrains_etat'?[copie(terrain)]:[];
 c.sbGetBatimentEtat=async()=>copie(entrepot);
 c.sbSetBatimentEtat=async(p,v,b,patch)=>{Object.assign(entrepot,copie(patch));if(concurrence&&!autreApport){const etat=JSON.parse(terrain.data);etat.chantier.tresorerie+=1000;etat.chantier.totalVerse+=1000;terrain.data=JSON.stringify(etat);autreApport=true;}return {};};
 c.sbRpc=async(n,p)=>{if(n==='entrepot_caisse_mouvement')caisse+=p.p_delta;return {ok:true};};
 c.sbUpdate=async(table,filtre,patch)=>{if(table==='terrains_etat'){if(echec)return null;Object.assign(terrain,copie(patch));}return [{}];};
 c.sbInsert=async()=>[{}];c.envoyerMailSysteme=async()=>{mails++;};return {c,terrain,entrepot,get caisse(){return caisse;},get mails(){return mails;}};
}
async function main(){
 const r=decorChantier({echec:true});await r.c.avancerChantiersQuotidien();const premier=r.caisse;await r.c.avancerChantiersQuotidien();
 noter('J01',r.entrepot.entrepot.stock.bois===800&&JSON.parse(r.terrain.data).chantier.stockMateriaux.bois===0&&r.caisse===premier*2,'Echec ecriture terrain : entrepot debite/credite deux fois au rejeu, aucun materiau conserve au chantier.');
 noter('J02',r.entrepot.entrepot.reserveMilitaire.bois===1000&&r.entrepot.entrepot.stock.bois<1000,'Approvisionnement cron puise dans la reserve militaire que le moteur SQL manuel soustrait.');
 const race=decorChantier({concurrence:true});await race.c.avancerChantiersQuotidien();
 noter('J03',JSON.parse(race.terrain.data).chantier.totalVerse===21000,'Un apport concurrent de 1000 FR est ecrase par le snapshot ancien du cron.');
 const fini=decorChantier({echec:true,termine:true});const resultat=await fini.c.avancerChantiersQuotidien();
 noter('J04',resultat.livraisons===1&&fini.mails===1&&!!JSON.parse(fini.terrain.data).chantier&&!JSON.parse(fini.terrain.data).niveau_construction,'Livraison annoncee et comptee avant une persistance refusee ; batiment non livre apres relecture.');
 for(const panne of ['personnage','dette']){
  const c=moteur(),pret={id:'audit-pret',emprunteur:'AuditeurA',country:'republic',type_banque:'nationale',statut:'en_cours',montant_restant:5000,mensualite:500,jours_impayes:0,jour_dernier_prelevement:null,created_at:'2026-10-01T12:00:00'},pers={arg:10000,liquide:10000};
  c.sbGet=async t=>t==='prets'?[copie(pret)]:t==='personnages'?[copie(pers)]:[];
  c.sbUpdate=async(t,f,p)=>{if(t==='prets'){Object.assign(pret,copie(p));return [{id:pret.id}];}if(t==='personnages'){if(panne==='personnage')return null;Object.assign(pers,copie(p));}return [{}];};
  c.sbUpdatePret=async(id,p)=>{if(panne==='dette')return null;Object.assign(pret,copie(p));return [{}];};c.envoyerMailSysteme=async()=>{};
  const v=await c.preleverPretsBancairesServeur();
  noter(panne==='personnage'?'J05':'J06',v.preleves===1&&pret.jour_dernier_prelevement==='2026-10-20'&&(panne==='personnage'?pers.liquide===10000&&pret.montant_restant===4500:pers.liquide===9500&&pret.montant_restant===5000),'Mensualite avec echec '+panne+' : argent et dette divergent, journee deja revendiquee, compteur de succes incremente.');
 }
 const achats=vm.createContext({state:{char:{name:'AuditeurA'},country:'republic',currentBuilding:'audit-parcelle',arg:10000,liquide:10000},COUNTRIES:{republic:{cur:'FR'}},SURFACE_TERRAINS:{},PRIX_AU_M2_TERRAIN:12,ACOMPTE_ACHAT_DIRECT:1000,terrainOrdreDisponible:()=>({ok:true}),showToast:()=>{},signalerRefusTerrain:()=>{}});
 vm.runInContext(declarations('plateau-pnj.js',n=>n.type==='FunctionDeclaration'&&n.id.name==='doAcheterTerrain'),achats);
 achats.deduireCoutOrdre=async()=>{achats.state.liquide-=1000;return {ok:true};};achats.sbTerrainActe=async()=>({ok:false,raison:'terrain_indisponible'});await achats.doAcheterTerrain();
 noter('J07',achats.state.liquide===9000,'Depot client : paiement effectue avant refus de reservation du terrain, sans remboursement dans le handler.');
 const c=moteur();vm.runInContext(lire('plateau-chantiers.js'),c);const gabarit=c.creerChantierConstruction('commerce_premium',1);const etat={proprietaire:'AuditeurA',surface:2000,permis:{decoupageInitial:[{id:'audit-lot',surface:500,destination:'commerce'}]},chantier:{...gabarit,totalVerse:gabarit.coutTotal,tresorerie:0,progressionJours:gabarit.dureeJours}};const livraison=c.livrerChantierServeur(etat,'2026-10-20');
 noter('G04',livraison.livre&&!etat.chantier&&etat.niveau_construction==='commerce_premium'&&etat.subdivisions.length===1,'Livraison pure deplace le chantier et materialise les lots dans le meme objet.','garantie_locale_observee');
 // Surfaces utilisees par le vrai handler, comparees aux descriptions canoniques.
 vm.runInContext(declarations('plateau-pnj.js',n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>['SURFACE_TERRAINS','PRIX_AU_M2_TERRAIN','ACOMPTE_ACHAT_DIRECT'].includes(d.id.name))),achats);
 achats.state.currentBuilding='terrain-a-batir-8';achats.state.liquide=10000;let demande;
 achats.sbTerrainActe=async(n,p)=>{demande=p.p_patch.achatDirect;return {ok:false,raison:'terrain_indisponible'};};await achats.doAcheterTerrain();
 const data=vm.createContext({});vm.runInContext(lire('data.js'),data);
 const desc=vm.runInContext("BUILDINGS['terrain-a-batir-8'].rooms.terrain8.desc",data);
 noter('J08',demande.surface===2000&&demande.prix===24000&&desc.includes('1500m2'),'Port-Sainte-Marie : surface canonique 1500 m2, achat direct calcule sur 2000 m2 et 24000 FR.');
 const miroirIndex=process.argv.indexOf('--ordres');assert.ok(miroirIndex>=0,'--ordres exige : JSON du generateur reel generer_ordres_couts.py --json');
 const triples=JSON.parse(fs.readFileSync(process.argv[miroirIndex+1],'utf8'));
 noter('J09',!triples.some(o=>o.fn==='acheter_terrain'&&o.pa===2&&o.cost===1000)&&triples.some(o=>o.fn==='acheter_terrain'),'Acompte acheter_terrain 2 PA / 1000 FR absent du miroir genere, payer_ordre le refuse s il est conforme.');
 noter('J10',triples.some(o=>o.fn==='officialiser_transaction'&&o.cost===0)&&!triples.some(o=>o.fn==='officialiser_transaction'&&o.cost>0),'Solde notarial variable incompatible avec le miroir officialiser_transaction qui declare uniquement 0 FR.');
 const prets=vm.createContext({console,state:{char:{name:'AuditeurA'},country:'republic',currentBuilding:'banque-nationale',comptesBancaires:{nationale:{solde:500}}},COUNTRIES:{republic:{cur:'FR'}},INDICES_NATIONAUX:{},document:{getElementById:id=>({value:id==='pret-montant'?'100000':'20',classList:{remove(){}}})},showToast:()=>{},signalerRefusCout:()=>{},updateUI:()=>{},addJournalEntry:()=>{},deduireCoutOrdre:async()=>({ok:true}),sbGetPretsEnCours:async()=>[],sbRpc:async()=>({ok:true,arg:100500,liquide:0,solde_banque:100500})});
 vm.runInContext(declarations('plateau-justice-economie.js',n=>n.type==='FunctionDeclaration'&&['confirmerPretBancaire','getTauxPret'].includes(n.id.name)||n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='TYPES_PRET')),prets);
 let erreur;try{await prets.confirmerPretBancaire('nationale','travaux',0);}catch(e){erreur=e;}
 noter('J11',erreur?.message.includes('find is not a function')&&prets.state.comptesBancaires.nationale.solde===500,'Apres un succes serveur, le handler de pret appelle .find sur la map bancaire : exception et solde bancaire affiche perime.');
 const saisie=moteur(),dette={id:'audit-saisie',emprunteur:'AuditeurA',country:'republic',type_banque:'nationale',statut:'en_cours',montant_restant:5000,mensualite:500,jours_impayes:3,jour_dernier_prelevement:null,created_at:'2026-10-01T12:00:00',building_id:'audit-parcelle'},terrainSaisi={id:'republic_audit-parcelle',proprietaire:'AuditeurA',data:JSON.stringify({proprietaire:'AuditeurA',chantier:chantier(),valeur_totale:30000})};
 saisie.sbGet=async t=>t==='prets'?[copie(dette)]:t==='personnages'?[{arg:0,liquide:0}]:t==='terrains_etat'?[copie(terrainSaisi)]:[];
 saisie.sbUpdate=async(t,f,p)=>{Object.assign(t==='prets'?dette:terrainSaisi,copie(p));return [{id:'fixture'}];};saisie.sbUpdatePret=async(id,p)=>{Object.assign(dette,copie(p));return [{}];};saisie.envoyerMailSysteme=async()=>{};
 await saisie.preleverPretsBancairesServeur();const apresSaisie=JSON.parse(terrainSaisi.data);
 noter('J12',apresSaisie.proprietaire===null&&!!apresSaisie.chantier&&terrainSaisi.proprietaire==='AuditeurA','Saisie nationale : chantier toujours actif sans proprietaire JSON, ancienne colonne proprietaire conservee.');
 vm.runInContext(declarations('plateau-justice-economie.js',n=>n.type==='FunctionDeclaration'&&n.id.name==='getVilleTerrain'||n.type==='VariableDeclaration'&&n.declarations.some(d=>['TERRAINS_LUTHECIA','TERRAINS_PAR_VILLE'].includes(d.id.name))),data);
 const erreursVille=vm.runInContext("Object.entries(WORLD).flatMap(([p,villes])=>Object.entries(villes).flatMap(([v,ville])=>ville.buildings.filter(id=>id.startsWith('terrain-a-batir')&&getVilleTerrain(id)!==v).map(id=>({pays:p,ville:v,terrain:id,villeCalculee:getVilleTerrain(id)}))))",data);
 noter('J13',erreursVille.length===9,'Le classement de ville utilise les seules listes de Republia : neuf terrains des trois autres empires sont rattaches a la mauvaise ville.');
 const sortie={nature:'audit_JS_sur_code_reel_avec_IO_de_fixture',productionConsultee:false,observations,erreursVille,sources:Object.fromEntries(['api/cron-minuit.js','plateau-pnj.js','plateau-justice-economie.js','plateau-chantiers.js','data.js'].map(f=>[f,crypto.createHash('sha256').update(lire(f)).digest('hex')]))};
 const i=process.argv.indexOf('--rapport');if(i>=0)fs.writeFileSync(process.argv[i+1],JSON.stringify(sortie,null,2)+'\n');for(const o of observations)console.log(o.id,o.resultat,o.constat);console.log(observations.length+' constats locaux reproduits ; aucun acces reseau.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
