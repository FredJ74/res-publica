'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const src=fs.readFileSync(path.join(root,'plateau-quete-accueil.js'),'utf8');
const win={};let lang='fr';win.RPPlateauI18n={language:()=>lang};
win.i18next={t:(k,{lng,defaultValue}={})=>k.split('.').reduce((v,key)=>v?.[key],win.RP_I18N_RESOURCES?.[lng]?.translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','jeremy-scenes-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const texts={
 introduceMyself:'Me présenter',later:'Plus tard',forumTitlePrefix:'Présentation de ',
 jeremyMailFallback:'Oh, vous avez besoin de moi ? Je suis sur la Place du Marché, venez me chercher !',
 newMailTitle:'Nouveau mail',jeremyReplied:'Jérémy vous a répondu !',
 replyLanguageInstruction:'Réponds EXCLUSIVEMENT en français.'
};
test('présentation au forum et courrier Jérémy : sept clés en neuf langues',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=locale;
  for(const [key,original] of Object.entries(texts)){
   const value=win.RP_I18N_RESOURCES[locale].translation.jeremyScenes[key];
   assert.ok(value?.trim(),locale+': '+key);
   assert.equal(win.RPJeremyScenesI18n.label(key,original),value,locale+': '+key);
  }
  assert.ok((win.RPJeremyScenesI18n.label('forumTitlePrefix',texts.forumTitlePrefix)+'Arnie').includes('Arnie'));
  assert.ok(!win.RPJeremyScenesI18n.label('replyLanguageInstruction',texts.replyLanguageInstruction).includes('{{'));
 }
});
test('choix forum, sujet prérempli et provenance restent exactement ceux du serveur',()=>{
 for(const [key,callback] of [['introduceMyself','queteAccueilLancerPresentationForum()'],
   ['later','queteAccueilIgnorerPresentationForum()']]){
  assert.ok(src.includes("rpQueteTexte('"+key+"'"),key);
  assert.ok(src.includes(callback),callback);
 }
 for(const key of ['forumTitlePrefix','jeremyMailFallback','newMailTitle','jeremyReplied','replyLanguageInstruction'])
  assert.ok(src.includes("rpQueteTexte('"+key+"'"),key);
 assert.ok(src.includes("if (titleEl) titleEl.value = rpQueteTexte('forumTitlePrefix'"));
 assert.ok(src.includes("state.char.queteAccueil = { etape: 'presentation_en_cours' }"));
 assert.ok(src.includes("state.char.queteAccueil = { etape: 'presentation_ignoree' }"));
 assert.ok(src.includes("state.char.queteAccueil = { etape: 'presentation_publiee' }"));
 assert.ok(src.includes("if (typeof onboardingArmerComposeCanvas === 'function') onboardingArmerComposeCanvas()"));
 assert.ok(src.includes("const r = await rpRedaction('quete_accueil_jeremy', prompt)"));
 assert.ok(src.includes("sbSendMail('Jérémy', state.char.name, sujetReponse, reply, heure)"));
 assert.ok(src.includes("const sujetReponse = 'Re: ' + subjectRecu"));
});
test('la langue de réponse seule varie, sans autorité du navigateur sur la publication',()=>{
 lang='ru';
 const ru=win.RPJeremyScenesI18n.label('replyLanguageInstruction',texts.replyLanguageInstruction);
 assert.match(ru,/русском/);
 const fallback=win.RPJeremyScenesI18n.label('unknown','Texte serveur');
 assert.equal(fallback,'Texte serveur');
 assert.ok(src.includes('const titleEl = document.getElementById'));
 assert.ok(!src.includes('submitComposeCanvas('));
});
