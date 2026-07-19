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
    bio:              charState.char?.bio || null,
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
    current_room:     charState.currentRoom || null,
    inventory:        charState.inventory || [],
    informateurs:     charState.informateurs || [],
    contacts:         charState.contacts || [],
    historique_crimes: charState.historiqueCrimes || [],
    enquetes_en_cours: charState.enquetesEnCours || [],
    domicile:         charState.domicile || null,
    employes:         charState.employes || [],
    locations_actives: charState.locationsActives || [],
    poison_actif:     charState.poisonActif || null,
    day:              charState.day || 1,
    dernier_dormir:   charState.dernierDormir || null,
    salaire_touche:   charState.salaireTouche || false,
    recherche:        charState.recherche || [],
    convocations:     charState.convocations || [],
    est_emprisonne:   charState.estEmprisonne || null,
    motto:            charState.char?.motto || null,
    licence_sportive: charState.char?.licenceSportive || null,
    performance_sportive: charState.char?.performance || null,
    blessure_sportive: charState.char?.blessureSportive || null,
    signature_html:   charState.char?.signatureHtml || null,
    signature_blocks: charState.char?.signatureBlocks || [],
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
    char: { name: r.name, archetype: r.archetype, career: r.career, stats: r.stats,
             photoUrl: r.photo_url || null, bio: r.bio || null, poste: r.poste || null,
             country: r.country, currentCity: r.current_city, currentBuilding: r.current_building,
             currentRoom: r.current_room || null, motto: r.motto || null,
             licenceSportive: r.licence_sportive || null, performance: r.performance_sportive || null, blessureSportive: r.blessure_sportive || null,
             signatureHtml: r.signature_html || null, signatureBlocks: r.signature_blocks || [] },
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
    currentRoom:   r.current_room || null,
    inventory:     r.inventory || [],
    informateurs:  r.informateurs || [],
    contacts:      r.contacts || [],
    historiqueCrimes: r.historique_crimes || [],
    enquetesEnCours:  r.enquetes_en_cours || [],
    domicile:      r.domicile || null,
    employes:      r.employes || [],
    locationsActives: r.locations_actives || [],
    poisonActif:   r.poison_actif,
    day:           r.day,
    dernierDormir: r.dernier_dormir || null,
    salaireTouche: r.salaire_touche || false,
    recherche:     r.recherche || [],
    convocations:  r.convocations || [],
    estEmprisonne: r.est_emprisonne || null
  };
}

