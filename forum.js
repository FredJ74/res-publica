/* ===========================
   RES PUBLICA — FORUM.JS v3
   Éditeur riche, mails, emojis
   =========================== */

const FORUMS_BASE = {
  local:         { name: 'Forum Local',          icon: 'ti-home',          desc: 'Discussions de votre ville', private: false },
  regional:      { name: 'Forum Régional',        icon: 'ti-map',           desc: 'Discussions de votre région', private: false },
  national:      { name: 'Forum National',        icon: 'ti-flag',          desc: 'Débats politiques nationaux', private: false },
  international: { name: 'Forum International',   icon: 'ti-world',         desc: 'Relations entre empires', private: false },
  gouvernement:  { name: 'Forum Gouvernemental',  icon: 'ti-building-bank', desc: 'Réservé au gouvernement', private: true, requiredPost: ['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'] },
  presidence:    { name: 'La Présidence à la Nation', icon: 'ti-flag-3',    desc: 'Discours et annonces officielles depuis la Présidence', private: false },
  presse:        { name: 'Presse & Médias',        icon: 'ti-news',          desc: 'Réservé aux journalistes', private: true },
  syndicats:     { name: 'Forum Syndical',         icon: 'ti-users-group',   desc: 'Réservé aux syndicalistes', private: true }
};

