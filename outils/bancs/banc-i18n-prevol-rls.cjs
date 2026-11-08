'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const sql=fs.readFileSync(path.resolve(__dirname,'../../historique/i18n/PREFLIGHT-I18N-RLS-LECTURE-SEULE.sql'),'utf8');
test('le prévol de la traduction contrôle les trois véritables portes de lecture après #422',()=>{
 for(const predicate of [
  'forum_lecture_autorisee(forum_id,country)',
  'chat_participe(conversation_id,salon)',
  'exists(select1fromforum_topicstwhere(t.id=forum_posts.topic_id))'
 ])assert.ok(sql.includes(predicate),'RLS absente: '+predicate);
 assert.ok(sql.includes("nombre_politiques_lecture=1"),'refus des politiques permissives supplémentaires');
 assert.ok(sql.includes('c.relrowsecurity'),'contrôle RLS indispensable');
 assert.ok(sql.includes("p.cmd IN ('SELECT','ALL')"),'contrôler aussi les politiques ALL');
});
test('prévol exclusivement en lecture, pas de modification de production',()=>{
 const stripped=sql.replace(/--[^\n]*/g,'');
 assert.ok(!/\b(?:INSERT|UPDATE|DELETE|TRUNCATE|DROP|GRANT|REVOKE|CREATE|ALTER|PERFORM|EXECUTE)\b/i.test(stripped));
 assert.match(stripped,/\bSELECT\b/);
});
