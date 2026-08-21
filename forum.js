/* ===========================
   RES PUBLICA — FORUM.JS v3
   Éditeur riche, mails, emojis
   =========================== */

const FORUMS_BASE = {
  local:         { name: 'Forum Local',          icon: 'ti-home',          desc: 'Discussions de votre ville', private: false, cat: 'intra' },
  national:      { name: 'Forum National',        icon: 'ti-flag',          desc: 'Débats politiques nationaux', private: false, cat: 'intra' },
  presidence:    { name: 'La Présidence à la Nation', icon: 'ti-flag-3',    desc: 'Discours et annonces officielles depuis la Présidence', private: false, cat: 'intra', sousGroupe: 'institutions' },
  gouvernement:  { name: 'Le Gouvernement à la Nation', icon: 'ti-building-bank', desc: 'Réservé au gouvernement', private: true, requiredPost: ['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'], cat: 'intra', sousGroupe: 'institutions' },
  presse:        { name: 'Presse & Médias',        icon: 'ti-news',          desc: 'Réservé aux journalistes', private: true, cat: 'intra' },
  international: { name: 'Forum International',   icon: 'ti-world',         desc: 'Relations entre empires', private: false, cat: 'inter' },
  sport:         { name: 'Championnat Sportif',    icon: 'ti-ball-football', desc: 'Résultats, classements et débats de supporters', private: false, cat: 'inter' }
};

// Getter dynamique — ajoute le forum Tribunal de la ville courante
function getForums() {
  const villeId = (typeof state !== 'undefined' && state.currentCity) || 'capitale';
  const tribunalKey = 'tribunal_' + villeId;
  const villeNom = (typeof WORLD !== 'undefined' && typeof state !== 'undefined')
    ? (WORLD[state.country]?.[villeId]?.name || villeId)
    : villeId;

  const orgForums = {};
  ((typeof state !== 'undefined' && state.organisations) || []).forEach(o => {
    if (!o?.id) return;
    orgForums['org_' + o.id] = {
      name: o.nom || 'Organisation',
      icon: 'ti-users-group',
      desc: 'Forum privé réservé aux membres de ' + (o.nom || 'cette organisation') + '.',
      private: true,
      requiredOrgId: o.id,
      cat: 'prive'
    };
  });

  return {
    ...FORUMS_BASE,
    [tribunalKey]: { name: '⚖️ Tribunal — ' + villeNom, icon: 'ti-gavel', desc: 'Plaintes et affaires judiciaires de ' + villeNom, private: false, cat: 'intra', sousGroupe: 'institutions' },
    ...orgForums
  };
}

// Alias retro-compatible : FORUMS devient un Proxy qui appelle getForums() dynamiquement
const FORUMS = new Proxy({}, {
  get(target, prop) {
    if (prop === Symbol.iterator || typeof prop === 'symbol') return FORUMS_BASE[prop];
    return getForums()[prop];
  },
  ownKeys() { return Object.keys(getForums()); },
  getOwnPropertyDescriptor(target, prop) {
    return { enumerable: true, configurable: true, value: getForums()[prop] };
  },
  has(target, prop) { return prop in getForums(); }
});

// Correctif bug beta forum (diagnostic + validation Fred, 16 aout 2026) : les 4 sujets de
// demonstration codes en dur ici (topic-1/topic-2/topic-4/topic-5) n'ont jamais existe dans
// Supabase (forum_topics) -- repondre a l'un d'eux echouait systematiquement, sbCreatePost
// echouant sur un topic_id sans ligne reelle correspondante. Retires plutot que migres : aucun
// sujet affiche dans le forum ne doit exister uniquement cote client.
const FORUM_TOPICS = {
  local: [],
  national: [],
  international: [],
  gouvernement: [], presse: []
};

// Mails inter-joueurs
const MAILS_STORAGE_KEY = 'respublica_mails';

function getMails() {
  try { return JSON.parse(localStorage.getItem(MAILS_STORAGE_KEY) || '[]'); } catch { return []; }
}
function saveMails(mails) {
  localStorage.setItem(MAILS_STORAGE_KEY, JSON.stringify(mails));
}
function getMyMails() {
  const name = state.char?.name;
  if (!name) return [];
  // m.fromReal (17 aout 2026) : pour un mail organisationnel, m.from est le nom PUBLIC de l
  // organisation, jamais celui du personnage reel -- sans ce critere, l'expediteur reel ne
  // retrouverait jamais son propre mail dans "Envoyes".
  return getMails().filter(m => m.to === name || m.from === name || m.fromReal === name);
}

// Correctif doublon "Envoyes" (17 aout 2026) : sendMail() generait auparavant son PROPRE id
// local ('mail-' + Date.now()) pour l'echo immediat, independamment de l'id deja genere par
// sbSendMail() pour la ligne Supabase reelle -- deux appels Date.now() separes par un aller-
// retour reseau, donc presque toujours deux ids differents. Au rechargement suivant de la
// messagerie (loadMailsFromSB), la ligne Supabase et l'echo local (id different, meme contenu)
// n'etaient jamais reconnus comme le meme mail et survivaient tous les deux -- doublon
// PERSISTANT dans "Envoyes", reproduit et confirme (voir audit). sbSendMail() renvoie desormais
// l'id reellement insere (ou null en cas d'echec) : reutilise ici pour l'echo local, jamais
// regenere -- meme doctrine que le correctif forum du 16 aout 2026 (458c334/458).
//
// Identite d'expedition (17 aout 2026, envoi au nom d'une organisation) : reutilise TEL QUEL
// resoudreIdentitePublication() (etablie pour le forum) -- fonction deja generique (aucun
// couplage aux sujets/posts du forum), meme doctrine de controle frais au moment exact de
// l'action (chef re-verifie via sbGetOrganisationParId, jamais state.organisations perime),
// aucune seconde source de verite creee. Le champ 'compose-mail-auteur' n'existe que dans le
// compositeur principal (renderMailCompose) -- absent ailleurs (ex. modal-compose-mail, envoi
// rapide depuis le repertoire/une fiche PNJ), resoudreIdentitePublication retombe alors
// naturellement sur l'identite personnelle (comportement inchange pour ce chemin, volontaire).
async function sendMail(to, subject, body) {
  const identite = typeof resoudreIdentitePublication === 'function'
    ? await resoudreIdentitePublication('compose-mail-auteur')
    : { authorName: state.char?.name || 'Anonyme', authorIsOrg: false, authorReal: state.char?.name || 'Anonyme', orgaId: null, orgIcon: null };
  if (identite.refuse) {
    showToast('Action refusée', "Vous n'êtes plus habilité à envoyer au nom de cette organisation.", false);
    return;
  }
  const from = identite.authorName;
  const time = formatDateHeureJeu();

  let mailId = null;
  if (typeof sbSendMail === 'function') {
    mailId = await sbSendMail(from, to, subject, body, time, identite.authorReal, identite.orgaId, identite.orgIcon);
    if (!mailId) {
      showToast('Erreur', "Le mail n'a pas pu être enregistré.", false);
      return;
    }
  } else {
    mailId = 'mail-' + Date.now();
  }

  const mails = getMails();
  mails.push({
    id: mailId, from, to, subject, body, time, read: false,
    fromIsOrg: identite.authorIsOrg, fromReal: identite.authorReal,
    fromOrgId: identite.orgaId, fromOrgIcon: identite.orgIcon
  });
  saveMails(mails);
  addJournalEntry(`Mail envoyé à ${to} : "${subject}".`, 'event-info');
  showToast('Mail envoyé', `À ${to} — "${subject}"`, true);

  if ((to || '').replace(' (PNJ)', '').trim() === 'Jérémy' && typeof queteAccueilGenererReponseMailJeremy === 'function') {
    queteAccueilGenererReponseMailJeremy(subject, body);
  }
}
function markMailRead(mailId) {
  const mails = getMails();
  const m = mails.find(x => x.id === mailId);
  if (m && !m.read) {
    m.read = true;
    saveMails(mails);
    if (typeof sbMarkMailRead === 'function') sbMarkMailRead(mailId).catch(() => {});
  }
}

// Correctif latence des voyants (audit du 21 aout 2026) : recalcule le voyant Mail global
// (#mail-badge + titre d'onglet, normalement mis a jour uniquement par verifierNouveauxMails(),
// plateau-communication.js, au chargement et toutes les 2 minutes) depuis le cache LOCAL deja a
// jour (getMyMails(), rafraichi par loadMailsFromSB() a chaque ouverture de la messagerie) --
// AUCUN appel reseau ici, purement une relecture locale instantanee. A appeler apres toute
// mutation locale de l'etat lu/non-lu (lecture d'un mail) pour ne pas attendre le prochain
// passage du polling.
function rafraichirVoyantMailLocal() {
  const nom = state.char?.name;
  if (!nom) return;
  const nonLus = getMyMails().filter(m => !m.read && m.to === nom).length;
  const badge = document.getElementById('mail-badge');
  if (badge) { badge.textContent = nonLus; badge.style.display = nonLus > 0 ? 'inline' : 'none'; }
  document.title = nonLus > 0 ? '(' + nonLus + ') Res Publica' : 'Res Publica';
}
function deleteMail(mailId) {
  const mails = getMails().filter(x => x.id !== mailId);
  saveMails(mails);
  // Supprimer aussi cote Supabase, sinon le mail reapparait a la prochaine synchro
  if (typeof sbDeleteMail === 'function') {
    sbDeleteMail(mailId).catch(() => {});
  }
}

