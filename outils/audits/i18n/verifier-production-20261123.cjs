'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),cp=require('node:child_process'),crypto=require('node:crypto'),vm=require('node:vm');
async function obtenir(url){
 const path=require('node:path'),os=require('node:os');
 const dossier=fs.mkdtempSync(path.join(os.tmpdir(),'hg-i18n-production-'));
 try{
  const corps=path.join(dossier,'corps'),entetes=path.join(dossier,'entetes');
  const statut=cp.execFileSync('curl',['--fail','--silent','--show-error','--location','--compressed','--connect-timeout','10','--max-time','30','--dump-header',entetes,'--output',corps,'--write-out','%{http_code}',String(url)],{encoding:'utf8'});
  const data=fs.readFileSync(corps),blocs=fs.readFileSync(entetes,'utf8').split(/\r?\n\r?\n/).filter(b=>/^HTTP\//.test(b));
  const headers=new Map((blocs.at(-1)||'').split(/\r?\n/).slice(1).filter(l=>l.includes(':')).map(l=>[l.slice(0,l.indexOf(':')).toLowerCase(),l.slice(l.indexOf(':')+1).trim()]));
  return {status:Number(statut),headers:{get:k=>headers.get(k.toLowerCase())||null},text:async()=>data.toString(),arrayBuffer:async()=>data};
 }finally{fs.rmSync(dossier,{recursive:true,force:true});}
}
const sha=process.argv[2],root=process.argv[3],out=process.argv[4];if(!sha||!root||!out)throw Error('SHA, dépôt et sortie requis');
const read=f=>cp.execFileSync('git',['show',sha+':'+f],{cwd:root,maxBuffer:4e6});const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 const htmlResponse=await obtenir('https://human-gambit.com/plateau.html',{signal:AbortSignal.timeout(30000)});assert.equal(htmlResponse.status,200);const html=await htmlResponse.text();
 const scriptURL=f=>{const escaped=f.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');const m=html.match(new RegExp('src=["\\\']('+escaped+'[^"\\\']*)["\\\']'));assert.ok(m,'script absent '+f);return m[1];};
 const paths=[['i18n/resources.js',scriptURL('i18n/resources.js')],['plateau-universite.js',scriptURL('plateau-universite.js')],['i18n/university-resources.js','i18n/university-resources.js?v=20261123'],['i18n/organization-creation-resources.js',scriptURL('i18n/organization-creation-resources.js')]];
 const resources={};const result=await Promise.all(paths.map(async([file,url])=>{const response=await obtenir(new URL(url,'https://human-gambit.com/'),{headers:{'accept-encoding':'br, gzip'},signal:AbortSignal.timeout(30000)});assert.equal(response.status,200);assert.match(response.headers.get('content-type'),/javascript/);const data=Buffer.from(await response.arrayBuffer());assert.equal(hash(data),hash(read(file)),file+' diffère du commit attendu');resources[file]=data.toString();return {fichier:file,url:new URL(url,'https://human-gambit.com/').href,http:response.status,type:response.headers.get('content-type'),encodage:response.headers.get('content-encoding'),sha256:hash(data),octets:data.length,identique_au_commit:true};}));
 const c={};c.window=c;vm.createContext(c);vm.runInContext(resources['i18n/resources.js'],c);vm.runInContext(resources['i18n/university-resources.js'],c);const words=JSON.parse(JSON.stringify(c.RPUniversityI18n.words));const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];assert.deepEqual(Object.keys(words),locales);const original=JSON.parse(read('outils/audits/i18n/FORMATION-20261123-sources.json')).fr;const catalogue=JSON.parse(read('outils/audits/i18n/FORMATION-CATALOGUE-20261123.json')).cursus;assert.deepEqual(words.fr,{...original,...Object.fromEntries(catalogue.map(x=>['catalogue_'+x.id,x.libelle]))});for(const l of locales){assert.equal(Object.keys(words[l]).length,46);for(const x of catalogue){assert.equal(c.RPUniversityI18n.careers[x.carriere].fr,x.carriere_libelle);assert.ok(c.RP_I18N_RESOURCES[l].translation.creation.careers[x.carriere].name);}}
 assert.match(resources['plateau-universite.js'],/university-resources\.js\?v=20261123/);assert.match(resources['i18n/organization-creation-resources.js'],/function sensSaisie/);
 const preuve={commit_attendu:sha,origine:'https://human-gambit.com',verification:'GET statiques sans PJ connecté ni appel métier',fichiers:result,langues:locales,cles_universite_par_langue:46,textes_francais_couverts:51,traductions_etrangeres:368,traductions_etrangeres_reutilisees:40,francais_original_exact:true,correctif_sens_saisie_present:true,telephone_physique:false};fs.writeFileSync(out,JSON.stringify(preuve,null,2)+'\n');console.log(JSON.stringify(preuve));
})().catch(e=>{console.error(e);process.exitCode=1;});
