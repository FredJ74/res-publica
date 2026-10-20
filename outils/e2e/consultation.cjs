'use strict';
// Restriction du pilote, jamais une autorisation serveur ni une substitution d'identite.
const crypto=require('node:crypto');
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
const erreur=c=>Object.assign(new Error(c),{code:c});
const RPC_LECTURE=new Set(['mon_personnage','rue_position_lire','rue_sortie_batiment_lire','inventaire_reception_etat']);
function verifierConsultation(env,a){
 if(env.HG_E2E_PERSONNAGE!=='Arnie')throw erreur('CONSULTATION_RESERVEE_A_ARNIE');
 if(env.HG_E2E_DECLENCHEMENT==='schedule')throw erreur('CAMPAGNE_RECURRENTE_ARNIE_INTERDITE');
 if(a?.autoriseParResponsable!==true||a?.mode!=='consultation_seule'||a?.personnageHistoriqueAutorise!=='Arnie')throw erreur('AUTORISATION_CONSULTATION_ARNIE_REQUISE');
 if(env.HG_E2E_PLAN_JSON&&JSON.stringify(JSON.parse(env.HG_E2E_PLAN_JSON))!=='[]')throw erreur('PLAN_SENSIBLE_INTERDIT_EN_CONSULTATION');
 if(env.HG_E2E_INVITE_EMAIL||env.HG_E2E_INVITE_PASSWORD||a.entreprises?.length||a.scenarios?.length)throw erreur('CONTREPARTIES_INTERDITES_EN_CONSULTATION');
 const audit=a.auditArnie;
 if(!audit||audit.personnage!=='Arnie'||audit.uid!==env.HG_E2E_UID||audit.authUsersVerifie!==true||audit.memePersonnageVerifie!==true)throw erreur('AUDIT_SUPABASE_ARNIE_REQUIS');
 if(!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(audit.uid||''))throw erreur('UID_ARNIE_NON_VERIFIE');
 if(audit.nombrePersonnagesDuCompte!==1)throw erreur('COMPTE_ARNIE_MULTIPERSONNAGES_A_AUDITER');
 const adresse=crypto.createHash('sha256').update((env.HG_E2E_EMAIL||'').trim().toLowerCase()).digest('hex');
 if(!env.HG_E2E_EMAIL||audit.adresseSHA256!==adresse)throw erreur('ADRESSE_NON_VERIFIEE_POUR_UID_ARNIE');
 const date=Date.parse(audit.verifieLe||'');
 if(!Number.isFinite(date)||Date.now()-date>86400000||date-Date.now()>300000)throw erreur('AUDIT_ARNIE_ABSENT_OU_EXPIRE');
 if(audit.anonyme===true)throw erreur('COMPTE_ARNIE_ANONYME_ACCES_INDEPENDANT_NON_DISPONIBLE');
 if(audit.anonyme!==false||audit.emailConfirme!==true)throw erreur('AUTHENTIFICATION_ARNIE_NON_CONFIRMEE');
 if(audit.navigationSansEffetVerifiee!==true)throw erreur('AUDIT_EFFETS_NAVIGATION_REQUIS');
 return true;
}
function uidJeton(entetes){
 // Seulement le JWT emis par la connexion independante de CE contexte. Pas de stockage/export.
 // Le sub ne prouve PAS l'authentification : GoTrue et les controles serveur restent obligatoires.
 try{return JSON.parse(Buffer.from((entetes.authorization||'').replace(/^Bearer\s+/i,'').split('.')[1],'base64url')).sub;}catch{return null;}
}
function decisionConsultation({url,methode,corps,entetes={}},conf,session){
 const u=new URL(url),backend=conf.autorisation.backend;
 const authentifie=session.uidValide===true&&uidJeton(entetes)===conf.comptes[0].uid;
 if(methode==='OPTIONS')return {action:'autoriser'};
 if(u.origin===backend&&u.pathname==='/auth/v1/token'&&methode==='POST'&&['password','refresh_token'].includes(u.searchParams.get('grant_type')))return {action:'verifier-auth'};
 if(u.origin===backend&&u.pathname.startsWith('/auth/')){
  if(methode==='GET'&&u.pathname==='/auth/v1/user'&&authentifie)return {action:'verifier-auth'};
  return {action:'bloquer',raison:'AUTHENTIFICATION_NON_AUTORISEE'};
 }
 const rpc=u.origin===backend&&u.pathname.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/)?.[1];
 if(rpc){
  if(!authentifie)return {action:'bloquer',raison:'IDENTITE_NON_CONFIRMEE'};
  if(RPC_LECTURE.has(rpc)&&['GET','POST'].includes(methode))return {action:rpc==='mon_personnage'?'verifier-personnage':'autoriser'};
  if(rpc==='rue_position_enregistrer'&&methode==='POST'&&session.personnageValide&&corps&&Object.keys(corps).length===1&&/^luthecia-[a-z0-9-]+$/.test(corps.p_noeud||''))return {action:'autoriser'};
  return {action:'bloquer',raison:'RPC_NON_VERIFIEE_SANS_EFFET'};
 }
 if((u.origin===conf.url&&u.pathname.startsWith('/api/'))||(u.origin===backend&&u.pathname.startsWith('/functions/')))return {action:'bloquer',raison:'API_A_EFFETS_NON_EXCLUS'};
 if(u.pathname==='/api/chat')return {action:'bloquer',raison:'DIALOGUE_A_EFFETS_NON_EXCLUS'};
 if(!['GET','HEAD'].includes(methode))return {action:'bloquer',raison:'ECRITURE_INTERDITE_EN_CONSULTATION'};
 // Toute sauvegarde, reception, invitation, effet ou progression reste donc refusee,
 // y compris PATCH de position a travers la vue legacy qui reecrit une fiche complete.
 return {action:'autoriser'};
}
async function installerConsultation(context,conf,rapport){
 const session={uidValide:false,personnageValide:false};
 rapport.protectionsConsultation={mode:'consultation_seule',personnage:'Arnie',authentificationVerifiee:false,personnageVerifie:false,refus:[]};
 if(typeof context.routeWebSocket==='function')await context.routeWebSocket('**/*',ws=>{rapport.protectionsConsultation.refus.push({raison:'WEBSOCKET_INTERDIT_EN_CONSULTATION',operation:'websocket'});ws.close({code:1008,reason:'consultation_seule'});});
 await context.route('**/*',async route=>{
  const req=route.request();let corps;try{corps=req.postDataJSON();}catch{}
  const decision=decisionConsultation({url:req.url(),methode:req.method(),corps,entetes:await req.allHeaders()},conf,session);
  const refuser=async raison=>{rapport.protectionsConsultation.refus.push({raison,methode:req.method(),operation:new URL(req.url()).pathname.split('/').filter(Boolean).slice(-1)[0]?.replace(/[^a-z0-9_-]/gi,'').slice(0,80)||'racine'});await route.abort('blockedbyclient');};
  if(decision.action==='bloquer')return refuser(decision.raison);
  if(decision.action==='autoriser')return route.continue();
  const res=await route.fetch({maxRetries:0,maxRedirects:0});
  if(!res.ok())return route.fulfill({response:res}); // Refus reel du fournisseur, jamais transforme en succes.
  const d=await res.json().catch(()=>null);
  if(decision.action==='verifier-auth'){
   const user=d?.user||d;
   if(user?.id!==conf.comptes[0].uid||user?.is_anonymous!==false||!user?.email_confirmed_at){
    session.uidValide=false;session.personnageValide=false;rapport.protectionsConsultation.authentificationVerifiee=false;rapport.protectionsConsultation.personnageVerifie=false;return refuser('COMPTE_DIFFERENT_OU_NON_CONFIRME');
   }
   session.uidValide=true;rapport.protectionsConsultation.authentificationVerifiee=true;
  }else{
   const valeur=Array.isArray(d)?(d.length===1?d[0]:null):d;
   const nom=valeur?.mon_personnage??valeur;
   if(nom!=='Arnie'){session.personnageValide=false;return refuser('PERSONNAGE_AUTRE_QUE_ARNIE');}
   session.personnageValide=true;rapport.protectionsConsultation.personnageVerifie=true;
  }
  return route.fulfill({response:res}); // Reponse reelle uniquement, aucun jeton conserve par le pilote.
 });
 return session;
}
function empreinteProtegee(ligne){
 const stable={...ligne};for(const k of ['current_city','current_building','current_room','updated_at'])delete stable[k];
 return hash(Object.fromEntries(Object.entries(stable).sort(([a],[b])=>a.localeCompare(b))));
}
module.exports={verifierConsultation,decisionConsultation,installerConsultation,empreinteProtegee};
