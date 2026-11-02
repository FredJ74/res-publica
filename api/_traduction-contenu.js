/* Orchestration interne de traductions, non exposée par HTTP.
 * Le lecteur est identifié et la lecture RLS doit précéder TOUT accès au cache.
 * Le quota atomique persistant est requis, y compris pour des traitements simultanés.
 */
import { validerSource } from './_traduction-sources.js';
import { traduireTexte } from './_traduction.js';

function refuse(raison='indisponible') {
 return Object.freeze({ok:false,raison,original:null,traduit:null});
}
function validateDependencies(deps) {
 return ['authenticate','readUnderRls','reserveBudget','readCache','writeCache','provider']
  .every(name=>typeof deps?.[name]==='function');
}
async function traduireContenu({type,id,field,langueCible},deps) {
 if(!validateDependencies(deps))return refuse('non_configure');
 const source=validerSource(type,id,field);
 if(!source || typeof langueCible!=='string')return refuse('requete_invalide');
 let auth;
 try { auth=await deps.authenticate(); } catch { return refuse(); }
 if(!auth?.userId || !auth?.readerToken)return refuse();
 // Le service doit lire par la connexion utilisateur sous RLS, jamais en service_role.
 let record;
 try { record=await deps.readUnderRls(source,auth.readerToken); }
 catch { return refuse(); }
 if(!record || typeof record.text!=='string' || typeof record.language!=='string')
  return refuse(); // aucune distinction entre absent et interdit
 const original=record.text;
 // La dépense ne doit pas être engagée sur du texte vide, illisible ou déjà localisé.
 if(!original.trim() || original.length>1800)return refuse('texte_invalide');
 if(typeof record.version!=='string' || !record.version || record.version.length>128)return refuse('version_absente');
 if(record.language===langueCible) return Object.freeze({ok:true,original,traduit:original,fromCache:true});
 const key=JSON.stringify([auth.userId,type,source.id,field,record.version,record.language,langueCible]);
 // Même un résultat déjà en cache a été précédé de la lecture autorisée sous RLS.
 let cached;
 try { cached=await deps.readCache(key); } catch { cached=null; }
 if(typeof cached==='string')return Object.freeze({ok:true,original,traduit:cached,fromCache:true});
 // Quota persistant et atomique vérifié avant tout appel payant.
 let permit;
 try { permit=await deps.reserveBudget(auth.userId,key); } catch { return refuse('quota_indisponible'); }
 if(permit!==true)return refuse('quota_atteint');
 const response=await traduireTexte({texte:original,langueOriginale:record.language,langueCible},deps.provider);
 if(!response.ok)return Object.freeze({...response,fromCache:false});
 try { await deps.writeCache(key,response.traduit); } catch { /* livraison possible sans cache */ }
 return Object.freeze({...response,fromCache:false});
}
export { traduireContenu };
