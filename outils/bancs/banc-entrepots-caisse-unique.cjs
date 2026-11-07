// Sources exécutables du cron : les commentaires historiques ne sont pas des écritures.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const acorn=require('../e2e/node_modules/acorn');
const lire=f=>fs.readFileSync(new URL('../../'+f,`file://${__filename}`),'utf8');
function anciensChamps(src){
 const ast=acorn.parse(src,{ecmaVersion:'latest',sourceType:'module'}),trouves=[];
 function visit(n){
  if(!n||typeof n!=='object')return;
  if(n.type==='VariableDeclarator'&&/^(entrepot|entrepotCible)$/.test(n.id?.name||'')){
   const scan=x=>{if(!x||typeof x!=='object')return;if(x.type==='Property'&&(x.key?.name||x.key?.value)==='caisse')trouves.push(x.start);for(const v of Object.values(x))if(v&&typeof v==='object')Array.isArray(v)?v.forEach(scan):scan(v);};scan(n.init);
  }
  if(n.type==='MemberExpression'&&(n.property?.name||n.property?.value)==='caisse'&&/entrepot/i.test(src.slice(n.object.start,n.object.end)))trouves.push(n.start);
  for(const v of Object.values(n))if(v&&typeof v==='object')Array.isArray(v)?v.forEach(visit):visit(v);
 }visit(ast);return trouves;
}
test('le cron ne crée ni ne lit une seconde bourse d’entrepôt',()=>assert.deepEqual(anciensChamps(lire('api/cron-minuit.js')),[]));
test('contre-épreuves : dotation et ancien solde détectés, commentaire ignoré',()=>{
 assert.equal(anciensChamps('const entrepotCible=x.entrepot||{stock:{},caisse:8500};').length,1);
 assert.equal(anciensChamps('const n=etat.entrepot.caisse;').length,1);
 assert.deepEqual(anciensChamps('// etat.entrepot.caisse = 8500\nconst entrepotCible=x.entrepot||{stock:{}};'),[]);
});
test('livraisons, travaux et exportations réutilisent les portes de caisse canoniques',()=>{
 const s=lire('api/cron-minuit.js');assert.match(s,/sbRpc\('entrepot_caisse_lire'/);assert.ok((s.match(/sbRpc\('entrepot_caisse_mouvement'/g)||[]).length>=3);
 const e=lire('plateau-entrepots.js');assert.match(e,/sbGetCaisseBatiment\(state.country \+ '_entrepot_' \+ state.poste.city\)/);
});
