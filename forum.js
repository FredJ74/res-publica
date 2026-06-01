/* ===========================
   RES PUBLICA — FORUM.JS
   Système de forums complet
   =========================== */

// Structure des forums
const FORUMS = {
  local:         { name: 'Forum Local',          icon: 'ti-home',        desc: 'Discussions de votre ville', private: false },
  regional:      { name: 'Forum Regional',        icon: 'ti-map',         desc: 'Discussions de votre region', private: false },
  national:      { name: 'Forum National',        icon: 'ti-flag',        desc: 'Debats politiques nationaux', private: false },
  international: { name: 'Forum International',   icon: 'ti-world',       desc: 'Relations entre empires', private: false },
  gouvernement:  { name: 'Forum Gouvernemental',  icon: 'ti-building-bank', desc: 'Reserve au gouvernement', private: true, requiredPost: ['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'] },
  presse:        { name: 'Presse & Medias',        icon: 'ti-news',        desc: 'Reserve aux journalistes', private: true },
  syndicats:     { name: 'Forum Syndical',         icon: 'ti-users-group', desc: 'Reserve aux syndicalistes', private: true }
};

// Données des forums (topics)
const FORUM_TOPICS = {
  local: [
    {
      id: 'topic-1', title: 'Corruption au commissariat central', author: 'CitoyenAnonyme',
      time: 'Jour 1 · 07h30', views: 42, replies: 3,
      posts: [
        { author: 'CitoyenAnonyme', time: 'Jour 1 · 07h30', content: 'La corruption au commissariat central est inacceptable ! J\'ai vu de mes propres yeux le commissaire Gros accepter une enveloppe. Qui va agir ?' },
        { author: 'JournalisteX', time: 'Jour 1 · 08h00', content: 'Des sources confirment ces informations. Une enquête est en cours.' },
        { author: 'CitoyenLambda', time: 'Jour 1 · 09h00', content: 'Rien de nouveau sous le soleil. Ca dure depuis des années.' }
      ]
    },
    {
      id: 'topic-2', title: 'Travaux avenue de la Republique', author: 'CommerçantDuCentre',
      time: 'Jour 1 · 06h00', views: 18, replies: 1,
      posts: [
        { author: 'CommerçantDuCentre', time: 'Jour 1 · 06h00', content: 'Les travaux paralysent le commerce depuis 3 semaines. Qui a signé ce permis ?' },
        { author: 'MairieOfficiel', time: 'Jour 1 · 10h00', content: 'Les travaux sont prévus pour se terminer dans 10 jours. Nous vous prions de nous excuser.' }
      ]
    }
  ],
  regional: [
    {
      id: 'topic-3', title: 'Budget regional : les syndicats se mobilisent', author: 'EluRegional',
      time: 'Jour 1 · 05h00', views: 67, replies: 2,
      posts: [
        { author: 'EluRegional', time: 'Jour 1 · 05h00', content: 'Le budget regional sera présenté la semaine prochaine. Les syndicats annoncent une mobilisation.' }
      ]
    }
  ],
  national: [
    {
      id: 'topic-4', title: 'Elections anticipées : rumeurs persistantes', author: 'ObservateurPolitique',
      time: 'Jour 1 · 08h00', views: 234, replies: 5,
      posts: [
        { author: 'ObservateurPolitique', time: 'Jour 1 · 08h00', content: 'Le gouvernement en place semble fragilisé. Des elections anticipées seraient envisagées selon nos informations.' }
      ]
    }
  ],
  international: [
    {
      id: 'topic-5', title: 'Tensions Republia / El Estado', author: 'DiplomateEtranger',
      time: 'Jour 1 · 04h00', views: 89, replies: 1,
      posts: [
        { author: 'DiplomateEtranger', time: 'Jour 1 · 04h00', content: 'Les tensions entre Republia et El Estado s\'intensifient autour des accords commerciaux.' }
      ]
    }
  ],
  gouvernement: [],
  presse: [],
  syndicats: []
};

let currentForumId = 'local';
let currentTopicId = null;
let forumView = 'list'; // 'list' | 'topic' | 'new-topic' | 'reply'

function openForum_module(forumId) {
  forumId = forumId || 'local';
  currentForumId = forumId;
  currentTopicId = null;
  forumView = 'list';
  renderForumModal();
  document.getElementById('modal-forum').classList.add('open');
}

