const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
function fixture() {
  const elements = new Map();
  for (const id of ['modal-pnj','postes-modal-title','postes-body','modal-postes','ced-acheter'])
    elements.set(id,{innerHTML:'',textContent:'',classList:{add(){},remove(){}}});
  let calls=[];
  const storage = new Map();
  const c={state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'centre-artisanal',currentRoom:'travees'},
    sessionStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},
    rpAuthUid:()=> 'uid',crypto:{randomUUID:()=> 'requete-unique'},document:{getElementById:id=>elements.get(id)},
    showToast(){},addJournalEntry(){},updateUI(){},appliquerPaiementServeur(){},sbAdopterInventaireServeur:r=>{c.state.inventory=r.inventory;return true;},
    sbRpcVerdict:async(fn,params)=>{calls.push({fn,params});return {ok:true,inventory:[{name:'Boulette de shit'}],paiement:{}};}};
  vm.createContext(c);vm.runInContext(fs.readFileSync(path.join(root,'plateau-ced.js'),'utf8'),c);
  return {c,elements,calls};
}
test('Ced : livraison serveur et aucune addition client',async()=>{
  const {c,calls}=fixture();c.ouvrirAchatCed();await c.confirmerAchatCed();
  assert.equal(calls.length,1);assert.equal(calls[0].fn,'pnj_ced_acheter');
  assert.equal(c.state.inventory[0].name,'Boulette de shit');assert.equal(c.state._achatCed.termine,true);
  await c.confirmerAchatCed();assert.equal(calls.length,1);
});
test('Ced : resultat perdu conserve UUID a la reouverture',async()=>{
  const {c}=fixture();let ids=[];c.sbRpcVerdict=async(fn,p)=>{ids.push(p.p_requete);return {ok:false,transport:{etat:'reseau'}};};
  c.ouvrirAchatCed();await c.confirmerAchatCed();const pending=c.state._achatCed;
  c.ouvrirAchatCed();assert.equal(c.state._achatCed,pending);await c.confirmerAchatCed();
  assert.deepEqual(ids,['requete-unique','requete-unique']);assert.equal(pending.termine,undefined);
  // Un rechargement perd l'objet memoire, mais conserve le recu a verifier dans cet onglet.
  delete c.state._achatCed;c.crypto.randomUUID=()=> 'ne-doit-pas-etre-utilisee';c.ouvrirAchatCed();
  await c.confirmerAchatCed();assert.equal(ids[2],'requete-unique');
});
test('Ced : double clic en vol et reconnexion ne recopient aucun inventaire',async()=>{
  const {c}=fixture();let resolve,n=0;c.sbRpcVerdict=()=>{n++;return new Promise(r=>resolve=r);};
  c.ouvrirAchatCed();const first=c.confirmerAchatCed();await c.confirmerAchatCed();assert.equal(n,1);
  c.state.char={name:'Autre'};resolve({ok:true,inventory:[{name:'objet premier joueur'}],paiement:{}});await first;
  assert.equal(c.state.inventory,undefined);
});
test('Ced : refus sans debit ni objet local',async()=>{
  const {c}=fixture();let paiements=0;c.appliquerPaiementServeur=()=>paiements++;
  c.sbRpcVerdict=async()=>({ok:false,raison:'fonds_insuffisants'});
  c.ouvrirAchatCed();await c.confirmerAchatCed();assert.equal(paiements,0);assert.equal(c.state.inventory,undefined);
});
test('Stade : vrais choix actifs a zero, desactives et expliques a deux',async()=>{
  const source=fs.readFileSync(path.join(root,'plateau-organisations-quetes.js'),'utf8');
  const code=source.slice(source.indexOf('async function doTenueEntrainement('),source.indexOf('async function confirmerEntrainement('));
  for(const nb of [0,2]){
    const {c,elements}=fixture();Object.assign(c,{getClubLocal:()=>({id:'club'}),rafraichirLicenceSportiveDepuisServeur:async()=>{},
      messageLicenceInvalidePourClub:()=>null,estIndisponiblePourSport:()=>false,
      sbFootballEntrainementsDuJour:async()=>({ok:true,nb,jour:42}),LABELS_PERF:{defense:'Défense',technique:'Technique',endurance:'Endurance'}});
    vm.runInContext(code,c);await c.doTenueEntrainement(2,0);
    const html=elements.get('postes-body').innerHTML;
    assert.equal((html.match(/<button disabled/g)||[]).length,nb===2?3:0);
    if(nb===2)assert.match(html,/minuit/);
    assert.equal(c.state.char.entrainementsJour.jour,42);
  }
});
test('Ced : trace effectivement formulatee pour les rumeurs',()=>{
  const src=fs.readFileSync(path.join(root,'plateau-actions-illegales-rumeurs.js'),'utf8');
  assert.match(src,/achat_drogue:\s*\(a, c\)/);
});
test('Henrico oriente des le premier conseil ; Ced connait son offre et Pat',async()=>{
  const {construirePromptSysteme}=await import(path.join(root,'api/_pnj-profils.js'));
  const h=construirePromptSysteme('henrico_stot','fr');
  assert.match(h,/premier conseil/);assert.match(h,/immédiatement/);assert.match(h,/Grobras Sécurité/);
  assert.match(h,/pas ton employeur/);
  const c=construirePromptSysteme('ced_labone','fr');assert.match(c,/50 FR/);assert.match(c,/Pat Hounette/);
  assert.doesNotMatch(c,/TU NE NOMMES PERSONNE|Tu ne nommes aucune marchandise/);
});
