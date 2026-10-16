// node outils/auditer-ressources.mjs
// Mesures locales des vrais calculs, sans redefinition de prix ni de reference.
import fs from 'node:fs';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {getPrixRessource as prixJournal} from '../api/_journal-collecte.js';
import {RESSOURCES_ECONOMIE_SERVEUR} from '../api/_referentiels-generes.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const lire=p=>fs.readFileSync(path.join(root,p),'utf8');
const ctx=vm.createContext({});vm.runInContext(lire('data.js'),ctx);
const canon=vm.runInContext('RESSOURCES_ECONOMIE',ctx);
const declaration=JSON.parse(lire('outils/baseline/fonctions.json'));
const decor=declaration.decor_des_grilles;
const a=decor.indexOf('var PRIX ='),b=decor.indexOf('var MEMBRES =',a);
if(a<0||b<a)throw Error('Grille PRIX a reexaminer');
vm.runInContext(decor.slice(a,b),ctx);
const cas=vm.runInContext('PRIX',ctx);
const divergences=cas.filter(([cle,qte])=>{
 ctx.cle=cle;ctx.qte=qte;
 return vm.runInContext('getPrixRessource(cle,qte)',ctx)!==prixJournal(cle,qte);
});
const attendu=declaration.copies.find(c=>c.cle==='economie/prix-ressource-journal').cas_divergents_attendus;
const config=JSON.parse(lire('outils/generateurs/referentiels-serveur.json'));
const entries=Array.isArray(config)?config:Object.values(config).find(Array.isArray);
const ordre=entries.find(e=>e.serveur==='RESSOURCES_ECONOMIE_SERVEUR').ordre_des_cles;
const reel=Object.keys(RESSOURCES_ECONOMIE_SERVEUR);
console.log(JSON.stringify({
 nature:'Audit local uniquement ; aucune mesure de Supabase et aucun tarif modifie.',
 grille:{cas:cas.length,divergences:divergences.length,referenceDeclaree:attendu,
  divergencesHorsLaitages:divergences.filter(c=>c[0]!=='laitages').length,
  casLaitages:divergences.filter(c=>c[0]==='laitages')},
 ressources:{canon:Object.keys(canon),ordreGenerateur:ordre,ordreArtefact:reel,
  absentesDeLOrdre:Object.keys(canon).filter(k=>!ordre.includes(k)),
  indicesDecales:ordre.map((cle,index)=>({cle,indexDeclare:index,indexArtefact:reel.indexOf(cle)})).filter(r=>r.indexDeclare!==r.indexArtefact)},
 prudence:'Le Journal et le prix fixe des entrepots sont deux usages distincts. Ne pas aligner leurs tarifs sans contrat editorial valide.'
},null,2));
