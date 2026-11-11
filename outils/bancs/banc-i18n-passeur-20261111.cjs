'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const moduleText=read('plateau-contact-organisation.js'),resources=read('i18n/contact-organization-resources.js'),html=read('plateau.html'),pnj=read('plateau-pnj.js');
const languages=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(lang='fr',enabled=true){
 const calls=[],toasts=[],journal=[],nodes={};
 let open=false, htmlBody='',parole=null,labels=[];
 const rootNode={
  getAttribute:name=>name==='data-contact-passeur'?'pat_hounette':null,
  querySelector:sel=>sel==='[data-contact-replique]'?parole:null,
  querySelectorAll:sel=>sel==='[data-contact-label]'?labels:[]
 };
 const corps={
  get innerHTML(){return htmlBody},
  set innerHTML(value){
   htmlBody=value;
   const id=value.match(/data-contact-replique="([^"]*)"/)?.[1]||'';
   parole={getAttribute:name=>name==='data-contact-replique'?id:null,textContent:''};
   labels=[...value.matchAll(/data-contact-label="([^"]+)">([^<]+)/g)].map(m=>({
     getAttribute:k=>k==='data-contact-label'?m[1]:null,textContent:m[2]
   }));
  },
  querySelector:sel=>sel==='[data-contact-passeur]'&&htmlBody.includes('data-contact-passeur=')?rootNode:null
 };
 const elements={
   'postes-modal-title':{textContent:''},'postes-body':corps,
   'modal-postes':{classList:{add(){open=true},remove(){open=false},contains(){return open}}},
   'modal-pnj':{classList:{remove(){}}},
   'contact-orga-projet':{value:'Mon projet secret ne doit jamais sortir'}
 };
 const ctx={
   window:null,console,RP_I18N_RESOURCES:Object.fromEntries(languages.map(l=>[l,{translation:{}}])),
   RP_I18N_LANGUAGES:Object.fromEntries(languages.map(l=>[l,{}])),
   RP_I18N_GAME_ENABLED:enabled,RPPlateauI18n:{language:()=>ctx.locale},locale:lang,
   document:{getElementById:id=>{if(id==='contact-orga-projet')calls.push(['lecture-projet']);return elements[id]||null},querySelectorAll:()=>[],documentElement:{lang:''}},
   sbContactOrganisationEtat:async(...args)=>{calls.push(['etat',...args]);return {ok:true,peut_demander:true}},
   sbContactOrganisationDemander:async(...args)=>{calls.push(['demander',...args]);return {ok:true}},
   showToast:(...args)=>toasts.push(args),addJournalEntry:(...args)=>journal.push(args),
   escapeHtmlText:v=>String(v).replace(/[&<>\\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))
 };
 ctx.window=ctx;
 vm.createContext(ctx);vm.runInContext(resources,ctx);vm.runInContext(moduleText,ctx);
 return {ctx,elements,calls,toasts,journal,corps,get parole(){return parole},get labels(){return labels},get opened(){return open},
   change(l){ctx.locale=l;for(const fn of ctx.RP_I18N_CHANGE_CALLBACKS||[])fn(l)},
   setEtat(fn){ctx.sbContactOrganisationEtat=fn},setDemander(fn){ctx.sbContactOrganisationDemander=fn}
 };
}
test('18 phrases, 9 langues, source canonique et contrôle du branchement',()=>{
 const e=setup(),fr=e.ctx.RP_I18N_RESOURCES.fr.translation.contactOrganization;
 assert.equal(Object.keys(fr).length,18);
 for(const lang of languages){
  const dict=e.ctx.RP_I18N_RESOURCES[lang].translation.contactOrganization;
  assert.deepEqual(Object.keys(dict).sort(),Object.keys(fr).sort(),lang);
  for(const [key,original] of Object.entries(fr)){
   assert.ok(dict[key]?.trim(),lang+'/'+key);
   const vars=s=>[...s.matchAll(/\{([a-z]+)\}/g)].map(x=>x[1]).sort();
   assert.deepEqual(vars(dict[key]),vars(original),lang+'/'+key);
  }
 }
 assert.match(html,/i18n\/contact-organization-resources\.js\?v=20261111/);
 assert.match(pnj,/contactOrgaLibelleAction\(defPasseur\)/);
 assert.match(moduleText,/question: 'Tu veux entrer en contact avec une organisation criminelle \?'/);
 assert.match(moduleText,/nom: 'Pat Hounette'/);
 assert.match(moduleText,/type: 'criminelle'/);
});
test('dialogue Pat : neuf langues, mêmes identifiants et aucune fuite du projet',async()=>{
 for(const lang of languages){
  const e=setup(lang),p=e.ctx.contactOrgaPasseur('pat_hounette');
  assert.equal(e.ctx.contactOrgaDuPnj({contactOrga:'pat_hounette'}),'pat_hounette');
  assert.equal(e.ctx.contactOrgaDuPnj({contactOrga:'inconnu'}),null);
  assert.ok(e.ctx.contactOrgaLibelleAction(p).length>0);
  if(lang!=='fr')assert.notEqual(e.ctx.contactOrgaLibelleAction(p),p.libelleAction);
  await e.ctx.contactOrgaDemarrer('pat_hounette');
  assert.deepEqual(e.calls,[['etat','pat_hounette','criminelle']]);
  assert.ok(e.corps.innerHTML.includes('data-contact-replique="question"'));
  assert.ok(e.corps.innerHTML.includes('data-contact-label="yes"'));
  e.ctx.contactOrgaConfirmer('pat_hounette');
  assert.ok(e.corps.innerHTML.includes('id="contact-orga-projet"'));
  assert.ok(e.corps.innerHTML.includes('data-contact-replique="projet"'));
  await e.ctx.contactOrgaEnvoyer('pat_hounette');
  assert.deepEqual(e.calls,[['etat','pat_hounette','criminelle'],['demander','pat_hounette','criminelle']],lang);
  assert.equal(e.journal.length,1);
  assert.ok(e.journal[0][0].includes('Pat Hounette'));
  assert.ok(!e.journal[0][0].includes('secret'));
 }
});
test('délai et panne : aucun appel de demande induit et message dans la langue choisie',async()=>{
 for(const lang of languages){
  const e=setup(lang);
  e.setEtat(async(...args)=>{e.calls.push(['etat',...args]);return {ok:true,peut_demander:false}});
  await e.ctx.contactOrgaDemarrer('pat_hounette');
  assert.equal(e.calls.length,1);
  assert.ok(e.corps.innerHTML.includes('data-contact-replique="refusDelai"'));
  e.setDemander(async(...args)=>{e.calls.push(['demander',...args]);return {ok:false,raison:'aucune_organisation'}});
  await e.ctx.contactOrgaEnvoyer('pat_hounette');
  assert.equal(e.calls.length,2);
  assert.ok(e.corps.innerHTML.includes('data-contact-replique="personne"'));
 }
});
test('changement de langue APRÈS chargement i18next : texte modifié, saisie intacte, aucun RPC',()=>{
 const e=setup('fr');
 assert.equal(e.ctx.i18next,undefined);
 assert.equal(e.ctx.RP_I18N_CHANGE_CALLBACKS.length,1);
 e.ctx.contactOrgaConfirmer('pat_hounette');
 const before=e.corps.innerHTML,qty=e.calls.length;
 e.ctx.i18next={language:'fr',on(ev,fn){if(ev==='languageChanged')this.notify=fn},
   init(opts,cb){this.language=opts.lng;cb(null)}};
 vm.runInContext(read('i18n/plateau-init.js'),e.ctx);
 e.ctx.locale='ko';e.ctx.i18next.language='ko';e.ctx.i18next.notify('ko');
 assert.ok(e.parole.textContent.includes('무슨 계획'));
 assert.ok(e.labels.some(x=>x.textContent==='그에게 설명하기'));
 assert.equal(e.elements['contact-orga-projet'].value,'Mon projet secret ne doit jamais sortir');
 assert.equal(e.calls.length,qty);
 assert.equal(e.corps.innerHTML,before);
 e.ctx.locale='fr';e.ctx.i18next.language='fr';e.ctx.i18next.notify('fr');
 assert.ok(e.parole.textContent.includes("C'est quoi ton projet"));
});
test('le dialogue français reste la version canonique si beta désactivée',async()=>{
 const e=setup('ar',false);await e.ctx.contactOrgaDemarrer('pat_hounette');
 assert.ok(e.corps.innerHTML.includes('Tu veux entrer en contact avec une organisation criminelle ?'));
 assert.equal(e.ctx.contactOrgaLibelleAction(e.ctx.contactOrgaPasseur('pat_hounette')),'Entrer en contact avec une organisation criminelle');
});
test('interdit de lire ou d’envoyer le projet du joueur, indépendamment du langage',()=>{
 const send=moduleText.slice(moduleText.indexOf('async function contactOrgaEnvoyer('),moduleText.indexOf('// Mise à jour des seuls libellés',moduleText.indexOf('async function contactOrgaEnvoyer(')));
 assert.ok(!send.includes("getElementById('contact-orga-projet')"));
 assert.ok(!send.includes('.value'));
 assert.match(send,/sbContactOrganisationDemander\(passeurId, p\.type\)/);
});
