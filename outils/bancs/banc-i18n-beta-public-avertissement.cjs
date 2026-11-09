'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function read(file){return fs.readFileSync(path.join(root,file),'utf8')}
const ctx={window:{}};
vm.createContext(ctx);
for(const file of ['i18n/resources.js','i18n/beta-language-notice.js'])vm.runInContext(read(file),ctx,{filename:file});
test('les neuf locales présentent sans ambiguïté le repli en français et la jouabilité',()=>{
 const resources=ctx.window.RP_I18N_RESOURCES;
 assert.deepEqual(Object.keys(ctx.window.RP_I18N_LANGUAGES),langs);
 for(const locale of langs){
  const text=resources[locale]?.translation?.betaLanguage?.notice;
  assert.equal(typeof text,'string',locale);
  assert.ok(text.length>60,locale);
  assert.ok(!/<[^>]+>/.test(text),locale+': aucun HTML de traduction');
 }
 for(const locale of langs) assert.equal(typeof resources[locale].translation.home.createCharacter,'string');
});
test('l information se trouve sur accueil et plateau avec la même clé',()=>{
 const home=read('index.html'),plateau=read('plateau.html');
 assert.match(home,/id="i18n-beta-notice-home"[^>]*data-i18n="betaLanguage.notice"/);
 assert.match(plateau,/id="i18n-beta-notice-plateau"[^>]*data-i18n="betaLanguage.notice"/);
 for(const html of [home,plateau]){
  const resourcesAt=html.indexOf('src="i18n/resources.js');
  const noticeAt=html.indexOf('src="i18n/beta-language-notice.js');
  const initAt=html.indexOf('src="i18n/'+(html===home?'i18n-init':'plateau-init')+'.js');
  assert.ok(resourcesAt>=0&&noticeAt>resourcesAt&&initAt>noticeAt,
    'ressources, notice, puis initialisation');
 }
});
test('activation du jeu ne touche pas aux mécanismes de traduction privée',()=>{
 const plateau=read('plateau.html');
 assert.match(plateau,/window\.RP_I18N_GAME_ENABLED\s*=\s*true/);
 assert.match(read('i18n/plateau-bridge.js'),/RP_I18N_GAME_ENABLED\s*!==\s*true/);
 assert.match(read('api/_pnj-profils.js'),/process\.env\.RP_I18N_GAME_ENABLED\s*===\s*'true'/);
 assert.doesNotMatch(read('i18n/beta-language-notice.js'),/\.fetch\(|\bRPC\b|sb[A-Z]/);
});