function toggleArchiveMail(mailId, archive) {
  const mails = getMails();
  const m = mails.find(x => x.id === mailId);
  if (m) { m.archived = archive; saveMails(mails); }
  if (typeof sbSetMailArchived === 'function') {
    sbSetMailArchived(mailId, archive).catch(() => {});
  }
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

// Emojis par catégorie
// Palette enrichie (correctif ergonomique post-E3) : catégories, mécanisme d'insertion
// (rpCanvasAttachEmojiButton, forum-canvas.js) et bouton 😊 (renderRichEditor) inchangés --
// uniquement les listes elles-mêmes. Ajouts choisis pour couvrir un éventail d'expressions
// utiles à un forum de jeu de rôle politique/social (rire, sourire, clin d'oeil, ironie,
// tristesse, pleurs, colère, surprise, peur, embarras, réflexion, approbation, désapprobation,
// amour/admiration, félicitations, provocation) sans dupliquer des variantes déjà couvertes
// (secret via 🤫 déjà présent, argent via 🤑 déjà présent, politique/vote/pouvoir et justice
// déjà bien représentés par 🗳️/👑/⚖️, médias/information déjà couverts par 📰/🔎, alerte/danger
// déjà couverts par 🚨/⚠️ -- ces catégories ne reçoivent que quelques ajouts ciblés, pas une
// refonte).
const EMOJI_CATS = {
  'Politique': ['🏛️','👑','⚖️','🗳️','📜','🤝','🚩','🎖️','🛡️','📋','🗡️','🔏','🏆','🎗️','🎩','🏰','🕊️','💼'],
  'Alertes':   ['⚠️','🚨','‼️','❗','🔴','🟢','🔵','⭕','✅','❌','🔔','📣','📢','🚫','🆘','⛔','🔥'],
  'Médias':    ['📰','📡','✍️','📝','💬','📨','🎙️','📸','🖊️','📖','🗞️','📻','🎬','🔎','📺','🎥','🗨️'],
  'Émotions':  ['😄','😈','🤫','🤐','👀','🙏','💪','🤑','😤','🧐','😏','🤭','👏','🫡',
                '😂','🤣','🙂','😉','🙃','😢','😭','😠','😲','😨','😳','🤔','👍','👎','😍','😜','🎉'],
  'Symboles':  ['⭐','💀','💣','🔒','🔓','🕵️','🃏','⚡','🌟','💡','🔑','💎','🏴','⚜️','💰','🏦','🎭'],
  'Séparateurs':['═══════════════','· · · · · · · · ·','— — — — — — —','⚜️ ─────────── ⚜️','◆ ─────────── ◆','✦ · · · · · · · ✦','★ ─────────── ★','─────── ⚖️ ───────']
};

// Styles narratifs
const STYLES_NARRATIFS = {
  'Communiqué officiel': `<div style="border:2px solid #C9A84C;padding:1rem;margin:.5rem 0;background:rgba(201,168,76,0.05)"><div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.15em;color:#C9A84C;border-bottom:1px solid #C9A84C;padding-bottom:.3rem;margin-bottom:.6rem">COMMUNIQUÉ OFFICIEL</div><p>Rédigez votre communiqué ici...</p></div>`,
  'Article de presse':   `<div style="border-left:3px solid #8a6a20;padding:.5rem 1rem;margin:.5rem 0"><div style="font-size:.7rem;letter-spacing:.1em;color:#8a8060;text-transform:uppercase">ARTICLE — LA TRIBUNE</div><h3 style="margin:.3rem 0;color:#f0ead6">Titre de l'article</h3><p style="font-style:italic;color:#8a8060;font-size:.8rem">Par [Auteur] · Jour [X]</p><p>Corps de l'article...</p></div>`,
  'Discours':            `<div style="text-align:center;padding:1rem;margin:.5rem 0"><div style="font-size:.7rem;letter-spacing:.2em;color:#8a8060">— DISCOURS —</div><p style="font-size:1.05rem;line-height:1.8;font-style:italic;color:#f0ead6">"Texte du discours..."</p><div style="font-size:.7rem;color:#8a6a20;margin-top:.5rem">— Nom, Titre</div></div>`,
  'Citation':            `<div style="margin:1.3rem 0"><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— · —</div><blockquote style="border-left:3px solid #C9A84C;padding:.7rem 1.2rem;margin:.5rem 0;color:#c0b090"><em>Texte cité...</em></blockquote><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— · —</div></div>`,
  'Encadré':             `<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin:.5rem 0;border-radius:2px">Contenu de l'encadré...</div>`,
  '2 colonnes':          `<div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin:.5rem 0"><div>Colonne gauche...</div><div>Colonne droite...</div></div>`,
};

let currentForumId = null;
let currentTopicId = null;
let forumView = 'list';
let forumCategorieActive = null; // 'intra' | 'inter' | 'prive' | null (rien de deplie)
let forumSousGroupeOuvert = false; // accordeon imbrique pour 'Institutionnels'
let mailView = 'inbox'; // 'inbox' | 'compose' | 'read'
let mailDefaultTo = ''; // Destinataire pré-rempli depuis répertoire PJ
let editingPostId = null;
let editingTopicId = null;
// Onboarding forum (17 aout 2026) : armé uniquement par queteAccueilLancerPresentationForum()
// (plateau-quete-accueil.js) juste après l'ouverture du compositeur, jamais avant. Remis à
// false au tout début de CHAQUE ouverture de showComposeCanvasForm() (donc y compris par le
// bouton normal "Nouveau sujet"), ce qui empêche une session d'onboarding abandonnée de
// "fuiter" vers une publication ultérieure sans rapport -- toute nouvelle ouverture du
// compositeur repart obligatoirement désarmée, seul l'appel d'onboarding la réarme aussitôt
// après. Consommé (remis à false) uniquement lors d'une publication personnelle réellement
// réussie dans submitComposeCanvas().
let onboardingComposeEnCours = false;
function onboardingArmerComposeCanvas() { onboardingComposeEnCours = true; }

// =====================
// MODAL PRINCIPALE
// =====================
function openForum_module(forumId) {
  currentForumId = forumId || null;
  currentTopicId = null;
  forumView = 'list';
  if (forumId) {
    const f = getForums()[forumId];
    if (f?.cat) forumCategorieActive = f.cat;
  } else {
    forumCategorieActive = null;
  }
  renderForumModal();
  document.getElementById('modal-forum').classList.add('open');
  // Voyant d'activite (17 aout 2026) : point d'entree UNIQUE de toute ouverture du forum/de la
  // messagerie (bouton principal, raccourcis depuis une organisation) -- eteindre ici couvre
  // tous les chemins d'acces sans code specifique a chacun.
  if (typeof marquerForumVisite === 'function') marquerForumVisite();
  if (forumId) {
    // Charger depuis Supabase en arrière-plan et rafraîchir -- renderForumModal() complet (pas
    // seulement #forum-main), sinon le compteur de la sidebar (forum-nav-count, deja rendu AVANT
    // que FORUM_TOPICS[forumId] soit peuple) reste fige a "0 sujet(s)" jusqu'a un changement de
    // rubrique ulterieur (bug constate le 20 aout 2026 : panneau principal a jour, sidebar non).
    loadForumTopicsFromSB(forumId).then(() => {
      if (mailView !== 'compose') renderForumModal();
    }).catch(() => {});
  }
}

// =====================
// VOYANT D'ACTIVITE FORUM (17 aout 2026)
// =====================
// Audit prealable : aucun mecanisme de lecture existant (ni lastForumVisit, ni table dediee, ni
// lu/non-lu par sujet) -- confirme, rien a reutiliser. Doctrine V1 volontairement simple :
// dernier contenu forum (nouveaux sujets + nouvelles reponses, jamais une simple edition
// puisque created_at ne change pas a l'edition) compare a la derniere consultation du joueur,
// sans suivi sujet par sujet.
//
// Persistance : localStorage, cle SUFFIXEE PAR LE NOM DU PERSONNAGE (meme convention que
// respublica_mails/respublica_photo_<nom>) -- jamais la table personnages, deja identifiee
// comme resauvegardee integralement a chaque action (sbSavePersonnage) : y ajouter un champ
// aurait exige une migration ET une re-ecriture complete du personnage a chaque ouverture du
// forum pour une simple estampille d'attention, risque disproportionne pour ce lot. Compromis
// assume : ne survit pas a un changement d'appareil -- acceptable pour cette V1 beta (voir
// rapport), et peut migrer vers une colonne dediee plus tard sans casser ce mecanisme.
function _cleDernierPassageForum() {
  const nom = state.char?.name;
  return nom ? 'respublica_dernier_passage_forum_' + nom : null;
}

// Marque le forum comme visite PAR CE PERSONNAGE (jamais global -- ne doit jamais eteindre le
// voyant d'un autre joueur). Appelee a l'ouverture du forum (openForum_module) ET juste apres
// la propre publication reussie du joueur (submitNewTopic/submitReply/submitReplyComposed/
// submitComposeCanvas), pour eviter qu'il voie un voyant rouge simplement parce qu'il vient de
// publier -- son propre post est cree AVANT cet appel, donc toujours <= a l'horodatage marque
// ici, jamais reconnu comme "nouveau" pour lui-meme au prochain controle.
function marquerForumVisite() {
  const cle = _cleDernierPassageForum();
  if (!cle) return;
  try { localStorage.setItem(cle, new Date().toISOString()); } catch(e) {}
  const dot = document.getElementById('forum-activity-dot');
  if (dot) dot.style.display = 'none';
}

async function verifierActiviteForumNonVue() {
  const cle = _cleDernierPassageForum();
  if (!cle || typeof sbGetDernierContenuForum !== 'function') return;
  try {
    const dernierContenu = await sbGetDernierContenuForum();
    const dot = document.getElementById('forum-activity-dot');
    if (!dernierContenu || !dot) return;
    const dernierPassage = localStorage.getItem(cle);
    dot.style.display = (!dernierPassage || dernierContenu > dernierPassage) ? 'inline-block' : 'none';
  } catch(e) {}
}

// Voyants par rubrique, a l'interieur de l'interface Messages/Forums (18 aout 2026). Reutilise
// STRICTEMENT les mecanismes deja existants -- aucune nouvelle notion de "lu" :
//  - Mail : recalcule en temps reel depuis read:false (meme filtre que le texte "X non lu(s)"
//    deja affiche a cote de "Boîte Mail", jamais un nouveau systeme de lecture) ;
//  - Forum : lit l'etat COURANT du voyant global #forum-activity-dot (doctrine "derniere
//    consultation globale" deja en place, jamais decomposee par sous-forum/sujet). Comme
//    openForum_module() rend le sidebar AVANT d'appeler marquerForumVisite() (voir plus haut),
//    cette lecture capture bien "y avait-il du nouveau au moment de l'ouverture", pas apres.
function forumADeLActiviteNonVue() {
  const dot = document.getElementById('forum-activity-dot');
  return !!dot && dot.style.display !== 'none';
}

// Meme identite visuelle que #forum-activity-dot (8px, #cc2020, rond) -- jamais une deuxieme
// forme de voyant. margeGauche permet de coller le point juste apres un libelle existant.
function htmlPointRougeActivite(margeGauche) {
  return '<span style="display:inline-block;width:8px;height:8px;background:#cc2020;border-radius:50%;margin-left:' + (margeGauche || '.4rem') + ';vertical-align:middle"></span>';
}

function renderForumNavItem(id, f) {
  const accessible = !f.private || canAccessForum(id);
  return `<div class="forum-nav-item ${id === currentForumId && forumView !== 'mail' ? 'active' : ''} ${!accessible ? 'locked' : ''}"
    onclick="${accessible ? `switchForum('${id}')` : `showToast('Accès restreint','Ce forum est réservé aux membres autorisés.',false)`}">
    <i class="ti ${f.icon}" style="font-size:.85rem"></i>
    <div>
      <div class="forum-nav-name">${f.name}</div>
      <div class="forum-nav-count">${(FORUM_TOPICS[id]||[]).length} sujet(s)</div>
    </div>
    ${f.private ? `<i class="ti ti-lock" style="font-size:.65rem;color:#4a4030;margin-left:auto"></i>` : ''}
  </div>`;
}

function renderForumCategorieItems(cat) {
  const forums = getForums();
  const entries = Object.entries(forums).filter(([id, f]) => f.cat === cat);

  if (cat === 'intra') {
    const directs = entries.filter(([id, f]) => !f.sousGroupe);
    const institutions = entries.filter(([id, f]) => f.sousGroupe === 'institutions');
    const parLocal = directs.filter(([id]) => id === 'local');
    const parNational = directs.filter(([id]) => id === 'national');
    const parPresse = directs.filter(([id]) => id === 'presse');
    return `<div class="forum-categorie-items">` +
      parLocal.map(([id, f]) => renderForumNavItem(id, f)).join('') +
      parNational.map(([id, f]) => renderForumNavItem(id, f)).join('') +
      (institutions.length > 0 ? `<div class="forum-nav-item" onclick="toggleSousGroupeForum()">
        <i class="ti ti-building-bank" style="font-size:.85rem"></i>
        <div><div class="forum-nav-name">Institutionnels</div></div>
        <i class="ti ti-chevron-right forum-categorie-chevron ${forumSousGroupeOuvert ? 'ouvert' : ''}" style="margin-left:auto"></i>
      </div>` +
        `<div class="forum-sousgroupe">` +
        (forumSousGroupeOuvert ? institutions.map(([id, f]) => renderForumNavItem(id, f)).join('') : '') +
        `</div>` : '') +
      parPresse.map(([id, f]) => renderForumNavItem(id, f)).join('') +
      `</div>`;
  }

  if (cat === 'prive' && entries.length === 0) {
    return `<div class="forum-categorie-items"><div style="padding:.7rem .8rem;font-size:.75rem;color:#6a5a30;font-style:italic">Aucune organisation trouvée. Rejoignez ou fondez une organisation pour accéder à son forum privé.</div></div>`;
  }

  return `<div class="forum-categorie-items">` + entries.map(([id, f]) => renderForumNavItem(id, f)).join('') + `</div>`;
}

function toggleSousGroupeForum() {
  forumSousGroupeOuvert = !forumSousGroupeOuvert;
  document.getElementById('forum-body').innerHTML && renderForumModal();
}

function toggleCategorieForum(cat) {
  if (forumCategorieActive === cat && forumView !== 'mail') {
    // Deja ouverte : on replie et on vide la selection (page centrale vide)
    forumCategorieActive = null;
    currentForumId = null;
    renderForumModal();
    return;
  }
  forumCategorieActive = cat;
  forumView = 'list';
  const forums = getForums();
  const premiereEntree = Object.entries(forums).find(([id, f]) => f.cat === cat);
  currentForumId = premiereEntree ? premiereEntree[0] : null;
  currentTopicId = null;
  renderForumModal();
  if (currentForumId) {
    // renderForumModal() complet (meme correctif que openForum_module ci-dessus, compteur
    // sidebar) plutot qu'une simple mise a jour de #forum-main.
    loadForumTopicsFromSB(currentForumId).then(() => {
      if (mailView !== 'compose') renderForumModal();
    }).catch(() => {});
  }
}

function renderCategorieHeader(cat, icon, label) {
  const active = forumView !== 'mail' && forumCategorieActive === cat;
  return `<div class="forum-categorie-header ${active ? 'active' : ''}" onclick="toggleCategorieForum('${cat}')">
    <i class="ti ${icon}" style="font-size:.85rem"></i>
    ${label}
    <i class="ti ti-chevron-right forum-categorie-chevron ${active ? 'ouvert' : ''}"></i>
  </div>
  ${active ? renderForumCategorieItems(cat) : ''}`;
}

function renderForumModal() {
  const modal = document.getElementById('forum-body');
  const unreadCount = getMyMails().filter(m => !m.read && m.to === state.char?.name).length;
  // Voyants de rubrique (18 aout 2026, corrige suite a retour : un seul voyant Forum, jamais
  // repete sur Forums nationaux/internationaux/prives -- le mecanisme sous-jacent n'a aucune
  // granularite par sous-forum, et 3 points rouges simultanes suggeraient visuellement le
  // contraire au joueur). Mail depuis unreadCount (deja calcule ci-dessus, temps reel) ; Forum
  // depuis l'etat courant du voyant global (calcule une seule fois, avant que
  // marquerForumVisite() -- appelee juste apres ce rendu par openForum_module() -- ne l'eteigne).
  // Place sur le titre du modal (#modal-forum-title, plateau.html), seul element qui represente
  // "Forum" en general sans etre l'une des 3 categories ni la Boite Mail.
  const forumNonVu = forumADeLActiviteNonVue();
  const titreModal = document.getElementById('modal-forum-title');
  if (titreModal) titreModal.innerHTML = 'Forum' + (forumNonVu ? htmlPointRougeActivite('.4rem') : '');
  modal.innerHTML = `
    <div class="forum-layout">
      <div class="forum-sidebar">
        <div class="forum-nav-item forum-mail-item ${forumView === 'mail' ? 'active' : ''}" onclick="switchToMail()">
          <i class="ti ti-mail" style="font-size:.85rem"></i>
          <div>
            <div class="forum-nav-name">Boîte Mail${unreadCount > 0 ? htmlPointRougeActivite('.4rem') : ''}</div>
            <div class="forum-nav-count">${unreadCount > 0 ? `<span style="color:#C9A84C">${unreadCount} non lu(s)</span>` : 'Aucun message'}</div>
          </div>
        </div>
        ${renderCategorieHeader('intra', 'ti-flag', 'Forums nationaux')}
        ${renderCategorieHeader('inter', 'ti-world', 'Forums internationaux')}
        ${renderCategorieHeader('prive', 'ti-lock', 'Forums privés')}
      </div>
      <div class="forum-main" id="forum-main">
        ${renderForumContent()}
      </div>
    </div>
  `;
}

function canAccessForum(forumId) {
  const f = FORUMS[forumId];
  if (!f || !f.private) return true;
  if (f.requiredOrgId) {
    const orga = (state.organisations || []).find(o => o.id === f.requiredOrgId);
    return !!orga && (orga.membres || []).some(m => m.nom === state.char?.name);
  }
  // Presse & Medias (correctif du 20 aout 2026) : lecture publique -- seule la CREATION d'un
  // nouveau sujet reste reservee (garde dedie dans submitComposeCanvas(), meme patron que
  // presidence). private:true est conserve uniquement pour l'icone cadenas + la description
  // "Reserve aux journalistes" (renderForumNavItem), qui restent des indications exactes des lors
  // que seule l'ecriture est concernee -- avant ce correctif, canAccessForum() bloquait aussi la
  // simple ouverture de la rubrique pour tout joueur sans poste institutionnel.
  if (forumId === 'presse') return true;
  if (!state.poste) return false;
  if (f.requiredPost) return f.requiredPost.includes(state.poste.id);
  return true;
}

function switchForum(id) {
  currentForumId = id;
  currentTopicId = null;
  forumView = 'list';
  const f = getForums()[id];
  if (f?.cat) forumCategorieActive = f.cat;
  renderForumModal();
  // renderForumModal() complet (meme correctif que ci-dessus, compteur sidebar).
  loadForumTopicsFromSB(id).then(() => {
    if (mailView !== 'compose') renderForumModal();
  }).catch(() => {});
}

function switchToMail() {
  forumView = 'mail';
  mailView = 'inbox';
  renderForumModal();
  if (typeof rafraichirCachePhotosJoueurs === 'function') {
    rafraichirCachePhotosJoueurs().then(() => { if (mailView !== 'compose') renderForumModal(); }).catch(() => {});
  }
  loadMailsFromSB().then(() => {
    if (mailView !== 'compose') renderForumModal();
    // Correctif latence des voyants (21 aout 2026) : synchronise le voyant EXTERIEUR (#mail-badge)
    // depuis le cache local que loadMailsFromSB() vient de rafraichir -- reutilise cette MEME
    // requete reseau (sbGetMailsFor, deja executee ci-dessus), jamais une deuxieme requete
    // separee (verifierNouveauxMails() ferait le meme travail en double).
    if (typeof rafraichirVoyantMailLocal === 'function') rafraichirVoyantMailLocal();
  }).catch(() => {});
}

function renderForumContent() {
  // Correctif croissance verticale du compositeur (correctif bugs bêta forum) : bascule une
  // classe sur le conteneur de modal STATIQUE (#modal-forum, toujours présent dans le DOM,
  // seul son contenu est remplacé -- voir renderForumModal) selon l'écran affiché. Cette
  // classe (style.css) neutralise l'overflow:hidden de #forum-body/.forum-layout/.forum-main
  // UNIQUEMENT pour l'écran de composition, sans rien changer aux autres écrans (liste, sujet,
  // etc., qui gardent leur propre défilement interne existant, .forum-topics-list). Effectué
  // ici plutôt qu'à chaque site d'appel : renderForumContent() est le seul point de passage
  // commun à tous les changements d'écran du forum.
  const modalForumEl = document.getElementById('modal-forum');
  if (modalForumEl) modalForumEl.classList.toggle('forum-compose-grow', forumView === 'compose-canvas');
  if (forumView === 'mail')      return renderMailView();
  if (forumView === 'list' && !currentForumId) return renderForumAccueil();
  if (forumView === 'list')      return renderTopicList();
  if (forumView === 'topic')     return renderTopicView();
  if (forumView === 'new-topic') return renderNewTopicForm();
  if (forumView === 'reply')     return renderReplyForm();
  if (forumView === 'edit-post') return renderEditPostForm();
  if (forumView === 'compose-canvas') return renderComposeCanvasForm();
  return '';
}

// =====================
// FORUM — LISTE TOPICS
// =====================
function renderForumAccueil() {
  return `<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;color:#6a5a30;gap:.6rem">
    <i class="ti ti-message-2-cog" style="font-size:2.2rem;opacity:.5"></i>
    <div style="font-family:Bebas Neue,sans-serif;font-size:1rem;letter-spacing:.05em;color:#8a7040">Choisissez une categorie a gauche</div>
    <div style="font-size:.78rem;max-width:260px;text-align:center">Forums nationaux, internationaux ou prives -- deroulez une categorie pour voir ses forums.</div>
  </div>`;
}

function renderTopicList() {
  const f = FORUMS[currentForumId];
  const topics = [...(FORUM_TOPICS[currentForumId] || [])].sort((a, b) =>
    parseGameTime(b.lastPostTime || b.time) - parseGameTime(a.lastPostTime || a.time)
  );
  const peutCreerSujet = currentForumId !== 'presidence' || state.poste?.id === 'president';
  return `
    <div class="forum-header-bar">
      <div>
        <div class="forum-title-main"><i class="ti ${f.icon}"></i> ${f.name}</div>
        <div class="forum-subtitle">${f.desc}</div>
      </div>
      ${peutCreerSujet ? `
      <button class="forum-new-btn" onclick="showComposeCanvasForm()">
        <i class="ti ti-pencil-plus"></i> Nouveau sujet
      </button>` : ''}
    </div>
    ${topics.length === 0
      ? `<div class="forum-empty">Aucun sujet. ${peutCreerSujet ? 'Soyez le premier à en créer un !' : "Seul le Président peut s'exprimer ici."}</div>`
      : `<div class="forum-topics-list">
          <div class="forum-topics-header">
            <span>Sujet</span><span>Auteur</span><span>Dernier post</span><span>Vues</span><span>Rép.</span>
          </div>
          ${topics.map(t => `
            <div class="forum-topic-row" onclick="openTopic('${t.id}')">
              <div class="forum-topic-title">
                <i class="ti ti-message-circle" style="font-size:.8rem;color:#4a6a4a;margin-right:.3rem"></i>
                ${escapeHtmlText(t.title)}
              </div>
              <div class="forum-topic-author">
                <div>${escapeHtmlText(t.author)}${t.authorIsOrg ? ' <i class="ti ti-shield" style="font-size:.65rem;color:#8a8060" title="Organisation"></i>' : ''}</div>
                <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(t.time)}</div>
              </div>
              <div class="forum-topic-author">
                <div>${escapeHtmlText(t.lastPostAuthor || t.author)}</div>
                <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(t.lastPostTime || t.time)}</div>
              </div>
              <div class="forum-topic-stat">${t.views}</div>
              <div class="forum-topic-stat">${t.replies}</div>
            </div>`).join('')}
        </div>`}
  `;
}

// =====================
// FORUM — VUE TOPIC
// =====================
// Avatar d'un post/sujet (16-17 aout 2026, publication au nom d'une organisation) : une
// publication organisationnelle affiche l'identite visuelle de l'organisation, figee au moment
// de la publication -- p.authorOrgIcon/authorOrgIcon selon le contexte -- jamais le portrait
// personnel du chef. Une publication personnelle garde l'avatar existant inchange
// (getAvatarHtmlPourNom).
//
// Identite visuelle organisationnelle (17 aout 2026, avatar personnalise) : 'icone' porte soit
// une classe Tabler Icon (ex. 'ti-users-group', repli generique TYPES_ORGANISATIONS[type].icon),
// soit desormais une URL/chemin d'image (avatar personnalise de l'organisation, orga.avatar).
// Distinction faite via le prefixe 'ti-' -- convention EXHAUSTIVE et sans exception dans tout le
// depot (aucune classe Tabler Icon n'existe hors de ce prefixe, verifie), pas une heuristique
// fragile mais la seule forme reellement prise par les deux valeurs possibles de ce champ ; une
// colonne de type dediee (image|icon) apporterait de la complexite de schema sans lever une
// ambiguite qui n'existe pas en pratique. onerror : repli visuel sur l'icone generique si l'
// image est cassee (URL externe supprimee, hebergement disparu), jamais un cadre casse.
function getAvatarHtmlPost(estOrg, icone, author, taille) {
  const t = taille || 32;
  if (estOrg) {
    if (icone && !icone.startsWith('ti-')) {
      const tailleIcone = Math.round(t * 0.5);
      return '<div style="width:' + t + 'px;height:' + t + 'px;border-radius:50%;overflow:hidden;border:1px solid #C9A84C;flex-shrink:0;background:#1a1508;position:relative">' +
        '<img src="' + icone + '" style="width:100%;height:100%;object-fit:cover" onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\'"/>' +
        '<i class="ti ti-building-community" style="display:none;position:absolute;inset:0;align-items:center;justify-content:center;font-size:' + tailleIcone + 'px;color:#C9A84C"></i>' +
        '</div>';
    }
    const cls = icone || 'ti-building-community';
    return '<div style="width:' + t + 'px;height:' + t + 'px;border-radius:50%;background:#1a1508;border:1px solid #C9A84C;display:flex;align-items:center;justify-content:center;flex-shrink:0"><i class="ti ' + cls + '" style="font-size:' + Math.round(t * 0.5) + 'px;color:#C9A84C"></i></div>';
  }
  return typeof getAvatarHtmlPourNom === 'function' ? getAvatarHtmlPourNom(author, t) : '<i class="ti ti-user" style="font-size:1.2rem;color:#C9A84C"></i>';
}

function renderTopicView() {
  const topics = FORUM_TOPICS[currentForumId] || [];
  const topic = topics.find(t => t.id === currentTopicId);
  if (!topic) return renderTopicList();
  const myName = state.char?.name || '';

  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToList()">
        <i class="ti ti-arrow-left"></i> Retour
      </button>
      <div class="forum-title-main" style="flex:1">${escapeHtmlText(topic.title)}</div>
    </div>
    <div class="forum-posts">
      ${topic.posts.map((p, i) => `
        <div class="forum-post">
          <div class="forum-post-side">
            <div class="forum-post-avatar" ${(!p.authorIsOrg && !(typeof PNJ_PERSONALITIES !== 'undefined' && PNJ_PERSONALITIES[p.author])) ? `style="cursor:pointer" data-author="${escapeHtmlText(p.author)}" onclick="ouvrirFichePublique(this.dataset.author)"` : ''}>${getAvatarHtmlPost(p.authorIsOrg, p.authorOrgIcon, p.author, 40)}</div>
            ${p.authorCountry && COUNTRIES?.[p.authorCountry] ? '<div style="width:100%;height:6px;background:' + COUNTRIES[p.authorCountry].col + ';margin:.3rem 0 .1rem"></div>' : ''}
            <div class="forum-post-author">${escapeHtmlText(p.author)}${p.authorIsOrg ? ' <i class="ti ti-shield" style="font-size:.7rem;color:#8a8060" title="Organisation"></i>' : ''}</div>
            ${p.authorSecret ? '<span class="forum-post-badge" style="border-color:#8a2020;color:#cc4444">secrète</span>' : ''}
            <div class="forum-post-time">${formatDateAffichage(p.time)}</div>
            ${i === 0 ? `<span class="forum-post-badge">Auteur du sujet</span>` : ''}
          </div>
          <div class="forum-post-main">
            <div class="forum-post-toolbar">
              ${(p.authorReal || p.author) === myName ? `
                <button onclick="editPost('${topic.id}','${p.id || i}')" style="background:transparent;border:none;color:#8a8060;cursor:pointer;font-size:.75rem;padding:.2rem .4rem" title="Modifier">
                  <i class="ti ti-edit"></i>
                </button>
                <button onclick="confirmerSuppressionPost('${topic.id}','${p.id || i}')" style="background:transparent;border:none;color:#8a8060;cursor:pointer;font-size:.75rem;padding:.2rem .4rem" title="Supprimer">
                  <i class="ti ti-trash"></i>
                </button>` : ''}
              <button onclick="quotePost(${i})" style="background:transparent;border:none;color:#8a8060;cursor:pointer;font-size:.75rem;padding:.2rem .4rem" title="Citer">
                <i class="ti ti-quote"></i>
              </button>
            </div>
            <div class="forum-post-content">${p.content_layout ? renderComposedPost(p.content_layout) : ((p.blocks && p.blocks.length > 0) ? sanitizeRichHtml(renderBlocks(p.blocks)) : sanitizeRichHtml(p.content))}</div>
          </div>
        </div>`).join('')}
    </div>
    <div class="forum-reply-bar">
      <button class="forum-new-btn" onclick="showComposeCanvasReply()">
        <i class="ti ti-corner-down-right"></i> Répondre
      </button>
    </div>
  `;
}

// =====================
// ÉDITEUR RICHE
// =====================
function renderRichEditor(id, initialContent = '') {
  return `
    <div class="rich-editor">
      <div class="rich-toolbar">
        <button class="rich-btn" onclick="richFmt('bold')" title="Gras"><b>G</b></button>
        <button class="rich-btn" onclick="richFmt('italic')" title="Italique"><i>I</i></button>
        <button class="rich-btn" onclick="richFmt('underline')" title="Souligné"><u>S</u></button>
        <div class="rich-sep"></div>
        <button class="rich-btn" onclick="richHeading(2)" title="Titre H2">H2</button>
        <button class="rich-btn" onclick="richHeading(3)" title="Titre H3">H3</button>
        <div class="rich-sep"></div>
        <button class="rich-btn" onclick="richFmt('justifyLeft')" title="Gauche"><i class="ti ti-align-left"></i></button>
        <button class="rich-btn" onclick="richFmt('justifyCenter')" title="Centrer"><i class="ti ti-align-center"></i></button>
        <button class="rich-btn" onclick="richFmt('justifyRight')" title="Droite"><i class="ti ti-align-right"></i></button>
        <button class="rich-btn" onclick="richFmt('justifyFull')" title="Justifier"><i class="ti ti-align-justified"></i></button>
        <div class="rich-sep"></div>
        <button class="rich-btn" onclick="richFmt('insertUnorderedList')" title="Liste à puces"><i class="ti ti-list"></i></button>
        <button class="rich-btn" onclick="richFmt('insertOrderedList')" title="Liste numérotée"><i class="ti ti-list-numbers"></i></button>
        <div class="rich-sep"></div>
        <button class="rich-btn" onclick="richColor()" title="Couleur texte" style="color:#C9A84C">A</button>
        <button class="rich-btn" onclick="richInsertHR()" title="Séparateur">—</button>
        <div class="rich-sep"></div>
        <button class="rich-btn" onmousedown="saveRichSelection()" onclick="richInsertImage()" title="Image"><i class="ti ti-photo"></i></button>
        <button class="rich-btn" onclick="toggleStylePanel()" title="Styles narratifs"><i class="ti ti-layout"></i></button>
        <button class="rich-btn" onclick="toggleEmojiPanel()" title="Emojis & Symboles">😊</button>
      </div>

      <!-- Panneau styles narratifs -->
      <div id="style-panel" style="display:none;border:1px solid #2a2010;background:#0a0a07;padding:.6rem;flex-wrap:wrap;gap:.4rem">
        ${Object.keys(STYLES_NARRATIFS).map(s =>
          `<button onclick="richInsertStyle('${s}')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.08em;padding:.3rem .6rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">${s}</button>`
        ).join('')}
      </div>

      <!-- Panneau emojis -->
      <div id="emoji-panel" style="display:none;border:1px solid #2a2010;background:#0a0a07;padding:.6rem">
        <div style="display:flex;gap:.4rem;margin-bottom:.5rem;flex-wrap:wrap">
          ${Object.keys(EMOJI_CATS).map(cat =>
            `<button onclick="switchEmojiCat('${cat}')" class="emoji-cat-btn" data-cat="${cat}" style="font-family:Bebas Neue,sans-serif;font-size:.6rem;letter-spacing:.08em;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">${cat}</button>`
          ).join('')}
        </div>
        <div id="emoji-grid" style="display:flex;flex-wrap:wrap;gap:.3rem">
          ${EMOJI_CATS['Politique'].map(e =>
            e.length > 4
              ? `<button onclick="richInsertSep('${e}')" style="font-size:.65rem;padding:.2rem .4rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer;white-space:nowrap">${e}</button>`
              : `<button onclick="richInsertEmoji('${e}')" style="font-size:1.1rem;padding:.1rem .2rem;border:none;background:transparent;cursor:pointer">${e}</button>`
          ).join('')}
        </div>
      </div>

      <div class="rich-content" id="${id}" contenteditable="true" onfocus="window._lastRichEditorId=this.id" onkeydown="handleRichEditorEnter(event)"
        style="min-height:150px;padding:.8rem;outline:none;font-family:Crimson Pro,Georgia,serif;font-size:.9rem;line-height:1.7;color:#f0ead6"
        placeholder="Écrivez votre message...">${initialContent}</div>
    </div>
  `;
}

function richFmt(cmd) {
  document.execCommand(cmd, false, null);
  document.querySelector('.rich-content:focus, [contenteditable]:focus')?.focus();
}

function richHeading(level) {
  document.execCommand('formatBlock', false, `h${level}`);
}

function richColor() {
  const colors = [
    '#f0ead6','#C9A84C','#E8D880','#cc4444','#e08a8a','#4a8a4a','#7abf6a',
    '#4a6aaa','#7a9ad0','#aa6aaa','#c98ac9','#d08a3a','#8a8060','#5a5040','#000000'
  ];
  const panel = document.getElementById('color-panel-rich');
  if (panel) { panel.remove(); return; }
  const div = document.createElement('div');
  div.id = 'color-panel-rich';
  div.style.cssText = 'position:absolute;z-index:999;background:#0a0a07;border:1px solid #2a2010;padding:.4rem;display:flex;gap:.3rem';
  colors.forEach(c => {
    const btn = document.createElement('button');
    btn.style.cssText = `width:20px;height:20px;background:${c};border:1px solid #2a2010;cursor:pointer`;
    btn.onclick = () => {
      document.execCommand('styleWithCSS', false, true);
      document.execCommand('foreColor', false, c);
      div.remove();
    };
    div.appendChild(btn);
  });
  const toolbar = document.querySelector('.rich-toolbar');
  toolbar?.parentNode?.insertBefore(div, toolbar.nextSibling);
}

