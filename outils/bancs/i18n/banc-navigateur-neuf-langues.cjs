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
    if(url.pathname.endsWith('.js') && !url.pathname.startsWith('/i18n/') &&
       !['/forum.js','/plateau-quete-accueil.js'].includes(url.pathname))return route.abort();
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
      unavailablePnj:window.RPPnjStatusI18n?.label('temporaryUnavailable','Discussion impossible momentanément. Veuillez réessayer dans quelques instants.'),
      expectedPnj:window.RP_I18N_RESOURCES?.[language]?.translation?.pnjStatus?.temporaryUnavailable,
      disabledPnj:window.RPPnjStatusI18n?.label('noConversation',"Ce personnage n'engage pas de conversation."),
      expectedDisabledPnj:window.RP_I18N_RESOURCES?.[language]?.translation?.pnjStatus?.noConversation,
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
   assert.equal(state.unavailablePnj,state.expectedPnj,language+': PNJ en panne localisé');
   assert.equal(state.disabledPnj,state.expectedDisabledPnj,language+': PNJ sans profil localisé');
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
       // Les premières minutes de jeu : les vrais modules i18n sont chargés
       // par la page réelle, sans lancer de quête ou écrire en base.
       guard:window.RPGuardWelcomeI18n?.label('guardWarning',
         window.RP_I18N_RESOURCES.fr.translation.guardWelcome.guardWarning),
       expectedGuard:resources.guardWelcome?.guardWarning,
       guardDirections:window.RPGuardWelcomeI18n?.label('guardDirections',
         window.RP_I18N_RESOURCES.fr.translation.guardWelcome.guardDirections),
       expectedGuardDirections:resources.guardWelcome?.guardDirections,
       jeremy:window.RPJeremyScenesI18n?.label('welcomeJeremy',
         window.RP_I18N_RESOURCES.fr.translation.jeremyScenes.welcomeJeremy),
       expectedJeremy:resources.jeremyScenes?.welcomeJeremy,
       bedroom:window.RPJeremyScenesI18n?.label('hotelInstructions',
         window.RP_I18N_RESOURCES.fr.translation.jeremyScenes.hotelInstructions),
       expectedBedroom:resources.jeremyScenes?.hotelInstructions,
       bar:window.RPJeremyScenesI18n?.label('barIntroduction',
         window.RP_I18N_RESOURCES.fr.translation.jeremyScenes.barIntroduction),
       expectedBar:resources.jeremyScenes?.barIntroduction,
       changedGuard:window.RPGuardWelcomeI18n?.label('guardWarning','Message différent'),
       htmlDir:document.documentElement.getAttribute('dir')
     };
   });
   assert.equal(social.room,social.expectedRoom,language+': Conseil du peuple');
   assert.equal(social.forum,social.expectedForum,language+': forum national');
   assert.equal(social.title,social.expectedTitle,language+': bouton sujet');
   assert.equal(social.otherRoom,'Salle du Conseil du Peuple',language+': autre bâtiment inchangé');
   assert.equal(social.otherForum,'Nom privé conservé',language+': forum privé inchangé');
   for(const [actual,expected,label] of [
     [social.guard,social.expectedGuard,'garde'],
     [social.guardDirections,social.expectedGuardDirections,'instructions mairie'],
     [social.jeremy,social.expectedJeremy,'Jérémy'],
     [social.bedroom,social.expectedBedroom,'hôtel'],
     [social.bar,social.expectedBar,'bar']
   ]){
     assert.ok(expected?.trim(),language+': ressource absente '+label);
     assert.equal(actual,expected,language+': scène non traduite '+label);
   }
   assert.equal(social.changedGuard,'Message différent',language+': texte dynamique préservé');
   assert.notEqual(social.htmlDir,'rtl',language+': aucun RTL global');
   checks++;
   // Exécuter les VRAIES popups scénarisées, sans déclencher leurs clics.
   // L'état est un leurre sans session ; les writes sont absents et bloqués.
   await page.evaluate(()=>{
     window.state={char:{name:'Testeur',queteAccueil:{etape:'attente_depart_jeremy'}},
       currentCity:'capitale',country:'republic',employes:[]};
   });
   await page.addScriptTag({url:ORIGIN+'/plateau-quete-accueil.js'});
   const scenes=await page.evaluate(()=>{
     queteAccueilProposerCarriere();
     const career=[...document.querySelectorAll('#quete-accueil-actions button')].map(x=>({
       text:x.textContent.trim(),handler:x.getAttribute('onclick')
     }));
     const careerIntro=document.getElementById('quete-accueil-texte').textContent;
     queteAccueilProposerPresentationForum();
     const forum=[...document.querySelectorAll('#quete-accueil-actions button')].map(x=>({
       text:x.textContent.trim(),handler:x.getAttribute('onclick')
     }));
     const forumIntro=document.getElementById('quete-accueil-texte').innerHTML;
     const data=window.RP_I18N_RESOURCES[window.i18next.language].translation.jeremyScenes;
     return {career,careerIntro,forum,forumIntro,
       names:['criminalChoice','politicalChoice','entrepreneurialChoice','undecidedChoice'].map(k=>data[k]),
       invite:data.localForumInvite,introduce:data.introduceMyself,later:data.later,
       careerExpected:data.careerChoice,stage:window.state.char.queteAccueil.etape};
   });
   assert.equal(scenes.career.length,4,language+': quatre choix de carrière rendus');
   assert.deepEqual(scenes.career.map(x=>x.text),scenes.names,language+': quatre textes de choix visibles');
   assert.equal(scenes.careerIntro,scenes.careerExpected,language+': question de carrière visible');
   for(const [i,id] of ['criminel','politique','entrepreneurial','indecis'].entries())
     assert.ok(scenes.career[i].handler.includes("queteAccueilChoisirAmbition('"+id+"')"),
       language+': destination originale '+id);
   assert.equal(scenes.forum.length,2,language+': deux choix de forum');
   assert.deepEqual(scenes.forum.map(x=>x.text),[scenes.introduce,scenes.later]);
   assert.ok(scenes.forum[0].handler.includes('queteAccueilLancerPresentationForum()'));
   assert.ok(scenes.forum[1].handler.includes('queteAccueilIgnorerPresentationForum()'));
   assert.equal(scenes.forumIntro,scenes.invite,language+': présentation locale visible');
   assert.equal(scenes.stage,'presentation_en_cours',language+': pas de publication client');
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
