/* Sources canoniques de textes joueurs à traduire.
 * Contrat interne seulement : n'autorise aucune lecture. Le service futur
 * doit identifier le lecteur connecté, appliquer RLS / visibilité et lire
 * lui-même l'original depuis la base avant tout appel au fournisseur.
 *
 * Schéma confirmé en lecture seule sur Supabase au 02/11/2026.
 * Ne jamais exposer des clés privées, auteurs secrets ou journaux par
 * un endpoint de traduction non authentifié.
 */
const SOURCES = Object.freeze({
  forum_post: Object.freeze({table:'forum_posts',id:'id',fields:Object.freeze(['content']),privacy:'forum_visibility'}),
  forum_topic: Object.freeze({table:'forum_topics',id:'id',fields:Object.freeze(['title']),privacy:'forum_visibility'}),
  chat_message: Object.freeze({table:'messages_chat',id:'id',fields:Object.freeze(['message']),privacy:'conversation_membership'}),
  court_message: Object.freeze({table:'audience_messages',id:'rang',fields:Object.freeze(['texte']),privacy:'court_access'}),
  pending_article: Object.freeze({table:'journal_articles_en_attente',id:'id',fields:Object.freeze(['titre','texte']),privacy:'editorial_access'})
});
function validerSource(type,id,field) {
 const source=Object.hasOwn(SOURCES,type)?SOURCES[type]:null;
 if(!source || typeof field!=='string' || !source.fields.includes(field))return null;
 if(typeof id!=='string'&&typeof id!=='number')return null;
 const identifiant=String(id);
 if(!identifiant || identifiant.length>128 || !/^[a-zA-Z0-9:_-]+$/.test(identifiant))return null;
 return Object.freeze({type,id:identifiant,field,source});
}
export { SOURCES,validerSource };
