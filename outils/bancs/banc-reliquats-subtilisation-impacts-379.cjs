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
 vm.runInContext('let RP_SUBTILISATION=null,RP_IMPACTS_RECEPTION=null;'+fonctions('plateau-communication.js',['recupererImpactsEnAttente']),c);
 return c;
}
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
 const c=impacts();let finir,n=0;c.sbRecupererImpactsEnAttente=()=>{n++;return new Promise(r=>finir=r);};const p=c.recupererImpactsEnAttente(),deux=c.recupererImpactsEnAttente();assert.equal(n,1);await deux;finir([{id:'i'}]);await p;assert.equal(c.marques.length,1);
});
test('le helper d’impact demande le contrat avant tout acte : aucun repli sur une surcharge historique',async()=>{
 const c=vm.createContext({appels:[]});c.sbRpc=async(...x)=>{c.appels.push(x);return null;};vm.runInContext(fonctions('supabase.js',['sbMarquerImpactTraite']),c);
 await c.sbMarquerImpactTraite('i');assert.equal(c.appels.length,1);assert.equal(c.appels[0][1].p_contrat,1);
});
