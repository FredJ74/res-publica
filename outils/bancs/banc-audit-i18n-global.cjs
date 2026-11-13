'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const audit=require('../audits/audit-i18n-global.cjs');
const root=path.resolve(__dirname,'../..');
function fixture(t,extra={}){
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hg-i18n-audit-'));
  t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
  const resource=Object.fromEntries(audit.LOCALES.map(l=>[l,{translation:{ui:{go:l==='fr'?'Partir':l+' Go',welcome:l==='fr'?'Bonjour {{name}}':l+' Hello {{name}}'}}}]));
  const files={
    'outils/audits/i18n-global/exclusions.json':fs.readFileSync(path.join(root,'outils/audits/i18n-global/exclusions.json'),'utf8'),
    'i18n/resources.js':'window.RP_I18N_RESOURCES='+JSON.stringify(resource)+';',
    'index.html':'<script src="i18n/resources.js"></script><script src="plateau-test.js"></script><button data-i18n="ui.go">Partir</button>',
    'plateau-test.js':"el.textContent = t('ui.welcome'); el.textContent = 'Erreur de paiement';",
    ...extra
  };
  for(const [file,text] of Object.entries(files)){fs.mkdirSync(path.dirname(path.join(dir,file)),{recursive:true});fs.writeFileSync(path.join(dir,file),text);}
  execFileSync('git',['init','-q'],{cwd:dir});execFileSync('git',['add','.'],{cwd:dir});
  execFileSync('git',['-c','user.name=Audit fixture','-c','user.email=audit@example.invalid','commit','-qm','fixture'],{cwd:dir});
  return {dir,files};
}
test('neuf langues et segmentation des mots source sans compter les variables',()=>{
  assert.equal(audit.LOCALES.length,9);
  assert.equal(audit.words('L’enquête : 3 indices, {{name}} et {DYNAMIC}.'),4);
  assert.equal(audit.normalize('  Bonjour\n monde  '),'Bonjour monde');
});
test('sources françaises exactes, présence ≠ raccordement, dénominateur et mots cohérents',t=>{
  const {dir}=fixture(t);const r=audit.build(dir);
  assert.deepEqual(r.extractionErrors,[]);assert.equal(r.central.frenchKeys,2);
  const go=r.entries.find(e=>e.text==='Partir');assert.equal(go.locales.en,'wired-unreviewed');
  const missing=r.entries.find(e=>e.text==='Erreur de paiement');assert.equal(missing.locales.en,'no-confirmed-resource');
  for(const l of audit.LOCALES){const m=r.perLanguage[l];assert.equal(m.texts,3);assert.equal(m.unconfirmedTexts+m.wiredTexts,m.texts);assert.equal(m.unconfirmedWords+m.wiredWords,m.words);}
  assert.equal(r.perLanguage.fr.wiredTextPercent,100);
});
test('ressource présente mais écran sans clé : aucune couverture revendiquée',t=>{
  const {dir}=fixture(t,{'index.html':'<script src="i18n/resources.js"></script><button>Partir</button>'});
  const r=audit.build(dir),e=r.entries.find(e=>e.text==='Partir');
  assert.equal(e.locales.en,'resource-review-binding');assert.equal(r.perLanguage.en.wiredTexts,0);
});
test('une clé dont le catalogue n’est pas chargé n’est pas une traduction raccordée',t=>{
 const {dir}=fixture(t,{'i18n/unloaded-resources.js':`for(const locale of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'])window.RP_I18N_RESOURCES[locale].translation.ui.unloaded=locale==='fr'?'Ressource non chargée':locale+' Not loaded';`,
 'plateau-test.js':`el.textContent=t('ui.unloaded',{defaultValue:'Ressource non chargée'});`});
 const r=audit.build(dir);assert.notEqual(r.entries.find(e=>e.text==='Ressource non chargée').locales.en,'wired-unreviewed');
});
test('une occurrence non raccordée empêche de déclarer tout le texte traduit',t=>{
  const {dir}=fixture(t,{'plateau-test.js':"el.textContent = 'Partir';"});
  const r=audit.build(dir),e=r.entries.find(e=>e.text==='Partir');
  assert.equal(e.occurrences.length,2);assert.equal(e.locales.en,'resource-review-binding');
});
test('manque, copie française et interpolation cassée détectés distinctement',()=>{
  const n=new Set(['PA']);
  assert.equal(audit.translationStatus('Bonjour',undefined,n),'missing');
  assert.equal(audit.translationStatus('Bonjour','Bonjour',n),'identical-review');
  assert.equal(audit.translationStatus('PA','PA',n),'neutral');
  assert.equal(audit.translationStatus('Bonjour {{nom}}','Hello {{name}}',n),'invalid-placeholders');
  assert.equal(audit.translationStatus('Demander ({n})','Ask ({k})',n),'invalid-placeholders');
});
test('matrices spécialisées découvertes même avec une langue absente',t=>{
  const rows=['Un ordre gratuit','Free order',null,'免費命令','Бесплатный приказ','무료 명령','أمر مجاني','Ordem gratuita','Kostenloser Befehl'];
  const {dir}=fixture(t,{'i18n/special-resources.js':'const rows='+JSON.stringify([rows])+';',
    'index.html':'<script src="i18n/resources.js"></script><script src="i18n/special-resources.js"></script><button>Un ordre gratuit</button>'});
  const r=audit.build(dir),reg=r.registrations.find(r=>r.fr==='Un ordre gratuit');assert.ok(reg);assert.equal(reg.status.es,'missing');assert.equal(reg.status.ar,'available-unreviewed');
});
test('les tables par langue hors du catalogue central sont recensées',t=>{
  const map=Object.fromEntries(audit.LOCALES.map(l=>[l,{greeting:l==='fr'?'Salut camarade':l+' Salut'}]));
  const {dir}=fixture(t,{'i18n/local-resources.js':'const labels='+JSON.stringify(map)+';'});
  const r=audit.build(dir);assert.ok(r.registrations.some(x=>x.fr==='Salut camarade'&&x.status.ko==='available-unreviewed'));assert.equal(r.registrations.find(x=>x.fr==='Salut camarade').loaded,false);
});
test('entrées à identifiants stables : français et neuf langues recensés sans moteur supplémentaire',t=>{
  const entry={id:'orders.description.fixture',...Object.fromEntries(audit.LOCALES.map(l=>[l,l==='fr'?'Un ordre stable':l+' A stable order']))};
  const {dir}=fixture(t,{'i18n/nouveau-resources.js':'const rows='+JSON.stringify([entry])+';'});
  const r=audit.build(dir),e=r.registrations.find(r=>r.key===entry.id);assert.ok(e);assert.equal(e.status.ru,'available-unreviewed');assert.equal(e.fr,entry.fr);
});
test('la liste technique des neuf codes de langue n’est pas une matrice de textes',t=>{
  const {dir}=fixture(t,{'i18n/local-resources.js':'const LANGUES='+JSON.stringify(audit.LOCALES)+';'});
  const r=audit.build(dir);assert.ok(!r.registrations.some(r=>r.fr==='fr'));
});
test('traducteur exporté et wrapper transparents reconnus sans importer le métier',t=>{
  const map=Object.fromEntries(audit.LOCALES.map(l=>[l,{hello:l==='fr'?'Un guide très bavard':l+' A talkative guide'}]));
  const {dir}=fixture(t,{'i18n/guide-resources.js':`(function(global){const texts=${JSON.stringify(map)}; function text(key){const original=texts.fr[key];const locale=global.RPPlateauI18n?.language?.()||'fr';return texts[locale]?.[key]||original;} global.texteGuide=text;})(window);`,
    'index.html':'<script src="i18n/resources.js"></script><script src="i18n/guide-resources.js"></script><script src="plateau-test.js"></script>',
    'plateau-test.js':"function guideTexte(key){return texteGuide(key);} el.textContent=guideTexte('hello');"});
  const r=audit.build(dir);assert.equal(r.entries.find(e=>e.text==='Un guide très bavard').locales.ru,'wired-unreviewed');
});
test('un faux traducteur renvoyant toujours le français ne constitue pas une preuve',t=>{
  const map=Object.fromEntries(audit.LOCALES.map(l=>[l,{hello:l==='fr'?'Un guide très bavard':l+' A talkative guide'}]));
  const {dir}=fixture(t,{'i18n/guide-resources.js':`(function(global){const texts=${JSON.stringify(map)}; function text(key){return texts.fr[key];} global.texteGuide=text;})(window);`,
    'index.html':'<script src="i18n/resources.js"></script><script src="i18n/guide-resources.js"></script><script src="plateau-test.js"></script>',
    'plateau-test.js':"el.textContent=texteGuide('hello');"});
  const r=audit.build(dir);assert.ok(!r.entries.some(e=>e.text==='Un guide très bavard'&&e.locales.en==='wired-unreviewed'));
});
test('HTML concaténé : texte et accessibilité conservés, balises/CSS exclus',t=>{
  const {dir}=fixture(t,{'plateau-test.js':`el.innerHTML='<button title="Détails">' + nom + ' Payer</button>'; el.textContent='padding:2px;color:red';`});
  const r=audit.build(dir);assert.ok(r.entries.some(e=>e.text==='Détails'));assert.ok(r.entries.some(e=>e.text==='{DYNAMIC} Payer'));
  assert.ok(!r.entries.some(e=>/padding:|<button|title=/.test(e.text)));assert.ok(r.dynamicSites.length>0);
});
test('un placeholder isolé n’est pas un texte et une notification marquée garde une preuve de raccordement',t=>{
  const {dir}=fixture(t,{'plateau-test.js':`el.innerHTML='<span>'+nom+'</span>'; function notify(){showToast('Titre','Partir',false);window.RPI18nPlateau?.markToast('ui.go','Partir');}`});
  const r=audit.build(dir);assert.ok(!r.entries.some(e=>e.text==='{DYNAMIC}'));assert.equal(r.entries.find(e=>e.text==='Partir').locales.en,'wired-unreviewed');
});
test('les variantes de notification sont prouvées seulement si les mêmes conditions sélectionnent clé et français',t=>{
 const resources=Object.fromEntries(audit.LOCALES.map(l=>[l,{translation:{ui:{go:l==='fr'?'Partir':l+' Go',welcome:l==='fr'?'Bonjour':l+' Hello'}}}]));
 const {dir}=fixture(t,{'i18n/resources.js':'window.RP_I18N_RESOURCES='+JSON.stringify(resources)+';','plateau-test.js':`function notify(){showToast('Titre',ok?'Partir':'Bonjour',false);window.RPI18nPlateau?.markToast(ok?'ui.go':'ui.welcome',ok?'Partir':'Bonjour');}`});
 const a=audit.build(dir);for(const text of ['Partir','Bonjour'])assert.equal(a.entries.find(e=>e.text===text).locales.en,'wired-unreviewed');
 fs.writeFileSync(path.join(dir,'plateau-test.js'),`function notify(){showToast('Titre',ok?'Partir':'Bonjour',false);window.RPI18nPlateau?.markToast(other?'ui.go':'ui.welcome',ok?'Partir':'Bonjour');}`);
 const b=audit.build(dir);assert.notEqual(b.entries.find(e=>e.text==='Bonjour').locales.en,'wired-unreviewed');
});
test('patch de catalogue après définition : pas de faux manque provenant d’une ancienne table',t=>{
  const {dir}=fixture(t,{'i18n/resources.js':`window.RP_I18N_RESOURCES={fr:{translation:{go:'Partir'}},en:{translation:{go:'Go'}},es:{translation:{}}}; window.RP_I18N_RESOURCES.es.translation.go='Salir';`});
  const r=audit.build(dir);assert.equal(r.resourceHealth.es.missing,0);assert.equal(r.registrations.filter(x=>x.fr==='Partir').length,1);
});
test('garde des guides : aucune traduction prouvée si la référence française a changé',t=>{
  const {dir}=fixture(t,{'plateau-personnage.js':`const REGLES={intro:{titre:'Un guide',contenu:'Un récit de référence'}}; function cle(section,champ){const key='guide.'+section+'.'+champ;return key;}`,
    'index.html':'<script src="i18n/resources.js"></script><script src="plateau-personnage.js"></script>',
    'i18n/guide-integrity.js':'window.RPGuideIntegrity={valid:()=>false};'});
  const r=audit.build(dir);assert.ok(r.registrations.some(r=>r.format==='guide-source'));assert.ok(r.entries.filter(e=>['Un guide','Un récit de référence'].includes(e.text)).every(e=>e.locales.en!=='wired-unreviewed'));
});
test('un nouveau catalogue de pays est découvert et pris en compte par le résolveur',t=>{
  const row=audit.LOCALES.map(l=>l==='fr'?'Un ordre à découvrir':l+' Discover an order');
  const {dir}=fixture(t,{
    'index.html':'<script src="i18n/resources.js"></script><script src="i18n/nouveau-pays-resources.js"></script><script src="i18n/sovarka-infobulles-resources.js"></script><script src="data.js"></script>',
    'i18n/nouveau-pays-resources.js':'window.RP_EXTRA='+JSON.stringify([row])+';',
    'i18n/sovarka-infobulles-resources.js':`window.RPSovarkaInfobullesI18n={desc(text){const row=window.RP_EXTRA.find(r=>r[0]===text);return row?row[${JSON.stringify(audit.LOCALES)}.indexOf(window.RPPlateauI18n.language())]:text;}};`,
    'data.js':"const WORLD = {republic:{capitale:{buildings:['test']}}};\nconst BUILDINGS = {test:{rooms:{hall:{orders:[{fn:'demo',label:'Agir',desc:'Un ordre à découvrir'}]}}}};"
  });
  const r=audit.build(dir);assert.deepEqual(r.extractionErrors,[]);
  const e=r.entries.find(e=>e.text==='Un ordre à découvrir');for(const l of audit.LOCALES.slice(1))assert.equal(e.locales[l],'wired-unreviewed');
});
test('français absent du catalogue et instructions IA restent des périmètres explicites',t=>{
  const {dir}=fixture(t,{'api/_pnj-profils.js':"const prompt = 'Vous êtes un guide très bavard';",'plateau-inactif.js':"const texte = 'Une quête inconnue reste ici';"});
  const r=audit.build(dir);assert.ok(r.entries.some(e=>e.certainty==='ai-context-not-output'));assert.ok(r.entries.some(e=>e.certainty==='candidate-review'));
});
test('aucune lecture des instantanés joueurs ou seeds, aucun accès réseau dans le VM',t=>{
  const {dir}=fixture(t,{'.scratch/personnages.json':'{"nom":"PERSONNE_PRIVEE_INVENTEE"}', 'baseline/seeds/joueurs.sql':"SELECT 'PERSONNE_PRIVEE_INVENTEE';",'i18n/test-resources.js':"fetch('https://example.invalid');"});
  const r=audit.build(dir);assert.ok(!JSON.stringify(r).includes('PERSONNE_PRIVEE_INVENTEE'));assert.ok(r.extractionErrors.some(e=>/fetch is not defined/.test(e.error)));
});
test('analyse reproductible, sources identiques avant/après, erreur de syntaxe explicite',t=>{
  const {dir,files}=fixture(t);const first=audit.build(dir),second=audit.build(dir);assert.deepEqual(first,second);
  for(const [file,source]of Object.entries(files))assert.equal(fs.readFileSync(path.join(dir,file),'utf8'),source);
  fs.writeFileSync(path.join(dir,'plateau-test.js'),'const = ;');assert.ok(audit.build(dir).extractionErrors.length>0);
});
test('variations : ajout, suppression, progrès de langue, changement d’exclusion traçables',t=>{
  const {dir}=fixture(t);const before=audit.build(dir);
  fs.writeFileSync(path.join(dir,'plateau-test.js'),"el.textContent='Nouvelle mission';");
  const after=audit.build(dir),delta=audit.compare(before,after);assert.equal(delta.added.length,1);assert.equal(delta.removed.length,2);assert.equal(delta.sameScope,true);
  after.policy.version++;assert.equal(audit.compare(before,after).sameScope,false);
});
test('inventaire actif : même fusion que le jeu, héritage, contexte, exclusions et ajouts',t=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8'),start=data.indexOf('function ordresDeclaresDeLaPiece('),fn=data.slice(start,data.indexOf('\n}',start)+2);
 const {dir}=fixture(t,{'data.js':fn+`\nconst BUILDINGS = {site:{rooms:{hall:{orders:[{fn:'heritage',desc:'Description héritée'},{fn:'retire',desc:'Description exclue'}]},cache:{orders:[{fn:'cache',desc:'Pièce exclue'}]}}}};
const WORLD = {republic:{ville:{buildings:['site'],buildingContext:{site:{roomsExclues:['cache'],orders:[{fn:'contexte',desc:'Description du contexte'}],roomOverrides:{hall:{excludeOrders:['retire'],orders:[{fn:'ajout',desc:'Description ajoutée'}],ordersExtra:[{fn:'extra',desc:'Description supplémentaire'}]}}}}}}};`});
 const r=audit.build(dir);assert.deepEqual(r.extractionErrors,[]);
 const active=r.entries.filter(e=>e.occurrences.some(o=>o.kind==='active-order-desc')).map(e=>e.text).sort();
 assert.deepEqual(active,['Description héritée','Description du contexte','Description ajoutée','Description supplémentaire'].sort(),JSON.stringify({sources:r.sourceFiles,entries:r.entries.map(e=>({text:e.text,kinds:e.occurrences.map(o=>o.kind)}))}));
});
