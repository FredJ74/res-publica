// Vérifie la collecte des portraits publiés en forum vers l'avant-dernière page.
// Aucun appel distant ni écriture de données PJ.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('api/_journal-generation.js','utf8');
const a=source.indexOf('const MAX_INTERVIEWS_AVANT_DERNIERE_PAGE = 4;');
const b=source.indexOf('// =====================================================================\n// ÉDITION DÉTERMINISTE',a);
assert(a>0&&b>a,'collecteur Jodie absent');
const fragment=source.slice(a,b);
async function cas({classiques=[],topics=[],posts=[],personnages=[]}={}){
  const appels=[];
  const context={SUPABASE_SERVICE_ROLE:'fixture',SB_HEADERS_SERVICE:{},encodeURIComponent,Date,Map,Set,
    sbGet:async(table,query)=>{appels.push({table,query});return ({interviews_jodie:classiques,forum_topics:topics,forum_posts:posts,personnages})[table]||[]}};
  vm.createContext(context);vm.runInContext(fragment+'\nthis.executer=assemblerAvantDernierePage',context);
  return {sortie:await context.executer('republic'),appels};
}
(async()=>{
  const date='2026-10-30T23:19:16.055Z';
  let r=await cas({topics:[{id:'topic-arnie',title:'Un jour, un portrait : Arnie',time:date}],posts:[{topic_id:'topic-arnie',content:'Portrait réel Arnie'}],personnages:[{name:'Arnie',photo_url:'photo.webp'}]});
  assert.equal(r.sortie.interviews.length,1);assert.equal(r.sortie.interviews[0].nom,'Arnie');
  assert.equal(r.sortie.interviews[0].texte,'Portrait réel Arnie');
  assert.equal(r.sortie.interviews[0].photo_url,'photo.webp');
  assert(r.appels.some(a=>a.table==='forum_topics'&&a.query.includes('forum_id=eq.presse')&&a.query.includes('Jodie')));
  assert(r.appels.some(a=>a.table==='forum_posts'&&a.query.includes('author=eq.')));
  r=await cas({topics:[{id:'vide',title:'Un jour, un portrait : Bob',time:date}]});
  assert.equal(r.sortie.interviews.length,0,'pas de publication sans post');
  r=await cas({classiques:[{personnage:'Arnie',article_texte:'Entretien plus ancien',publie_le:'2026-10-29T12:00:00Z'}],topics:[{id:'arnie',title:'Un jour, un portrait : Arnie',time:date}],posts:[{topic_id:'arnie',content:'Portrait récent'}]});
  assert.equal(r.sortie.interviews.length,1,'un seul article par personnage');
  assert.equal(r.sortie.interviews[0].texte,'Portrait récent');
  const ts=Array.from({length:6},(_,i)=>({id:'t'+i,title:'Un jour, un portrait : PJ'+i,time:new Date(Date.parse(date)-i*3600000).toISOString()}));
  r=await cas({topics:ts,posts:ts.map(t=>({topic_id:t.id,content:'Contenu '+t.id}))});
  assert.equal(r.sortie.interviews.length,4,'maximum de quatre');
  console.log('OK journal Jodie : Arnie repris, publication incomplete exclue, dedoublonnage, limite quatre, attribution et photo');
})().catch(e=>{console.error(e);process.exitCode=1});
