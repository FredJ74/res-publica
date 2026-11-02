'use strict';
// Contrat réel de provenance/version, réponses fictives : aucun accès Supabase.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn'),root=path.resolve(__dirname,'../..');
function jeu(){
 const c=vm.createContext({console,session:'session-A',state:{char:{name:'FixtureServices'},inventory:[{id:'ancien'}],_inventaireVersionne:true,_inventaireRevision:7},rendus:0,appels:[]});
 c.rpAuthUid=()=> 'uid-fixture';c.rpAuthSessionIdentifiant=()=>c.session;
 vm.runInContext(fs.readFileSync(path.join(root,'supabase.js'),'utf8'),c);
 const source=process.env.HG135_CONTRE_INVENTAIRE?require('node:child_process').execFileSync('git',['show',process.env.HG135_CONTRE_INVENTAIRE+':plateau-justice-economie.js'],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,'plateau-justice-economie.js'),'utf8');
 const n=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.id?.name==='rafraichirInventaireDepuisServeur');assert.ok(n);vm.runInContext(source.slice(n.start,n.end),c);
 c.renderInventory=()=>c.rendus++;
 c.reponse={ok:true,inventory:[{id:'document-greffe',contenu:{fige:true}}],revision:8};
 c.sbRpc=(fn,p)=>{c.appels.push({fn,p});const origine=c.sbContexteInventaire();return new Promise(resolve=>{c.finir=()=>resolve(c.sbMarquerInventaires(c.reponse,origine));});};
 // Le vieux GET porte sa vraie provenance mais omet la révision : il l'efface.
 c.sbGet=async()=>c.sbMarquerInventaires([{inventory:c.reponse.inventory}],c.sbContexteInventaire());
 return c;
}
test('greffe et services : inventaire et révision adoptés ensemble, objet original conservé',async()=>{
 const c=jeu(),p=c.rafraichirInventaireDepuisServeur();c.finir?.();assert.equal(await p,true);
 assert.equal(c.state._inventaireRevision,8);assert.equal(c.state.inventory,c.reponse.inventory);assert.equal(c.rendus,1);
 assert.equal(c.appels[0].fn,'inventaire_reception_etat');assert.equal(c.appels[0].p.p_acteur,'FixtureServices');
});
for(const reponse of [null,{ok:false},{ok:true,inventory:[]},{ok:true,revision:8},{ok:true,inventory:[],revision:8.5}])test('lecture incomplète refusée : '+JSON.stringify(reponse),async()=>{
 const c=jeu(),avant=c.state.inventory;c.reponse=reponse;const p=c.rafraichirInventaireDepuisServeur();c.finir?.();assert.equal(await p,false);assert.equal(c.state.inventory,avant);assert.equal(c.state._inventaireRevision,7);assert.equal(c.rendus,0);
});
for(const changement of ['personnage','session','generation'])test('réponse tardive / '+changement,async()=>{
 const c=jeu(),p=c.rafraichirInventaireDepuisServeur();
 if(changement==='personnage')c.state.char={name:'AutreFixture'};
 if(changement==='session')c.session='autre-session';
 if(changement==='generation')c.state._inventaireGeneration=1;
 c.finir?.();assert.equal(await p,false);assert.equal(c.state._inventaireRevision,7);assert.equal(c.rendus,0);
});
test('lecteur canonique absent : aucun repli vers un GET sans révision',async()=>{
 const c=jeu();c.sbInventaireReceptionEtat=undefined;c.sbGet=()=>assert.fail('GET historique interdit');assert.equal(await c.rafraichirInventaireDepuisServeur(),false);
});