async function ouvrirFichePublique(nom) {
  if (!nom) return;
  if (nom === state.char?.name && typeof openCharSheet === 'function') { openCharSheet(); return; }

  document.getElementById('postes-modal-title').textContent = nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const joueurs = typeof sbListPersonnages === 'function' ? await sbListPersonnages().catch(() => []) : [];
  const j = (joueurs || []).find(p => p.name === nom);

  let html = '<div style="padding:1rem;text-align:center">';
  const photo = j?.photo_url || window._cachePhotosJoueurs?.[nom];
  if (photo) {
    html += '<img src="' + photo + '" style="width:80px;height:80px;border-radius:50%;object-fit:cover;border:1px solid #C9A84C;margin-bottom:.6rem"/>';
  }
  html += '<div style="font-family:Playfair Display,serif;font-size:1.1rem;color:#E8D880;margin-bottom:.4rem">' + nom + '</div>';
  if (j) {
    const pays = (typeof COUNTRIES !== 'undefined' && COUNTRIES[j.country]?.n) || j.country || '';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.2rem">' + pays + (j.current_city ? ' · ' + j.current_city : '') + '</div>';
    if (j.poste?.name) html += '<div style="font-size:.8rem;color:#C9A84C">' + j.poste.name + '</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#6a5a30;font-style:italic">Personnage introuvable.</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function richInsertHR() {
  document.execCommand('insertHTML', false, '<hr style="border:none;border-top:1px solid #2a2010;margin:.8rem 0">');
}

let _richInsertTargetId = null;
let _richSavedRange = null;

// Appele au mousedown du bouton Image (avant que le clic ne fasse perdre le focus au champ de texte),
// pour memoriser EXACTEMENT ou etait le curseur, pas juste dans quel champ.
// Entree simple = saut de ligne dans le meme bloc (utile pour rester a cote d'une image flottante).
// Entree deux fois de suite (ligne vide) = nouveau bloc, qui repart toujours en pleine largeur
// meme s'il restait de la place a cote d'une image flottante precedente.
let _lastBreakNode = null;

function handleRichEditorEnter(e) {
  if (e.key !== 'Enter') { _lastBreakNode = null; return; }
  e.preventDefault();

  const sel = window.getSelection();
  if (!sel.rangeCount) return;
  const range = sel.getRangeAt(0);

  if (_lastBreakNode && _lastBreakNode.isConnected) {
    // Deuxieme Entree consecutive : transformer en nouveau bloc plein largeur
    const editorEl = e.target;
    const newP = document.createElement('p');
    newP.style.clear = 'both';
    newP.style.margin = '0 0 .8em';
    newP.appendChild(document.createElement('br'));

    const parentBlock = _lastBreakNode.parentNode === editorEl ? editorEl : (_lastBreakNode.closest('p, div') || editorEl);
    _lastBreakNode.remove();

    if (parentBlock !== editorEl && parentBlock.parentNode) {
      parentBlock.parentNode.insertBefore(newP, parentBlock.nextSibling);
    } else {
      editorEl.appendChild(newP);
    }

    const newRange = document.createRange();
    newRange.setStart(newP, 0);
    newRange.collapse(true);
    sel.removeAllRanges();
    sel.addRange(newRange);

    _lastBreakNode = null;
  } else {
    // Premiere Entree : simple saut de ligne, on reste dans le meme bloc
    const br = document.createElement('br');
    range.deleteContents();
    range.insertNode(br);
    range.setStartAfter(br);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
    _lastBreakNode = br;
  }
}

function saveRichSelection() {
  _richInsertTargetId = null;
  _richSavedRange = null;
  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0) return;
  const range = sel.getRangeAt(0);
  const node = range.commonAncestorContainer;
  const el = node.nodeType === 1 ? node : node.parentElement;
  const editor = el?.closest ? el.closest('.rich-content') : null;
  if (editor) {
    _richSavedRange = range.cloneRange();
    _richInsertTargetId = editor.id;
  }
}

