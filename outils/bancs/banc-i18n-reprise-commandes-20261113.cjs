'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {parse,walk}=require('../audits/audit-i18n-global.cjs');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8'),old=f=>execFileSync('git',['show','2c2de64:'+f],{cwd:root,encoding:'utf8',maxBuffer:4e6});
function marker(n){const e=n?.expression?.type==='ChainExpression'?n.expression.expression:n?.expression;return n?.type==='ExpressionStatement'&&e?.type==='CallExpression'&&e.callee?.property?.name==='markToast'&&e.callee.object?.property?.name==='RPI18nPlateau'&&e.callee.object.object?.name==='window';}
function clean(n,parent,field,{removeHelper=false}={}){if(!n||typeof n!=='object')return n;if(marker(n)||(removeHelper&&n.type==='FunctionDeclaration'&&n.id.name==='markToast'))return null;if(Array.isArray(n))return n.map(x=>clean(x,parent,field,{removeHelper})).filter(x=>x!==null);const out={};for(const [k,v]of Object.entries(n))if(!['start','end','loc','raw'].includes(k))out[k]=clean(v,n,k,{removeHelper});if(n.type==='BlockStatement'&&parent?.type==='IfStatement'&&['consequent','alternate'].includes(field)&&out.body.length===1&&out.body[0].type==='ExpressionStatement')return out.body[0];return out;}
test('reprise : programme métier identique, seul le service de présentation évolue',()=>{
 const p='outils/audits/I18N-REPRISE-COMMANDES-871-preuve.json',proof=fs.existsSync(path.join(root,p))?JSON.parse(read(p)):null;
 const source=f=>proof?execFileSync('git',['show',proof.codeCommit+':'+f],{cwd:root,encoding:'utf8',maxBuffer:4e6}):read(f);
 assert.deepEqual(clean(parse(source('plateau-construction-commandes.js'))),clean(parse(old('plateau-construction-commandes.js'))));
 assert.deepEqual(clean(parse(source('i18n/plateau-init.js')),null,null,{removeHelper:true}),clean(parse(old('i18n/plateau-init.js')),null,null,{removeHelper:true}));
 let count=0;walk(parse(source('plateau-construction-commandes.js')),n=>{if(marker(n))count++;});assert.equal(count,11);
 const current=read('plateau-construction-commandes.js');assert.ok(current.includes("r.raison?null:'constructionFeedback.serverRefusal'"));assert.ok(current.includes("'constructionFeedback.uncertain'"));
 const base=execFileSync('git',['merge-base','HEAD','origin/main'],{cwd:root,encoding:'utf8'}).trim();assert.equal(execFileSync('git',['diff','--name-only',base,'--','api','migrations','supabase','data.js'],{cwd:root,encoding:'utf8'}),'');
});
