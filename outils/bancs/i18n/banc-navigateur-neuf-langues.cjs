'use strict';
// Chromium local, aucune connexion Supabase : le serveur est un http.server statique.
// Les appels réseau externes sont bloqués avant l'initialisation du jeu.
const assert=require('node:assert/strict');
const {chromium}=require('playwright');

const ORIGIN=process.env.I18N_STATIC_ORIGIN||'http://127.0.0.1:8765';
const LANGS=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
async function run(){
 const browser=await chromium.launch({headless:true});
 let checks=0;
 try{
  for(const language of LANGS){
   const mobile=language==='ar'||language==='ko'||language==='zh-TW';
   const page=await browser.newPage({viewport:mobile?{width:375,height:667}:{width:1440,height:900}});
   await page.route('**/*',route=>{
    const requestUrl=route.request().url();
    if(requestUrl.startsWith(ORIGIN+'/'))return route.continue();
    return route.abort(); // polices externes, Supabase, IA, analytics : bloqués
   });
   await page.goto(ORIGIN+'/index.html',{waitUntil:'domcontentloaded'});
   await page.waitForFunction(()=>window.i18next?.isInitialized===true && !!document.querySelector('#lang-btn-fr'));
   assert.equal(await page.locator('#lang-switcher button').count(),9,language+': neuf langues visibles');
   // La langue est changée par le vrai bouton UI, pas seulement en mémoire.
   await page.locator('#lang-btn-'+language).click();
   await page.waitForFunction(lang=>window.i18next.language===lang,language);
   const state=await page.evaluate(()=>{
    const node=document.querySelector('[data-i18n="home.createCharacter"]');
    const message=node?.textContent?.trim();
    const expected=window.RP_I18N_RESOURCES?.[window.i18next.language]?.translation?.home?.createCharacter;
    return {language:window.i18next.language,htmlLang:document.documentElement.lang,
     message,expected,dir:node?.getAttribute('dir'),
     saved:localStorage.getItem('respublica_language'),
     title:document.title};
   });
   assert.equal(state.htmlLang,language);
   assert.equal(state.saved,language);
   assert.equal(state.message,state.expected,language+': traduction visible');
   assert.ok(state.title.includes('Human Gambit'),language+': marque inchangée');
   assert.equal(state.dir,language==='ar'?'rtl':null,language+': RTL local seulement');
   checks++;
   // Retour navigateur réel : le choix doit survivre à un reload sans compte.
   await page.reload({waitUntil:'domcontentloaded'});
   await page.waitForFunction(lang=>window.i18next?.language===lang,language);
   assert.equal(await page.locator('[data-i18n="home.createCharacter"]').first().textContent(),state.expected);
   checks++;
   await page.close();
  }
  // Plateau hors session : seules les ressources i18n sont autorisées.
  // Cela teste le HTML réel sans ouvrir de compte ni exécuter les moteurs métier.
  for(const language of LANGS){
   const page=await browser.newPage({viewport:{width:393,height:852}});
   await page.addInitScript(lang=>localStorage.setItem('respublica_language',lang),language);
   await page.route('**/*',route=>{
    const url=new URL(route.request().url());
    if(url.origin!==ORIGIN)return route.abort();
    if(url.pathname.endsWith('.js') && !url.pathname.startsWith('/i18n/') && url.pathname!=='/forum.js')return route.abort();
    return route.continue();
   });
   await page.goto(ORIGIN+'/plateau.html',{waitUntil:'domcontentloaded'});
   await page.waitForFunction(lang=>window.i18next?.isInitialized===true &&
     document.documentElement.lang===lang,language);
   const state=await page.evaluate(()=>{
    const language=window.i18next.language;
    const node=document.querySelector('[data-i18n="plateau.rulesIntro"]');
    const expected=window.RP_I18N_RESOURCES?.[language]?.translation?.plateau?.rulesIntro;
    const mail=document.querySelector('#compose-mail-subject');
    return {language,label:node?.textContent?.trim(),expected,dir:node?.getAttribute('dir'),
      placeholder:mail?.getAttribute('placeholder'),
      expectedPlaceholder:window.RP_I18N_RESOURCES?.[language]?.translation?.plateau?.subjectPlaceholder,
      councilRoom:window.RPRoomI18n?.label('palais-gouvernement','salle_conseil','Salle du Conseil du Peuple'),
      expectedCouncil:window.RP_I18N_RESOURCES?.[language]?.translation?.rooms?.salle_conseil,
      townHall:window.RPRoomI18n?.label('mairie','bureau_maire_local','Bureau du Maire'),
      expectedTownHall:window.RP_I18N_RESOURCES?.[language]?.translation?.rooms?.bureau_maire_local,
      unknownRoom:window.RPRoomI18n?.label('palais-presidentiel','salle_conseil','Salle du Conseil du Peuple'),
      forumName:window.RPForumUI?.forumNameHtml('national','Forum National'),
      expectedForum:window.RP_I18N_RESOURCES?.[language]?.translation?.forumNames?.national,
      privateForum:window.RPForumUI?.forumNameHtml('local_novomirsk','Forum local — Novomirsk'),
      replyControl:window.RPForumUI?.labelHtml('reply','Répondre'),
      expectedReply:window.RP_I18N_RESOURCES?.[language]?.translation?.forumUI?.reply,
      toastTitle:window.RPToastI18n?.label('Action impossible'),
      expectedToast:window.RP_I18N_RESOURCES?.[language]?.translation?.toastTitles?.actionImpossible,
      // Panneau personnel du vrai HTML, pas seulement le dictionnaire.
      panelLabels:Object.fromEntries(['myStats','myGoals','myEmployees','inventory'].map(key=>{
        const el=document.querySelector('[data-i18n="plateau.'+key+'"]');
        const expected=window.RP_I18N_RESOURCES?.[language]?.translation?.plateau?.[key];
        return [key,{visible:el?.textContent?.trim(),expected,
          icon:el?.closest('button')?.querySelector('i')?.className||null,
          dir:el?.getAttribute('dir')||null}];
      })),
      panelHandlers:{
        stats:document.querySelector('[data-i18n="plateau.myStats"]')?.closest('button')?.getAttribute('onclick'),
        goals:document.querySelector('[data-i18n="plateau.myGoals"]')?.closest('button')?.getAttribute('onclick'),
        employees:document.querySelector('[data-i18n="plateau.myEmployees"]')?.parentElement?.getAttribute('onclick'),
        inventory:document.querySelector('.panel-title [data-i18n="plateau.inventory"]')?.parentElement?.getAttribute('onclick')
      },
      toolbarDir:document.querySelector('.top-right')?.getAttribute('dir')||null};
   });
   assert.equal(state.label,state.expected,language+': guide sur le plateau réel');
   assert.equal(state.placeholder,state.expectedPlaceholder,language+': composition de mail');
   assert.equal(state.dir,language==='ar'?'rtl':null,language+': direction limitée au texte');
   assert.equal(state.councilRoom,state.expectedCouncil,language+': salle du Conseil localisée');
   assert.equal(state.townHall,state.expectedTownHall,language+': bureau municipal localisé');
   assert.equal(state.unknownRoom,'Salle du Conseil du Peuple',language+': autre palais inchangé');
   assert.equal(state.forumName,state.expectedForum,language+': forum national localisé');
   assert.equal(state.privateForum,'Forum local — Novomirsk',language+': nom privé/local inchangé');
   assert.equal(state.replyControl,state.expectedReply,language+': bouton répondre localisé');
   assert.equal(state.toastTitle,state.expectedToast,language+': notification localisée sans changer raison serveur');
   for(const [key,entry] of Object.entries(state.panelLabels)){
     assert.ok(entry.expected,language+': absent du catalogue du panneau '+key);
     assert.equal(entry.visible,key==='myEmployees'||key==='inventory'
       ? entry.expected.toLocaleUpperCase(language) : entry.expected,
       language+': texte vraiment affiché dans le panneau '+key);
     assert.equal(entry.dir,language==='ar'?'rtl':null,language+': direction localisée '+key);
   }
   assert.ok(state.panelLabels.myStats.icon?.includes('ti-chart-bar'));
   assert.ok(state.panelLabels.myGoals.icon?.includes('ti-target'));
   assert.equal(state.panelHandlers.stats,"openSelfView('stats')");
   assert.equal(state.panelHandlers.goals,'afficherObjectifsSecrets()');
   assert.equal(state.panelHandlers.employees,"toggleSection('employes-panel','emp-chevron')");
   assert.equal(state.panelHandlers.inventory,'toggleInventaire()');
   assert.equal(state.toolbarDir,null,language+': barre globale non inversée');
   checks++;
   // Le navigateur réel résout aussi les nouveaux catalogues du Conseil
   // et des forums, avec les handlers métier explicitement bloqués.
   const social=await page.evaluate(()=>{
     const locale=window.i18next.language;
     const resources=window.RP_I18N_RESOURCES[locale].translation;
     return {
       room:window.RPRoomI18n?.label('palais-gouvernement','salle_conseil','Salle du Conseil du Peuple'),
       expectedRoom:resources.rooms.salle_conseil,
       forum:window.RPForumUI?.forumNameHtml('national','Forum National'),
       expectedForum:resources.forumNames.national,
       title:window.RPForumUI?.labelHtml('newTopic','Nouveau sujet'),
       expectedTitle:resources.forumUI.newTopic,
       otherRoom:window.RPRoomI18n?.label('palais-presidentiel','salle_conseil','Salle du Conseil du Peuple'),
       otherForum:window.RPForumUI?.forumNameHtml('private-org-81','Nom privé conservé'),
       htmlDir:document.documentElement.getAttribute('dir')
     };
   });
   assert.equal(social.room,social.expectedRoom,language+': Conseil du peuple');
   assert.equal(social.forum,social.expectedForum,language+': forum national');
   assert.equal(social.title,social.expectedTitle,language+': bouton sujet');
   assert.equal(social.otherRoom,'Salle du Conseil du Peuple',language+': autre bâtiment inchangé');
   assert.equal(social.otherForum,'Nom privé conservé',language+': forum privé inchangé');
   assert.notEqual(social.htmlDir,'rtl',language+': aucun RTL global');
   checks++;
   // Vérifier cette fois les vraies fonctions de rendu du forum, avec state
   // de test local. Aucun moteur métier, identifiant ou appel réseau externe.
   await page.evaluate(()=>{window.state={char:{name:'Testeur'},currentCity:'novomirsk',poste:null,contacts:[]};});
   await page.addScriptTag({url:ORIGIN+'/forum.js'});
   const rendered=await page.evaluate(()=>{
     const name=renderForumNavItem('national',FORUMS_BASE.national);
     const unread=renderMailCompose('Destinataire PJ','Sujet PJ');
     const locale=window.i18next.language;
     return {name,unread,locale,
       national:window.RP_I18N_RESOURCES[locale].translation.forumNames.national,
       mail:window.RP_I18N_RESOURCES[locale].translation.forumUI.newMail};
   });
   assert.ok(rendered.name.includes(rendered.national),language+': nom dans le HTML généré');
   assert.ok(rendered.name.includes('switchForum(&#39;national&#39;)') ||
     rendered.name.includes("switchForum('national')"),language+': identifiant du forum inchangé');
   assert.ok(rendered.unread.includes('Destinataire PJ'),language+': destinataire saisi préservé');
   assert.ok(rendered.unread.includes('Sujet PJ'),language+': sujet saisi préservé');
   assert.ok(rendered.unread.includes('onclick="submitMail()"'),language+': action courrier inchangée');
   checks++;
   // Trois états réels du même composant (chargement, liste vide, lecture
   // échouée) : un incident serveur ne doit jamais être présenté comme vide.
   const topics=await page.evaluate(()=>{
     currentForumId='national';
     FORUM_TOPICS.national=[];
     delete FORUM_LECTURE_TERMINEE.national;
     delete FORUM_LECTURE_ECHOUEE.national;
     const loading=renderTopicList();
     FORUM_LECTURE_TERMINEE.national=true;
     const empty=renderTopicList();
     FORUM_LECTURE_ECHOUEE.national='transport_indisponible';
     const failed=renderTopicList();
     const labels=window.RP_I18N_RESOURCES[window.i18next.language].translation.forumUI;
     return {loading,empty,failed,labels};
   });
   assert.ok(topics.loading.includes(topics.labels.loadingTopics),language+': chargement réel');
   assert.ok(!topics.loading.includes(topics.labels.noTopics),language+': pas de faux vide pendant chargement');
   assert.ok(topics.empty.includes(topics.labels.noTopics),language+': vrai vide affiché');
   assert.ok(topics.failed.includes(topics.labels.failedTopics),language+': panne affichée');
   assert.ok(topics.failed.includes(topics.labels.failedTopicsDetail),language+': détail de la panne affiché');
   assert.ok(!topics.failed.includes(topics.labels.noTopics),language+': aucun faux vide pendant panne');
   assert.ok(topics.failed.includes('onclick="rechargerForumActuel()"'),language+': réessai conservé');
   checks++;
   await page.close();
  }

  console.log('I18N CHROMIUM : '+checks+' vérifications accueil/rechargement/plateau, neuf langues, mobile/bureau, sans réseau externe');
 }finally {await browser.close();}
}
run().catch(error=>{console.error(error);process.exitCode=1});