function richInsertImage() {
  // saveRichSelection() (onmousedown, juste avant ce clic) a deja capture la bonne cible de facon fiable.
  if (!_richInsertTargetId) _richInsertTargetId = window._lastRichEditorId || null;

  // Poser un marqueur a la position exacte du curseur, tant que la selection est encore valide —
  // juste avant que la fenetre d'insertion ne prenne le focus. On le remplacera par l'image plus tard
  // via une simple recherche par id, bien plus fiable qu'une restauration de Range apres coup.
  document.querySelectorAll('#_richimg_marker').forEach(m => m.remove());
  if (_richSavedRange) {
    try {
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(_richSavedRange);
      const range = sel.getRangeAt(0);
      const marker = document.createElement('span');
      marker.id = '_richimg_marker';
      marker.style.cssText = 'display:inline-block;width:0;height:0';
      range.deleteContents();
      range.insertNode(marker);
    } catch(e) { /* si ca echoue, confirmerRichInsertImage retombera sur l'insertion en fin de contenu */ }
  }

  document.getElementById('postes-modal-title').textContent = 'Insérer une image';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.4rem">Adresse de l\'image</label>';
  html += '<input id="richimg-url" type="text" autocomplete="off" placeholder="https://..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.55rem;font-family:Crimson Pro,serif;font-size:.9rem;outline:none;box-sizing:border-box;margin-bottom:.8rem" onkeydown="if(event.key===\'Enter\'){event.preventDefault();confirmerRichInsertImage();}"/>';
  html += '<button onclick="confirmerRichInsertImage()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Insérer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  setTimeout(() => document.getElementById('richimg-url')?.focus(), 50);
}

