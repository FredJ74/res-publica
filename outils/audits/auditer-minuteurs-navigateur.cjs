// Inventaire syntaxique, pas preuve d'absence de reseau dans un appel indirect.
const fs=require('node:fs'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const racine=process.argv[2]||path.resolve(__dirname,'../..'),minuteurs=[];
for(const nom of fs.readdirSync(racine).filter(n=>/\.(m?js)$/.test(n))){
 const texte=fs.readFileSync(path.join(racine,nom),'utf8');
 let arbre;try{arbre=acorn.parse(texte,{ecmaVersion:'latest',sourceType:'script',locations:true});}catch(_){arbre=acorn.parse(texte,{ecmaVersion:'latest',sourceType:'module',locations:true});}
 function visiter(n,fonction='initialisation'){
  if(!n||typeof n!=='object')return;
  if(n.type==='FunctionDeclaration')fonction=n.id.name;
  if(n.type==='CallExpression'&&['setInterval','setTimeout'].includes(n.callee?.name))minuteurs.push({fichier:nom,fonction,ligne:n.loc.start.line,type:n.callee.name,delai:texte.slice(n.arguments[1]?.start||n.end,n.arguments[1]?.end||n.end)});
  for(const v of Object.values(n))if(Array.isArray(v))v.forEach(x=>visiter(x,fonction));else if(v&&typeof v==='object')visiter(v,fonction);
 }
 visiter(arbre);
}
process.stdout.write(JSON.stringify({portee:'Fichiers navigateur JS/MJS a la racine ; bibliotheques tierces exclues',intervalles:minuteurs.filter(m=>m.type==='setInterval'),delais_uniques_ou_sequences:minuteurs.filter(m=>m.type==='setTimeout')},null,2)+'\n');
