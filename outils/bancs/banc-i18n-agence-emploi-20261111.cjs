const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const langues=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const read=name=>fs.readFileSync(require('node:path').join(__dirname,'../..',name),'utf8');
const source=read('plateau-agence-emploi.js'),resources=read('i18n/employment-agency-resources.js'),html=read('plateau.html');
function setup(lang='fr',enabled=true){
  let onLanguage=null;
  const elements={
    'postes-modal-title':{textContent:''},
    'postes-body':{innerHTML:''},
    'modal-postes':{classList:{add(){},contains(){return true}}}
  };
  const calls={toast:[],catalogue:0,hire:[],journal:[]};
  const ctx={console,window:null,document:{getElementById:id=>elements[id]||null},
    RP_I18N_RESOURCES:Object.fromEntries(langues.map(l=>[l,{translation:{}}])),
    RP_I18N_GAME_ENABLED:enabled,RPPlateauI18n:{language:()=>ctx.currentLang},
    i18next:{on(name,fn){if(name==='languageChanged')onLanguage=fn}},
    currentLang:lang,state:{country:'republic',char:{name:'test'},currentBuilding:'bureau',currentRoom:'accueil',employes:[],day:12},
    COUNTRIES:{republic:{cur:'FR'}},
    BUILDINGS:{bureau:{rooms:{accueil:{orders:[{fn:'embaucher_agent_securite',employeur:'agence1',metier:'vigile'}],persons:[]}}}},
    sbEmployeurCandidats:async()=>{calls.catalogue++;return {ok:true,employeur:'Agence Alpha',plafond_employes:4,employes_actuels:1,metiers:[{metier:'vigile',libelle:'Agent de sécurité',quota:3,employes:1,recrutable:true,cout_embauche:500,cout_jour:0,pa:1,caracteristiques:{PER:10,VOL:8}}],candidats:[{metier:'vigile',nom:'Irina',candidat_id:'id1',accroche:'Une présentation du serveur',deja_employe:false}]}},
    sbEmployeurEmbaucher:async id=>{calls.hire.push(id);return {ok:false,raison:'paiement_refuse'}},
    showToast:(...args)=>calls.toast.push(args),
    escapeHtmlText:x=>String(x).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c])),
    PNJ_AVATAR:{default:{icon:'ti-user',color:'#fff'}},
    appliquerPaiementServeur:()=>{},sauvegarderPersonnageImmediat:()=>{},updateUI:()=>{},renderPersonsList:()=>{},
    addJournalEntry:(...args)=>calls.journal.push(args)
  };
  ctx.window=ctx;
  vm.createContext(ctx);
  vm.runInContext(resources,ctx,{filename:'i18n/employment-agency-resources.js'});
  vm.runInContext(source,ctx,{filename:'plateau-agence-emploi.js'});
  return {ctx,calls,elements,change(l){ctx.currentLang=l;onLanguage?.(l)}};
}
test('chargement dans le plateau, syntaxe et couverture exacte des neuf langues',()=>{
  assert.match(html,/i18n\/employment-agency-resources\.js\?v=20261111/);
  assert.match(html,/plateau-agence-emploi\.js\?v=i18n-20261111/);
  const s=setup();const fr=s.ctx.RP_I18N_RESOURCES.fr.translation.employmentAgency;
  assert.equal(Object.keys(fr).length,36);
  for(const l of langues){
    const words=s.ctx.RP_I18N_RESOURCES[l].translation.employmentAgency;
    assert.deepEqual(Object.keys(words).sort(),Object.keys(fr).sort());
    for(const key of Object.keys(fr)){
      assert.ok(words[key].length>0,l+'/'+key);
      assert.deepEqual([...words[key].matchAll(/\{(\w+)\}/g)].map(m=>m[1]).sort(),[...fr[key].matchAll(/\{(\w+)\}/g)].map(m=>m[1]).sort(),l+'/'+key);
    }
  }
});
test('français conservé et neuf langues pour frais, limites, refus et embauche',async()=>{
 const expected=['Frais d\'embauche :','Hiring fee:','Gastos de contratación:','聘用費用：','Стоимость найма:','채용 비용:','رسوم التوظيف:','Taxa de contratação:','Einstellungskosten:'];
 for(const [index,lang] of langues.entries()){
   const t=setup(lang);const {ctx,elements,calls}=t;
   await ctx.agenceEmploiOuvrir('embaucher_agent_securite');
   assert.equal(calls.catalogue,1);
   const page=elements['postes-body'].innerHTML;
   assert.ok(page.includes(expected[index]),lang);
   assert.ok(page.includes('500')&&page.includes('FR')&&page.includes('1 PA'),lang);
   assert.ok(page.includes('Irina')&&page.includes('Agent de sécurité'),lang);
   assert.equal(ctx.state.employes.length,0);
   await ctx.agenceEmploiEmbaucher('id1','embaucher_agent_securite');
   assert.deepEqual(calls.hire,['id1']);
   assert.equal(ctx.state.employes.length,0);
   const toast=calls.toast.at(-1);
   assert.ok(toast[0]&&toast[1]&&!toast[1].includes('{'),lang);
   if(lang!=='fr')assert.notEqual(toast[0],'Refusé');
 }
});
test('changement de langue : re-rendu sans requête ni perte des identités',async()=>{
 const s=setup('fr');await s.ctx.agenceEmploiOuvrir('embaucher_agent_securite');
 const previous=s.elements['postes-body'].innerHTML;const count=s.calls.catalogue;
 s.change('ko');const after=s.elements['postes-body'].innerHTML;
 assert.notEqual(after,previous);assert.ok(after.includes('채용 비용:'));
 assert.ok(after.includes('Irina')&&after.includes('500'));
 assert.equal(s.calls.catalogue,count);assert.equal(s.calls.hire.length,0);
 s.change('fr');assert.equal(s.elements['postes-body'].innerHTML,previous);
});
test('beta désactivée : repli strict en français',async()=>{
 const s=setup('ko',false);await s.ctx.agenceEmploiOuvrir('embaucher_agent_securite');
 assert.ok(s.elements['postes-body'].innerHTML.includes('Frais d\'embauche :'));
 assert.ok(s.elements['postes-body'].innerHTML.includes('Aucun salaire journalier'));
});
test('aucune modification du chemin serveur ni des paramètres d\'embauche',()=>{
 assert.match(source,/sbEmployeurEmbaucher\(candidatId\)/);
 assert.match(source,/sbEmployeurEmbaucherAgence\(ordreAgence\.employeur, candidatId\)/);
 assert.match(source,/appliquerPaiementServeur\(r\.paiement\)/);
 assert.match(source,/cout: r\.cout_jour/);
 assert.match(source,/agenceEmploiCatalogue\(ordre\.employeur, true\)/);
});
