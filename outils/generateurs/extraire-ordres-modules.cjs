'use strict';
// Analyse des déclarations, sans exécuter les écrans ni leurs effets.
const fs=require('node:fs'),path=require('node:path');
const acorn=require('../e2e/node_modules/acorn');
function extraire(source,fichier='<fixture>'){
 const ast=acorn.parse(source,{ecmaVersion:'latest',sourceType:'module',locations:true}),constantes=new Map(),litteraux=[],dynamiques=[];
 function valeur(n,scope=constantes){
  if(!n)return undefined;
  if(n.type==='Literal')return n.value;
  if(n.type==='Identifier')return scope.get(n.name);
  if(n.type==='UnaryExpression'&&n.operator==='-'&&typeof valeur(n.argument,scope)==='number')return -valeur(n.argument,scope);
 }
 for(const n of ast.body)if(n.type==='VariableDeclaration'&&n.kind==='const')for(const d of n.declarations)if(d.id.type==='Identifier'&&d.init&&['Literal','Identifier','UnaryExpression'].includes(d.init.type))constantes.set(d.id.name,valeur(d.init));
 function walk(n,parent,scope=constantes){
  if(!n||typeof n!=='object')return;
  if(['FunctionDeclaration','FunctionExpression','ArrowFunctionExpression','BlockStatement'].includes(n.type))scope=new Map(scope);
  if(n.params)for(const param of n.params)if(param.type==='Identifier')scope.set(param.name,undefined);
  if(n.type==='VariableDeclaration'&&n.kind==='const')for(const d of n.declarations)if(d.id.type==='Identifier')scope.set(d.id.name,valeur(d.init,scope));
  if(n.type==='CallExpression'&&n.callee?.name==='acheterObjetServeur'){
   const fn=valeur(n.arguments[0],scope),pa=valeur(n.arguments[2],scope),cost=valeur(n.arguments[3],scope);
   if(typeof fn==='string'&&Number.isSafeInteger(pa)&&Number.isSafeInteger(cost))litteraux.push({fn,pa,cost,fichier,ligne:n.loc.start.line});
  }
  if(n.type==='ObjectExpression'){
   const props=new Map(n.properties.filter(p=>p.type==='Property'&&!p.computed).map(p=>[p.key.name??p.key.value,p.value]));
   const fn=valeur(props.get('fn'),scope),paiement=parent?.type==='CallExpression'&&parent.callee?.name==='deduireCoutOrdre';
   if(typeof fn==='string'&&/^[a-z0-9_#]+$/.test(fn)&&(props.has('label')||paiement)){
    const pa=props.has('pa')?valeur(props.get('pa'),scope):0,cost=props.has('cost')?valeur(props.get('cost'),scope):0;
    const objet={fn,fichier,ligne:n.loc.start.line};
    if(n.properties.some(p=>p.type==='SpreadElement')||!Number.isSafeInteger(pa)||!Number.isSafeInteger(cost))dynamiques.push({...objet,raison:'Coût non littéral : aucun zéro fabriqué'});
    else litteraux.push({...objet,pa,cost});
   }
  }
  for(const [k,v] of Object.entries(n)){if(['loc','start','end'].includes(k))continue;if(Array.isArray(v))for(const x of v)walk(x,n,scope);else if(v&&typeof v==='object')walk(v,n,scope);}
 }
 walk(ast,null);return {litteraux,dynamiques};
}
if(require.main===module){
 const root=path.resolve(__dirname,'../..'),sortie={litteraux:[],dynamiques:[]};
 for(const f of fs.readdirSync(root).sort())if(f.endsWith('.js')&&fs.statSync(path.join(root,f)).isFile()){
  const r=extraire(fs.readFileSync(path.join(root,f),'utf8'),f);sortie.litteraux.push(...r.litteraux);sortie.dynamiques.push(...r.dynamiques);
 }
 process.stdout.write(JSON.stringify(sortie));
}
module.exports={extraire};
