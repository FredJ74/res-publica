'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('supabase.js', 'utf8');
const start = source.indexOf('function sbEnfilerEcriturePersonnage(');
const end = source.indexOf('// PREMIERE ECRITURE D\'UN PERSONNAGE', start);
assert(start >= 0 && end > start, 'extraire la vraie fonction de sauvegarde');
const fragment = source.slice(start, end);
async function scenario({ verdict, lecture, changerPendantLecture = false }) {
  let ecritures = 0, lectures = 0, rapports = [], affichages = 0;
  const personnage = { name: 'PJ fictif' };
  const state = { char: personnage, inventory: [{id:'objet local'}], _inventaireRevision: 2, _inventaireGeneration: 0, _inventaireVersionne: true };
  const environnement = {
    Promise, JSON, Number, state,
    sbSaveQueue: Promise.resolve(),
    rpAuthUid: () => 'uid-fixture',
    rpAuthJeton: () => 'jeton-fixture',
    sbInventaireSauverRevision: async () => verdict,
    sbInventaireReceptionEtat: async () => {
      lectures++;
      if (changerPendantLecture) state.inventory = [{id:'objet nouveau de session'}];
      if (lecture instanceof Error) throw lecture;
      return lecture;
    },
    sbEmpreinteInventaire: (x) => JSON.stringify(x),
    sbEcrirePersonnage: async () => { ecritures++; return {updated_at:'2026-10-31'}; },
    reporterDeltaPopNonEcrit: () => { rapports.push('refus'); },
    sbFicheRecaler: () => {},
    rpDiagId: (_type, diagnostic) => rapports.push(diagnostic),
    updateUI: () => {affichages++;}
  };
  vm.createContext(environnement);
  vm.runInContext(fragment + '\nthis.sauvegarder=sbEnfilerEcriturePersonnage;', environnement);
  const resultat = await environnement.sauvegarder(state, { name:'PJ fictif', inventory:[{id:'objet local'}], resources:{} });
  return { state, resultat, ecritures, lectures, rapports, affichages };
}
(async () => {
  const refus = {ok:false,raison:'ajout_inventaire_interdit',revision:2};
  const canonique = {ok:true,inventory:[{id:'objet serveur'}],revision:7};
  let a = await scenario({verdict:refus,lecture:canonique});
  assert.equal(a.resultat, null);
  assert.equal(a.ecritures,0, 'aucun PATCH après refus');
  assert.equal(a.lectures,1);
  assert.equal(a.state.inventory[0].id,'objet serveur');
  assert.equal(a.state._inventaireRevision,7);
  assert.equal(a.state._inventaireConflit,false);
  assert.equal(a.affichages,1);
  let b = await scenario({verdict:refus,lecture:canonique,changerPendantLecture:true});
  assert.equal(b.ecritures,0);
  assert.equal(b.state.inventory[0].id,'objet nouveau de session', 'pas d écrasement concurrent');
  assert.equal(b.state._inventaireConflit,true);
  let c = await scenario({verdict:refus,lecture:new Error('réseau indisponible')});
  assert.equal(c.ecritures,0);
  assert.equal(c.state._inventaireConflit,true, 'réseau perdu ne valide pas la sauvegarde');
  let d = await scenario({verdict:{ok:true,inventory:[{id:'objet local'}],revision:3}});
  assert.equal(d.ecritures,1, 'une sauvegarde légitime poursuit le PATCH');
  assert.equal(d.state._inventaireRefusAjout,false);
  assert.equal(d.state._inventaireRevision,3);
  console.log('OK 4 scénarios réels du code client de sauvegarde inventaire');
})().catch(e => {console.error(e);process.exitCode=1;});
