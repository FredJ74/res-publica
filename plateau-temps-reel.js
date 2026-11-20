/* ===========================================================================
   HUMAN GAMBIT — PLATEAU-TEMPS-REEL.JS
   Présence permanente et synchronisation immédiate (décisions de Fred du 20/11/2026)
   ===========================================================================
   DEVOIR RECHARGER LA PAGE N'EST JAMAIS ACCEPTABLE. Quand le serveur déplace un personnage (neutralisation,
   hospitalisation, arrestation, garde à vue, libération, évasion, QHS, goulag, expulsion, MJ), son écran et celui des
   présents se recalent aussitôt.

   CE QUI ARRIVE PAR LE RÉSEAU NE CONTIENT AUCUN NOM. Le serveur tient deux tables de signaux (migration
   20261120280000) : salles_signaux (une version par pièce ou rue) et personnages_signaux (une version par personnage,
   lisible par lui seul). Un signal dit seulement « quelque chose a changé ici » ; l'écran RELIT alors le serveur
   (crim_presents pour la pièce, la fiche pour soi-même), qui applique la discrétion. Rien n'est adopté du message.

   DEUX CHEMINS, UNE MÊME RELECTURE. 1) Le temps réel de Supabase (WebSocket Phoenix, sans dépendance) ; 2) en
   secours, une relecture des deux versions toutes les 15 s (et au retour sur l'onglet) : si le WebSocket tombe, rien
   n'est perdu. Reprend l'idée de la PR #1148 (relecture légère de sa propre position), généralisée.

   UNE ACTION REFUSÉE POUR ÉTAT PÉRIMÉ déclenche la même resynchronisation (supabase.js → rpResynchroniserEtat).
   =========================================================================== */