function confirmerRichInsertImage() {
  const url = document.getElementById('richimg-url')?.value?.trim();
  if (!url) { showToast('URL manquante', 'Indiquez une adresse d\'image.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  // Insertion immediate, centree par defaut. L'alignement/legende s'ajustent ensuite
  // en cliquant directement sur l'image une fois inseree — pas de choix a faire avant de voir le resultat.
  const imgId = 'img-' + Date.now();
  const wrapHtml = '<span id="' + imgId + '" data-align="centre" contenteditable="false" style="display:block;text-align:center;margin:.6rem 0;cursor:pointer" onclick="ajusterImageInseree(\'' + imgId + '\')" title="Cliquer pour ajuster"><img src="' + url + '" style="max-width:100%;display:inline-block"/></span>';

  const target = _richInsertTargetId ? document.getElementById(_richInsertTargetId) : null;
  if (target) {
    const marker = document.getElementById('_richimg_marker');
    let insertedSpan;
    if (marker && target.contains(marker)) {
      marker.outerHTML = wrapHtml;
      insertedSpan = document.getElementById(imgId);
    } else {
      // Repli : marqueur introuvable (selection non capturee ou perdue) -> fin de contenu
      target.insertAdjacentHTML('beforeend', wrapHtml);
      insertedSpan = document.getElementById(imgId);
    }

    // Garantir un espace editable juste apres l'image (sinon, si elle est le seul contenu,
    // il n'y a plus nulle part ou cliquer pour continuer a ecrire, l'image n'etant pas editable).
    if (insertedSpan) {
      const next = insertedSpan.nextSibling;
      let brEl;
      if (!next || (next.nodeType === 1 && next.tagName !== 'BR')) {
        brEl = document.createElement('br');
        insertedSpan.parentNode.insertBefore(brEl, insertedSpan.nextSibling);
      }
      // Placer le curseur juste apres l'image, dans l'espace editable qui suit
      try {
        const sel = window.getSelection();
        const range = document.createRange();
        range.setStartAfter(brEl || insertedSpan);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
      } catch(e) {}
    }

    target.focus();
    _richSavedRange = null;
    _richInsertTargetId = null;
  } else {
    showToast('Erreur', 'Impossible de retrouver le champ de texte. Cliquez dans le message avant d\'insérer une image.', false);
  }
}

function ajusterImageInseree(imgId) {
  const wrap = document.getElementById(imgId);
  if (!wrap) return;
  const legendEl = wrap.querySelector('.img-legend');
  const align = wrap.dataset.align || 'centre';

  document.getElementById('postes-modal-title').textContent = 'Ajuster l\'image';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Position</label>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.8rem">';
  ['gauche','centre','droite'].forEach(pos => {
    const active = align === pos;
    html += '<button type="button" onclick="appliquerAlignementImage(\'' + imgId + '\',\'' + pos + '\')" style="flex:1;padding:.4rem;border:1px solid ' + (active?'#C9A84C':'#2a2010') + ';background:transparent;color:#c0b090;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em">' + pos.charAt(0).toUpperCase()+pos.slice(1) + '</button>';
  });
  html += '</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Légende (optionnel)</label>';
  html += '<input id="richimg-legend-edit" type="text" autocomplete="off" value="' + (legendEl?.textContent||'').replace(/"/g,'&quot;') + '" placeholder="Légende de l\'image" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.45rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button onclick="appliquerLegendeImage(\'' + imgId + '\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '<button onclick="supprimerImageInseree(\'' + imgId + '\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #6a2a20;background:transparent;color:#cc6a44;cursor:pointer">Supprimer l\'image</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerAlignementImage(imgId, pos) {
  const wrap = document.getElementById(imgId);
  if (!wrap) return;
  wrap.dataset.align = pos;
  if (pos === 'centre') {
    wrap.style.cssText = 'display:block;text-align:center;margin:.6rem 0;cursor:pointer';
  } else if (pos === 'gauche') {
    wrap.style.cssText = 'float:left;margin:0 1rem .5rem 0;max-width:45%;display:inline-block;cursor:pointer';
  } else {
    wrap.style.cssText = 'float:right;margin:0 0 .5rem 1rem;max-width:45%;display:inline-block;cursor:pointer';
  }
  ajusterImageInseree(imgId); // rafraichir le panneau pour montrer la nouvelle selection
}

function appliquerLegendeImage(imgId) {
  const wrap = document.getElementById(imgId);
  if (!wrap) return;
  const legendText = document.getElementById('richimg-legend-edit')?.value?.trim() || '';
  let legendEl = wrap.querySelector('.img-legend');
  if (legendText) {
    if (!legendEl) {
      legendEl = document.createElement('span');
      legendEl.className = 'img-legend';
      legendEl.style.cssText = 'display:block;text-align:center;font-size:.85rem;color:#8a8060;font-style:italic;margin-top:.2rem';
      wrap.appendChild(legendEl);
    }
    legendEl.textContent = legendText;
  } else if (legendEl) {
    legendEl.remove();
  }
  document.getElementById('modal-postes').classList.remove('open');
}

function supprimerImageInseree(imgId) {
  const wrap = document.getElementById(imgId);
  if (wrap) wrap.remove();
  document.getElementById('modal-postes').classList.remove('open');
}

function confirmerSuppressionPost(topicId, postId) {
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === topicId);
  if (!topic) return;
  const idx = topic.posts.findIndex((p, i) => (p.id || i) == postId);
  if (idx === -1) return;
  const estPremierPost = idx === 0;

  document.getElementById('postes-modal-title').textContent = 'Supprimer ce message ?';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">' +
    (estPremierPost
      ? "C'est le message d'origine du sujet — le supprimer supprimera l'intégralité du sujet, y compris toutes les réponses. Cette action est irréversible."
      : "Cette action est irréversible.") +
    '</div>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button onclick="executerSuppressionPost(\'' + topicId + '\',\'' + postId + '\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #6a2a20;background:transparent;color:#cc6a44;cursor:pointer">Supprimer</button>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function executerSuppressionPost(topicId, postId) {
  document.getElementById('modal-postes').classList.remove('open');
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === topicId);
  if (!topic) return;
  const idx = topic.posts.findIndex((p, i) => (p.id || i) == postId);
  if (idx === -1) return;
  const estPremierPost = idx === 0;
  const post = topic.posts[idx];

  if (typeof sbDelete === 'function' && post.id) {
    await sbDelete('forum_posts', `id=eq.${encodeURIComponent(post.id)}`).catch(() => {});
  }

  if (estPremierPost) {
    // Supprimer le sujet entier (Supabase + local)
    if (typeof sbDelete === 'function') {
      await sbDelete('forum_topics', `id=eq.${encodeURIComponent(topicId)}`).catch(() => {});
      await sbDelete('forum_posts', `topic_id=eq.${encodeURIComponent(topicId)}`).catch(() => {});
    }
    FORUM_TOPICS[currentForumId] = (FORUM_TOPICS[currentForumId]||[]).filter(t => t.id !== topicId);
    showToast('Sujet supprimé', '', true);
    backToList();
  } else {
    topic.posts.splice(idx, 1);
    topic.replies = Math.max(0, topic.posts.length - 1);
    if (typeof sbUpdate === 'function') {
      await sbUpdate('forum_topics', `id=eq.${encodeURIComponent(topicId)}`, { replies: topic.replies }).catch(() => {});
    }
    showToast('Message supprimé', '', true);
    document.getElementById('forum-main').innerHTML = renderForumContent();
  }
}

function richInsertStyle(styleName) {
  document.execCommand('insertHTML', false, STYLES_NARRATIFS[styleName]);
  toggleStylePanel();
}

function richInsertEmoji(emoji) {
  document.execCommand('insertText', false, emoji);
}

function richInsertSep(sep) {
  document.execCommand('insertHTML', false, `<div style="text-align:center;color:#8a8060;margin:.5rem 0">${sep}</div>`);
}

function toggleStylePanel() {
  const p = document.getElementById('style-panel');
  if (p) p.style.display = p.style.display === 'none' ? 'flex' : 'none';
}

function toggleEmojiPanel() {
  const p = document.getElementById('emoji-panel');
  if (p) p.style.display = p.style.display === 'none' ? 'block' : 'none';
}

function switchEmojiCat(cat) {
  const grid = document.getElementById('emoji-grid');
  if (!grid) return;
  document.querySelectorAll('.emoji-cat-btn').forEach(b => b.style.color = '#8a8060');
  document.querySelector(`[data-cat="${cat}"]`).style.color = '#C9A84C';
  grid.innerHTML = EMOJI_CATS[cat].map(e =>
    e.length > 4
      ? `<button onclick="richInsertSep('${e}')" style="font-size:.65rem;padding:.2rem .4rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer;white-space:nowrap">${e}</button>`
      : `<button onclick="richInsertEmoji('${e}')" style="font-size:1.1rem;padding:.1rem .2rem;border:none;background:transparent;cursor:pointer">${e}</button>`
  ).join('');
}

// =====================
// NOUVEAU TOPIC / RÉPONSE
// =====================
// Publication au nom d'une organisation (17 aout 2026) : seul le CHEF ACTUEL peut publier au nom
// de son organisation (doctrine validee -- pas les membres). orga.chef est le champ deja utilise
// partout ailleurs comme source de verite du poste de direction (quitterOrga, ouvrirMailOrga,
// resolution d'election), aucune convention nouvelle inventee. state.organisations sert
// uniquement a REMPLIR la liste deroulante (peut etre legerement perime) ; l'autorisation reelle
// est reverifiee fraichement au moment de publier, voir resoudreIdentitePublication ci-dessous.
function getMesOrganisations() {
  return (state.organisations || []).filter(o => o.chef === state.char?.name);
}

function renderPosterEnTantQue(fieldId) {
  const mesOrgas = getMesOrganisations();
  if (mesOrgas.length === 0) return '';
  let html = '<div class="forum-field"><label class="forum-field-label">Publier en tant que</label>';
  html += '<select id="' + fieldId + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
  html += '<option value="">' + escapeHtmlText(state.char?.name || 'Moi-même') + '</option>';
  mesOrgas.forEach(o => {
    html += '<option value="' + o.id + '">' + escapeHtmlText(o.nom) + (!o.visible ? ' (secrète)' : '') + '</option>';
  });
  html += '</select></div>';
  return html;
}

// Resout l'identite de publication (personnage ou organisation) pour un champ "Publier en tant
// que" donne -- point d'entree UNIQUE reutilise par les 4 pipelines de publication (ancien et
// nouveau compositeur, sujet et reponse), pour ne jamais dupliquer la verification.
//
// IMPORTANT (controle d'autorisation, doctrine validee) : ne fait JAMAIS confiance au seul choix
// de l'interface. Si une organisation est selectionnee, son chef est revérifié ICI, en lisant
// Supabase directement (sbGetOrganisationParId, jamais state.organisations qui peut etre perime
// depuis le chargement de la session) -- couvre explicitement le cas ou le joueur etait chef en
// ouvrant l'editeur mais a perdu le poste avant de cliquer Publier. Si le controle echoue,
// { refuse: true } est retourne et AUCUNE publication ne doit avoir lieu.
//
// Le logo est fige au moment de la publication (avatar personnalise de l'organisation en
// priorite -- orga.avatar, 17 aout 2026 -- puis repli sur l'icone du TYPE, TYPES_ORGANISATIONS,
// si l'organisation n'a defini aucun avatar) plutot que resolu a l'affichage via l'id de l'
// organisation : une organisation peut etre dissoute ou changer d'avatar plus tard, l'ancien
// message doit rester lisible avec son identite d'origine intacte (persistance historique
// demandee -- reutilise pour le forum ET la messagerie, meme fonction, aucune doctrine separee).
async function resoudreIdentitePublication(fieldId) {
  const char = state.char;
  const nomPersonnage = char?.name || 'Anonyme';
  const orgaId = document.getElementById(fieldId)?.value || '';

  if (!orgaId) {
    return { authorName: nomPersonnage, authorIsOrg: false, authorSecret: false, authorReal: nomPersonnage, orgaId: null, orgIcon: null };
  }

  if (typeof sbGetOrganisationParId !== 'function') return { refuse: true };
  const orgaFraiche = await sbGetOrganisationParId(orgaId).catch(() => null);
  if (!orgaFraiche || orgaFraiche.chef !== nomPersonnage) {
    return { refuse: true };
  }

  const icon = orgaFraiche.avatar || (typeof TYPES_ORGANISATIONS !== 'undefined' && TYPES_ORGANISATIONS[orgaFraiche.type]?.icon) || null;
  return {
    authorName: orgaFraiche.nom,
    authorIsOrg: true,
    authorSecret: !orgaFraiche.visible,
    authorReal: nomPersonnage,
    orgaId: orgaFraiche.id,
    orgIcon: icon
  };
}

function renderSignatureCheckbox(fieldId) {
  const char = state.char;
  if (!char?.signatureHtml && !char?.motto) return '';
  return '<label style="display:flex;align-items:center;gap:.4rem;font-size:.78rem;color:#8a8060;margin:.4rem 0"><input type="checkbox" id="' + fieldId + '" checked/> Inclure ma signature</label>';
}

function getSignatureHtml() {
  const char = state.char;
  if (char?.signatureHtml) return '<div style="margin-top:1rem;padding-top:.5rem;border-top:1px solid #2a2010;font-size:.9rem;color:#8a8060"><em>' + char.signatureHtml + '</em></div>';
  if (char?.motto) return '<div style="margin-top:1rem;padding-top:.5rem;border-top:1px solid #2a2010;font-size:.9rem;color:#8a8060"><em>— "' + char.motto + '"</em></div>';
  return '';
}

function renderNewTopicForm() {
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToList()"><i class="ti ti-arrow-left"></i> Retour</button>
      <div class="forum-title-main">Nouveau sujet</div>
    </div>
    <div class="forum-compose-form">
      <div class="forum-field">
        <label class="forum-field-label">Titre du sujet</label>
        <input class="forum-field-input" id="new-topic-title" type="text" placeholder="Intitulé du sujet..."/>
      </div>
      ${renderPosterEnTantQue('new-topic-auteur')}
      <div class="forum-field">
        <label class="forum-field-label">Message</label>
        ${renderRichEditor('new-topic-content')}
      </div>
      ${renderSignatureCheckbox('new-topic-signature')}
      <button class="forum-submit-btn" onclick="submitNewTopic()">
        <i class="ti ti-send"></i> Publier le sujet
      </button>
    </div>
  `;
}

function renderReplyForm() {
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === currentTopicId);
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToTopic()"><i class="ti ti-arrow-left"></i> Retour au sujet</button>
      <div class="forum-title-main">Répondre : ${escapeHtmlText(topic?.title||'')}</div>
    </div>
    <div class="forum-compose-form">
      ${renderPosterEnTantQue('reply-auteur')}
      <div class="forum-field">
        <label class="forum-field-label">Votre réponse</label>
        ${renderRichEditor('reply-content')}
      </div>
      ${renderSignatureCheckbox('reply-signature')}
      <button class="forum-submit-btn" onclick="submitReply()">
        <i class="ti ti-send"></i> Publier la réponse
      </button>
    </div>
  `;
}

function renderEditPostForm() {
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === editingTopicId);
  const post = topic?.posts.find(p => (p.id || '') === editingPostId) || topic?.posts[parseInt(editingPostId)] || {};
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToTopic()"><i class="ti ti-arrow-left"></i> Annuler</button>
      <div class="forum-title-main">Modifier le message</div>
    </div>
    <div class="forum-compose-form">
      <div class="forum-field">
        <label class="forum-field-label">Message</label>
        ${renderRichEditor('edit-post-content', post.content || '')}
      </div>
      <button class="forum-submit-btn" onclick="submitEditPost()">
        <i class="ti ti-check"></i> Enregistrer les modifications
      </button>
    </div>
  `;
}

// =====================
// ACTIONS FORUM
// =====================
function editPost(topicId, postId) {
  editingTopicId = topicId;
  editingPostId = postId;
  // Lot E3 : un post composé (content_layout non nul) se rouvre dans l'écran de composition
  // libre, pas dans l'éditeur classique -- seul cet écran sait reconstruire son canvas
  // vivant. rpCanvasInitComposeScreen() (forum-canvas.js) lit editingTopicId/editingPostId
  // posés ci-dessus pour décider s'il doit désérialiser un content_layout existant.
  const topic = (FORUM_TOPICS[currentForumId] || []).find(t => t.id === topicId);
  const post = topic ? (topic.posts.find(p => (p.id || '') === postId) || topic.posts[parseInt(postId)]) : null;
  if (post && post.content_layout) {
    forumView = 'compose-canvas';
    document.getElementById('forum-main').innerHTML = renderForumContent();
    if (typeof rpCanvasInitComposeScreen === 'function') rpCanvasInitComposeScreen();
    return;
  }
  forumView = 'edit-post';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

async function submitEditPost() {
  const contentEl = document.getElementById('edit-post-content');
  const content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!content) return;
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === editingTopicId);
  if (!topic) return;
  const post = topic.posts.find(p => (p.id||'') === editingPostId) || topic.posts[parseInt(editingPostId)];
  if (!post) return;

  const blocks = htmlToBlocks(content);

  // Persistance reelle en base -- UN SEUL appel Supabase. Avant ce correctif,
  // submitEditPost() ne persistait jamais rien : la modification n'existait qu'en memoire
  // locale et disparaissait a la moindre relecture depuis Supabase. Si la sauvegarde
  // echoue, on ne touche a rien localement et on previent explicitement le joueur, plutot
  // que de lui laisser croire que sa modification est enregistree.
  const result = (typeof sbEditPost === 'function' && post.id)
    ? await sbEditPost(post.id, content, blocks).catch(() => null)
    : null;

  if (!result) {
    showToast('Échec de la sauvegarde', 'La modification n\'a pas pu être enregistrée. Réessayez.', false);
    return;
  }

  post.content = content;
  post.blocks = blocks;
  post.edited = true;
  forumView = 'topic';
  currentTopicId = editingTopicId;
  document.getElementById('forum-main').innerHTML = renderForumContent();
  showToast('Modifié', 'Votre message a été mis à jour.', true);
}

function quotePost(postIndex) {
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === currentTopicId);
  const post = topic?.posts[postIndex];
  if (!post) return;
  const stripped = post.content.replace(/<[^>]+>/g, '').substring(0, 200);
  const quoteHtml = `<div style="margin:1.3rem 0"><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— · —</div><blockquote style="border-left:3px solid #C9A84C;padding:.7rem 1.2rem;margin:.5rem 0;color:#c0b090"><em>${stripped}...</em><br><small style="color:#6a5a30">— ${escapeHtmlText(post.author)}</small></blockquote><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— · —</div></div><p></p>`;
  forumView = 'reply';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  setTimeout(() => {
    const el = document.getElementById('reply-content');
    if (el) { el.innerHTML = quoteHtml; el.focus(); }
  }, 100);
}

// Ancien chemin de création (éditeur classique, avant la bascule vers la composition libre
// -- lot de finitions post-I) : plus appelé depuis aucun bouton de renderTopicList (un seul
// bouton désormais, "Nouveau sujet", branché sur showComposeCanvasForm). Conservé tel quel,
// non supprimé, car renderNewTopicForm()/submitNewTopic() restent le seul code qui sait créer
// un sujet au format plat (content/content_blocks) -- utile en repli si besoin, et
// renderEditPostForm()/submitEditPost() (édition d'un post existant, chemin séparé et
// toujours actif) partagent renderRichEditor() avec ce formulaire.
function showNewTopicForm() {
  if (currentForumId === 'presidence' && state.poste?.id !== 'president') {
    showToast('Accès restreint', 'Seul le Président peut ouvrir un sujet dans "La Présidence à la Nation".', false);
    return;
  }
  // Presse & Medias (correctif du 20 aout 2026) : meme garde que submitComposeCanvas() -- chemin
  // legacy non branche a un bouton actif, conserve par coherence.
  if (currentForumId === 'presse' && state.char?.career !== 'press') {
    showToast('Accès restreint', 'Seuls les journalistes peuvent ouvrir un sujet ici.', false);
    return;
  }
  forumView = 'new-topic'; document.getElementById('forum-main').innerHTML = renderForumContent();
}
function showReplyForm()    { forumView = 'reply';     document.getElementById('forum-main').innerHTML = renderForumContent(); }
function showComposeCanvasForm() {
  // Meme garde-fou que showNewTopicForm (double verification : le bouton est deja masque par
  // la meme condition, mais on protege aussi l'appel direct de la fonction).
  if (currentForumId === 'presidence' && state.poste?.id !== 'president') {
    showToast('Accès restreint', 'Seul le Président peut ouvrir un sujet dans "La Présidence à la Nation".', false);
    return;
  }
  // Onboarding forum (17 aout 2026) : toute (ré)ouverture du compositeur repart désarmée, voir
  // le commentaire sur la déclaration de onboardingComposeEnCours plus haut dans ce fichier.
  onboardingComposeEnCours = false;
  // Lot E3 : editingTopicId/editingPostId peuvent porter l'état d'une édition de post
  // composé précédente (editPost) -- une NOUVELLE composition doit toujours repartir d'un
  // canvas vide, jamais hériter silencieusement d'une session d'édition abandonnée sans
  // sauvegarde.
  editingTopicId = null;
  editingPostId = null;
  forumView = 'compose-canvas'; document.getElementById('forum-main').innerHTML = renderForumContent();
  if (typeof rpCanvasInitComposeScreen === 'function') rpCanvasInitComposeScreen();
}
// Réponse via le nouveau compositeur (correctif bugs bêta forum, remplace showReplyForm comme
// cible du bouton "Répondre") -- ne touche PAS currentTopicId, déjà posé par openTopic() sur le
// sujet réellement affiché : c'est cette valeur, conservée telle quelle, qui permet à
// renderComposeCanvasForm()/submitComposeCanvas() de reconnaître une réponse (currentTopicId
// non nul, editingPostId nul) plutôt qu'un nouveau sujet. Pas de garde-fou "Présidence" ici :
// répondre à un sujet n'a jamais été restreint (showReplyForm(), toujours actif pour quotePost,
// n'en avait aucun), seule la création d'un nouveau sujet l'est. editingTopicId/editingPostId
// remis à null, même précaution que showComposeCanvasForm(), pour ne jamais hériter d'une
// édition abandonnée. L'ancien pipeline (renderReplyForm/submitReply) reste intact, encore
// utilisé par quotePost().
function showComposeCanvasReply() {
  editingTopicId = null;
  editingPostId = null;
  forumView = 'compose-canvas'; document.getElementById('forum-main').innerHTML = renderForumContent();
  if (typeof rpCanvasInitComposeScreen === 'function') rpCanvasInitComposeScreen();
}
function backToList()       { forumView = 'list'; currentTopicId = null; onboardingComposeEnCours = false; document.getElementById('forum-main').innerHTML = renderForumContent(); }
function backToTopic()      { forumView = 'topic'; document.getElementById('forum-main').innerHTML = renderForumContent(); }

function openTopic(topicId) {
  currentTopicId = topicId;
  forumView = 'topic';
  // Afficher d'abord les posts locaux
  document.getElementById('forum-main').innerHTML = renderForumContent();
  // Charger les avatars des auteurs (cache partagé avec la presence en piece)
  if (typeof rafraichirCachePhotosJoueurs === 'function') {
    rafraichirCachePhotosJoueurs().then(() => {
      document.getElementById('forum-main').innerHTML = renderForumContent();
    }).catch(() => {});
  }
  // Puis charger depuis Supabase
  loadForumPostsFromSB(topicId).then(() => {
    if (typeof sbIncrementViews === 'function') sbIncrementViews(topicId);
    document.getElementById('forum-main').innerHTML = renderForumContent();
  }).catch(() => {});
}

// =====================
// SECURITE : nettoyage du HTML genere par l'editeur riche avant sauvegarde/affichage
// =====================
// DETAILS/SUMMARY ajoutés au lot E1 : nécessaires pour que les spoilers du canvas (lot D6,
// extension Tiptap Details/DetailsSummary/DetailsContent) survivent à la sanitisation --
// sans eux, un spoiler serait entièrement déplié en texte normal (la balise interdite est
// dépliée, pas supprimée, voir cleanNode ci-dessous). HTML sémantique natif, aucun style ni
// script requis pour le repli/dépli en lecture (déjà vérifié en F0.5).
const RICH_ALLOWED_TAGS = new Set(['P','BR','B','I','U','STRONG','EM','H2','H3','BLOCKQUOTE','DIV','SPAN','IMG','HR','UL','OL','LI','A','DETAILS','SUMMARY']);
// font-family ajouté au lot E1 : nécessaire pour que les polices bornées du canvas (lot D4)
// survivent à la sanitisation -- font-size y figurait déjà.
const RICH_ALLOWED_STYLE_PROPS = new Set([
  'color','background-color','text-align','font-style','font-weight','text-decoration','float','clear',
  'margin','margin-left','margin-right','margin-top','margin-bottom','max-width','max-height',
  'width','height','display','border-left','border','border-top','border-radius','object-fit',
  'vertical-align','padding','grid-template-columns','gap',
  'text-transform','letter-spacing','font-size','font-family','line-height','overflow'
]);

function sanitizeRichStyle(styleStr) {
  return (styleStr || '').split(';').map(r => r.trim()).filter(Boolean).filter(rule => {
    const parts = rule.split(':');
    const prop = parts[0]?.trim().toLowerCase();
    const val = parts.slice(1).join(':').trim().toLowerCase();
    if (!RICH_ALLOWED_STYLE_PROPS.has(prop)) return false;
    if (val.includes('expression(') || val.includes('javascript:') || val.includes('url(')) return false;
    return true;
  }).join(';');
}

// =====================
// SYSTEME DE BLOCS (fondations)
// Un post devient une liste de blocs typés : paragraph, image, quote, separator.
// Pour l'instant, on continue d'afficher via le HTML existant (content) ; les blocs
// (content_blocks) sont calcules et sauvegardes en parallele pour preparer la suite
// (edition/reorganisation par blocs), sans rien casser de ce qui fonctionne deja.
// =====================

function htmlToBlocks(html) {
  const tmp = document.createElement('div');
  tmp.innerHTML = html || '';
  const blocks = [];
  let currentParagraphHtml = '';

  function flushParagraph() {
    const trimmed = currentParagraphHtml.trim();
    if (trimmed) blocks.push({ type: 'paragraph', html: trimmed });
    currentParagraphHtml = '';
  }

  Array.from(tmp.childNodes).forEach(node => {
    if (node.nodeType === 3) { // texte brut directement au premier niveau
      currentParagraphHtml += node.textContent;
      return;
    }
    if (node.nodeType !== 1) return;
    const tag = node.tagName;

    if (tag === 'HR') {
      flushParagraph();
      blocks.push({ type: 'separator' });
    } else if (tag === 'BLOCKQUOTE') {
      flushParagraph();
      blocks.push({ type: 'quote', html: node.innerHTML.trim() });
    } else if (tag === 'IMG') {
      flushParagraph();
      blocks.push({ type: 'image', url: node.getAttribute('src') || '', align: 'centre', legend: '' });
    } else if (tag === 'SPAN' && node.querySelector('img')) {
      // Image inseree via le nouveau systeme (span avec data-align, cliquable pour ajuster —
      // voir confirmerRichInsertImage/appliquerAlignementImage)
      flushParagraph();
      const img = node.querySelector('img');
      const legendEl = node.querySelector('.img-legend');
      blocks.push({
        type: 'image',
        url: img?.getAttribute('src') || '',
        align: node.dataset?.align || (node.style.float === 'left' ? 'gauche' : node.style.float === 'right' ? 'droite' : 'centre'),
        legend: legendEl ? legendEl.textContent.trim() : ''
      });
    } else if (tag === 'DIV' && node.querySelector('img')) {
      // Image centree (ancien format, ou bloc dedie)
      flushParagraph();
      const img = node.querySelector('img');
      const legendEl = node.querySelector('span');
      blocks.push({
        type: 'image',
        url: img?.getAttribute('src') || '',
        align: 'centre',
        legend: legendEl ? legendEl.textContent.trim() : ''
      });
    } else if (tag === 'P' || tag === 'DIV') {
      // Bloc paragraphe (cree via double Entree, ou paragraphe deja existant)
      flushParagraph();
      const inner = node.innerHTML.trim();
      if (inner && inner !== '<br>') blocks.push({ type: 'paragraph', html: inner });
    } else {
      // Elements en ligne (b, i, span de couleur, etc.) restent dans le paragraphe en cours
      currentParagraphHtml += node.outerHTML;
    }
  });
  flushParagraph();

  return blocks;
}

function renderBlocks(blocks) {
  if (!Array.isArray(blocks) || blocks.length === 0) return '';
  return blocks.map(b => {
    if (b.type === 'paragraph') {
      return '<p style="margin:0 0 .8em;clear:both">' + b.html + '</p>';
    }
    if (b.type === 'quote') {
      return '<div style="margin:1.3rem 0;clear:both"><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— &middot; —</div><blockquote style="border-left:3px solid #C9A84C;padding:.7rem 1.2rem;margin:.5rem 0;color:#c0b090"><em>' + b.html + '</em></blockquote><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— &middot; —</div></div>';
    }
    if (b.type === 'separator') {
      return '<hr style="border:none;border-top:1px solid #3a2a10;margin:1rem 0;clear:both"/>';
    }
    if (b.type === 'image') {
      const legendHtml = b.legend ? '<span style="display:block;text-align:center;font-size:.85rem;color:#8a8060;font-style:italic;margin-top:.2rem">' + b.legend + '</span>' : '';
      if (b.align === 'centre') {
        return '<div style="text-align:center;margin:.5rem 0;clear:both"><img src="' + b.url + '" style="display:inline-block;max-width:100%"/>' + legendHtml + '</div>';
      }
      const floatStyle = b.align === 'gauche' ? 'float:left;margin:0 1rem .5rem 0' : 'float:right;margin:0 0 .5rem 1rem';
      return '<span style="' + floatStyle + ';max-width:45%;display:inline-block"><img src="' + b.url + '" style="width:100%;display:block"/>' + legendHtml + '</span>';
    }
    return '';
  }).join('');
}

// Échappement texte brut (distinct de sanitizeRichHtml, qui autorise du balisage riche) --
// pour les champs qui ne sont JAMAIS censés contenir de HTML (sujet de mail, destinataire/
// expéditeur : simples <input type="text">, jamais de formatage). Un <input> ne peut de toute
// façon jamais contenir de vraies balises HTML dans sa valeur -- seulement la chaîne littérale
// telle que tapée -- donc le risque n'existe qu'au moment où cette chaîne est réinjectée telle
// quelle dans un template HTML sans passer par ici (lot H2, faille XSS pipeline mail).
function escapeHtmlText(str) {
  return String(str == null ? '' : str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function sanitizeRichHtml(html) {
  const tmp = document.createElement('div');
  tmp.innerHTML = html || '';

  // Normaliser <font color="..."> (legacy execCommand sans styleWithCSS) en <span style="color:...">
  tmp.querySelectorAll('font').forEach(f => {
    const span = document.createElement('span');
    const color = f.getAttribute('color');
    if (color) span.setAttribute('style', 'color:' + color);
    while (f.firstChild) span.appendChild(f.firstChild);
    f.replaceWith(span);
  });

  function cleanNode(node) {
    Array.from(node.childNodes).forEach(child => {
      if (child.nodeType === 1) { // Element
        const tag = child.tagName;
        if (!RICH_ALLOWED_TAGS.has(tag)) {
          // Deplier : on garde le contenu interne, on retire juste la balise interdite
          while (child.firstChild) node.insertBefore(child.firstChild, child);
          node.removeChild(child);
          return;
        }
        Array.from(child.attributes).forEach(attr => {
          const name = attr.name.toLowerCase();
          if (name === 'style') {
            child.setAttribute('style', sanitizeRichStyle(attr.value));
          } else if (name === 'src' && tag === 'IMG') {
            if (!/^https?:\/\//i.test(attr.value.trim())) child.removeAttribute('src');
          } else if (name === 'href' && tag === 'A') {
            if (!/^https?:\/\//i.test(attr.value.trim())) child.removeAttribute('href');
          } else if ((name === 'target' || name === 'rel') && tag === 'A') {
            // Conservés tels quels (lot E1) : valeurs fixes posées par l'extension Tiptap
            // Link (lot D5, HTMLAttributes:{target:'_blank',rel:'noopener noreferrer nofollow'}),
            // jamais une saisie utilisateur libre -- les retirer romprait l'ouverture en
            // nouvel onglet et les protections rel sans aucun bénéfice de sécurité.
          } else {
            child.removeAttribute(attr.name);
          }
        });
        cleanNode(child);
      } else if (child.nodeType !== 3) { // pas du texte -> commentaires, etc.
        node.removeChild(child);
      }
    });
  }

  cleanNode(tmp);
  return tmp.innerHTML;
}

function parseGameTime(str) {
  if (!str) return 0;
  // Nouveau format : "DD/MM/YYYY · HHhMM"
  const mDate = /(\d{2})\/(\d{2})\/(\d{4})\s*·\s*(\d{1,2})h(\d{2})?/.exec(str);
  if (mDate) {
    const [, dd, mm, yyyy, hh, mn] = mDate;
    return new Date(parseInt(yyyy), parseInt(mm)-1, parseInt(dd), parseInt(hh), parseInt(mn||0)).getTime();
  }
  // Ancien format "Jour X · HHhMM" — retrocompatibilite avec les messages deja postes
  const mJour = /Jour\s*(\d+)\s*·\s*(\d{1,2})h(\d{2})?/.exec(str);
  if (mJour) return parseInt(mJour[1]||0) * 1440 + parseInt(mJour[2]||0) * 60 + parseInt(mJour[3]||0);
  return 0;
}

async function submitNewTopic() {
  if (currentForumId === 'presidence' && state.poste?.id !== 'president') {
    showToast('Accès restreint', 'Seul le Président peut ouvrir un sujet ici.', false);
    return;
  }
  // Presse & Medias (correctif du 20 aout 2026) : meme garde que submitComposeCanvas() -- chemin
  // legacy non branche a un bouton actif, conserve par coherence.
  if (currentForumId === 'presse' && state.char?.career !== 'press') {
    showToast('Accès restreint', 'Seuls les journalistes peuvent ouvrir un sujet ici.', false);
    return;
  }
  const titleEl = document.getElementById('new-topic-title');
  const contentEl = document.getElementById('new-topic-content');
  const title = titleEl?.value?.trim();
  let content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!title || !content) { showToast('Champs requis','Remplissez le titre et le message.',false); return; }
  if (document.getElementById('new-topic-signature')?.checked) {
    content = sanitizeRichHtml(content + getSignatureHtml());
  }
  const identite = await resoudreIdentitePublication('new-topic-auteur');
  if (identite.refuse) {
    showToast('Publication refusée', "Vous n'êtes plus le/la responsable de cette organisation.", false);
    return;
  }
  const { authorName, authorIsOrg, authorSecret, authorReal, orgaId: idOrga, orgIcon } = identite;

  const time = formatDateHeureJeu();
  const blocks = htmlToBlocks(content);

  // Supabase
  let topicId;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic(currentForumId, title, authorName, state.country, time, authorIsOrg, authorSecret, authorReal, idOrga, orgIcon);
    if (topicId) await sbCreatePost(topicId, authorName, content, time, authorIsOrg, authorSecret, blocks, null, authorReal, idOrga, orgIcon);
  }

  // Local aussi pour affichage immédiat
  const newTopic = {
    id: topicId || 'topic-' + Date.now(), title, author: authorName,
    authorCountry: state.country, authorIsOrg, authorSecret, authorReal, authorOrgId: idOrga, authorOrgIcon: orgIcon,
    time, views: 1, replies: 0,
    lastPostAuthor: authorName, lastPostTime: time,
    posts: [{ id:'p-'+Date.now(), author: authorName, authorCountry: state.country, authorIsOrg, authorSecret, authorReal, authorOrgId: idOrga, authorOrgIcon: orgIcon, time, content, blocks }]
  };
  if (!FORUM_TOPICS[currentForumId]) FORUM_TOPICS[currentForumId] = [];
  FORUM_TOPICS[currentForumId].unshift(newTopic);
  state.pop = Math.min(100, (state.pop||0) + 2);
  updateUI();
  forumView = 'list';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez créé le sujet "${escapeHtmlText(title)}" sur le forum.`, 'event-info');
  // Voyant (17 aout 2026) : sa propre publication ne doit pas s'afficher comme "nouvelle" a
  // ses propres yeux au prochain controle.
  if (typeof marquerForumVisite === 'function') marquerForumVisite();
}

