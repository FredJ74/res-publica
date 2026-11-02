'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
function load() {
  const sandbox = { window: {} };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(root, 'i18n/resources.js'), 'utf8'), sandbox);
  return sandbox.window;
}
test('six langues historiques et trois autres presentes a l accueil', () => {
  const w = load();
  assert.deepEqual(Array.from(Object.keys(w.RP_I18N_LANGUAGES)), ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']);
  for (const lang of Object.keys(w.RP_I18N_LANGUAGES)) {
    assert.ok(w.RP_I18N_LANGUAGES[lang].nativeName);
    assert.ok(w.RP_I18N_RESOURCES[lang]?.translation?.home?.createCharacter, lang);
  }
});
test('nouvelles langues : accueil traduit, suite du parcours avec repli FR', () => {
  const w = load();
  for (const lang of ['ar','pt-BR','de']) {
    const t = w.RP_I18N_RESOURCES[lang].translation;
    assert.ok(t.home.descriptor);
    assert.ok(t.home.signature);
    assert.ok(t.home.findCharacter);
    assert.ok(t.creation.countries.republic.description, 'La création comporte désormais ses descriptions localisées');
  }
  assert.ok(w.RP_I18N_RESOURCES.fr.translation.creation.steps.country.title);
});
test('navigation dans la création présente dans les trois nouvelles langues', () => {
  const w = load();
  for (const lang of ['ar', 'pt-BR', 'de']) {
    const creation = w.RP_I18N_RESOURCES[lang].translation.creation;
    for (const key of ['back','next','seeSheet','edit','validate','enter']) {
      assert.ok(creation.nav[key], lang + ':' + key);
    }
    for (const step of ['country','origin','school','archetype','career','stats','identity']) {
      assert.ok(creation.steps[step].title, lang + ':' + step);
      assert.ok(creation.steps[step].step, lang + ':' + step + ' number');
    }
  }
});
test('index et script i18n conservent la generation dynamique du selecteur', () => {
  const index = fs.readFileSync(path.join(root, 'index.html'),'utf8');
  const init = fs.readFileSync(path.join(root, 'i18n/i18n-init.js'),'utf8');
  assert.match(index, /id="lang-switcher"/);
  assert.match(index, /i18n\/resources\.js\?v=3/);
  assert.match(init, /Object\.keys\(window\.RP_I18N_LANGUAGES/);
  assert.match(init, /genererSelecteurLangueRP\(\)/);
});

test('résumé, ville et succès sont traduits dans les trois langues supplémentaires', () => {
  const w = load();
  for (const lang of ['ar', 'pt-BR', 'de']) {
    const t = w.RP_I18N_RESOURCES[lang].translation.creation;
    assert.ok(t.city.modalTitle, lang + ':ville');
    assert.ok(t.steps.review.title, lang + ':récapitulatif');
    assert.ok(t.review.lifePath, lang + ':fiche');
    assert.ok(t.success.title, lang + ':succès');
    assert.ok(t.success.text.includes('{{name}}'), lang + ':nom');
    assert.ok(t.success.text.includes('{{country}}'), lang + ':empire');
    assert.ok(t.genders.nonbinary, lang + ':genre');
  }
});

test('attributs et identité traduits sans perdre les paramètres de pluriel', () => {
 const w = load();
 for (const lang of ['ar','pt-BR','de']) {
   const steps = w.RP_I18N_RESOURCES[lang].translation.creation.steps;
   for (const key of ['pointsLabel','info','warning_one','warning_other']) assert.ok(steps.stats[key],lang+':stats.'+key);
   for (const key of ['photoLabel','photoHint','nameLabel','namePlaceholder','bioLabel','bioPlaceholder','mottoLabel','mottoOptional','mottoPlaceholder']) assert.ok(steps.identity[key],lang+':identity.'+key);
   assert.ok(steps.stats.warning_other.includes('{{count}}'));
 }
});

test('texte de bienvenue et conseiller complets pour les trois langues supplémentaires', () => {
  const w=load();
  const names=['title','intro','placeholder','ask','skip','pending','unavailable','libre','hint'];
  for (const lang of ['ar','pt-BR','de']) {
    const tr=w.RP_I18N_RESOURCES[lang].translation;
    assert.ok(tr.home.beta.title,lang+':beta title');
    assert.ok(tr.home.beta.body,lang+':beta body');
    for (const key of names) assert.ok(tr.creation.conseiller[key],lang+':conseiller.'+key);
  }
});

test('origines et écoles possèdent leurs libellés dans les trois nouvelles langues', () => {
 const w=load();
 for (const lang of ['ar','pt-BR','de']) {
   const c=w.RP_I18N_RESOURCES[lang].translation.creation;
   for (const k of ['poor','worker','bourgeois','elite']) {
     assert.ok(c.origins[k]?.name && c.origins[k]?.trait, lang+':origine '+k);
   }
   for (const k of ['none','basic','higher','elite']) {
     assert.ok(c.schools[k]?.name && c.schools[k]?.blockLabel, lang+':école '+k);
   }
 }
});

test('les neuf archétypes gardent leurs identifiants', () => {
 const w=load();
 const keys=['politician','authoritarian','oligarch','informer','legalist','believer','shadow','anticapitalist','criminal'];
 for (const lang of ['ar','pt-BR','de']) {
  const values=w.RP_I18N_RESOURCES[lang].translation.creation.archetypes;
  assert.deepEqual(Object.keys(values),keys);
  for (const key of keys) assert.ok(values[key].name);
 }
});

test('carrières, archétypes et caractéristiques restent alignés avec les identifiants français', () => {
 const w=load();
 const fr=w.RP_I18N_RESOURCES.fr.translation.creation;
 for(const lang of ['ar','pt-BR','de']) {
  const c=w.RP_I18N_RESOURCES[lang].translation.creation;
  for (const type of ['careers','archetypes','stats']) {
   assert.deepEqual(Object.keys(c[type]),Object.keys(fr[type]),lang+':'+type);
   for (const [id, value] of Object.entries(c[type])) {
    assert.ok(value.name,lang+':'+id);
    if(type==='careers') assert.ok(value.comp);
    else assert.ok(value.description);
   }
  }
 }
});

test('catalogues des neuf langues entièrement couverts pour accueil et création', () => {
 const w=load();
 function flatten(o,p='',out={}) {
  for(const [key,value] of Object.entries(o||{})) {
   const k=p?p+'.'+key:key;
   if(typeof value==='string') out[k]=value;
   else if(Array.isArray(value)) value.forEach((v,i)=>{if(typeof v==='string')out[k+'.'+i]=v});
   else if(value && typeof value==='object') flatten(value,k,out);
  }
  return out;
 }
 const reference=flatten(w.RP_I18N_RESOURCES.fr.translation);
 for(const lang of Object.keys(w.RP_I18N_LANGUAGES)) {
  const locale=flatten(w.RP_I18N_RESOURCES[lang].translation);
  const missing=Object.keys(reference).filter(k=>!Object.hasOwn(locale,k));
  assert.deepEqual(missing,[],lang+' missing translations');
 }
});

test('le formulaire de connexion préexistant est localisé en neuf langues sans changer les handlers',()=>{
 const w=load();
 const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
 for(const key of ['signIn','signInEmailPlaceholder','signInPasswordPlaceholder','signInSubmit','cancel']) {
  for(const lang of Object.keys(w.RP_I18N_LANGUAGES)) assert.ok(w.RP_I18N_RESOURCES[lang].translation.auth[key],lang+':'+key);
  const attr=key.endsWith('Placeholder')?'data-i18n-placeholder':'data-i18n';
  assert.ok(index.includes(attr+'="auth.'+key+'"'),key);
 }
 assert.match(index,/onclick="connecterAvecMotDePasse\(\)"/);
 assert.match(index,/onclick="ouvrirConnexionCompte\(\)"/);
});

test('chaque clé effectivement utilisée par les écrans de bienvenue existe dans les neuf langues',()=>{
 const w=load();
 const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
 const keys=[...html.matchAll(/data-i18n(?:-placeholder)?="([a-zA-Z0-9_.-]+)"/g)].map(x=>x[1]);
 assert.ok(keys.length>20);
 for(const lang of Object.keys(w.RP_I18N_LANGUAGES)){
  const data=w.RP_I18N_RESOURCES[lang].translation;
  for(const key of keys){
   const value=key.split('.').reduce((node,part)=>node?.[part],data);
   assert.equal(typeof value,'string',lang+':'+key);
  }
 }
});
