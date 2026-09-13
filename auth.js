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

let RP_AUTH_SESSION = null;
let RP_AUTH_PROMESSE = null;      // deduplique les appels concurrents
let RP_AUTH_INDISPONIBLE = false; // vrai si le fournisseur refuse : on cesse d'insister

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
    // 422 anonymous_provider_disabled : le reglage n'est pas encore active cote
    // Supabase. Ce n'est pas une panne du jeu -- on repli sur la cle anon et on
    // n'insiste plus de la session.
    RP_AUTH_INDISPONIBLE = true;
    console.warn('[auth] compte anonyme indisponible (' + r.statut + ') :',
                 r.donnees && (r.donnees.msg || r.donnees.error_code));
    return null;
  }
  return rpAuthNormaliser(r.donnees);
}

/* --- Renouvellement ------------------------------------------------------ */
async function rpAuthRenouveler(refreshToken) {
  const res = await fetch(RP_AUTH_URL + '/token?grant_type=refresh_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'apikey': rpAuthCleAnon() },
    body: JSON.stringify({ refresh_token: refreshToken })
  });
  if (!res.ok) return null;
  return rpAuthNormaliser(await res.json().catch(() => null));
}

/* --- LE POINT D'ENTREE. Idempotent, deduplique, ne leve jamais. ---------- */
async function rpAuthAssurerSession() {
  if (rpAuthSessionValide(RP_AUTH_SESSION)) return RP_AUTH_SESSION;
  if (RP_AUTH_PROMESSE) return RP_AUTH_PROMESSE;

  RP_AUTH_PROMESSE = (async function () {
    try {
      if (!RP_AUTH_SESSION) RP_AUTH_SESSION = rpAuthLireStockage();
      if (rpAuthSessionValide(RP_AUTH_SESSION)) return RP_AUTH_SESSION;

      // Session connue mais perimee : on la renouvelle -- surtout ne pas ouvrir
      // un nouveau compte, ce serait abandonner le personnage du joueur.
      if (RP_AUTH_SESSION && RP_AUTH_SESSION.refresh_token) {
        const renouvelee = await rpAuthRenouveler(RP_AUTH_SESSION.refresh_token).catch(() => null);
        if (renouvelee) { RP_AUTH_SESSION = renouvelee; rpAuthEcrireStockage(renouvelee); return renouvelee; }
        // Renouvellement refuse : le compte n'existe plus (base reinitialisee,
        // jeton revoque). On repart a zero, ce qui est le comportement attendu.
        RP_AUTH_SESSION = null; rpAuthEcrireStockage(null);
      }

      if (RP_AUTH_INDISPONIBLE) return null;
      const nouvelle = await rpAuthOuvrirAnonyme().catch(() => null);
      if (nouvelle) { RP_AUTH_SESSION = nouvelle; rpAuthEcrireStockage(nouvelle); }
      return nouvelle;
    } finally {
      RP_AUTH_PROMESSE = null;
    }
  })();
  return RP_AUTH_PROMESSE;
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
  RP_AUTH_SESSION = null;
  rpAuthEcrireStockage(null);
  RP_AUTH_PROMESSE = null;
  return await rpAuthAssurerSession();
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
  // Le jeton courant reste valable ; on rafraichit l'etat local pour que l'IHM
  // cesse d'afficher l'avertissement "personnage non securise".
  if (RP_AUTH_SESSION && RP_AUTH_SESSION.user) {
    RP_AUTH_SESSION.user.email = email;
    RP_AUTH_SESSION.user.est_anonyme = false;
    rpAuthEcrireStockage(RP_AUTH_SESSION);
  }
  return { ok: true, email: email };
}

/** Reconnexion explicite d'un compte deja securise (autre appareil, session perdue). */
async function rpAuthSeConnecter(email, motDePasse) {
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
  RP_AUTH_SESSION = session; rpAuthEcrireStockage(session);
  return { ok: true, uid: session.user && session.user.id };
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
