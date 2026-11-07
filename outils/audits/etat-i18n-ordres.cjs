'use strict';
/* Mesure reproductible de couverture des ordres, sans exécuter d'ordre ni de RPC.
 * Seuls les libellés littéraux trouvés par l'inventaire existant sont comptés.
 * Les libellés construits dynamiquement restent hors mesure et donc NON certifiés.
 */
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const source=require('./inventaire-i18n-ordres.cjs');
const win={};
const context=vm.createContext({window:win});
for(const name of ['resources.js','orders-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',name),'utf8'),context);
const languages=Object.keys(win.RP_I18N_LANGUAGES||{});
const catalog=Object.fromEntries(languages.map(language=>[
 language,win.RP_I18N_RESOURCES[language]?.translation?.orders||{}
]));
const french=catalog.fr||{};
const existing=new Map(source.entries.map(entry=>[entry.fn,entry]));
const covered=[],partiallyCovered=[],missingStable=[],ambiguousWithoutCoverage=[],obsolete=[];
for(const [fn,label] of Object.entries(french)){
 const record=existing.get(fn);
 if(!record || !record.labels.includes(label))obsolete.push({fn,label});
 else if(record.ambiguous)partiallyCovered.push({fn,sourceLabels:record.labels});
 else covered.push(fn);
}
for(const entry of source.entries){
 if(entry.ambiguous){
  if(!Object.hasOwn(french,entry.fn))ambiguousWithoutCoverage.push({fn:entry.fn,labels:entry.labels});
 }else if(!Object.hasOwn(french,entry.fn))missingStable.push({fn:entry.fn,label:entry.labels[0]});
}
const perLocale=Object.fromEntries(languages.map(language=>{
 const words=catalog[language];
 const missing=Object.keys(french).filter(fn=>typeof words[fn]!=='string'||!words[fn].trim());
 const extra=Object.keys(words).filter(fn=>!Object.hasOwn(french,fn));
 return [language,{keys:Object.keys(words).length,missing,extra}];
}));
const report={
 description:'Inventaire statique, pas une certification de toutes les commandes dynamiques',
 sourceFiles:source.filesInspected,
 sourceUniqueIds:source.uniqueIds,
 sourceAmbiguousIds:source.ambiguousIds,
 locales:languages,
 catalogueFrenchKeys:Object.keys(french).length,
 canonicalMatches:covered.length+partiallyCovered.length,
 stableCovered:covered.length,
 ambiguousPartiallyCovered:partiallyCovered.length,
 stableNotCovered:missingStable.length,
 ambiguousNotCovered:ambiguousWithoutCoverage.length,
 obsoleteCanonical:obsolete,
 perLocale,
 missingStable,
 ambiguousPartiallyCoveredDetails:partiallyCovered,
 ambiguousNotCoveredDetails:ambiguousWithoutCoverage
};
if(require.main===module){
 process.stdout.write(JSON.stringify(report,null,2)+'\n');
 const bad=languages.length!==9||obsolete.length>0||
  Object.values(perLocale).some(x=>x.missing.length||x.extra.length);
 if(bad)process.exitCode=1;
}
module.exports=report;
