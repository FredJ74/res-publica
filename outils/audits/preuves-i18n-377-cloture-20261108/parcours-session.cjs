// Recette locale : vrais modules et renderer, DOM Chromium, aucune session ou opération métier.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../../e2e/node_modules/playwright'),acorn=require('../../vercel/node_modules/acorn');
const R=path.resolve(__dirname,'../../..'),corrige=process.argv.includes('--correctif'),patch=corrige?JSON.parse(fs.readFileSync('/tmp/cert377-sources-corrigees.json','utf8')):{},source=patch['plateau-politique.js']||fs.readFileSync(path.join(R,'plateau-politique.js'),'utf8');
const f=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='renderRoomActions');
if(process.argv.includes('--contre-catalogue'))patch['i18n/ordres.js']=patch['i18n/ordres.js'].replace(/const description=[^\n]+;/,'const description=null;');
if(process.argv.includes('--contre-salle'))patch['i18n/plateau-init.js']=patch['i18n/plateau-init.js'].replace('global.RPRoomI18n?.refreshVisibleLabels?.(global.document);','void 0;');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.HG_CHROMIUM||'/usr/bin/chromium',args:['--no-sandbox']});
 try{
 const context=await browser.newContext({viewport:{width:360,height:800},isMobile:true,hasTouch:true});let network=0;await context.route('**/*',r=>{network++;return r.abort()});
 const page=await context.newPage();
 await page.setContent('<html><body><label data-i18n="plateau.messages">Messages</label><div id="action-context-bat"></div><div id="actions-row-bat"></div><div id="piece-nom"></div><div id="postes-body"></div><input id="saisie" value="Texte de test, محفوظ"><textarea id="message">Brouillon privé fictif</textarea></body></html>');
 await page.evaluate(()=>Object.assign(window,{RP_I18N_GAME_ENABLED:true,state:{country:'republic',currentCity:'capitale',char:{country:'republic'},pa:30},COUNTRIES:{republic:{cur:'FR'}},WORLD:{republic:{capitale:{}}},TEST_MODE:false,ORDER_EFFECTS:{},ordresDeclaresDeLaPiece:r=>r.orders,intitulePoste:(id,c,t)=>t}));
 for(const n of ['i18next.min.js','resources.js','plateau-resources.js','orders-resources.js','order-variants-resources.js','order-templates-resources.js','ordres.js','room-resources.js','plateau-bridge.js','plateau-init.js'])await page.addScriptTag(patch['i18n/'+n]?{content:patch['i18n/'+n]}:{path:path.join(R,'i18n',n)});
 await page.addScriptTag({content:source.slice(f.start,f.end)});
 await page.addScriptTag({path:path.join(R,'i18n/forum-ui.js')});await page.addScriptTag(patch['forum.js']?{content:patch['forum.js']}:{path:path.join(R,'forum.js')});
 const result=await page.evaluate(async()=>{
  const order={fn:'plainte_police',label:'Porter plainte',pa:1,cost:200,type:'legal',icon:'ti-test'};
  const room={name:'Accueil',orders:[order]};window.renderRoomActions(room,'banque-privee','fixture');
  const button=document.querySelector('#actions-row-bat button'),node=button.querySelector('[data-rp-order-index]'),input=document.querySelector('#saisie');input.focus();input.setSelectionRange(2,6);
  const writes=[];for(const name of ['sbRpc','sbRpcVerdict','sbTransportRpc','sbSavePersonnage','sbSendMail','deduireCoutOrdre','doOrder'])window[name]=()=>{writes.push(name);throw Error('action métier interdite dans la recette')};
  const beforeState=JSON.stringify(state);
  const initial={handler:button.getAttribute('onclick'),cout:button.querySelector('.pa-cost').textContent,input:input.value,textarea:document.querySelector('#message').value};
  let checks=0;
  for(const l of ['en','es','zh-TW','ru','ko','ar','pt-BR','de','fr','ar','fr']){
   await i18next.changeLanguage(l);
   if(node.textContent!==RPOrderI18n.label(order,i18next,l))throw Error('ordre non traduit : '+l);
   if(button!==document.querySelector('#actions-row-bat button')||node!==button.querySelector('[data-rp-order-index]'))throw Error('noeud remplacé');
   if(button.getAttribute('onclick')!==initial.handler||button.querySelector('.pa-cost').textContent!==initial.cout||input.value!==initial.input||document.querySelector('#message').value!==initial.textarea||input.selectionStart!==2||input.selectionEnd!==6)throw Error('saisie, commande ou coût modifié');
   if(JSON.stringify(state)!==beforeState)throw Error('bascule modifie state');
   checks++;
  }
  // Menu conservé pendant un nouveau rendu : les index sont réutilisés.
  await i18next.changeLanguage('fr');renderRoomActions(room,'banque-privee','fixture');
  document.querySelector('#postes-body').innerHTML=document.querySelector('#actions-row-bat').innerHTML;
  const old=document.querySelector('#postes-body button'),oldHandler=old.getAttribute('onclick');
  const autre={fn:'reserver_chambre_hotel',i18nKey:'variant.hotel_standard',label:"Réserver une chambre d'hôtel",pa:0,cost:60,type:'legal',icon:'ti-bed'};
  state.currentCity='ville_a'; // Déplacement de fixture seulement, pas un ordre.
  renderRoomActions({name:'Accueil hôtel',orders:[autre]},'hotel-republica','fixture');await i18next.changeLanguage('de');
  const collision={attendu:RPOrderI18n.label(order,i18next,'de'),obtenu:old.querySelector('span[data-rp-order-index]').textContent,handler:old.getAttribute('onclick')};
  if(oldHandler!==collision.handler)throw Error('handler muté');
  // Une salle déjà affichée ne porte pas data-i18n (préservation du nom source).
  await i18next.changeLanguage('fr');
  const nom=RP_I18N_RESOURCES.fr.translation.rooms.accueil_banque;
  if(RPRoomI18n.bindLabel)RPRoomI18n.bindLabel(document.querySelector('#piece-nom'),'banque-nationale','accueil_banque',nom);
  else document.querySelector('#piece-nom').textContent=RPRoomI18n.label('banque-nationale','accueil_banque',nom);
  await i18next.changeLanguage('ar');
  const salle={source:nom,attendu:RPRoomI18n.label('banque-nationale','accueil_banque',nom),obtenu:document.querySelector('#piece-nom').textContent};
  await i18next.changeLanguage('fr');
  const host=document.createElement('section');document.body.append(host);
  host.innerHTML=renderForumNavItem('national',FORUMS_BASE.national)+renderMailCompose('Destinataire fictif','Brouillon fictif');
  const forum=host.querySelector('.forum-nav-name'),recipient=host.querySelector('#mail-to'),subject=host.querySelector('#mail-subject'),subjectBefore=subject.value;
  const previousForum=forum.textContent,editor=host.querySelector('.rich-content');editor.textContent='Corps de courrier saisi, محتوى';const bodyBefore=editor.innerHTML;
  subject.value='Sujet réellement modifié dans le formulaire';
  await i18next.changeLanguage('de');
  const forumMail={forum_avant:previousForum,forum_apres:forum.textContent,forum_attendu:RP_I18N_RESOURCES.de.translation.forumNames.national,
   mail_titre:host.querySelector('.forum-title-main').textContent,mail_attendu:RP_I18N_RESOURCES.de.translation.plateau.newMessage,
   saisie_conservee:recipient.value==='Destinataire fictif'&&subject.value==='Sujet réellement modifié dans le formulaire'&&host.querySelector('.rich-content')===editor&&editor.innerHTML===bodyBefore};
  if(!forumMail.saisie_conservee)throw Error('saisie mail perdue');
  return {bascules_positives:checks,collision_catalogues:collision,nom_salle:salle,forum_mail:forumMail,appels_metier:writes.length,mutation_metier:writes.length!==0,authenticated:false};
 });
 assert.equal(result.bascules_positives,11);assert.equal(result.appels_metier,0);assert.equal(network,0);result.requetes_reseau=network;(corrige?assert.equal:assert.notEqual)(result.collision_catalogues.obtenu,result.collision_catalogues.attendu);(corrige?assert.equal:assert.notEqual)(result.nom_salle.obtenu,result.nom_salle.attendu);result.correctif_reference=corrige;
 (corrige?assert.equal:assert.notEqual)(result.forum_mail.forum_apres,result.forum_mail.forum_attendu);(corrige?assert.equal:assert.notEqual)(result.forum_mail.mail_titre,result.forum_mail.mail_attendu);
 console.log(JSON.stringify(result));await context.close();
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
