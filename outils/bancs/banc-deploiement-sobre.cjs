const test = require('node:test'), assert = require('node:assert/strict');
const { mkdtempSync, writeFileSync, mkdirSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os'), path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const { ignorerBuild } = require('../../vercel-ignore-build.cjs');
const root = path.resolve(__dirname, '../..');
function depot(t) {
  const cwd = mkdtempSync(path.join(tmpdir(), 'hg-ignore-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore','pipe','pipe'] }).trim();
  git('init','-q'); git('config','user.name','Banc local'); git('config','user.email','banc@example.invalid');
  function ecrire(f, s='contenu') { mkdirSync(path.dirname(path.join(cwd,f)),{recursive:true}); writeFileSync(path.join(cwd,f),s); }
  function commit() { git('add','-A'); git('commit','-qm','banc'); return git('rev-parse','HEAD'); }
  ecrire('.vercelignore','*.md\n'); ecrire('README.md'); ecrire('api/chat.js','export default ()=>{};');
  const base = commit();
  return { cwd, git, ecrire, commit, base, decision(sha=base) { return ignorerBuild({cwd, env:{VERCEL_GIT_PREVIOUS_SHA:sha, VERCEL_GIT_COMMIT_SHA:git('rev-parse','HEAD')}}); } };
}
test('documentation seule ignoree, sur main comme sur une branche Preview', t => {
 const d=depot(t); d.ecrire('README.md','suite'); d.commit(); assert.equal(d.decision(),true);
 d.git('checkout','-qb','preview'); d.ecrire('outils/bancs/RAPPORT.md'); d.commit(); assert.equal(d.decision(),true);
});
for(const fichier of ['api/chat.js','images/test.webp','migrations/20261018000000_test.sql','vercel.json','.github/workflows/test.yml','vercel-ignore-build.cjs','api/prompt.md','inconnu.txt']) {
 test(`build conserve pour ${fichier}`,t=>{const d=depot(t);d.ecrire(fichier,'nouveau');d.commit();assert.equal(d.decision(),false);});
}
test('tous les commits depuis le dernier deploiement sont examines, pas seulement HEAD^',t=>{
 const d=depot(t);d.ecrire('api/chat.js','modifie');d.commit();d.ecrire('README.md','doc');d.commit();assert.equal(d.decision(),false);
});
test('suppression ou renommage de code ne sont pas caches par une extension documentaire',t=>{
 const d=depot(t);d.git('mv','api/chat.js','api/chat.md');d.commit();assert.equal(d.decision(),false);
});
test('premier deploiement, SHA absent/invalide, HEAD incoherent ou diff vide : build',t=>{
 const d=depot(t);const sha=d.git('rev-parse','HEAD');
 for(const env of [{},{VERCEL_GIT_PREVIOUS_SHA:'invalide',VERCEL_GIT_COMMIT_SHA:sha},{VERCEL_GIT_PREVIOUS_SHA:'f'.repeat(40),VERCEL_GIT_COMMIT_SHA:sha},{VERCEL_GIT_PREVIOUS_SHA:sha,VERCEL_GIT_COMMIT_SHA:'f'.repeat(40)}]) assert.equal(ignorerBuild({cwd:d.cwd,env}),false);
 assert.equal(d.decision(),false);
});
test('historique reecrit ou commit precedent indisponible : build',t=>{
 const d=depot(t);d.ecrire('README.md','branche-a');const a=d.commit();d.git('checkout','-qb','autre',d.base);d.ecrire('README.md','branche-b');d.commit();assert.equal(d.decision(a),false);
 d.git('checkout','--orphan','sans-historique');d.git('rm','-rf','.');d.ecrire('.vercelignore','*.md\n');d.ecrire('README.md');d.commit();assert.equal(d.decision(a),false);
});
test('re-inclusion documentaire ou disparition de son exclusion : build',t=>{
 const d=depot(t);for(const s of ['*.md\n!README.md\n','images/\n']){d.ecrire('.vercelignore',s);const base=d.commit();d.ecrire('README.md',s);d.commit();assert.equal(d.decision(base),false);}
});
test('commande Vercel : codes de sortie reels 0=ignorer et 1=construire',t=>{
 const d=depot(t);const { readFileSync }=require('node:fs');d.ecrire('vercel-ignore-build.cjs',readFileSync(path.join(root,'vercel-ignore-build.cjs')));const base=d.commit();d.ecrire('README.md','doc');const courant=d.commit();
 const run=env=>spawnSync(process.execPath,[path.join(d.cwd,'vercel-ignore-build.cjs')],{cwd:d.cwd,env:{...process.env,...env},encoding:'utf8'});
 assert.equal(run({VERCEL_GIT_PREVIOUS_SHA:base,VERCEL_GIT_COMMIT_SHA:courant}).status,0);
 assert.equal(run({VERCEL_GIT_PREVIOUS_SHA:'',VERCEL_GIT_COMMIT_SHA:courant}).status,1);
});
test('syntaxe API portable : vrai module accepte, syntaxe invalide refusee',t=>{
 const d=depot(t);const script=path.join(root,'outils/bancs/verifier-syntaxe-api.py');
 for(const [src,ok] of [['import x from "./absent.js"; export default async function handler() {}',true],['export default function ( {',false]]){
  d.ecrire('api/test.js',src);const r=spawnSync('python3',[script,path.join(d.cwd,'api/test.js')],{encoding:'utf8'});assert.equal(r.status===0,ok,r.stdout+r.stderr);
 }
});
for (const cas of ['derive','orpheline','non-declaree','disparue','muet']) {
 test(`referentiels : ${cas} reste en echec sans faux miroir absent`,()=>{
 const code=`import runpy,json,sys,contextlib,io
m=runpy.run_path(sys.argv[1]);f=m['axe_empreintes'];cas=sys.argv[2]
f.__globals__['empreinte_du_generateur']=lambda gen: (None,'muet') if cas=='muet' else ('nouvelle' if cas=='derive' else 'ancienne',None)
d={'empreintes':{'miroirs':{'miroir':{'generateur':'test','data_js':'ancienne','reelle':'ancienne' if cas=='disparue' else 'base','posee':'posee'}}},'divergences_empreintes':{'miroir/base':{},'miroir/posee':{}}}
if cas=='orpheline': d['divergences_empreintes']['absent/base']={}
if cas=='non-declaree': del d['divergences_empreintes']['miroir/base']
e=[]
with contextlib.redirect_stdout(io.StringIO()): f(d,e)
print(json.dumps(e))`;
 const r=spawnSync('python3',['-c',code,path.join(root,'outils/baseline/verifier-referentiels.py'),cas],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);const e=JSON.parse(r.stdout);assert.ok(e.length>0);
 if(cas==='derive'){assert.equal(e.length,1);assert.match(e[0],/generateur rend nouvelle/);}
 if(cas==='orpheline')assert.ok(e.some(s=>s.includes('absent/base')));
 if(cas==='non-declaree')assert.ok(e.some(s=>s.includes("n'est pas declare")));
 if(cas==='disparue')assert.ok(e.some(s=>s.includes('DISPARUE')));
 if(cas==='muet')assert.ok(e.some(s=>s.includes('muet')));
 });
}
test('configuration raccordee au script teste, production et Preview non desactivees',()=>{
 const { readFileSync }=require('node:fs');const v=JSON.parse(readFileSync(path.join(root,'vercel.json'),'utf8'));
 assert.equal(v.ignoreCommand,'node vercel-ignore-build.cjs');
 assert.equal(v.git?.deploymentEnabled,undefined);assert.equal(v.github?.enabled,undefined);
 assert.equal(v.crons.length,2);assert.equal(v.functions['api/chat.js'].maxDuration,30);
 for(const f of ['coherence-client','garde-payload-vercel','test-detention-jours-civils','test-fermetures-jours-civils']){
  const y=readFileSync(path.join(root,`.github/workflows/${f}.yml`),'utf8');
  assert.match(y,/cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}/);
  assert.match(y,/group: \$\{\{ github\.workflow \}\}-\$\{\{ github\.event\.pull_request\.number \|\| github\.ref \}\}/);
 }
});

test('Krasnov : seuls huit originaux non raccordes sont exclus, les futurs WebP restent servis',()=>{
 const fs=require('node:fs'),ignore=fs.readFileSync(path.join(root,'.vercelignore'),'utf8').split('\n');
 const originaux=fs.readdirSync(path.join(root,'images/krasnov')).filter(n=>n.endsWith('.png')).map(n=>'images/krasnov/'+n).sort();
 assert.equal(originaux.length,8);assert.ok(!ignore.includes('images/krasnov/'));
 assert.deepEqual(ignore.filter(n=>n.startsWith('images/krasnov/')).sort(),originaux);
 const exclus=new Set(['.git','node_modules','outils','baseline','historique','images','audio','Blender']);
 function lire(dir){for(const d of fs.readdirSync(dir,{withFileTypes:true})){
  if(d.name.startsWith('.')||exclus.has(d.name))continue;const f=path.join(dir,d.name);
  if(d.isDirectory())lire(f);else if(/\.(?:js|mjs|cjs|html|css|json)$/.test(d.name)){
   const s=fs.readFileSync(f,'utf8');for(const n of originaux)assert.ok(!s.includes(n),`asset exclu reference dans ${path.relative(root,f)} : ${n}`);
  }
 }}lire(root);
});