// Getter dynamique — ajoute le forum Tribunal de la ville courante
function getForums() {
  const villeId = (typeof state !== 'undefined' && state.currentCity) || 'capitale';
  const tribunalKey = 'tribunal_' + villeId;
  const villeNom = (typeof WORLD !== 'undefined' && typeof state !== 'undefined')
    ? (WORLD[state.country]?.[villeId]?.name || villeId)
    : villeId;
  return {
    ...FORUMS_BASE,
    [tribunalKey]: { name: '⚖️ Tribunal — ' + villeNom, icon: 'ti-gavel', desc: 'Plaintes et affaires judiciaires de ' + villeNom, private: false }
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

const FORUM_TOPICS = {
  local: [
    {
      id: 'topic-1', title: 'Corruption au commissariat central', author: 'CitoyenAnonyme',
      time: 'Jour 1 · 07h30', views: 42, replies: 3,
      posts: [
        { id:'p1', author: 'CitoyenAnonyme', time: 'Jour 1 · 07h30', content: 'La corruption au commissariat central est inacceptable ! J\'ai vu de mes propres yeux le commissaire Gros accepter une enveloppe. Qui va agir ?' },
        { id:'p2', author: 'JournalisteX', time: 'Jour 1 · 08h00', content: 'Des sources confirment ces informations. Une enquête est en cours.' },
        { id:'p3', author: 'CitoyenLambda', time: 'Jour 1 · 09h00', content: 'Rien de nouveau sous le soleil. Ça dure depuis des années.' }
      ]
    },
    {
      id: 'topic-2', title: 'Travaux avenue de la République', author: 'CommerçantDuCentre',
      time: 'Jour 1 · 06h00', views: 18, replies: 1,
      posts: [
        { id:'p4', author: 'CommerçantDuCentre', time: 'Jour 1 · 06h00', content: 'Les travaux paralysent le commerce depuis 3 semaines. Qui a signé ce permis ?' },
        { id:'p5', author: 'MairieOfficiel', time: 'Jour 1 · 10h00', content: 'Les travaux sont prévus pour se terminer dans 10 jours. Nous vous prions de nous excuser.' }
      ]
    }
  ],
  regional: [
    { id:'topic-3', title:'Budget régional : les syndicats se mobilisent', author:'EluRegional', time:'Jour 1 · 05h00', views:67, replies:1,
      posts:[{ id:'p6', author:'EluRegional', time:'Jour 1 · 05h00', content:'Le budget régional sera présenté la semaine prochaine. Les syndicats annoncent une mobilisation.' }] }
  ],
  national: [
    { id:'topic-4', title:'Elections anticipées : rumeurs persistantes', author:'ObservateurPolitique', time:'Jour 1 · 08h00', views:234, replies:5,
      posts:[{ id:'p7', author:'ObservateurPolitique', time:'Jour 1 · 08h00', content:'Le gouvernement en place semble fragilisé. Des élections anticipées seraient envisagées selon nos informations.' }] }
  ],
  international: [
    { id:'topic-5', title:'Tensions Républia / El Estado', author:'DiplomateEtranger', time:'Jour 1 · 04h00', views:89, replies:1,
      posts:[{ id:'p8', author:'DiplomateEtranger', time:'Jour 1 · 04h00', content:'Les tensions entre Républia et El Estado s\'intensifient autour des accords commerciaux.' }] }
  ],
  gouvernement: [], presse: [], syndicats: []
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
  return getMails().filter(m => m.to === name || m.from === name);
}
async function sendMail(to, subject, body) {
  const from = state.char?.name || 'Anonyme';
  const time = formatDateHeureJeu();

  // Supabase
  if (typeof sbSendMail === 'function') {
    await sbSendMail(from, to, subject, body, time);
  }

  // Local aussi
  const mails = getMails();
  mails.push({ id: 'mail-' + Date.now(), from, to, subject, body, time, read: false });
  saveMails(mails);
  addJournalEntry(`Mail envoyé à ${to} : "${subject}".`, 'event-info');
  showToast('Mail envoyé', `À ${to} — "${subject}"`, true);
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
const EMOJI_CATS = {
  'Politique': ['🏛️','👑','⚖️','🗳️','📜','🤝','🚩','🎖️','🛡️','📋','🗡️','🔏','🏆','🎗️'],
  'Alertes':   ['⚠️','🚨','‼️','❗','🔴','🟢','🔵','⭕','✅','❌','🔔','📣','📢','🚫'],
  'Médias':    ['📰','📡','✍️','📝','💬','📨','🎙️','📸','🖊️','📖','🗞️','📻','🎬','🔎'],
  'Émotions':  ['😄','😈','🤫','🤐','👀','🙏','💪','🤑','😤','🧐','😏','🤭','👏','🫡'],
  'Symboles':  ['⭐','💀','💣','🔒','🔓','🕵️','🃏','⚡','🌟','💡','🔑','💎','🏴','⚜️'],
  'Séparateurs':['═══════════════','· · · · · · · · ·','— — — — — — —','⚜️ ─────────── ⚜️','◆ ─────────── ◆','✦ · · · · · · · ✦']
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

let currentForumId = 'local';
let currentTopicId = null;
let forumView = 'list';
let mailView = 'inbox'; // 'inbox' | 'compose' | 'read'
let mailDefaultTo = ''; // Destinataire pré-rempli depuis répertoire PJ
let editingPostId = null;
let editingTopicId = null;

// =====================
// MODAL PRINCIPALE
// =====================
function openForum_module(forumId) {
  forumId = forumId || 'local';
  currentForumId = forumId;
  currentTopicId = null;
  forumView = 'list';
  renderForumModal();
  document.getElementById('modal-forum').classList.add('open');
  // Charger depuis Supabase en arrière-plan et rafraîchir
  loadForumTopicsFromSB(forumId).then(() => {
    if (mailView !== 'compose') document.getElementById('forum-main').innerHTML = renderForumContent();
  }).catch(() => {});
}

function renderForumModal() {
  const modal = document.getElementById('forum-body');
  const unreadCount = getMyMails().filter(m => !m.read && m.to === state.char?.name).length;
  modal.innerHTML = `
    <div class="forum-layout">
      <div class="forum-sidebar">
        <div class="forum-sidebar-section">FORUMS</div>
        ${Object.entries(FORUMS).map(([id, f]) => {
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
        }).join('')}
        <div class="forum-sidebar-section" style="margin-top:.8rem">MESSAGERIE</div>
        <div class="forum-nav-item ${forumView === 'mail' ? 'active' : ''}" onclick="switchToMail()">
          <i class="ti ti-mail" style="font-size:.85rem"></i>
          <div>
            <div class="forum-nav-name">Boîte Mail</div>
            <div class="forum-nav-count">${unreadCount > 0 ? `<span style="color:#C9A84C">${unreadCount} non lu(s)</span>` : 'Aucun message'}</div>
          </div>
        </div>
      </div>
      <div class="forum-main" id="forum-main">
        ${renderForumContent()}
      </div>
    </div>
  `;
}

function canAccessForum(forumId) {
  const f = FORUMS[forumId];
  if (!f.private) return true;
  if (!state.poste) return false;
  if (f.requiredPost) return f.requiredPost.includes(state.poste.id);
  return true;
}

function switchForum(id) {
  currentForumId = id;
  currentTopicId = null;
  forumView = 'list';
  renderForumModal();
  loadForumTopicsFromSB(id).then(() => {
    document.getElementById('forum-main').innerHTML = renderForumContent();
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
  }).catch(() => {});
}

function renderForumContent() {
  if (forumView === 'mail')      return renderMailView();
  if (forumView === 'list')      return renderTopicList();
  if (forumView === 'topic')     return renderTopicView();
  if (forumView === 'new-topic') return renderNewTopicForm();
  if (forumView === 'reply')     return renderReplyForm();
  if (forumView === 'edit-post') return renderEditPostForm();
  return '';
}

// =====================
// FORUM — LISTE TOPICS
// =====================
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
      <button class="forum-new-btn" onclick="showNewTopicForm()">
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
                ${t.title}
              </div>
              <div class="forum-topic-author">
                <div>${t.author}</div>
                <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(t.time)}</div>
              </div>
              <div class="forum-topic-author">
                <div>${t.lastPostAuthor || t.author}</div>
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
      <div class="forum-title-main" style="flex:1">${topic.title}</div>
    </div>
    <div class="forum-posts">
      ${topic.posts.map((p, i) => `
        <div class="forum-post">
          <div class="forum-post-side">
            <div class="forum-post-avatar" ${!p.authorIsOrg ? `style="cursor:pointer" onclick="ouvrirFichePublique('${(p.author||'').replace(/'/g,"\\'")}')"` : ''}>${typeof getAvatarHtmlPourNom === 'function' ? getAvatarHtmlPourNom(p.author, 40) : '<i class="ti ti-user" style="font-size:1.2rem;color:#C9A84C"></i>'}</div>
            ${p.authorCountry && COUNTRIES?.[p.authorCountry] ? '<div style="width:100%;height:6px;background:' + COUNTRIES[p.authorCountry].col + ';margin:.3rem 0 .1rem"></div>' : ''}
            <div class="forum-post-author">${p.author}${p.authorIsOrg ? ' <i class="ti ti-shield" style="font-size:.7rem;color:#8a8060" title="Organisation"></i>' : ''}</div>
            ${p.authorSecret ? '<span class="forum-post-badge" style="border-color:#8a2020;color:#cc4444">secrète</span>' : ''}
            <div class="forum-post-time">${formatDateAffichage(p.time)}</div>
            ${i === 0 ? `<span class="forum-post-badge">Auteur du sujet</span>` : ''}
          </div>
          <div class="forum-post-main">
            <div class="forum-post-toolbar">
              ${p.author === myName ? `
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
            <div class="forum-post-content">${(p.blocks && p.blocks.length > 0) ? sanitizeRichHtml(renderBlocks(p.blocks)) : sanitizeRichHtml(p.content)}</div>
          </div>
        </div>`).join('')}
    </div>
    <div class="forum-reply-bar">
      <button class="forum-new-btn" onclick="showReplyForm()">
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
function getMesOrganisations() {
  return (state.organisations || []).filter(o => (o.membres || []).some(m => m.nom === state.char?.name));
}

function renderPosterEnTantQue(fieldId) {
  const mesOrgas = getMesOrganisations();
  if (mesOrgas.length === 0) return '';
  let html = '<div class="forum-field"><label class="forum-field-label">Poster en tant que</label>';
  html += '<select id="' + fieldId + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
  html += '<option value="">' + (state.char?.name || 'Moi-même') + '</option>';
  mesOrgas.forEach(o => {
    html += '<option value="' + o.id + '">' + o.nom + (!o.visible ? ' (secrète)' : '') + '</option>';
  });
  html += '</select></div>';
  return html;
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
      <div class="forum-title-main">Répondre : ${topic?.title||''}</div>
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
  forumView = 'edit-post';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

function submitEditPost() {
  const contentEl = document.getElementById('edit-post-content');
  const content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!content) return;
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === editingTopicId);
  if (!topic) return;
  const post = topic.posts.find(p => (p.id||'') === editingPostId) || topic.posts[parseInt(editingPostId)];
  if (post) {
    post.content = content;
    post.blocks = htmlToBlocks(content);
    post.edited = true;
  }
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
  const quoteHtml = `<div style="margin:1.3rem 0"><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— · —</div><blockquote style="border-left:3px solid #C9A84C;padding:.7rem 1.2rem;margin:.5rem 0;color:#c0b090"><em>${stripped}...</em><br><small style="color:#6a5a30">— ${post.author}</small></blockquote><div style="text-align:center;color:#6a5a30;font-size:.7rem;letter-spacing:.35em">— · —</div></div><p></p>`;
  forumView = 'reply';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  setTimeout(() => {
    const el = document.getElementById('reply-content');
    if (el) { el.innerHTML = quoteHtml; el.focus(); }
  }, 100);
}

function showNewTopicForm() {
  if (currentForumId === 'presidence' && state.poste?.id !== 'president') {
    showToast('Accès restreint', 'Seul le Président peut ouvrir un sujet dans "La Présidence à la Nation".', false);
    return;
  }
  forumView = 'new-topic'; document.getElementById('forum-main').innerHTML = renderForumContent();
}
function showReplyForm()    { forumView = 'reply';     document.getElementById('forum-main').innerHTML = renderForumContent(); }
function backToList()       { forumView = 'list'; currentTopicId = null; document.getElementById('forum-main').innerHTML = renderForumContent(); }
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
const RICH_ALLOWED_TAGS = new Set(['P','BR','B','I','U','STRONG','EM','H2','H3','BLOCKQUOTE','DIV','SPAN','IMG','HR','UL','OL','LI','A']);
const RICH_ALLOWED_STYLE_PROPS = new Set([
  'color','background-color','text-align','font-style','font-weight','text-decoration','float','clear',
  'margin','margin-left','margin-right','margin-top','margin-bottom','max-width','max-height',
  'width','height','display','border-left','border','border-top','border-radius','object-fit',
  'vertical-align','padding','grid-template-columns','gap',
  'text-transform','letter-spacing','font-size','line-height','overflow'
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
  const titleEl = document.getElementById('new-topic-title');
  const contentEl = document.getElementById('new-topic-content');
  const title = titleEl?.value?.trim();
  let content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!title || !content) { showToast('Champs requis','Remplissez le titre et le message.',false); return; }
  if (document.getElementById('new-topic-signature')?.checked) {
    content = sanitizeRichHtml(content + getSignatureHtml());
  }
  const char = state.char;

  const orgaId = document.getElementById('new-topic-auteur')?.value || '';
  const orga = orgaId ? getMesOrganisations().find(o => o.id === orgaId) : null;
  const authorName = orga ? orga.nom : (char?.name || 'Anonyme');
  const authorIsOrg = !!orga;
  const authorSecret = orga ? !orga.visible : false;

  const time = formatDateHeureJeu();
  const blocks = htmlToBlocks(content);

  // Supabase
  let topicId;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic(currentForumId, title, authorName, state.country, time, authorIsOrg, authorSecret);
    if (topicId) await sbCreatePost(topicId, authorName, content, time, authorIsOrg, authorSecret, blocks);
  }

  // Local aussi pour affichage immédiat
  const newTopic = {
    id: topicId || 'topic-' + Date.now(), title, author: authorName,
    authorCountry: state.country, authorIsOrg, authorSecret,
    time, views: 1, replies: 0,
    lastPostAuthor: authorName, lastPostTime: time,
    posts: [{ id:'p-'+Date.now(), author: authorName, authorCountry: state.country, authorIsOrg, authorSecret, time, content, blocks }]
  };
  if (!FORUM_TOPICS[currentForumId]) FORUM_TOPICS[currentForumId] = [];
  FORUM_TOPICS[currentForumId].unshift(newTopic);
  state.pop = Math.min(100, (state.pop||0) + 2);
  updateUI();
  forumView = 'list';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez créé le sujet "${title}" sur le forum.`, 'event-info');
}

async function submitReply() {
  const contentEl = document.getElementById('reply-content');
  let content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!content) { showToast('Message vide','Écrivez votre réponse avant de publier.',false); return; }
  if (document.getElementById('reply-signature')?.checked) {
    content = sanitizeRichHtml(content + getSignatureHtml());
  }
  const char = state.char;

  const orgaId = document.getElementById('reply-auteur')?.value || '';
  const orga = orgaId ? getMesOrganisations().find(o => o.id === orgaId) : null;
  const authorName = orga ? orga.nom : (char?.name || 'Anonyme');
  const authorIsOrg = !!orga;
  const authorSecret = orga ? !orga.visible : false;

  const time = formatDateHeureJeu();
  const blocks = htmlToBlocks(content);
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === currentTopicId);
  if (!topic) return;

  // Supabase
  if (typeof sbCreatePost === 'function') {
    await sbCreatePost(topic.id, authorName, content, time, authorIsOrg, authorSecret, blocks);
  }

  // Local
  topic.posts.push({ id:'p-'+Date.now(), author: authorName, authorCountry: state.country, authorIsOrg, authorSecret, time, content, blocks });
  topic.replies = topic.posts.length - 1;
  topic.lastPostAuthor = authorName;
  topic.lastPostTime = time;
  state.pop = Math.min(100, (state.pop||0) + 1);
  updateUI();
  forumView = 'topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez répondu au sujet "${topic.title}".`, 'event-info');
}