async function sbListPersonnages() {
  // archetype (vocation) volontairement exclu - reste secret pour les autres joueurs
  return sbGet('personnages', 'select=name,country,current_city,poste,photo_url,domicile&order=created_at.asc');
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

async function sbCreateTopic(forumId, title, author, country, time, authorIsOrg, authorSecret) {
  const id = 'topic-' + Date.now();
  await sbInsert('forum_topics', {
    id, forum_id: forumId, title, author, country, time, views: 1, replies: 0,
    last_post_author: author, last_post_time: time,
    author_is_org: !!authorIsOrg, author_secret: !!authorSecret
  });
  return id;
}

async function sbCreatePost(topicId, author, content, time, authorIsOrg, authorSecret, blocks) {
  const id = 'post-' + Date.now();
  await sbInsert('forum_posts', { id, topic_id: topicId, author, content, time, author_is_org: !!authorIsOrg, author_secret: !!authorSecret, content_blocks: blocks || [] });
  // Mettre à jour le compteur de réponses + le dernier post (pour le tri par activité)
  const posts = await sbLoadForumPosts(topicId);
  const count = (posts?.length || 1) - 1;
  await sbUpdate('forum_topics', `id=eq.${encodeURIComponent(topicId)}`, { replies: count, last_post_author: author, last_post_time: time });
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
// =====================
// REGISTRE DE VENTE D'ARMES
// =====================
async function sbEnregistrerVenteArme(vente) {
  return sbInsert('registre_ventes_armes', vente);
}

async function sbConsulterRegistreArmes(pays) {
  const rows = await sbGet('registre_ventes_armes', `pays=eq.${encodeURIComponent(pays)}&order=created_at.desc`);
  return rows || [];
}

// =====================
// BATIMENTS FERMES (incendie / explosifs)
// =====================
async function sbFermerBatiment(fermeture) {
  return sbInsert('batiments_fermes', fermeture);
}

async function sbChargerBatimentsFermes(pays, ville) {
  const rows = await sbGet('batiments_fermes', `pays=eq.${encodeURIComponent(pays)}&ville=eq.${encodeURIComponent(ville)}`);
  return rows || [];
}

// =====================
// CHAMPIONNAT SPORTIF (etat partage, une seule ligne)
// =====================
async function sbGetChampionnat() {
  const rows = await sbGet('championnat', 'id=eq.1');
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveChampionnat(data) {
  const existing = await sbGet('championnat', 'id=eq.1');
  if (existing && existing.length > 0) {
    return sbUpdate('championnat', 'id=eq.1', { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('championnat', { id: 1, data, updated_at: new Date().toISOString() });
}

async function sbCreerPari(data) {
  const id = 'pari-' + Date.now() + '-' + Math.floor(Math.random()*10000);
  await sbInsert('paris_sportifs', { id, resolu: false, data });
  return id;
}

async function sbGetParisJourneeNonResolus(journeeNumero, saisonNumero) {
  const rows = await sbGet('paris_sportifs', 'resolu=eq.false&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.journeeNumero === journeeNumero && r.data?.saisonNumero === saisonNumero).map(r => ({ id: r.id, ...r.data }));
}

async function sbResoudrePari(id, joueurNom, gain) {
  await sbUpdate('paris_sportifs', `id=eq.${encodeURIComponent(id)}`, { resolu: true });
  if (gain > 0) {
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(joueurNom)}&select=arg`);
    const argActuel = rows?.[0]?.arg ?? 0;
    await sbUpdate('personnages', `name=eq.${encodeURIComponent(joueurNom)}`, { arg: argActuel + gain });
  }
}

async function sbAppliquerBlessureSportive(nomJoueur, blessure, degatsPV) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=hp`);
  const hpActuel = rows?.[0]?.hp ?? 100;
  const nouveauHp = Math.max(1, hpActuel - (degatsPV || 0));
  return sbUpdate('personnages', `name=eq.${encodeURIComponent(nomJoueur)}`, { blessure_sportive: blessure, hp: nouveauHp });
}

async function sbGetPresidentClub(clubId) {
  const rows = await sbGet('presidents_clubs', `id=eq.${encodeURIComponent(clubId)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSavePresidentClub(clubId, data) {
  const existing = await sbGet('presidents_clubs', `id=eq.${encodeURIComponent(clubId)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('presidents_clubs', `id=eq.${encodeURIComponent(clubId)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('presidents_clubs', { id: clubId, data, updated_at: new Date().toISOString() });
}

async function sbListTransfertsClub(clubId) {
  const rows = await sbGet('transferts_clubs', 'statut=neq.termine&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.clubDepartId === clubId || r.data?.clubArriveeId === clubId || r.data?.joueur === clubId);
}

async function sbCreerTransfert(data) {
  const id = 'transfert-' + Date.now();
  await sbInsert('transferts_clubs', { id, statut: data.statut, data });
  return id;
}

async function sbMajTransfert(id, data) {
  return sbUpdate('transferts_clubs', `id=eq.${encodeURIComponent(id)}`, { statut: data.statut, data });
}

async function sbGetTransfertsJoueur(nomJoueur) {
  const rows = await sbGet('transferts_clubs', 'statut=neq.termine&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.joueur === nomJoueur && r.data?.statut === 'attente_joueur').map(r => ({ id: r.id, ...r.data }));
}

async function sbGetTransfertsClubVente(clubId) {
  const rows = await sbGet('transferts_clubs', 'statut=neq.termine&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.clubDepartId === clubId && ['propose','contre_offre'].includes(r.data?.statut)).map(r => ({ id: r.id, ...r.data }));
}

async function sbGetEntreprise(id) {
  const rows = await sbGet('entreprises', `id=eq.${encodeURIComponent(id)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveEntreprise(id, data) {
  const existing = await sbGet('entreprises', `id=eq.${encodeURIComponent(id)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('entreprises', `id=eq.${encodeURIComponent(id)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('entreprises', { id, data, updated_at: new Date().toISOString() });
}

async function sbAppliquerSalaire(nomJoueur, montant) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=arg`);
  const argActuel = rows?.[0]?.arg ?? 0;
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomJoueur)}`, { arg: argActuel + montant });
}

async function sbAppliquerRachatEntreprise(nomAcheteur, montant) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomAcheteur)}&select=arg`);
  const argActuel = rows?.[0]?.arg ?? 0;
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomAcheteur)}`, { arg: argActuel - montant });
}

async function sbGetJoueurClub(nomJoueur) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=name,licence_sportive,performance_sportive`);
  return rows?.[0] || null;
}

async function sbListJoueursLicencies(clubId) {
  // On recupere tous les personnages ayant une licence, puis on filtre cote client sur le clubId
  // (les operateurs JSON de PostgREST sur des colonnes jsonb imbriquees sont plus fragiles a maintenir ici).
  const rows = await sbGet('personnages', 'licence_sportive=not.is.null&select=name,performance_sportive,blessure_sportive,licence_sportive');
  if (!rows) return [];
  return rows.filter(r => r.licence_sportive?.clubId === clubId);
}

async function sbGetBudgetClub(clubId) {
  const rows = await sbGet('budgets_clubs', `id=eq.${encodeURIComponent(clubId)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveBudgetClub(clubId, data) {
  const existing = await sbGet('budgets_clubs', `id=eq.${encodeURIComponent(clubId)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('budgets_clubs', `id=eq.${encodeURIComponent(clubId)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('budgets_clubs', { id: clubId, data, updated_at: new Date().toISOString() });
}

async function sbGetCaisseBatiment(key) {
  const rows = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(key)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveCaisseBatiment(key, data) {
  const existing = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(key)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('caisses_batiments', `id=eq.${encodeURIComponent(key)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('caisses_batiments', { id: key, data, updated_at: new Date().toISOString() });
}

async function sbGetBudgetNational(pays) {
  const rows = await sbGet('budgets_nationaux', `id=eq.${encodeURIComponent(pays)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveBudgetNational(pays, data) {
  const existing = await sbGet('budgets_nationaux', `id=eq.${encodeURIComponent(pays)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('budgets_nationaux', `id=eq.${encodeURIComponent(pays)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('budgets_nationaux', { id: pays, data, updated_at: new Date().toISOString() });
}

async function sbGetBudgetMunicipal(key) {
  const rows = await sbGet('budgets_municipaux', `id=eq.${encodeURIComponent(key)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveBudgetMunicipal(key, data) {
  const existing = await sbGet('budgets_municipaux', `id=eq.${encodeURIComponent(key)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('budgets_municipaux', `id=eq.${encodeURIComponent(key)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('budgets_municipaux', { id: key, data, updated_at: new Date().toISOString() });
}

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
  // Si pas dans un batiment/piece (rue centrale), pas de presence a chercher
  if (!buildingId || !roomId) return [];
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

// =====================
// SUPPRESSION DE PERSONNAGE (conserve forum/mails)
// =====================
async function sbDeletePersonnage(name) {
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(name)}`, {
      method: 'DELETE', headers: SB_HEADERS
    });
    await fetch(`${SUPABASE_URL}/rest/v1/presences?name=eq.${encodeURIComponent(name)}`, {
      method: 'DELETE', headers: SB_HEADERS
    });
    await fetch(`${SUPABASE_URL}/rest/v1/dons_en_attente?destinataire=eq.${encodeURIComponent(name)}`, {
      method: 'DELETE', headers: SB_HEADERS
    });
    await fetch(`${SUPABASE_URL}/rest/v1/votes_electoraux?votant=eq.${encodeURIComponent(name)}`, {
      method: 'DELETE', headers: SB_HEADERS
    });
    await fetch(`${SUPABASE_URL}/rest/v1/candidatures?nom=eq.${encodeURIComponent(name)}`, {
      method: 'DELETE', headers: SB_HEADERS
    });
    return true;
  } catch(e) { console.error('sbDeletePersonnage error', e); return false; }
}

// =====================
// MISE A JOUR PHOTO/BIO SEULES (depuis la fiche personnage)
// =====================
async function sbUpdatePhotoBio(name, photoUrl, bio) {
  const data = {};
  if (photoUrl !== undefined) data.photo_url = photoUrl;
  if (bio !== undefined) data.bio = bio;
  return sbUpdate('personnages', `name=eq.${encodeURIComponent(name)}`, data);
}

// =====================
// SOUVENIRS DE L'ACCUEIL (objets trouvés / kompromat potentiel)
// =====================
async function sbAjouterSouvenirAccueil(souvenir) {
  return sbInsert('souvenirs_accueil', {
    id: souvenir.id,
    pj_nom: souvenir.pjNom,
    objet_nom: souvenir.objetNom,
    jour_creation: souvenir.jourCreation,
    jour_expiration: souvenir.jourExpiration,
    revele: false
  });
}

async function sbGetSouvenirsAccueilPour(pjNom) {
  return sbGet('souvenirs_accueil', `pj_nom=eq.${encodeURIComponent(pjNom)}`) || [];
}

async function sbMarquerSouvenirRevele(souvenirId) {
  return sbUpdate('souvenirs_accueil', `id=eq.${souvenirId}`, { revele: true });
}

// =====================
// ORGANISATIONS (structure plate, prepare le multi-empire)
// =====================
async function sbSaveOrganisation(orga) {
  const data = { id: orga.id, country_origine: orga.country_origine || orga.country, data: JSON.stringify(orga) };
  const existing = await sbGet('organisations', `id=eq.${encodeURIComponent(orga.id)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('organisations', `id=eq.${encodeURIComponent(orga.id)}`, data);
  } else {
    return sbInsert('organisations', data);
  }
}

async function sbLoadOrganisations() {
  const rows = await sbGet('organisations', 'select=*');
  if (!rows) return [];
  return rows.map(r => { try { return JSON.parse(r.data); } catch(e) { return null; } }).filter(Boolean);
}

async function sbDeleteOrganisation(orgaId) {
  return sbDelete('organisations', `id=eq.${encodeURIComponent(orgaId)}`);
}

// =====================
// PLAINTES EN COURS (commissariat/tribunal, partage entre joueurs)
// =====================
async function sbSavePlainte(plainte) {
  const data = { id: plainte.id, country: plainte.country || 'republic', city: plainte.city || null, data: JSON.stringify(plainte) };
  const existing = await sbGet('plaintes_en_cours', `id=eq.${encodeURIComponent(plainte.id)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('plaintes_en_cours', `id=eq.${encodeURIComponent(plainte.id)}`, data);
  } else {
    return sbInsert('plaintes_en_cours', data);
  }
}

async function sbLoadPlaintes(country) {
  const filtre = country ? `country=eq.${encodeURIComponent(country)}` : 'select=*';
  const rows = await sbGet('plaintes_en_cours', filtre);
  if (!rows) return [];
  return rows.map(r => { try { return JSON.parse(r.data); } catch(e) { return null; } }).filter(Boolean);
}

async function sbDeletePlainte(plainteId) {
  return sbDelete('plaintes_en_cours', `id=eq.${encodeURIComponent(plainteId)}`);
}

// =====================
// OBJETS ABANDONNES DANS UNE PIECE (visibles/ramassables par d'autres joueurs)
// =====================
async function sbAbandonnerObjet(objet, country, city, buildingId, roomId) {
  const data = { id: objet.id, country, city, building_id: buildingId, room_id: roomId, data: JSON.stringify(objet) };
  return sbInsert('objets_abandonnes', data);
}

async function sbGetObjetsAbandonnesDansPiece(country, city, buildingId, roomId) {
  const filtre = `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&building_id=eq.${encodeURIComponent(buildingId)}&room_id=eq.${encodeURIComponent(roomId)}`;
  const rows = await sbGet('objets_abandonnes', filtre);
  if (!rows) return [];
  return rows.map(r => { try { return JSON.parse(r.data); } catch(e) { return null; } }).filter(Boolean);
}

async function sbRamasserObjetAbandonne(objetId) {
  return sbDelete('objets_abandonnes', `id=eq.${encodeURIComponent(objetId)}`);
}

// =====================
// DEMANDES DE NATURALISATION
// =====================
async function sbCreerDemandeNaturalisation(demande) {
  return sbInsert('demandes_naturalisation', demande);
}

async function sbGetDemandesNaturalisationPour(paysVise) {
  return sbGet('demandes_naturalisation', `pays_vise=eq.${encodeURIComponent(paysVise)}&statut=eq.pending&order=created_at.asc`);
}

async function sbTraiterDemandeNaturalisation(id, statut) {
  return sbUpdate('demandes_naturalisation', `id=eq.${encodeURIComponent(id)}`, { statut });
}

// =====================
// VOLS EN ATTENTE (vol effectif sur un vrai joueur, applique a sa prochaine connexion)
// =====================
async function sbDeposerVol(vol) {
  return sbInsert('vols_en_attente', vol);
}

async function sbRecupererVolsEnAttente(victime) {
  const filtre = `victime=eq.${encodeURIComponent(victime)}&traite=eq.false`;
  return sbGet('vols_en_attente', filtre) || [];
}

async function sbMarquerVolTraite(volId) {
  return sbUpdate('vols_en_attente', `id=eq.${encodeURIComponent(volId)}`, { traite: true });
}

// =====================
// ACTIONS TRACABLES (pour le systeme de rumeurs vraies)
// =====================
async function sbCreerDemandeManifestation(data) {
  const id = 'manif-' + Date.now() + '-' + Math.floor(Math.random()*10000);
  await sbInsert('demandes_manifestation', { id, statut: 'attente', data });
  return id;
}

async function sbGetDemandeManifestationParId(id) {
  if (!id) return null;
  const rows = await sbGet('demandes_manifestation', `id=eq.${encodeURIComponent(id)}`);
  if (!rows || rows.length === 0) return null;
  return { statut: rows[0].statut, ...rows[0].data };
}

async function sbGetDemandesManifestationAutorisees(pays) {
  const rows = await sbGet('demandes_manifestation', `statut=eq.autorisee&select=id,data`);
  if (!rows) return [];
  return rows.filter(r => r.data?.pays === pays && !r.data?.effetApplique).map(r => ({ id: r.id, ...r.data }));
}

async function sbGetDemandesManifestationPays(pays) {
  const rows = await sbGet('demandes_manifestation', `statut=eq.attente&select=id,data`);
  if (!rows) return [];
  return rows.filter(r => r.data?.pays === pays).map(r => ({ id: r.id, ...r.data }));
}

async function sbMajDemandeManifestation(id, statut, patch) {
  const rows = await sbGet('demandes_manifestation', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...(rows?.[0]?.data || {}), ...(patch || {}) };
  return sbUpdate('demandes_manifestation', `id=eq.${encodeURIComponent(id)}`, { statut, data });
}

async function sbCreerDemandeGrace(data) {
  const id = 'grace-' + Date.now() + '-' + Math.floor(Math.random()*10000);
  await sbInsert('demandes_grace', { id, statut: 'attente', data });
  return id;
}

async function sbGetDemandesGracePays(pays) {
  const rows = await sbGet('demandes_grace', 'statut=eq.attente&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.pays === pays).map(r => ({ id: r.id, ...r.data }));
}

async function sbMajDemandeGrace(id, statut) {
  return sbUpdate('demandes_grace', `id=eq.${encodeURIComponent(id)}`, { statut });
}

async function sbGetGuerresPays(pays) {
  const rows = await sbGet('guerres', 'statut=neq.terminee&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.attaquant === pays || r.data?.attaque === pays).map(r => ({ id: r.id, ...r.data }));
}

// =====================
// FILE D'ATTENTE DIPLOMATIQUE GENERIQUE
// Reutilisee par : signer un traite, ouvrir des negociations. Meme schema propose/accepte/refuse
// que les guerres ci-dessus, mais generalise a n'importe quel type d'accord diplomatique.
// =====================
async function sbGetPropositionsDiplomatiques(pays) {
  const rows = await sbGet('propositions_diplomatiques', 'statut=eq.en_attente&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.empireProposeur === pays || r.data?.empireCible === pays).map(r => ({ id: r.id, ...r.data }));
}

async function sbCreerPropositionDiplomatique(data) {
  const id = 'diplo-' + Date.now();
  await sbInsert('propositions_diplomatiques', { id, statut: 'en_attente', data });
  return id;
}

async function sbMajPropositionDiplomatique(id, patch) {
  const rows = await sbGet('propositions_diplomatiques', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...(rows?.[0]?.data || {}), ...patch };
  return sbUpdate('propositions_diplomatiques', `id=eq.${encodeURIComponent(id)}`, { statut: patch.statut || rows?.[0]?.statut || 'en_attente', data });
}

// =====================
// AMBASSADES OUVERTES (partagees) — pays_hote = pays qui accueille physiquement le bureau,
// empire = pays dont l'ambassadeur y siege.
// =====================
async function sbGetAmbassadesOuvertes(paysHote) {
  const rows = await sbGet('ambassades_ouvertes', `pays_hote=eq.${encodeURIComponent(paysHote)}&select=id,data`);
  return rows || [];
}

async function sbOuvrirAmbassade(paysHote, empire, jour) {
  const id = paysHote + '-' + empire;
  const existants = await sbGet('ambassades_ouvertes', `id=eq.${encodeURIComponent(id)}`);
  if (existants && existants.length > 0) return existants[0];
  return sbInsert('ambassades_ouvertes', { id, pays_hote: paysHote, empire, data: { empire, jour } });
}

// Nomme un ambassadeur pour une ambassade deja ouverte — met a jour le champ "ambassadeur"
// de la meme ligne, pour permettre de restreindre les ordres du bureau a cette seule personne.
async function sbNommerAmbassadeur(paysHote, empire, nomAmbassadeur) {
  const id = paysHote + '-' + empire;
  const rows = await sbGet('ambassades_ouvertes', `id=eq.${encodeURIComponent(id)}`);
  if (!rows || rows.length === 0) return null;
  const data = { ...(rows[0].data || {}), ambassadeur: nomAmbassadeur };
  return sbUpdate('ambassades_ouvertes', `id=eq.${encodeURIComponent(id)}`, { data });
}

// Renvoi d'un ambassadeur — ancien mécanisme, conservé pour compatibilité mais plus utilisé
// directement (voir sbFixerEcheanceExpulsion pour la vraie expulsion avec délai de 24h).
async function sbRenvoyerAmbassadeur(paysHote, empire) {
  return sbNommerAmbassadeur(paysHote, empire, null);
}

// =====================
// ARCHIVE PARTAGEE DES LOIS DE L'ASSEMBLEE (retention 1 an)
// Remplace l'ancien systeme purement local (state.archivesLois), qui n'etait jamais alimente
// et ne reflétait de toute facon que la session d'un seul joueur, pas un vrai historique
// collectif de l'Assemblee.
// =====================
async function sbArchiverLoi(country, loiData) {
  const id = loiData.id;
  const existant = await sbGet('lois_assemblee', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...loiData };
  if (existant && existant.length > 0) {
    return sbUpdate('lois_assemblee', `id=eq.${encodeURIComponent(id)}`, { data });
  }
  return sbInsert('lois_assemblee', { id, country, data });
}

async function sbGetArchivesLois(country) {
  const rows = await sbGet('lois_assemblee', `country=eq.${encodeURIComponent(country)}&select=id,data`);
  return (rows || []).map(r => r.data);
}

// =====================
// MILITANTS RECRUTES (Universite, amphi) — plafond 2 par joueur, prepare les manifestations
// =====================
async function sbRecruterMilitant(country, recruteur, nomPnj) {
  const id = 'militant-' + Date.now();
  return sbInsert('militants_recrutes', { id, country, recruteur, data: { nom: nomPnj, jour: Date.now() } });
}

async function sbGetMesMilitants(country, recruteur) {
  const rows = await sbGet('militants_recrutes', `country=eq.${encodeURIComponent(country)}&recruteur=eq.${encodeURIComponent(recruteur)}`);
  return (rows || []).map(r => r.data);
}

// =====================
// MESSAGERIE PERSISTANTE (conversations privees + salons nommes)
// Remplace le chat lie a une piece physique : ici, une conversation existe independamment
// du lieu et de la connexion des participants. Une conversation privee est identifiee par
// les 2 noms tries alphabetiquement ; un salon est identifie par son propre id.
// =====================

function getConversationId(nom1, nom2) {
  return [nom1, nom2].sort().join('__');
}

async function sbEnvoyerMessageChat(conversationId, auteur, message, estSalon) {
  const id = 'msg-' + Date.now() + '-' + Math.random().toString(36).slice(2, 7);
  return sbInsert('messages_chat', {
    id, conversation_id: conversationId, auteur, message,
    salon: !!estSalon, created_at: new Date().toISOString()
  });
}

async function sbGetMessagesConversation(conversationId, depuis) {
  let filtre = `conversation_id=eq.${encodeURIComponent(conversationId)}&order=created_at.asc`;
  if (depuis) filtre += `&created_at=gt.${encodeURIComponent(depuis)}`;
  return await sbGet('messages_chat', filtre) || [];
}

async function sbCreerSalon(nom, createur) {
  const id = 'salon-' + nom.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').slice(0, 50) + '-' + Date.now().toString(36);
  await sbInsert('salons_chat', { id, nom, createur, created_at: new Date().toISOString() });
  await sbRejoindreSalon(id, createur);
  return id;
}

async function sbRejoindreSalon(salonId, membre) {
  const existant = await sbGet('salons_membres', `salon_id=eq.${encodeURIComponent(salonId)}&membre=eq.${encodeURIComponent(membre)}`);
  if (existant && existant.length > 0) return;
  return sbInsert('salons_membres', { id: salonId + '__' + membre, salon_id: salonId, membre });
}

async function sbQuitterSalon(salonId, membre) {
  return sbDelete('salons_membres', `salon_id=eq.${encodeURIComponent(salonId)}&membre=eq.${encodeURIComponent(membre)}`);
}

async function sbGetMesSalons(membre) {
  const memberships = await sbGet('salons_membres', `membre=eq.${encodeURIComponent(membre)}`);
  if (!memberships || memberships.length === 0) return [];
  const salons = [];
  for (const m of memberships) {
    const rows = await sbGet('salons_chat', `id=eq.${encodeURIComponent(m.salon_id)}`);
    if (rows && rows[0]) salons.push(rows[0]);
  }
  return salons;
}

async function sbGetMembresSalon(salonId) {
  const rows = await sbGet('salons_membres', `salon_id=eq.${encodeURIComponent(salonId)}`);
  return (rows || []).map(r => r.membre);
}

// Marque une conversation comme lue jusqu'a maintenant, pour ce joueur
async function sbMarquerConversationLue(conversationId, membre) {
  const id = conversationId + '__' + membre;
  const maintenant = new Date().toISOString();
  const existant = await sbGet('lectures_chat', `id=eq.${encodeURIComponent(id)}`);
  const data = { id, conversation_id: conversationId, membre, dernier_lu: maintenant };
  if (existant && existant.length > 0) return sbUpdate('lectures_chat', `id=eq.${encodeURIComponent(id)}`, data);
  return sbInsert('lectures_chat', data);
}

// Verifie s'il existe au moins un message non lu, dans une conversation privee OU un salon
// dont le joueur fait partie — sert au point clignotant, persiste au-dela de la deconnexion.
async function sbAMessagesNonLus(membre) {
  try {
    const tousMessages = await sbGet('messages_chat', `order=created_at.desc&limit=200`);
    const mesSalons = await sbGetMesSalons(membre);
    const idsSalons = new Set(mesSalons.map(s => s.id));
    const mesConversations = new Set(
      (tousMessages || [])
        .map(m => m.conversation_id)
        .filter(cid => cid.split('__').includes(membre) || idsSalons.has(cid))
    );
    for (const cid of mesConversations) {
      const lecture = await sbGet('lectures_chat', `id=eq.${encodeURIComponent(cid + '__' + membre)}`);
      const dernierLu = lecture?.[0]?.dernier_lu || null;
      const messagesConv = (tousMessages || []).filter(m => m.conversation_id === cid && m.auteur !== membre);
      if (messagesConv.length === 0) continue;
      const dernierMessage = messagesConv[0];
      if (!dernierLu || new Date(dernierMessage.created_at) > new Date(dernierLu)) {
        return true;
      }
    }
    return false;
  } catch (e) { console.warn('sbAMessagesNonLus error', e); return false; }
}

// =====================
// LOCATIONS ACTIVES (bail de salle/local) — n'avait jusqu'ici AUCUNE sauvegarde Supabase,
// purement local et perdu au rafraichissement (contrairement aux organisations qui l'ont deja).
// =====================
async function sbSaveLocation(location) {
  const id = location.buildingId + ':' + location.roomId;
  const data = { id, country: location.country, data: location };
  const existing = await sbGet('locations_actives', `id=eq.${encodeURIComponent(id)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('locations_actives', `id=eq.${encodeURIComponent(id)}`, data);
  }
  return sbInsert('locations_actives', data);
}

async function sbLoadLocations(country) {
  const rows = await sbGet('locations_actives', `country=eq.${encodeURIComponent(country)}`);
  return (rows || []).map(r => r.data);
}

async function sbSupprimerLocation(buildingId, roomId) {
  const id = buildingId + ':' + roomId;
  return sbDelete('locations_actives', `id=eq.${encodeURIComponent(id)}`);
}

// =====================
// RESERVATION DE LA SALLE DE RECEPTION (Quartier des Ambassades)
// Une seule reservation possible par jour et par pays hote — evite que 2 ambassades
// organisent un evenement le meme jour dans la meme salle commune.
// =====================
async function sbGetReservationSalle(paysHote, jour) {
  const id = paysHote + '-' + jour;
  const rows = await sbGet('reservations_salle_reception', `id=eq.${encodeURIComponent(id)}`);
  return rows?.[0] || null;
}

async function sbReserverSalleReception(paysHote, jour, empireReservant, reservePar) {
  const id = paysHote + '-' + jour;
  const existant = await sbGetReservationSalle(paysHote, jour);
  if (existant) return { ok: false, existant };
  await sbInsert('reservations_salle_reception', { id, pays_hote: paysHote, jour, data: { empire: empireReservant, reservePar } });
  return { ok: true };
}

// Expulsion avec delai : garde l'ambassadeur en poste, ajoute juste une echeance. La verification
// (arrestation automatique si l'echeance est depassee) doit se faire au passage au jour suivant.
async function sbFixerEcheanceExpulsion(paysHote, empire, jourEcheance) {
  const id = paysHote + '-' + empire;
  const rows = await sbGet('ambassades_ouvertes', `id=eq.${encodeURIComponent(id)}`);
  if (!rows || rows.length === 0) return null;
  const data = { ...(rows[0].data || {}), expulsionEcheance: jourEcheance };
  return sbUpdate('ambassades_ouvertes', `id=eq.${encodeURIComponent(id)}`, { data });
}

async function sbCreerGuerre(data) {
  const id = 'guerre-' + Date.now();
  await sbInsert('guerres', { id, statut: 'active', data });
  return id;
}

async function sbMajGuerre(id, patch) {
  const rows = await sbGet('guerres', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...(rows?.[0]?.data || {}), ...patch };
  return sbUpdate('guerres', `id=eq.${encodeURIComponent(id)}`, { statut: data.statut || 'active', data });
}

async function sbGetCompagnies(pays) {
  const rows = await sbGet('compagnies_militaires', `select=id,data`);
  if (!rows) return [];
  return rows.filter(r => r.data?.pays === pays).map(r => ({ id: r.id, ...r.data }));
}

async function sbCreerPrisonnierQHS(data) {
  const id = 'qhs-' + Date.now() + '-' + Math.floor(Math.random()*10000);
  await sbInsert('prisonniers_qhs', { id, statut: 'detenu', data });
  return id;
}

async function sbGetPrisonniersQHS(pays) {
  const rows = await sbGet('prisonniers_qhs', `statut=eq.detenu&select=id,data`);
  if (!rows) return [];
  return rows.filter(r => r.data?.pays === pays).map(r => ({ id: r.id, ...r.data }));
}

async function sbMajPrisonnierQHS(id, statut, patch) {
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...(rows?.[0]?.data || {}), ...(patch || {}) };
  return sbUpdate('prisonniers_qhs', `id=eq.${encodeURIComponent(id)}`, { statut, data });
}

async function sbCreerRapportRenseignement(data) {
  const id = 'rens-' + Date.now();
  await sbInsert('rapports_renseignement', { id, data });
  return id;
}

async function sbGetRapportsRenseignementNonRemontes(lieutenantNom) {
  const rows = await sbGet('rapports_renseignement', `select=id,data`);
  if (!rows) return [];
  return rows.filter(r => r.data?.lieutenantNom === lieutenantNom && !r.data?.remonte).map(r => ({ id: r.id, ...r.data }));
}

async function sbMarquerRapportRemonte(id) {
  const rows = await sbGet('rapports_renseignement', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...(rows?.[0]?.data || {}), remonte: true };
  return sbUpdate('rapports_renseignement', `id=eq.${encodeURIComponent(id)}`, { data });
}

async function sbCreerEngagement(data) {
  const id = 'engagement-' + Date.now();
  await sbInsert('engagements_militaires', { id, statut: 'attente_commandant', data });
  return id;
}

async function sbGetEngagementsPays(pays, statut) {
  const rows = await sbGet('engagements_militaires', `statut=eq.${encodeURIComponent(statut)}&select=id,data`);
  if (!rows) return [];
  return rows.filter(r => r.data?.pays === pays).map(r => ({ id: r.id, ...r.data }));
}

async function sbMajEngagement(id, statut, patch) {
  const rows = await sbGet('engagements_militaires', `id=eq.${encodeURIComponent(id)}`);
  const data = { ...(rows?.[0]?.data || {}), ...(patch || {}) };
  return sbUpdate('engagements_militaires', `id=eq.${encodeURIComponent(id)}`, { statut, data });
}

async function sbCreerFaitArmes(data) {
  const id = 'combat-' + Date.now();
  await sbInsert('faits_armes', { id, data });
  return id;
}

async function sbGetFaitsArmes() {
  const rows = await sbGet('faits_armes', 'select=id,data&order=created_at.desc&limit=30');
  if (!rows) return [];
  return rows.map(r => ({ id: r.id, ...r.data }));
}

async function sbSaveCompagnie(id, data) {
  const existing = await sbGet('compagnies_militaires', `id=eq.${encodeURIComponent(id)}`);
  if (existing && existing.length > 0) return sbUpdate('compagnies_militaires', `id=eq.${encodeURIComponent(id)}`, { data });
  return sbInsert('compagnies_militaires', { id, data });
}

async function sbCreerRumeurPolitique(data) {
  const id = 'rumeur-' + Date.now() + '-' + Math.floor(Math.random()*10000);
  await sbInsert('rumeurs_actives', { id, resolu: false, data });
  return id;
}

async function sbGetRumeursActivesCible(cible) {
  const rows = await sbGet('rumeurs_actives', 'resolu=eq.false&select=id,data');
  if (!rows) return [];
  return rows.filter(r => r.data?.cible === cible).map(r => ({ id: r.id, ...r.data }));
}

async function sbResoudreRumeur(id) {
  return sbUpdate('rumeurs_actives', `id=eq.${encodeURIComponent(id)}`, { resolu: true });
}

async function sbAjusterPopJoueur(nomJoueur, delta) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=pop`);
  const popActuel = rows?.[0]?.pop ?? 50;
  const nouveauPop = Math.max(0, Math.min(100, popActuel + delta));
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomJoueur)}`, { pop: nouveauPop });
  return nouveauPop;
}

// =====================
// INVITATIONS A DINER (diner d'affaires entre PJ presents dans la meme piece)
// =====================
async function sbCreerInvitationDiner(inviteur, invite, country, city, buildingId, roomId, cout, type) {
  return sbInsert('invitations_diner', {
    inviteur, invite, country, city,
    building_id: buildingId, room_id: roomId,
    statut: 'attente', cout, type: type || 'diner_affaires'
  });
}

async function sbGetInvitationsDinerRecues(nomJoueur) {
  const filtre = `invite=eq.${encodeURIComponent(nomJoueur)}&statut=eq.attente`;
  return sbGet('invitations_diner', filtre) || [];
}

async function sbGetInvitationsDinerTraitees(nomInviteur, nomInvite) {
  const filtre = `inviteur=eq.${encodeURIComponent(nomInviteur)}&invite=eq.${encodeURIComponent(nomInvite)}&statut=neq.attente`;
  return sbGet('invitations_diner', filtre) || [];
}

async function sbRepondreInvitationDiner(id, accepte) {
  return sbUpdate('invitations_diner', `id=eq.${id}`, { statut: accepte ? 'acceptee' : 'refusee' });
}

async function sbSupprimerInvitationDiner(id) {
  return sbDelete('invitations_diner', `id=eq.${id}`);
}

async function sbTracerAction(action) {
  return sbInsert('actions_tracables', action);
}

async function sbGetActionsTracables(country, city, jourActuel) {
  const filtre = `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&jour_expiration=gte.${jourActuel}`;
  return sbGet('actions_tracables', filtre) || [];
}

// Recherche par auteur (peu importe la ville) — utilisee pour verifier si une accusation
// (plainte/enquete) repose sur une action reellement tracee, ex: torture au QHS.
async function sbGetActionsTracablesParAuteur(country, auteur, typeAction, jourActuel) {
  const filtre = `country=eq.${encodeURIComponent(country)}&auteur=eq.${encodeURIComponent(auteur)}&type_action=eq.${encodeURIComponent(typeAction)}&jour_expiration=gte.${jourActuel}`;
  return sbGet('actions_tracables', filtre) || [];
}

// =====================
// IMPACTS D'INDICES EN ATTENTE (generique, applique a la victime a sa prochaine connexion)
// =====================
async function sbDeposerImpactIndice(impact) {
  return sbInsert('impacts_indices_attente', impact);
}

async function sbRecupererImpactsEnAttente(victime) {
  const filtre = `victime=eq.${encodeURIComponent(victime)}&traite=eq.false`;
  return sbGet('impacts_indices_attente', filtre) || [];
}

async function sbMarquerImpactTraite(impactId) {
  return sbUpdate('impacts_indices_attente', `id=eq.${encodeURIComponent(impactId)}`, { traite: true });
}

// =====================
// QUETES ACTIVES (animation plateau)
// =====================
async function sbGetQueteActive(country) {
  const rows = await sbGet('quetes_actives', `country=eq.${encodeURIComponent(country)}&statut=eq.active`);
  return (rows && rows.length > 0) ? rows[0] : null;
}

async function sbCreerQuete(quete) {
  return sbInsert('quetes_actives', quete);
}

async function sbMettreAJourQuete(queteId, data) {
  return sbUpdate('quetes_actives', `id=eq.${encodeURIComponent(queteId)}`, data);
}

async function sbGetDerniereQueteResolue(country) {
  const rows = await sbGet('quetes_actives', `country=eq.${encodeURIComponent(country)}&statut=eq.resolue&order=created_at.desc&limit=1`);
  return (rows && rows.length > 0) ? rows[0] : null;
}

// =====================
// ETAT DES TERRAINS A BATIR (proprietaire, squatteurs, etc.) - persiste reellement
// =====================
async function sbSetTerrainState(country, buildingId, etat) {
  const data = {
    id: country + '_' + buildingId,
    country, building_id: buildingId,
    proprietaire: etat.proprietaire || null,
    data: JSON.stringify(etat),
    updated_at: new Date().toISOString()
  };
  const existing = await sbGet('terrains_etat', `id=eq.${encodeURIComponent(data.id)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(data.id)}`, data);
  } else {
    return sbInsert('terrains_etat', data);
  }
}

async function sbGetTerrainState(country, buildingId) {
  const rows = await sbGet('terrains_etat', `id=eq.${encodeURIComponent(country + '_' + buildingId)}`);
  if (!rows || rows.length === 0) return null;
  try { return JSON.parse(rows[0].data); } catch(e) { return null; }
}

async function sbGetTerrainsLibres(country) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}`);
  return rows || [];
}

// =====================
// CHAT EN PIECE (messages ephemeres entre PJ presents)
// =====================
async function sbEnvoyerMessageChatPiece(message) {
  return sbInsert('chat_piece', message);
}

async function sbGetMessagesChatPiece(country, city, buildingId, roomId, depuisTimestamp) {
  let filtre = `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&building_id=eq.${encodeURIComponent(buildingId)}&room_id=eq.${encodeURIComponent(roomId)}&order=created_at.asc`;
  if (depuisTimestamp) filtre += `&created_at=gt.${encodeURIComponent(depuisTimestamp)}`;
  return sbGet('chat_piece', filtre) || [];
}
