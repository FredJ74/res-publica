'use strict';
// Tests de présentation pure, ni navigation ni serveur ni compte joueur.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const room=read('i18n/room-resources.js');
const shared=read('i18n/common-room-resources.js');
const html=read('plateau.html');
const audit=read('outils/audits/audit-i18n-editorial.cjs');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fixture(locale='fr',active=true,sovarkaLabel=null){
 const refs=Object.fromEntries(langs.map(x=>[x,{translation:{}}]));
 let lang=locale,enabled=active;
 const global={
   RP_I18N_RESOURCES:refs,
   RPPlateauI18n:{language:()=>lang},
   get RP_I18N_GAME_ENABLED(){return enabled;},
   i18next:{t:(key,{defaultValue})=>defaultValue},
   RPSovarkaPiecesI18n:sovarkaLabel?{label:sovarkaLabel}:null
 };
 const ctx=vm.createContext({window:global});
 vm.runInContext(room,ctx,{filename:'room-resources.js'});
 vm.runInContext(shared,ctx,{filename:'common-room-resources.js'});
 return{global,refs,setLang:x=>{lang=x;},enable:x=>{enabled=x;},label:(b,r,name)=>global.RPRoomI18n.label(b,r,name)};
}
test('59 intitulés dans neuf langues et 118 paires bâtiment/pièce validées',()=>{
 const f=fixture();
 for(const lang of langs){
  const words=f.refs[lang].translation.commonRoomLabels;
  assert.equal(Object.keys(words).length,59,lang);
  for(const [key,value] of Object.entries(words)){
   assert.ok(key.length>0&&value.length>0,lang+':'+key);
   assert.ok(!/[{}]/.test(value),'aucune variable de moteur dans les titres '+key);
  }
 }
 assert.equal(f.global.RPCommonRoomI18n.scopes.size,118);
});
test('noms de gabarit traduits, de la mairie au tribunal, dans neuf langues',()=>{
 for(const lang of langs){
  const f=fixture(lang);
  const words=f.refs[lang].translation.commonRoomLabels;
  for(const [building,room,title] of [
   ['tribunal','greffe','Greffe'],
   ['tribunal-local','salle_audience_locale',"Salle d'audience"],
   ['mairie-capitale','salle_elections','Salle des Elections'],
   ['commissariat-local','geoles','Geôles'],
   ['banque-locale','guichet','Guichet'],
   ['port-sainte-marie','capitainerie','Capitainerie'],
   ['centre-multinodal-montrouge','hall_gare_montrouge','Hall de la Gare'],
   ['caserne-militaire','refectoire','Réfectoire'],
   ['bureau-national-emploi','accueil','Accueil'],
   ['imprimerie-librairie','atelier',"Atelier d'Imprimerie"]
  ]){
   assert.equal(f.label(building,room,title),lang==='fr'?title:words[title],lang+':'+building+':'+room);
  }
 }
});
test('couples inconnus, noms changés et enseignes de joueurs inchangés',()=>{
 for(const lang of langs){
  const f=fixture(lang);
  assert.equal(f.label('banque-locale','guichet','Guichet du Syndicat'),'Guichet du Syndicat');
  assert.equal(f.label('autre-batiment','accueil','Accueil'),'Accueil');
  assert.equal(f.label('tribunal','autre','Greffe'),'Greffe');
  assert.equal(f.label('centre-affaires','bureau_prestige','La maison de Léa'),'La maison de Léa');
  assert.equal(f.label('port-novomirsk','quai_sovarka','Quai du Peuple'),'Quai du Peuple');
 }
});
test('français et beta multilingue désactivée : rendu strictement conservé',()=>{
 const f=fixture('fr');
 assert.equal(f.label('tribunal','greffe','Greffe'),'Greffe');
 f.setLang('en');f.enable(false);
 assert.equal(f.label('tribunal','greffe','Greffe'),'Greffe');
 f.enable(true);
 assert.equal(f.label('tribunal','greffe','Greffe'),'Court registry');
});
test('les variantes propres à Sovarka gagnent sur le socle partagé',()=>{
 const f=fixture('en',true,(_,__,name)=>name==='Accueil'?'Sovarka-specific reception':name);
 assert.equal(f.label('bureau-national-emploi','accueil','Accueil'),'Sovarka-specific reception');
});
test('les onglets ouverts disposent déjà de la traduction à chaud, sans requête réseau',()=>{
 assert.match(read('plateau-navigation.js'),/RPRefreshOpenRoomNames/);
 assert.match(read('plateau-navigation.js'),/data-rp-room-source/);
 assert.match(read('plateau-navigation.js'),/RPRoomI18n\.label\(building,room,source\)/);
 assert.match(html,/i18n\/common-room-resources\.js\?v=20261112/);
 assert.ok(html.indexOf('room-resources.js?v=pieces-communes')<
           html.indexOf('common-room-resources.js?v=20261112'));
 assert.match(audit,/common-room-resources\.js/);
});