// =====================
// MESSAGERIE
// =====================
function renderMailView() {
  if (mailView === 'inbox')   return renderMailInbox();
  if (mailView === 'compose') return renderMailCompose(mailDefaultTo);
  if (mailView === 'read')    return renderMailRead();
  return renderMailInbox();
}

function renderMailInbox() {
  const myName = state.char?.name || '';
  const allMails = getMyMails().sort((a,b) => b.id.localeCompare(a.id));
  const mails = allMails.filter(m => !m.archived);
  const archives = allMails.filter(m => m.archived);
  const received = mails.filter(m => m.to === myName);
  const sent = mails.filter(m => m.from === myName);

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
                ${!m.read?'🔵 ':''}${m.subject}
              </div>
              <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(m.time)}</div>
            </div>
            <div style="font-size:.72rem;color:#6a5a30">De : ${m.from}</div>
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
              <div style="font-size:.82rem;color:#8a8060">${m.subject}</div>
              <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(m.time)}</div>
            </div>
            <div style="font-size:.72rem;color:#6a5a30">À : ${m.to}</div>
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
            <div style="font-size:.82rem;color:#8a8060">${m.subject}</div>
            <div style="font-size:.68rem;color:var(--text3)">${formatDateAffichage(m.time)}</div>
          </div>
          <div style="font-size:.72rem;color:#6a5a30">${m.from === myName ? 'À : ' + m.to : 'De : ' + m.from}</div>
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
      authorCountry: topic.authorCountry || topic.country, authorIsOrg: r.author_is_org, authorSecret: r.author_secret
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
          subject: r.subject, body: r.body, time: r.time, read: estLu, archived: r.archived || false };
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
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

