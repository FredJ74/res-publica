/* ===========================================================================
   RES PUBLICA — AUTH.JS
   Identite du joueur (chantier B, 14 septembre 2026)
   ===========================================================================

   CE QUE CE MODULE REMPLACE. Jusqu'ici l'identite du joueur etait le NOM de son
   personnage, lu dans localStorage et cru sur parole : editer une cle de
   localStorage suffisait a devenir n'importe qui, et saisir a la creation le nom
   d'un joueur existant ECRASAIT sa fiche. Rien, nulle part, ne verifiait qu'un
   appelant etait bien celui qu'il declarait etre.

   OPTION C (arbitrage du 14 septembre 2026). A la premiere entree, le jeu ouvre
   silencieusement un compte Supabase ANONYME : aucun ecran, aucune adresse, aucun
   mot de passe -- l'experience d'entree ne change pas d'un iota. Ce compte porte
   un identifiant cryptographique (auth.users.id) auquel le personnage est
   rattache par la base elle-meme. Le joueur pourra plus tard, s'il le souhaite et
   quand il le souhaite, y attacher une adresse et un mot de passe SANS RIEN
   PERDRE : meme compte, meme personnage, meme patrimoine.

   CE MODULE NE BLOQUE JAMAIS RIEN. Si la connexion anonyme n'est pas encore
   activee cote Supabase, ou si le reseau tombe, tout retombe sur la cle anon
   publique et le jeu fonctionne exactement comme avant. C'est la condition pour
   qu'aucun joueur ne se retrouve devant une porte fermee pendant la bascule.

   PAS DE DEPENDANCE. Aucune bibliotheque : le dépôt n'a pas d'etape de build et
   n'en aura pas pour ca. Une centaine de lignes de fetch suffisent, dans le meme
   style que supabase.js.
   =========================================================================== */

const RP_AUTH_URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co/auth/v1';
const RP_AUTH_CLE_SESSION = 'respublica_auth_session';
// Marge avant expiration : on renouvelle un peu en avance plutot que de decouvrir
// un jeton perime au milieu d'une sauvegarde.
const RP_AUTH_MARGE_MS = 60 * 1000;

// Adresse du dernier compte AUTHENTIFIE connu de ce navigateur. Ni jeton ni mot de passe :
// juste de quoi savoir qu'il ne faut pas fabriquer d'anonyme a la place (voir rpAuthAssurerSession).
const RP_AUTH_CLE_IDENTITE = 'respublica_auth_identite';

let RP_AUTH_SESSION = null;
let RP_AUTH_PROMESSE = null;      // deduplique les appels concurrents
let RP_AUTH_INDISPONIBLE = false; // vrai si le fournisseur REFUSE STRUCTURELLEMENT l'anonyme (422)
let RP_AUTH_ETAT = null;          // 'ok' | 'reconnexion_requise' | 'reseau' | 'indisponible'

function rpAuthCleAnon() {
  return (typeof SUPABASE_ANON === 'string') ? SUPABASE_ANON : '';
}

function rpAuthLireStockage() {
  try {
    const brut = localStorage.getItem(RP_AUTH_CLE_SESSION);
    return brut ? JSON.parse(brut) : null;
  } catch (e) { return null; }
}

function rpAuthEcrireStockage(session) {
  try {
    if (session) localStorage.setItem(RP_AUTH_CLE_SESSION, JSON.stringify(session));
    else localStorage.removeItem(RP_AUTH_CLE_SESSION);
  } catch (e) { /* navigation privee, quota : on continue en memoire */ }
}

function rpAuthNormaliser(rep) {
  if (!rep || !rep.access_token) return null;
  return {
    access_token: rep.access_token,
    refresh_token: rep.refresh_token || null,
    // expires_at de Supabase est en SECONDES depuis l'epoque.
    expire_le: (rep.expires_at ? rep.expires_at * 1000 : Date.now() + (rep.expires_in || 3600) * 1000),
    user: rep.user ? { id: rep.user.id, email: rep.user.email || null,
                       est_anonyme: rep.user.is_anonymous === true } : null
  };
}

