#!/usr/bin/env node
// Banc de publication Jodie : transport Supabase et IA simulés, aucune connexion externe.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {createHash,createHmac,timingSafeEqual}=require('node:crypto');
const source=fs.readFileSync('api/jodie-portrait.js','utf8')
  .replace(/^import .*;\s*$/gm,'')
  .replace('export default async function handler','async function handler');
const INVITE="Un portrait pour L'Autruche Entravée ?";
const REFUS="Un portrait pour L'Autruche Entravée ? (classé)";
let count=0;
async function scenario({user=true,owner=true,invite=true,refuse=false,postFailure=false}={}) {
  const topics=new Map(),posts=new Map();
  const writes=[];
  const mockFetch=async(url,opts={})=>{
    const u=new URL(url),table=u.pathname.split('/').pop(),mode=opts.method||'GET';
    if (mode==='GET') {
      let rows=[];
      if(table==='personnages_donnees') rows=owner?[{name:'Arnie'}]:[];
      if(table==='mails') rows=[...(invite?[{subject:INVITE}]:[]),...(refuse?[{subject:REFUS}]:[])];
      if(table==='forum_topics') rows=[...topics.values()];
      if(table==='forum_posts') rows=[...posts.values()];
      const id=u.searchParams.get('id');
      if(id?.startsWith('eq.')) rows=rows.filter(x=>x.id===id.slice(3));
      return {ok:true,json:async()=>rows};
    }
    if(mode==='POST'){
      const data=JSON.parse(opts.body);writes.push({table,data});
      if(table==='forum_posts'&&postFailure) return {ok:false,status:503,text:async()=> 'panne'};
      if(table==='forum_topics')topics.set(data.id,data);
      if(table==='forum_posts')posts.set(data.id,data);
      return {ok:true,json:async()=>[data]};
    }
    throw Error('transport inattendu '+mode+' '+url);
  };
  const context={Buffer,Date,URL,createHash,createHmac,timingSafeEqual,
    process:{env:{SUPABASE_SERVICE_ROLE_KEY:'secret-test-sans-production'}},
    console:{error(){}},
    fetch:mockFetch,AbortSignal,
    joueurAuthentifie:async()=>user?{id:'user-arnie'}:null,
    appelDeepSeek:async()=>({ok:true,texte:'Portrait journalistique de test.'})
  };
  vm.createContext(context);
  vm.runInContext(source+'\nthis.handler=handler;',context,{filename:'api/jodie-portrait.js'});
  const call=async(body)=>{
    let status=200,answer;
    const res={status(v){status=v;return this},json(v){answer=v;return this}};
    await context.handler({method:'POST',body},res);
    count++;
    return {status,answer};
  };
  const rep=['Une réponse','Deux','Trois','Quatre','Cinq'];
  return {call,topics,posts,writes,rep};
}
(async()=>{
  let s=await scenario({user:false});
  let r=await s.call({action:'apercu',personnage:'Arnie',reponses:s.rep});
  assert.equal(r.status,401);assert.equal(s.writes.length,0);
  s=await scenario({owner:false});
  r=await s.call({action:'apercu',personnage:'Arnie',reponses:s.rep});
  assert.equal(r.status,403);assert.equal(s.writes.length,0);
  s=await scenario({invite:false});
  r=await s.call({action:'apercu',personnage:'Arnie',reponses:s.rep});
  assert.equal(r.status,403);
  s=await scenario({refuse:true});
  r=await s.call({action:'apercu',personnage:'Arnie',reponses:s.rep});
  assert.equal(r.status,403);
  s=await scenario();
  r=await s.call({action:'apercu',personnage:'Arnie',reponses:s.rep});
  assert.equal(r.status,200);assert.equal(r.answer.texte,'Portrait journalistique de test.');
  assert.equal(s.writes.length,0);
  const jeton=r.answer.jeton;
  r=await s.call({action:'publier',personnage:'Arnie',jeton:jeton.slice(0,-3)+'xxx'});
  assert.equal(r.status,403);assert.equal(s.writes.length,0);
  r=await s.call({action:'publier',personnage:'Arnie',jeton});
  assert.equal(r.status,200);assert.equal(s.topics.size,1);assert.equal(s.posts.size,1);
  assert.equal([...s.topics.values()][0].author,'Jodie Moitout');
  assert.equal([...s.posts.values()][0].content,'Portrait journalistique de test.');
  r=await s.call({action:'publier',personnage:'Arnie',jeton});
  assert.equal(r.status,200);assert.equal(s.topics.size,1);assert.equal(s.posts.size,1);
  s=await scenario({postFailure:true});
  r=await s.call({action:'apercu',personnage:'Arnie',reponses:s.rep});
  const jeton2=r.answer.jeton;
  r=await s.call({action:'publier',personnage:'Arnie',jeton:jeton2});
  assert.equal(r.status,503);assert.equal(s.topics.size,1);assert.equal(s.posts.size,0);
  console.log(count+'/ '+count+' requêtes simulées vérifiées : auth, propriété, invitation, refus, signature, publication, anti-doublon, panne de post');
})().catch(e=>{console.error(e);process.exitCode=1});
