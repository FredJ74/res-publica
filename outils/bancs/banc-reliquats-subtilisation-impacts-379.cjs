'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const acorn=require('../vercel/node_modules/acorn'),R=path.resolve(__dirname,'../..');
function fonctions(f,noms){const s=process.env.HG379_CONTRE?require('node:child_process').execFileSync('git',['show',process.env.HG379_CONTRE+':'+f],{cwd:R,encoding:'utf8'}):fs.readFileSync(path.join(R,f),'utf8'),ast=acorn.parse(s,{ecmaVersion:'latest'});return noms.map(n=>{const x=ast.body.find(x=>x.id?.name===n);assert.ok(x,n);return s.slice(x.start,x.end);}).join('\n');}
function jeu(){
 const c=vm.createContext({console,session:'S',uid:'U',state:{char:{name:'Fixture'},country:'republic',currentCity:'caserne',pa:100,hp:100,moral:100,pop:100,inf:100,dis:100,inventory:[],_inventaireRevision:3},toasts:[],journal:[],adoptions:[],document:{getElementById:()=>({classList:{remove(){}}})},PA_SUBTILISATION:2,JOURS_QHS_SUBTILISATION:3,CASERNE_CITY:'caserne'});
 c.rpAuthUid=()=>c.uid;c.rpAuthSessionIdentifiant=()=>c.session;
 vm.runInContext(fonctions('plateau-multijoueur.js',['contexteGroupePj','contexteGroupePjValide']),c);
 c.showToast=(...x)=>c.toasts.push(x);c.addJournalEntry=(...x)=>c.journal.push(x);c.updateUI=()=>{};c.renderInventory=()=>{};
 c.appliquerPaiementServeur=v=>{assert.equal(v,c.verdict,'réponse originale');c.state.pa=v.pa;};
 c.sbAdopterInventaireServeur=v=>{c.adoptions.push(v);if(c.refusAdoption)return false;c.state.inventory=v.inventory;c.state._inventaireRevision=v.revision;return true;};
 c.sbSavePersonnage=()=>assert.fail('aucune sauvegarde générale');c.sauvegarderPersonnageImmediat=c.sbSavePersonnage;
 c.sbGet=()=>assert.fail('aucun GET partiel sans révision');c.placerAuQHS=async()=>{c.qhs=(c.qhs||0)+1;return true;};
 c.sbFicheBaseAdopter=v=>c.base=v;c.adopterJaugeServeur=(k,v)=>{c.state[k]=v;};
 vm.runInContext('let RP_SUBTILISATION=null,RP_IMPACTS_RECEPTION=null;'+fonctions('plateau-actions-illegales-rumeurs.js',['confirmerSubtilisationExplosif'])+fonctions('plateau-communication.js',['recupererImpactsEnAttente']),c);
 return c;
}
for(const issue of ['succes','echec','detecte','stock'])test('subtilisation '+issue+' : PA officiels, inventaire et révision originaux',async()=>{
 const c=jeu();c.verdict={ok:true,contrat:1,pa:8,inventory:[{id:'officiel'}],revision:4,reussite:issue==='succes',detecte:issue==='detecte',raison:issue==='stock'?'stock_insuffisant':null};
 c.sbMilitaireSubtiliserTenter=async()=>c.verdict;await c.confirmerSubtilisationExplosif();assert.equal(c.state.pa,8);assert.equal(c.adoptions[0],c.verdict);assert.equal(c.state._inventaireRevision,4);assert.equal(c.qhs||0,issue==='detecte'?1:0);
});
for(const v of [null,{ok:false},{ok:true},{ok:true,contrat:1,pa:8,inventory:[]}])test('subtilisation : réponse absente/incomplète ne recalcule aucun PA '+JSON.stringify(v),async()=>{
 const c=jeu();c.verdict=v;c.sbMilitaireSubtiliserTenter=async()=>v;await c.confirmerSubtilisationExplosif();assert.equal(c.state.pa,100);assert.equal(c.adoptions.length,0);assert.ok(c.toasts.every(x=>x[2]===false));
});
for(const changement of ['personnage','uid','session'])test('subtilisation : double clic et réponse tardive / '+changement,async()=>{
 const c=jeu();let finir,n=0;c.sbMilitaireSubtiliserTenter=()=>{n++;return new Promise(r=>finir=r);};const p=c.confirmerSubtilisationExplosif();await c.confirmerSubtilisationExplosif();assert.equal(n,1);
 if(changement==='personnage')c.state.char={name:'Autre'};if(changement==='uid')c.uid='autre';if(changement==='session')c.session='autre';
 finir({ok:true,contrat:1,pa:8,inventory:[],revision:4});await p;assert.equal(c.state.pa,100);assert.equal(c.adoptions.length,0);assert.equal(c.toasts.length,0);
});
test('subtilisation : provenance rejetée, aucun autre miroir appliqué',async()=>{
 const c=jeu();c.refusAdoption=true;c.verdict={ok:true,contrat:1,pa:8,inventory:[],revision:4};c.sbMilitaireSubtiliserTenter=async()=>c.verdict;await c.confirmerSubtilisationExplosif();assert.equal(c.state.pa,100);assert.ok(c.toasts.every(x=>!x[2]));
});
test('subtilisation : réponse perdue, état relu sans seconde tentative',async()=>{
 const c=jeu();let demandes=0;c.sbMilitaireSubtiliserTenter=async()=>{demandes++;return null;};
 const inventaire={ok:true,inventory:[{id:'deja-depose'}],revision:9};
 c.sbLoadPersonnage=async()=>({userId:'U',pa:8});c.sbInventaireReceptionEtat=async()=>inventaire;
 c.appliquerPaiementServeur=v=>{c.state.pa=v.pa;};await c.confirmerSubtilisationExplosif();
 assert.equal(demandes,1);assert.equal(c.state.pa,8);assert.equal(c.adoptions[0],inventaire);assert.equal(c.state._inventaireRevision,9);assert.ok(c.toasts.every(t=>!t[2]));
});
test('subtilisation : un refus versionné actualise les PA sans dépense locale',async()=>{
 const c=jeu();c.verdict={ok:false,raison:'pa_insuffisants',contrat:1,pa:1,inventory:[],revision:3};c.sbMilitaireSubtiliserTenter=async()=>c.verdict;await c.confirmerSubtilisationExplosif();assert.equal(c.state.pa,1);assert.ok(c.toasts.every(t=>!t[2]));
});
function impacts(){const c=jeu();c.marques=[];c.lectures=0;c.sbRecupererImpactsEnAttente=async()=>[{id:'i',indice:'hp_set',delta:999}];c.reponse={ok:true,contrat:1,marques:1,applique:true,indice:'hp_set'};
 c.sbMarquerImpactTraite=async id=>{c.marques.push(id);return c.reponse;};c.frais={userId:'U',pa:0,hp:0,moral:0,dis:0,pop:0,inf:0,statsAffaiblies:{ENT:true},empoisonnement:null,hospitalisation:{regime:'pa0'}};
 c.sbLoadPersonnage=async()=>{c.lectures++;return c.frais;};return c;}
