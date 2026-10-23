'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const source = fs.readFileSync('plateau-justice-economie.js', 'utf8');
const debut = source.indexOf('let RP_PERMIS_DEPOT_EN_COURS = false;');
const fin = source.indexOf('// A appeler en entrant sur le terrain', debut);
assert(debut > 0 && fin > debut);
function fixture(stockage = new Map()) {
  const appels = [], effets = [], messages = [];
  const c = {
    state: {char: {name:'Fixture'}, country:'republic', currentCity:'capitale', currentBuilding:'terrain'},
    DUREE_INSTRUCTION_PERMIS: {hangar:2, building:7}, NIVEAUX_CONSTRUCTION: {hangar:{label:'Hangar'}},
    rpAuthUid: () => 'uid-fixture', crypto: {randomUUID},
    sessionStorage: {getItem:k=>stockage.get(k)||null, setItem:(k,v)=>stockage.set(k,v), removeItem:k=>stockage.delete(k)},
    sbRpcVerdict: async (fn, params) => { appels.push({fn,params}); return c.reponse; },
    remplacerTerrainState: (...a) => effets.push(['terrain',...a]),
    appliquerPaiementServeur: (...a) => effets.push(['paiement',...a]),
    showToast: (...a) => messages.push(a), addJournalEntry:()=>{},
    document: {getElementById:()=>({classList:{remove:()=>{}}})},
    _planPermisEnCours: {},
    reponse: {ok:true, etat:{permis:{}}, document:{id:'doc'}, paiement:{pa:9,liquide:900}}
  };
  vm.createContext(c);vm.runInContext(source.slice(debut,fin),c);
  return {c,appels,effets,messages,stockage};
}
test('depot : un seul RPC, aucun paiement ni archivage client', async()=>{
 const f=fixture();await f.c.confirmerDepotPermis('hangar',999,999);
 assert.equal(f.appels.length,1);assert.equal(f.appels[0].fn,'terrain_permis_deposer');
 assert.equal(f.appels[0].params.p_palier,'hangar');assert.equal(f.stockage.size,0);
 assert.deepEqual(f.effets.map(x=>x[0]),['terrain','paiement']);
});
test('double clic : une seule commande pendant la reponse',async()=>{
 const f=fixture();let terminer;f.c.sbRpcVerdict=async(...args)=>{f.appels.push(args);return new Promise(r=>terminer=r);};
 const a=f.c.confirmerDepotPermis('hangar',1,100);await f.c.confirmerDepotPermis('hangar',1,100);
 assert.equal(f.appels.length,1);terminer(f.c.reponse);await a;
});
test('reponse perdue puis rechargement : meme intention et aucun delta local',async()=>{
 const f=fixture();f.c.reponse={ok:false,transport:{etat:'indetermine'}};await f.c.confirmerDepotPermis('hangar',1,100);
 const id=f.appels[0].params.p_requete;assert.equal(f.effets.length,0);assert.equal(f.stockage.size,1);
 const g=fixture(f.stockage);g.c.reponse.rejeu=true;await g.c.confirmerDepotPermis('hangar',1,100);
 assert.equal(g.appels[0].params.p_requete,id);assert.equal(g.stockage.size,0);
});
test('refus metier : aucun changement local et intention liberee',async()=>{
 const f=fixture();f.c.reponse={ok:false,raison:'fonds_insuffisants'};await f.c.confirmerDepotPermis('hangar',1,100);
 assert.equal(f.effets.length,0);assert.equal(f.stockage.size,0);
});
test('ancien personnage : une reponse tardive ne modifie pas le nouveau',async()=>{
 const f=fixture();let terminer;f.c.sbRpcVerdict=()=>new Promise(r=>terminer=r);
 const a=f.c.confirmerDepotPermis('hangar',1,100);f.c.state.char={name:'Autre'};terminer(f.c.reponse);await a;
 assert.equal(f.effets.length,0);assert.equal(f.stockage.size,1);
});
test('intention incertaine : changement de palier interdit',async()=>{
 const f=fixture();f.c.reponse={ok:false,transport:{etat:'indetermine'}};await f.c.confirmerDepotPermis('hangar',1,100);
 await f.c.confirmerDepotPermis('building',1,100);assert.equal(f.appels.length,1);
});
test('stockage indisponible : aucune commande envoyee',async()=>{
 const f=fixture();f.c.sessionStorage.setItem=()=>{throw Error('quota');};await f.c.confirmerDepotPermis('hangar',1,100);
 assert.equal(f.appels.length,0);assert.equal(f.effets.length,0);
});
test('confirmation incomplete : aucune fausse reussite',async()=>{
 const f=fixture();f.c.reponse={ok:true};await f.c.confirmerDepotPermis('hangar',1,100);
 assert.equal(f.effets.length,0);assert.equal(f.stockage.size,1);
});
