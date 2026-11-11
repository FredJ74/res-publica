'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=n=>fs.readFileSync(path.join(root,n),'utf8');
const source=read('plateau-escorts-agence.js'),resource=read('i18n/social-agency-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(lang='fr',active=true){
 let redraw=null,opened=false;
 const requests=[],toasts=[],entries=[],external=[];
 const modale={classList:{add(){opened=true},remove(){opened=false},contains:()=>opened}};
 let inner='';
 const corps={get innerHTML(){return inner},set innerHTML(x){inner=x},querySelector:s=>s==='[data-social-agency-gallery]'&&inner.includes('data-social-agency-gallery')?{}:null};
 const controls={
 'postes-modal-title':{textContent:''},'postes-body':corps,'modal-postes':modale,
 'modal-pnj':{classList:{remove(){}}}
 };
 const context={window:null,console,document:{getElementById:id=>controls[id]||null},
 RP_I18N_GAME_ENABLED:active,RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}])),
 RPPlateauI18n:{language:()=>context.locale},locale:lang,
 i18next:{on(name,fn){if(name==='languageChanged')redraw=fn}},
 state:{country:'republic',day:1,char:{name:'Joueur'},employes:[],group:{members:[]}},
 escapeHtmlText:s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),
 sbEscortsAgence:async()=>{requests.push(['catalogue']);return {ok:true,pays:'republic',agence:'Agence de PSM',escorts:[{escort_id:'personne-fixture',genre:'femme',nom:'Rita <test>',vignette:'fixture.webp',portrait:'fixture.webp',cadrage:'50% 15%'}]}},
 sbEscortSocialeActuelle:async()=>{requests.push(['confidente']);return {ok:true,escort_id:null}},
 sbEscortSocialeChoisir:async id=>{requests.push(['choix',id]);return {ok:true,escort_id:id,nom:'Rita',precedente_nom:null}},
 sbEscortRecruter:async id=>{requests.push(['recruter',id]);return {ok:false,raison:'paiement_refuse'}},
 showToast:(...a)=>toasts.push(a),addJournalEntry:(...a)=>entries.push(a),addExternalEvent:s=>external.push(s),
 openPnjModal:()=>{},encodePnjSafe:x=>x,
 sauvegarderPersonnageImmediat:()=>{},updateUI:()=>{}
 };
 context.window=context;
 vm.createContext(context);
 vm.runInContext(resource,context,{filename:'social-agency-resources.js'});
 vm.runInContext(source,context,{filename:'plateau-escorts-agence.js'});
 return {context,requests,toasts,entries,external,corps,controls,change(l){context.locale=l;redraw?.(l);},get opened(){return opened}};
}
test('28 messages complets, variables et scripts sur les neuf locales',()=>{
 const e=setup(),fr=e.context.RP_I18N_RESOURCES.fr.translation.socialAgency;
 assert.equal(Object.keys(fr).length,28);
 for(const lang of langs){
  const d=e.context.RP_I18N_RESOURCES[lang].translation.socialAgency;
  assert.deepEqual(Object.keys(d).sort(),Object.keys(fr).sort());
  for(const [key,original] of Object.entries(fr)){
    const vars=s=>[...s.matchAll(/\{([a-z]+)\}/g)].map(x=>x[1]).sort();
    assert.ok(d[key]?.trim(),lang+' '+key);
    assert.deepEqual(vars(d[key]),vars(original),lang+' '+key);
  }
 }
 assert.match(html,/i18n\/social-agency-resources\.js\?v=20261111/);
 assert.match(html,/plateau-escorts-agence\.js\?v=i18n-20261111/);
});
test('présentation et frais en neuf langues, candidats et ids serveur conservés',async()=>{
 for(const lang of langs){
  const e=setup(lang);
  await e.context.escortsAgenceOuvrir('femme');
  assert.equal(e.requests.filter(x=>x[0]==='catalogue').length,1);
  assert.ok(e.corps.innerHTML.includes('data-social-agency-gallery'));
  assert.ok(e.corps.innerHTML.includes('Rita &lt;test&gt;'),lang);
  assert.ok(e.corps.innerHTML.includes('personne-fixture'),lang);
  assert.ok(e.corps.innerHTML.includes('9'),lang);
  assert.ok(!e.corps.innerHTML.includes('<test>'),lang);
  if(lang!=='fr')assert.ok(!e.corps.innerHTML.includes('votre confidente'),lang);
  await e.context.escortsAgenceRecruter('personne-fixture');
  assert.deepEqual(e.requests.at(-1),['recruter','personne-fixture']);
  assert.equal(e.context.state.employes.length,0);
  assert.equal(e.toasts.at(-1)[2],false);
  if(lang!=='fr')assert.notEqual(e.toasts.at(-1)[0],'Refusé');
 }
});
test('bascule de langue réaffiche la galerie sans RPC ni perte du casting',async()=>{
 const e=setup('fr');await e.context.escortsAgenceOuvrir('femme');
 const old=e.corps.innerHTML,count=e.requests.length;
 e.change('ko');await Promise.resolve();await Promise.resolve();
 assert.ok(e.corps.innerHTML.includes('선택 가능'));
 assert.ok(e.corps.innerHTML.includes('Rita &lt;test&gt;'));
 assert.equal(e.requests.length,count);
 e.change('fr');await Promise.resolve();await Promise.resolve();
 assert.equal(e.corps.innerHTML,old);assert.equal(e.requests.length,count);
});
test('pas de réouverture de galerie si la fenêtre affiche une autre activité',async()=>{
 const e=setup('fr');await e.context.escortsAgenceOuvrir('femme');
 e.corps.innerHTML='<div id="une-autre-fenetre">Formulaire tiers</div>';
 const n=e.requests.length;e.change('en');await Promise.resolve();
 assert.equal(e.corps.innerHTML,'<div id="une-autre-fenetre">Formulaire tiers</div>');
 assert.equal(e.requests.length,n);
});
test('confidente : nom conservé, choix explicite unique et confirmation localisée',async()=>{
 const e=setup('ru');
 await e.context.escortsAgenceConfidente('personne-fixture');
 assert.deepEqual(e.requests.at(-1),['choix','personne-fixture']);
 assert.ok(e.toasts.at(-1)[0].includes('Rita'));
 assert.equal(e.toasts.at(-1)[2],true);
 assert.ok(e.entries.at(-1)[0].includes('Rita'));
 assert.equal(e.context.escortsAgenceEstConfidente('personne-fixture'),true);
});
test('repli strict français et aucune modification des données employé',async()=>{
 const e=setup('ko',false);
 await e.context.escortsAgenceOuvrir('femme');
 assert.ok(e.corps.innerHTML.includes('« Prenez le temps de choisir. Elles ne se ressemblent pas. »'));
 assert.ok(e.corps.innerHTML.includes('libre'));
 const src=source;
 assert.match(src,/sbEscortRecruter\(escortId\)/);
 assert.match(src,/sbEscortSocialeChoisir\(escortId\)/);
 assert.match(src,/cout: r\.cout_jour/);
 assert.match(src,/state\.group\.members\.push\(r\.nom\)/);
});
