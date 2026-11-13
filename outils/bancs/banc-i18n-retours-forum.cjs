'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const {parse,walk}=require('../audits/audit-i18n-global.cjs');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8'),locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const previous=execFileSync('git',['show','94d4631:forum.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6});
function load(){const c={RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>c.locale||'fr'}};c.window=c;vm.createContext(c);
 for(const f of ['i18n/i18next.min.js','i18n/resources.js','i18n/toast-resources.js','i18n/forum-feedback-resources.js'])vm.runInContext(read(f),c);c.i18next.init({lng:'fr',fallbackLng:'fr',resources:c.RP_I18N_RESOURCES,initImmediate:false,interpolation:{escapeValue:false}});return c;}
test('43 textes de source exacts, neuf langues complètes et nom de forum conservé',()=>{
 const messages=new Set(),titles=new Set();walk(parse(previous),n=>{if(n.type==='CallExpression'&&n.callee.name==='showToast'){if(n.arguments[0]?.type==='Literal')titles.add(n.arguments[0].value);walk(n.arguments[1],s=>{if(s.type==='Literal'&&typeof s.value==='string')messages.add(s.value);});}});
 const c=load(),fr=c.RP_I18N_RESOURCES.fr.translation.forumFeedback;assert.equal(Object.keys(fr).length,43);
 for(const [key,text]of Object.entries(fr))assert.ok((c.RPToastI18n.key(text)==='forumFeedback.'+key?titles:messages).has(text),key+': '+text);
 for(const lang of locales){const words=c.RP_I18N_RESOURCES[lang].translation.forumFeedback;assert.deepEqual(Object.keys(words),Object.keys(fr));for(const [key,text]of Object.entries(words)){
  assert.ok(text.trim());if(lang!=='fr')assert.notEqual(text,fr[key]);if(key==='namedPresidency')assert.ok(text.includes('La Présidence à la Nation'));
 }}
});
test('titres extensibles : anciens libellés conservés, neuf langues et repli français',()=>{
 const c=load();for(const lang of locales){c.locale=lang;c.i18next.changeLanguage(lang);assert.equal(c.RPToastI18n.label('Connexion indisponible'),c.i18next.t('forumFeedback.titleConnection'));
  assert.equal(c.RPToastI18n.label('Erreur'),c.i18next.t('toastTitles.error'));assert.equal(c.RPToastI18n.label('Inconnu sans ressource'),'Inconnu sans ressource');
 }
 assert.equal(c.RPToastI18n.registerTitle('Erreur','forumFeedback.titleConnection'),false);assert.equal(c.RPToastI18n.key('Erreur'),'toastTitles.error');
 assert.equal(c.RPToastI18n.registerTitle('Titre de fixture','fixture.missing'),true);assert.equal(c.RPToastI18n.label('Titre de fixture'),'Titre de fixture');
 for(const input of [null,{},'','   '])assert.equal(c.RPToastI18n.registerTitle(input,'fixture.missing'),false);
});
function isMarker(n){const e=n?.expression?.type==='ChainExpression'?n.expression.expression:n?.expression;return n?.type==='ExpressionStatement'&&e?.type==='CallExpression'&&e.callee?.property?.name==='markToast'&&e.callee.object?.property?.name==='RPI18nPlateau'&&e.callee.object.object?.name==='window';}
function canonical(n,parent,field){
 if(!n||typeof n!=='object')return n;if(isMarker(n))return null;if(Array.isArray(n))return n.map(x=>canonical(x,parent,field)).filter(x=>x!==null);
 const out={};for(const [k,v]of Object.entries(n))if(!['start','end','loc','raw'].includes(k))out[k]=canonical(v,n,k);
 // Un seul if sans accolades est enveloppé pour garder le marqueur sous sa garde d’origine.
 if(n.type==='BlockStatement'&&parent?.type==='IfStatement'&&['consequent','alternate'].includes(field)&&out.body.length===1&&out.body[0].type==='ExpressionStatement')return out.body[0];
 return out;
}
test('AST métier entièrement identique après retrait des 44 appels de présentation',()=>{
 // Preuve figée sur la PR #877 elle-même (13/11, Claude) : forum.js à sa fusion (e9989c6) contre 94d4631.
 // Comparer le forum.js courant refusait toute PR ultérieure touchant forum.js (ex. nouveaux boutons de courrier).
 const fusion=execFileSync('git',['show','e9989c6e35a35619ff5ae762799754f5d6065ee2:forum.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6});
 const after=parse(fusion);let count=0;walk(after,n=>{if(isMarker(n))count++;});assert.equal(count,44);
 assert.deepEqual(canonical(after),canonical(parse(previous)));
 // Les 44 marqueurs de présentation restent branchés dans le forum.js courant.
 let courant=0;walk(parse(read('forum.js')),n=>{if(isMarker(n))courant++;});assert.equal(courant,44);
 assert.match(read('plateau.html'),/forum-feedback-resources\.js/);
 assert.ok(read('plateau.html').indexOf('i18n/toast-resources.js')<read('plateau.html').indexOf('i18n/forum-feedback-resources.js'));
});
