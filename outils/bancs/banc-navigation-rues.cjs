const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const racine=path.resolve(__dirname,'../..'),source=fs.readFileSync(path.join(racine,'plateau-rue-centrale.js'),'utf8');
class Element{constructor(){this.innerHTML='';this.style={};this.enfants=[];this.events={};this.classList={add(){},remove(){}};}appendChild(n){this.enfants.push(n);}addEventListener(n,f){this.events[n]=f;}}
function jeu(ville='capitale'){
 const elements=new Map(['rue-centrale-conteneur','rc-scene','rc-image','rc-overlay','rc-texte'].map(k=>[k,new Element()]));
 const c=vm.createContext({state:{char:{name:'Alice'},country:'republic',currentCity:ville},uid:'u',session:'s',console,timers:[],document:{getElementById:id=>elements.get(id)||null,createElement:()=>new Element()},localStorage:{setItem(){},getItem(){return null;}}});
 c.rpAuthUid=()=>c.uid;c.rpAuthSessionIdentifiant=()=>c.session;c.setTimeout=(f,ms)=>{c.timers.push({f,ms});};c.requestAnimationFrame=f=>f();c.sbRpc=async()=>({ok:true});
 vm.runInContext(source,c);c.lire=e=>vm.runInContext(e,c);c.html=()=>elements.get('rue-centrale-conteneur').innerHTML;c.zones=()=>elements.get('rc-scene').enfants;c.flux=()=>c.timers.sort((a,b)=>a.ms-b.ms).splice(0);
 return c;
}
for(const [ville,noeud,parent] of [['capitale','luthecia-terrains-lots','luthecia-terrains-artisanal'],['ville_a','psm-terrains-lots','psm-terrains-vente']])test(`lots/${ville} : fleche en bas, destination et retour valides`,async()=>{
 const c=jeu(ville);await c.afficherNoeudRue('republic',noeud,parent,true);
 assert.match(c.html(),/bottom:10px; left:50%; transform:translateX\(-50%\)/);assert.equal((c.html().match(/class="rc-fleche"/g)||[]).length,1);
 const commandes=[];c.sbRpc=async(fn,p)=>{commandes.push([fn,p]);return {ok:true};};c.deplacerRueCentrale('republic','arriere');for(const t of c.flux())await t.f();await new Promise(setImmediate);
 assert.equal(commandes.length,1);assert.equal(commandes[0][0],'rue_position_enregistrer');assert.equal(commandes[0][1].p_noeud,parent);assert.equal(c.lire('rueCentraleNoeudActuel'),parent);assert.equal(c.lire('rueCentraleDepuisNoeud'),noeud);
});
const variantes={
 'psm-carrefour-artisanal-scierie':{image:'artisanal',zones:[['musee-port-sainte-marie',0,22],['centre-commercial',38,60],['centre-affaires',78,100]],liens:['psm-ecole-phare','psm-eglise-cimetiere','psm-tribunal-banque']},
 'psm-ecole-phare':{image:'phare',zones:[['musee-port-sainte-marie',0,35],['centre-commercial',42,58],['centre-affaires',65,100]],liens:['psm-tribunal-banque','psm-carrefour-artisanal-scierie','psm-eglise-cimetiere']},
 'psm-tribunal-banque':{image:'tribunal',zones:[['centre-commercial',0,30],['centre-affaires',40,55],['musee-port-sainte-marie',68,100]],liens:['psm-eglise-cimetiere','psm-ecole-phare','psm-carrefour-artisanal-scierie']},
 'psm-eglise-cimetiere':{image:'eglise',zones:[['centre-affaires',0,32],['musee-port-sainte-marie',50,65],['centre-commercial',70,100]],liens:['psm-carrefour-artisanal-scierie','psm-tribunal-banque','psm-ecole-phare']}
};
for(const [depuis,v] of Object.entries(variantes))test(`carrefour PSM/${depuis} : image, zones et quatre directions preservees`,async()=>{
 const c=jeu('ville_a'),noeud=c.lire('RUE_CENTRALE_NOEUDS.republic["psm-carrefour-musee"]');
 await c.afficherNoeudRue('republic','psm-carrefour-musee',depuis,true);assert.ok(c.html().includes('images/rue-carrefour-musee-depuis-'+v.image+'.webp'));
 assert.ok(fs.existsSync(path.join(racine,noeud.imagesParArrivee[depuis])));
 assert.deepEqual(JSON.parse(JSON.stringify(noeud.zonesParArrivee[depuis].map(z=>[z.buildingId,...z.xPct]))),v.zones);
 assert.equal(c.zones().length,3);
 if(depuis==='psm-tribunal-banque'){assert.deepEqual(c.zones().map(z=>[z.style.top,z.style.height]),[['22%','53%'],['22%','33%'],['22%','53%']]);}
 for(const [i,z] of c.zones().entries()){let cible;c.entrerDansBatimentRue=id=>cible=id;z.events.click();assert.equal(cible,v.zones[i][0]);}
 for(const [i,dir] of ['gauche','droite','toutDroit','arriere'].entries()){
  let cible;c.afficherNoeudRue=async(p,n)=>cible=n;c.deplacerRueCentrale('republic',dir);for(const t of c.flux())await t.f();assert.equal(cible,i===3?depuis:v.liens[i]);
 }
});
for(const changement of ['personnage','nom','compte','session','ville','batiment'])test(`reponse de deplacement tardive/${changement} : pas de contamination`,async()=>{
 const c=jeu();let finir;c.sbRpc=()=>new Promise(r=>finir=r);const p=c.afficherNoeudRue('republic','luthecia-terrains-lots','luthecia-terrains-artisanal');
 if(changement==='personnage')c.state.char={name:'Bob'};if(changement==='nom')c.state.char.name='Bob';if(changement==='batiment')c.state.currentBuilding='mairie';if(changement==='compte')c.uid='autre';if(changement==='session')c.session='autre';if(changement==='ville')c.state.currentCity='ville_a';
 finir({ok:true});await p;assert.equal(c.html(),'');assert.equal(c.lire('rueCentraleNoeudActuel'),null);
});
test('double clic : un seul ordre serveur simultane',async()=>{
 const c=jeu();let finir,n=0;c.sbRpc=()=>{n++;return new Promise(r=>finir=r);};const p=c.afficherNoeudRue('republic','luthecia-terrains-lots');
 const autre=c.afficherNoeudRue('republic','luthecia-terrains-artisanal');assert.equal(n,1);finir({ok:true});await Promise.all([p,autre]);
});
for(const fn of ['deplacerRueCentrale','naviguerVersNoeudRue'])test(`animation differee/${fn} : aucun ordre sur le nouveau personnage`,async()=>{
 const c=jeu();await c.afficherNoeudRue('republic','luthecia-terrains-lots',null,true);let n=0;c.sbRpc=async()=>{n++;return {ok:true};};
 c[fn]('republic',fn==='deplacerRueCentrale'?'arriere':'luthecia-terrains-artisanal');c.state.char={name:'Bob'};for(const t of c.flux())await t.f();assert.equal(n,0);
});
test('refus du serveur : scene conservee et verrou libere pour une nouvelle tentative',async()=>{
 const c=jeu();await c.afficherNoeudRue('republic','luthecia-terrains-artisanal',null,true);c.sbRpc=async()=>({ok:false,raison:'non_voisin'});
 await c.afficherNoeudRue('republic','luthecia-terrains-lots');assert.equal(c.lire('rueCentraleNoeudActuel'),'luthecia-terrains-artisanal');
 c.sbRpc=async()=>({ok:true});await c.afficherNoeudRue('republic','luthecia-terrains-lots');assert.equal(c.lire('rueCentraleNoeudActuel'),'luthecia-terrains-lots');
});
test('restauration : la lecture la plus recente gagne sans envoyer de deplacement',async()=>{
 const c=jeu();const finir=[];c.sbRpc=(fn)=>{assert.equal(fn,'rue_position_lire');return new Promise(r=>finir.push(r));};
 const a=c.initialiserRueCentrale('republic','luthecia-terrains-artisanal'),b=c.initialiserRueCentrale('republic','luthecia-terrains-lots');
 finir[1]({ok:true,country:'republic',city:'capitale',street:'luthecia-terrains-lots'});await b;finir[0]({ok:true,country:'republic',city:'capitale',street:'luthecia-terrains-artisanal'});await a;
 assert.equal(c.lire('rueCentraleNoeudActuel'),'luthecia-terrains-lots');
});
test('une lecture partie pendant un deplacement ne restaure pas une ancienne position',async()=>{
 const c=jeu();let mouvement,lecture;c.sbRpc=fn=>new Promise(r=>{if(fn==='rue_position_lire')lecture=r;else mouvement=r;});
 const a=c.afficherNoeudRue('republic','luthecia-terrains-lots'),b=c.initialiserRueCentrale('republic','luthecia-terrains-artisanal');
 mouvement({ok:true});await a;lecture({ok:true,country:'republic',city:'capitale',street:'luthecia-terrains-artisanal'});await b;assert.equal(c.lire('rueCentraleNoeudActuel'),'luthecia-terrains-lots');
});
test('restauration d un ancien personnage : ni scene ni position locale appliquee',async()=>{
 const c=jeu();let finir;c.sbRpc=()=>new Promise(r=>finir=r);const p=c.initialiserRueCentrale('republic','luthecia-terrains-lots');c.state.char={name:'Bob'};
 finir({ok:true,country:'republic',city:'capitale',street:'luthecia-terrains-lots'});await p;assert.equal(c.html(),'');
});
test('31 scenes Luthecia/PSM : images et destinations existent sans imposer la meme orientation aux quatre vues',()=>{
 const c=jeu(),scenes=c.lire('RUE_CENTRALE_NOEUDS.republic');let nombre=0;
 for(const [id,scene] of Object.entries(scenes)){
  if(!/^(luthecia|psm)-/.test(id))continue;nombre++;
  for(const image of [scene.image,...Object.values(scene.imagesParArrivee||{})])if(image)assert.ok(fs.existsSync(path.join(racine,image)),id+' : '+image);
  for(const liens of [scene.liens,...Object.values(scene.liensParArrivee||{})])for(const dest of Object.values(liens||{}))if(dest)assert.ok(scenes[dest],id+' : '+dest);
  for(const zones of [scene.zones,...Object.values(scene.zonesParArrivee||{})])for(const zone of zones||[])if(zone.type==='noeud')assert.ok(scenes[zone.noeudId],id+' : '+zone.noeudId);
 }
 assert.equal(nombre,31);
});

test('authentification différée : la garde transmise interdit un nouvel ordre après changement de session',async()=>{
 const c=jeu();let garde; c.sbRpc=async(fn,p,options)=>{garde=options.encoreValide;assert.equal(garde(),true);c.session='autre';assert.equal(garde(),false);return null;};
 await c.afficherNoeudRue('republic','luthecia-terrains-lots');assert.equal(typeof garde,'function');assert.equal(c.lire('rueCentraleNoeudActuel'),null);
});
