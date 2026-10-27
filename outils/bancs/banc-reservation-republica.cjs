// #63: vrais handlers extraits par AST, backend double de controle, aucun achat reel.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn'),root=path.resolve(__dirname,'../..');
function fonctions(noms) {
  const s=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
  return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name))
    .map(n=>s.slice(n.start,n.end)).join('\n');
}
function jeu(droitsInitiaux=[]) {
  const appels=[],sauvegardes=[],droits=[...droitsInitiaux],messages=[];
  const c=vm.createContext({
    console,
    BUILDINGS:{'hotel-republica':{rooms:{
      accueil:{orders:[{fn:'reserver_chambre_hotel',pa:0,cost:80}]},
      chambres:{orders:[{fn:'dormir_chambre'}]}
    }}},
    state:{char:{name:'Alice'},country:'republic',currentCity:'capitale',currentBuilding:'hotel-republica',currentRoom:'accueil',moral:50,pa:10},
    chargerCommerce:async()=>({id:'hotel'}),
    commerceVendreProduit:async(...args)=>{
      appels.push(args);
      droits.push({id:'n'+droits.length,buildingId:'hotel-republica',ville:'capitale',country:'republic',bonus:{moral:3,paBonus:2}});
      return {ok:true};
    },
    encaisserVenteStructure:async()=>{throw Error('SECOND_PAIEMENT');},
    sbRpc:async fn=>fn==='hotel_reservations_lire'?droits.map(x=>({...x})):{ok:false},
    updateUI:()=>{},
    sauvegarderPersonnageImmediat:()=>sauvegardes.push('sauvegarde'),
    showToast:(...x)=>messages.push(x),
    addJournalEntry:()=>{},
    signalerRefusReservationChambre:()=>appels.push('refus'),
    queteAccueilApresReservationChambre:()=>{}
  });
  vm.runInContext('let reservationHotelEnCours=false;\n'+fonctions(['doReserverChambreHotel','doDormirChambre']),c);
  return {c,appels,droits,messages,sauvegardes};
}
test('une reservation : un paiement et un droit serveur, aucune sauvegarde locale',async()=>{
  const {c,appels,droits,sauvegardes}=jeu();
  await c.doReserverChambreHotel(0);
  assert.deepEqual(JSON.parse(JSON.stringify(appels[0])),['hotel',[],'service','reserver_chambre_hotel',0,80]);
  assert.equal(appels.length,1);
  assert.equal(droits.length,1);
  assert.equal(c.state.char.reservationHotel,undefined);
  assert.equal(sauvegardes.length,0);
});
test('refus paiement : aucun droit, aucune fausse reussite',async()=>{
  const {c,droits,sauvegardes}=jeu();
  c.commerceVendreProduit=async()=>({ok:false,raison:'pas_sur_place'});
  await c.doReserverChambreHotel(0);
  assert.equal(droits.length,0);
  assert.equal(sauvegardes.length,0);
});
test('deux nuits dans le meme hotel, puis chambre : aucune seconde RPC de bonus',async()=>{
  const {c,droits}=jeu();
  await c.doReserverChambreHotel(0);
  await c.doReserverChambreHotel(0);
  assert.equal(droits.length,2);
  c.state.currentRoom='chambres';
  const appels=[];c.doDormir=async()=>{appels.push('pa_repos_nocturne');return true;};
  await c.doDormirChambre();
  assert.deepEqual(appels,['pa_repos_nocturne']);
  assert.equal(c.state.pa,10);
  assert.equal(c.state.moral,50);
  assert.equal(droits.length,2); // Le serveur, et lui seul, consomme lors du repos.
});
test('reconnexion/F5 : la liste serveur reste la source de verite',async()=>{
  const premier=jeu();
  await premier.c.doReserverChambreHotel(0);
  const second=jeu(premier.droits);
  second.c.state.currentRoom='chambres';
  const appels=[];second.c.doDormir=async()=>{appels.push('repos');return true;};
  await second.c.doDormirChambre();
  assert.equal(appels.length,1);
});
test('absence de droit ou chambre absente : aucun repos',async()=>{
  const {c}=jeu();
  c.doDormir=async()=>{throw Error('REPOS_INTERDIT');};
  await c.doDormirChambre(); // accueil, refus
  c.state.currentRoom='chambres';
  await c.doDormirChambre(); // chambre sans droit, refus
});
test('double clic sur achat : une seule transaction en cours',async()=>{
  const {c,droits}=jeu();
  let debloquer;const attente=new Promise(resolve=>{debloquer=resolve;});
  let debits=0;c.commerceVendreProduit=async()=>{
    debits++;await attente;
    droits.push({id:'n0',buildingId:'hotel-republica',ville:'capitale',country:'republic',bonus:{moral:3,paBonus:2}});
    return {ok:true};
  };
  const a=c.doReserverChambreHotel(0),b=c.doReserverChambreHotel(0);
  debloquer();
  await Promise.all([a,b]);
  assert.equal(debits,1);
  assert.equal(droits.length,1);
});