function rpAuthSessionValide(s) {
  return !!(s && s.access_token && s.expire_le && (s.expire_le - RP_AUTH_MARGE_MS) > Date.now());
}

async function rpAuthAppel(chemin, corps, jeton) {
  const entetes = { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon() };
  if (jeton) entetes['Authorization'] = 'Bearer ' + jeton;
  const res = await fetch(RP_AUTH_URL + chemin, {
    method: 'POST', headers: entetes, body: JSON.stringify(corps || {})
  });
  const texte = await res.text();
  let donnees = null;
  try { donnees = texte ? JSON.parse(texte) : null; } catch (e) { donnees = null; }
  return { ok: res.ok, statut: res.status, donnees };
}

/* --- Ouverture d'un compte anonyme ------------------------------------- */
async function rpAuthOuvrirAnonyme() {
  const r = await rpAuthAppel('/signup', {});
  if (!r.ok) {
    // VERROU RESERRE (24 septembre 2026). RP_AUTH_INDISPONIBLE etait pose sur N'IMPORTE quel
    // echec -- un 500 passager, un 429, une coupure -- et n'etait jamais relache de toute la vie
    // de la page. Une seconde de reseau capricieux condamnait donc la session entiere : le jeu
    // basculait sur la cle anon partagee, et toutes les fonctions liees a l'identite (presence,
    // paiements, sauvegarde) echouaient jusqu'au rechargement, sans que rien ne l'explique.
    // Seul le refus STRUCTUREL du fournisseur justifie de cesser d'insister : le provider anonyme
    // desactive cote Supabase (422). Tout le reste est passager et doit pouvoir etre retente.
    const code = (r.donnees && (r.donnees.error_code || r.donnees.msg)) || '';
    const structurel = (r.statut === 422) || String(code).indexOf('anonymous_provider_disabled') !== -1;
    if (structurel) RP_AUTH_INDISPONIBLE = true;
    console.warn('[auth] ouverture de compte anonyme refusee (' + r.statut + ') : ' + code
                 + (structurel ? ' — refus structurel, on cesse d\'insister' : ' — passager, retentable'));
    return null;
  }
  return rpAuthNormaliser(r.donnees);
}

/* --- Renouvellement ------------------------------------------------------
   REND DESORMAIS UN VERDICT, PAS UN SIMPLE null (24 septembre 2026).
   L'ancienne version renvoyait null aussi bien pour « ce jeton est mort » que pour « le wifi a
   saute ». L'appelant, incapable de distinguer les deux, effacait la session et OUVRAIT UN
   NOUVEAU COMPTE ANONYME dans les deux cas : une coupure passagere suffisait donc a faire perdre
   son personnage a un joueur. C'est le risque majeur de ce chantier.
     { ok:true, session }            -> renouvele
     { ok:false, definitif:true }    -> le serveur a REFUSE le jeton : il est mort
     { ok:false, definitif:false }   -> reseau ou panne serveur : on ne conclut RIEN            */
async function rpAuthRenouveler(refreshToken) {
  let res;
  try {
    res = await fetch(RP_AUTH_URL + '/token?grant_type=refresh_token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon() },
      body: JSON.stringify({ refresh_token: refreshToken })
    });
  } catch (e) {
    return { ok: false, definitif: false, raison: 'reseau' };
  }
  if (!res.ok) {
    // 400/401 = le jeton est refuse (revoque, deja consomme, compte supprime) : definitif.
    // 429 = on nous demande d'attendre. 5xx = panne serveur. Ni l'un ni l'autre ne prouve quoi
    // que ce soit sur la validite du jeton.
    const definitif = (res.status === 400 || res.status === 401 || res.status === 403);
    return { ok: false, definitif: definitif, raison: 'http_' + res.status };
  }
  const session = rpAuthNormaliser(await res.json().catch(() => null));
  if (!session) return { ok: false, definitif: false, raison: 'reponse_illisible' };
  return { ok: true, session: session };
}

