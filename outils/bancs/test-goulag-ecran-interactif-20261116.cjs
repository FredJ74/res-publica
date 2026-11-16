'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('plateau-goulag-toundra.js','utf8');

const commandes = [];
const panneaux = new Map();
const boutons = [];
let etape = 0;
const contenu = {
  innerHTML: '',
  querySelectorAll() {
    boutons.length = 0;
    for (const nom of ['abri','dormir','progresser']) {
      boutons.push({dataset:{goulagAction:nom},disabled:false,addEventListener(event,fn){this.activer=fn;}});
    }
    return boutons;
  },
};
const doc = {
  createElement() {
    return {style:{},setAttribute(){},querySelector(){return contenu;},querySelectorAll(){return contenu.querySelectorAll();},innerHTML:''};
  },
  getElementById(id) {return panneaux.get(id)||null;},
  body: {appendChild(node){panneaux.set(node.id,node);}},
  addEventListener(event,fn) {if(event==='DOMContentLoaded') this.onReady=fn;},
};
const contexte = {
  console,document:doc,state:{country:'soviet',personnageChargeDepuisServeur:false},
  window:{RP_ORDRES_DYNAMIQUES:[],setInterval(){return 1;},clearInterval(){},confirm:()=>true},
  sbRpcVerdict:async (fn,params) => {
    commandes.push({fn,params});
    if(fn==='goulag_toundra_lire')return {ok:true,en_cours:true,destination:'krasnov',progressions:etape,pa:12,bois_trouve:0,
      abri_aujourdhui:false,dormi_aujourdhui:false,progresse_aujourdhui:false};
    if(fn==='goulag_toundra_agir'){
      assert.equal(params.p_action,'progresser');
      etape++;
      return {ok:true,progressions:etape,pa:7};
    }
    return {ok:false,raison:'fonction_non_active'};
  },
};
vm.createContext(contexte);
vm.runInContext(source,contexte,{filename:'plateau-goulag-toundra.js'});
async function test(){
  await contexte.window.goulagToundraOuvrir();
  const pleinEcran=panneaux.get('goulag-toundra');
  assert.equal(pleinEcran.style.display,'block');
  assert.match(contenu.innerHTML,/Sovarka_goulag_toundra_01\.webp/);
  assert.match(contenu.innerHTML,/Dresser un abri/);
  assert.match(contenu.innerHTML,/Dormir/);
  assert.match(contenu.innerHTML,/Progresser/);
  assert.equal(boutons.length,3);
  assert.equal(boutons.find(b=>b.dataset.goulagAction==='progresser').disabled,false);
  boutons.find(b=>b.dataset.goulagAction==='progresser').activer();
  for(let i=0;i<6;i++) await new Promise(resolve=>setImmediate(resolve));
  assert.equal(etape,1);
  assert.match(contenu.innerHTML,/Sovarka_goulag_toundra_02\.webp/);
  assert.deepEqual(commandes.filter(x=>x.fn==='goulag_toundra_agir').map(x=>x.params.p_action),['progresser']);
  assert.equal(commandes.filter(x=>x.fn==='goulag_toundra_lire').length,2);
  console.log('Goulag : écran, 3 ordres, RPC serveur et passage visuel 01 → 02 testés');
}
test().catch(e=>{console.error(e);process.exitCode=1;});
