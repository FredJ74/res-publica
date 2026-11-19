'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const config={RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}]))};
for(const f of ['i18n/commerce-management-resources.js','i18n/commerce-pj-complements-20261119.js','i18n/political-org-resources-20261119.js'])
  vm.runInNewContext(read(f),{window:config},{filename:f});
const flat=(x,p='',o={})=>{if(typeof x==='string')o[p]=x;else if(x&&typeof x==='object')for(const [k,v]of Object.entries(x))flat(v,p?p+'.'+k:k,o);return o;};
const source=read('plateau-commerce-pj.js');
const begin=source.indexOf('const I18N_COMMERCE_PJ_FR = {');
const end=source.indexOf('\n};',begin);
assert.ok(begin>=0&&end>begin);
const canonical=vm.runInNewContext(source.slice(begin,end+3)+'\nI18N_COMMERCE_PJ_FR');
const commercial=flat(config.RP_I18N_RESOURCES.fr.translation.commercepj);
const keyStart='// Human Gambit — compléments';
const supplement=read('i18n/commerce-pj-complements-20261119.js');
test('70 textes de commerce complétés, français exactement conservé et 8 langues',()=>{
  const extras=[...supplement.matchAll(/"([a-zA-Z]+(?:\.[a-zA-Z]+)*)":/g)];
  const dataStart=supplement.indexOf('const words='),dataEnd=supplement.indexOf(';\n function assign',dataStart);
  assert.ok(dataStart>0&&dataEnd>dataStart);
  const entries=JSON.parse(supplement.slice(dataStart+'const words='.length,dataEnd));
  assert.equal(Object.keys(entries.fr).length,70);
  for(const [k,v]of Object.entries(entries.fr)){
    assert.equal(v,canonical['commercepj.'+k],k);
  }
  for(const lang of langs){
    const all=flat(config.RP_I18N_RESOURCES[lang].translation.commercepj);
    for(const [k,fr] of Object.entries(entries.fr)){
      assert.equal(typeof all[k],'string',lang+' '+k);
      assert.ok(all[k].trim());
      if(lang==='fr')assert.equal(all[k],fr);
      else {
        assert.notEqual(all[k],fr,'translation must differ: '+lang+' '+k);
        const vars=s=>[...s.matchAll(/\{(?:\{values\.)?([A-Za-z0-9_]+)\}?/g)].map(x=>x[1]).sort();
        assert.deepEqual(vars(all[k]),vars(fr),'placeholder '+lang+' '+k);
      }
    }
  }
});
test('Les 52 libellés de gestion antérieurs restent présents, sans écrasement',()=>{
  for(const lang of langs){
    const all=flat(config.RP_I18N_RESOURCES[lang].translation.commercepj);
    for(const key of ['gestion.local','gestion.identite','tab.caisse','col.prixVente'])assert.ok(all[key],lang+' '+key);
  }
});
test('20 libellés politiques en neuf langues et variables dynamiques',()=>{
  const reference=config.RP_I18N_RESOURCES.fr.translation.politicalOrg;
  assert.equal(Object.keys(reference).length,20);
  for(const lang of langs){
    const t=config.RP_I18N_RESOURCES[lang].translation.politicalOrg;
    assert.deepEqual(Object.keys(t).sort(),Object.keys(reference).sort());
    for(const [k,v] of Object.entries(reference)){
      assert.ok(t[k].trim(),lang+' '+k);
      const vars=s=>[...s.matchAll(/\{\{values\.([A-Za-z0-9_]+)\}\}/g)].map(x=>x[1]).sort();
      assert.deepEqual(vars(t[k]),vars(v),lang+' '+k);
    }
  }
});
test('Branchages conservateurs dans le HTML et le rendu politique uniquement',()=>{
  const html=read('plateau.html');
  const m=html.indexOf('i18n/commerce-management-resources.js');
  const c=html.indexOf('i18n/commerce-pj-complements-20261119.js');
  const p=html.indexOf('i18n/political-org-resources-20261119.js');
  const init=html.indexOf('i18n/plateau-init.js');
  assert.ok(m>=0 && c>m && c<init && p>=0 && p<init);
  const politique=read('plateau-politique.js');
  new vm.Script(politique,{filename:'plateau-politique.js'});
  const fn=politique.slice(politique.indexOf('async function ouvrirEcranPostes()'),politique.indexOf('// PRIORITE PJ SUR POSTES NOMMES'));
  assert.ok(fn.includes("orgT('elected'")&&fn.includes("orgT('military'"));
  assert.ok(fn.includes('window.RPI18nPlateau?.apply?.('),'bascule de langue de la modale');
  assert.ok(fn.includes('demanderNominationPoste(')&&fn.includes('ouvrirCalendrierElectoral()'),'mêmes actions');
});