/* --- LE POINT D'ENTREE. Idempotent, deduplique, ne leve jamais. ---------- */
async function rpAuthAssurerSession() {
  if (rpAuthSessionValide(RP_AUTH_SESSION)) return RP_AUTH_SESSION;
  if (RP_AUTH_PROMESSE) return RP_AUTH_PROMESSE;

  RP_AUTH_PROMESSE = (async function () {
    try {
      if (!RP_AUTH_SESSION) RP_AUTH_SESSION = rpAuthLireStockage();
      if (rpAuthSessionValide(RP_AUTH_SESSION)) { RP_AUTH_ETAT = 'ok'; return RP_AUTH_SESSION; }

      // Session connue mais perimee : on la renouvelle -- surtout ne pas ouvrir
      // un nouveau compte, ce serait abandonner le personnage du joueur.
      if (RP_AUTH_SESSION && RP_AUTH_SESSION.refresh_token) {
        const r = await rpAuthRenouveler(RP_AUTH_SESSION.refresh_token)
                          .catch(() => ({ ok: false, definitif: false, raison: 'exception' }));
        if (r.ok) {
          RP_AUTH_SESSION = r.session; rpAuthEcrireStockage(r.session);
          rpAuthMemoriserIdentite(r.session);
          RP_AUTH_ETAT = 'ok';
          return r.session;
        }
        // ECHEC PASSAGER : ON NE CONCLUT RIEN, ET SURTOUT ON N'EFFACE RIEN. Le refresh token
        // reste en place et la prochaine tentative reussira. Ouvrir un compte anonyme ici, ou
        // jeter la session, reviendrait a perdre le personnage du joueur sur une coupure.
        if (!r.definitif) {
          RP_AUTH_ETAT = 'reseau';
          console.warn('[auth] renouvellement impossible pour le moment (' + r.raison
                       + ') — session conservee, aucune identite creee.');
          return null;
        }
        // ECHEC DEFINITIF : le serveur a refuse le jeton.
        RP_AUTH_SESSION = null; rpAuthEcrireStockage(null);
      }

      // LE COEUR DU DURCISSEMENT. Un joueur qui a DEJA pose une adresse et un mot de passe ne
      // doit JAMAIS etre transforme en nouvel anonyme : son personnage appartient a un compte
      // qui existe toujours, et lui fabriquer une identite neuve le lui ferait croire disparu.
      // On demande une reconnexion explicite, ce qui est reparable ; un compte anonyme
      // accidentel, lui, ne l'est pas.
      const identite = rpAuthIdentiteMemorisee();
      if (identite && identite.email) {
        RP_AUTH_ETAT = 'reconnexion_requise';
        console.warn('[auth] session perdue pour ' + identite.email
                     + ' — reconnexion demandee, aucun compte anonyme cree.');
        return null;
      }

      if (RP_AUTH_INDISPONIBLE) { RP_AUTH_ETAT = 'indisponible'; return null; }
      const nouvelle = await rpAuthOuvrirAnonyme().catch(() => null);
      if (nouvelle) {
        RP_AUTH_SESSION = nouvelle; rpAuthEcrireStockage(nouvelle);
        RP_AUTH_ETAT = 'ok';
      } else {
        RP_AUTH_ETAT = RP_AUTH_INDISPONIBLE ? 'indisponible' : 'reseau';
      }
      return nouvelle;
    } finally {
      RP_AUTH_PROMESSE = null;
    }
  })();
  return RP_AUTH_PROMESSE;
}

