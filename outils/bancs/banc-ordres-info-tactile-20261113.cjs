'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const base=execFileSync('git',['merge-base','origin/main','HEAD'],{cwd:root,encoding:'utf8'}).trim();
test('seule la présentation du renderer change ; fonctions métier et catalogues intacts',()=>{
 const clean=s=>s.replace(/^.*(?:let infoBlocage =|infoBlocage =|if \(infoBlocage\) tipDescripteur\.blocage).*\n/gm,'').replaceAll(", details: tipSpec",'')
  .replace(/^.*\/\/ Les descriptions métier peuvent contenir des guillemets droits.*\n/gm,'')
  .replace(/^.*\/\/ Les messages bloqués ont déjà été échappés.*\n/gm,'')
  .replace(/^.*const tooltipAttribut = tooltipFinal === tooltip.*\n/gm,'')
  .replace(" + tooltipAttribut + ", " + tooltipFinal + ");
 assert.equal(clean(read('plateau-politique.js')),clean(execFileSync('git',['show',base+':plateau-politique.js'],{cwd:root,encoding:'utf8',maxBuffer:8*1024*1024})));
 const changed=execFileSync('git',['diff','--name-only',base,'--','api','migrations','baseline','data.js','plateau-router.js','plateau-core.js','plateau-mobile.js','i18n'],{cwd:root,encoding:'utf8'}).trim();
 // Les catalogues de présentation i18n peuvent évoluer indépendamment du bouton tactile.
 const allowed=new Set(['i18n/republia-infobulles-resources.js','i18n/sovarka-infobulles-resources.js']);
 assert.deepEqual(changed?changed.split('\n').filter(x=>!allowed.has(x)):[],[]);
 const s=read('plateau-ordres-info.js');assert.doesNotMatch(s,/fetch\(|sbRpc|sbSave|doOrder\(|deduireCout|payer_ordre|state\./);
 assert.doesNotMatch(s,/longpress|touchstart|setTimeout|eval\(|new Function/);
 assert.match(s,/RPSovarkaInfobullesI18n\.infobulle\(p\.details\)/);
 assert.match(s,/label\('closeButton'\)/);assert.match(s,/\.showModal\(\)/);
 assert.ok(read('plateau.html').includes('plateau-ordres-info.js'));
});
