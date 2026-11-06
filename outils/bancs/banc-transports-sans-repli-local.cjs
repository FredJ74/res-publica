// Vraies entrées publiques, moteur canonique remplacé par un refus témoin : aucun paiement réel.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn'),R=path.resolve(__dirname,'../..');
function source(f,nom){const s=fs.readFileSync(path.join(R,f),'utf8');const n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);assert.ok(n,nom);return s.slice(n.start,n.end);}
const cas=[['plateau-navigation.js','executerVoyage','commanderTransportServeur',['train','republic','ville_a']],['plateau-navigation.js','confirmerTransport','commanderTransportServeur',['bus','republic','ville_b']],['plateau-navigation.js','doPasserDouanesAeroport','commanderDouanesServeur',[]],['plateau-navigation.js','doCorrompreDoanier','commanderCorruptionDouanesServeur',[1,300]],['plateau-justice-economie.js','doTaxiSpecial','commanderTransportServeur',['qhs',1,50]]];
for(const [f,nom,moteur,args]of cas)for(const drapeau of [undefined,false,true])test(nom+' : drapeau '+String(drapeau)+' ne sélectionne pas un paiement ou déplacement local',async()=>{
 const appels=[],toasts=[],avant={char:{name:'BancTransport'},country:'republic',currentCity:'capitale',liquide:500,pa:10,_navigationServeur:drapeau};
 const c=vm.createContext({state:structuredClone(avant),showToast:(...x)=>toasts.push(x),document:{getElementById:()=>({classList:{remove(){}},style:{}})},COUNTRIES:{republic:{cur:'FR'}},TRANSPORT_CONFIG:{train:{pa:2,cost:75,ordre:'prendre_train'},bus:{pa:1,cost:150,ordre:'prendre_bus_taxi'}},getFondsDisponiblesOrdinaires:()=>500,
 deduireCoutOrdre:async()=>assert.fail('ancien paiement séparé exécuté'),sbSavePersonnage:()=>assert.fail('ancienne sauvegarde de position'),localStorage:{setItem:()=>assert.fail('ancienne position locale')},Math:Object.assign(Object.create(Math),{random:()=>assert.fail('ancien contrôle aléatoire')})});
 c[moteur]=async(...x)=>{appels.push(x);return false;};vm.runInContext(source(f,nom),c);
 assert.equal(await c[nom](...args),false);assert.equal(appels.length,1);
 assert.deepEqual(appels[0],nom==='doTaxiSpecial'?['taxi_qhs','republic','qhs']:args);
 assert.deepEqual(JSON.parse(JSON.stringify(c.state)),JSON.parse(JSON.stringify(avant)));assert.equal(toasts.length,0);
});
test('taxi : destination inconnue refusée sans paiement ni commande',async()=>{
 const c=vm.createContext({state:{country:'republic'},showToast(){},commanderTransportServeur:()=>assert.fail('destination invalide')});vm.runInContext(source('plateau-justice-economie.js','doTaxiSpecial'),c);assert.equal(await c.doTaxiSpecial('inconnue',1,50),false);
});
