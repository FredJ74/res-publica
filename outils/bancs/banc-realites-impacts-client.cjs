const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const racine=path.resolve(__dirname,'../..');
function source(f,noms){const s=fs.readFileSync(path.join(racine,f),'utf8');return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
function fixture(){
 const appels=[],impacts=[{id:'i',indice:'hp_set',delta:0,palier:'totale',applique_serveur:true}];
 const c=vm.createContext({console,state:{char:{name:'Victime'},hp:100,pa:8},
 sbRecupererImpactsEnAttente:async()=>impacts,rpRealitesContexte:()=>({nom:'Victime'}),rpRealitesContexteValide:()=>true,
 rpRealitesRelirePersonnage:async()=>{appels.push('lire');c.state.hp=0;c.state.pa=0;return {ok:true};},
 sbMarquerImpactTraite:async(id)=>{appels.push('notifier:'+id);return {ok:true};},
 rejoindreHospitalisation:()=>appels.push('accueil-medical'),declencherHospitalisation:()=>assert.fail('aucune deuxieme hospitalisation'),updateUI:()=>assert.fail('aucune sauvegarde depuis notification'),
 addJournalEntry:()=>assert.fail('journal deja persiste SQL'),showToast:()=>appels.push('toast'),signalerEvenementJournal:()=>appels.push('signal')});
 vm.runInContext(source('plateau-communication.js',['recupererImpactsEnAttente']),c);return {c,appels,impacts};
}
test('impact serveur : relire avant notification, aucun effet ou journal rejoue',async()=>{const {c,appels}=fixture();await c.recupererImpactsEnAttente();assert.equal(c.state.hp,0);assert.equal(c.state.pa,0);assert.deepEqual(appels,['lire','notifier:i','accueil-medical','toast','signal']);});
test('reponse de notification perdue : deux lectures, aucune seconde application',async()=>{const {c,appels}=fixture();c.sbMarquerImpactTraite=async()=>null;await c.recupererImpactsEnAttente();await c.recupererImpactsEnAttente();assert.equal(c.state.hp,0);assert.equal(appels.filter(a=>a==='lire').length,2);});
test('lecture medicale refusee : ne pas consommer evenement et bloquer ordre',async()=>{const {c,appels}=fixture();c.rpRealitesRelirePersonnage=async()=>({ok:false});assert.equal((await c.recupererImpactsEnAttente()).realiteNonConfirmee,true);assert.deepEqual(appels,[]);assert.equal(c.state.hp,100);});
test('erreur HTTP lecture impacts : aucun faux ensemble vide',async()=>{const {c}=fixture();c.sbRecupererImpactsEnAttente=async()=>null;assert.equal((await c.recupererImpactsEnAttente()).realiteNonConfirmee,true);});
test('changement de personnage avant relecture : aucune notification consommee',async()=>{const {c,appels}=fixture();c.rpRealitesContexteValide=()=>false;await c.recupererImpactsEnAttente();assert.deepEqual(appels,[]);});
test('bonus carte deja acquis : pas de second gain client',async()=>{const {c,impacts}=fixture();impacts[0]={id:'carte',indice:'moral_carte_postale',applique_serveur:true,resultat:{gain_moral:10}};c.state.moral=60;await c.recupererImpactsEnAttente();assert.equal(c.state.moral,60);});

test('arrivee medicale reutilisee : aucun recalcul de PA, PV, dates, stats ou sauvegarde directe',()=>{
 const appels=[],h={lieu:'clinique',dateFinParis:'2099-01-01',impactId:'i'};
 const c=vm.createContext({state:{hospitalisation:h,hp:0,pa:0},enterBuilding:(...a)=>appels.push(a),enterRoom:(...a)=>appels.push(a)});
 vm.runInContext(source('plateau-personnage.js',['rejoindreHospitalisation']),c);c.rejoindreHospitalisation();assert.equal(c.state.hospitalisation,h);assert.equal(c.state.hp,0);assert.equal(c.state.pa,0);assert.deepEqual(appels,[['clinique-privee',true],['clinique-privee','reception_clinique',null]]);
});

test('rapports collectifs existants : tous les rounds autorises restent consultables',async()=>{
 const dom=new Map();const document={getElementById(id){if(!dom.has(id))dom.set(id,{classList:{add(){}}});return dom.get(id);}};
 const c=vm.createContext({document,sbMilitaireBatailleEtat:async()=>({ok:true,bataille:{id:3,statut:'termine',lieu:{ville:'Luthécia'},rounds:[{round:1,mes_pa_perdus:1},{round:2,mes_pa_perdus:2}]}}),escapeHtmlText:s=>String(s),showToast:()=>assert.fail('rapport disponible')});
 vm.runInContext(source('plateau-politique.js',['ouvrirPanneauCombat']),c);await c.ouvrirPanneauCombat(3);
 const html=dom.get('postes-body').innerHTML;assert.ok(html.includes('BILAN DU ROUND 1'));assert.ok(html.includes('BILAN DU ROUND 2'));
});

test('projection impacts : le navigateur ne demande jamais la colonne auteur secrete',async()=>{
 let filtre;const c=vm.createContext({sbGet:async(_,f)=>{filtre=f;return [];}});vm.runInContext(source('supabase.js',['sbRecupererImpactsEnAttente']),c);await c.sbRecupererImpactsEnAttente('Victime');assert.ok(filtre.includes('select=id,'));assert.ok(!filtre.includes('auteur'));assert.ok(filtre.includes('applique_serveur'));
});
