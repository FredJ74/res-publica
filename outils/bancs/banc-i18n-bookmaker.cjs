'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const resources=read('i18n/sport-bets-resources.js');
const sport=read('plateau-organisations-quetes.js');
const html=read('plateau.html');
const languages=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(locale,enabled=true) {
  const window={RP_I18N_GAME_ENABLED:enabled,RPPlateauI18n:{language:()=>locale},RP_I18N_RESOURCES:{}};
  for(const lang of languages)window.RP_I18N_RESOURCES[lang]={translation:{}};
  const c=vm.createContext({window,console,Date,Intl,Number,Object});
  vm.runInContext(resources,c);
  return {window,c};
}
test('29 textes et placeholders identiques dans les 9 langues',()=>{
 const base=setup('fr').window.RP_I18N_RESOURCES.fr.translation.sportBets;
 assert.equal(Object.keys(base).length,29);
 for(const lang of languages){
  const v=setup(lang).window.RP_I18N_RESOURCES[lang].translation.sportBets;
  assert.deepEqual(Object.keys(v),Object.keys(base),lang);
  for(const key of Object.keys(base)){
   assert.ok(typeof v[key]==='string'&&v[key].trim(),lang+':'+key);
   const vars=x=>(x.match(/\{[a-z]+\}/g)||[]).sort();
   assert.deepEqual(vars(v[key]),vars(base[key]),lang+':'+key);
  }
 }
});
test('le pont respecte la langue, la désactivation et les paramètres',()=>{
 const ru=setup('ru');
 assert.equal(ru.window.RPSportBetsI18n.text('confirm'),'Сделать ставку');
 assert.equal(ru.window.RPSportBetsI18n.text('stake',{currency:'PSK'}),'Ставка (PSK)');
 assert.equal(ru.window.RPSportBetsI18n.text('betDay',{day:3}),'Ставка — тур 3');
 const fr=setup('ar',false);
 assert.equal(fr.window.RPSportBetsI18n.text('confirm'),'Valider le pari');
 assert.equal(fr.window.RPSportBetsI18n.text('stake',{currency:'FR'}),'Mise (FR)');
 assert.equal(ru.window.RPSportBetsI18n.html('win',{club:'<A&B>'}),'Победа &lt;A&amp;B&gt;');
});
test('formulaire bookmaker réellement traduit sans modifier identifiants, mise ni callbacks',()=>{
 const start=sport.indexOf('function texteBookmaker(');
 const begin=sport.indexOf('function ouvrirFormulairePari(',start);
 const end=sport.indexOf('async function confirmerPariMatch(',begin);
 assert.ok(start>=0&&begin>start&&end>begin);
 const helper=sport.slice(start,sport.indexOf('async function doParierMatch(',start));
 const impl=sport.slice(begin,end);
 assert.ok(html.includes('i18n/sport-bets-resources.js'));
 for(const lang of languages){
  const {window,c}=setup(lang);
  let body='',title='';
  const nodes={'postes-modal-title':{set textContent(v){title=v}},
    'postes-body':{set innerHTML(v){body=v}},
    'modal-postes':{classList:{add(){}}}};
  Object.assign(c,{getClub:id=>({nom:id}),state:{country:'soviet'},
    COUNTRIES:{soviet:{cur:'PSK'}},document:{getElementById:id=>nodes[id]}});
  vm.runInContext(helper+'\n'+impl,c);
  vm.runInContext("ouvrirFormulairePari('home-id','away-id',0,1,1,0,'quarts_aller')",c);
  const t=window.RP_I18N_RESOURCES[lang].translation.sportBets;
  assert.equal(title,t.betMatch);
  assert.ok(body.includes(t.prediction),lang+':prediction');
  assert.ok(body.includes(t.confirm),lang+':confirm');
  assert.ok(body.includes(t.stake.replace('{currency}','PSK')),lang+':stake');
  assert.ok(body.includes(t.win.replace('{club}','home-id')),lang+':win');
  assert.ok(body.includes(t.draw),lang+':draw');
  assert.match(body,/id="pari-choix" value="domicile"/);
  assert.match(body,/id="pari-mise" type="number" value="10" min="10"/);
  assert.ok(body.includes("confirmerPariMatch("),lang+':RPC handler');
  assert.ok(body.includes("'quarts_aller'"),lang+':manche');
 }
});
test('l’internationalisation ne change pas les ordres métier ni les RPC',()=>{
 for(const name of ['football_pari_engager','football_pari_playoff_engager','football_pari_playoff_resoudre'])
  assert.ok(sport.includes(name));
 assert.ok(sport.includes("p_choix:choix, p_mise:mise"));
 assert.ok(sport.includes("await reglerParisPlayoff(etapeAvant)"));
});