/* --- MEMOIRE D'IDENTITE (24 septembre 2026) ------------------------------
   Une trace MINUSCULE et non secrete -- une adresse, rien d'autre, aucun jeton, aucun mot de
   passe. Elle sert a une seule chose, mais essentielle : savoir qu'un compte porte des
   identifiants, donc qu'il ne faut JAMAIS lui substituer une identite anonyme, et pouvoir
   proposer « reconnectez-vous » en nommant l'adresse plutot qu'un formulaire nu.
   Elle survit volontairement a l'effacement de la session : c'est precisement quand la session
   est perdue qu'elle sert.                                                                    */
function rpAuthMemoriserIdentite(session) {
  const u = session && session.user;
  const email = u && (u.email || null);
  if (!email) return;
  try {
    localStorage.setItem(RP_AUTH_CLE_IDENTITE, JSON.stringify({ email: email, uid: u.id || null }));
  } catch (e) {}
}

function rpAuthIdentiteMemorisee() {
  try {
    const brut = localStorage.getItem(RP_AUTH_CLE_IDENTITE);
    return brut ? JSON.parse(brut) : null;
  } catch (e) { return null; }
}

function rpAuthOublierIdentite() {
  try { localStorage.removeItem(RP_AUTH_CLE_IDENTITE); } catch (e) {}
}

/** Etat courant de l'authentification, pour que l'interface puisse en parler au joueur.
 *  'ok' | 'reconnexion_requise' | 'reseau' | 'indisponible' | null (pas encore sollicitee) */
function rpAuthEtat() { return RP_AUTH_ETAT; }

/* --- A QUEL COMPTE APPARTIENT LE CACHE PERSONNAGE ? (24 septembre 2026) ---
   Le cache local du personnage (respublica_char*, dans plateau-core.js) est indexe par NOM et
   par rien d'autre : aucune de ses cles ne dit a QUI le personnage appartient. Tant qu'un
   navigateur ne sert qu'un compte cela ne se voit pas ; des que le compte change sous le cache
   -- rpAuthRepartirDeZero() le fait, par exemple, quand le serveur prouve que le compte n'existe
   plus -- l'interface continue de presenter l'identite du compte precedent.
   Ces deux accesseurs vivent ICI et non dans plateau-core.js pour une raison mecanique :
   l'ecran de connexion (index.html) ne charge pas plateau-core.js, et c'est precisement lui qui
   reecrit le cache apres une connexion. auth.js, lui, est charge par les deux pages.
   La cle est separee a dessein : jamais dans state.char, que sbSavePersonnage renvoie au
   serveur et qui n'a aucune raison de porter un identifiant de compte.                        */
const RP_CLE_CHAR_UID = 'respublica_char_uid';

/** Estampille le cache personnage au nom du compte connecte. A appeler a CHAQUE ecriture. */
function rpMarquerProprietaireCache() {
  try {
    const uid = rpAuthUid();
    if (uid) localStorage.setItem(RP_CLE_CHAR_UID, uid);
  } catch (e) {}
}

/** Le compte auquel appartient le cache local, ou null si on ne sait pas (cache ecrit par une
    version anterieure a ce lot). Ne JAMAIS conclure d'un null : on ne rejette que sur preuve. */
function rpProprietaireCache() {
  try { return localStorage.getItem(RP_CLE_CHAR_UID) || null; } catch (e) { return null; }
}

/* --- Repartir de zero (14 septembre 2026) --------------------------------
   Un jeton peut rester valide DANS LE TEMPS alors que son compte n'existe plus : c'est le cas
   apres une purge de comptes anonymes cote base. rpAuthAssurerSession ne le voit pas -- elle ne
   renouvelle que sur expiration. Le serveur, lui, le prouve : toute ecriture referencant ce uid
   echoue en violation de cle etrangere sur personnages_user_id_fkey.
   Cette fonction abandonne la session locale et en ouvre une neuve. A n'appeler QUE sur cette
   preuve : jamais sur un simple echec reseau, sinon on abandonnerait le compte d'un joueur --
   et donc son personnage -- pour une coupure passagere. */
