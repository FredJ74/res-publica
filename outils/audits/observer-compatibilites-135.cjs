// Diagnostic exécutable sur fixtures exclusivement ; code 2 = défauts observés, jamais un contrôle vert.
// Aucun réseau, compte, paiement ou sauvegarde réels. Ne modifie aucun fichier.
const fs=require('fs'),vm=require('vm'),path=require('path'),R=path.resolve(__dirname,'../..'),acorn=require('../vercel/node_modules/acorn');
function f(f,n){const s=fs.readFileSync(path.join(R,f),'utf8'),node=acorn.parse(s,{ecmaVersion:'latest'}).body.find(x=>x.id?.name===n);return s.slice(node.start,node.end);}
(async()=>{
 const c=vm.createContext({console,state:{char:{name:'FixtureLegacy'},country:'republic',arg:100,liquide:100,inventory:[]},COUNTRIES:{republic:{cur:'FR'}},sauvegardes:0,marques:0,updateUI(){},sbRecupererVolsEnAttente:async()=>[{id:'vol-fixture',type_butin:'argent',montant:25}],sbSavePersonnage:async()=>{c.sauvegardes++;return null;},sbMarquerVolTraite:async()=>{c.marques++;}});
 vm.runInContext(f('plateau-communication.js','recupererVolsEnAttente'),c);await c.recupererVolsEnAttente();
 const out={nature:'Diagnostic sur réponses fictives, aucun accès production',vols_en_attente:{condition:'Une ligne ancienne argent en attente est fournie par le lecteur de fixture',argent_avant:100,argent_apres:c.state.arg,liquide:c.state.liquide,sauvegarde_resultat:null,marques:c.marques}};
 const d=vm.createContext({console,state:{char:{name:'FixtureLegacy'},country:'republic',currentCity:'caserne',pa:100,inventory:[]},document:{getElementById:()=>null},PA_SUBTILISATION:2,updateUI(){},showToast(){},addJournalEntry(){},sbMilitaireSubtiliserTenter:async()=>({ok:true,contrat:1,pa:8,inventory:[],revision:1,reussite:false,raison:'stock_insuffisant'})});
 d.contexteGroupePj=()=>({nom:'FixtureLegacy',personnage:d.state.char});d.contexteGroupePjValide=x=>x.personnage===d.state.char;d.sbAdopterInventaireServeur=v=>{d.state.inventory=v.inventory;d.state._inventaireRevision=v.revision;return true;};d.appliquerPaiementServeur=v=>{d.state.pa=v.pa;};
 vm.runInContext('let RP_SUBTILISATION=null;'+f('plateau-actions-illegales-rumeurs.js','confirmerSubtilisationExplosif'),d);await d.confirmerSubtilisationExplosif();out.subtilisation={condition:'Réponse serveur versionnée de fixture, ancien affichage 100 PA ; PA officiels 8',pa_interface_apres:d.state.pa,pa_serveur_fixture:8};
 out.anomalies=[];if(out.vols_en_attente.marques&&out.vols_en_attente.sauvegarde_resultat===null)out.anomalies.push('vol_marque_apres_sauvegarde_null');if(out.subtilisation.pa_interface_apres!==out.subtilisation.pa_serveur_fixture)out.anomalies.push('miroir_PA_perime');
 console.log(JSON.stringify(out,null,2));process.exitCode=out.anomalies.length?2:0;
})().catch(e=>{console.error(e);process.exitCode=1;});
