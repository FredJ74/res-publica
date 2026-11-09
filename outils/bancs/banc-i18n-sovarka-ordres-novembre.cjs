'use strict';
// Contrôle sans réseau, sans authentification, sans RPC et sans activation publique.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const ids={
  sovarka_musee_billet:'Billet du musée présidentiel',
  sovarka_surveiller:'Placer sous surveillance',
  sovarka_registre_plaintes:'Affaires judiciaires',
  sovarka_extrait_parti:"Extrait d'enregistrement du parti"
};
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
const bridge=fs.readFileSync(path.join(root,'i18n/plateau-bridge.js'),'utf8');
const init=fs.readFileSync(path.join(root,'i18n/plateau-init.js'),'utf8');
const ctx={window:{}};
vm.createContext(ctx);
for(const file of ['i18n/resources.js','i18n/orders-resources.js','i18n/ordres.js']){
  vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
}
const win=ctx.window;
assert.deepEqual(Array.from(Object.keys(win.RP_I18N_LANGUAGES)),langs);
const words=win.RP_I18N_RESOURCES;
const catalog=words.fr.translation.orders;
let count=0;
for(const [id,label] of Object.entries(ids)){
  // Chaque libellé français est strictement celui d'une action déclarée,
  // et les identifiants d'ordre ne sont ni créés ni modifiés.
  const match=new RegExp('\\bfn\\s*:\\s*[\\x27\\x22]'+id+'[\\x27\\x22]\\s*,\\s*label\\s*:\\s*[\\x27\\x22]');
  assert.match(source,match,id+': ordre réel dans data.js');
  assert.equal(catalog[id],label,id+': ancre française');
  for(const lang of langs){
    const translated=words[lang]?.translation?.orders?.[id];
    assert.equal(typeof translated,'string',lang+'/'+id+': manquant');
    assert.ok(translated.trim(),lang+'/'+id+': vide');
    count++;
  }
}
// Le rendu ne translate que le libellé, après vérification du canon français.
const engine={t(key,{lng,defaultValue}={}){
  const [scope,id]=key.split('.');
  return words[lng]?.translation?.[scope]?.[id]??defaultValue;
}};
const translate=win.RPOrderI18n.label;
for(const lang of langs){
  for(const [fn,label] of Object.entries(ids)){
    const order={fn,label,pa:2,cost:123,requiresPost:'min_just'};
    const before=JSON.stringify(order);
    assert.equal(translate(order,engine,lang),words[lang].translation.orders[fn]);
    assert.equal(JSON.stringify(order),before,'ne jamais modifier le contrat d’ordre');
    assert.equal(translate({...order,label:'Autre prestation'},engine,lang),'Autre prestation',
      'ne jamais traduire un sens différent');
    count+=3;
  }
}
assert.match(bridge,/RP_I18N_GAME_ENABLED\s*!==\s*true/,'plateau reste fermé');
assert.match(init,/RP_I18N_GAME_ENABLED\s*===\s*true/,'activation explicite seulement');
console.log('OK: '+count+' vérifications, 4 commandes × 9 langues, repli fail-closed, contrats intacts et activation fermée.');
