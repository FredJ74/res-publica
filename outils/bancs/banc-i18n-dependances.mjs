import test from 'node:test';
import assert from 'node:assert/strict';
import { creerDependancesTraduction } from '../../api/_traduction-dependances.js';
import { traduireContenu } from '../../api/_traduction-contenu.js';
const request={headers:{authorization:'Bearer token-joueur'}};
const source={type:'forum_post',id:'id1',field:'content',langueCible:'en'};
const uid='12345678-1234-1234-1234-123456789abc';

test('ordre de bout en bout : Auth, RLS, cache, quota, fournisseur, cache écrit',async()=>{
 const calls=[];
 const deps=creerDependancesTraduction(request,{
  authentifier:async()=>{calls.push('auth');return {id:uid,jeton:'token-joueur'}},
  lire:async(_src,token)=>{assert.equal(token,'token-joueur');calls.push('rls');return {text:'Hola',language:'und'}},
  stockage:{
   readCache:async()=>{calls.push('cache');return null},
   reserveBudget:async(id,_key,count)=>{assert.equal(id,uid);assert.equal(count,4);calls.push('quota');return true},
   writeCache:async()=>{calls.push('write')}
  },
  fournisseur:async()=>{calls.push('provider');return {ok:true,texte:'Hello',tronque:false}}
 });
 const result=await traduireContenu(source,deps);
 assert.equal(result.ok,true);
 assert.equal(result.langueOriginale,'und');
 assert.deepEqual(calls,['auth','rls','cache','quota','provider','write']);
});
test('Auth refuse : aucun accès RLS, quota ou fournisseur',async()=>{
 const calls=[];
 const deps=creerDependancesTraduction(request,{
  authentifier:async()=>{calls.push('auth');return null},
  lire:async()=>{calls.push('rls');throw Error('should not read')},
  stockage:{
   readCache:async()=>{calls.push('cache')},
   reserveBudget:async()=>{calls.push('quota')},
   writeCache:async()=>{calls.push('write')}
  },
  fournisseur:async()=>{calls.push('provider')}
 });
 const result=await traduireContenu(source,deps);
 assert.equal(result.ok,false);
 assert.deepEqual(calls,['auth']);
});
test('RLS refuse : aucune révélation de la ligne ni nouvelle dépense',async()=>{
 const calls=[];
 const deps=creerDependancesTraduction(request,{
  authentifier:async()=>{calls.push('auth');return {id:uid,jeton:'jwt'}},
  lire:async()=>{calls.push('rls');return null},
  stockage:{
   readCache:async()=>{calls.push('cache')},
   reserveBudget:async()=>{calls.push('quota')},
   writeCache:async()=>{calls.push('write')}
  },
  fournisseur:async()=>{calls.push('provider')}
 });
 const result=await traduireContenu(source,deps);
 assert.equal(result.ok,false);
 assert.equal(result.original,null);
 assert.deepEqual(calls,['auth','rls']);
});
test('quota désactivé : jamais d’appel payant',async()=>{
 const calls=[];
 const deps=creerDependancesTraduction(request,{
  authentifier:async()=>({id:uid,jeton:'jwt'}),
  lire:async()=>({text:'Salut',language:'und'}),
  stockage:{
   readCache:async()=>{calls.push('cache');return null},
   reserveBudget:async()=>{calls.push('quota');return false},
   writeCache:async()=>{calls.push('write')}
  },
  fournisseur:async()=>{calls.push('provider')}
 });
 const result=await traduireContenu(source,deps);
 assert.equal(result.raison,'quota_atteint');
 assert.deepEqual(calls,['cache','quota']);
});