(function (global) {
'use strict';
const etat = () => (typeof state !== 'undefined' && state) ? state : null;
const trad = (cle, secours) => {
  const t = (global.i18next && typeof global.i18next.t === 'function') ? global.i18next.t(cle, { defaultValue: secours }) : null;
  return (typeof t === 'string' && t && t !== cle) ? t : secours;
};

// Clé de salle : identique à salle_cle_interne côté serveur.
function cleSalle(pays, ville, batiment, piece, rue) {
  return (pays || '') + '|' + (ville || '') + '|' + (batiment ? batiment + '|' + (piece || '') : 'rue|' + (rue || ''));
}
function maSalle() {
  const s = etat();
  if (!s || !s.country) return null;
  const rue = (typeof rueCentraleNoeudActuel !== 'undefined') ? rueCentraleNoeudActuel : null;
  return cleSalle(s.country, s.currentCity, s.currentBuilding, s.currentRoom, rue);
}

// ---------------------------------------------------------------------------------------------------------------
// Relectures (le serveur seul fait foi)
// ---------------------------------------------------------------------------------------------------------------
let presentsMinuteur = null;
function rafraichirPresents() {
  clearTimeout(presentsMinuteur);
  presentsMinuteur = setTimeout(() => {
    if (typeof global.chargerVraisJoueursPresents === 'function') {
      try { global.chargerVraisJoueursPresents(); } catch (_) {}
    }
  }, 250);
}

// Message explicatif d'un changement subi : détention, libération, hôpital, sortie d'hôpital, déplacement.
function messageChangement(avant, apres) {
  const detenuAvant = !!avant.estEmprisonne, detenuApres = !!apres.estEmprisonne;
  const hopitalAvant = !!avant.hospitalisation, hopitalApres = !!apres.hospitalisation;
  if (!detenuAvant && detenuApres) return [trad('liveSync.arrestedTitle', 'Arrestation'), trad('liveSync.arrested', 'Vous avez été arrêté(e) et conduit(e) en détention.')];
  if (detenuAvant && !detenuApres) return [trad('liveSync.releasedTitle', 'Libération'), trad('liveSync.released', 'Vous êtes sorti(e) de détention.')];
  if (!hopitalAvant && hopitalApres) return [trad('liveSync.hospitalTitle', 'Hospitalisation'), trad('liveSync.hospital', 'Vous avez été conduit(e) à l’hôpital.')];
  if (hopitalAvant && !hopitalApres) return [trad('liveSync.dischargedTitle', 'Sortie de l’hôpital'), trad('liveSync.discharged', 'Vous avez quitté l’hôpital.')];
  if (avant.lieu !== apres.lieu) return [trad('liveSync.movedTitle', 'Déplacement'), trad('liveSync.moved', 'Votre personnage a été déplacé.')];
  return null;
}

let resyncEnCours = false, resyncDemandee = false;
// Relit SA fiche au serveur et recale l'écran si la position ou l'état ont changé. N'écrit rien.
async function rpResynchroniserEtat(motif) {
  const s = etat();
  if (!s || !s.char || !s.char.name || typeof global.sbLoadPersonnage !== 'function') return false;
  if (resyncEnCours) { resyncDemandee = true; return false; }
  resyncEnCours = true;
  try {
    const nom = s.char.name;
    const uid = typeof global.rpAuthUid === 'function' ? global.rpAuthUid() : null;
    const lieu = (x) => JSON.stringify([x.country, x.currentCity, x.currentBuilding || null, x.currentRoom || null]);
    const avant = { lieu: lieu(s), estEmprisonne: s.estEmprisonne, hospitalisation: s.hospitalisation };
    const frais = await global.sbLoadPersonnage(nom).catch(() => null);
    const s2 = etat();
    if (!frais || !s2 || !s2.char || s2.char.name !== nom || (uid && frais.userId && frais.userId !== uid)) return false;
    const apres = { lieu: lieu(frais), estEmprisonne: frais.estEmprisonne, hospitalisation: frais.hospitalisation };
    if (Object.prototype.hasOwnProperty.call(frais, 'hospitalisation')) s2.hospitalisation = frais.hospitalisation;
    if (Object.prototype.hasOwnProperty.call(frais, 'estEmprisonne')) s2.estEmprisonne = frais.estEmprisonne;
    if (Number.isFinite(frais.hp)) s2.hp = frais.hp;
    if (Number.isFinite(frais.pa)) s2.pa = frais.pa;
    const msg = messageChangement(avant, apres);
    if (avant.lieu !== apres.lieu && typeof global.afficherPositionNavigationConfirmee === 'function') {
      global.afficherPositionNavigationConfirmee(frais);
      abonnerSalle();
    }
    if (msg && typeof global.showToast === 'function') global.showToast(msg[0], msg[1], false, true);
    if (typeof global.updateUI === 'function') global.updateUI();
    rafraichirPresents();
    return true;
  } finally {
    resyncEnCours = false;
    if (resyncDemandee) { resyncDemandee = false; setTimeout(() => rpResynchroniserEtat('relance'), 300); }
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Temps réel Supabase (protocole Phoenix, vsn 1.0.0)
// ---------------------------------------------------------------------------------------------------------------
let ws = null, ref = 0, battement = null, salleAbonnee = null, personnageAbonne = null, reconnexion = null;
const SUJET_SALLE = 'realtime:hg-salle', SUJET_PERSO = 'realtime:hg-personnage', SUJET_CHAT = 'realtime:hg-chat';
let chatAbonne = null;
// « On vous parle » (20/11/2026) : chat_signaux, lisible par soi seul ; relit les messages non lus.
function abonnerChat() {
  const s = etat(), nom = s && s.char && s.char.name;
  if (!nom || nom === chatAbonne) return;
  if (chatAbonne) quitter(SUJET_CHAT);
  chatAbonne = nom;
  rejoindre(SUJET_CHAT, 'chat_signaux', 'personnage=eq.' + nom);
}
function signalChat() {
  if (typeof global.verifierNotificationChat === 'function') { try { global.verifierNotificationChat(); } catch (_) {} }
  if (typeof global.rafraichirConversationActuelle === 'function' && global.document && global.document.getElementById('chat-messages-zone')) {
    try { global.rafraichirConversationActuelle(false); } catch (_) {}
  }
}
const versions = { salle: null, perso: null };

function jeton() { return typeof global.rpAuthJeton === 'function' ? global.rpAuthJeton() : null; }
function envoyer(msg) { try { if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg)); } catch (_) {} }
function rejoindre(sujet, table, filtre) {
  const r = String(++ref);
  envoyer({ topic: sujet, event: 'phx_join', ref: r, join_ref: r, payload: {
    config: { broadcast: { self: false }, presence: { key: '' },
              postgres_changes: [{ event: '*', schema: 'public', table, filter: filtre }] },
    access_token: jeton() } });
}
function quitter(sujet) { envoyer({ topic: sujet, event: 'phx_leave', ref: String(++ref), payload: {} }); }

function abonnerSalle() {
  const cle = maSalle();
  if (!cle || cle === salleAbonnee) return;
  if (salleAbonnee) quitter(SUJET_SALLE);
  salleAbonnee = cle; versions.salle = null;
  rejoindre(SUJET_SALLE, 'salles_signaux', 'salle=eq.' + cle);
}
function abonnerPersonnage() {
  const s = etat(), nom = s && s.char && s.char.name;
  if (!nom || nom === personnageAbonne) return;
  if (personnageAbonne) quitter(SUJET_PERSO);
  personnageAbonne = nom; versions.perso = null;
  rejoindre(SUJET_PERSO, 'personnages_signaux', 'personnage=eq.' + nom);
}

// Un message ne transporte qu'une version : on relit le serveur, rien n'est adopté du message.
function traiterMessage(m) {
  if (!m || m.event !== 'postgres_changes') return;
  const rec = (m.payload && m.payload.data && (m.payload.data.record || m.payload.data.old_record)) || {};
  if (m.topic === SUJET_SALLE) { versions.salle = rec.version || versions.salle; rafraichirPresents(); }
  else if (m.topic === SUJET_PERSO) { versions.perso = rec.version || versions.perso; rpResynchroniserEtat('signal'); }
  else if (m.topic === SUJET_CHAT) signalChat();
}

function connecter() {
  if (!global.WebSocket || typeof SUPABASE_URL === 'undefined' || typeof SUPABASE_ANON === 'undefined' || !jeton()) return;
  if (ws && (ws.readyState === 0 || ws.readyState === 1)) return;
  const url = SUPABASE_URL.replace(/^http/, 'ws') + '/realtime/v1/websocket?apikey=' + encodeURIComponent(SUPABASE_ANON) + '&vsn=1.0.0';
  try { ws = new global.WebSocket(url); } catch (_) { ws = null; return; }
  ws.onopen = () => {
    salleAbonnee = null; personnageAbonne = null; chatAbonne = null;
    abonnerPersonnage(); abonnerSalle(); abonnerChat();
    clearInterval(battement);
    battement = setInterval(() => {
      envoyer({ topic: 'phoenix', event: 'heartbeat', payload: {}, ref: String(++ref) });
      const t = jeton();
      if (t) { envoyer({ topic: SUJET_SALLE, event: 'access_token', payload: { access_token: t }, ref: String(++ref) });
               envoyer({ topic: SUJET_PERSO, event: 'access_token', payload: { access_token: t }, ref: String(++ref) });
               envoyer({ topic: SUJET_CHAT, event: 'access_token', payload: { access_token: t }, ref: String(++ref) }); }
    }, 25000);
  };
  ws.onmessage = (e) => { let m = null; try { m = JSON.parse(e.data); } catch (_) {} traiterMessage(m); };
  ws.onclose = () => {
    clearInterval(battement); ws = null;
    clearTimeout(reconnexion); reconnexion = setTimeout(connecter, 5000);
  };
  ws.onerror = () => { try { ws && ws.close(); } catch (_) {} };
}

// ---------------------------------------------------------------------------------------------------------------
// Secours : relire les deux versions (15 s, et au retour sur l'onglet). Même relecture que le temps réel.
// ---------------------------------------------------------------------------------------------------------------
async function verifierVersions() {
  const s = etat();
  if (!s || !s.char || !s.char.name || typeof global.sbGet !== 'function') return;
  abonnerPersonnage(); abonnerSalle();
  try {
    const [p, sa] = await Promise.all([
      global.sbGet('personnages_signaux', 'personnage=eq.' + encodeURIComponent(s.char.name) + '&select=version'),
      salleAbonnee ? global.sbGet('salles_signaux', 'salle=eq.' + encodeURIComponent(salleAbonnee) + '&select=version') : null
    ]);
    const vp = p && p[0] ? p[0].version : null, vs = sa && sa[0] ? sa[0].version : null;
    if (vp != null && versions.perso != null && vp !== versions.perso) rpResynchroniserEtat('version');
    if (vs != null && versions.salle != null && vs !== versions.salle) rafraichirPresents();
    if (vp != null) versions.perso = vp;
    if (vs != null) versions.salle = vs;
  } catch (_) {}
}

function demarrer() {
  setTimeout(connecter, 4000);
  setInterval(() => { if (!global.document || !global.document.hidden) { connecter(); verifierVersions(); } }, 15000);
  if (global.document) global.document.addEventListener('visibilitychange', () => {
    if (!global.document.hidden) { connecter(); verifierVersions(); rpResynchroniserEtat('retour'); }
  });
}
if (global.document && global.setTimeout) {
  if (global.document.readyState !== 'loading') demarrer();
  else global.document.addEventListener('DOMContentLoaded', demarrer);
}

global.rpResynchroniserEtat = rpResynchroniserEtat;
global.RPTempsReel = { signalChat, cleSalle, maSalle, messageChangement, traiterMessage, abonnerSalle, verifierVersions, rpResynchroniserEtat, versions };
})(typeof window !== 'undefined' ? window : globalThis);
