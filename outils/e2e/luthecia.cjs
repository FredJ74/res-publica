#!/usr/bin/env node
// Parcours de l'interface reelle. Aucun SQL, injection d'etat ou RPC d'ecriture.
'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const {lancerChromium}=require('../bancs/fixtures/chromium-cdp.cjs');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
const code=(c)=>Object.assign(new Error(c),{code:c});
const SENSIBLES=['achat','production','offrir-a-boire','diner','reception'];
const CAS_REQUIS=['achat/succes','achat/rupture','achat/fonds-insuffisants','achat/rechargement','production/autorise','production/interdit','offrir-a-boire/acceptation','offrir-a-boire/refus-total','offrir-a-boire/gains-non-cumulables','offrir-a-boire/double-reponse','diner/deux-repas-deux-champagnes','diner/refus','diner/stock-insuffisant','diner/rejeu','reception/simple','reception/double','reception/reponse-perdue','session/reponse-tardive'];
async function borner(p,ms){let t;try{return await Promise.race([p,new Promise((_,j)=>{t=setTimeout(()=>j(code('DELAI_NETTOYAGE')),ms);})]);}finally{clearTimeout(t);}}

function configuration(env=process.env){
 let autorisation;try{autorisation=JSON.parse(env.HG_E2E_AUTORISATION_JSON||'null');}catch{throw code('AUTORISATION_JSON_INVALIDE');}
 const a=autorisation;
 const manquants=[];
 for(const n of ['HG_E2E_BASE_URL','HG_E2E_EMAIL','HG_E2E_PASSWORD','HG_E2E_PERSONNAGE','HG_E2E_UID'])if(!env[n])manquants.push(n);
 if(!a||a.comptesReservesAuxTests!==true||a.autoriseParResponsable!==true)manquants.push('AUTORISATION_EXPLICITE_COMPTES_TEST');
 if(manquants.length)return {bloque:true,manquants};
 const url=new URL(env.HG_E2E_BASE_URL);
 if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw code('URL_HTTPS_ORIGINE_REQUISE');
 if(a.origine!==url.origin||a.backend!=='https://jxpwoosmmhohoihxpbuc.supabase.co')throw code('ORIGINE_OU_BACKEND_NON_AUTORISE');
 const comptes=[{cle:'principal',nom:env.HG_E2E_PERSONNAGE,uid:env.HG_E2E_UID,email:env.HG_E2E_EMAIL,password:env.HG_E2E_PASSWORD}];
 if(env.HG_E2E_INVITE_EMAIL||env.HG_E2E_INVITE_PASSWORD){
  for(const n of ['EMAIL','PASSWORD','PERSONNAGE','UID'])if(!env['HG_E2E_INVITE_'+n])throw code('SECOND_COMPTE_INCOMPLET');
  comptes.push({cle:'invite',nom:env.HG_E2E_INVITE_PERSONNAGE,uid:env.HG_E2E_INVITE_UID,email:env.HG_E2E_INVITE_EMAIL,password:env.HG_E2E_INVITE_PASSWORD});
 }
 if(new Set(comptes.map(c=>c.uid)).size!==comptes.length)throw code('COMPTES_TEST_NON_DISTINCTS');
 for(const c of comptes)if(!a.comptes?.some(x=>x.personnage===c.nom&&x.uid===c.uid))throw code('IDENTITE_NON_AUTORISEE');
 const duree=Number(env.HG_E2E_MAX_MINUTES||30);
 if(!Number.isFinite(duree)||duree<1||duree>40)throw code('DUREE_HORS_LIMITES');
 const plan=env.HG_E2E_PLAN_JSON?JSON.parse(env.HG_E2E_PLAN_JSON):[];
 if(!Array.isArray(plan)||plan.length>100)throw code('PLAN_INVALIDE');
 for(const e of plan){
  if(e.cas&&!CAS_REQUIS.includes(e.cas))throw code('CAS_INCONNU');
  if(!['clic','saisie','recharger'].includes(e.type)||!SENSIBLES.includes(e.scenario)||!a.scenarios?.includes(e.scenario))throw code('ACTE_NON_AUTORISE');
  if(!a.economieIsolee||!a.entreprises?.length)throw code('RESSOURCES_ECONOMIQUES_NON_ISOLEES');
  if(!comptes.some(c=>c.cle===(e.acteur||'principal')))throw code('ACTEUR_PLAN_INCONNU');
  if(!e.attendu||typeof e.attendu!=='object'||!e.attendu.delta||!Object.keys(e.attendu.delta).length)throw code('VERIFICATION_SERVEUR_REQUISE');
  for(const [champ,v]of Object.entries(e.attendu.delta))if(!['liquide','arg','pa','hp','moral','inf','ent'].includes(champ)||typeof v!=='number'||!Number.isFinite(v))throw code('DELTA_INVALIDE_AVANT_ACTION');
  for(const [id,stocks]of Object.entries(e.attendu.stocks||{})){
   if(!a.entreprises.includes(id)||!stocks||typeof stocks!=='object')throw code('ENTREPRISE_ORACLE_NON_AUTORISEE');
   for(const q of Object.values(stocks))if(!Number.isInteger(q))throw code('DELTA_STOCK_INVALIDE_AVANT_ACTION');
  }
  if(e.type==='saisie'&&e.cas)throw code('SAISIE_NE_VALIDE_PAS_UN_CAS');
  if(e.cas&&!e.cas.startsWith(e.scenario+'/')&&!e.cas.startsWith('session/'))throw code('CAS_HORS_SCENARIO');
  if(e.type==='clic'&&(!e.selecteur||!e.handlerSHA256||!/^[a-f0-9]{64}$/.test(e.handlerSHA256)))throw code('HANDLER_EXACT_REQUIS');
  if(e.panne&&e.type!=='clic')throw code('PANNE_RESERVEE_A_UN_CLIC');
  if(e.type==='clic'&&(typeof e.attendu.uiTexte!=='string'||!e.attendu.uiTexte.trim()))throw code('VERIFICATION_UI_REQUISE');
  if(e.type==='clic'&&!e.panne&&typeof e.attendu.rpc?.ok!=='boolean')throw code('VERDICT_RPC_REQUIS');
  if(e.type==='saisie'&&(!e.selecteur||typeof e.valeur!=='string'||e.valeur.length>300))throw code('SAISIE_INVALIDE');
  if(e.panne&&!['perdre-reponse','retarder-reponse'].includes(e.panne))throw code('PANNE_INVALIDE');
  if(e.type==='clic'&&!/^[a-z][a-z0-9_]+$/.test(e.rpc||''))throw code('RPC_CIBLE_REQUISE');
 }
 return {url:url.origin,comptes,autorisation:a,duree,plan,bloque:false};
}
function proxyNavigateur(env){
 const source=env.HTTPS_PROXY||env.HTTP_PROXY;
 if(!source)return undefined;
 const u=new URL(source);
 if(!['http:','https:','socks5:'].includes(u.protocol))throw code('PROTOCOLE_PROXY_NON_SUPPORTE');
 return {server:u.protocol+'//'+u.hostname+(u.port?':'+u.port:''),...(u.username?{username:decodeURIComponent(u.username),password:decodeURIComponent(u.password)}:{})};
}
function resumerReseau(url,status){
 try{const u=new URL(url),rpc=u.pathname.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/),table=u.pathname.match(/^\/rest\/v1\/([a-z0-9_]+)$/);return {operation:rpc?'rpc:'+rpc[1]:table?'lecture:'+table[1]:u.pathname==='/api/chat'?'dialogue':'ressource',status};}catch{return {operation:'inconnue',status};}
}
function diagnostic(message){
 const s=String(message);return {empreinte:hash(s),categorie:/ERR_[A-Z_]+/.exec(s)?.[0]||(/timeout|timed out/i.test(s)?'DELAI':/auth|401|403/i.test(s)?'AUTH_OU_ACCES':'ERREUR_NAVIGATEUR')};
}
function comparer(avant,apres,attendu={}){
 for(const [k,v]of Object.entries(attendu.delta||{})){
  if(!['liquide','arg','pa','hp','moral','inf','ent'].includes(k)||typeof v!=='number'||!Number.isFinite(v))throw code('DELTA_INVALIDE');
  if(typeof avant[k]!=='number'||typeof apres[k]!=='number'||Math.abs(apres[k]-avant[k]-v)>1e-8)throw code('DELTA_SERVEUR_INATTENDU_'+k);
 }
 if(attendu.inventaireChange!==undefined&& (hash(avant.inventory)!==hash(apres.inventory))!==attendu.inventaireChange)throw code('INVENTAIRE_INATTENDU');
 for(const [id,stocks]of Object.entries(attendu.stocks||{}))for(const [produit,delta]of Object.entries(stocks)){
  if(!avant.entreprises[id]||!apres.entreprises[id]||typeof delta!=='number')throw code('STOCK_NON_VERIFIABLE');
  if((apres.entreprises[id].stockProduits?.[produit]??0)-(avant.entreprises[id].stockProduits?.[produit]??0)!==delta)throw code('DELTA_STOCK_INATTENDU');
 }
}
function preuve(s){return {liquide:s.liquide,arg:s.arg,pa:s.pa,hp:s.hp,moral:s.moral,inf:s.inf,ent:s.ent,inventaireSHA256:hash(s.inventory),entreprisesSHA256:hash(s.entreprises),batiment:s.current_building,piece:s.current_room};}
class Joueur{
 constructor(page,compte,conf,rapport,signal){this.page=page;this.compte=compte;this.conf=conf;this.rapport=rapport;this.signal=signal;this.derniereAction=0;}
 async rythme(deplacement=false){this.signal.throwIfAborted();const ms=(deplacement?2000:2000)+crypto.randomInt(deplacement?2001:3001);await pause(ms);this.signal.throwIfAborted();this.derniereAction=Date.now();}
 async etat(){return this.page.evaluate(()=>({nom:typeof state!=='undefined'?state.char?.name:null,uid:typeof rpAuthUid==='function'?rpAuthUid():null,pays:typeof state!=='undefined'?state.country:null,ville:typeof state!=='undefined'?state.currentCity:null,batiment:typeof state!=='undefined'?state.currentBuilding:null,piece:typeof state!=='undefined'?state.currentRoom:null,noeud:typeof rueCentraleNoeudActuel!=='undefined'?rueCentraleNoeudActuel:null,backend:typeof SUPABASE_URL!=='undefined'?SUPABASE_URL:null}));}
 async identite(){const s=await this.etat();if(s.nom!==this.compte.nom||s.uid!==this.compte.uid||s.pays!=='republic'||s.ville!=='capitale'||s.backend!==this.conf.autorisation.backend)throw code('IDENTITE_SESSION_OU_TERRITOIRE_CHANGE');return s;}
 async serveur(){
  await this.identite();
  const r=await this.page.evaluate(async({nom,uid,ids})=>{
   if(typeof sbGet!=='function')return null;
   const lignes=await sbGet('personnages','name=eq.'+encodeURIComponent(nom)+'&select=user_id,arg,liquide,pa,hp,moral,resources,stats,inventory,current_building,current_room');
   if(!Array.isArray(lignes)||lignes.length!==1||lignes[0].user_id!==uid)return null;
   const s=lignes[0];const entreprises={};
   for(const id of ids){const e=await sbGet('entreprises','id=eq.'+encodeURIComponent(id)+'&select=id,data');if(!Array.isArray(e)||e.length!==1)return null;entreprises[id]={stockProduits:e[0].data.stockProduits,caisse:e[0].data.caisse};}
   return {arg:s.arg,liquide:s.liquide,pa:s.pa,hp:s.hp,moral:s.moral,inf:s.resources?.inf,ent:s.stats?.ENT,inventory:s.inventory,current_building:s.current_building,current_room:s.current_room,entreprises};
  },{nom:this.compte.nom,uid:this.compte.uid,ids:this.conf.autorisation.entreprises||[]});
  await this.identite();if(!r)throw code('ETAT_SERVEUR_INACCESSIBLE');return r;
 }
 async clic(locator,deplacement=false){await this.rythme(deplacement);await this.identite();await locator.click({timeout:15000});}
 async connexion(){
  this.signal.throwIfAborted();
  await this.page.goto(this.conf.url+'/',{waitUntil:'domcontentloaded',timeout:45000});
  await this.page.locator('[onclick="ouvrirConnexionCompte()"]:visible').first().click();
  await this.page.locator('#connexion-email').fill(this.compte.email);
  await this.page.locator('#connexion-mdp').fill(this.compte.password);
  await this.rythme();
  await this.page.locator('#connexion-valider').click();
  await this.page.waitForFunction(()=>location.pathname.endsWith('plateau.html')&&typeof state!=='undefined'&&state.char?.name&&typeof rpAuthUid==='function'&&rpAuthUid(),null,{timeout:45000});
  await this.identite();await this.serveur();
 }
 async stable(batiment,piece){
  await this.page.waitForFunction(({b,p})=>typeof state!=='undefined'&&state.currentBuilding===b&&(!p||state.currentRoom===p)&&document.querySelector('#vue-batiment.active')&&document.querySelector('#piece-nom')?.textContent.trim()&&[...document.querySelectorAll('#piece-image img')].every(i=>i.complete&&i.naturalWidth>0),{b:batiment,p:piece},{timeout:30000});
  await this.identite();
  const limite=Date.now()+30000;
  while(Date.now()<limite){this.signal.throwIfAborted();const s=await this.serveur();if(s.current_building===batiment&&(!piece||s.current_room===piece))return s;await pause(1000);}
  throw code('POSITION_PIECE_NON_CONFIRMEE_SERVEUR');
 }
 async fermerModales(){
  for(const id of ['modal-pnj','modal-postes']){
   const m=this.page.locator('#'+id+'.open');if(!await m.count())continue;
   const fermeture=m.locator('.modal-close').first();
   if(!await fermeture.count())throw code('FERMETURE_MODALE_INTROUVABLE');
   await this.clic(fermeture);await m.waitFor({state:'hidden',timeout:10000});
  }
 }
 async positionRue(noeud){
  await this.identite();
  const r=await this.page.evaluate(async()=>typeof sbRpcVerdict==='function'?await sbRpcVerdict('rue_position_lire',{}):null);
  await this.identite();
  if(r?.ok!==true||r.country!=='republic'||r.city!=='capitale'||r.building!==null||r.street!==noeud)throw code('POSITION_RUE_NON_CONFIRMEE_SERVEUR');
  return r;
 }
 async sortir(){
  await this.fermerModales();await this.clic(this.page.locator('#vue-batiment .sortir-btn'),true);
  await this.page.locator('#vue-rue.active').waitFor({state:'visible',timeout:30000});
  await this.identite();const s=await this.serveur();
  await this.positionRue((await this.etat()).noeud);
  return s;
 }
 async aller(batiment){
  let s=await this.identite();if(s.batiment===batiment)return this.stable(batiment,s.piece);
  if(s.batiment&&s.batiment!=='rue-centrale')await this.sortir();
  for(let i=0;i<30;i++){
   s=await this.identite();
   const choix=await this.page.evaluate(({cible})=>{
    if(typeof RUE_CENTRALE_NOEUDS==='undefined'||typeof rueCentraleNoeudActuel==='undefined')return null;
    const nodes=RUE_CENTRALE_NOEUDS.republic,depart=rueCentraleNoeudActuel,origine=rueCentraleDepuisNoeud;
    const zones=nodes[depart]?.zonesParArrivee?.[origine]||nodes[depart]?.zones||[];
    const index=zones.findIndex(z=>z.buildingId===cible);if(index>=0)return {zone:index};
    const file=[[depart,null,origine]],vus=new Set();
    while(file.length){const [n,premier,depuis]=file.shift(),cle=n+'|'+depuis;if(vus.has(cle))continue;vus.add(cle);const node=nodes[n];if(!node||!n.startsWith('luthecia-'))continue;
     if((node.zones||[]).some(z=>z.buildingId===cible))return premier;
     const liens=node.liensParArrivee?.[depuis]||node.liens||{};
     for(const [dir,destination]of Object.entries(liens))if(destination)file.push([destination,premier||{dir},n]);
    }return null;
   },{cible:batiment});
   if(!choix)throw code('CHEMIN_UI_NON_TROUVE');
   if(choix.zone!==undefined){await this.clic(this.page.locator('#rc-scene .rc-zone').nth(choix.zone),true);const now=await this.etat();return this.stable(batiment,now.piece);}
   const noeud=s.noeud;
   await this.clic(this.page.locator('.rc-fleche[onclick*="'+"'"+choix.dir+"'"+'"]'),true);
   await this.page.waitForFunction(n=>typeof rueCentraleNoeudActuel!=='undefined'&&rueCentraleNoeudActuel!==n,noeud,{timeout:30000});
   await this.positionRue((await this.etat()).noeud);
  }throw code('CHEMIN_UI_TROP_LONG');
 }
 async piece(batiment,piece){await this.clic(this.page.locator('#pieces-tabs .piece-tab[onclick*="'+"'"+piece+"'"+'"]'),true);return this.stable(batiment,piece);}
 async observer(){
  const s=await this.identite(),serveur=await this.serveur();
  const affichage=await this.page.evaluate(()=>({liquide:state.liquide,pa:state.pa,hp:state.hp,moral:state.moral,ordres:[...document.querySelectorAll('#vue-batiment [onclick*="doOrder("]')].map(e=>({libelle:e.textContent.trim(),handler:e.getAttribute('onclick')}))}));
  for(const k of ['liquide','pa','hp','moral'])if(affichage[k]!==serveur[k])throw code('MIROIR_CLIENT_SERVEUR_DIFFERENT_'+k);
  this.rapport.visites.push({acteur:this.compte.cle,batiment:s.batiment,piece:s.piece,preuve:preuve(serveur),ordresVisibles:affichage.ordres.map(o=>({libelle:o.libelle,handlerSHA256:hash(o.handler)}))});
 }
 async ouvrirOrdreLecture(fn){
  if(!['consulter_dossier_notarial','reclamer_heritage','officialiser_transaction','consulter_archives_notariales'].includes(fn))throw code('CONSULTATION_NON_AUTORISEE');
  const avant=await this.serveur();
  await this.clic(this.page.locator('#vue-batiment [onclick*="doOrder("][onclick*="'+fn+'"]'));
  await this.page.locator('#modal-postes.open').waitFor({state:'visible',timeout:30000});
  await this.page.waitForFunction(()=>{const t=document.getElementById('postes-body')?.innerText||'';return t.trim()&&!/^Chargement[.\s…]*$/.test(t.trim());},null,{timeout:30000});
  const apres=await this.serveur();comparer(avant,apres,{delta:{liquide:0,arg:0,pa:0},inventaireChange:false});
  this.rapport.consultations.push({ordre:fn,acteur:this.compte.cle,avant:preuve(avant),apres:preuve(apres)});
  await this.fermerModales();
 }
 async catalogue(){
  const s=await this.identite();await this.clic(this.page.locator('#vue-batiment [onclick*="doOrder("][onclick*="consulter_carte_commerce"]'));
  const m=this.page.locator('#modal-postes.open');await m.waitFor({state:'visible',timeout:30000});
  await m.getByText('Fiche produit',{exact:true}).first().waitFor({state:'visible',timeout:30000});
  const articles=await m.locator('[onclick*="ouvrirFicheProduitCommerce"]').evaluateAll(boutons=>boutons.map(b=>{
   const id=b.getAttribute('onclick').match(/'([^']+)'\s*\)\s*$/)?.[1];
   const ligne=b.parentElement.parentElement,texte=ligne.innerText;
   const stock=texte.match(/Stock\s*:\s*(\d+)/)?.[1],prix=texte.match(/([\d\s\u00a0\u202f]+(?:,\d+)?)\s*FR/)?.[1];
   return {id,stock:stock===undefined?null:Number(stock),prix:prix===undefined?null:Number(prix.replace(/[\s\u00a0\u202f]/g,'').replace(',','.')),productionActive:!([...ligne.querySelectorAll('button')].find(x=>x.textContent==='Produire')?.disabled)};
  }));
  if(!articles.length||articles.some(a=>a.stock===null||a.prix===null))throw code('PRIX_OU_STOCK_NON_VERIFIABLE_UI');
  const champagne=articles.find(a=>a.id==='champagne_luthecia');
  if(!champagne||champagne.prix!==25)throw code('PRIX_CHAMPAGNE_INCORRECT');
  if(s.piece==='restaurant'&&articles.filter(a=>a.id?.startsWith('menu_gastronomique_')).some(a=>a.prix!==125))throw code('PRIX_REPAS_INCORRECT');
  if(s.piece==='bar'&&articles.find(a=>a.id==='cocktail_luthecia')?.prix!==25)throw code('PRIX_COCKTAIL_INCORRECT');

