/* Lecteur INTERNE de sources sociales, aucune route HTTP ni droit nouveau.
 * Le contenu à traduire n'est JAMAIS pris dans le corps d'une requête client.
 * Une lecture sous JWT du joueur et sous RLS précède tout accès au cache.
 */
import { sbGetVerdict } from './_supabase.js';
import { validerSource } from './_traduction-sources.js';

async function lireOriginalSousRls(source, readerToken, getVerdict=sbGetVerdict) {
 // L'objet source peut provenir d'une couche externe : revalidation complète.
 const canonical=validerSource(source?.type,source?.id,source?.field);
 if(!canonical || typeof readerToken!=='string' || !readerToken.trim() ||
    typeof getVerdict!=='function')return null;
 // Une colonne sensible ajoutée au schéma n'est jamais récupérée par SELECT *.
 const column=canonical.field;
 const filter='select=id,'+column+
  '&id=eq.'+encodeURIComponent(canonical.id)+'&limit=2';
 let response;
 try{
  response=await getVerdict(canonical.source.table,filter,{jeton:readerToken});
 }catch{ return null; }
 // Une panne, un interdit, une absence ou plusieurs lignes ont la même sortie.
 const rows=response?.ok?response.donnees:null;
 if(!Array.isArray(rows)||rows.length!==1)return null;
 const row=rows[0];
 if(!row || String(row.id)!==canonical.id || typeof row[column]!=='string')
  return null;
 // Les tables sociales actuelles n'ont pas de colonne de langue ou de version.
 // Le moteur de traduction déduit une version du contenu après lecture RLS.
 // La langue source demeure explicitement indéterminée, jamais supposée FR.
 return Object.freeze({text:row[column],language:'und'});
}
export { lireOriginalSousRls };
