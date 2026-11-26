/* Lecteur INTERNE de sources sociales, aucune route HTTP ni droit nouveau.
 * Le contenu à traduire n'est JAMAIS pris dans le corps d'une requête client.
 * Une lecture sous JWT du joueur et sous RLS précède tout accès au cache.
 */
import { sbGetVerdict } from './_supabase.js';
import { validerSource } from './_traduction-sources.js';

function texteDepuisHtml(html) {
 return String(html||'')
  .replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi,' ')
  .replace(/<br\s*\/?>/gi,'\n').replace(/<\/(p|div|li|h[1-6]|blockquote)>/gi,'\n')
  .replace(/<[^>]+>/g,' ')
  .replace(/&nbsp;/g,' ').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&amp;/g,'&')
  .replace(/[ \t]+/g,' ').replace(/ *\n */g,'\n').replace(/\n{3,}/g,'\n\n').trim();
}
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
 // Les messages du forum sont du HTML assaini : seul le texte lisible est traduit (balises retirées, entités courantes
 // décodées) ; la traduction est affichée en texte simple, jamais injectée comme HTML (décisions du 26/11, bloc D).
 const texte=canonical.type==='forum_post'?texteDepuisHtml(row[column]):row[column];
 return Object.freeze({text:texte,language:'und'});
}
export { lireOriginalSousRls, texteDepuisHtml };
