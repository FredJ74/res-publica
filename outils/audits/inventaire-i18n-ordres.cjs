'use strict';
/* Inventaire non autoritaire des libellés d'ordres visibles.
 * Un identifiant fn peut avoir plusieurs libellés légitimes selon état/ville ;
 * ne jamais déduire d'ici la règle métier ni une traduction par défaut unique.
 */
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'../..');
const files=fs.readdirSync(root).filter(n=>n==='data.js'||/^plateau-.*\.js$/.test(n));
const result=new Map();
for(const name of files) {
 const text=fs.readFileSync(path.join(root,name),'utf8');
 for(const match of text.matchAll(/\bfn\s*:\s*(['"])([^'"\n]+)\1\s*,\s*label\s*:\s*(['"])([^'"\n]+)\3/g)) {
  const fn=match[2],label=match[4];
  const map=result.get(fn)||new Map();map.set(label,(map.get(label)||0)+1);result.set(fn,map);
 }
 for(const match of text.matchAll(/\blabel\s*:\s*(['"])([^'"\n]+)\1\s*,\s*fn\s*:\s*(['"])([^'"\n]+)\3/g)) {
  const label=match[2],fn=match[4];const map=result.get(fn)||new Map();
  map.set(label,(map.get(label)||0)+1);result.set(fn,map);
 }
}
const entries=[...result.entries()].sort((a,b)=>a[0].localeCompare(b[0])).map(([fn,labels])=>({
 fn,labels:[...labels.keys()].sort(),ambiguous:labels.size>1
}));
const report={filesInspected:files.length,uniqueIds:entries.length,
 ambiguousIds:entries.filter(x=>x.ambiguous).length,entries};
if(require.main===module) console.log(JSON.stringify(report,null,2));
module.exports=report;
