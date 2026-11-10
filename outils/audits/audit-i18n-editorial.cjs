'use strict';
/* Revue reproductible des catalogues d'interface (aucune donnée joueur).
 * Distingue les problèmes structurels des traductions à relire manuellement.
 * Les guides ont des traductions sans copie française dans le catalogue :
 * le français métier reste dans REGLES, ces extras sont seulement recensés.
 */
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const scripts=[
 'resources.js','plateau-resources.js','guide-resources.js',
 'guide-plateau-resources.js','guide-interactions-resources.js',
 'guide-politique-resources.js','guide-sport-resources.js',
 'guide-economie-resources.js','guide-religion-resources.js',
 'orders-resources.js','order-variants-resources.js',
 'order-templates-resources.js',
 'room-resources.js','forum-ui.js',
 'guard-welcome-resources.js','jeremy-scenes-resources.js',
 'petit-accueil-resources.js','pnj-status-resources.js',
 'toast-resources.js','character-sheet-resources.js','inventory-ui-resources.js','material-trade-resources.js','administration-economy-resources.js','commerce-management-resources.js','commerce-production-resources.js','economic-catalog-resources.js','product-sheet-resources.js','connection-resources.js',
 'municipal-ui-resources.js','social-pnj-resources.js','room-actions-resources.js','navigation-resources.js',
 'sport-bets-resources.js','commerce-menu-resources.js'
];
const global={};
const context=vm.createContext({window:global});
for(const name of scripts){
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',name),'utf8'),context,{filename:name});
}
function flatten(node,prefix='',out={}){
 if(typeof node==='string'){out[prefix]=node;return out;}
 if(node&&typeof node==='object'){
  for(const [name,value] of Object.entries(node))
   flatten(value,prefix?prefix+'.'+name:name,out);
 }
 return out;
}
function placeholders(str){
 return [...str.matchAll(/\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}/g)]
  .map(match=>match[1]).sort().join(',');
}
const languages=Object.keys(global.RP_I18N_LANGUAGES||{});
const reference=flatten(global.RP_I18N_RESOURCES?.fr?.translation||{});
const entries=Object.entries(reference);
const results={};
for(const locale of languages){
 const translated=flatten(global.RP_I18N_RESOURCES?.[locale]?.translation||{});
 const missing=[],placeholderMismatch=[],unchanged=[],currencyReview=[],extra=[];
 for(const [key,original] of entries){
  const value=translated[key];
  if(typeof value!=='string'||!value.trim()){missing.push(key);continue;}
  if(placeholders(value)!==placeholders(original))placeholderMismatch.push(key);
  if(locale!=='fr'&&value===original)unchanged.push(key);
  for(const currency of ['FR','PSK']){
   if(new RegExp('\\b'+currency+'\\b').test(original)&&
     !new RegExp('\\b'+currency+'\\b').test(value))
    currencyReview.push({key,currency});
  }
 }
 for(const key of Object.keys(translated))
  if(!Object.hasOwn(reference,key))extra.push(key);
 results[locale]={keys:Object.keys(translated).length,missing,placeholderMismatch,
  unchanged,currencyReview,extra};
}
const report={description:'Analyse de présentation, pas validation linguistique ni recette utilisateur',
 sourceFiles:scripts,referenceKeys:entries.length,languages,results};
if(require.main===module){
 process.stdout.write(JSON.stringify(report,null,2)+'\n');
 if(languages.length!==9||Object.values(results).some(x=>x.missing.length||x.placeholderMismatch.length))
  process.exitCode=1;
}
module.exports=report;
