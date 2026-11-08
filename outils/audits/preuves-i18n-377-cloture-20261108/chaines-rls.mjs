// Authentification de fixture ; lecteur, orchestrateur, stockage JS et RLS PostgreSQL réels.
// Aucun HTTP/Supabase réel. Le lanceur impose un socket privé de base jetable.
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {traduireContenu} from '../../../api/_traduction-contenu.js';
import {lireOriginalSousRls} from '../../../api/_traduction-lecture-rls.js';
import {creerStockageTraductions} from '../../../api/_traduction-stockage.js';
assert.match(process.env.PGHOST||'',/^\/tmp\/hg-i18n-cert17-/);
const sql=s=>{const v=execFileSync('psql',['-X','-Atq','-v','ON_ERROR_STOP=1','-c',s],{encoding:'utf8',env:process.env}).trim();return v?JSON.parse(v):null};
const quote=s=>"'"+String(s).replaceAll("'","''")+"'";
const uids={Alpha:'00000000-0000-4000-9000-000000000001',Beta:'00000000-0000-4000-9000-000000000002',Gamma:'00000000-0000-4000-9000-000000000003'};
let actor='Alpha',calls=0,cacheReads=0,mode='normal',lastCacheKey;
const stock=creerStockageTraductions(async(name,b)=>{
 let call;
 if(name==='rp_i18n_cache_lire'){lastCacheKey=b.p_cache_key;call=`${name}(${quote(b.p_cache_key)})`}
 else if(name==='rp_i18n_cache_ecrire')call=`${name}(${quote(b.p_cache_key)},${quote(b.p_text)})`;
 else if(name==='rp_i18n_budget_reserver')call=`${name}(${quote(b.p_uid)}::uuid,${quote(b.p_cache_key)},${b.p_characters})`;
 else throw Error('RPC inconnue');
 return {ok:true,donnees:sql(`SET ROLE service_role; SELECT to_jsonb(public.${call})`)};
},()=>true);
const read=(source,token)=>lireOriginalSousRls(source,token,async(table,filter,options)=>{
 const uid=uids[options.jeton];assert.ok(uid);
 const p=new URLSearchParams(filter),id=p.get('id').slice(3),column=p.get('select').split(',')[1];
 assert.ok(['forum_posts','forum_topics','messages_chat'].includes(table));assert.ok(['content','title','message'].includes(column));
 const donnees=sql(`BEGIN READ ONLY; SET LOCAL ROLE authenticated; SET LOCAL "request.jwt.claim.sub"=${quote(uid)}; SELECT coalesce(json_agg(x),'[]'::json) FROM (SELECT id,${column} FROM ${table} WHERE id=${quote(id)} LIMIT 2)x; ROLLBACK`);
 return {ok:true,donnees};
});
const deps={authenticate:async()=>uids[actor]?{userId:uids[actor],readerToken:actor}:null,readUnderRls:read,
 readCache:async key=>{cacheReads++;return stock.readCache(key)},writeCache:stock.writeCache,reserveBudget:stock.reserveBudget,
 provider:async({messages})=>{calls++;if(mode==='timeout')throw Error('fixture timeout');return {ok:true,texte:messages[0].content.replace('Bonjour','Hello')}}};
const results=[];
async function cas(name,f){await f();results.push({cas:name,ok:true})}
const req=(type,id,field)=>({type,id,field,langueCible:'en'});
const topic=req('forum_topic','org-topic','title'),post=req('forum_post','org-post','content'),chat=req('chat_message','salon-message','message');
await cas('membre_autorise_premier_cache_reel',async()=>{const v=await traduireContenu(post,deps);assert.equal(v.ok,true);assert.equal(v.fromCache,false)});
await cas('autre_membre_cache_partage_apres_RLS',async()=>{actor='Beta';const n=calls;const v=await traduireContenu(post,deps);assert.equal(v.ok,true);assert.equal(v.fromCache,true);assert.equal(calls,n)});
await cas('non_membre_aucun_cache_ni_divulgation',async()=>{actor='Gamma';const n=cacheReads;const v=await traduireContenu(post,deps);assert.equal(v.ok,false);assert.equal(v.original,null);assert.equal(cacheReads,n)});
await cas('revocation_adhesion_immediate_avant_hit_cache',async()=>{sql(`UPDATE organisations SET data='{"chef":"Alpha","membres":["Alpha"]}' WHERE id='prive';SELECT 'null'`);actor='Beta';const n=cacheReads;const v=await traduireContenu(post,deps);assert.equal(v.ok,false);assert.equal(cacheReads,n)});
await cas('sujet_prive_lu_sans_post_par_le_chef',async()=>{actor='Alpha';assert.equal((await traduireContenu(topic,deps)).ok,true)});
await cas('edition_original_invalide_cache_sans_version',async()=>{const n=calls;sql(`UPDATE forum_posts SET content='Bonjour texte révisé' WHERE id='org-post';SELECT 'null'`);assert.equal((await traduireContenu(post,deps)).fromCache,false);assert.equal(calls,n+1)});
await cas('forum_national_pays_etranger_refuse',async()=>{actor='Gamma';const n=cacheReads;assert.equal((await traduireContenu(req('forum_topic','national-topic','title'),deps)).ok,false);assert.equal(cacheReads,n)});
await cas('forum_local_voyage_revoque_meme_cache',async()=>{actor='Alpha';const r=req('forum_topic','local-topic','title');assert.equal((await traduireContenu(r,deps)).ok,true);sql(`UPDATE personnages_donnees SET current_city='ville_a' WHERE name='Alpha';SELECT 'null'`);const n=cacheReads;assert.equal((await traduireContenu(r,deps)).ok,false);assert.equal(cacheReads,n)});
await cas('chat_salon_acces_puis_revocation',async()=>{actor='Beta';assert.equal((await traduireContenu(chat,deps)).ok,true);sql(`DELETE FROM salons_membres WHERE salon_id='prive' AND membre='Beta';SELECT 'null'`);const n=cacheReads;assert.equal((await traduireContenu(chat,deps)).ok,false);assert.equal(cacheReads,n)});
await cas('chat_direct_seuls_les_participants',async()=>{const r=req('chat_message','direct-message','message');actor='Alpha';assert.equal((await traduireContenu(r,deps)).ok,true);actor='Gamma';assert.equal((await traduireContenu(r,deps)).ok,false)});
await cas('cache_falsifie_refuse_sans_nouveau_fournisseur_si_deja_reserve',async()=>{actor='Alpha';await traduireContenu(post,deps);sql(`SELECT to_jsonb(rp_i18n_cache_ecrire(${quote(lastCacheKey)},'999 USD'))`);const n=calls;const v=await traduireContenu(post,deps);assert.equal(v.ok,false);assert.equal(calls,n)});
await cas('timeout_fournisseur_ni_rejeu_payant_ni_faux_succes',async()=>{actor='Alpha';mode='timeout';const r=req('chat_message','timeout-message','message'),n=calls;assert.equal((await traduireContenu(r,deps)).ok,false);assert.equal((await traduireContenu(r,deps)).ok,false);assert.equal(calls,n+1);mode='normal'});
await cas('identite_inconnue_refusee_avant_toute_lecture',async()=>{actor='inconnu';const n=cacheReads;assert.equal((await traduireContenu(post,deps)).ok,false);assert.equal(cacheReads,n)});
console.log(JSON.stringify({tests:results,fournisseur_simule:true,SQL_RLS_reel:true,auth_uid_de_fixture:true,production:false}));
