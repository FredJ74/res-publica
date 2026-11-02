// Reproduit les défauts du main audité, sans modifier le worktree ni le jeu.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process'),acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),reference=process.argv[2]||'a99c406928ec7449f7dc11f5a447177c59b5452b';
if(!/^[a-f0-9]{40}$/.test(reference))throw Error('SHA Git complet attendu');
const lire=f=>execFileSync('git',['show',reference+':'+f],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
const data=lire('data.js'),variants=lire('plateau-variantes-pieces.js'),politique=lire('plateau-politique.js');
const c=vm.createContext({state:{country:'republic',currentCity:'ville_a'}});vm.runInContext(data+'\n'+variants,c);
const cas=[];
for(const piece of ['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve']){
 c.piece=piece;vm.runInContext("PIECE_FAMILLES_ETAT.location.etat=()=> 'libre'",c);
 const image=vm.runInContext("varianteImagePiece('centre-commercial',piece,'ville_a')",c);
 assert.throws(()=>assert.match(image,/^images\/port-sainte-marie-/),'le défaut ancien doit rougir');
 cas.push({cas:'image_libre_'+piece,defaut_reproduit:true});
}
const ns=acorn.parse(politique,{ecmaVersion:'latest'}).body.filter(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='ACTIONS_POSTE_NOMME')||n.type==='FunctionDeclaration'&&n.id.name==='coutActionPosteNomme');
vm.runInContext(ns.map(n=>politique.slice(n.start,n.end)).join('\n'),c);
for(const poste of ['directeur_pharma','directeur_tabac_alcools','directeur_raffinerie'])for(const [action,pa]of [['nommer',3],['revoquer',1]]){
 c.poste=poste;c.action=action;c.pa=pa;
 const r=JSON.parse(vm.runInContext('JSON.stringify(coutActionPosteNomme(poste,action,pa,0))',c));
 assert.throws(()=>assert.deepEqual(r,{fn:action+'_'+poste,pa,cost:0}),'la perte du nom d’ordre doit rougir');
 cas.push({cas:action+'_'+poste,defaut_reproduit:true});
}
console.log(JSON.stringify({reference,production:false,defauts_reproduits:cas.length,cas},null,2));
