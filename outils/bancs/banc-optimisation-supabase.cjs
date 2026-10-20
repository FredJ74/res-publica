// Transports locaux uniquement : aucun compte, aucune requete distante.
const {test}=require('node:test');
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const {createHash}=require('node:crypto');
const acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
const lire=f=>fs.readFileSync(path.join(root,f),'utf8');
function extraire(texte,noms){
 const trouves=[];
 function visiter(n){if(!n||typeof n!=='object')return;if(n.type==='FunctionDeclaration'&&noms.includes(n.id.name))trouves.push(texte.slice(n.start,n.end));for(const v of Object.values(n))if(Array.isArray(v))v.forEach(visiter);else if(v&&typeof v==='object')visiter(v);}
 visiter(acorn.parse(texte,{ecmaVersion:'latest'}));assert.equal(trouves.length,noms.length);return trouves.join('\n');
}
const multi=['contexteCachePhotosJoueurs','rafraichirCachePhotosJoueurs','rafraichirTitulairesPostesElectifs'];
function contexte(options={}){
 const temps={now:0},identite={uid:'fixture-compte',session:'fixture-session'},appels=[];
 const c=vm.createContext({window:{_cachePhotosJoueurs:{},_cachePhotosJoueursTimestamp:0},state:{char:{name:'Fixture'},country:'republic'},console:{warn(){},error(){}},
 Date:class extends Date{static now(){return temps.now;}},setTimeout,clearTimeout,rpAuthUid:()=>identite.uid,rpAuthSessionIdentifiant:()=>identite.session,
 rpAuthJeton:()=>identite.session,document:{hidden:false},fetch:async(url,init)=>{appels.push({url,init});return {ok:true,status:200,json:async()=>[]};}});
 vm.runInContext(options.sb||lire('supabase.js'),c);
 const texte=options.multi||lire('plateau-multijoueur.js');
 vm.runInContext(extraire(texte,options.multi?multi.slice(1):multi),c);
 return {c,temps,identite,appels};
}
const flush=()=>new Promise(r=>setImmediate(r));
function differer(){let resolve;const p=new Promise(r=>resolve=r);return {p,resolve};}
const normal=v=>JSON.parse(JSON.stringify(v));

test('invitations : un GET simultane, circuits diner/tournee distincts et nouvelle lecture fraiche',async()=>{
 const {c,appels}=contexte();let statut='attente';
 c.fetch=async(url,init)=>{appels.push({url,init});return {ok:true,status:200,json:async()=>[
  {id:1,tournee_id:null,statut:'attente'}, {id:2,tournee_id:'tournee',statut},
  {id:3,tournee_id:'tournee',statut:'acceptee'}, {id:4,tournee_id:null,statut:'acceptee'},
  {id:5,tournee_id:'tournee',statut:'refusee'}]};};
 const [diners,tournees]=await Promise.all([c.sbGetInvitationsDinerRecues('Fixture'),c.sbGetInvitationsTourneeRecues('Fixture')]);
 assert.equal(appels.length,1);assert.deepEqual(normal(diners).map(x=>x.id),[1]);assert.deepEqual(normal(tournees).map(x=>x.id),[2,3]);
 const q=new URL(appels[0].url).searchParams;assert.equal(q.get('invite'),'eq.Fixture');
 assert.equal(q.get('or'),'(statut.eq.attente,and(tournee_id.not.is.null,statut.eq.acceptee))');
 statut='refusee';assert.deepEqual(normal(await c.sbGetInvitationsTourneeRecues('Fixture')).map(x=>x.id),[3]);assert.equal(appels.length,2);
});
test('invitations : aucun partage entre comptes ni masque des erreurs HTTP/reseau',async()=>{
 const {c,identite,appels}=contexte();const a=c.sbGetInvitationsDinerRecues('A');identite.session='autre';const b=c.sbGetInvitationsTourneeRecues('B');await Promise.all([a,b]);assert.equal(appels.length,2);
 c.fetch=async()=>({ok:false,status:500,text:async()=>'{"message":"indisponible"}'});assert.equal(await c.sbGetInvitationsTourneeRecues('B'),null);
 c.fetch=async()=>{throw Error('reseau');};await assert.rejects(c.sbGetInvitationsDinerRecues('A'),/reseau/);
});