function renderForumModal() {
  const modal = document.getElementById('forum-body');
  modal.innerHTML = `
    <div class="forum-layout">
      <!-- Sidebar forums -->
      <div class="forum-sidebar">
        ${Object.entries(FORUMS).map(([id, f]) => {
          const accessible = !f.private || canAccessForum(id);
          return `<div class="forum-nav-item ${id === currentForumId ? 'active' : ''} ${!accessible ? 'locked' : ''}"
            onclick="${accessible ? `switchForum('${id}')` : `showToast('Acces restreint', 'Ce forum est reserve aux membres autorises.', false)`}">
            <i class="ti ${f.icon}" style="font-size:.85rem"></i>
            <div>
              <div class="forum-nav-name">${f.name}</div>
              <div class="forum-nav-count">${(FORUM_TOPICS[id]||[]).length} sujet(s)</div>
            </div>
            ${f.private ? `<i class="ti ti-lock" style="font-size:.65rem;color:#4a4030;margin-left:auto"></i>` : ''}
          </div>`;
        }).join('')}
      </div>
      <!-- Contenu principal -->
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
  document.querySelectorAll('.forum-nav-item').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.forum-nav-item').forEach(el => {
    if (el.textContent.includes(FORUMS[id].name)) el.classList.add('active');
  });
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

function renderForumContent() {
  if (forumView === 'list') return renderTopicList();
  if (forumView === 'topic') return renderTopicView();
  if (forumView === 'new-topic') return renderNewTopicForm();
  if (forumView === 'reply') return renderReplyForm();
  return '';
}

function renderTopicList() {
  const f = FORUMS[currentForumId];
  const topics = FORUM_TOPICS[currentForumId] || [];
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
      ? `<div class="forum-empty">Aucun sujet pour l'instant. Soyez le premier a en créer un !</div>`
      : `<div class="forum-topics-list">
          <div class="forum-topics-header">
            <span>Sujet</span><span>Auteur</span><span>Vues</span><span>Reponses</span>
          </div>
          ${topics.map(t => `
            <div class="forum-topic-row" onclick="openTopic('${t.id}')">
              <div class="forum-topic-title">
                <i class="ti ti-message-circle" style="font-size:.8rem;color:#4a6a4a;margin-right:.3rem"></i>
                ${t.title}
              </div>
              <div class="forum-topic-author">${t.author}</div>
              <div class="forum-topic-stat">${t.views}</div>
              <div class="forum-topic-stat">${t.replies}</div>
            </div>`).join('')}
        </div>`}
  `;
}

function renderTopicView() {
  const topics = FORUM_TOPICS[currentForumId] || [];
  const topic = topics.find(t => t.id === currentTopicId);
  if (!topic) return renderTopicList();

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
            <div class="forum-post-avatar"><i class="ti ti-user" style="font-size:1rem;color:#C9A84C"></i></div>
            <div>
              <div class="forum-post-author">${p.author}</div>
              <div class="forum-post-time">${p.time}</div>
            </div>
            ${i === 0 ? `<span class="forum-post-badge">OP</span>` : ''}
          </div>
          <div class="forum-post-content">${p.content}</div>
          ${p.image ? `<div class="forum-post-image"><img src="${p.image}" alt="" style="max-width:100%;max-height:200px;border:1px solid #2a2010"/></div>` : ''}
        </div>`).join('')}
    </div>
    <div class="forum-reply-bar">
      <button class="forum-new-btn" onclick="showReplyForm()">
        <i class="ti ti-corner-down-right"></i> Repondre
      </button>
    </div>
  `;
}

function renderNewTopicForm() {
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToList()">
        <i class="ti ti-arrow-left"></i> Retour
      </button>
      <div class="forum-title-main">Nouveau sujet</div>
    </div>
    <div class="forum-compose-form">
      <div class="forum-field">
        <label class="forum-field-label">Titre du sujet</label>
        <input class="forum-field-input" id="new-topic-title" type="text" placeholder="Intitule du sujet..."/>
      </div>
      <div class="forum-field">
        <label class="forum-field-label">Message</label>
        ${renderRichEditor('new-topic-content')}
      </div>
      <div class="forum-field">
        <label class="forum-field-label">Image (optionnel)</label>
        <div class="forum-img-upload">
          <input type="file" accept="image/*" id="new-topic-img" onchange="previewForumImage('new-topic-img','new-topic-img-preview')" style="display:none"/>
          <button class="forum-img-btn" onclick="document.getElementById('new-topic-img').click()">
            <i class="ti ti-photo"></i> Inserer une image
          </button>
          <div id="new-topic-img-preview"></div>
        </div>
      </div>
      <button class="forum-submit-btn" onclick="submitNewTopic()">
        <i class="ti ti-send"></i> Publier le sujet
      </button>
    </div>
  `;
}