async function rpAuthRepartirDeZero() {
  const ancienUid = rpAuthUid();
  RP_AUTH_SESSION = null;
  rpAuthEcrireStockage(null);
  RP_AUTH_PROMESSE = null;
  const session = await rpAuthAssurerSession();
  // C'EST LE CHEMIN QUI FAISAIT REELLEMENT DIVERGER L'ECRAN ET LE COMPTE. Cette fonction ouvre
  // une session NEUVE -- donc un uid neuf -- pendant que le cache personnage, lui, ne bouge pas.
  // L'interface continuait ensuite d'afficher un personnage que le nouveau compte ne possede
  // pas. On previent desormais le plateau, qui rechargera le personnage du compte courant.
  const nouvelUid = (session && session.user) ? session.user.id : null;
  if (nouvelUid && ancienUid && nouvelUid !== ancienUid
      && typeof rpIdentiteChangementDeCompte === 'function') {
    await rpIdentiteChangementDeCompte(ancienUid, nouvelUid).catch(() => {});
  }
  return session;
}

/* --- Lecture synchrone, utilisee par supabase.js a chaque requete -------- */
function rpAuthJeton() {
  if (!RP_AUTH_SESSION) RP_AUTH_SESSION = rpAuthLireStockage();
  return rpAuthSessionValide(RP_AUTH_SESSION) ? RP_AUTH_SESSION.access_token : null;
}

function rpAuthUid() {
  if (!RP_AUTH_SESSION) RP_AUTH_SESSION = rpAuthLireStockage();
  return (RP_AUTH_SESSION && RP_AUTH_SESSION.user) ? RP_AUTH_SESSION.user.id : null;
}

function rpAuthEstAuthentifie() { return !!rpAuthJeton(); }

/** Le compte est-il encore anonyme (donc lie au seul navigateur) ? */
function rpAuthEstAnonyme() {
  if (!RP_AUTH_SESSION) RP_AUTH_SESSION = rpAuthLireStockage();
  return !!(RP_AUTH_SESSION && RP_AUTH_SESSION.user && RP_AUTH_SESSION.user.est_anonyme);
}

function rpAuthEmail() {
  if (!RP_AUTH_SESSION) RP_AUTH_SESSION = rpAuthLireStockage();
  return (RP_AUTH_SESSION && RP_AUTH_SESSION.user) ? RP_AUTH_SESSION.user.email : null;
}

/* --- SECURISATION FACULTATIVE DU COMPTE ---------------------------------
   Convertit le compte anonyme en compte permanent. C'est le MEME compte :
   auth.users.id ne change pas, donc personnages.user_id reste valide et le
   joueur ne perd ni personnage, ni progression, ni inventaire, ni patrimoine.
   C'est exactement ce que la Beta 2.0 rendra obligatoire ; le modele de
   securite, lui, ne bougera pas d'une ligne.                              */
