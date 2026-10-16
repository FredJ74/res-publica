// node --test outils/bancs/banc-coherence-sauvegarde.cjs
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.resolve(__dirname,'../../supabase.js'),'utf8');
function contexte(){
 const state={char:{name:'Alice'},country:'republic',arg:0,liquide:0,hp:0,moral:0,pa:0,dis:0,pop:0,inf:0,
  inventory:[{name:'Pain',qty:1}],personnageChargeDepuisServeur:true,_dernierUpdatedAtConnu:'2026-10-16T01:00:00Z'};
 const ctx=vm.createContext({console,state,setTimeout,clearTimeout,localStorage:{getItem:()=>null}});
 vm.runInContext(source,ctx);return ctx;
}
test('sauvegarde normale et dechargement conservent sante, moral, PA et discipline a zero',()=>{
 const c=contexte();let body;c.fetch=async(url,opts)=>{body=JSON.parse(opts.body);};
 const normal=c.sbPayloadPersonnage(c.state);c.sbSauvegardeUrgenceDechargement();
 for(const p of [normal,body])for(const k of ['arg','liquide','hp','moral','pa'])assert.equal(p[k],0,k);
 assert.equal(body.resources.dis,0);
});
test('les valeurs initiales ne servent que pour les champs absents',()=>{
 const c=contexte();delete c.state.hp;delete c.state.moral;
 const p=c.sbPayloadPersonnage(c.state);assert.equal(p.hp,100);assert.equal(p.moral,75);
});
test('une sauvegarde en file capture aussi les donnees imbriquees avant tout await',async()=>{
 const c=contexte();const envoyes=[];c.sbEcrirePersonnage=async data=>{envoyes.push(JSON.parse(JSON.stringify(data)));return [{}];};
 const p=c.sbSavePersonnage(c.state);c.state.inventory[0].qty=2;c.state.inventory.push({name:'Autre'});await p;
 assert.deepEqual(envoyes[0].inventory,[{name:'Pain',qty:1}]);
});
test('un onglet perime ne peut pas ecraser les autres au deuxieme tick',async()=>{
 const c=contexte();let n=0;c.sbGet=async()=>[{updated_at:'2026-10-16T02:00:00Z'}];
 c.sbSavePersonnage=async()=>{n++;};
 await c.sbVerifierEtSauvegarderPersonnage(c.state);await c.sbVerifierEtSauvegarderPersonnage(c.state);
 assert.equal(n,0);assert.equal(c.state._dernierUpdatedAtConnu,'2026-10-16T01:00:00Z');
});
test('lecture refusee, vide, sans date, ou repere inconnu : aucun autosave aveugle',async()=>{
 for(const lire of [async()=>null,async()=>[],async()=>[{}],async()=>{throw Error('reseau');}]){
  const c=contexte();c.sbGet=lire;c.sbSavePersonnage=async()=>assert.fail('Aucune ecriture autorisee');
  await c.sbVerifierEtSauvegarderPersonnage(c.state);
 }
 const c=contexte();delete c.state._dernierUpdatedAtConnu;c.sbGet=async()=>[{updated_at:'date'}];
 c.sbSavePersonnage=async()=>assert.fail('Aucun etat initial connu');await c.sbVerifierEtSauvegarderPersonnage(c.state);
});
test('un repere concordant permet toujours la sauvegarde periodique',async()=>{
 const c=contexte();c.sbGet=async()=>[{updated_at:c.state._dernierUpdatedAtConnu}];let n=0;
 c.sbSavePersonnage=async()=>{n++;};await c.sbVerifierEtSauvegarderPersonnage(c.state);assert.equal(n,1);
});
test('une lecture tardive ne sauvegarde pas un nouveau personnage',async()=>{
 const c=contexte();let resolve;c.sbGet=()=>new Promise(r=>resolve=r);
 c.sbSavePersonnage=async()=>assert.fail('Personnage change');
 const p=c.sbVerifierEtSauvegarderPersonnage(c.state);c.state.char={name:'Bob'};
 resolve([{updated_at:'2026-10-16T01:00:00Z'}]);await p;
});
test('le repere de sauvegarde vient de la reponse serveur, pas de la date du navigateur',async()=>{
 const c=contexte();c.sbEcrirePersonnage=async()=>[{updated_at:'2026-10-16T03:00:00Z'}];
 await c.sbSavePersonnage(c.state);assert.equal(c.state._dernierUpdatedAtConnu,'2026-10-16T03:00:00Z');
});
test('une sauvegarde mise en file ne part pas sous un nouveau personnage',async()=>{
 const c=contexte();c.sbEcrirePersonnage=async()=>assert.fail('Ecriture obsolete');
 const p=c.sbSavePersonnage(c.state);c.state.char={name:'Bob'};await p;
 assert.equal(c.state._dernierUpdatedAtConnu,'2026-10-16T01:00:00Z');
});
test('une confirmation tardive ne pose pas le repere sur un autre personnage',async()=>{
 const c=contexte();let resolve;c.sbEcrirePersonnage=()=>new Promise(r=>resolve=r);
 const p=c.sbSavePersonnage(c.state);await new Promise(r=>setImmediate(r));
 c.state.char={name:'Bob'};resolve([{updated_at:'2026-10-16T03:00:00Z'}]);await p;
 assert.equal(c.state._dernierUpdatedAtConnu,'2026-10-16T01:00:00Z');
});
test('la sauvegarde de fermeture est conditionnee au dernier etat connu',()=>{
 const c=contexte();let url;c.fetch=async u=>{url=u;};c.sbSauvegardeUrgenceDechargement();
 assert.equal(new URL(url).searchParams.get('updated_at'),'eq.2026-10-16T01:00:00Z');
});
test('la fermeture sans repere serveur n’envoie aucun etat aveugle',()=>{
 const c=contexte();delete c.state._dernierUpdatedAtConnu;c.fetch=()=>assert.fail('Aucun PATCH attendu');
 c.sbSauvegardeUrgenceDechargement();
});
test('la lecture Supabase conserve aussi les ressources nulles avant hydratation',async()=>{
 const c=contexte();c.sbGet=async()=>[{name:'Alice',country:'republic',resources:{inf:0,pop:0,dis:0},arg:0,hp:0,moral:0,pa:0}];
 const r=await c.sbLoadPersonnage('Alice');
 for(const k of ['inf','pop','dis','arg','hp','moral','pa'])assert.equal(r[k],0,k);
});
test('deconnexion puis reconnexion du meme compte : une ancienne sauvegarde en file est annulee',async()=>{
 const c=contexte();let jeton='ancien';c.rpAuthUid=()=> 'meme-compte';c.rpAuthJeton=()=>jeton;
 c.sbEcrirePersonnage=async()=>assert.fail('Ancienne session');
 const p=c.sbSavePersonnage(c.state);jeton='nouvelle-session';await p;
});
test('rehydratation du meme nom : un ancien snapshot en file ne repart pas',async()=>{
 const c=contexte();let n=0;c.sbEcrirePersonnage=async()=>{n++;return [{}];};
 const p=c.sbSavePersonnage(c.state);c.state.char={name:'Alice',arg:900};await p;assert.equal(n,0);
});
test('rehydratation du meme nom : une ancienne confirmation ne certifie pas la nouvelle fiche',async()=>{
 const c=contexte();let resolve;c.sbEcrirePersonnage=()=>new Promise(r=>resolve=r);
 const p=c.sbSavePersonnage(c.state);await new Promise(r=>setImmediate(r));c.state.char={name:'Alice',arg:900};
 resolve([{updated_at:'2026-10-16T09:00:00Z'}]);await p;
 assert.equal(c.state._dernierUpdatedAtConnu,'2026-10-16T01:00:00Z');
});
