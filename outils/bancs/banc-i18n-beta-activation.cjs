'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const plateau=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const init=fs.readFileSync(path.join(root,'i18n/plateau-init.js'),'utf8');
const bridge=fs.readFileSync(path.join(root,'i18n/plateau-bridge.js'),'utf8');

test('la beta active les neuf langues avant le pont et le moteur plateau',()=>{
 const enabled=plateau.indexOf('window.RP_I18N_GAME_ENABLED = true;');
 const startup=plateau.indexOf('src="i18n/plateau-bridge.js');
 const engine=plateau.indexOf('src="i18n/plateau-init.js');
 assert.ok(enabled>=0,'activation du plateau absente');
 assert.ok(startup>enabled,'la garde doit précéder la résolution de langue');
 assert.ok(engine>startup,'initialisation après le pont');
 assert.match(init,/const supported=global\.RP_I18N_GAME_ENABLED === true/);
 assert.match(bridge,/if\(global\.RP_I18N_GAME_ENABLED !== true\)return 'fr'/);
});

test('la traduction privée des contenus sociaux reste désactivée et non exposée',()=>{
 const contents=fs.readFileSync(path.join(root,'api/_traduction-contenu.js'),'utf8');
 const translation=fs.readFileSync(path.join(root,'api/_traduction.js'),'utf8');
 assert.match(contents,/readUnderRls/);
 assert.match(contents,/reserveBudget/);
 assert.doesNotMatch(contents,/export\s+default\s+(?:async\s+)?function\s+handler/);
 assert.doesNotMatch(translation,/export\s+default\s+(?:async\s+)?function\s+handler/);
 const config=fs.readFileSync(path.join(root,'api/_pnj-profils.js'),'utf8');
 assert.match(config,/RP_I18N_GAME_ENABLED/);
});