async function submitReply() {
  const contentEl = document.getElementById('reply-content');
  let content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!content) { showToast('Message vide','Écrivez votre réponse avant de publier.',false); return; }
  if (document.getElementById('reply-signature')?.checked) {
    content = sanitizeRichHtml(content + getSignatureHtml());
  }
  const time = formatDateHeureJeu();
  const blocks = htmlToBlocks(content);
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === currentTopicId);
  if (!topic) return;

  // Correctif bug beta forum (16 aout 2026) : sbCreatePost() etait appelee sans jamais verifier
  // son resultat -- un echec Supabase (ex. topic_id sans ligne reelle correspondante) etait
  // totalement silencieux, le message apparaissait quand meme localement comme si la
  // publication avait reussi. Meme garde-fou et meme comportement que submitReplyComposed().
  // Doctrine intacte (17 aout 2026) : la resolution d'identite (avec sa verification fraiche du
  // chef d'organisation) est faite ICI, apres ce garde-fou de connexion mais avant tout appel
  // reseau d'ecriture -- aucun etat local modifie avant le succes reel de sbCreatePost().
  if (typeof sbCreatePost !== 'function') {
    showToast('Connexion indisponible', 'Impossible de publier sans connexion à la base.', false);
    return;
  }
  const identite = await resoudreIdentitePublication('reply-auteur');
  if (identite.refuse) {
    showToast('Publication refusée', "Vous n'êtes plus le/la responsable de cette organisation.", false);
    return;
  }
  const { authorName, authorIsOrg, authorSecret, authorReal, orgaId: idOrga, orgIcon } = identite;
  const postId = await sbCreatePost(topic.id, authorName, content, time, authorIsOrg, authorSecret, blocks, null, authorReal, idOrga, orgIcon).catch(() => null);
  if (!postId) {
    showToast('Échec de la publication', "La réponse n'a pas pu être enregistrée. Réessayez.", false);
    return;
  }

  // Local
  topic.posts.push({ id: postId, author: authorName, authorCountry: state.country, authorIsOrg, authorSecret, authorReal, authorOrgId: idOrga, authorOrgIcon: orgIcon, time, content, blocks });
  topic.replies = topic.posts.length - 1;
  topic.lastPostAuthor = authorName;
  topic.lastPostTime = time;
  state.pop = Math.min(100, (state.pop||0) + 1);
  updateUI();
  forumView = 'topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez répondu au sujet "${escapeHtmlText(topic.title)}".`, 'event-info');
  if (typeof marquerForumVisite === 'function') marquerForumVisite();
}

