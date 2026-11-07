'use strict';
/* i18n des contrôles du forum : aucune mutation des données ou identités PJ. */
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'forum.js'),'utf8');
const page=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const win={};
let lang='fr';
win.RPPlateauI18n={language:()=>lang};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','plateau-resources.js','forum-ui.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const labels={newTopic:'Nouveau sujet',reply:'Répondre',retry:'Réessayer',
 newMail:'Nouveau mail',back:'Retour',backToTopic:'Retour au sujet',
 postAs:'Publier en tant que',sendAs:'Envoyer en tant que'};
test('huit commandes x neuf locales, repli et conservation de la langue du lecteur',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=lng;
  const dictionary=win.RP_I18N_RESOURCES[lng].translation.forumUI;
  for(const key of Object.keys(labels)) assert.ok(Object.hasOwn(dictionary,key),lng+': '+key);
  for(const [key,original] of Object.entries(labels)){
   assert.ok(dictionary[key].trim(),lng+' : '+key);
   const got=win.RPForumUI.labelHtml(key,original);
   assert.ok(got.length>0);
   if(lng==='fr')assert.equal(got,original);
  }
 }
});
test('les contrôles dynamiques sont localisés sans changer les noms des handlers',()=>{
 for(const [key,original] of Object.entries(labels)){
  assert.ok(source.includes("rpForumLibelle('"+key+"','"+original+"')"),key);
 }
 for(const handler of ['showComposeCanvasForm()', 'showComposeCanvasReply()', 'rechargerForumActuel()',
                       'backToList()', 'backToTopic()']){
  assert.ok(source.includes(handler),handler);
 }
 assert.ok(source.includes('renderPosterEnTantQue(fieldId)'));
 assert.ok(source.includes('renderEnvoyerMailEnTantQue'));
 const bridge=page.indexOf('src="i18n/plateau-bridge.js');
 const module=page.indexOf('src="i18n/forum-ui.js');
 const init=page.indexOf('src="i18n/plateau-init.js');
 assert.ok(bridge>=0&&bridge<module&&module<init);
});
test('aucun HTML arbitraire ne traverse les traductions des boutons',()=>{
 lang='en';
 const original=win.i18next.t;
 win.i18next.t=()=>'<img src=x onerror=alert(1)> &';
 const escaped=win.RPForumUI.labelHtml('reply','Répondre');
 assert.ok(!escaped.includes('<img'));
 assert.ok(escaped.includes('&lt;img'));
 assert.ok(escaped.includes('&amp;'));
 win.i18next.t=original;
 assert.equal(win.RPForumUI.labelHtml('noSuchKey','Texte original'),'Texte original');
});


test('sept forums canoniques : titres et descriptions sans élargir les accès',()=>{
 const french={
  national:['Forum National','Débats politiques nationaux'],
  presidence:['La Présidence à la Nation','Discours et annonces officielles depuis la Présidence'],
  assemblee:["L'Assemblée nationale",'Projets de loi, débats parlementaires et résultats des scrutins'],
  gouvernement:['Le Gouvernement à la Nation','Réservé au gouvernement'],
  presse:['Presse & Médias','Réservé aux journalistes'],
  international:['Forum International','Relations entre empires'],
  sport:['Championnat Sportif','Résultats, classements et débats de supporters']
 };
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=lng;
  for(const [id,[name,desc]] of Object.entries(french)){
   const data=win.RP_I18N_RESOURCES[lng].translation;
   assert.ok(data.forumNames[id]?.length,lng+': name '+id);
   assert.ok(data.forumDescriptions[id]?.length,lng+': desc '+id);
   assert.ok(win.RPForumUI.forumNameHtml(id,name)?.length);
   assert.ok(win.RPForumUI.forumDescriptionHtml(id,desc)?.length);
  }
 }
 lang='ru';
 // L'intitulé d'un forum local, privé ou renommé reste strictement inchangé.
 for(const [id,value] of [['local_novomirsk','Forum local — Novomirsk'],['gouvernement','Conseil Central'],['organisation_7','Organisation privée']]){
  assert.equal(win.RPForumUI.forumNameHtml(id,value),value);
 }
 assert.ok(source.includes('rpForumNom(id,f.name)'));
 assert.ok(source.includes('rpForumNom(currentForumId,f.name)'));
 assert.ok(source.includes('rpForumDescription(currentForumId,f.desc)'));
 assert.ok(source.includes('canAccessForum(id)'));
});

