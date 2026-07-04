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
  const h = String(state.hour || 8).padStart(2,'0');
  const time = `Jour ${state.day} · ${h}h`;

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
  'Citation':            `<blockquote style="border-left:3px solid #C9A84C;padding:.5rem 1rem;margin:.5rem 0;color:#c0b090;font-style:italic">Texte cité...</blockquote>`,
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
  return `
    <div class="forum-header-bar">
      <div>
        <div class="forum-title-main"><i class="ti ${f.icon}"></i> ${f.name}</div>
        <div class="forum-subtitle">${f.desc}</div>
      </div>
      <button class="forum-new-btn" onclick="showNewTopicForm()">
        <i class="ti ti-pencil-plus"></i> Nouveau sujet
      </button>
    </div>
    ${topics.length === 0
      ? `<div class="forum-empty">Aucun sujet. Soyez le premier à en créer un !</div>`
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
                <div style="font-size:.68rem;color:var(--text3)">${t.time || ''}</div>
              </div>
              <div class="forum-topic-author">
                <div>${t.lastPostAuthor || t.author}</div>
                <div style="font-size:.68rem;color:var(--text3)">${t.lastPostTime || t.time || ''}</div>
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
          <div class="forum-post-header">
            <div class="forum-post-avatar">${typeof getAvatarHtmlPourNom === 'function' ? getAvatarHtmlPourNom(p.author, 32) : '<i class="ti ti-user" style="font-size:1rem;color:#C9A84C"></i>'}</div>
            <div>
              <div class="forum-post-author">${p.author}</div>
              <div class="forum-post-time">${p.time}</div>
            </div>
            ${i === 0 ? `<span class="forum-post-badge">OP</span>` : ''}
            <div style="margin-left:auto;display:flex;gap:.4rem;align-items:center">
              ${p.author === myName ? `
                <button onclick="editPost('${topic.id}','${p.id || i}')" style="background:transparent;border:none;color:#8a8060;cursor:pointer;font-size:.75rem;padding:.2rem .4rem" title="Modifier">
                  <i class="ti ti-edit"></i>
                </button>` : ''}
              <button onclick="quotePost(${i})" style="background:transparent;border:none;color:#8a8060;cursor:pointer;font-size:.75rem;padding:.2rem .4rem" title="Citer">
                <i class="ti ti-quote"></i>
              </button>
            </div>
          </div>
          <div class="forum-post-content">${sanitizeRichHtml(p.content)}</div>
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
        <button class="rich-btn" onclick="richInsertImage()" title="Image"><i class="ti ti-photo"></i></button>
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

      <div class="rich-content" id="${id}" contenteditable="true"
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
  const colors = ['#C9A84C','#f0ead6','#cc4444','#4a8a4a','#4a6aaa','#aa6aaa','#8a8060'];
  const panel = document.getElementById('color-panel-rich');
  if (panel) { panel.remove(); return; }
  const div = document.createElement('div');
  div.id = 'color-panel-rich';
  div.style.cssText = 'position:absolute;z-index:999;background:#0a0a07;border:1px solid #2a2010;padding:.4rem;display:flex;gap:.3rem';
  colors.forEach(c => {
    const btn = document.createElement('button');
    btn.style.cssText = `width:20px;height:20px;background:${c};border:1px solid #2a2010;cursor:pointer`;
    btn.onclick = () => { document.execCommand('foreColor', false, c); div.remove(); };
    div.appendChild(btn);
  });
  const toolbar = document.querySelector('.rich-toolbar');
  toolbar?.parentNode?.insertBefore(div, toolbar.nextSibling);
}

function richInsertHR() {
  document.execCommand('insertHTML', false, '<hr style="border:none;border-top:1px solid #2a2010;margin:.8rem 0">');
}

let _richInsertTargetId = null;

function richInsertImage() {
  // Retrouve le champ contenteditable actuellement focus pour y revenir apres la saisie
  const focused = document.querySelector('.rich-content:focus, [contenteditable]:focus');
  _richInsertTargetId = focused?.id || null;

  document.getElementById('postes-modal-title').textContent = 'Insérer une image';
  let html = '<div style="padding:1rem">';
  html += '<div style="margin-bottom:.6rem"><label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.2rem">URL de l\'image</label>';
  html += '<input id="richimg-url" type="text" placeholder="https://..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none"/></div>';
  html += '<div style="margin-bottom:.6rem"><label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Position</label>';
  html += '<div style="display:flex;gap:.4rem">';
  ['gauche','centre','droite'].forEach((pos, i) => {
    html += '<button type="button" class="richimg-pos-btn" data-pos="' + pos + '" onclick="document.querySelectorAll(\'.richimg-pos-btn\').forEach(b=>b.style.borderColor=\'#2a2010\');this.style.borderColor=\'#C9A84C\'" style="flex:1;padding:.4rem;border:1px solid ' + (i===1?'#C9A84C':'#2a2010') + ';background:transparent;color:#c0b090;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em">' + pos.charAt(0).toUpperCase()+pos.slice(1) + '</button>';
  });
  html += '</div></div>';
  html += '<div style="margin-bottom:.8rem"><label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.2rem">Légende (optionnel)</label>';
  html += '<input id="richimg-legend" type="text" placeholder="Légende de l\'image" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none"/></div>';
  html += '<div id="richimg-preview" style="margin-bottom:.8rem"></div>';
  html += '<input id="richimg-url-preview-trigger" type="hidden"/>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button onclick="confirmerRichInsertImage()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Insérer</button>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');

  // Aperçu live de l'image en tapant l'URL
  const urlInput = document.getElementById('richimg-url');
  urlInput?.addEventListener('input', () => {
    const preview = document.getElementById('richimg-preview');
    if (urlInput.value.trim()) {
      preview.innerHTML = '<img src="' + urlInput.value.trim() + '" style="max-width:100%;max-height:160px;display:block;margin:0 auto;border:1px solid #2a2010" onerror="this.style.display=\'none\'"/>';
    } else {
      preview.innerHTML = '';
    }
  });
}

