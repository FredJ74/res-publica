const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function jeu(){
 const c=vm.createContext({console:{warn(){}},state:{char:{name:'Alice'},organisations:[{id:'connue',caisse:42}]},uid:'u',jeton:'t',document:{querySelector:()=>null}});
 c.rpAuthUid=()=>c.uid;c.rpAuthJeton=()=>c.jeton;
 vm.runInContext(fs.readFileSync(path.join(root,'supabase.js'),'utf8'),c);
 const s=fs.readFileSync(path.join(root,'plateau-organisations-quetes.js'),'utf8');
 vm.runInContext(s.slice(s.indexOf('// Charge toutes les organisations depuis Supabase'),s.indexOf('// Trouve le responsable de la loge')),c);
 return c;
}
test('panne et donnees malformees ne deviennent pas une liste vide',async()=>{
 for(const rows of [null,{},[{data:'{'}],[{data:'null'}],[{data:'[]'}]]){
  const c=jeu();c.sbGet=async()=>rows;await assert.rejects(c.sbLoadOrganisations());
  await c.chargerOrganisations();assert.equal(c.state.organisations[0].caisse,42);
 }
});
test('un vide reel est accepte',async()=>{const c=jeu();c.sbGet=async()=>[];await c.chargerOrganisations();assert.equal(c.state.organisations.length,0);});
test('les JSON texte et objet sont lus sans changer leurs champs',async()=>{
 const c=jeu();c.sbGet=async()=>[{data:'{"id":"a","caisse":0}'},{data:{id:'b',caisse:7}}];
 await c.chargerOrganisations();assert.equal(c.state.organisations[0].caisse,0);assert.equal(c.state.organisations[1].caisse,7);
});
for(const changement of ['personnage','compte','session'])test(`chargement tardif/${changement} ignore`,async()=>{
 const c=jeu();let resolve;c.sbLoadOrganisations=()=>new Promise(r=>resolve=r);const p=c.chargerOrganisations();
 if(changement==='personnage')c.state.char={name:'Bob'};if(changement==='compte')c.uid='autre';if(changement==='session')c.jeton='autre';
 resolve([]);await p;assert.equal(c.state.organisations[0].id,'connue');
});
test('une ancienne lecture ne remplace pas un chargement plus recent',async()=>{
 const c=jeu();let resolve;c.sbLoadOrganisations=()=>new Promise(r=>resolve=r);const p=c.chargerOrganisations();
 c.sbLoadOrganisations=async()=>[{id:'recente'}];await c.chargerOrganisations();resolve([]);await p;
 assert.equal(c.state.organisations[0].id,'recente');
});
