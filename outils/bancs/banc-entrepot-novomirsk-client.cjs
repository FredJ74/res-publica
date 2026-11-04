// Raccordement au moteur existant ; aucune session réelle, aucun achat réseau.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const R=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(R,f),'utf8');
function contexte(pays='soviet'){
 const c=vm.createContext({state:{country:pays,currentCity:'capitale',currentBuilding:'entrepot-logistique-novomirsk',poste:{id:'directeur_entrepot',city:'capitale'}},window:{}});
 vm.runInContext(lire('data.js'),c);vm.runInContext(lire('plateau-entrepots.js'),c);
 // Fonction courte : extraction bornée entre deux déclarations connues, sans réécriture.
 const s=lire('plateau-justice-economie.js');vm.runInContext(s.slice(s.indexOf('function getBuildingIdDirecteurEntrepot()'),s.indexOf('async function doOuvrirFixerPrixAchatEntrepot')),c);return c;
}
test('quatre entrepôts distincts, aucune capitale de repli hors pays configuré',()=>{
 const c=contexte();for(const [p,v,b]of[['soviet','capitale','novomirsk'],['republic','capitale','luthecia'],['republic','ville_a','psm'],['republic','ville_b','montrouge']])assert.equal(vm.runInContext(`entrepotLogistiqueDe('${p}','${v}')`,c),'entrepot-logistique-'+b);
 assert.equal(vm.runInContext("entrepotLogistiqueDe('narco','capitale')",c),null);assert.equal(vm.runInContext("entrepotLogistiqueDe('soviet','ville_a')",c),null);
 assert.equal(vm.runInContext('entrepotIdCourant()',c),'soviet_capitale_entrepot-logistique-novomirsk');
});
test('accueil, ventes, direction et ordres issus du modèle existant',()=>{
 const c=contexte(),b=vm.runInContext("BUILDINGS['entrepot-logistique-novomirsk']",c);
 assert.deepEqual(Object.keys(b.rooms),['accueil','salle_ventes','bureau_direction']);
 assert.ok(vm.runInContext("WORLD.soviet.capitale.buildings.includes('entrepot-logistique-novomirsk')",c));
 for(const r of ['salle_ventes','bureau_direction'])assert.deepEqual(JSON.parse(JSON.stringify(b.rooms[r].orders)),JSON.parse(vm.runInContext(`JSON.stringify(BUILDINGS['entrepot-logistique-luthecia'].rooms.${r}.orders)`,c)));
 assert.equal(b.rooms.accueil.persons.length,1);assert.equal(b.rooms.bureau_direction.persons[0].job,'directeur_entrepot');assert.equal(b.rooms.salle_ventes.imageUrl,null);
 const rue=lire('plateau-rue-centrale.js'),section=rue.slice(rue.indexOf("'novomirsk-vue-8':"),rue.indexOf("'novomirsk-vue-9':"));assert.match(section,/type: 'batiment', buildingId: 'entrepot-logistique-novomirsk'/);
});
test('tableau de bord : requête nationale, caisse nationale, aucun fournisseur étranger',async()=>{
 const c=contexte(),calls=[];Object.assign(c,{sbGetBatimentEtat:async(...args)=>{calls.push(args);return{entrepot:{stock:{bois:3}}};},sbGetCaisseBatiment:async id=>{calls.push([id]);return{solde:0};},sbGet:async(...args)=>{calls.push(args);return[];},sbRpc:async()=>{throw Error('RPC étrangère inattendue');}});
 const v=await vm.runInContext('chargerTableauEntrepot()',c);assert.equal(v.caisse,0);assert.equal(v.etrangers.length,0);assert.equal(v.port,null);
 assert.ok(calls.some(x=>x[0]==='soviet_entrepot_capitale'));assert.ok(calls.some(x=>x[0]==='batiments_etat'&&x[1].includes('country=eq.soviet')));assert.ok(!calls.some(x=>x.includes('republic')));
});
test('un client ne peut ouvrir le tableau du directeur ni débiter via une commande locale',async()=>{
 const c=contexte();c.state.poste=null;let refus=false;c.showToast=()=>{refus=true;};await vm.runInContext('ouvrirTableauBordEntrepot()',c);assert.ok(refus);
 assert.match(lire('plateau-entrepots.js'),/executerReceptionInventaire\('entrepot_commander'/);
 assert.doesNotMatch(lire('plateau-entrepots.js'),/sbRpc\('entrepot_commander'/);
});
test('cache des titulaires séparé par pays et réponse tardive ignorée',async()=>{
 const c=contexte();c.POSTES_UNIQUES_A_MASQUER=['directeur_entrepot'];const s=lire('plateau-multijoueur.js');
 vm.runInContext(s.slice(s.indexOf('function filtrerPnjPostesPourvus('),s.indexOf('async function rafraichirTitulairesPostesElectifs(')),c);
 const start=s.indexOf('async function rafraichirTitulairesPostesElectifs('),end=s.indexOf('\n}',start)+2;vm.runInContext(s.slice(start,end),c);
 c.sbListPersonnages=async()=>[{name:'Autre',country:'republic',poste:{id:'directeur_entrepot',city:'capitale'}}];await vm.runInContext('rafraichirTitulairesPostesElectifs()',c);
 assert.equal(vm.runInContext("filtrerPnjPostesPourvus([{name:'Direction (PNJ)',job:'directeur_entrepot'}]).length",c),1);
 c.window._titulairesPostes={directeur_entrepot_capitale:'Ancien'};c.window._titulairesPostesPays='republic';assert.equal(vm.runInContext("filtrerPnjPostesPourvus([{name:'Direction (PNJ)',job:'directeur_entrepot'}]).length",c),1);
 let resolve;c.sbListPersonnages=()=>new Promise(r=>resolve=r);const p=vm.runInContext('rafraichirTitulairesPostesElectifs()',c);c.state.country='republic';resolve([{name:'Tardif',country:'republic',poste:{id:'directeur_entrepot',city:'capitale'}}]);await p;assert.equal(c.window._titulairesPostes.directeur_entrepot_capitale,'Ancien');
});