function renderReplyForm() {
  const topics = FORUM_TOPICS[currentForumId] || [];
  const topic = topics.find(t => t.id === currentTopicId);
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToTopic()">
        <i class="ti ti-arrow-left"></i> Retour au sujet
      </button>
      <div class="forum-title-main">Repondre : ${topic?.title||''}</div>
    </div>
    <div class="forum-compose-form">
      <div class="forum-field">
        <label class="forum-field-label">Votre reponse</label>
        ${renderRichEditor('reply-content')}
      </div>
      <div class="forum-field">
        <label class="forum-field-label">Image (optionnel)</label>
        <div class="forum-img-upload">
          <input type="file" accept="image/*" id="reply-img" onchange="previewForumImage('reply-img','reply-img-preview')" style="display:none"/>
          <button class="forum-img-btn" onclick="document.getElementById('reply-img').click()">
            <i class="ti ti-photo"></i> Inserer une image
          </button>
          <div id="reply-img-preview"></div>
        </div>
      </div>
      <button class="forum-submit-btn" onclick="submitReply()">
        <i class="ti ti-send"></i> Publier la reponse
      </button>
    </div>
  `;
}

function renderRichEditor(id) {
  return `
    <div class="rich-editor">
      <div class="rich-toolbar">
        <button class="rich-btn" onclick="richCmd('bold')" title="Gras"><i class="ti ti-bold"></i></button>
        <button class="rich-btn" onclick="richCmd('underline')" title="Souligne"><i class="ti ti-underline"></i></button>
        <div class="rich-sep"></div>
        <button class="rich-btn" onclick="richCmd('justifyLeft')" title="Aligner a gauche"><i class="ti ti-align-left"></i></button>
        <button class="rich-btn" onclick="richCmd('justifyCenter')" title="Centrer"><i class="ti ti-align-center"></i></button>
        <button class="rich-btn" onclick="richCmd('justifyRight')" title="Aligner a droite"><i class="ti ti-align-right"></i></button>
      </div>
      <div class="rich-content" id="${id}" contenteditable="true"
        placeholder="Ecrivez votre message..."></div>
    </div>
  `;
}

function richCmd(cmd) {
  document.execCommand(cmd, false, null);
}

function previewForumImage(inputId, previewId) {
  const input = document.getElementById(inputId);
  const preview = document.getElementById(previewId);
  const file = input.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => {
    preview.innerHTML = `<img src="${e.target.result}" style="max-width:200px;max-height:120px;border:1px solid #2a2010;margin-top:.5rem"/>`;
    preview.dataset.url = e.target.result;
  };
  reader.readAsDataURL(file);
}

function showNewTopicForm() {
  forumView = 'new-topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}
function showReplyForm() {
  forumView = 'reply';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}
function backToList() {
  forumView = 'list';
  currentTopicId = null;
  document.getElementById('forum-main').innerHTML = renderForumContent();
}
function backToTopic() {
  forumView = 'topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}
function openTopic(topicId) {
  currentTopicId = topicId;
  forumView = 'topic';
  // Incrementer vues
  const topics = FORUM_TOPICS[currentForumId] || [];
  const t = topics.find(x => x.id === topicId);
  if (t) t.views++;
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

function submitNewTopic() {
  const titleEl = document.getElementById('new-topic-title');
  const contentEl = document.getElementById('new-topic-content');
  const imgPreview = document.getElementById('new-topic-img-preview');
  const title = titleEl?.value?.trim();
  const content = contentEl?.innerHTML?.trim();
  if (!title || !content || content === '') {
    showToast('Champs requis', 'Veuillez remplir le titre et le message.', false);
    return;
  }
  const char = state.char;
  const h = String(state.hour).padStart(2,'0');
  const newTopic = {
    id: 'topic-' + Date.now(),
    title: title,
    author: char?.name || 'Anonyme',
    time: `Jour ${state.day} · ${h}h00`,
    views: 1, replies: 0,
    posts: [{
      author: char?.name || 'Anonyme',
      time: `Jour ${state.day} · ${h}h00`,
      content: content,
      image: imgPreview?.dataset?.url || null
    }]
  };
  if (!FORUM_TOPICS[currentForumId]) FORUM_TOPICS[currentForumId] = [];
  FORUM_TOPICS[currentForumId].unshift(newTopic);
  state.pop = Math.min(100, state.pop + 2);
  updateUI();
  forumView = 'list';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez cree le sujet "${title}" sur le forum.`, 'event-info');
}

function submitReply() {
  const contentEl = document.getElementById('reply-content');
  const imgPreview = document.getElementById('reply-img-preview');
  const content = contentEl?.innerHTML?.trim();
  if (!content || content === '') {
    showToast('Message vide', 'Ecrivez votre reponse avant de publier.', false);
    return;
  }
  const char = state.char;
  const h = String(state.hour).padStart(2,'0');
  const topics = FORUM_TOPICS[currentForumId] || [];
  const topic = topics.find(t => t.id === currentTopicId);
  if (!topic) return;
  topic.posts.push({
    author: char?.name || 'Anonyme',
    time: `Jour ${state.day} · ${h}h00`,
    content: content,
    image: imgPreview?.dataset?.url || null
  });
  topic.replies = topic.posts.length - 1;
  state.pop = Math.min(100, state.pop + 1);
  updateUI();
  forumView = 'topic';
  document.getElementById('forum-main').innerHTML = renderForumContent();
  addJournalEntry(`Vous avez repondu au sujet "${topic.title}".`, 'event-info');
}