async function rpAuthSecuriserCompte(email, motDePasse) {
  const session = await rpAuthAssurerSession();
  if (!session) return { ok: false, raison: 'aucune_session' };
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { ok: false, raison: 'email_invalide' };
  if (!motDePasse || motDePasse.length < 8) return { ok: false, raison: 'mot_de_passe_trop_court' };

  const res = await fetch(RP_AUTH_URL + '/user', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon(),
               'Authorization': 'Bearer ' + session.access_token },
    body: JSON.stringify({ email: email, password: motDePasse })
  });
  const texte = await res.text();
  let donnees = null; try { donnees = texte ? JSON.parse(texte) : null; } catch (e) {}
  if (!res.ok) {
    return { ok: false, raison: (donnees && (donnees.error_code || donnees.msg)) || ('http_' + res.status) };
  }
  // DURCISSEMENT DU 21 septembre 2026 (lot « Securiser mon personnage »).
  //
  // 1. L'ETAT VENAIT D'UNE SUPPOSITION. On posait est_anonyme = false sans jamais regarder la
  //    reponse : si le serveur n'avait pas reellement converti le compte (confirmation en
  //    attente selon la configuration), l'interface aurait affiche « securise » a tort. On lit
  //    desormais ce que le serveur repond.
  //    MISE A JOUR DU 22 septembre 2026 (lot 3b) : mailer_autoconfirm vaut desormais FALSE. La
  //    conversion n'est donc PLUS immediate -- le serveur repond is_anonymous:true et new_email
  //    renseigne. C'est l'etat normal, pas un echec : l'appelant doit annoncer « en attente de
  //    confirmation », jamais « personnage securise ». On rend enAttente pour qu'il le puisse.
  //
  // 2. L'IDENTIFIANT EST VERIFIE, PAS SUPPOSE. PUT /user agit sur l'utilisateur porte par le
  //    jeton : il ne peut pas changer d'identifiant, c'est structurel. Mais cette garantie est
  //    ce qui protege le personnage -- si elle tombait un jour, tout le rattachement tomberait
  //    avec elle, en silence. On la rend donc OBSERVABLE : un identifiant qui aurait bouge fait
  //    echouer l'operation au lieu de passer inapercu.
  const compte = (donnees && (donnees.id ? donnees : donnees.user)) || null;
  const uidAvant = (RP_AUTH_SESSION && RP_AUTH_SESSION.user) ? RP_AUTH_SESSION.user.id : null;
  if (compte && compte.id && uidAvant && compte.id !== uidAvant) {
    return { ok: false, raison: 'identifiant_de_compte_modifie' };
  }
  // Le jeton courant reste valable (meme `sub`) ; on rafraichit l'etat local pour que l'IHM
  // cesse d'afficher l'avertissement "personnage non securise".
  if (RP_AUTH_SESSION && RP_AUTH_SESSION.user) {
    RP_AUTH_SESSION.user.email = (compte && compte.email) || null;
    RP_AUTH_SESSION.user.est_anonyme = compte ? (compte.is_anonymous === true) : false;
    rpAuthEcrireStockage(RP_AUTH_SESSION);
  }
  // ON MEMORISE L'ADRESSE MEME NON CONFIRMEE. C'est le cas le plus exposé : le compte porte
  // deja un mot de passe mais reste `is_anonymous` tant que le lien n'est pas clique. Sans cette
  // trace, une perte de session entre la saisie et la confirmation relancerait la fabrique
  // d'anonymes -- et le joueur se retrouverait devant un jeu vierge avec un personnage bien
  // vivant dans la base, sous un compte qu'il ne porte plus.
  try {
    localStorage.setItem(RP_AUTH_CLE_IDENTITE, JSON.stringify({
      email: (compte && (compte.email || compte.new_email)) || email,
      uid: (compte && compte.id) || uidAvant || null
    }));
  } catch (e) {}
  return { ok: true, email: (compte && compte.email) || null,
           enAttente: (compte && compte.new_email) || email,
           encore_anonyme: compte ? (compte.is_anonymous === true) : null };
}

/* --- ETAT REEL DU COMPTE, LU AU SERVEUR (Lot 3b, 21 septembre 2026) ------
   L'interface ne doit JAMAIS deduire « compte securise » du fait qu'un formulaire a ete envoye :
   entre la saisie et la confirmation, le compte reste anonyme et l'adresse n'est qu'EN ATTENTE.
   Seul le serveur sait ou l'on en est, et c'est lui qu'on interroge.

   Comportement REEL de notre instance, mesure et non suppose (banc du 21 septembre) :
     - avant confirmation : email vide, new_email renseigne, is_anonymous true, mot de passe DEJA
       pose, connexion par mot de passe refusee ;
     - apres confirmation : email renseigne, new_email vide, is_anonymous false, identite 'email'
       creee, connexion possible -- et auth.users.id inchange de bout en bout.
   La documentation officielle affirme le contraire sur le mot de passe : elle a tort ici. */