test('titres : projection sans photo, annuaire complet preserve pour ses autres usages',async()=>{
 const {c,appels}=contexte();await c.rafraichirTitulairesPostesElectifs();await c.sbListPersonnages();
 assert.equal(new URL(appels[0].url).searchParams.get('select'),'name,poste');
 assert.equal(new URL(appels[0].url).searchParams.get('poste'),'not.is.null');
 assert.match(new URL(appels[1].url).searchParams.get('select'),/photo_url/);
});
test('titres : titulaires PJ et postes encodes en JSON restent visibles',async()=>{
 const {c}=contexte();c.sbListTitulairesPostes=async()=>[{name:'A',poste:{id:'maire',city:'capitale'}},{name:'B',poste:'{"id":"president"}'}];
 await c.rafraichirTitulairesPostesElectifs();assert.deepEqual(normal(c.window._titulairesPostes),{maire_capitale:'A',president:'B'});
});
test('photos : filtre encode les noms sans injection et ne lit pas une piece vide',async()=>{
 const {c,appels}=contexte();await c.sbListPhotosJoueurs([]);assert.equal(appels.length,0);
 const nom='Nom, "special" \\ suite';await c.sbListPhotosJoueurs([nom,nom]);const q=new URL(appels[0].url).searchParams;
 assert.equal(q.get('select'),'name,photo_url');assert.deepEqual(JSON.parse('['+q.get('name').slice(4,-1)+']'),[nom]);
});
test('photos : lots de 100 noms, sans troncature ni traitement de panne comme vide',async()=>{
 const {c,appels}=contexte();assert.deepEqual(normal(await c.sbListPhotosJoueurs(Array.from({length:205},(_,i)=>'P'+i))),[]);assert.equal(appels.length,3);
 c.sbGet=async()=>null;assert.equal(await c.sbListPhotosJoueurs(['A']),null);
});
test('cache vide ou personnages sans photo : succes memorise pendant 60 secondes',async()=>{
 const {c,temps}=contexte();let n=0;c.sbListPhotosJoueurs=async()=>{n++;return [];};
 await c.rafraichirCachePhotosJoueurs();temps.now=59999;await c.rafraichirCachePhotosJoueurs();assert.equal(n,1);
 temps.now=60000;await c.rafraichirCachePhotosJoueurs();assert.equal(n,2);
});
test('contre-epreuve : les cinq lectures successives du cache vide historique deviennent une',async()=>{
 const fixture=JSON.parse(lire('outils/bancs/fixtures/optimisation-supabase-avant.json')),comptes=[];
 for(const ancien of [true,false]){
  const {c}=contexte(ancien?{multi:fixture.fonctions}:{});let n=0;const lire=async()=>{n++;return [];};
  c.sbListPersonnages=lire;c.sbListPhotosJoueurs=lire;
  for(let i=0;i<5;i++)await c.rafraichirCachePhotosJoueurs();comptes.push(n);
 }
 assert.deepEqual(comptes,[5,1]);
});
test('lectures photos simultanees : une lecture, puis seulement les noms encore manquants',async()=>{
 const {c}=contexte(),d=differer(),appels=[];c.sbListPhotosJoueurs=async noms=>{appels.push(normal(noms));return appels.length===1?d.p:[];};
 const a=c.rafraichirCachePhotosJoueurs(['A']),b=c.rafraichirCachePhotosJoueurs(['A']),e=c.rafraichirCachePhotosJoueurs(['A','B']);await flush();assert.equal(appels.length,1);
 d.resolve([{name:'A',photo_url:'portrait-A'}]);await Promise.all([a,b,e]);assert.deepEqual(appels,[['A'],['B']]);assert.equal(c.window._cachePhotosJoueurs.A,'portrait-A');
});
test('presence : seuls les autres PJ sont demandes ; forum peut encore charger toutes les photos',async()=>{
 const {c}=contexte(),appels=[];c.sbListPhotosJoueurs=async noms=>{appels.push(noms&&normal(noms));return [{name:'A',photo_url:'portrait-A'}];};
 await c.rafraichirCachePhotosJoueurs(['A']);await c.rafraichirCachePhotosJoueurs();assert.deepEqual(appels,[['A'],undefined]);
 const code=extraire(lire('plateau-multijoueur.js'),['chargerVraisJoueursPresents']);assert.match(code,/rafraichirCachePhotosJoueurs\(autres\.map\(p => p\.name\)\)/);
});
test('photos supprimees, ajoutees ou modifiees : relues a expiration',async()=>{
 const {c,temps}=contexte();c.sbListPhotosJoueurs=async()=>[{name:'A',photo_url:'ancienne'}];await c.rafraichirCachePhotosJoueurs(['A']);
 temps.now=60000;c.sbListPhotosJoueurs=async()=>[{name:'A',photo_url:null}];await c.rafraichirCachePhotosJoueurs(['A']);assert.equal(c.window._cachePhotosJoueurs.A,undefined);
 temps.now=120000;c.sbListPhotosJoueurs=async()=>[{name:'A',photo_url:'nouvelle'}];await c.rafraichirCachePhotosJoueurs(['A']);assert.equal(c.window._cachePhotosJoueurs.A,'nouvelle');
});
test('photos tardives : aucun rendu de presence apres changement de piece, pays, personnage ou session',async()=>{
 for(const changement of ['piece','pays','personnage','session']){
  const {c,identite}=contexte(),d=differer();c.state.currentCity='capitale';c.state.currentBuilding='mairie';c.state.currentRoom='accueil';
  c.rafraichirStatutsJudiciaires=async()=>{};c.sbGetPresencesInRoom=async()=>[{name:'Autre'}];c.rafraichirCachePhotosJoueurs=()=>d.p;
  c.document.getElementById=()=>assert.fail('aucun rendu tardif');
  vm.runInContext(extraire(lire('plateau-multijoueur.js'),['chargerVraisJoueursPresents']),c);
  const p=c.chargerVraisJoueursPresents();await flush();
  if(changement==='piece')c.state.currentRoom='bureau';else if(changement==='pays')c.state.country='autre';else if(changement==='personnage')c.state.char={name:'Autre'};else identite.session='autre';
  d.resolve({Autre:'portrait'});await p;assert.equal(c.window._vraisJoueursPresents,undefined);
 }
});
test('panne de photos : ancien cache conserve, aucune fausse fraicheur, pas de rafale des attenteurs',async()=>{
 const {c,temps}=contexte();c.sbListPhotosJoueurs=async()=>[{name:'A',photo_url:'ancienne'}];await c.rafraichirCachePhotosJoueurs();temps.now=60000;
 const d=differer();let n=0;c.sbListPhotosJoueurs=async()=>{n++;return d.p;};const ps=Array.from({length:8},()=>c.rafraichirCachePhotosJoueurs());await flush();d.resolve(null);await Promise.all(ps);
 assert.equal(n,1);assert.equal(c.window._cachePhotosJoueurs.A,'ancienne');assert.equal(c.window._cachePhotosJoueursTimestamp,0);
 c.sbListPhotosJoueurs=async()=>{n++;return [];};await c.rafraichirCachePhotosJoueurs();assert.equal(n,2);
});
test('changement de compte ou de session : cache purge, retour tardif ancien ignore',async()=>{
 for(const champ of ['uid','session']){
  const {c,identite}=contexte(),d=differer();c.sbListPhotosJoueurs=()=>d.p;const ancien=c.rafraichirCachePhotosJoueurs();await flush();
  identite[champ]='autre';c.sbListPhotosJoueurs=async()=>[{name:'B',photo_url:'nouveau'}];await c.rafraichirCachePhotosJoueurs();d.resolve([{name:'A',photo_url:'ancien'}]);
  assert.deepEqual(normal(await ancien),{});assert.deepEqual(normal(c.window._cachePhotosJoueurs),{B:'nouveau'});
 }
});
test('sauvegarde : corps financier/inventaire intact ; reponse limitee aux metadonnees utiles',async()=>{
 const {c,appels}=contexte();const data={name:'Fixture',arg:0,liquide:0,inventory:[{name:'objet'}],updated_at:'2026-10-20T12:00:00Z'};
 c.fetch=async(url,init)=>{appels.push({url,init});return {ok:true,status:200,json:async()=>[{name:data.name,updated_at:data.updated_at}]};};
 const r=await c.sbEcrirePersonnage(data);assert.equal(new URL(appels[0].url).searchParams.get('select'),'name,updated_at');assert.deepEqual(JSON.parse(appels[0].init.body),data);assert.equal(r[0].updated_at,data.updated_at);
 c.fetch=async()=>({ok:true,status:200,json:async()=>[]});assert.equal(await c.sbEcrirePersonnage(data),null);
});
test('presence : corps et journal de deplacement conserves, pas de renvoi des portraits PNJ',async()=>{
 const {c,appels}=contexte(),rpc=[];c.sbRpc=async(...a)=>{rpc.push(normal(a));};
 await c.sbUpdatePresence('Fixture','republic','capitale','mairie','accueil',[{nom:'Employe',photoUrl:'portrait'}]);
 assert.equal(new URL(appels[0].url).searchParams.get('select'),'name');const body=JSON.parse(appels[0].init.body);
 assert.equal(body.groupe_pnj[0].photoUrl,'portrait');assert.equal(body.room_id,'accueil');assert.equal(rpc[0][0],'deplacement_enregistrer');
});
function lanceur(){const {c}=contexte();vm.runInContext('const lecturesFondEnCours=new Set();'+extraire(lire('plateau-core.js'),['lancerLectureFond']),c);return c;}
test('garde commune : pas de chevauchement, liberation apres erreur, cadences masquees preservees',async()=>{
 const c=lanceur(),d=differer();let n=0;const fn=()=>{n++;return d.p;};const a=c.lancerLectureFond('dons',fn,true);c.lancerLectureFond('dons',fn,true);await flush();assert.equal(n,1);d.resolve();await a;
 await c.lancerLectureFond('dons',()=>{throw Error('panne');},true);await c.lancerLectureFond('dons',()=>{n++;},true);assert.equal(n,2);
 c.document.hidden=true;await c.lancerLectureFond('mails',()=>{n++;});assert.equal(n,2);await c.lancerLectureFond('dons',()=>{n++;},true);assert.equal(n,3);
});
test('raccordement : 90 secondes et traitement masque conserves pour dons, vols et impacts',()=>{
 const code=lire('plateau-core.js');for(const [nom,fn] of [['dons','recupererDonsEnAttente'],['vols','recupererVolsEnAttente'],['impacts','recupererImpactsEnAttente']]){
  assert.ok(code.includes(`setInterval(() => lancerLectureFond('${nom}', ${fn}, true), 90000)`));
  assert.ok(code.includes(`setTimeout(() => lancerLectureFond('${nom}', ${fn}, true),`));
 }
});

