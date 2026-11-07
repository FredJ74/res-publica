/* Assemblage serveur INTERNE, sans export HTTP / aucune activation publique.
 * L'authentification est vérifiée par Supabase Auth ; la lecture de chaque
 * message se fait sous LE JWT du lecteur et les politiques RLS.
 * Les seuls accès service_role servent au quota/cache, après lecture RLS.
 */
import { joueurAuthentifie, appelDeepSeek } from './_deepseek.js';
import { lireOriginalSousRls } from './_traduction-lecture-rls.js';
import { creerStockageTraductions } from './_traduction-stockage.js';

function creerDependancesTraduction(req,{
 authentifier=joueurAuthentifie,
 lire=lireOriginalSousRls,
 stockage=creerStockageTraductions(),
 fournisseur=appelDeepSeek
}={}) {
 if(!req||typeof authentifier!=='function'||typeof lire!=='function'||
    typeof fournisseur!=='function'||!stockage||
    !['readCache','reserveBudget','writeCache'].every(k=>typeof stockage[k]==='function'))
  return null;
 return Object.freeze({
  async authenticate(){
   const user=await authentifier(req);
   if(!user?.id || !user?.jeton)return null;
   // Seuls des identifiants obtenus du serveur Auth entrent dans le quota.
   return Object.freeze({userId:user.id,readerToken:user.jeton});
  },
  readUnderRls:(source,token)=>lire(source,token),
  readCache:(key)=>stockage.readCache(key),
  reserveBudget:(uid,key,chars)=>stockage.reserveBudget(uid,key,chars),
  writeCache:(key,text)=>stockage.writeCache(key,text),
  provider:fournisseur
 });
}
export { creerDependancesTraduction };
