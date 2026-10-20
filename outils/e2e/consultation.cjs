'use strict';
// Restriction du pilote, jamais une autorisation serveur ni une substitution d'identite.
const crypto=require('node:crypto');
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
const erreur=c=>Object.assign(new Error(c),{code:c});
const RPC_LECTURE=new Set(['mon_personnage','rue_position_lire','rue_sortie_batiment_lire','inventaire_reception_etat']);
function verifierConsultation(env,a){
 if(env.HG_E2E_PERSONNAGE!=='Arnie')throw erreur('CONSULTATION_RESERVEE_A_ARNIE');
 if(env.HG_E2E_DECLENCHEMENT!=='workflow_dispatch')throw erreur('CONSULTATION_ARNIE_MANUELLE_REQUISE');
 if(env.HG_E2E_PLAN_JSON&&JSON.stringify(JSON.parse(env.HG_E2E_PLAN_JSON))!=='[]')throw erreur('PLAN_SENSIBLE_INTERDIT_EN_CONSULTATION');
 if(env.HG_E2E_INVITE_EMAIL||env.HG_E2E_INVITE_PASSWORD||a?.entreprises?.length||a?.scenarios?.length)throw erreur('CONTREPARTIES_INTERDITES_EN_CONSULTATION');
 if(!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(env.HG_E2E_UID||''))throw erreur('UID_ARNIE_NON_VERIFIE');
 if(env.HG_E2E_BASE_URL&&new URL(env.HG_E2E_BASE_URL).origin!=='https://res-publica.vercel.app')throw erreur('ORIGINE_ARNIE_NON_AUTORISEE');
 // Portee fixe issue de l'autorisation du proprietaire, PAS une declaration d'audit.
 // L'identite et la position seront verifiees par des reponses serveur avant la page.
 return {origine:'https://res-publica.vercel.app',backend:'https://jxpwoosmmhohoihxpbuc.supabase.co',
  comptes:[{personnage:'Arnie',uid:env.HG_E2E_UID}],entreprises:[],scenarios:[]};
}
function verifierUtilisateur(user,compte){
 if(user?.id!==compte.uid||user?.is_anonymous!==false||!user?.email_confirmed_at||
  typeof user.email!=='string'||user.email.trim().toLowerCase()!==compte.email.trim().toLowerCase())throw erreur('COMPTE_DIFFERENT_OU_NON_CONFIRME');
}
async function prevolAutomatique(request,conf,clePublique){
 const compte=conf.comptes[0],backend=conf.autorisation.backend;
 async function lire(chemin,options={}){
  let res;try{res=await request.fetch(backend+chemin,{...options,timeout:15000,maxRedirects:0,maxRetries:0});}catch{throw erreur('PREVOL_TRANSPORT_INDISPONIBLE');}
  if(!res.ok())throw erreur('PREVOL_HTTP_'+res.status());
  const d=await res.json().catch(()=>{throw erreur('PREVOL_REPONSE_INVALIDE');});return d;
 }
 const auth=await lire('/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:clePublique},data:{email:compte.email,password:compte.password}});
 verifierUtilisateur(auth?.user,compte);
 if(typeof auth.access_token!=='string'||!auth.access_token)throw erreur('PREVOL_SESSION_ABSENTE');
 const headers={apikey:clePublique,Authorization:'Bearer '+auth.access_token};
 verifierUtilisateur(await lire('/auth/v1/user',{method:'GET',headers}),compte);
 const nom=await lire('/rest/v1/rpc/mon_personnage',{method:'POST',headers,data:{}});
 if(nom!=='Arnie')throw erreur('PERSONNAGE_AUTRE_QUE_ARNIE');
 // Le filtre d'UID sert seulement a lire : les droits RLS restent ceux de la session.
 const lignes=await lire('/rest/v1/personnages?user_id=eq.'+encodeURIComponent(compte.uid)+'&select=*&limit=2',{method:'GET',headers});
 if(!Array.isArray(lignes)||lignes.length!==1||lignes[0].name!=='Arnie'||lignes[0].user_id!==compte.uid)throw erreur('COMPTE_ARNIE_AMBIGU_OU_INACCESSIBLE');
 const ligne=lignes[0];
 if(ligne.country!=='republic'||ligne.current_city!=='capitale')throw erreur('ARNIE_HORS_LUTHECIA_AUCUN_DEPLACEMENT');
 return {authentificationVerifiee:true,personnageVerifie:true,personnageUniqueVisible:true,
  ficheSHA256:empreinteProtegee(ligne),position:{batiment:ligne.current_building,piece:ligne.current_room},
  limite:'La lecture sous RLS ne certifie pas les lignes invisibles ni les fonctions de mouvement.'};
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
 if(u.origin===backend&&u.pathname==='/auth/v1/token'&&methode==='POST'&&['password','refresh_token'].includes(u.searchParams.get('grant_type'))){
  if(u.searchParams.get('grant_type')==='password'&&corps?.email?.trim().toLowerCase()!==conf.comptes[0].email.trim().toLowerCase())return {action:'bloquer',raison:'ADRESSE_AUTH_NON_AUTORISEE'};
  return {action:'verifier-auth'};
 }
 if(u.origin===backend&&u.pathname.startsWith('/auth/')){
  if(methode==='GET'&&u.pathname==='/auth/v1/user'&&authentifie)return {action:'verifier-auth'};
  return {action:'bloquer',raison:'AUTHENTIFICATION_NON_AUTORISEE'};
 }
 const rpc=u.origin===backend&&u.pathname.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/)?.[1];
 if(rpc){
  if(!authentifie)return {action:'bloquer',raison:'IDENTITE_NON_CONFIRMEE'};
  if(RPC_LECTURE.has(rpc)&&['GET','POST'].includes(methode))return {action:rpc==='mon_personnage'?'verifier-personnage':'autoriser'};
  // Aucun mouvement tant que ses effets serveur ne sont pas certifies.
  if(rpc==='rue_position_enregistrer')return {action:'bloquer',raison:'DEPLACEMENT_NON_AUDITE_INTERDIT'};
  return {action:'bloquer',raison:'RPC_NON_VERIFIEE_SANS_EFFET'};
 }
 if(u.origin===backend&&u.pathname.startsWith('/rest/v1/rpc/'))return {action:'bloquer',raison:'RPC_NON_VERIFIEE_SANS_EFFET'};
 if(u.origin===backend&&u.pathname.startsWith('/rest/')&&!authentifie)return {action:'bloquer',raison:'IDENTITE_NON_CONFIRMEE'};
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
   let valide=true;try{verifierUtilisateur(user,conf.comptes[0]);}catch{valide=false;}
   if(!valide){
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
module.exports={prevolAutomatique,verifierUtilisateur,verifierConsultation,decisionConsultation,installerConsultation,empreinteProtegee};
