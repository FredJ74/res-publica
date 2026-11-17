'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const js=fs.readFileSync('creation.js','utf8');
const html=fs.readFileSync('index.html','utf8');
const countries={republic:{n:'Républia',col:'#fff',icon:'ti-flag'},narco:{n:'El Estado',col:'#fff',icon:'ti-flag'},soviet:{n:'Sovarka',col:'#fff',icon:'ti-flag'},khalija:{n:'Al-Khalija',col:'#fff',icon:'ti-flag'}};
const sections={'country-grid':{innerHTML:''},'n1':{disabled:true},'modal-city':{classList:{remove(){}}}};
const context={COUNTRIES:countries,G:{country:null,city:null,freeStats:{},freePts:30},WORLD:{},document:{documentElement:{lang:'fr'},getElementById:id=>sections[id]||null},t:key=>key,console};
vm.createContext(context);
vm.runInContext(js.slice(js.indexOf('const RP_EMPIRES_OUVERTS_CREATION'),js.indexOf('/* ---- Origin ---- */')),context);
context.renderCountry();
const cards=sections['country-grid'].innerHTML;
for(const country of ['narco','khalija']){
 const segment=cards.split('data-c="'+country+'"')[1].split('</div>')[0];
 assert.match(segment,/aria-disabled="true"/);
 assert.doesNotMatch(segment,/onclick=/);
 assert.equal(context.rpEmpireOuvertCreation(country),false);
}
for(const country of ['republic','soviet']){
 const segment=cards.split('data-c="'+country+'"')[1].split('</div>')[0];
 assert.match(segment,/onclick=/);
 assert.equal(context.rpEmpireOuvertCreation(country),true);
}
assert.equal((cards.match(/Bientôt disponible/g)||[]).length,2);
context.selCountry('narco');assert.equal(context.G.country,null);
context.selCountry('khalija');assert.equal(context.G.country,null);
assert.match(js,/async function validateChar\(\)\{\s*\/\/[^\n]*\n\s*if \(!rpEmpireOuvertCreation\(G\.country\)\)/);
assert.match(html,/\.rp-empire-a-venir\s*\{/);
assert.match(html,/creation\.js\?v=empires-a-venir-20261117/);
for(const [lang,label] of Object.entries({fr:'Bientôt disponible',en:'Coming soon',es:'Próximamente',ru:'Скоро будет доступно',de:'Demnächst verfügbar',ko:'곧 이용 가능',ar:'قريبًا','pt-BR':'Em breve','zh-TW':'即將推出'})){
 context.document.documentElement.lang=lang;
 assert.equal(context.rpEmpireBientotLibelle(),label);
}
console.log('OK : quatre cartes, deux empires fermés, création protégée et neuf langues');