async function rpAuthEtatCompte() {
  const jeton = rpAuthJeton();
  if (!jeton) return { ok: false, raison: 'aucune_session' };
  let res;
  try {
    res = await fetch(RP_AUTH_URL + '/user', {
      headers: { 'apikey': rpAuthCleAnon(), 'Authorization': 'Bearer ' + jeton }
    });
  } catch (e) { return { ok: false, raison: 'reseau' }; }
  if (!res.ok) return { ok: false, raison: 'http_' + res.status };
  const u = await res.json().catch(() => null);
  if (!u || !u.id) return { ok: false, raison: 'reponse_illisible' };

  // On rafraichit l'etat local au passage : rpAuthEstAnonyme/rpAuthEmail cessent ainsi de
  // repondre d'apres un souvenir, y compris apres une confirmation faite sur un autre appareil.
  if (RP_AUTH_SESSION && RP_AUTH_SESSION.user) {
    RP_AUTH_SESSION.user.est_anonyme = (u.is_anonymous === true);
    RP_AUTH_SESSION.user.email = u.email || null;
    rpAuthEcrireStockage(RP_AUTH_SESSION);
  }
  return {
    ok: true,
    anonyme:   u.is_anonymous === true,
    email:     u.email || null,        // adresse EFFECTIVE, donc confirmee
    enAttente: u.new_email || null,    // adresse saisie, pas encore prouvee
    confirmee: !!u.email_confirmed_at
  };
}

/* --- (RE)DEMANDER LA CONFIRMATION D'UNE ADRESSE -------------------------
   Sert aux DEUX besoins du lot : renvoyer le courriel (meme adresse) et corriger une adresse
   mal saisie (adresse differente). C'est le meme appel -- verifie au banc : une nouvelle adresse
   remplace celle en attente ET revoque le jeton precedent, si bien qu'il n'existe jamais qu'un
   seul lien valide. Une adresse erronee ne peut donc pas prendre le compte plus tard.
   Secure email change est desactive : aucun lien n'est envoye a l'ancienne adresse -- ce qui est
   indispensable, le joueur ne controlant precisement pas l'adresse qu'il vient de mal saisir. */
async function rpAuthDemanderConfirmationAdresse(email) {
  const jeton = rpAuthJeton();
  if (!jeton) return { ok: false, raison: 'aucune_session' };
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { ok: false, raison: 'email_invalide' };
  let res;
  try {
    res = await fetch(RP_AUTH_URL + '/user', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon(),
                 'Authorization': 'Bearer ' + jeton },
      body: JSON.stringify({ email: email })
    });
  } catch (e) { return { ok: false, raison: 'reseau' }; }
  const texte = await res.text();
  let d = null; try { d = texte ? JSON.parse(texte) : null; } catch (e) {}
  if (!res.ok) {
    // 429 over_email_send_rate_limit : fenetre mesuree a ~86 s sur notre instance. On ne la
    // contourne pas, on l'annonce.
    return { ok: false, raison: (d && (d.error_code || d.msg)) || ('http_' + res.status) };
  }
  const u = (d && (d.id ? d : d.user)) || null;
  return { ok: true, enAttente: (u && u.new_email) || email };
}

/** Reconnexion explicite d'un compte deja securise (autre appareil, session perdue).
 *
 *  CE QU'ELLE NE FAIT PAS, et c'est l'essentiel : elle ne nomme aucun personnage. On ne
 *  RECLAME pas une fiche, on s'authentifie sur un COMPTE -- et le serveur dira ensuite, seul,
 *  quel personnage ce compte possede. Aucun nom saisi par le joueur n'entre dans cette chaine,
 *  donc aucune prise de controle par la connaissance d'un nom (qui est public) n'est possible.
 *
 *  Elle n'envoie pas non plus le jeton anonyme courant : c'est une authentification neuve, pas
 *  une modification de l'utilisateur en place. La session obtenue REMPLACE entierement la
 *  precedente, en memoire et dans le stockage.
 */