test('dix libellés de sidebar ne changent pas les identifiants de catégories et de mails',()=>{
 const ui=['institutions','mailbox','receivedMails','sentMails','archivedMails','nationalForums',
  'internationalForums','privateForums','noMessages','noOrganizations'];
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=lng;
  for(const key of ui){
   assert.ok(win.RP_I18N_RESOURCES[lng].translation.forumUI[key]?.trim(),lng+': '+key);
  }
 }
 for(const fn of ['toggleCategorieForum','selectionnerRubriqueMail','renderForumSidebar',
                  'mailsRecusVisibles','nombreSujetsForum']){
  assert.ok(source.includes(fn),fn);
 }
 for(const id of ['intra','inter','prive','recus','envoyes','archives']){
  assert.ok(source.includes("'"+id+"'"),id);
 }
 assert.ok(source.includes("rpForumLibelle('institutions','Institutionnels')"));
 assert.ok(source.includes("rpForumLibelle('mailbox','Boîte Mail')"));
 assert.ok(source.includes("rpForumLibelle('noOrganizations'"));
});


test('états des sujets : panne distincte du vide, cinq colonnes préservées',()=>{
 const keys=['chooseCategory','categoryHelp','loadingTopics','failedTopics','failedTopicsDetail',
  'noTopics','firstTopic','presidentOnly','topicColumn','authorColumn','lastPostColumn',
  'viewsColumn','repliesColumn'];
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=lng;
  for(const key of keys)assert.ok(win.RP_I18N_RESOURCES[lng].translation.forumUI[key]?.trim(),lng+': '+key);
 }
 for(const key of keys)assert.ok(source.includes("rpForumLibelle('"+key+"'"),key);
 assert.ok(source.includes('FORUM_LECTURE_ECHOUEE[currentForumId]'));
 assert.ok(source.includes('FORUM_LECTURE_EN_COURS[currentForumId]'));
 assert.ok(source.includes('FORUM_LECTURE_TERMINEE[currentForumId]'));
 assert.ok(source.includes('peutCreerSujet ?'));
 assert.ok(source.includes('escapeHtmlText(t.title)'));
});


test('formulaire de mail : réutilisation des clés de l’accueil, sans toucher aux données saisies',()=>{
 const keys=['newMessage','recipient','recipientPlaceholder','subject','subjectPlaceholder',
             'messageLabel','sendButton'];
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  const resource=win.RP_I18N_RESOURCES[lng].translation.plateau;
  for(const key of keys)assert.ok(resource[key]?.trim(),lng+': '+key);
 }
 const section=source.slice(source.indexOf('function renderMailCompose('),
   source.indexOf('let _mailEnvoiEnCours'));
 for(const key of keys)assert.ok(section.includes("rpForumPlateauLibelle('"+key+"'"),key);
 assert.ok(section.includes('${escapeHtmlText(defaultTo)}'));
 assert.ok(section.includes('${escapeHtmlText(defaultSubject)}'));
 for(const marker of ['id="mail-to"','id="mail-subject"',"renderRichEditor('compose-body')",
                       'onclick="submitMail()"',"renderEnvoyerMailEnTantQue('compose-mail-auteur'"]){
  assert.ok(section.includes(marker),marker);
 }
});


test('courriers : treize libellés, lecture, archivage et suppression inchangés',()=>{
 const keys=['sentMessagesTitle','noSentMail','toLabel','archivesTitle','noArchivedMail','fromLabel',
  'receivedMessagesTitle','noReceivedMail','unarchive','archiveKeep','delete','orgReplyUnavailable','autoDeleteNotice'];
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  lang=lng;
  for(const key of keys)assert.ok(win.RP_I18N_RESOURCES[lng].translation.forumUI[key]?.trim(),lng+': '+key);
 }
 const inbox=source.slice(source.indexOf('function renderMailInbox()'),source.indexOf('let currentMailId = null'));
 const read=source.slice(source.indexOf('function renderMailRead()'),source.indexOf('function replyToMail('));
 for(const key of keys)assert.ok((inbox+read).includes("rpForumLibelle('"+key+"'"),key);
 for(const handler of ["readMail('", "toggleArchiveMail('", "deleteMail('",
                       "replyToMail(this.dataset.mailFrom, this.dataset.mailSubject)"]){
  assert.ok((inbox+read).includes(handler),handler);
 }
 for(const userData of ['escapeHtmlText(mail.subject)','escapeHtmlText(mail.from)',
                        'escapeHtmlText(mail.to)','sanitizeRichHtml(_actionsMail.corps)']){
  assert.ok(read.includes(userData),userData);
 }
 assert.ok(source.includes("mailRubrique === 'archives'"));
 assert.ok(source.includes("mailRubrique === 'envoyes'"));
});