// Publication réelle d'un sujet composé (Lot E2) — même geste que submitNewTopic (sbCreateTopic
// puis sbCreatePost pour le premier message), avec en plus la sérialisation du canvas vivant
// (rpCanvasSerializeCompose, lot E1) et le fallback à plat (rpCanvasBuildFallbackContent, lot
// E1) passés à sbCreatePost. Volontairement minimal par rapport à submitNewTopic : pas de
// "poster en tant que" (organisation) ni de case signature -- non prévus par le plan E2,
// consignés comme finition ultérieure plutôt qu'ajoutés silencieusement.
//
// Rien de partiellement publié en cas d'échec réseau : si sbCreateTopic réussit mais que
// sbCreatePost échoue (le sujet resterait alors sans aucun message), le sujet orphelin est
// immédiatement supprimé via sbDelete -- exploitable de façon fiable parce que sbCreatePost
// a été corrigé dans ce même lot pour renvoyer null en cas d'échec réel (voir supabase.js).
// La défaillance symétrique (sbCreateTopic lui-même échoue silencieusement en interne mais
// renvoie tout de même un id) est un défaut préexistant, partagé avec submitNewTopic, hors
// périmètre de ce lot -- consigné, pas corrigé ici.
// Édition d'un post composé existant (Lot E3) — branche dédiée de submitComposeCanvas(),
// déclenchée quand editingTopicId/editingPostId sont posés (editPost, sur un post dont
// content_layout est non nul). Volontairement séparée du chemin de création juste en
// dessous plutôt que fusionnée dans un long if/else : les deux ne partagent ni le titre, ni
// sbCreateTopic/sbCreateTopic-rollback, ni la mise à jour locale -- seules la sérialisation
// (rpCanvasSerializeCompose) et la construction du fallback (rpCanvasBuildFallbackContent)
// sont réellement communes, et le restent (mêmes appels, aucune logique dupliquée). Si la
// sauvegarde échoue, on ne touche à rien localement (même principe que submitEditPost pour
// l'éditeur classique) plutôt que de laisser croire à une modification enregistrée.
async function submitEditComposedPost(layout, content) {
  const topic = (FORUM_TOPICS[currentForumId] || []).find(t => t.id === editingTopicId);
  const post = topic ? (topic.posts.find(p => (p.id || '') === editingPostId) || topic.posts[parseInt(editingPostId)]) : null;
  if (!topic || !post) { showToast('Message introuvable', "Impossible de retrouver le message à modifier.", false); return; }

  if (typeof sbEditPost !== 'function') {
    showToast('Connexion indisponible', 'Impossible d\'enregistrer sans connexion à la base.', false);
    return;
  }
  const result = await sbEditPost(post.id, content, [], layout).catch(() => null);
  if (!result) {
    showToast('Échec de la sauvegarde', "Les modifications n'ont pas pu être enregistrées. Réessayez.", false);
    return;
  }

  post.content = content;
  post.blocks = [];
  post.content_layout = layout;
  post.edited = true;
  currentTopicId = editingTopicId;
  editingTopicId = null;
  editingPostId = null;
  forumView = 'topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  showToast('Modifié', 'Votre message a été mis à jour.', true);
}

// Réponse composée dans un sujet existant (correctif bugs bêta forum) — branche dédiée de
// submitComposeCanvas() au même titre que submitEditComposedPost() juste au-dessus : même
// contenu sauvegardé qu'un post composé normal (content_layout + fallback content), mais poste
// dans currentTopicId (sbCreatePost seul, jamais sbCreateTopic) et reprend le bookkeeping local
// de submitReply() (replies/lastPostAuthor/lastPostTime/pop/journal) plutôt que celui de la
// création de sujet. Rien de local n'est modifié si la sauvegarde échoue, même principe que
// submitEditComposedPost et submitComposeCanvas (branche nouveau sujet).
async function submitReplyComposed(layout, content) {
  const topic = (FORUM_TOPICS[currentForumId] || []).find(t => t.id === currentTopicId);
  if (!topic) { showToast('Sujet introuvable', 'Impossible de retrouver le sujet.', false); return; }

  if (typeof sbCreatePost !== 'function') {
    showToast('Connexion indisponible', 'Impossible de publier sans connexion à la base.', false);
    return;
  }
  // Identite de publication (17 aout 2026, publication au nom d'une organisation) : meme
  // resolveur/meme verification fraiche que submitReply() -- doctrine de garde-fou du correctif
  // precedent intacte, rien de local touche avant le succes reel de sbCreatePost().
  const identite = await resoudreIdentitePublication('compose-canvas-auteur');
  if (identite.refuse) {
    showToast('Publication refusée', "Vous n'êtes plus le/la responsable de cette organisation.", false);
    return;
  }
  const { authorName, authorIsOrg, authorSecret, authorReal, orgaId: idOrga, orgIcon } = identite;
  const time = formatDateHeureJeu();

  const postId = await sbCreatePost(topic.id, authorName, content, time, authorIsOrg, authorSecret, [], layout, authorReal, idOrga, orgIcon).catch(() => null);
  if (!postId) {
    showToast('Échec de la publication', "La réponse n'a pas pu être enregistrée. Réessayez.", false);
    return;
  }

  topic.posts.push({ id: postId, author: authorName, authorCountry: state.country, authorIsOrg, authorSecret, authorReal, authorOrgId: idOrga, authorOrgIcon: orgIcon, time, content, blocks: [], content_layout: layout });
  topic.replies = topic.posts.length - 1;
  topic.lastPostAuthor = authorName;
  topic.lastPostTime = time;
  state.pop = Math.min(100, (state.pop || 0) + 1);
  updateUI();
  forumView = 'topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez répondu au sujet "${escapeHtmlText(topic.title)}".`, 'event-info');
  if (typeof marquerForumVisite === 'function') marquerForumVisite();
}

