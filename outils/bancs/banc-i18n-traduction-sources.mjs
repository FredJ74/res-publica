import test from 'node:test';
import assert from 'node:assert/strict';
import { SOURCES,validerSource } from '../../api/_traduction-sources.js';
test('seules les trois sources lisibles par RLS sont admises sont admises',()=>{
 assert.deepEqual(Object.keys(SOURCES),['forum_post','forum_topic','chat_message']);
 for(const [type,source] of Object.entries(SOURCES)){
  for(const field of source.fields) {
   const value=validerSource(type,'fixture-id',field);
   assert.equal(value.source.table,source.table);
   assert.equal(value.field,field);
  }
 }
});
test('aucun auteur secret, JWT, colonne ou chemin arbitraire n est lisible',()=>{
 for(const value of [['forum_post','1','author_real'],['forum_post','1','content_blocks'],['chat_message','1','auteur'],['forum_post','../1','content'],['__proto__','1','content'],['pending_article','1','fait_json']]){
  assert.equal(validerSource(...value),null,value.join('/'));
 }
});
test('chaque type déclare une autorisation de lecture à vérifier au serveur',()=>{
 for(const source of Object.values(SOURCES))assert.ok(source.privacy&&source.privacy!=='public');
});

test('audiences et brouillons de presse sans politique SELECT restent fermés',()=>{
 assert.equal(validerSource('court_message','1','texte'),null);
 assert.equal(validerSource('pending_article','1','texte'),null);
});
