/* Adaptateur INTERNE du stockage de traduction, sans route HTTP.
 * PRÉREQUIS NON APPLIQUÉ : outils/livraison/I18N-STOCKAGE-PRIVE-BROUILLON-NON-APPLIQUER.sql
 * Aucune dépense possible avant activation explicite du budget SQL.
 */
import { createHash } from 'node:crypto';
import { sbRpcVerdict, identiteServeurDisponible } from './_supabase.js';

function cleCourte(key) {
 if(typeof key!=='string' || !key || key.length>2048)return null;
 return createHash('sha256').update(key,'utf8').digest('hex');
}
function creerStockageTraductions(rpc=sbRpcVerdict,serviceAvailable=identiteServeurDisponible) {
 function verifierService(){
  if(typeof rpc!=='function'||typeof serviceAvailable!=='function'||
      serviceAvailable()!==true)throw new Error('stockage_i18n_non_configure');
 }
 async function appeler(name,body) {
  verifierService();
  const answer=await rpc(name,body,{service:true});
  if(!answer?.ok)throw new Error('stockage_i18n_indisponible');
  return answer.donnees;
 }
 return Object.freeze({
  async readCache(key){
   const hash=cleCourte(key);
   if(!hash)throw new Error('cle_i18n_invalide');
   const value=await appeler('rp_i18n_cache_lire',{p_cache_key:hash});
   if(value===null)return null;
   if(typeof value!=='string')throw new Error('cache_i18n_invalide');
   return value;
  },
  async reserveBudget(uid,key,characters){
   const hash=cleCourte(key);
   if(typeof uid!=='string' || !/^[0-9a-f-]{36}$/i.test(uid) ||
      !hash || !Number.isInteger(characters)||characters<1||characters>1800)
    return false;
   const value=await appeler('rp_i18n_budget_reserver',{
    p_uid:uid,p_cache_key:hash,p_characters:characters
   });
   if(value!==true && value!==false)throw new Error('quota_i18n_invalide');
   return value;
  },
  async writeCache(key,text){
   const hash=cleCourte(key);
   if(!hash || typeof text!=='string'||!text.trim()||text.length>4000)
    throw new Error('contenu_i18n_invalide');
   const value=await appeler('rp_i18n_cache_ecrire',{
    p_cache_key:hash,p_text:text
   });
   if(value!==true)throw new Error('cache_i18n_ecriture_echouee');
  }
 });
}
export { creerStockageTraductions, cleCourte };
