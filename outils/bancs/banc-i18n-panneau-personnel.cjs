'use strict';
/* Couverture du panneau gauche : titres traduits, commandes et icônes inchangées.
 * Aucun appel serveur, aucun état PJ, aucune interaction métier.
 */
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const window={};
const context=vm.createContext({window});
for(const file of ['resources.js','plateau-resources.js'])
  vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),context);
const locales=Object.keys(window.RP_I18N_LANGUAGES);
test('panneau personnel : quatre titres et neuf langues sans clé manquante',()=>{
  assert.equal(locales.length,9);
  for(const locale of locales){
    const labels=window.RP_I18N_RESOURCES[locale].translation.plateau;
    for(const k of ['myStats','myGoals','myEmployees','inventory'])
      assert.ok(typeof labels[k]==='string'&&labels[k].trim(),locale+': '+k);
  }
});
test('boutons et chevrons inchangés, seule portion de texte balisée',()=>{
  for(const [fn,key] of [["openSelfView('stats')","myStats"],["afficherObjectifsSecrets()","myGoals"],["toggleSection('employes-panel','emp-chevron')","myEmployees"],["toggleInventaire()","inventory"]]){
    const pos=html.indexOf('onclick="'+fn+'"');
    assert.notEqual(pos,-1,fn);
    const nearby=html.slice(pos,pos+650);
    assert.ok(nearby.includes('data-i18n="plateau.'+key+'"'),key);
  }
  assert.ok(html.includes('id="emp-chevron"'));
  assert.ok(html.includes('id="inv-chevron"'));
  assert.ok(html.includes('data-i18n="plateau.myGoals">Mes Objectifs 🎯</span>'));
});
