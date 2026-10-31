'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'..','..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
function extract(src, name) {
  const start=src.indexOf('function '+name+'(');
  assert.ok(start>=0,'fonction '+name+' introuvable');
  const open=src.indexOf('{',start);
  let depth=0;
  for(let i=open;i<src.length;i++){
    if(src[i]==='{')depth++;
    if(src[i]==='}' && --depth===0)return src.slice(start,i+1);
  }
  throw Error('bloc incomplet');
}
test('caisse affichée arrondie au supérieur sans modifier la valeur serveur',()=>{
  const s=read('plateau-politique.js');
  const fn=extract(s,'afficherCaisseAccueilCommunal');
  assert.match(fn,/Math\.ceil\(Number\(reponse\.solde\)\)/);
  assert.match(fn,/maximumFractionDigits: 0/);
  assert.match(fn,/sbGetCaisseBatiment/);
  assert.doesNotMatch(fn,/sbSave|update\(|upsert|rpc.*mouvement/i);
});
test('contexte PNJ neutre pour personnage ancien ou genre absent',()=>{
  const s=read('api/_pnj-profils.js');
  const fn=Function(extract(s,'blocContextePublic')+';return blocContextePublic;')();
  const x=fn({nom:'Arnie',fonctions:['ministre de la Défense']});
  assert.match(x,/Cette personne exerce officiellement/);
  assert.doesNotMatch(x,/Elle exerce officiellement/);
  assert.match(x,/Sans genre explicitement verifie/);
  assert.match(x,/evite Monsieur\/Madame/);
  assert.doesNotMatch(fn({nom:'Arnie',fonctions:[]}),/Elle n'exerce/);
});
test('lisibilité des conversations et rafraîchissement du cache',()=>{
  const css=read('style.css'),plateau=read('plateau.html'),index=read('index.html');
  assert.match(css,/#modal-pnj \.pnj-action-btn/);
  assert.match(css,/#modal-pnj \.pnj-speech/);
  assert.match(css,/body\.plateau-body \.person-role/);
  assert.match(plateau,/style\.css\?v=lisibilite-pnj-20261031/);
  assert.match(index,/style\.css\?v=lisibilite-pnj-20261031/);
  assert.match(plateau,/plateau-politique\.js\?v=caisses-entieres-20261031/);
});