function confirmerRichInsertImage() {
  const url = document.getElementById('richimg-url')?.value?.trim();
  if (!url) { showToast('URL manquante', 'Indiquez une adresse d\'image.', false); return; }
  const posBtn = document.querySelector('.richimg-pos-btn[style*="C9A84C"]');
  const pos = posBtn?.dataset?.pos || 'centre';
  const legend = document.getElementById('richimg-legend')?.value?.trim() || '';

  let style = 'display:block;margin:0 auto;max-width:100%';
  if (pos === 'gauche') style = 'float:left;margin:0 1rem .5rem 0;max-width:45%';
  if (pos === 'droite') style = 'float:right;margin:0 0 .5rem 1rem;max-width:45%';
  const legendHtml = legend ? '<div style="text-align:center;font-size:.75rem;color:#8a8060;font-style:italic;margin-top:.2rem">' + legend + '</div>' : '';
  const wrapHtml = '<div style="overflow:hidden"><img src="' + url + '" style="' + style + '"/>' + legendHtml + '</div>';

  document.getElementById('modal-postes').classList.remove('open');

  const target = _richInsertTargetId ? document.getElementById(_richInsertTargetId) : null;
  if (target) {
    target.focus();
    document.execCommand('insertHTML', false, wrapHtml);
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
      <div class="forum-field">
        <label class="forum-field-label">Message</label>
        ${renderRichEditor('new-topic-content')}
      </div>
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
      <div class="forum-field">
        <label class="forum-field-label">Votre réponse</label>
        ${renderRichEditor('reply-content')}
      </div>
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
  const quoteHtml = `<blockquote style="border-left:3px solid #C9A84C;padding:.5rem 1rem;margin:.5rem 0;color:#c0b090;font-style:italic">${stripped}...<br><small style="color:#6a5a30">— ${post.author}</small></blockquote><p></p>`;
  forumView = 'reply';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  setTimeout(() => {
    const el = document.getElementById('reply-content');
    if (el) { el.innerHTML = quoteHtml; el.focus(); }
  }, 100);
}

function showNewTopicForm() { forumView = 'new-topic'; document.getElementById('forum-main').innerHTML = renderForumContent(); }
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
  'color','background-color','text-align','font-style','font-weight','text-decoration','float',
  'margin','margin-left','margin-right','margin-top','margin-bottom','max-width','max-height',
  'width','display','border-left','border','border-top','padding','grid-template-columns','gap',
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

function sanitizeRichHtml(html) {
  const tmp = document.createElement('div');
  tmp.innerHTML = html || '';

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
  // Format attendu : "Jour X · HHhMM" -> valeur numerique triable
  const m = /Jour\s*(\d+)\s*·\s*(\d{1,2})h(\d{2})?/.exec(str || '');
  if (!m) return 0;
  return parseInt(m[1]||0) * 1440 + parseInt(m[2]||0) * 60 + parseInt(m[3]||0);
}

async function submitNewTopic() {
  const titleEl = document.getElementById('new-topic-title');
  const contentEl = document.getElementById('new-topic-content');
  const title = titleEl?.value?.trim();
  const content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!title || !content) { showToast('Champs requis','Remplissez le titre et le message.',false); return; }
  const char = state.char;
  const h = String(state.hour||8).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const time = `Jour ${state.day} · ${h}h${m}`;

  // Supabase
  let topicId;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic(currentForumId, title, char?.name||'Anonyme', state.country, time);
    if (topicId) await sbCreatePost(topicId, char?.name||'Anonyme', content, time);
  }

  // Local aussi pour affichage immédiat
  const newTopic = {
    id: topicId || 'topic-' + Date.now(), title, author: char?.name||'Anonyme',
    time, views: 1, replies: 0,
    lastPostAuthor: char?.name||'Anonyme', lastPostTime: time,
    posts: [{ id:'p-'+Date.now(), author: char?.name||'Anonyme', time, content }]
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
  const content = sanitizeRichHtml(contentEl?.innerHTML?.trim());
  if (!content) { showToast('Message vide','Écrivez votre réponse avant de publier.',false); return; }
  const char = state.char;
  const h = String(state.hour||8).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const time = `Jour ${state.day} · ${h}h${m}`;
  const topic = (FORUM_TOPICS[currentForumId]||[]).find(t => t.id === currentTopicId);
  if (!topic) return;

  // Supabase
  if (typeof sbCreatePost === 'function') {
    await sbCreatePost(topic.id, char?.name||'Anonyme', content, time);
  }

  // Local
  topic.posts.push({ id:'p-'+Date.now(), author: char?.name||'Anonyme', time, content });
  topic.replies = topic.posts.length - 1;
  topic.lastPostAuthor = char?.name||'Anonyme';
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
              <div style="font-size:.68rem;color:#4a4030">${m.time}</div>
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
              <div style="font-size:.68rem;color:#4a4030">${m.time}</div>
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
            <div style="font-size:.68rem;color:#4a4030">${m.time}</div>
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
      time: r.time, edited: r.edited
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
          · ${mail.time}
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
      ${!mail.archived ? '<div style="margin-top:.5rem;font-size:.65rem;color:#5a5040;font-style:italic">Ce message sera supprime automatiquement 14 jours apres reception, sauf archivage.</div>' : ''}
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
