/* ===========================================================================
   HUMAN GAMBIT — ADMIN-AUTH.JS
   Session administrateur, distincte de celle du joueur (12 octobre 2026)
   ===========================================================================

   POURQUOI UN MODULE SEPARE, ET PAS UN MODE DE auth.js. L'administration doit
   pouvoir rester ouverte EN MEME TEMPS que le compte joueur, dans le meme
   navigateur, sans qu'aucune des deux sessions ne chasse l'autre. Deux
   conditions, et aucune n'est negociable :
     . une CLE DE STOCKAGE differente -- `respublica_admin_session` ici,
       `respublica_auth_session` pour le joueur : rien n'est partage ;
     . aucune lecture croisee -- ce fichier n'appelle jamais `rpAuthJeton()`, et
       `sbEnTetes()` (supabase.js) ne connait pas le jeton administrateur. La
       page d'administration ne charge d'ailleurs ni auth.js ni supabase.js.
   Il n'y a donc AUCUNE bascule de role depuis un personnage : ce sont deux
   comptes Supabase Auth distincts, avec deux jetons distincts.

   CE QUE CE STOCKAGE N'EST PAS. Il ne fait PAS autorite. Il ne transporte qu'un
   jeton signe par Supabase ; c'est la base, et elle seule, qui dit si le compte
   porte une autorite administrateur (`administrateurs`, lue par
   `est_administrateur()` a chaque action sensible). Editer `localStorage`,
   inventer une variable, ou connaitre l'adresse de cette page ne donne donc
   aucun pouvoir : toutes les portes sensibles LEVENT en 42501 pour un compte
   qui n'est pas inscrit.

   PAS DE DEPENDANCE, pas d'etape de build : quelques dizaines de lignes de
   fetch, dans le meme style que auth.js et supabase.js.
   =========================================================================== */

const RP_ADMIN_BASE    = 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const RP_ADMIN_AUTH    = RP_ADMIN_BASE + '/auth/v1';
const RP_ADMIN_REST    = RP_ADMIN_BASE + '/rest/v1';
// Cle publique `anon` : la meme que celle de supabase.js, deja dans le depot. Elle n'ouvre rien
// par elle-meme -- elle ne fait que designer le projet.
const RP_ADMIN_ANON    = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
const RP_ADMIN_CLE     = 'respublica_admin_session';
const RP_ADMIN_MARGE   = 60 * 1000;

let RP_ADMIN_SESSION = null;

function rpAdminLire() {
  try { const b = localStorage.getItem(RP_ADMIN_CLE); return b ? JSON.parse(b) : null; }
  catch (e) { return null; }
}
function rpAdminEcrire(s) {
  try {
    if (s) localStorage.setItem(RP_ADMIN_CLE, JSON.stringify(s));
    else localStorage.removeItem(RP_ADMIN_CLE);
  } catch (e) { /* navigation privee : on continue en memoire */ }
}
function rpAdminNormaliser(rep) {
  if (!rep || !rep.access_token) return null;
  return {
    access_token: rep.access_token,
    refresh_token: rep.refresh_token || null,
    expire_le: rep.expires_at ? rep.expires_at * 1000 : Date.now() + (rep.expires_in || 3600) * 1000,
    email: (rep.user && rep.user.email) || null,
    uid: (rep.user && rep.user.id) || null
  };
}
function rpAdminValide(s) {
  return !!(s && s.access_token && s.expire_le && (s.expire_le - RP_ADMIN_MARGE) > Date.now());
}

/** Jeton courant, ou null. Lecture synchrone, comme rpAuthJeton cote joueur. */
function rpAdminJeton() {
  if (!RP_ADMIN_SESSION) RP_ADMIN_SESSION = rpAdminLire();
  return rpAdminValide(RP_ADMIN_SESSION) ? RP_ADMIN_SESSION.access_token : null;
}
function rpAdminEmail() {
  if (!RP_ADMIN_SESSION) RP_ADMIN_SESSION = rpAdminLire();
  return RP_ADMIN_SESSION ? RP_ADMIN_SESSION.email : null;
}