  const texte=await m.innerText();
  if(s.piece==='bar'&&/Menu Gastronomique|Amuse-bouche/i.test(texte))throw code('REPAS_DANS_CARTE_BAR');
  if(s.piece==='restaurant'&&/Cacahu[eè]tes|Cocktail/i.test(texte))throw code('PRODUIT_BAR_DANS_RESTAURANT');
  if(!/Champagne/i.test(texte)||!texte.includes('25'))throw code('CHAMPAGNE_ABSENT_OU_PRIX_NON_VISIBLE');
  await this.clic(m.getByText('Fiche produit',{exact:true}).first());
  await this.page.locator('#modal-postes.open').waitFor({state:'visible',timeout:10000});
  this.rapport.catalogues.push({piece:s.piece,texteSHA256:hash(texte),articles,fiches:articles.length});
  await this.fermerModales();
 }
 async dialogue(){
  const carte=this.page.locator('#persons-list .person-card[data-enc]').first();
  if(!await carte.count())throw code('PNJ_NON_PRESENT');
  // Le contenu encode doit confirmer un PNJ, jamais un autre joueur.
  const estPnj=await carte.evaluate(e=>{try{const p=JSON.parse(decodeURIComponent(e.dataset.enc));return !p.isRealPlayer&&!p.isPJ&&!p.estPJ&&!p.user_id;}catch{return false;}});
  if(!estPnj)throw code('CIBLE_DIALOGUE_NON_CONFIRMEE_PNJ');
  await this.clic(carte);
  await this.page.locator('#pnj-question-libre').waitFor({state:'visible',timeout:15000});
  await this.page.locator('#pnj-speech .pnj-loading').waitFor({state:'hidden',timeout:45000});
  const question='Bonjour. Pouvez-vous présenter votre rôle dans cet établissement ?';
  await this.page.locator('#pnj-question-libre').fill(question);
  await this.rythme();await this.identite();
  const attente=this.page.waitForResponse(r=>{try{return new URL(r.url()).origin===this.conf.url&&new URL(r.url()).pathname==='/api/chat'&&r.request().postDataJSON()?.message===question;}catch{return false;}},{timeout:45000});
  attente.catch(()=>{});
  await this.page.locator('#modal-pnj [onclick="envoyerQuestion()"]').click();
  const response=await attente;
  if(!response.ok())throw code('DIALOGUE_HTTP_'+response.status());
  const body=await response.json();
  const texte=body.reponse;
  if(typeof texte!=='string'||!texte.trim()||/revenir plus tard|revenez plus tard/i.test(texte))throw code('DIALOGUE_NON_ABOUTI');
  await this.page.waitForFunction(t=>document.getElementById('modal-pnj')?.innerText.includes(t),texte,{timeout:15000});
  const s=await this.identite();this.rapport.dialogues.push({batiment:s.batiment,piece:s.piece,reponseSHA256:hash(texte)});
  await this.fermerModales();
 }
 async acte(e){
  const avant=await this.serveur();let utilise=false;
  this.rapport.actesEnCours=this.rapport.actesEnCours||[];
  const enCours={scenario:e.scenario,cas:e.cas||null,acteur:this.compte.cle,avant:preuve(avant)};
  this.rapport.actesEnCours.push(enCours);this.sauver?.();
  let reponseAttendue,attenteUI;
  const motif='**/rest/v1/rpc/'+e.rpc;
  const route=async r=>{
   if(utilise||new URL(r.request().url()).origin!==this.conf.autorisation.backend)return r.continue();utilise=true;
   // Une seule execution serveur. Jamais de retry automatique d'une ecriture.
   const reponse=await r.fetch({maxRetries:0,maxRedirects:0});
   if(e.panne==='perdre-reponse')return r.abort('failed');
   await pause(8000);await r.fulfill({response:reponse});
  };
  if(e.panne)await this.page.route(motif,route);
  try{
   if(e.type==='recharger'){await this.rythme();await this.page.reload({waitUntil:'domcontentloaded'});await this.identite();}
   else{
    const l=this.page.locator(e.selecteur);if(await l.count()!==1)throw code('CIBLE_UI_NON_UNIQUE');
    if(e.type==='saisie'){await this.rythme();await this.identite();await l.fill(e.valeur);}
    else {if(hash(await l.getAttribute('onclick'))!==e.handlerSHA256)throw code('HANDLER_UI_MODIFIE');await this.rythme();await this.identite();
     const texte=this.page.getByText(e.attendu.uiTexte,{exact:false}).first();
     if(await texte.isVisible())await texte.waitFor({state:'hidden',timeout:15000});
     attenteUI=texte.waitFor({state:'visible',timeout:30000});attenteUI.catch(()=>{});
     if(!e.panne){reponseAttendue=this.page.waitForResponse(r=>r.url().split('?')[0]===this.conf.autorisation.backend+'/rest/v1/rpc/'+e.rpc,{timeout:30000});reponseAttendue.catch(()=>{});}
     await l.click({clickCount:e.doubleClic?2:1,delay:120});}
   }
   if(reponseAttendue){
    const rep=await reponseAttendue;
    if(!rep.ok())throw code('ACTE_HTTP_'+rep.status());
    const verdict=await rep.json();
    for(const [k,v]of Object.entries(e.attendu.rpc)){if(!['ok','rejeu','raison','total','pa','repas','champagnes'].includes(k)||verdict?.[k]!==v)throw code('VERDICT_RPC_INATTENDU');}
   }
   const limite=Date.now()+30000;let apres,erreur;
   do{this.signal.throwIfAborted();apres=await this.serveur();try{comparer(avant,apres,e.attendu);erreur=null;break;}catch(x){erreur=x;}await pause(1000);}while(Date.now()<limite);
   if(erreur)throw erreur;
   if(e.panne&&!utilise)throw code('PANNE_NON_EXERCEE');
   if(attenteUI)await attenteUI;
   this.rapport.actes.push({scenario:e.scenario,cas:e.cas||null,acteur:this.compte.cle,type:e.type,avant:preuve(avant),apres:preuve(apres),panne:e.panne||null});
   this.rapport.actesEnCours=this.rapport.actesEnCours.filter(x=>x!==enCours);this.sauver?.();
  }finally{if(e.panne)await this.page.unroute(motif,route);}
 }
}
async function campagne({env=process.env,prevol=false,interruption,dossier=env.HG_E2E_RAPPORT||path.join(os.tmpdir(),'hg-e2e-'+Date.now())}={}){
 fs.mkdirSync(dossier,{recursive:true,mode:0o700});
 const rapport={debut:new Date().toISOString(),mode:prevol?'prevol':'authentifie-demande',statut:'BLOQUE',visites:[],dialogues:[],catalogues:[],consultations:[],actes:[],etapes:[],reseau:[],erreurs:[],nonExecutes:[...SENSIBLES],casNonExecutes:[...CAS_REQUIS],actesEnCours:[],limites:['Aucun test local ne constitue une preuve authentifiee.']};
 let conf,navigateur,browser,profil,timer,signal,retirerInterruption=()=>{};
 const fichier=path.join(dossier,'rapport.json');
 const enregistrer=()=>fs.writeFileSync(fichier,JSON.stringify(rapport,null,2)+'\n',{mode:0o600});
 try{
  conf=configuration(env);
  if(env.HG_E2E_REPRISE_DOSSIER&&conf.plan?.length){const ancien=JSON.parse(fs.readFileSync(path.join(env.HG_E2E_REPRISE_DOSSIER,'rapport.json'),'utf8'));if(ancien.actes?.length||ancien.actesEnCours?.length)throw code('REPRISE_SENSIBLE_RECONCILIATION_REQUISE');}
  if(conf.bloque){rapport.blocages=conf.manquants;return rapport;}
  const http=await require('playwright').request.newContext({proxy:proxyNavigateur(env)});
  try{const test=await http.get(conf.url+'/',{timeout:15000,maxRedirects:0});if(!test.ok())throw code('SITE_HTTP_'+test.status());}
  finally{await http.dispose();}
  if(prevol){rapport.statut='PREVOL_LOCAL_CONFORME_AUTHENTIFICATION_NON_TESTEE';return rapport;}
  const controller=new AbortController();signal=controller.signal;
  const arret=()=>controller.abort();
  interruption?.addEventListener('abort',arret,{once:true});
  retirerInterruption=()=>interruption?.removeEventListener('abort',arret);
  signal.addEventListener('abort',()=>browser?.close().catch(()=>{}),{once:true});
  timer=setTimeout(arret,conf.duree*60000);
  if(interruption?.aborted)throw code('CAMPAGNE_INTERROMPUE');
  profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-joueur-'));
  const executable=env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync);
  if(!executable)throw code('CHROMIUM_ABSENT');
  navigateur=await lancerChromium({executable,profil,delaiDemarrage:30000});
  browser=await require('playwright').chromium.connectOverCDP('http://127.0.0.1:'+navigateur.port);
  signal.throwIfAborted();
  const joueurs={};
  for(const compte of conf.comptes){
   const context=await browser.newContext({viewport:{width:1440,height:1000},serviceWorkers:'block',proxy:proxyNavigateur(env)}),page=await context.newPage();
   page.setDefaultTimeout(15000);page.setDefaultNavigationTimeout(45000);
   page.on('pageerror',e=>rapport.erreurs.push({acteur:compte.cle,...diagnostic(e.message)}));
   page.on('console',m=>{if(m.type()==='error')rapport.erreurs.push({acteur:compte.cle,...diagnostic(m.text())});});
   page.on('response',r=>{if(r.status()>=400||/\/rest\/v1\/rpc\/|\/api\/chat/.test(r.url()))rapport.reseau.push({acteur:compte.cle,...resumerReseau(r.url(),r.status())});});
   page.on('requestfailed',r=>rapport.reseau.push({acteur:compte.cle,...resumerReseau(r.url(),null),...diagnostic(r.failure()?.errorText)}));
   const j=new Joueur(page,compte,conf,rapport,signal);j.sauver=enregistrer;joueurs[compte.cle]=j;await j.connexion();
  }
  const j=joueurs.principal;
  async function etape(nom,fn,joueur=j){signal.throwIfAborted();const debut=Date.now();try{await fn();rapport.etapes.push({nom,resultat:'REUSSI',dureeMs:Date.now()-debut});}catch(e){rapport.etapes.push({nom,resultat:'ECHEC',code:e.code||'UI_OU_SERVEUR_NON_CONFIRME',...diagnostic(e.message)});try{await joueur.identite();await joueur.page.screenshot({path:path.join(dossier,'echec-'+rapport.etapes.length+'.png')});}catch{}throw e;}finally{enregistrer();}}
  await etape('office-notarial-entree',()=>j.aller('office-notarial'));
  for(const piece of ['accueil_notaire','bureau_successions','bureau_contrats','archives_notariales'])await etape('office-notarial-'+piece,async()=>{await j.piece('office-notarial',piece);await j.observer();const ordre={accueil_notaire:'consulter_dossier_notarial',bureau_successions:'reclamer_heritage',bureau_contrats:'officialiser_transaction',archives_notariales:'consulter_archives_notariales'}[piece];await j.ouvrirOrdreLecture(ordre);if(piece==='accueil_notaire')await j.dialogue();});
  await etape('office-notarial-sortie-sans-rechargement',()=>j.sortir());
  await etape('hotel-entree',()=>j.aller('hotel-republica'));
  for(const piece of ['accueil','bar','restaurant'])await etape('hotel-'+piece,async()=>{await j.piece('hotel-republica',piece);await j.observer();if(piece!=='accueil')await j.catalogue();});
  await etape('hotel-rechargement',async()=>{const s=await j.identite();await j.rythme();await j.page.reload({waitUntil:'domcontentloaded'});await j.stable(s.batiment,s.piece);await j.observer();});
  for(const [i,e]of conf.plan.entries())await etape('acte-autorise-'+i,()=>joueurs[e.acteur||'principal'].acte(e),joueurs[e.acteur||'principal']);
  rapport.nonExecutes=SENSIBLES.filter(s=>!rapport.actes.some(a=>a.scenario===s&&a.type==='clic'));
  await etape('hotel-sortie',()=>j.sortir());
  rapport.casNonExecutes=CAS_REQUIS.filter(c=>!rapport.actes.some(a=>a.cas===c&&['clic','recharger'].includes(a.type)));
  rapport.statut=rapport.casNonExecutes.length||rapport.nonExecutes.length?'PARCOURS_AUTHENTIFIE_PARTIEL':'PARCOURS_AUTHENTIFIE_REUSSI';
  if(rapport.erreurs.length)rapport.statut='PARCOURS_AVEC_ANOMALIES_A_EXAMINER';
 }catch(e){rapport.blocages=[e.code||'ACCES_OU_EXECUTION_IMPOSSIBLE'];rapport.erreurs.push(diagnostic(e.message));rapport.statut=rapport.visites.length?'PARCOURS_INTERROMPU':'BLOQUE';}
 finally{
  clearTimeout(timer);retirerInterruption();
  try{await borner(browser?.close(),10000);}catch{rapport.erreurs.push({categorie:'FERMETURE_PLAYWRIGHT'});}
  try{await navigateur?.arreter();}catch{rapport.erreurs.push({categorie:'ARRET_CHROMIUM_NON_CONFIRME'});rapport.statut='NETTOYAGE_ECHOUE';}
  if(profil)try{fs.rmSync(profil,{recursive:true,force:true,maxRetries:3,retryDelay:100});}catch{rapport.statut='NETTOYAGE_ECHOUE';rapport.erreurs.push({categorie:'PROFIL_NON_SUPPRIME'});}
  rapport.fin=new Date().toISOString();enregistrer();
 }
 return rapport;
}
if(require.main===module){const arret=new AbortController();for(const sig of ['SIGINT','SIGTERM'])process.once(sig,()=>arret.abort());campagne({interruption:arret.signal,prevol:process.argv.includes('--prevol')}).then(r=>{console.log(JSON.stringify({statut:r.statut,visites:r.visites.length,actes:r.actes.length,blocages:r.blocages||[],rapport:process.env.HG_E2E_RAPPORT||'repertoire temporaire'}));process.exitCode=r.statut==='PARCOURS_AUTHENTIFIE_REUSSI'||r.statut==='PREVOL_LOCAL_CONFORME_AUTHENTIFICATION_NON_TESTEE'?0:2;}).catch(()=>{console.error('EXECUTEUR_ECHEC');process.exitCode=1;});}
module.exports={proxyNavigateur,configuration,resumerReseau,diagnostic,comparer,preuve,Joueur,campagne,hash};
