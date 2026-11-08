'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'plateau-quete-accueil.js'),'utf8');
const page=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const win={};let language='fr';
win.RPPlateauI18n={language:()=>language};
win.i18next={t:(key,{lng,defaultValue}={})=>
 key.split('.').reduce((r,k)=>r?.[k],win.RP_I18N_RESOURCES?.[lng]?.translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','guard-welcome-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const ids=['guardWarning','playerAsks','guardDirections','playerThanks',
 'hostileTitle','friendlyTitle','you'];
test('quatre répliques et trois titres de la garde dans neuf langues',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  language=locale;
  const labels=win.RP_I18N_RESOURCES[locale].translation.guardWelcome;
  assert.deepEqual(Object.keys(labels).sort(),ids.slice().sort());
  for(const id of ids){
   const original=win.RP_I18N_RESOURCES.fr.translation.guardWelcome[id];
   assert.ok(labels[id]?.trim(),locale+': '+id);
   assert.equal(win.RPGuardWelcomeI18n.label(id,original),labels[id],locale+': '+id);
   assert.ok(!/<(?!br\s*\/?\s*>|strong>|\/strong>)/i.test(labels[id]),locale+': HTML contrôlé');
  }
  assert.equal((labels.guardDirections.match(/<strong>/g)||[]).length,2,locale+': personnages et arrivée');
  assert.equal((labels.guardDirections.match(/<br><br>/g)||[]).length,3,locale+': paragraphes de guidage');
 }
});
test('les quatre étapes de dialogue et les flèches restent celles du moteur français',()=>{
 const start=source.indexOf('function demarrerQueteAccueil()');
 const end=source.indexOf('function terminerEtapeGardeQueteAccueil()');
 const scene=source.slice(start,end);
 for(const id of ids)assert.ok(scene.includes("rpQueteGuardTexte('"+id+"'"),id);
 for(const name of ['afficherPopupQueteAccueilEtape2','afficherPopupQueteAccueilEtape3',
    'afficherPopupQueteAccueilEtape4','terminerEtapeGardeQueteAccueil']){
  assert.ok(scene.includes(name),name);
 }
 assert.ok(source.includes("state.char.queteAccueil = { etape: 'garde_en_cours' }"));
 assert.ok(source.includes("state.char.queteAccueil = { etape: 'guide_carrefour' }"));
 assert.ok(source.includes("afficherGuidageFleche('luthecia-palais-presidentiel', 'droite')"));
 assert.ok(page.indexOf('src="i18n/guard-welcome-resources.js')>0);
 assert.ok(page.indexOf('src="i18n/guard-welcome-resources.js')<
   page.indexOf('src="i18n/plateau-init.js'));
});
test('nom et phrases inconnus ne sont pas changés, HTML extérieur refusé',()=>{
 language='ru';
 assert.equal(win.RPGuardWelcomeI18n.label('you','Arnie'),'Arnie');
 assert.equal(win.RPGuardWelcomeI18n.label('guardWarning','Nouvelle version'), 'Nouvelle version');
 const old=win.i18next.t;
 win.i18next.t=()=>'<script>alert(1)</script>';
 const original=win.RP_I18N_RESOURCES.fr.translation.guardWelcome.guardWarning;
 assert.equal(win.RPGuardWelcomeI18n.label('guardWarning',original),original);
 win.i18next.t=old;
});
