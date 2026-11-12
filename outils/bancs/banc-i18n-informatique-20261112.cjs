'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const dict=read('i18n/computer-files-resources.js'),logic=read('plateau-informatique.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fixture(locale='fr'){
 const values=Object.fromEntries(langs.map(l=>[l,{translation:{}}]));
 const saved=[],calls=[],inputs={value:'Valeur saisie intacte'};
 let title='',markup='',lang=locale,open=false;
 const titleNode={setAttribute(k,v){this[k]=v;},getAttribute(k){return this[k]||'';},get textContent(){return title;},set textContent(v){title=v;}};
 const elements={};
 const body={querySelector(q){return markup.includes('data-info-text')?{}:null;},
   querySelectorAll(q){return q==='[data-info-text]'?Object.values(elements):[]}};
 const document={getElementById(id){return id==='postes-modal-title'?titleNode:id==='modal-postes'?{classList:{contains:k=>k==='open'&&open}}:id==='postes-body'?body:id==='pirate-banque'?inputs:id==='pirate-ordi'?inputs:null;}};
 const global={console,document,
  RP_I18N_GAME_ENABLED:true,RP_I18N_RESOURCES:values,RPPlateauI18n:{language:()=>lang},
  state:{country:'republic',char:{name:'Tester'}},equipementsEchapper:s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c])),
  equipementsBouton:(onClick,label,primary)=>'<button onclick="'+onClick+'"'+(primary?' data-primary="1"':'')+'>'+label+'</button>',
  equipementsModale:(t,h)=>{title=t;markup=h;open=true;},
  showToast:()=>{},sbRpcVerdict:async(nom)=>{calls.push(nom);return {ok:false,raison:'cible_inconnue'};}
 };
 global.window=global;
 const ctx=vm.createContext({...global,window:global});
 vm.runInContext(dict,ctx,{filename:'computer-files-resources.js'});
 vm.runInContext(logic,ctx,{filename:'plateau-informatique.js'});
 return{ctx,words:values,setLang:l=>{lang=l;},get title(){return title;},get markup(){return markup;},calls,inputs};
}
test('39 chaînes d’interface informatique présentes dans neuf langues',()=>{
 const f=fixture(),ref=f.words.fr.translation.computerFiles;
 assert.equal(Object.keys(ref).length,39);
 for(const lang of langs){
  const w=f.words[lang].translation.computerFiles;
  assert.deepEqual(Object.keys(w).sort(),Object.keys(ref).sort());
  for(const [key,value] of Object.entries(w)){assert.ok(key&&value&&value.trim(),lang+':'+key);}
 }
});
test('panneau de piratage traduit sans modifier les actions ni les coûts',()=>{
 for(const lang of langs){
  const f=fixture(lang);f.ctx.ouvrirPiratage();
  const words=f.words[lang].translation.computerFiles;
  assert.equal(f.title,lang==='fr'?'Piratage':words.Piratage);
  assert.ok(f.markup.includes(words['Comptes en banque']),lang);
  assert.ok(f.markup.includes(words['Registres de votre ville']),lang);
  assert.ok(f.markup.includes(words['Pirater les casernes']),lang);
  assert.ok(f.markup.includes('piraterLancer('));
  assert.ok(f.markup.includes('registre'));
  assert.ok(f.markup.includes('caserne'));
  assert.ok(f.markup.includes(words['3 PA par tentative. Réussite de base 45 %, selon votre intelligence. Un intranet protège presque toujours un ordinateur. Tout piratage laisse une trace ; un échec peut alerter la cible.']),lang);
  assert.equal(f.calls.length,0);
 }
});
test('neuf langues : raisons de refus serveur traduites, sans interpréter la décision',()=>{
 const reasons={pas_de_connexion:"Il faut être dans votre bureau, avec votre ordinateur et votre box installés.",cible_inconnue:'Cible introuvable.',registre_inconnu:'Registre inconnu ici.',acces_expire:"L'accès obtenu a expiré ou a déjà servi : il faut pirater à nouveau.",dossier_inaccessible:"Ce dossier n'est pas accessible."};
 for(const lang of langs){
  const f=fixture(lang),words=f.words[lang].translation.computerFiles;
  for(const [reason,fr] of Object.entries(reasons))
   assert.equal(f.ctx.informatiqueRefus({raison:reason}),lang==='fr'?fr:words[fr],lang+':'+reason);
 }
});
test('changement de langue : aucune nouvelle RPC et saisies intactes',()=>{
 const f=fixture('fr');f.ctx.ouvrirPiratage();
 f.inputs.value='Cible conservée';
 f.setLang('ko');
 f.ctx.window.RP_I18N_CHANGE_CALLBACKS[0]();
 assert.equal(f.title,'해킹');
 assert.equal(f.inputs.value,'Cible conservée');
 assert.equal(f.calls.length,0);
});
test('chargement catalogue avant script, audit éditorial enregistré et modes conservés',()=>{
 assert.match(html,/i18n\/computer-files-resources\.js\?v=20261112/);
 assert.match(html,/plateau-informatique\.js\?v=computer-i18n-20261112/);
 assert.ok(html.indexOf('computer-files-resources.js')<html.indexOf('plateau-informatique.js'));
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/computer-files-resources\.js/);
 for(const action of ['pirater','piratage_dossier_agir','dossiers_lire','dossier_transferer',
    'faux_document_imprimer','plans3d_lire','organisation_materiel_autoriser'])
  assert.ok(logic.includes(action),action);
});