async function rpAuthSeConnecter(email, motDePasse) {
  // Qui etions-nous AVANT de tenter ? Lu maintenant, parce que la reponse va ecraser la session.
  // Rien n'est purge a ce stade : un echec ne doit rien detruire (voir plus bas).
  const ancienUid = rpAuthUid();
  const res = await fetch(RP_AUTH_URL + '/token?grant_type=password', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon() },
    body: JSON.stringify({ email: email, password: motDePasse })
  });
  if (!res.ok) {
    const t = await res.text(); let d = null; try { d = JSON.parse(t); } catch (e) {}
    return { ok: false, raison: (d && (d.error_code || d.msg)) || ('http_' + res.status) };
  }
  const session = rpAuthNormaliser(await res.json().catch(() => null));
  if (!session) return { ok: false, raison: 'reponse_illisible' };
  // DURCISSEMENT DU 21 septembre 2026. Une promesse d'ouverture de session pouvait etre EN VOL
  // au moment de la connexion (rpAuthAssurerSession est dedupliquee et survit a l'appel qui l'a
  // lancee). En se resolvant apres nous, elle reassignait RP_AUTH_SESSION avec le compte ANONYME
  // -- et le joueur repartait sous l'identite qu'il venait precisement de quitter. On l'abandonne
  // explicitement : la session nominative fait desormais autorite.
  RP_AUTH_PROMESSE = null;
  RP_AUTH_INDISPONIBLE = false;
  RP_AUTH_SESSION = session; rpAuthEcrireStockage(session);
  // On retient l'adresse : ce navigateur sait desormais qu'il porte un compte a identifiants,
  // et ne se laissera plus remplacer par un anonyme si la session vient a se perdre.
  if (session.user && !session.user.email) session.user.email = email;
  rpAuthMemoriserIdentite(session);
  RP_AUTH_ETAT = 'ok';

  // LE COMPTE A CHANGE : ON OUBLIE LE PERSONNAGE DU PRECEDENT (24 septembre 2026).
  // La purge est accrochee ICI, au succes AVERE de l'authentification -- jamais au clic sur
  // « Se connecter ». Un mot de passe refuse laisse donc intacts la session et le personnage
  // du joueur deja connecte : on sort bien avant ce point, par le `if (!res.ok)` du dessus.
  // Et securiser un ancien compte anonyme conserve le meme auth.uid() : la comparaison est
  // alors egale, rien n'est purge, le personnage reste.
  const nouvelUid = session.user && session.user.id;
  if (nouvelUid && ancienUid && nouvelUid !== ancienUid
      && typeof rpIdentiteChangementDeCompte === 'function') {
    await rpIdentiteChangementDeCompte(ancienUid, nouvelUid).catch(() => {});
  }
  return { ok: true, uid: nouvelUid };
}

/** Rattache au compte connecte un personnage cree AVANT l'authentification.
    Fenetre transitoire, fermee a la reinitialisation de la beta. */
async function rpAuthRattacherPersonnage(nom) {
  const session = await rpAuthAssurerSession();
  if (!session || !nom) return { ok: false, raison: 'aucune_session' };
  const res = await fetch('https://jxpwoosmmhohoihxpbuc.supabase.co/rest/v1/rpc/rattacher_personnage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon(),
               'Authorization': 'Bearer ' + session.access_token },
    body: JSON.stringify({ p_nom: nom })
  });
  if (!res.ok) return { ok: false, raison: 'http_' + res.status };
  const d = await res.json().catch(() => null);
  return d || { ok: false, raison: 'reponse_illisible' };
}