async function submitComposeCanvas() {
  const enEdition = editingTopicId != null && editingPostId != null;
  // Réponse dans le sujet courant (correctif bugs bêta forum) : distingué sans nouvelle
  // variable globale, en réutilisant currentTopicId/editingPostId déjà maintenus par
  // openTopic()/showComposeCanvasReply() -- currentTopicId n'est jamais posé quand on arrive
  // par "Nouveau sujet" (bouton visible seulement depuis la liste, où currentTopicId est null).
  const enReponse = !enEdition && currentTopicId != null;

  // Même garde-fou que submitNewTopic, mais seulement pour la création d'un nouveau sujet :
  // répondre à un sujet existant ou modifier son propre message n'a jamais été restreint à la
  // Présidence (ni submitReply ni submitEditPost ne l'étaient).
  if (!enEdition && !enReponse && currentForumId === 'presidence' && state.poste?.id !== 'president') {
    showToast('Accès restreint', 'Seul le Président peut ouvrir un sujet ici.', false);
    return;
  }
  // Presse & Medias (correctif du 20 aout 2026) : lecture desormais publique (canAccessForum),
  // mais la creation d'un nouveau sujet reste reservee aux journalistes -- meme carriere deja
  // existante ('press', CAREERS/data.js) que celle utilisee pour la redaction/les articles de La
  // Tribune, aucune nouvelle notion inventee. Meme exception "reponse jamais restreinte" que
  // presidence ci-dessus.
  if (!enEdition && !enReponse && currentForumId === 'presse' && state.char?.career !== 'press') {
    showToast('Accès restreint', 'Seuls les journalistes peuvent ouvrir un sujet ici.', false);
    return;
  }

  let title = null;
  if (!enEdition && !enReponse) {
    const titleEl = document.getElementById('compose-canvas-title');
    title = titleEl?.value?.trim();
    if (!title) { showToast('Titre requis', 'Donnez un titre à votre sujet avant de publier.', false); return; }
  }

  if (typeof rpCanvasSerializeCompose !== 'function') return;
  const layout = rpCanvasSerializeCompose();
  if (!layout.elements || layout.elements.length === 0) {
    showToast('Composition vide',
      enEdition ? "Ajoutez au moins une zone de texte ou une image avant d'enregistrer."
        : (enReponse ? "Ajoutez au moins une zone de texte ou une image avant de publier votre réponse." : 'Ajoutez au moins une zone de texte ou une image avant de publier.'), false);
    return;
  }
  const content = typeof rpCanvasBuildFallbackContent === 'function' ? rpCanvasBuildFallbackContent(layout) : '';

  if (enEdition) {
    await submitEditComposedPost(layout, content);
    return;
  }
  if (enReponse) {
    await submitReplyComposed(layout, content);
    return;
  }

  const time = formatDateHeureJeu();

  if (typeof sbCreateTopic !== 'function' || typeof sbCreatePost !== 'function') {
    showToast('Connexion indisponible', 'Impossible de publier sans connexion à la base.', false);
    return;
  }
  // Identite de publication (17 aout 2026, publication au nom d'une organisation) : meme
  // resolveur/meme verification fraiche que les autres pipelines -- effectuee avant tout appel
  // d'ecriture, aucun etat local touche si elle est refusee.
  const identite = await resoudreIdentitePublication('compose-canvas-auteur');
  if (identite.refuse) {
    showToast('Publication refusée', "Vous n'êtes plus le/la responsable de cette organisation.", false);
    return;
  }
  const { authorName, authorIsOrg, authorSecret, authorReal, orgaId: idOrga, orgIcon } = identite;
  // Onboarding forum (17 aout 2026) : capturé avant tout appel d'écriture, jamais réévalué
  // après (le flag est mono-thread, rien d'autre ne le modifie pendant cet appel async).
  const eraOnboarding = onboardingComposeEnCours;

  const topicId = await sbCreateTopic(currentForumId, title, authorName, state.country, time, authorIsOrg, authorSecret, authorReal, idOrga, orgIcon).catch(() => null);
  if (!topicId) {
    showToast('Échec de la publication', "Le sujet n'a pas pu être créé. Réessayez.", false);
    return;
  }

  const postId = await sbCreatePost(topicId, authorName, content, time, authorIsOrg, authorSecret, [], layout, authorReal, idOrga, orgIcon).catch(() => null);
  if (!postId) {
    if (typeof sbDelete === 'function') await sbDelete('forum_topics', `id=eq.${encodeURIComponent(topicId)}`).catch(() => {});
    showToast('Échec de la publication', "Le message n'a pas pu être enregistré. Rien n'a été publié.", false);
    return;
  }

  // Local aussi pour affichage immédiat, même geste que submitNewTopic.
  const newTopic = {
    id: topicId, title, author: authorName,
    authorCountry: state.country, authorIsOrg, authorSecret, authorReal, authorOrgId: idOrga, authorOrgIcon: orgIcon,
    time, views: 1, replies: 0,
    lastPostAuthor: authorName, lastPostTime: time,
    posts: [{ id: postId, author: authorName, authorCountry: state.country, authorIsOrg, authorSecret, authorReal, authorOrgId: idOrga, authorOrgIcon: orgIcon, time, content, blocks: [], content_layout: layout }]
  };
  if (!FORUM_TOPICS[currentForumId]) FORUM_TOPICS[currentForumId] = [];
  FORUM_TOPICS[currentForumId].unshift(newTopic);
  state.pop = Math.min(100, (state.pop || 0) + 2);
  updateUI();
  forumView = 'list';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez créé le sujet "${escapeHtmlText(title)}" sur le forum (composition libre).`, 'event-info');
  if (typeof marquerForumVisite === 'function') marquerForumVisite();
  showToast('Sujet publié', 'Votre sujet est en ligne.', true, true);
  // Onboarding forum (17 aout 2026) : validation UNIQUEMENT après succès réel Supabase confirmé
  // ci-dessus, ET compositeur réellement armé par l'onboarding, ET publication personnelle (pas
  // organisationnelle). Une publication organisationnelle pendant une session armée ne valide
  // rien mais ne désarme pas non plus le flag (le joueur reste libre de réessayer en personnel
  // dans la même session). Jamais basé sur le titre, le forum choisi ou le contenu.
  if (eraOnboarding && !authorIsOrg) {
    onboardingComposeEnCours = false;
    if (typeof queteAccueilMarquerPresentationPubliee === 'function') queteAccueilMarquerPresentationPubliee();
  }
}

// =====================
// MESSAGERIE
// =====================
function renderMailView() {
  if (mailView === 'inbox')   return renderMailInbox();
  if (mailView === 'compose') return renderMailCompose(mailDefaultTo);
  if (mailView === 'read')    return renderMailRead();
  // Portrait de Jodie Moitout (lot du 21 aout 2026) : deux vues supplementaires dans la meme
  // messagerie, memes fonctions de rendu que ci-dessus mais definies dans plateau-communication.js
  // (toute la logique Jodie y est regroupee) -- meme pattern de dispatch, rien de nouveau cote
  // architecture.
  if (mailView === 'jodie-interview' && typeof renderJodieInterviewForm === 'function') return renderJodieInterviewForm();
  if (mailView === 'jodie-preview' && typeof renderJodiePortraitPreview === 'function') return renderJodiePortraitPreview();
  return renderMailInbox();
}

function renderMailInbox() {
  const myName = state.char?.name || '';
  const allMails = getMyMails().sort((a,b) => b.id.localeCompare(a.id));
  const mails = allMails.filter(m => !m.archived);
  const archives = allMails.filter(m => m.archived);
  const received = mails.filter(m => m.to === myName);
  // m.fromReal (17 aout 2026) : un mail organisationnel a m.from = nom de l'organisation, pas
  // le personnage reel -- sans ce critere, l'expediteur reel ne verrait jamais son propre envoi
  // dans "Envoyes".
  const sent = mails.filter(m => m.from === myName || m.fromReal === myName);

  return `
    <div class="forum-header-bar">
      <div class="forum-title-main"><i class="ti ti-mail"></i> Boîte Mail</div>
      <button class="forum-new-btn" onclick="mailView='compose';document.getElementById('forum-main').innerHTML=renderForumContent()">
        <i class="ti ti-pencil-plus"></i> Nouveau mail
      </button>
    </div>
    <div style="margin-bottom:.8rem">
      <div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;padding:.4rem 0;border-bottom:1px solid #2a2010;margin-bottom:.4rem">
        MESSAGES REÇUS (${received.length})
      </div>
      ${received.length === 0
        ? `<div class="forum-empty">Aucun message reçu.</div>`
        : received.map(m => `
          <div onclick="readMail('${m.id}')" style="padding:.6rem .8rem;border-bottom:1px solid #1a1810;cursor:pointer;background:${m.read?'transparent':'rgba(201,168,76,0.05)'}">
            <div style="display:flex;justify-content:space-between;align-items:center">
              <div style="font-size:.82rem;color:${m.read?'#8a8060':'#f0ead6'};font-weight:${m.read?'normal':'bold'}">
                ${!m.read?'🔵 ':''}${escapeHtmlText(m.subject)}
              </div>
              <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(m.time)}</div>
            </div>
            <div style="font-size:.72rem;color:#6a5a30">De : ${escapeHtmlText(m.from)}${m.fromIsOrg ? ' <i class="ti ti-shield" style="font-size:.65rem;color:#8a8060" title="Organisation"></i>' : ''}</div>
          </div>`).join('')}
    </div>
    <div>
      <div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;padding:.4rem 0;border-bottom:1px solid #2a2010;margin-bottom:.4rem">
        MESSAGES ENVOYÉS (${sent.length})
      </div>
      ${sent.length === 0
        ? `<div class="forum-empty">Aucun message envoyé.</div>`
        : sent.map(m => `
          <div onclick="readMail('${m.id}')" style="padding:.6rem .8rem;border-bottom:1px solid #1a1810;cursor:pointer">
            <div style="display:flex;justify-content:space-between">
              <div style="font-size:.82rem;color:#8a8060">${m.fromIsOrg ? '<i class="ti ti-shield" style="font-size:.65rem" title="Envoyé en tant qu\'organisation"></i> ' : ''}${escapeHtmlText(m.subject)}</div>
              <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(m.time)}</div>
            </div>
            <div style="font-size:.72rem;color:#6a5a30">À : ${escapeHtmlText(m.to)}</div>
          </div>`).join('')}
    </div>
    ${archives.length > 0 ? `
    <div style="margin-top:.8rem">
      <div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#6a5a30;padding:.4rem 0;border-bottom:1px solid #2a2010;margin-bottom:.4rem">
        <i class="ti ti-archive"></i> ARCHIVES (${archives.length}) — conservées indéfiniment
      </div>
      ${archives.map(m => `
        <div onclick="readMail('${m.id}')" style="padding:.6rem .8rem;border-bottom:1px solid #1a1810;cursor:pointer;opacity:.75">
          <div style="display:flex;justify-content:space-between">
            <div style="font-size:.82rem;color:#8a8060">${m.fromIsOrg ? '<i class="ti ti-shield" style="font-size:.65rem" title="Organisation"></i> ' : ''}${escapeHtmlText(m.subject)}</div>
            <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(m.time)}</div>
          </div>
          <div style="font-size:.72rem;color:#6a5a30">${(m.from === myName || m.fromReal === myName) ? 'À : ' + escapeHtmlText(m.to) : 'De : ' + escapeHtmlText(m.from)}</div>
        </div>`).join('')}
    </div>` : ''}
  `;
}

let currentMailId = null;
// =====================
// CHARGEMENT DEPUIS SUPABASE
// =====================
async function loadForumTopicsFromSB(forumId) {
  if (typeof sbLoadForumTopics !== 'function') return;
  try {
    const rows = await sbLoadForumTopics(forumId);
    if (!rows || rows.length === 0) return;
    // Fusionner avec les topics locaux existants
    if (!FORUM_TOPICS[forumId]) FORUM_TOPICS[forumId] = [];
    rows.forEach(row => {
      const existing = FORUM_TOPICS[forumId].find(t => t.id === row.id);
      if (!existing) {
        FORUM_TOPICS[forumId].unshift({
          id: row.id, title: row.title, author: row.author,
          time: row.time, views: row.views, replies: row.replies,
          lastPostAuthor: row.last_post_author || row.author,
          lastPostTime: row.last_post_time || row.time,
          authorCountry: row.country, authorIsOrg: row.author_is_org, authorSecret: row.author_secret,
          authorReal: row.author_real, authorOrgId: row.author_org_id, authorOrgIcon: row.author_org_icon,
          posts: []
        });
      } else {
        existing.views = row.views;
        existing.replies = row.replies;
        existing.lastPostAuthor = row.last_post_author || existing.lastPostAuthor || existing.author;
        existing.lastPostTime = row.last_post_time || existing.lastPostTime || existing.time;
      }
    });
    // Trier par activite la plus recente (dernier post), pas par date de creation
    FORUM_TOPICS[forumId].sort((a, b) => parseGameTime(b.lastPostTime || b.time) - parseGameTime(a.lastPostTime || a.time));
  } catch(e) { console.warn('loadForumTopicsFromSB error', e); }
}

async function loadForumPostsFromSB(topicId) {
  if (typeof sbLoadForumPosts !== 'function') return;
  try {
    const rows = await sbLoadForumPosts(topicId);
    if (!rows || rows.length === 0) return;
    const topic = Object.values(FORUM_TOPICS).flat().find(t => t.id === topicId);
    if (!topic) return;
    // Remplacer les posts locaux par ceux de Supabase
    topic.posts = rows.map(r => ({
      id: r.id, author: r.author, content: r.content,
      time: r.time, edited: r.edited, blocks: r.content_blocks || null,
      content_layout: r.content_layout || null,
      authorCountry: topic.authorCountry || topic.country, authorIsOrg: r.author_is_org, authorSecret: r.author_secret,
      authorReal: r.author_real, authorOrgId: r.author_org_id, authorOrgIcon: r.author_org_icon
    }));
    topic.replies = Math.max(0, topic.posts.length - 1);
  } catch(e) { console.warn('loadForumPostsFromSB error', e); }
}

async function loadMailsFromSB() {
  if (typeof sbGetMailsFor !== 'function') return;
  const name = state.char?.name;
  if (!name) return;
  try {
    const rows = await sbGetMailsFor(name);
    if (!rows) return;
    // Fusionner avec localStorage
    const local = getMails();
    const localById = new Map(local.map(m => [m.id, m]));
    const sbIds = new Set(rows.map(r => r.id));
    const merged = [
      ...rows.map(r => {
        const dejaLuLocalement = localById.get(r.id)?.read || false;
        const estLu = r.read || dejaLuLocalement;
        // Si Supabase n'a pas encore le statut lu alors qu'on l'a localement, on retente la synchro
        if (dejaLuLocalement && !r.read && typeof sbMarkMailRead === 'function') {
          sbMarkMailRead(r.id).catch(() => {});
        }
        return { id: r.id, from: r.from_player, to: r.to_player,
          subject: r.subject, body: r.body, time: r.time, read: estLu, archived: r.archived || false,
          // Mapping explicite (17 aout 2026) : le meme oubli venait d'etre trouve et corrige sur
          // le forum (loadForumTopicsFromSB/loadForumPostsFromSB, colonnes jamais recopiees sur
          // les objets locaux) -- verifie ici des la premiere version, pas apres coup.
          fromIsOrg: !!r.from_org_id, fromReal: r.from_real, fromOrgId: r.from_org_id, fromOrgIcon: r.from_org_icon };
      }),
      ...local.filter(m => !sbIds.has(m.id))
    ];
    saveMails(merged);
  } catch(e) { console.warn('loadMailsFromSB error', e); }
}

function readMail(mailId) {
  currentMailId = mailId;
  markMailRead(mailId);
  mailView = 'read';
  // Correctif latence des voyants (21 aout 2026) : renderForumModal() (sidebar + panneau
  // principal), pas seulement renderForumContent() (panneau principal seul, comportement
  // precedent) -- le compteur "Boîte Mail X non lu(s)"/le point rouge de la barre laterale
  // (calcules a chaque appel de renderForumModal() depuis getMyMails(), voir plus haut dans ce
  // fichier) restaient sinon figes a leur valeur d'ouverture jusqu'a la fermeture/reouverture de
  // la fenetre. rafraichirVoyantMailLocal() synchronise en plus le voyant EXTERIEUR (#mail-badge,
  // hors de cette fenetre) -- les deux sans aucun appel reseau, purement locaux.
  renderForumModal();
  if (typeof rafraichirVoyantMailLocal === 'function') rafraichirVoyantMailLocal();
}

function renderMailRead() {
  const mail = getMails().find(m => m.id === currentMailId);
  if (!mail) return renderMailInbox();
  const myName = state.char?.name || '';
  const estPropositionJodie = mail.to === myName && mail.from === 'Jodie Moitout' &&
    mail.subject === (typeof JODIE_PORTRAIT_SUJET_PROPOSITION !== 'undefined' ? JODIE_PORTRAIT_SUJET_PROPOSITION : null);
  // Portrait de Jodie Moitout : l'etat (encore a decider / deja refuse / deja publie) est verifie
  // FRAIS depuis Supabase (jamais le simple cache local de getMails() ci-dessus, potentiellement
  // perime -- voir jodiePortraitADejaRefuse()/jodiePortraitDejaPublie(), plateau-communication.js)
  // -- rendu en differe (comme de nombreux autres ecrans de ce jeu : placeholder synchrone puis
  // contenu reel une fois la reponse arrivee) plutot que de rendre renderMailRead() elle-meme
  // asynchrone, ce qui aurait exige de convertir en cascade renderMailView()/renderForumContent()
  // et tous leurs appelants synchrones existants -- hors perimetre de ce correctif. Ce masquage
  // reste purement indicatif : la protection reelle contre une reprise est le controle refait par
  // le handler jodiePortraitOuvrirInterview() lui-meme, jamais ce seul affichage.
  if (estPropositionJodie && typeof jodiePortraitRafraichirEtatMail === 'function') {
    setTimeout(() => jodiePortraitRafraichirEtatMail(), 0);
  }
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="mailView='inbox';document.getElementById('forum-main').innerHTML=renderForumContent()">
        <i class="ti ti-arrow-left"></i> Retour
      </button>
      <div class="forum-title-main" style="flex:1">${escapeHtmlText(mail.subject)}</div>
    </div>
    <div style="padding:.8rem">
      <div style="display:flex;align-items:center;gap:.6rem;font-size:.72rem;color:#6a5a30;margin-bottom:.8rem;padding:.5rem;border:1px solid #1a1810">
        ${typeof getAvatarHtmlPost === 'function' ? getAvatarHtmlPost(mail.fromIsOrg, mail.fromOrgIcon, mail.from, 28) : ''}
        <div>
          De : <strong style="color:#c0b090">${escapeHtmlText(mail.from)}</strong>${mail.fromIsOrg ? ' <i class="ti ti-shield" style="font-size:.65rem;color:#8a8060" title="Organisation"></i>' : ''}
          → À : <strong style="color:#c0b090">${escapeHtmlText(mail.to)}</strong>
          · ${formatDateAffichage(mail.time)}
        </div>
      </div>
      <div class="lecture-longue lecture-longue-page" style="color:#f0ead6">${typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(mail.body || '') : ''}</div>
      ${estPropositionJodie ? '<div id="jodie-portrait-etat" style="margin-top:1rem"></div>' : ''}
      <div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">
        ${mail.to === myName && !mail.fromIsOrg ? `
          <button data-mail-from="${escapeHtmlText(mail.from)}" data-mail-subject="${escapeHtmlText(mail.subject)}"
            onclick="replyToMail(this.dataset.mailFrom, this.dataset.mailSubject)" class="forum-new-btn" style="font-size:.72rem">
            <i class="ti ti-corner-down-left"></i> Répondre
          </button>` : ''}
        ${mail.archived ? `
          <button onclick="toggleArchiveMail('${mail.id}', false)"
            style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#C9A84C;cursor:pointer">
            <i class="ti ti-archive-off"></i> Désarchiver
          </button>` : `
          <button onclick="toggleArchiveMail('${mail.id}', true)"
            style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#8a8060;cursor:pointer">
            <i class="ti ti-archive"></i> Archiver (conserver indéfiniment)
          </button>`}
        <button onclick="deleteMail('${mail.id}');mailView='inbox';document.getElementById('forum-main').innerHTML=renderForumContent()" 
          style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">
          <i class="ti ti-trash"></i> Supprimer
        </button>
      </div>
      ${mail.to === myName && mail.fromIsOrg ? '<div style="margin-top:.5rem;font-size:.72rem;color:#9a8a68;font-style:italic">La réponse directe à une organisation n\'est pas encore disponible — aucune boîte de messagerie propre aux organisations n\'existe à ce jour.</div>' : ''}
      ${!mail.archived ? '<div style="margin-top:.5rem;font-size:.72rem;color:#9a8a68;font-style:italic">Ce message sera supprimé automatiquement 14 jours après réception, sauf archivage.</div>' : ''}
    </div>
  `;
}

function replyToMail(to, subject) {
  mailView = 'compose';
  document.getElementById('forum-main').innerHTML = renderMailCompose(to, 'RE: ' + subject);
}

// Selecteur d'identite d'expedition (17 aout 2026, envoi au nom d'une organisation) : quasi-
// duplique de renderPosterEnTantQue (forum, ci-dessus) plutot que reutilise directement --
// libelle different ("Envoyer" vs "Publier") et ce lot doit explicitement ne pas toucher au
// forum. getMesOrganisations() (chef actuel uniquement, deja etabli pour le forum) est en
// revanche appele tel quel, sans duplication : seule la couche d'affichage differe.
function renderEnvoyerMailEnTantQue(fieldId, selectedOrgaId) {
  const mesOrgas = typeof getMesOrganisations === 'function' ? getMesOrganisations() : [];
  if (mesOrgas.length === 0) return '';
  let html = '<div class="forum-field"><label class="forum-field-label">Envoyer en tant que</label>';
  html += '<select id="' + fieldId + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
  html += '<option value="">' + escapeHtmlText(state.char?.name || 'Moi-même') + '</option>';
  mesOrgas.forEach(o => {
    html += '<option value="' + o.id + '"' + (selectedOrgaId === o.id ? ' selected' : '') + '>' + escapeHtmlText(o.nom) + (!o.visible ? ' (secrète)' : '') + '</option>';
  });
  html += '</select></div>';
  return html;
}

function renderMailCompose(defaultTo = '', defaultSubject = '', defaultOrgaId = '') {
  // Liste des PJ connus (contacts)
  const contacts = state.contacts || [];
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="mailView='inbox';document.getElementById('forum-main').innerHTML=renderForumContent()">
        <i class="ti ti-arrow-left"></i> Retour
      </button>
      <div class="forum-title-main">Nouveau message</div>
    </div>
    <div class="forum-compose-form">
      <div class="forum-field">
        <label class="forum-field-label">Destinataire</label>
        <input class="forum-field-input" id="mail-to" type="text" value="${escapeHtmlText(defaultTo)}"
          placeholder="Nom du destinataire..." list="contacts-list"/>
        <datalist id="contacts-list">
          ${contacts.map(c => `<option value="${escapeHtmlText(c.name)}">`).join('')}
        </datalist>
      </div>
      ${renderEnvoyerMailEnTantQue('compose-mail-auteur', defaultOrgaId)}
      <div class="forum-field">
        <label class="forum-field-label">Sujet</label>
        <input class="forum-field-input" id="mail-subject" type="text" value="${escapeHtmlText(defaultSubject)}"
          placeholder="Objet du message..."/>
      </div>
      <div class="forum-field">
        <label class="forum-field-label">Message</label>
        ${renderRichEditor('compose-body')}
      </div>
      <button class="forum-submit-btn" onclick="submitMail()">
        <i class="ti ti-send"></i> Envoyer
      </button>
    </div>
  `;
}

let _mailEnvoiEnCours = false;
function submitMail() {
  // Verrou anti-double-envoi : quelle que soit la cause (double-clic, doublon DOM du
  // formulaire), on ignore tout appel suivant tant que le premier n'est pas termine.
  if (_mailEnvoiEnCours) return;
  _mailEnvoiEnCours = true;

  // Prendre toujours le dernier élément en cas de doublons dans le DOM
  const toEls = document.querySelectorAll('#mail-to');
  const subjectEls = document.querySelectorAll('#mail-subject');
  const bodyEls = document.querySelectorAll('#compose-body');
  const to = toEls[toEls.length - 1]?.value?.trim();
  const subject = subjectEls[subjectEls.length - 1]?.value?.trim();
  const bodyEl = bodyEls[bodyEls.length - 1];
  const bodyText = bodyEl?.innerText?.trim();
  if (!to || !subject || !bodyText) {
    showToast('Champs requis','Remplissez tous les champs.',false);
    _mailEnvoiEnCours = false;
    return;
  }
  // Sanitisation à l'écriture (lot H2, faille XSS pipeline mail) : le corps vient d'un
  // contenteditable, même filtre que les posts du forum (RICH_ALLOWED_TAGS).
  const body = typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(bodyEl?.innerHTML?.trim() || '') : (bodyEl?.innerHTML?.trim() || '');
  sendMail(to, subject, body);
  mailDefaultTo = '';
  mailView = 'inbox';
  renderForumModal();
  setTimeout(function() { _mailEnvoiEnCours = false; }, 1500);
}
