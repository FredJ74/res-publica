/* ===========================
   RES PUBLICA — SUPABASE.JS
   Persistance multijoueur
   =========================== */

const SUPABASE_URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';

const SB_HEADERS = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};

// =====================
// UTILITAIRES
// =====================
async function sbGet(table, filters = '') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, {
    headers: { ...SB_HEADERS, 'Prefer': 'return=representation' }
  });
  if (!res.ok) { console.error('sbGet error', await res.text()); return null; }
  return res.json();
}

async function sbInsert(table, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...SB_HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) { console.error('sbInsert error', await res.text()); return null; }
  return res.json();
}

async function sbUpdate(table, filters, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, {
    method: 'PATCH',
    headers: { ...SB_HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) { console.error('sbUpdate error', await res.text()); return null; }
  return res.json();
}

async function sbDelete(table, filters) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, {
    method: 'DELETE',
    headers: SB_HEADERS
  });
  if (!res.ok) { console.error('sbDelete error', await res.text()); return null; }
  return true;
}

// =====================
// PERSONNAGES
// =====================
async function sbSavePersonnage(charState) {
  const photoKey = 'respublica_photo_' + (charState.char?.name || 'default');
  const savedPhoto = (typeof localStorage !== 'undefined') ? localStorage.getItem(photoKey) : null;
  const data = {
    name:             charState.char?.name,
    country:          charState.country,
    photo_url:        savedPhoto || charState.char?.photoUrl || null,
    archetype:        charState.char?.archetype,
    career:           charState.char?.career,
    stats:            charState.char?.stats,
    resources:        { inf: charState.inf, pop: charState.pop, dis: charState.dis },
    arg:              charState.arg || 0,
    liquide:          charState.liquide || 0,
    banque:           charState.banque || 0,
    hp:               charState.hp || 100,
    pa:               charState.pa || 10,
    moral:            charState.moral || 75,
    poste:            charState.poste || null,
    current_city:     charState.currentCity || 'capitale',
    current_building: charState.currentBuilding || null,
    inventory:        charState.inventory || [],
    informateurs:     charState.informateurs || [],
    poison_actif:     charState.poisonActif || null,
    day:              charState.day || 1,
    recherche:        charState.recherche || [],
    updated_at:       new Date().toISOString()
  };

  // Vérifier si le personnage existe déjà
  const existing = await sbGet('personnages', `name=eq.${encodeURIComponent(data.name)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('personnages', `name=eq.${encodeURIComponent(data.name)}`, data);
  } else {
    return sbInsert('personnages', data);
  }
}

async function sbLoadPersonnage(name) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(name)}`);
  if (!rows || rows.length === 0) return null;
  const r = rows[0];
  return {
    char: { name: r.name, archetype: r.archetype, career: r.career, stats: r.stats },
    country:       r.country,
    inf:           r.resources?.inf || 0,
    pop:           r.resources?.pop || 0,
    dis:           r.resources?.dis || 50,
    arg:           r.arg,
    liquide:       r.liquide,
    banque:        r.banque,
    hp:            r.hp,
    pa:            r.pa,
    moral:         r.moral,
    poste:         r.poste,
    currentCity:   r.current_city,
    currentBuilding: r.current_building,
    inventory:     r.inventory || [],
    informateurs:  r.informateurs || [],
    poisonActif:   r.poison_actif,
    day:           r.day,
    recherche:     r.recherche || []
  };
}

async function sbListPersonnages() {
  return sbGet('personnages', 'select=name,country,archetype,current_city,poste&order=created_at.asc');
}

// =====================
// FORUM
// =====================
async function sbLoadForumTopics(forumId) {
  return sbGet('forum_topics', `forum_id=eq.${forumId}&order=created_at.desc`);
}

async function sbLoadForumPosts(topicId) {
  return sbGet('forum_posts', `topic_id=eq.${encodeURIComponent(topicId)}&order=created_at.asc`);
}

async function sbCreateTopic(forumId, title, author, country, time) {
  const id = 'topic-' + Date.now();
  await sbInsert('forum_topics', { id, forum_id: forumId, title, author, country, time, views: 1, replies: 0 });
  return id;
}

async function sbCreatePost(topicId, author, content, time) {
  const id = 'post-' + Date.now();
  await sbInsert('forum_posts', { id, topic_id: topicId, author, content, time });
  // Mettre à jour le compteur de réponses
  const posts = await sbLoadForumPosts(topicId);
  const count = (posts?.length || 1) - 1;
  await sbUpdate('forum_topics', `id=eq.${encodeURIComponent(topicId)}`, { replies: count });
  return id;
}

async function sbEditPost(postId, content) {
  return sbUpdate('forum_posts', `id=eq.${encodeURIComponent(postId)}`, { content, edited: true });
}

