// Complément AST de auditer-etats-client.py ; aucune connexion ni action de jeu.
'use strict';
const fs=require('node:fs'),path=require('node:path');
const acorn=require(require.resolve('acorn',{paths:[path.join(__dirname,'e2e'),path.join(__dirname,'vercel')]}));
const proteges=new Set(['inventory','arg','liquide','pa','hp','moral','group','employes','currentCity','currentBuilding','currentRoom','currentStreet','estEmprisonne','detentionQHS']);
function analyser(fichiers,html=''){
 const definitions=[],appels=[],mutations=[],sql=[],inconnus=[];
 const propriete=n=>n?.type==='Identifier'?n.name:n?.type==='Literal'?String(n.value):null;
 const membre=n=>n?.type==='Identifier'?n.name:n?.type==='MemberExpression'?(membre(n.object)||'?')+'.'+(n.computed?(n.property.type==='Literal'?String(n.property.value):'*'):propriete(n.property)):null;
 function interfaceTexte(s,f,ligne,owner){for(const m of s.matchAll(/\bon(?:click|change|submit)\s*=\s*["']\s*([\w$]+)\s*\(/g))appels.push({cible:m[1],fichier:f,ligne,source:owner,type:'interface'});}
 interfaceTexte(html,'plateau.html',1,null);
 for(const {nom,texte} of fichiers){
  let ast;try{ast=acorn.parse(texte,{ecmaVersion:'latest',locations:true,sourceType:'script'});}catch(e){ast=acorn.parse(texte,{ecmaVersion:'latest',locations:true,sourceType:'module'});}
  for(const n of ast.body){if(n.type==='FunctionDeclaration')definitions.push({nom:n.id.name,fichier:nom,ligne:n.loc.start.line});}
  function parcourir(n,owner){
   if(!n||typeof n!=='object')return;
   if(n.type==='FunctionDeclaration'&&ast.body.includes(n))owner=n.id.name;
   const ligne=n.loc?.start.line||1;
   if(n.type==='CallExpression'){
    if(n.callee.type==='Identifier'){
     appels.push({cible:n.callee.name,source:owner,fichier:nom,ligne,type:'appel'});
     if((/^sb(?:Rpc|RpcVerdict|TransportRpc|Get|Update|Insert|Delete|Upsert|PatcherBlob)$/.test(n.callee.name)||n.callee.name==='executerReceptionInventaire'))sql.push({fonction:owner,fichier:nom,ligne,transport:n.callee.name,objet:n.arguments[0]?.type==='Literal'?n.arguments[0].value:'<dynamique>'});
    }else if(n.callee.computed)inconnus.push({fonction:owner,fichier:nom,ligne,type:'appel_calculé'});
    const cible=membre(n.callee);
    if(cible?.startsWith('state.')&&/\.(push|splice|pop|shift|unshift)$/.test(cible)&&proteges.has(cible.split('.')[1]))mutations.push({fonction:owner,fichier:nom,ligne,cible,type:'mutation_tableau'});
   }
   if(n.type==='AssignmentExpression'||n.type==='UpdateExpression'){
    const cible=membre(n.left||n.argument);
    if(cible?.startsWith('state.')&&proteges.has(cible.split('.')[1]))mutations.push({fonction:owner,fichier:nom,ligne,cible,type:n.operator});
   }
   if(n.type==='Literal'&&typeof n.value==='string')interfaceTexte(n.value,nom,ligne,owner);
   if(n.type==='TemplateElement')interfaceTexte(n.value.cooked||'',nom,ligne,owner);
   for(const [k,v] of Object.entries(n)){if(k==='loc')continue;if(Array.isArray(v))v.forEach(x=>parcourir(x,owner));else if(v&&typeof v==='object')parcourir(v,owner);}
  }
  parcourir(ast,null);
 }
 const parNom=new Map();for(const d of definitions){const a=parNom.get(d.nom)||[];a.push(d);parNom.set(d.nom,a);}
 const racines=new Map();for(const a of appels)if(!a.source&&parNom.has(a.cible)&&!racines.has(a.cible))racines.set(a.cible,[a]);
 const chemins=new Map(racines),queue=[...racines.keys()];
 for(let i=0;i<queue.length;i++)for(const a of appels)if(a.source===queue[i]&&parNom.has(a.cible)&&!chemins.has(a.cible)){chemins.set(a.cible,[...chemins.get(a.source),a]);queue.push(a.cible);}
 return {nature:'Analyse statique conservatrice des seuls scripts chargés ; pas une preuve de déploiement ni de RLS. Alias, eval, appels calculés et conditions métier exigent une revue.',scripts:fichiers.map(x=>x.nom),doublons:[...parNom].filter(([,v])=>v.length>1).map(([nom,definitions])=>({nom,definitions})),operations:definitions.filter(d=>mutations.some(x=>x.fonction===d.nom&&x.fichier===d.fichier)||sql.some(x=>x.fonction===d.nom&&x.fichier===d.fichier)).map(d=>({...d,exposeGlobal:true,cheminPotentiel:chemins.get(d.nom)||null,appelsEntrants:appels.filter(x=>x.cible===d.nom),mutations:mutations.filter(x=>x.fonction===d.nom&&x.fichier===d.fichier),sql:sql.filter(x=>x.fonction===d.nom&&x.fichier===d.fichier)})),appelsDynamiques:inconnus};
}
function depot(root){const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8'),fichiers=[];for(const m of html.matchAll(/<script[^>]+src="([^"?]+)(?:\?[^" ]*)?"/g)){const f=m[1];if(/^https?:/.test(f))continue;const p=path.resolve(root,f);if(!p.startsWith(path.resolve(root)+path.sep))throw Error('Script hors dépôt');fichiers.push({nom:f,texte:fs.readFileSync(p,'utf8')});}return analyser(fichiers,html);}
module.exports={analyser,depot};
if(require.main===module)process.stdout.write(JSON.stringify(depot(path.resolve(__dirname,'..')),null,2)+'\n');