function renderMailRead() {
  const mail = getMails().find(m => m.id === currentMailId);
  if (!mail) return renderMailInbox();
  const myName = state.char?.name || '';
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="mailView='inbox';document.getElementById('forum-main').innerHTML=renderForumContent()">
        <i class="ti ti-arrow-left"></i> Retour
      </button>
      <div class="forum-title-main" style="flex:1">${mail.subject}</div>
    </div>
    <div style="padding:.8rem">
      <div style="display:flex;align-items:center;gap:.6rem;font-size:.72rem;color:#6a5a30;margin-bottom:.8rem;padding:.5rem;border:1px solid #1a1810">
        ${typeof getAvatarHtmlPourNom === 'function' ? getAvatarHtmlPourNom(mail.from, 28) : ''}
        <div>
          De : <strong style="color:#c0b090">${mail.from}</strong> 
          → À : <strong style="color:#c0b090">${mail.to}</strong>
          · ${formatDateAffichage(mail.time)}
        </div>
      </div>
      <div style="font-family:Crimson Pro,Georgia,serif;font-size:.9rem;line-height:1.8;color:#f0ead6">${mail.body}</div>
      <div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">
        ${mail.to === myName ? `
          <button onclick="replyToMail('${mail.from}','${mail.subject}')" class="forum-new-btn" style="font-size:.72rem">
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
      ${!mail.archived ? '<div style="margin-top:.5rem;font-size:.72rem;color:#9a8a68;font-style:italic">Ce message sera supprimé automatiquement 14 jours après réception, sauf archivage.</div>' : ''}
    </div>
  `;
}

function replyToMail(to, subject) {
  mailView = 'compose';
  document.getElementById('forum-main').innerHTML = renderMailCompose(to, 'RE: ' + subject);
}

function renderMailCompose(defaultTo = '', defaultSubject = '') {
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
        <input class="forum-field-input" id="mail-to" type="text" value="${defaultTo}" 
          placeholder="Nom du destinataire..." list="contacts-list"/>
        <datalist id="contacts-list">
          ${contacts.map(c => `<option value="${c.name}">`).join('')}
        </datalist>
      </div>
      <div class="forum-field">
        <label class="forum-field-label">Sujet</label>
        <input class="forum-field-input" id="mail-subject" type="text" value="${defaultSubject}"
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

function submitMail() {
  // Prendre toujours le dernier élément en cas de doublons dans le DOM
  const toEls = document.querySelectorAll('#mail-to');
  const subjectEls = document.querySelectorAll('#mail-subject');
  const bodyEls = document.querySelectorAll('#compose-body');
  const to = toEls[toEls.length - 1]?.value?.trim();
  const subject = subjectEls[subjectEls.length - 1]?.value?.trim();
  const bodyEl = bodyEls[bodyEls.length - 1];
  const body = bodyEl?.innerHTML?.trim();
  const bodyText = bodyEl?.innerText?.trim();
  if (!to || !subject || !bodyText) { showToast('Champs requis','Remplissez tous les champs.',false); return; }
  sendMail(to, subject, body);
  mailDefaultTo = '';
  mailView = 'inbox';
  renderForumModal();
}
