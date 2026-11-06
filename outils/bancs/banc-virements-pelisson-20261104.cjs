'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const racine=path.join(__dirname,'../..');
const fichier=(n)=>fs.readFileSync(path.join(racine,n),'utf8');
const data=fichier('data.js');
const sourceFormulaire=fichier('plateau-justice-economie.js');
function bloc(nom) {
  const debut=data.lastIndexOf("  '"+nom+"': {");
  assert.ok(debut>=0,nom);
  return data.slice(debut, data.indexOf('\n  },', debut)+5);
}
test('la banque nationale et les guichets locaux affichent un seul menu Virements sans debit',()=>{
  for(const id of ['banque-nationale','banque-locale']){
    const b=bloc(id),ordres=b.slice(b.indexOf('orders: ['));
    assert.match(ordres,/fn:'virements', label:'Virements', pa:0, cost:0/);
    assert.doesNotMatch(ordres,/fn:'virement_joueur'|fn:'virement_automatique'/);
    assert.equal((ordres.match(/fn:'virements'/g)||[]).length,1);
    assert.match(ordres,/fn:'gerer_finances'/);
    assert.match(ordres,/fn:'emprunter'/);
  }
  const client=fichier('plateau-router.js');
  assert.match(client,/if \(fn === 'virements'\)\s*\{ ouvrirChoixVirements\(\); return; \}/);
  assert.match(client,/if \(fn === 'virement_joueur'\)\s*\{ ouvrirVirementJoueur\(false\); return; \}/);
  assert.match(client,/if \(fn === 'virement_automatique'\)\s*\{ ouvrirVirementJoueur\(true\); return; \}/);
});
test('le sous-menu choisit les deux formulaires existants sans payer ni ouvrir hors banque',()=>{
  const start=sourceFormulaire.indexOf('function ouvrirChoixVirements() {');
  const end=sourceFormulaire.indexOf('async function ouvrirVirementJoueur(automatique)',start);
  assert.ok(start>0&&end>start);
  const title={textContent:''},body={innerHTML:''};
  const classes=[],toasts=[],calls=[];
  const nodes={'postes-modal-title':title,'postes-body':body,'modal-postes':{classList:{add:k=>classes.push(k)}}};
  const ctx={state:{currentBuilding:'banque-locale'},document:{getElementById:k=>nodes[k]},showToast:(...a)=>toasts.push(a),ouvrirVirementJoueur:v=>calls.push(v)};
  vm.createContext(ctx);
  vm.runInContext(sourceFormulaire.slice(start,end),ctx);
  ctx.ouvrirChoixVirements();
  assert.deepEqual(classes,['open']);
  assert.match(body.innerHTML,/Virement unique/);
  assert.match(body.innerHTML,/Virement récurrent/);
  assert.match(body.innerHTML,/ouvrirVirementJoueur\(false\)/);
  assert.match(body.innerHTML,/ouvrirVirementJoueur\(true\)/);
  assert.match(body.innerHTML,/Aucun PA/);
  assert.deepEqual(calls,[]);
  ctx.ouvrirVirementJoueur(false);ctx.ouvrirVirementJoueur(true);
  assert.deepEqual(calls,[false,true]);
  ctx.state.currentBuilding='banque-nationale';ctx.ouvrirChoixVirements();assert.equal(classes.length,2);
  ctx.state.currentBuilding='banque-privee';ctx.ouvrirChoixVirements();assert.equal(classes.length,2);assert.equal(toasts.length,1);
  assert.match(sourceFormulaire,/sbRpcVerdict\('banque_virement'/);
  assert.match(sourceFormulaire,/sbRpcVerdict\('banque_virement_automatique_creer'/);
  assert.match(sourceFormulaire,/Virer \(1 PA\)/);
});
test('Robert Pelisson occupe le meme poste que Marie Le Roux, avec la personnalite locale',async()=>{
  const b=data.indexOf("Banque Cheminote de Montrouge");
  const m=data.slice(b,b+1000);
  assert.match(m,/Robert Pelisson \(PNJ\)/);
  assert.match(m,/job:'directeur'/);
  const p=data.indexOf("name:'Marie Le Roux \(PNJ\)'");
  assert.ok(p>0);
  assert.match(data.slice(p,p+220),/job:'directeur'/);
  const ui=fichier('plateau-core.js');
  assert.match(ui,/'Robert Pelisson': \{ trait: .*55 ans/);
  assert.match(ui,/supporter de l'USM/);
  const profils=await import(pathToFileURL(path.join(racine,'api/_pnj-personnalites.js')).href);
  const profil=profils.profilsPersonnalites().robert_pelisson;
  assert.ok(profil);
  for(const mot of ['55 ans','Montrouge','USM','football'])assert.ok(profil.caractere.includes(mot));
  assert.match(profil.identite,/Directeur de la Banque Cheminote de Montrouge/);
  assert.match(profil.limites,/TU NE CONNAIS AUCUNE REGLE DU JEU/);
});
