'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),zlib=require('node:zlib'),crypto=require('node:crypto');
const R=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(R,'plateau-personnage.js'),'utf8');
const debut=source.indexOf('const REGLES = ')+'const REGLES = '.length;
const regles=vm.runInNewContext('('+source.slice(debut,source.indexOf('\n};',debut)+2)+')');
const window={};
for(const f of ['resources.js','guide-resources.js','guide-integrity.js'])vm.runInNewContext(fs.readFileSync(path.join(R,'i18n',f),'utf8'),{window});
const brut=fs.readFileSync(path.join(__dirname,'fixtures/guide-marque-relue-20261122.json.gz'));
assert.equal(crypto.createHash('sha256').update(brut).digest('hex'),'b2bff314e8ca4d58583e157f3372e8ad198a383e5cfd0d4c5f7079e5156dc5bd');
const base=JSON.parse(zlib.gunzipSync(brut));
const nom=(texte,lang)=>lang==='ko'?texte.replaceAll('Res Publica','Human Gambit').replaceAll('Human Gambit는','Human Gambit은'):texte.replaceAll('Res Publica','Human Gambit');

test('neuf langues : seul le nom change dans les textes relus, sans perte de récit ni de règle',()=>{
 assert.equal(Object.keys(base.guide).length,9);
 for(const [lang,sections] of Object.entries(base.guide)){
  const actuel=lang==='fr'?regles:window.RP_I18N_RESOURCES[lang].translation.guide;
  assert.deepEqual(Object.keys(actuel),Object.keys(sections),lang);
  for(const [section,texte] of Object.entries(sections)){
   assert.equal(actuel[section].titre,nom(texte.titre,lang),lang+'/'+section+'/titre');
   assert.equal(actuel[section].contenu,nom(texte.contenu,lang),lang+'/'+section+'/contenu');
   assert.doesNotMatch(actuel[section].contenu,/Res Publica/);
  }
 }
});

test('les empreintes restent strictes et couvrent le nom Human Gambit',()=>{
 for(const section of ['tuto','intro']){
  assert.equal(window.RPGuideIntegrity.valid(section,regles[section]),true);
  assert.equal(window.RPGuideIntegrity.valid(section,{...regles[section],contenu:regles[section].contenu+'Texte non relu.'}),false);
 }
});
