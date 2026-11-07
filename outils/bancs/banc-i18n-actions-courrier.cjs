'use strict';
/* Libellés des 16 ordres reçus par courrier : le marqueur/action reste serveur. */
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const forum=fs.readFileSync(path.join(root,'forum.js'),'utf8');
const win={};let locale='fr';
win.RPPlateauI18n={language:()=>locale};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[lng]?.translation)??defaultValue};
const context=vm.createContext({window:win});
for(const file of ['resources.js','forum-ui.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),context);
const original=win.RP_I18N_RESOURCES.fr.translation.mailActions;
test('16 boutons d'action de courriers localisés dans neuf langues',()=>{
 assert.equal(Object.keys(original).length,16);
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
  locale=lang;
  const words=win.RP_I18N_RESOURCES[lang].translation.mailActions;
  assert.deepEqual(Object.keys(words).sort(),Object.keys(original).sort(),lang);
  for(const [id,canonical] of Object.entries(original)){
   assert.equal(win.RPForumUI.mailActionLabel(id,canonical),words[id],lang+': '+id);
   assert.ok(words[id]?.trim());
  }
 }
});
test('ni marqueur, ni nom de handler, ni args modifiés et texte inattendu conservé',()=>{
 locale='ru';
 for(const [id,label] of [
  ['unknown','✓ Accepter le poste'],['poste','Accepter le poste'],
  ['poste','✓ Accepter le poste (100 FR)']
 ])assert.equal(win.RPForumUI.mailActionLabel(id,label),label);
 assert.ok(forum.includes("escapeHtmlText(rpActionMailLabel(a.cle,def.label))"));
 assert.ok(forum.includes("const def = ACTIONS_MAIL[a.cle]"));
 assert.ok(forum.includes("def.fn + '(' + args.join(',')"));
 assert.ok(forum.includes("a.args.slice(0, def.n)"));
 assert.ok(forum.includes("marqueurActionMail(cle, ...args)"));
 assert.ok(forum.includes("const _actionsMail = extraireActionsMail(mail.body || '')"));
});
