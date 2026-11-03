'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn'),R=path.resolve(__dirname,'../..');
const lire=f=>process.env.HG379_CONTRE?require('node:child_process').execFileSync('git',['show',process.env.HG379_CONTRE+':'+f],{cwd:R,encoding:'utf8'}):fs.readFileSync(path.join(R,f),'utf8');
function corps(f,nom){const s=lire(f),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.id?.name===nom);assert.ok(n,nom);return s.slice(n.start,n.end);}
// main #416 a supprimé la consommation locale des vols (branche morte) : plus aucun consommateur.
test('ancienne file des vols : aucun consommateur ni marqueur navigateur',()=>{
 assert.doesNotMatch(lire('plateau-communication.js'),/function recupererVolsEnAttente\b/);
 assert.doesNotMatch(lire('supabase.js'),/function sb(RecupererVolsEnAttente|MarquerVolTraite)\b/);
 assert.doesNotMatch(lire('plateau-core.js'),/recupererVolsEnAttente\(/);
});
function jeu(){
 const c=vm.createContext({state:{char:{name:'Fixture'},employes:[],arg:100,liquide:100},session:'S',COUNTRIES:{republic:{cur:'FR'}},MAX_EMPLOYES:10,console,toasts:[],appels:[],document:{getElementById:()=>({classList:{remove(){}}})},Math:Object.assign(Object.create(Math),{random:()=>assert.fail('aucun profil aléatoire local')})});
 c.contexteGroupePj=()=>({personnage:c.state.char,nom:c.state.char.name,session:c.session});c.contexteGroupePjValide=x=>x.personnage===c.state.char&&x.session===c.session;
 c.showToast=(...x)=>c.toasts.push(x);c.sbEmployeRecruter=async(...x)=>{c.appels.push(x);return c.verdict;};
 vm.runInContext('let RP_CODETENU_RECRUTEMENT=null;'+corps('plateau-multijoueur.js','confirmerRecrutementCodetenu'),c);return c;
}
for(const verdict of [null,{ok:false,raison:'metier_non_recrutable'},{ok:false,raison:'paiement_refuse'},{ok:true,pnj_id:'serveur'}])test('codétenu : commande existante, prix/profil jamais imposés '+JSON.stringify(verdict),async()=>{
 const c=jeu();c.verdict=verdict;const avant=JSON.stringify(c.state);await c.confirmerRecrutementCodetenu('NomFixture',-999);assert.equal(JSON.stringify(c.state),avant);assert.deepEqual(c.appels,[['codetenu','NomFixture',null,null,null,null]]);assert.equal(c.toasts[0][2],verdict?.ok===true);
});
test('codétenu : double clic et réponse tardive d’une autre session',async()=>{
 const c=jeu();let finir;c.sbEmployeRecruter=(...x)=>{c.appels.push(x);return new Promise(r=>finir=r);};
 const p=c.confirmerRecrutementCodetenu('NomFixture',100);await c.confirmerRecrutementCodetenu('NomFixture',0);assert.equal(c.appels.length,1);c.session='autre';finir({ok:true});await p;assert.equal(c.toasts.length,0);assert.deepEqual(c.state.employes,[]);
});
test('catalogue canonique : codétenu reste non actif, aucune identité du décor transformée',()=>{
 const seed=fs.readFileSync(path.join(R,'baseline/seeds/90_socle/pnj_metiers_profils.sql'),'utf8');assert.match(seed,/'codetenu'.*'false'/);
 const source=fs.readFileSync(path.join(R,'data.js'),'utf8');assert.doesNotMatch(source,/job:\s*['"]codetenu['"]/);
 const f=fs.readFileSync(path.join(R,'baseline/domaines/personnage-et-presence/20_fonctions-1.sql'),'utf8');assert.match(f,/FUNCTION public.employe_recruter\(/);assert.match(f,/p_metier = ANY \(public.employe_metiers_recrutables\(\)\)/);
});