// Mesure reproductible : requetes executees par les vraies fonctions, reponses simulees.
// Octets JSON non comprimes, jamais une mesure de facturation ni de trafic en production.
async function mesurer(ancien){
 const fixture=JSON.parse(lire('outils/bancs/fixtures/optimisation-supabase-avant.json'));
 assert.equal(createHash('sha256').update(fixture.fonctions).digest('hex'),fixture.sha256);
 const {c,temps}=contexte(ancien?{multi:fixture.fonctions}:{});
 const joueurs=Array.from({length:20},(_,i)=>({name:'PJ'+i,country:'republic',current_city:'capitale',poste:i===0?{id:'maire',city:'capitale'}:null,photo_url:'data:image/webp;base64,'+'A'.repeat(32768),domicile:{city:'capitale'}}));
 let octets=0,requetes=0;c.fetch=async url=>{
  const q=new URL(url).searchParams;let rows=joueurs;
  if(q.has('name')){const filtre=q.get('name');const noms=JSON.parse('['+filtre.slice(4,-1)+']');rows=rows.filter(j=>noms.includes(j.name));}
  if(q.get('poste')==='not.is.null')rows=rows.filter(j=>j.poste!==null);
  rows=rows.map(j=>Object.fromEntries(q.get('select').split(',').map(k=>[k,j[k]])));
  octets+=Buffer.byteLength(JSON.stringify(rows));requetes++;return {ok:true,status:200,json:async()=>rows};
 };
 for(let tick=0;tick<20;tick++){temps.now=tick*30000;await c.rafraichirTitulairesPostesElectifs();await c.rafraichirCachePhotosJoueurs(['PJ1','PJ2']);}
 return {requetes,octets_json_non_comprimes:octets,titulaires:normal(c.window._titulairesPostes)};
}
test('contre-epreuve et mesure avant/apres : portraits inutiles supprimes sans changer les titulaires',async()=>{
 const avant=await mesurer(true),apres=await mesurer(false);
 assert.ok(avant.octets_json_non_comprimes>apres.octets_json_non_comprimes*10);
 assert.equal(avant.requetes,30);assert.equal(apres.requetes,30);assert.deepEqual(avant.titulaires,apres.titulaires);
 const resultat={base:'baa9cb7',scenario:'20 PJ, portraits fictifs 32 Kio, 2 PJ visibles, 20 ticks de 30 s; aucune autre vue ouverte',avant,apres,mesure:'transport simule; JSON non comprime; pas une mesure de production'};
 if(process.env.HG_RAPPORT_OPTIMISATION)fs.writeFileSync(process.env.HG_RAPPORT_OPTIMISATION,JSON.stringify(resultat,null,2)+'\n');
 console.log(JSON.stringify(resultat));
});
