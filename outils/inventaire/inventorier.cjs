#!/usr/bin/env node
// Lecture seule du code. Ne prouve ni les aliases d'inventaire ni l'accessibilite de chaque branche.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),a=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),resultats=[],sources={};
const champs=new Set(['qty','quantite','legal','etat','name','type','tractType','expireDay','documentUrbanisme','bonus','munitions','charges','charge','doses','utilisations','usagesRestants','equipped','equipe','durabilite','usure','dateExpiration']);
const prop=n=>n?.type==='MemberExpression'?(n.computed?(n.property.type==='Literal'?n.property.value:null):n.property.name):null;
for(const file of fs.readdirSync(root).filter(f=>/^plateau-.*\.js$/.test(f)).sort()){
 const s=fs.readFileSync(path.join(root,file),'utf8');sources[file]=crypto.createHash('sha256').update(s).digest('hex');
 function visit(n,fonction='(global)'){
  if(!n||typeof n!=='object')return;
  if(/Function/.test(n.type))fonction=n.id?.name||fonction+' / callback';
  let type=null;
  if(n.type==='CallExpression'){
   if(n.callee.type==='Identifier'&&['addToInventory','recevoirObjetAutomatique'].includes(n.callee.name))type='ajout_local';
   if(['push','unshift'].includes(prop(n.callee))&&prop(n.callee.object)==='inventory')type='ajout_local';
   if(['splice','pop','shift'].includes(prop(n.callee))&&prop(n.callee.object)==='inventory')type='retrait_ou_remplacement';
  }
  if(['AssignmentExpression','UpdateExpression'].includes(n.type)||(n.type==='UnaryExpression'&&n.operator==='delete')){
   const cible=n.left||n.argument;
   if(prop(cible)==='inventory'||prop(cible?.object)==='inventory')type='retrait_ou_remplacement';
   else if(champs.has(prop(cible))||prop(cible?.object?.object)==='inventory')type='changement_objet_candidat';
  }
  if(type)resultats.push({fichier:file,ligne:n.loc.start.line,fonction,type,extrait:s.slice(n.start,n.end).replace(/\s+/g,' ').slice(0,240)});
  for(const [k,v]of Object.entries(n))if(!['loc','start','end'].includes(k))if(Array.isArray(v))v.forEach(x=>visit(x,fonction));else if(v&&typeof v==='object')visit(v,fonction);
 }
 visit(a.parse(s,{ecmaVersion:'latest',locations:true}));
}
console.log(JSON.stringify({portee:'Analyse statique du code, aucune execution en jeu',verrou_final_prepare:false,verrou_final_applique:false,
 limites:['Les changements_objet_candidat ne prouvent pas un effet sur un objet possede : aliases et appelants restent a examiner.','Les variantes de simulation et les aides generiques ne sont pas automatiquement des circuits actifs.','Aucun changement d objet ni verrou final n est autorise par ce releve.'],sha256_sources:sources,sites:resultats},null,2));
