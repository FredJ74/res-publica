import test from 'node:test';
import assert from 'node:assert/strict';
import { lireOriginalSousRls } from '../../api/_traduction-lecture-rls.js';
import { validerSource } from '../../api/_traduction-sources.js';
const source=validerSource('forum_post','test-id-1','content');

test('lecture sous JWT du lecteur, seule la colonne autorisée est demandée',async()=>{
 const calls=[];
 const result=await lireOriginalSousRls(source,'jwt-player',async(table,query,opts)=>{
  calls.push({table,query,opts});
  return {ok:true,donnees:[{id:'test-id-1',content:'Bonjour',author_secret:true}]};
 });
 assert.equal(result.text,'Bonjour');
 assert.equal(result.language,'und');
 assert.deepEqual(Object.keys(result),['text','language']);
 assert.equal(calls.length,1);
 assert.equal(calls[0].table,'forum_posts');
 assert.match(calls[0].query,/^select=id,content&id=eq\.test-id-1&limit=2$/);
 assert.deepEqual(calls[0].opts,{jeton:'jwt-player'});
 assert.equal(Object.hasOwn(calls[0].opts,'service'),false);
});
test('objet source forgé : nouvelle validation contre la liste blanche',async()=>{
 const calls=[];
 const forged={...source,source:{table:'private_secrets'}};
 const result=await lireOriginalSousRls(forged,'jwt',async(table)=>{
  calls.push(table);return {ok:true,donnees:[{id:'test-id-1',content:'Salut'}]};
 });
 assert.equal(result.text,'Salut');
 assert.deepEqual(calls,['forum_posts']);
});
test('colonne sensible, token absent : aucun appel réseau',async()=>{
 let count=0;const spy=async()=>{count++;return {ok:true,donnees:[]}};
 assert.equal(await lireOriginalSousRls({...source,field:'author_secret'},'jwt',spy),null);
 assert.equal(await lireOriginalSousRls(source,'',spy),null);
 assert.equal(count,0);
});
test('RLS interdit, erreur, ligne manquante ou dupliquée : même refus',async()=>{
 const cases=[
  {ok:false,raison:'interdit'},
  {ok:false,raison:'réseau'},
  {ok:true,donnees:[]},
  {ok:true,donnees:[{id:'test-id-1',content:'a'},{id:'test-id-1',content:'b'}]},
  {ok:true,donnees:[{id:'autre',content:'a'}]},
  {ok:true,donnees:[{id:'test-id-1',content:null}]}
 ];
 for(const response of cases){
  const answer=await lireOriginalSousRls(source,'jwt',async()=>response);
  assert.equal(answer,null);
 }
});
