/* Orchestration interne de traductions, non exposée par HTTP.
 * Le lecteur est identifié et la lecture RLS doit précéder TOUT accès au cache.
 * Le quota atomique persistant est requis, y compris pour des traitements simultanés.
 */
import { createHash } from 'node:crypto';
import { validerSource } from './_traduction-sources.js';
import { traduireTexte, langueAdmise, placeholders, invariantsIdentiques, caracteresControles } from './_traduction.js';

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
 if(!source || !langueAdmise(langueCible))return refuse('requete_invalide');
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
 if(!original.trim() || original.length>1800 || /[\u0000-\u0008\u000E-\u001F]/.test(original))
  return refuse('texte_invalide');
 // Les trois tables sociales en production n'ont pas de colonne « version ».
 // Un hash de l'original LU SOUS RLS suffit à invalider le cache sur édition.
 // Toute version explicite fournie par une source de confiance reste acceptée.
 const fingerprint=createHash('sha256').update(original,'utf8').digest('hex');
 const version=record.version==null?'sha256:'+fingerprint:record.version;
 if(typeof version!=='string'||!version||version.length>128)return refuse('version_invalide');
 // 'und' signifie source inconnue : les messages PJ n'ont actuellement
 // aucune colonne langue en base. Ne pas présumer du français.
 if(!langueAdmise(record.language) && record.language!=='und')return refuse('langue_source_invalide');
 if(record.language===langueCible) return Object.freeze({ok:true,original,traduit:original,fromCache:true});
 // Cache partagé entre lecteurs AUTORISÉS : le droit de lecture RLS est
 // recontrôlé avant CHAQUE accès au cache. L'UID reste attaché à la réservation
 // de quota, pas à la traduction réutilisable d'un même contenu.
 const key=JSON.stringify([type,source.id,field,version,fingerprint,record.language,langueCible]);
 // Même un résultat déjà en cache a été précédé de la lecture autorisée sous RLS.
 let cached;
 // Une panne de cache n'est PAS une absence de traduction : ne pas engager
 // de nouvelles dépenses fournisseur dans un état serveur incertain.
 try { cached=await deps.readCache(key); } catch { return refuse('cache_indisponible'); }
 const sameTokens=(left,right)=>JSON.stringify(placeholders(left))===JSON.stringify(placeholders(right));
 if(typeof cached==='string' && cached.trim() && cached.length<=4000 &&
    !caracteresControles(cached) && sameTokens(original,cached) && invariantsIdentiques(original,cached))
  return Object.freeze({ok:true,original,traduit:cached,fromCache:true});
 // Quota persistant et atomique vérifié avant tout appel payant.
 let permit;
 try { permit=await deps.reserveBudget(auth.userId,key,original.length); } catch { return refuse('quota_indisponible'); }
 if(permit!==true)return refuse('quota_atteint');
 const response=await traduireTexte({texte:original,langueOriginale:record.language,langueCible},deps.provider);
 if(!response.ok)return Object.freeze({...response,fromCache:false});
 try { await deps.writeCache(key,response.traduit); } catch { /* livraison possible sans cache */ }
 return Object.freeze({...response,fromCache:false});
}
export { traduireContenu };
