'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const {parse}=require('../audits/audit-i18n-global.cjs'),root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
function clean(n){if(!n||typeof n!=='object')return n;const e=n?.expression?.type==='ChainExpression'?n.expression.expression:n?.expression;if(n.type==='ExpressionStatement'&&e?.callee?.property?.name==='markToast')return null;if(Array.isArray(n))return n.map(clean).filter(x=>x!==null);const o={};for(const [k,v]of Object.entries(n))if(!['start','end','loc','raw'].includes(k))o[k]=clean(v);return o;}
test('confirmations : forum intégralement identique hors annotations, deux titres exacts et neuf langues',()=>{
 const proofPath=path.join(root,'outils/audits/I18N-CONFIRMATIONS-FORUM-871-preuve.json'),proof=fs.existsSync(proofPath)?JSON.parse(fs.readFileSync(proofPath)):null;
 const before=execFileSync('git',['show','69a1c03:forum.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6}),after=proof?execFileSync('git',['show',proof.codeCommit+':forum.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6}):read('forum.js');assert.deepEqual(clean(parse(after)),clean(parse(before)));
 const c={};c.window=c;vm.createContext(c);vm.runInContext(read('i18n/resources.js'),c);vm.runInContext(read('i18n/forum-feedback-resources.js'),c);
 for(const [key,fr]of [['titleTopicDeleted','Sujet supprimé'],['titleMessageDeleted','Message supprimé']]){assert.equal(c.RP_I18N_RESOURCES.fr.translation.forumFeedback[key],fr);for(const lang of ['en','es','zh-TW','ru','ko','ar','pt-BR','de']){const value=c.RP_I18N_RESOURCES[lang].translation.forumFeedback[key];assert.ok(value.trim());assert.notEqual(value,fr);}}
});
