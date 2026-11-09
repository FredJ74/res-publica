'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const src=read('plateau-navigation.js');
const win={RPPlateauI18n:{language:()=>'fr'}};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((o,k)=>o?.[k],win.RP_I18N_RESOURCES?.[lng]?.translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['i18n/resources.js','i18n/toast-resources.js'])
 vm.runInContext(read(file),ctx,{filename:file});
const idTitles={
 movementUnconfirmed:'Déplacement non confirmé',intercepted:'Interpellé(e) !',
 arrested:'Arrêté(e) !',imprisoned:'Emprisonné(e)',buildingClosed:'Bâtiment fermé',
 visitDenied:'Visite refusée',republicanGuard:'Garde republicaine',troopsSpotted:'Troupes repérées',
 inspectionUnconfirmed:'Contrôle non confirmé',customsInspection:'Contrôle douanier',
 inspectionDenied:'Contrôle refusé',inspectionConfirmed:'Contrôle confirmé',
 journeyUnconfirmed:'Voyage non confirmé',journeyRegistered:'Voyage enregistré',
 journeyConfirmed:'Voyage confirmé',attemptNotSent:'Tentative non envoyée',
 attemptUnconfirmed:'Tentative non confirmée',attemptDenied:'Tentative refusée',
 attemptRegistered:'Tentative enregistrée',attemptFailed:'Tentative échouée',
 smugglingSucceeded:'Contrebande réussie !',smugglingDetected:'Contrebande détectée !',
 inspectionCompleted:'Inspection terminée',inspectionNoResult:'Inspection sans résultat',
 blockadeUnavailable:'Blocus indisponible',inspectionAlreadyHandled:'Inspection déjà traitée',
 failedWithPunctuation:'Échec !'
};
test('27 alertes d opérations réelles, françaises canoniques, présentes en neuf langues',()=>{
 const langs=Object.keys(win.RP_I18N_LANGUAGES);
 assert.equal(langs.length,9);
 assert.equal(Object.keys(idTitles).length,27);
 for(const [key,original] of Object.entries(idTitles)){
  assert.ok(src.includes(original),'titre non déclaré dans navigation : '+original);
  assert.equal(win.RP_I18N_RESOURCES.fr.translation.toastTitles[key],original,key);
  for(const lang of langs){
   const translation=win.RP_I18N_RESOURCES[lang].translation.toastTitles[key];
   assert.ok(typeof translation==='string'&&translation.trim(),lang+'/'+key);
   win.RPPlateauI18n.language=()=>lang;
   assert.equal(win.RPToastI18n.label(original),translation,lang+'/'+key);
  }
 }
});
test('aucune notification dynamique, accusé serveur, montant ou incident retraduit',()=>{
 win.RPPlateauI18n.language=()=>'ko';
 for(const title of [
  'Voyage confirmé : 2 PJ', 'Contrôle refusé : 150 PSK',
  'Client : <script>alert(1)</script>','Titre d un joueur',''
 ])assert.equal(win.RPToastI18n.label(title),title);
 const core=read('plateau-core.js');
 const from=core.indexOf('function showToast(result, msg, success, isCrit)');
 const to=core.indexOf('// =====================',from);
 assert.ok(from>=0&&to>from);
 const body=core.slice(from,to);
 assert.ok(body.includes("noterIncidentSession('notification', result)"));
 assert.ok(body.includes('toast-sub').valueOf());
 assert.match(body,/textContent = msg/);
 assert.match(body,/RPToastI18n\.label\(result\)/);
 assert.ok(!body.includes('innerHTML'));
});
