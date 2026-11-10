'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const code=fs.readFileSync(path.join(__dirname,'../../plateau-actions-illegales-rumeurs.js'),'utf8');
test('la carte définit la devise locale avant le rendu du prix et ne dépend pas d une globale',()=>{
 const from=code.indexOf('async function doConsulterCarteCommerce('),to=code.indexOf('// Pont UI <->',from);
 assert.ok(from>=0&&to>from);
 const body=code.slice(from,to);
 const declaration=body.indexOf("const monnaie = (typeof COUNTRIES !== 'undefined' && COUNTRIES[pays]?.cur) || 'FR';");
 const usage=body.indexOf("prix.toLocaleString('fr-FR') + ' ' + monnaie");
 assert.ok(declaration>0&&usage>declaration);
 assert.ok(body.includes("const pays = state.country || 'republic';"));
});
