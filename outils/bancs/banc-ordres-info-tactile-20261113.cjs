'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
// Preuve figée sur les PR #855 et #857 elles-mêmes (13/11, Claude) : avant = 8d9dc22 (main avant
// #855), après = a14fd38 (#857 fusionnée). L'ancienne comparaison à merge-base(origin/main, HEAD)
// refusait toute PR ultérieure touchant plateau-politique.js, une migration, data.js ou i18n.
const base='8d9dc2246fd24bdd06a12f81c691328df2b4c901',tete='a14fd38ac17911c5bcdbbbced6c0e825af7f9969';
const show=(c,p)=>execFileSync('git',['show',c+':'+p],{cwd:root,encoding:'utf8',maxBuffer:8*1024*1024});
test('seule la présentation du renderer change ; fonctions métier et catalogues intacts',()=>{
 const clean=s=>s.replace(/^.*(?:let infoBlocage =|infoBlocage =|if \(infoBlocage\) tipDescripteur\.blocage).*\n/gm,'').replaceAll(", details: tipSpec",'')
  .replace(/^.*\/\/ Les descriptions métier peuvent contenir des guillemets droits.*\n/gm,'')
  .replace(/^.*\/\/ Les messages bloqués ont déjà été échappés.*\n/gm,'')
  .replace(/^.*const tooltipAttribut = tooltipFinal === tooltip.*\n/gm,'')
  .replace(" + tooltipAttribut + ", " + tooltipFinal + ");
 assert.equal(clean(show(tete,'plateau-politique.js')),clean(show(base,'plateau-politique.js')));
 // Fichier actuel : présentation tactile et échappement des guillemets toujours branchés.
 assert.match(read('plateau-politique.js'),/details: tipSpec/);
 assert.match(read('plateau-politique.js'),/tooltipAttribut/);
 const changed=execFileSync('git',['diff','--name-only',base,tete,'--','api','migrations','baseline','data.js','plateau-router.js','plateau-core.js','plateau-mobile.js','i18n'],{cwd:root,encoding:'utf8'}).trim();assert.equal(changed,'');
 const s=read('plateau-ordres-info.js');assert.doesNotMatch(s,/fetch\(|sbRpc|sbSave|doOrder\(|deduireCout|payer_ordre|state\./);
 assert.doesNotMatch(s,/longpress|touchstart|setTimeout|eval\(|new Function/);
 assert.match(s,/RPSovarkaInfobullesI18n\.infobulle\(p\.details\)/);
 assert.match(s,/label\('closeButton'\)/);assert.match(s,/\.showModal\(\)/);
 assert.ok(read('plateau.html').includes('plateau-ordres-info.js'));
});
