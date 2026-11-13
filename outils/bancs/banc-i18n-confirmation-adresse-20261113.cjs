'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const {parse,walk}=require('../audits/audit-i18n-global.cjs'),parse5=require('../audits/i18n-global/node_modules/parse5');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8'),base='196af01ddc4bf65dd0421f5754ea34856eb4eebf',old=f=>execFileSync('git',['show',base+':'+f],{cwd:root,encoding:'utf8',maxBuffer:4e6});
function fn(source,name){const n=parse(source).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===name);assert.ok(n,name);return source.slice(n.start,n.end);}
function clean(n){if(!n||typeof n!=='object')return n;if(n.type==='IfStatement'&&n.consequent?.expression?.callee?.name==='appliquerTraductionsRP')return null;if(Array.isArray(n))return n.map(clean).filter(x=>x!==null);const out={};for(const [k,v]of Object.entries(n))if(!['start','end','loc','raw'].includes(k))out[k]=clean(v);if(n.type==='Literal'&&typeof n.value==='string')out.value=n.value.replace(/ data-i18n="connectionUi\.confirmation(?:Expired|Success)(?:Title|Body)"/g,'');return out;}
test('confirmation : AST de création entier inchangé hors quatre attributs et deux appels de présentation',()=>{
 const p=path.join(root,'outils/audits/I18N-CONFIRMATION-ADRESSE-871-preuve.json'),proof=fs.existsSync(p)?JSON.parse(fs.readFileSync(p)):null;
 const source=proof?execFileSync('git',['show',proof.codeCommit+':creation.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6}):read('creation.js');assert.deepEqual(clean(parse(source)),clean(parse(old('creation.js'))));
 const section=fn(read('creation.js'),'rpRetourConfirmation');assert.equal((section.match(/data-i18n="connectionUi.confirmation/g)||[]).length,4);assert.equal((section.match(/if \(typeof appliquerTraductionsRP/g)||[]).length,2);
});
test('confirmation : français repris exactement du rendu initial, neuf langues et anciennes traductions intactes',()=>{
 const c={};c.window=c;vm.createContext(c);for(const f of ['i18n/resources.js','i18n/connection-resources.js'])vm.runInContext(read(f),c);
 const previous={};previous.window=previous;vm.createContext(previous);vm.runInContext(read('i18n/resources.js'),previous);vm.runInContext(old('i18n/connection-resources.js'),previous);
 const source=fn(old('creation.js'),'rpRetourConfirmation'),fr=c.RP_I18N_RESOURCES.fr.translation.connectionUi;
 for(const [kind,hash]of [['Expired','#error_code=otp_expired'],['Success','#type=signup&access_token=fixture-invalid']]){const zone={style:{},innerHTML:''};const b={window:{location:{hash,pathname:'/index.html',search:''},history:{replaceState(){}}},URLSearchParams,document:{getElementById:id=>id==='retour-confirmation'?zone:null}};vm.createContext(b);vm.runInContext(source,b);b.rpRetourConfirmation();const text=n=>n.nodeName==='#text'?n.value:(n.childNodes||[]).map(text).join('');const divs=parse5.parseFragment(zone.innerHTML).childNodes[0].childNodes;assert.equal(fr['confirmation'+kind+'Title'],text(divs[0]));assert.equal(fr['confirmation'+kind+'Body'],text(divs[1]));}
 for(const lang of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']){const cat=c.RP_I18N_RESOURCES[lang].translation.connectionUi;assert.ok(Object.keys(cat).length>=13);for(const [key,value]of Object.entries(previous.RP_I18N_RESOURCES[lang].translation.connectionUi))assert.equal(cat[key],value);for(const key of Object.keys(fr).filter(k=>k.startsWith('confirmation'))){assert.ok(cat[key].trim());if(lang!=='fr')assert.notEqual(cat[key],fr[key]);}}
});
test('confirmation : aucun moteur, RPC, serveur, donnée ou authentification modifié',()=>{
 const manifest=path.join(root,'outils/audits/I18N-CONFIRMATION-ADRESSE-871-preuve.json'),codeCommit=fs.existsSync(manifest)?JSON.parse(fs.readFileSync(manifest)).codeCommit:'HEAD';
 assert.equal(execFileSync('git',['diff','--name-only',base,codeCommit,'--','api','migrations','supabase','supabase.js','auth.js','data.js','i18n/i18n-init.js'],{cwd:root,encoding:'utf8'}),'');
});
