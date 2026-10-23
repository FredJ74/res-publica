const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const src=fs.readFileSync('plateau-pnj.js','utf8');
const debut=src.indexOf('const PALIERS_BONUS_ARGENT_SQUATTEURS'),fin=src.indexOf('const ACOMPTE_COMPROMIS',debut);
function fixture(){
 const els={},appels=[],toasts=[],journal=[],rendus=[],observateurs=[];
 const element=id=>els[id]||(els[id]={id,textContent:'',value:'500',disabled:false,classList:{open:false,add(){this.open=true},remove(){this.open=false},contains(){return this.open}},innerHTML:''});
 const state={char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'terrain-a-batir-1',currentRoom:'terrain',pa:30,moral:50};
 let verdict={ok:true,etat:{pnj:'squatter_cool',dateGeneration:1},occupation:'1:squatter_cool',minimum:1,baseTaux:50};
 const ctx={state,crypto:{randomUUID:()=> 'requete-unique'},rpAuthUid:()=> 'fixture-uid',COUNTRIES:{republic:{cur:'FR'}},
  BUILDINGS:{'terrain-a-batir-1':{rooms:{terrain:{persons:[]}}}},document:{getElementById:element},
  sbRpcVerdict:async(fn,args)=>{appels.push({fn,args});return typeof verdict==='function'?verdict(fn,args):verdict},
  remplacerTerrainState:(id,e)=>{state.etat=e},renderPersonsList:()=>rendus.push('personnes'),renderRoomActions:()=>rendus.push('ordres'),
  appliquerPaiementServeur:p=>Object.assign(state,p),updateUI:()=>{},showToast:(...x)=>toasts.push(x),addJournalEntry:(...x)=>journal.push(x),
  sessionStorage:{removeItem(){}},window:{_terrainOrdresGroupes:{}},
  sbGetTerrainState:async()=>state.etat,
  MutationObserver:class{constructor(fn){this.fn=fn;observateurs.push(this)}observe(){}disconnect(){this.termine=true}},
  ouvrirMenuOrdresTerrain:k=>rendus.push(k)};
 vm.createContext(ctx);vm.runInContext(src.slice(debut,fin),ctx);
 return {ctx,state,els,element,appels,toasts,journal,rendus,observateurs,setVerdict:v=>verdict=v};
}
test('refus : nouvelle proposition, fonds inchanges, offre egale ou inferieure non envoyee',async()=>{
 const f=fixture();await f.ctx.doNegocierSquatteurs(1,0);assert.match(f.element('postes-body').innerHTML,/uniquement si l’accord est accepté/);
 f.element('negoc-montant').value='500';
 f.setVerdict({ok:true,accepte:false,pnj:'squatter_cool',etat:{pnj:'squatter_cool'},paiement:{pa:29,arg:1000,moral:50}});
 await f.ctx.confirmerNegociation(1,0);assert.match(f.element('postes-body').innerHTML,/Nouvelle proposition/);assert.equal(f.state.arg,1000);
 f.setVerdict({ok:true,etat:{pnj:'squatter_cool'},occupation:'1:squatter_cool',minimum:501,dernierRefus:500,baseTaux:50});
 await f.ctx.doNegocierSquatteurs(1,0);assert.match(f.element('postes-body').innerHTML,/Dernière offre refusée : 500/);
 const n=f.appels.length;for(const valeur of ['499','500','500.5','NaN']){f.element('negoc-montant').value=valeur;await f.ctx.confirmerNegociation(1,0)}
 assert.equal(f.appels.length,n);
});
test('accord : bonus recopie, jamais additionne, reponse RP et achat seulement apres fermeture',async()=>{
 const f=fixture();await f.ctx.doNegocierSquatteurs(1,0);
 f.setVerdict({ok:true,accepte:true,pnj:'squatter_cool',bonusMoral:1,etat:{pnj:null,occupationScellee:true},paiement:{pa:29,moral:51,arg:500}});
 await f.ctx.confirmerNegociation(1,0);assert.equal(f.state.moral,51);assert.match(f.element('negoc-replique').textContent,/offre une mousse/);
 assert.doesNotMatch(f.element('postes-body').innerHTML,/Acheter le terrain/);
 const n=f.appels.length;await f.ctx.confirmerNegociation(1,0);assert.equal(f.appels.length,n);assert.equal(f.state.moral,51);
 f.element('modal-postes').classList.remove('open');f.observateurs[0].fn();await new Promise(resolve=>setImmediate(resolve));
 assert.match(f.element('postes-body').innerHTML,/Les squatteurs sont partis/);assert.match(f.element('postes-body').innerHTML,/Acheter le terrain/);
 assert.equal(f.observateurs[0].termine,true);
});
test('reponse perdue : meme UUID et meme montant, aucun tirage ni debit client',async()=>{
 const f=fixture();await f.ctx.doNegocierSquatteurs(1,0);f.setVerdict(null);
 await f.ctx.confirmerNegociation(1,0);assert.equal(f.element('negoc-confirmer').textContent,'Vérifier le résultat');
 f.element('negoc-montant').value='900';await f.ctx.confirmerNegociation(1,0);
 assert.deepEqual(f.appels[1].args,f.appels[2].args);assert.equal(f.state.pa,30);
});
test('changement de personnage pendant le transport : aucun fonds ni dialogue recopie',async()=>{
 const f=fixture();await f.ctx.doNegocierSquatteurs(1,0);let resolve;
 f.setVerdict(()=>new Promise(r=>resolve=r));const promesse=f.ctx.confirmerNegociation(1,0);f.state.char={name:'Autre'};
 resolve({ok:true,accepte:true,paiement:{moral:51,arg:1},etat:{pnj:null}});await promesse;
 assert.equal(f.state.moral,50);assert.equal(f.state.arg,undefined);assert.equal(f.journal.length,0);
});
test('cadavre ou occupation remplacee : aucun accord invente, cartes rafraichies',async()=>{
 const f=fixture();f.setVerdict({ok:false,raison:'aucun_squatteur',etat:{pnj:'cadavre'}});
 await f.ctx.doNegocierSquatteurs(1,0);assert.equal(f.state._negociationSquatteurs,undefined);assert.deepEqual(f.rendus,['personnes','ordres']);
 assert.equal(f.state.etat.pnj,'cadavre');
});
test('repliques agressives et bareme par paliers restent coherents',()=>{
 const {ctx}=fixture();assert.match(ctx.repliqueNegociationSquatteurs('squatter_agr'),/baltringue.*toutous.*défonce/);
 assert.match(ctx.repliqueNegociationSquatteurs('squatter_agr','refuse'),/Garde ton fric/);
 assert.match(ctx.repliqueNegociationSquatteurs('squatter_agr','accepte'),/On prend le fric/);
 for(const [montant,bonus] of [[1,0],[500,5],[1000,8],[2000,12],[3000,16],[4000,20],[5000,20]])assert.equal(ctx.bonusArgentSquatteurs(montant),bonus);
 assert.equal(ctx.tauxNegociationServeur(50,500),55);
});
