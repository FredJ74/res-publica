// Complément reproductible de l'audit visuel : profils serveur et graphe déclaratif.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {pathToFileURL}=require('node:url');
const acorn=require('../vercel/node_modules/acorn'),{analyser}=require('./auditer-republia-complet.cjs');
const ROOT=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(ROOT,f),'utf8');
function parcourir(n,f){if(!n||typeof n!=='object')return;f(n);for(const [k,v]of Object.entries(n))if(k!=='start'&&k!=='end'){if(Array.isArray(v))v.forEach(x=>parcourir(x,f));else if(v&&typeof v==='object')parcourir(v,f);}}
async function analyserRaccordements(){
 const a=analyser(),{profilExiste}=await import(pathToFileURL(path.join(ROOT,'api/_pnj-profils.js')));
 const s=lire('plateau-pnj.js'),ast=acorn.parse(s,{ecmaVersion:'latest'});
 const morceaux=ast.body.filter(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='PNJ_PROFILS_SERVEUR')||n.type==='FunctionDeclaration'&&['slugPnj','profilServeurDuPnj'].includes(n.id.name));
 const c=vm.createContext({});vm.runInContext(morceaux.map(n=>s.slice(n.start,n.end)).join('\n'),c);
 const banque=lire('outils/bancs/banc-dialogue-pnj-republia.js');const declarationMuets=acorn.parse(banque,{ecmaVersion:'latest'}).body.find(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='MUETS_DECLARES'));
 vm.runInContext(banque.slice(declarationMuets.start,declarationMuets.end),c);
 const profils=a.pnj.map(p=>{c.p=p;const id=vm.runInContext('profilServeurDuPnj(p)',c);return {ville:p.ville,batiment:p.batiment,piece:p.piece,nom:p.name,id,agence:p.job==='escort_agence',existe:profilExiste(id),silenceDeclare:vm.runInContext('MUETS_DECLARES',c)[id]||null};});
 const rues=a.rues,zones=[],liensInvalides=[];
 for(const [id,r]of Object.entries(rues)){
  for(const z of [...r.zones||[],...Object.values(r.zonesParArrivee||{}).flat()])if(z.buildingId)zones.push({rue:id,batiment:z.buildingId});
  for(const [etat,liens]of [['base',r.liens],...Object.entries(r.liensParArrivee||{})])for(const [direction,n]of Object.entries(liens||{}))if(typeof n==='string'&&!rues[n])liensInvalides.push({rue:id,etat,direction,destination:n});
 }
 const sansZone=a.villes.flatMap(v=>{
  const prefixe={capitale:'luthecia-',ville_a:'psm-',ville_b:'montrouge-'}[v.id],visibles=new Set(zones.filter(z=>z.rue.startsWith(prefixe)).map(z=>z.batiment));
  return v.batiments.filter(b=>!visibles.has(b.id)).map(b=>({ville:v.id,batiment:b.id,viaSelecteurTerrains:v.id==='ville_b'&&b.id.startsWith('terrain-a-batir')}));
 });
 const src=lire('plateau-router.js'),routeAst=acorn.parse(src,{ecmaVersion:'latest'}),litteraux=new Set(),expressions=[];
 parcourir(routeAst,n=>{if(n.type==='BinaryExpression'&&['===','=='].includes(n.operator)&&n.left.type==='Identifier'&&n.left.name==='fn'&&typeof n.right.value==='string')litteraux.add(n.right.value);
  if(n.type==='CallExpression'&&n.callee.type==='MemberExpression'&&n.callee.property.name==='test'&&n.callee.object.regex&&n.arguments[0]?.name==='fn')expressions.push(new RegExp(n.callee.object.regex.pattern,n.callee.object.regex.flags));});
 const generiques=new Set([...lire('baseline/seeds/90_socle/ordres_generiques.sql').matchAll(/VALUES \('([^']+)'/g)].map(x=>x[1]));
 const routes=[...new Set(a.ordres.map(o=>o.fn))].sort().map(fn=>({fn,chemin:litteraux.has(fn)?'routeur_litteral':expressions.some(r=>r.test(fn))?'routeur_expression_reguliere':fn==='postuler'?'rendu_direct_ouvrirEcranPostes':generiques.has(fn)?'generique_seed_a_confirmer_vivant':a.ordres.filter(o=>o.fn===fn).every(o=>o.bientot)?'volontairement_grise':'non_identifie'}));
 const declares=new Set(),appels=new Set(),erreursAnalyse=[];
 const fichiers=[...new Set([...lire('plateau.html').matchAll(/<script[^>]+src="([^"?]+)/g)].map(x=>x[1]).filter(x=>!/^https?:/.test(x)))];
 for(const f of fichiers){if(!fs.existsSync(path.join(ROOT,f))){erreursAnalyse.push({fichier:f,erreur:'script_absent'});continue;}
  try{parcourir(acorn.parse(lire(f),{ecmaVersion:'latest',sourceType:'module'}),n=>{
   if(n.type==='FunctionDeclaration'&&n.id)declares.add(n.id.name);
   if(n.type==='VariableDeclarator'&&n.id.type==='Identifier')declares.add(n.id.name);
   if(f==='plateau-router.js'&&n.type==='CallExpression'&&n.callee.type==='Identifier')appels.add(n.callee.name);
  });}catch(e){erreursAnalyse.push({fichier:f,erreur:e.message});}}
 const appelsSansDeclaration=[...appels].filter(n=>!declares.has(n)&&!['Number','String','Boolean','parseInt','parseFloat','setTimeout','setInterval','clearTimeout','clearInterval','fetch'].includes(n));
 return {limite:'Analyse de déclarations et code chargé, pas une preuve de droits/RLS ni d’exécution métier en production.',profils,graphe:{noeuds:Object.keys(rues).length,liensInvalides,sansZone,carrefourPSM:rues['psm-carrefour-musee']},routes,routeur:{appelsDistincts:appels.size,appelsSansDeclaration,erreursAnalyse}};
}
if(require.main===module)analyserRaccordements().then(v=>{if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(v,null,2)+'\n');console.log(JSON.stringify({profilsManquants:v.profils.filter(p=>!p.existe&&!p.agence&&!p.silenceDeclare),graphe:v.graphe.sansZone,routesManquantes:v.routes.filter(r=>r.chemin==='non_identifie'),routeur:v.routeur},null,2));}).catch(e=>{console.error(e);process.exitCode=1;});
module.exports={analyserRaccordements};
