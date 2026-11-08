import test from 'node:test';
import assert from 'node:assert/strict';
import {creerStockageTraductions,cleCourte} from '../../api/_traduction-stockage.js';

const uid='12345678-1234-1234-1234-123456789abc';
const key='["forum_post","test-id","content","sha256:abc","abc","und","en"]';
function adapter(outputs){
 const calls=[];
 const rpc=async(name,args,options)=>{
  calls.push({name,args,options});
  return outputs[name]??{ok:false};
 };
 return {calls,store:creerStockageTraductions(rpc,()=>true)};
}
test('clé opaque SHA256 stable ; aucun original ni UID dans les clés du cache',()=>{
 const hash=cleCourte(key);
 assert.match(hash,/^[0-9a-f]{64}$/);
 assert.equal(hash,cleCourte(key));
 assert.equal(hash.includes('forum_post'),false);
 assert.equal(cleCourte(''),null);
});
test('hit de cache : RPC serveur uniquement et refus de donnée malformée',async()=>{
 const hash=cleCourte(key);
 const {store,calls}=adapter({
  rp_i18n_cache_lire:{ok:true,donnees:'Hello'}
 });
 assert.equal(await store.readCache(key),'Hello');
 assert.equal(calls.length,1);
 assert.equal(calls[0].name,'rp_i18n_cache_lire');
 assert.equal(calls[0].args.p_cache_key,hash);
 assert.deepEqual(calls[0].options,{service:true});
 const invalid=adapter({rp_i18n_cache_lire:{ok:true,donnees:{text:'secret'}}});
 await assert.rejects(invalid.store.readCache(key));
});
test('quota atomique : UID vérifié, empreinte et longueur exacte envoyés',async()=>{
 const {store,calls}=adapter({rp_i18n_budget_reserver:{ok:true,donnees:true}});
 assert.equal(await store.reserveBudget(uid,key,18),true);
 assert.equal(calls[0].args.p_uid,uid);
 assert.equal(calls[0].args.p_characters,18);
 assert.equal(calls[0].args.p_cache_key,cleCourte(key));
 assert.deepEqual(calls[0].options,{service:true});
 assert.equal(await store.reserveBudget('forged-user',key,18),false);
 assert.equal(await store.reserveBudget(uid,key,2000),false);
 assert.equal(calls.length,1);
});
test('absence de clé serveur ou panne SQL : aucun accès ne réussit',async()=>{
 let count=0;
 const store=creerStockageTraductions(async()=>{count++;return {ok:true,donnees:'Leaked'}},()=>false);
 await assert.rejects(store.readCache(key));
 await assert.rejects(store.reserveBudget(uid,key,20));
 assert.equal(count,0);
 const unavailable=adapter({rp_i18n_budget_reserver:{ok:false,raison:'http'}});
 await assert.rejects(unavailable.store.reserveBudget(uid,key,20));
});
test('écriture : traductions uniquement, RPC serveur, refus sur erreur',async()=>{
 const {store,calls}=adapter({rp_i18n_cache_ecrire:{ok:true,donnees:true}});
 await store.writeCache(key,'Hallo');
 assert.equal(calls[0].args.p_text,'Hallo');
 assert.equal(calls[0].args.p_cache_key,cleCourte(key));
 assert.deepEqual(calls[0].options,{service:true});
 await assert.rejects(store.writeCache(key,' '));
 const broken=adapter({rp_i18n_cache_ecrire:{ok:true,donnees:false}});
 await assert.rejects(broken.store.writeCache(key,'Salut'));
});