for(const type of ['pop','inf','dis','moral_carte_postale','hp_set','poison_start'])test('impact '+type+' : seul l’état serveur relu est adopté, zéro conservé',async()=>{
 const c=impacts();c.reponse.indice=type;assert.equal(await c.recupererImpactsEnAttente(),true);assert.equal(c.lectures,1);
 for(const k of ['pa','hp','moral','pop','inf','dis'])assert.equal(c.state[k],0,k);assert.deepEqual(c.marques,['i']);assert.equal(c.state.statsAffaiblies,c.frais.statsAffaiblies);assert.equal(c.base.hp,0);
});
test('impact : réponse perdue après effet, relecture sans appliquer une seconde fois',async()=>{
 const c=impacts();c.reponse=null;assert.equal(await c.recupererImpactsEnAttente(),false);assert.equal(c.state.hp,0);assert.equal(c.lectures,1);assert.equal(c.journal.length,0);
});
for(const r of [{ok:false,raison:'indice_non_pris_en_charge'},{ok:true,marques:1},{ok:false,raison:'client_obsolete'}])test('impact : refus ou ancien contrat ne permet aucun effet local '+JSON.stringify(r),async()=>{
 const c=impacts(),avant=JSON.stringify(c.state);c.reponse=r;assert.equal(await c.recupererImpactsEnAttente(),false);assert.equal(JSON.stringify(c.state),avant);assert.equal(c.lectures,0);
});
for(const changement of ['personnage','uid','session'])test('impact : réponse tardive / '+changement,async()=>{
 const c=impacts();let finir;c.sbMarquerImpactTraite=()=>new Promise(r=>finir=r);const p=c.recupererImpactsEnAttente();await new Promise(r=>setImmediate(r));
 if(changement==='personnage')c.state.char={name:'Autre'};if(changement==='uid')c.uid='autre';if(changement==='session')c.session='autre';finir(c.reponse);await p;assert.equal(c.state.hp,100);assert.equal(c.lectures,0);
});
test('impact : plafond quotidien déjà atteint, aucune annonce de gain',async()=>{
 const c=impacts();c.reponse.applique=false;c.reponse.indice='moral_carte_postale';await c.recupererImpactsEnAttente();assert.equal(c.journal.length,0);assert.equal(c.toasts.length,0);
});
test('impact : échec de relecture ou mauvais propriétaire, aucune projection inventée',async()=>{
 for(const frais of [null,{userId:'Autre',hp:25}]){const c=impacts();c.frais=frais;const avant=JSON.stringify(c.state);assert.equal(await c.recupererImpactsEnAttente(),false);assert.equal(JSON.stringify(c.state),avant);assert.equal(c.toasts.length,0);}
});
test('impact : double clic ne crée pas deux consommations',async()=>{
 const c=impacts();let finir,n=0;c.sbRecupererImpactsEnAttente=()=>{n++;return new Promise(r=>finir=r);};const p=c.recupererImpactsEnAttente();await c.recupererImpactsEnAttente();assert.equal(n,1);finir([{id:'i'}]);await p;assert.equal(c.marques.length,1);
});
test('les helpers demandent le contrat avant tout acte : aucun repli sur une surcharge historique',async()=>{
 const c=vm.createContext({appels:[]});c.sbRpc=async(...x)=>{c.appels.push(x);return null;};vm.runInContext(fonctions('supabase.js',['sbMilitaireSubtiliserTenter','sbMarquerImpactTraite']),c);
 await c.sbMilitaireSubtiliserTenter('republic');await c.sbMarquerImpactTraite('i');assert.equal(c.appels.length,2);assert.equal(c.appels[0][1].p_contrat,1);assert.equal(c.appels[1][1].p_contrat,1);
});