/** Renouvellement. Ne conclut RIEN d'une coupure reseau : seul un refus du serveur est definitif. */
async function rpAdminRenouveler() {
  if (!RP_ADMIN_SESSION) RP_ADMIN_SESSION = rpAdminLire();
  if (!RP_ADMIN_SESSION || !RP_ADMIN_SESSION.refresh_token) return false;
  let res;
  try {
    res = await fetch(RP_ADMIN_AUTH + '/token?grant_type=refresh_token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': RP_ADMIN_ANON },
      body: JSON.stringify({ refresh_token: RP_ADMIN_SESSION.refresh_token })
    });
  } catch (e) { return false; }
  if (!res.ok) {
    if (res.status === 400 || res.status === 401 || res.status === 403) {
      RP_ADMIN_SESSION = null; rpAdminEcrire(null);
    }
    return false;
  }
  const s = rpAdminNormaliser(await res.json().catch(() => null));
  if (!s) return false;
  RP_ADMIN_SESSION = s; rpAdminEcrire(s);
  return true;
}

/** Connexion explicite. Aucun compte n'est jamais cree ici : l'administration ne s'auto-inscrit pas. */
async function rpAdminSeConnecter(email, motDePasse) {
  let res;
  try {
    res = await fetch(RP_ADMIN_AUTH + '/token?grant_type=password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': RP_ADMIN_ANON },
      body: JSON.stringify({ email: email, password: motDePasse })
    });
  } catch (e) { return { ok: false, raison: 'reseau' }; }
  if (!res.ok) {
    const t = await res.text(); let d = null; try { d = JSON.parse(t); } catch (e) {}
    return { ok: false, raison: (d && (d.error_code || d.msg || d.error_description)) || ('http_' + res.status) };
  }
  const s = rpAdminNormaliser(await res.json().catch(() => null));
  if (!s) return { ok: false, raison: 'reponse_illisible' };
  RP_ADMIN_SESSION = s; rpAdminEcrire(s);
  return { ok: true, email: s.email };
}

function rpAdminSeDeconnecter() {
  RP_ADMIN_SESSION = null; rpAdminEcrire(null);
}

/* --- APPEL DE PORTE -------------------------------------------------------
   Toujours avec le jeton ADMINISTRATEUR, jamais avec la cle anon : une porte
   d'administration appelee sans identite doit echouer, pas retomber sur un
   acces partage. Et un 401 declenche UN renouvellement, puis un seul reessai. */
async function rpAdminRpc(fn, params, _reessai) {
  const jeton = rpAdminJeton();
  if (!jeton) {
    const renouvele = await rpAdminRenouveler();
    if (!renouvele) return { ok: false, raison: 'session_absente' };
    return rpAdminRpc(fn, params, true);
  }
  let res;
  try {
    res = await fetch(RP_ADMIN_REST + '/rpc/' + fn, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': RP_ADMIN_ANON,
                 'Authorization': 'Bearer ' + jeton },
      body: JSON.stringify(params || {})
    });
  } catch (e) { return { ok: false, raison: 'reseau' }; }
  if (res.status === 401 && !_reessai) {
    if (await rpAdminRenouveler()) return rpAdminRpc(fn, params, true);
  }
  const texte = await res.text();
  let d = null; try { d = texte ? JSON.parse(texte) : null; } catch (e) {}
  if (!res.ok) {
    // 42501 : le serveur a refuse l'autorite. C'est la bonne reponse pour un compte non inscrit.
    const code = (d && (d.code || d.message)) || ('http_' + res.status);
    return { ok: false, raison: String(code), refus_serveur: true };
  }
  if (Array.isArray(d)) return d[0] || { ok: false, raison: 'reponse_vide' };
  return d || { ok: false, raison: 'reponse_vide' };
}