async function sbIncrementViews(topicId) {
  const rows = await sbGet('forum_topics', `id=eq.${encodeURIComponent(topicId)}`);
  if (rows && rows.length > 0) {
    await sbUpdate('forum_topics', `id=eq.${encodeURIComponent(topicId)}`, { views: (rows[0].views || 0) + 1 });
  }
}

// =====================
// MAILS
// =====================
async function sbSendMail(from, to, subject, body, time) {
  const id = 'mail-' + Date.now();
  return sbInsert('mails', { id, from_player: from, to_player: to, subject, body, time, read: false });
}

async function sbGetMailsFor(playerName) {
  return sbGet('mails', `or=(to_player.eq.${encodeURIComponent(playerName)},from_player.eq.${encodeURIComponent(playerName)})&order=created_at.desc`);
}

async function sbMarkMailRead(mailId) {
  return sbUpdate('mails', `id=eq.${encodeURIComponent(mailId)}`, { read: true });
}

async function sbDeleteMail(mailId) {
  return sbDelete('mails', `id=eq.${encodeURIComponent(mailId)}`);
}


// =====================
// ÉVÉNEMENTS GLOBAUX (journal partagé entre joueurs)
// =====================
async function sbAddEvenementGlobal(country, city, texte, jour) {
  const id = 'evt-' + Date.now();
  return sbInsert('evenements_globaux', { country, city, texte, jour });
}

async function sbGetEvenementsRecents(country, city) {
  // Récupère les événements nationaux (city null) + ceux de la ville courante, 50 derniers
  const filterCountry = `country=eq.${encodeURIComponent(country)}`;
  const rows = await sbGet('evenements_globaux', `${filterCountry}&order=created_at.desc&limit=50`);
  if (!rows) return [];
  // Filtrer côté client : national (city null) OU ville du joueur
  return rows.filter(r => !r.city || r.city === city);
}


// =====================
// PRÉSENCE EN PIÈCE (multijoueur temps réel)
// =====================
async function sbUpdatePresence(name, country, city, buildingId, roomId) {
  if (!name) return;
  // Upsert — name est cle primaire, on remplace la ligne existante (sinon conflit silencieux)
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/presences`, {
      method: 'POST',
      headers: { ...SB_HEADERS, 'Prefer': 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify({
        name, country, city, building_id: buildingId, room_id: roomId,
        updated_at: new Date().toISOString()
      })
    });
    if (!res.ok) { console.error('sbUpdatePresence error', await res.text()); return null; }
    return res.json();
  } catch(e) { return null; }
}

async function sbGetPresencesInRoom(country, city, buildingId, roomId) {
  const filtre = `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&building_id=eq.${encodeURIComponent(buildingId)}&room_id=eq.${encodeURIComponent(roomId)}`;
  const rows = await sbGet('presences', filtre);
  if (!rows) return [];
  // Filtrer les présences trop anciennes (>5 min = probablement déconnecté)
  const now = Date.now();
  return rows.filter(r => (now - new Date(r.updated_at).getTime()) < 5 * 60 * 1000);
}

// =====================
// SAUVEGARDE AUTO
// =====================
let sbSaveTimer = null;
function sbAutoSave() {
  if (sbSaveTimer) clearTimeout(sbSaveTimer);
  sbSaveTimer = setTimeout(async () => {
    if (state?.char?.name) {
      await sbSavePersonnage(state);
    }
  }, 3000); // Sauvegarde 3s après la dernière action
}

// =====================
// INIT — vérification connexion
// =====================
async function sbInit() {
  try {
    const rows = await sbGet('personnages', 'select=count&limit=1');
    console.log('✅ Supabase connecté');
    return true;
  } catch(e) {
    console.warn('⚠️ Supabase non disponible — mode local');
    return false;
  }
}

// =====================
// DONS D'ARGENT ENTRE JOUEURS (en attente de credit)
// =====================
async function sbDeposerDon(destinataire, montant, expediteur) {
  return sbInsert('dons_en_attente', { destinataire, montant, expediteur, traite: false });
}

async function sbRecupererDonsEnAttente(destinataire) {
  const filtre = `destinataire=eq.${encodeURIComponent(destinataire)}&traite=eq.false`;
  return await sbGet('dons_en_attente', filtre) || [];
}

async function sbMarquerDonTraite(donId) {
  return sbUpdate('dons_en_attente', `id=eq.${donId}`, { traite: true });
}

// =====================
// ARCHIVAGE DES MAILS
// =====================
async function sbSetMailArchived(mailId, archived) {
  return sbUpdate('mails', `id=eq.${encodeURIComponent(mailId)}`, { archived });
}
