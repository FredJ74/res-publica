const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn'),root=path.resolve(__dirname,'../..');
function extraire(f,noms){const rue=f==='plateau-rue-centrale.js'&&noms.some(n=>['initialiserRueCentrale','afficherNoeudRue'].includes(n));if(rue)noms=[...noms,'contexteNavigationRue','contexteNavigationRueValide'];const s=fs.readFileSync(path.join(root,f),'utf8');return (rue?'let rueCentraleLecturePosition=0,rueCentraleDeplacementEnCours=null;':'')+acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
function mails(){
 let cache=[];const c=vm.createContext({state:{char:{name:'Alice'}},console,Map,Set,rpAuthUid:()=> 'uid',rpAuthSessionIdentifiant:()=> 'connexion',getMails:()=>cache,saveMails:x=>cache=x,
 getMyMails:()=>cache,mailsRecusVisibles:()=>cache.filter(m=>m.to==='Alice'&&!m.archived),trierMailsRecents:x=>x,escapeHtmlText:s=>s,formatDateAffichage:s=>s||'',renderForumModal(){},rafraichirVoyantsEtCompteursForum(){}});
 vm.runInContext("let mailLectureSequence=0,mailRubrique='recus',mailView='inbox',forumView='mail';const FORUM_VUES_COMPOSITION=['compose-canvas','edit-post','new-topic','reply'];"+extraire('forum.js',['loadMailsFromSB','selectionnerRubriqueMail','switchToMail','forumEstEnCompositionActuellement','renderMailInbox']),c);
 c.cache=()=>cache;c.rubrique=()=>vm.runInContext('mailRubrique',c);return c;
}
test('messagerie : chaque rubrique affiche exclusivement ses messages, y compris organisations',()=>{
 const c=mails();c.saveMails([{id:'recu',to:'Alice',from:'Jodie',subject:'RECU'},{id:'envoye',from:'Association',fromReal:'Alice',fromIsOrg:true,to:'Bob',subject:'ENVOYE'},{id:'archive',from:'Bob',to:'Alice',archived:true,subject:'ARCHIVE'}]);
 for(const [r,contenu,autres] of [['recus','RECU',['ENVOYE','ARCHIVE']],['envoyes','ENVOYE',['RECU','ARCHIVE']],['archives','ARCHIVE',['RECU','ENVOYE']]]){
  c.selectionnerRubriqueMail(r);const html=c.renderMailInbox();assert.ok(html.includes("readMail('"+({RECU:'recu',ENVOYE:'envoye',ARCHIVE:'archive'}[contenu])+"')"));for(const autre of autres)assert.ok(!html.includes("readMail('"+({RECU:'recu',ENVOYE:'envoye',ARCHIVE:'archive'}[autre])+"')"));
 }
});
test('ouverture par defaut recus ; retour asynchrone preserve la rubrique selectionnee',async()=>{
 const c=mails();let resolve;c.sbGetMailsFor=()=>new Promise(r=>resolve=r);c.selectionnerRubriqueMail('archives');c.switchToMail();assert.equal(c.rubrique(),'recus');c.selectionnerRubriqueMail('envoyes');resolve([]);await new Promise(r=>setImmediate(r));assert.equal(c.rubrique(),'envoyes');
});
test('interview et apercu Jodie proteges comme les brouillons',()=>{const c=mails();for(const v of ['compose','jodie-interview','jodie-preview']){vm.runInContext(`mailView='${v}'`,c);assert.equal(c.forumEstEnCompositionActuellement(),true);}});
test('lecture tardive d un ancien personnage ne remplit pas la boite du suivant',async()=>{const c=mails();let resolve;c.sbGetMailsFor=()=>new Promise(r=>resolve=r);const p=c.loadMailsFromSB();c.state.char={name:'Bob'};resolve([{id:'ancien'}]);await p;assert.equal(c.cache().length,0);});
test('lectures dans le desordre : seule la derniere requete modifie le cache',async()=>{const c=mails();const resolvers=[];c.sbGetMailsFor=()=>new Promise(r=>resolvers.push(r));const a=c.loadMailsFromSB(),b=c.loadMailsFromSB();resolvers[1]([{id:'nouveau'}]);await b;resolvers[0]([{id:'ancien'}]);await a;assert.equal(c.cache()[0].id,'nouveau');});
test('changement de connexion : ancien retour ignore ; lu local conserve lors du refresh',async()=>{const c=mails();let resolve;c.sbGetMailsFor=()=>new Promise(r=>resolve=r);const p=c.loadMailsFromSB();c.rpAuthSessionIdentifiant=()=> 'nouvelle';resolve([{id:'ancien'}]);await p;assert.equal(c.cache().length,0);c.saveMails([{id:'lu',read:true}]);c.sbGetMailsFor=async()=>[{id:'lu',read:false}];await c.loadMailsFromSB();assert.equal(c.cache()[0].read,true);});
for(const room of ['accueil','bureau'])test(`F5 en ${room} : aucune alerte ni ordre de deplacement`,async()=>{
 const appels=[],toasts=[];const c=vm.createContext({state:{currentCity:'capitale'},sbRpc:async f=>{appels.push(f);return {ok:true,country:'republic',city:'capitale',building:'mairie',room};},showToast:(...a)=>toasts.push(a),RUE_CENTRALE_NOEUDS:{republic:{depart:{}}},afficherNoeudRue:()=>assert.fail('pas de sortie automatique')});
 vm.runInContext(extraire('plateau-rue-centrale.js',['initialiserRueCentrale']),c);await c.initialiserRueCentrale('republic','depart',null);assert.deepEqual(appels,['rue_position_lire']);assert.equal(toasts.length,0);
});
test('F5 en rue : position serveur affichee sans ecriture ; panne reste signalee',async()=>{
 const toasts=[];let rendu;const c=vm.createContext({state:{currentCity:'capitale'},sbRpc:async()=>({ok:true,country:'republic',city:'capitale',street:'depart'}),showToast:(...a)=>toasts.push(a),RUE_CENTRALE_NOEUDS:{republic:{depart:{}}},afficherNoeudRue:(...a)=>rendu=a});vm.runInContext(extraire('plateau-rue-centrale.js',['initialiserRueCentrale']),c);await c.initialiserRueCentrale('republic','depart',null);assert.equal(rendu[3],true);c.sbRpc=async()=>null;await c.initialiserRueCentrale('republic','depart',null);assert.equal(toasts.length,1);
});
