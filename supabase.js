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

// preferResolution (optionnel, Lot 4 -- cartes postales, 23 aout 2026) : ajoute
// "resolution=<valeur>" au Prefer PostgREST (ex. 'ignore-duplicates', equivalent a
// ON CONFLICT DO NOTHING). Retrocompatible : tous les appelants existants (dizaines, deux
// arguments) gardent exactement le meme comportement, seul un appel a 3 arguments est affecte.
async function sbInsert(table, data, preferResolution) {
  const prefer = preferResolution ? `return=representation,resolution=${preferResolution}` : 'return=representation';
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...SB_HEADERS, 'Prefer': prefer },
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
// File d'attente de sauvegarde personnage (22 aout 2026, correctif audit PA) : sbSavePersonnage()
// est appelee ~50 fois dans le projet, la plupart en "tire-et-oublie" (.catch(() => {}), jamais
// await). Chaque appel capture `data` de facon SYNCHRONE (avant tout await, voir plus bas) --
// donc un appel plus tardif capture toujours un state.pa au moins aussi frais qu'un appel
// anterieur (JS mono-thread, rien d'autre ne peut muter state entre deux appels synchrones). Le
// bug reel n'etait donc jamais la capture, mais l'ORDRE D'ARRIVEE en base : sans coordination,
// rien ne garantit qu'une ecriture lancee plus tot (donnees plus anciennes) ne termine pas APRES
// une ecriture lancee plus tard (donnees plus fraiches), l'ecrasant silencieusement (cas
// demontre dans doDormir() : sauvegarderPersonnageImmediat() ligne ~1561, non awaited, capture
// AVANT la recuperation de PA, contre l'ecriture correcte de fin de fonction).
//
// Correctif : sbSaveQueue serialise uniquement l'ECRITURE RESEAU (sbEcrirePersonnage), jamais la
// capture -- chaque appel de sbSavePersonnage() est chaine APRES la fin du precedent, quel que
// soit l'ordre dans lequel les requetes HTTP repondraient naturellement. Les ecritures atteignent
// donc Supabase strictement dans l'ordre des APPELS, jamais dans l'ordre des reponses reseau.
// sbSaveQueue est toujours reaffectee via .catch(() => {}) : un echec ne bloque jamais les
// ecritures suivantes. AUCUN appelant existant n'est modifie -- sbSavePersonnage() garde exactement
// la meme signature et retourne toujours une Promise qui reflete le succes/echec de SA PROPRE
// ecriture (jamais celui d'une autre, deja en file ou suivante).
let sbSaveQueue = Promise.resolve();

async function sbEcrirePersonnage(data) {
  const existing = await sbGet('personnages', `name=eq.${encodeURIComponent(data.name)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('personnages', `name=eq.${encodeURIComponent(data.name)}`, data);
  } else {
    return sbInsert('personnages', data);
  }
}

// Garde de bootstrap (lot du 25 aout 2026, correctif generique de concurrence client/serveur) :
// tant que loadCharacter() n'a pas fini de reconcilier state.char avec Supabase
// (state.personnageChargeDepuisServeur === false, jamais undefined -- voir loadCharacter,
// plateau-core.js), aucune sauvegarde ne doit pouvoir ecraser un etat serveur potentiellement
// plus recent avec une copie localStorage perimee. Point unique et central : TOUS les appelants
// (sauvegarderPersonnageImmediat, enterRoom, sbAutoSave/updateUI...) passent par cette seule
// fonction, jamais par un chemin d'ecriture parallele. Fail-open par defaut : seule une valeur
// explicitement false bloque (flag absent/undefined = autorise, comportement inchange partout
// ailleurs qu'au tout debut du chargement de page).
// INSTRUMENTATION TEMPORAIRE (diagnostic licence Arnie, 25 aout 2026) -- A RETIRER une fois la
// cause identifiee. Consigne CHAQUE appel de sbSavePersonnage pour Arnie (bloque ou non par la
// garde de bootstrap ci-dessous) dans batiments_etat (store generique deja existant, aucune
// migration, cle dediee 'debug'/'debug'/'licence-arnie') : horodatage, valeur de
// licenceSportive au moment de l'appel, etat du flag de bootstrap, position, et pile d'appel
// JS -- pour identifier factuellement l'appelant reel, sans dependre des DevTools du joueur.
// Fire-and-forget, ne bloque et ne modifie jamais le comportement reel de la sauvegarde.
async function instrumenterAppelSavePersonnage(charState) {
  try {
    if (charState.char?.name !== 'Arnie') return;
    if (typeof sbGetBatimentEtat !== 'function' || typeof sbSetBatimentEtat !== 'function') return;
    const etatDebug = await sbGetBatimentEtat('debug', 'debug', 'licence-arnie').catch(() => ({}));
    const breadcrumbs = Array.isArray(etatDebug.breadcrumbs) ? etatDebug.breadcrumbs : [];
    breadcrumbs.push({
      ts: new Date().toISOString(),
      bloque_par_bootstrap: charState.personnageChargeDepuisServeur === false,
      licenceSportive: charState.char?.licenceSportive || null,
      currentBuilding: charState.currentBuilding || null,
      currentRoom: charState.currentRoom || null,
      currentCity: charState.currentCity || null,
      stack: (new Error('trace_sbSavePersonnage')).stack || null
    });
    if (breadcrumbs.length > 40) breadcrumbs.splice(0, breadcrumbs.length - 40);
    await sbSetBatimentEtat('debug', 'debug', 'licence-arnie', { breadcrumbs }).catch(() => {});
  } catch (e) {}
}

async function sbSavePersonnage(charState) {
  instrumenterAppelSavePersonnage(charState); // temporaire, voir commentaire ci-dessus -- fire-and-forget, n'attend jamais son resultat
  if (charState.personnageChargeDepuisServeur === false) return;
  const photoKey = 'respublica_photo_' + (charState.char?.name || 'default');
  const savedPhoto = (typeof localStorage !== 'undefined') ? localStorage.getItem(photoKey) : null;
  const data = {
    name:             charState.char?.name,
    country:          charState.country,
    photo_url:        savedPhoto || charState.char?.photoUrl || null,
    bio:              charState.char?.bio || null,
    archetype:        charState.char?.archetype,
    career:           charState.char?.career,
    // origin/school (bêta, P0) : jamais écrits jusqu'ici -- perte de données silencieuse
    // confirmée par l'audit (aucune colonne dédiée n'existait même côté base, vérifié en
    // direct -- voir migration_origin_school_freepts.sql, à exécuter manuellement une fois
    // avant que ce correctif ne prenne réellement effet).
    origin:           charState.char?.origin || null,
    school:           charState.char?.school || null,
    free_pts_restants: charState.char?.freePtsRestants || 0,
    stats:            charState.char?.stats,
    resources:        { inf: charState.inf, pop: charState.pop, dis: charState.dis },
    arg:              charState.arg || 0,
    liquide:          charState.liquide || 0,
    banque:           charState.banque || 0,
    hp:               charState.hp || 100,
    pa:               (typeof charState.pa === 'number') ? charState.pa : 10,
    moral:            charState.moral || 75,
    poste:            charState.poste || null,
    poste_depute:     charState.posteDepute || null,
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
    escort_active:    charState.escortActive || [],
    locations_actives: charState.locationsActives || [],
    poison_actif:     charState.poisonActif || null,
    day:              charState.day || 1,
    recherche:        charState.recherche || [],
    reputation_criminelle: charState.reputationCriminelle || 0,
    salutations_du_jour: charState.salutationsDuJour || null,
    invitation_sociale_en_attente: charState._invitationSocialeEnAttente || null,
    convocations:     charState.convocations || [],
    est_emprisonne:   charState.estEmprisonne || null,
    // Plafonds quotidiens Moral des cartes postales (Lot 4, 23 aout 2026) : meme motif que
    // salutations_du_jour ci-dessus (une colonne dediee, jamais une cle ajoutee a un state.*
    // implicitement suppose persiste). {lecteur, expediteur} : date reelle Europe/Paris
    // (dateReelleParisStr, plateau-core.js) de la derniere occurrence de chaque bonus, ou null.
    // AUDIT (23 aout 2026) : sans cette colonne, ces deux plafonds n'etaient QUE des state.*
    // en memoire, jamais retournes par cette fonction -- perdus a chaque refresh/reconnexion,
    // plafond quotidien entierement contournable. Colonne a creer manuellement, voir
    // migration_carte_postale.sql -- absente tant que la migration n'a pas ete executee.
    carte_postale_moral_jour: charState.cartePostaleMoralJour || null,
    motto:            charState.char?.motto || null,
    licence_sportive: charState.char?.licenceSportive || null,
    performance_sportive: charState.char?.performance || null,
    blessure_sportive: charState.char?.blessureSportive || null,
    signature_html:   charState.char?.signatureHtml || null,
    signature_blocks: charState.char?.signatureBlocks || [],
    quete_accueil:    charState.char?.queteAccueil || null,
    enigme1:          charState.char?.enigme1 || null,
    maxence:          charState.char?.maxence || null,
    succes_maxence:   charState.char?.succesMaxence || null,
    journal:          charState.char?.journal || [],
    updated_at:       new Date().toISOString()
  };

  // `data` est fige ici, de facon synchrone (avant tout await) -- voir le commentaire de
  // sbSaveQueue plus haut. La file ne retarde que l'ECRITURE, jamais cette capture.
  const tache = sbSaveQueue.then(() => sbEcrirePersonnage(data));
  sbSaveQueue = tache.catch(() => {}); // ne bloque jamais la file suite a un echec
  return tache;
}

async function sbLoadPersonnage(name) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(name)}`);
  if (!rows || rows.length === 0) return null;
  const r = rows[0];
  return {
    char: { name: r.name, archetype: r.archetype, career: r.career,
             origin: r.origin || null, school: r.school || null, freePtsRestants: r.free_pts_restants || 0,
             stats: r.stats,
             // Restauration de createdAt (correctif audit du 20 aout 2026) : ce mapping manquait
             // -- state.char.createdAt redevenait undefined a chaque synchronisation Supabase
             // (loadCharacter ecrase state.char avec cet objet), cassant silencieusement le
             // declenchement de enigme1VerifierDeclenchement() des la premiere synchro de chaque
             // session. personnages.created_at (colonne Postgres native, jamais reecrite) est la
             // seule source fiable -- aucune nouvelle colonne, deja utilisee ailleurs (voir
             // etatCivilChargerJoueurs, plateau-etat-civil.js).
             createdAt: r.created_at || null,
             photoUrl: r.photo_url || null, bio: r.bio || null, poste: r.poste || null, posteDepute: r.poste_depute || null,
             country: r.country, currentCity: r.current_city, currentBuilding: r.current_building,
             currentRoom: r.current_room || null, motto: r.motto || null,
             licenceSportive: r.licence_sportive || null, performance: r.performance_sportive || null, blessureSportive: r.blessure_sportive || null,
             signatureHtml: r.signature_html || null, signatureBlocks: r.signature_blocks || [],
             queteAccueil: r.quete_accueil || null, enigme1: r.enigme1 || null, maxence: r.maxence || null, succesMaxence: r.succes_maxence || null,
             journal: r.journal || [] },
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
    posteDepute:   r.poste_depute || null,
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
    escortActive:  r.escort_active || [],
    locationsActives: r.locations_actives || [],
    poisonActif:   r.poison_actif,
    day:           r.day,
    recherche:     r.recherche || [],
    reputationCriminelle: r.reputation_criminelle || 0,
    salutationsDuJour: r.salutations_du_jour || null,
    _invitationSocialeEnAttente: r.invitation_sociale_en_attente || null,
    convocations:  r.convocations || [],
    estEmprisonne: r.est_emprisonne || null,
    cartePostaleMoralJour: r.carte_postale_moral_jour || null
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

// Voyant d'activite forum (17 aout 2026) : horodatage du contenu forum le plus recent, tous
// forums confondus (nouveaux sujets ET nouvelles reponses, jamais une simple edition puisque
// created_at ne change pas a l'edition -- exactement la distinction demandee). Volontairement
// GLOBAL, non filtre par pays : forum_posts n'a pas de colonne country (verifie, seul
// forum_topics en a une), et une jointure aurait ajoute une complexite disproportionnee pour
// une V1 -- simplification assumee et documentee (un post dans un autre empire peut en theorie
// allumer le voyant), pas une table de lecture sujet par sujet.
async function sbGetDernierContenuForum() {
  const [topics, posts] = await Promise.all([
    sbGet('forum_topics', 'select=created_at&order=created_at.desc&limit=1').catch(() => null),
    sbGet('forum_posts', 'select=created_at&order=created_at.desc&limit=1').catch(() => null)
  ]);
  const t = topics?.[0]?.created_at || null;
  const p = posts?.[0]?.created_at || null;
  if (!t) return p;
  if (!p) return t;
  return t > p ? t : p; // horodatages ISO 8601 -- comparaison lexicographique fiable
}

// Voyants d'activite PAR FORUM (22 aout 2026, architecture finale suite a 3 revues successives
// le meme jour) : remplace l'usage de sbGetDernierContenuForum() ci-dessus (laissee en place,
// sans plus aucun appelant, au cas ou une V1 plus simple redevienne utile ailleurs) ET une
// premiere version a pagination globale (abandonnee : son MAX_PAGES pouvait encore produire un
// faux negatif au-dela du plafond, et un forum accessible sans aucun contenu forcait un scan de
// tout l'historique de forum_posts a CHAQUE sondage de 60s pour le reconfirmer vide).
//
// Architecture retenue, en 2 temps (orchestres par forum.js, verifierActiviteForumNonVue()) :
//  - sbActiviteForumCibles() : resolution CIBLEE, une fois par forum nouvellement accessible
//    (jamais tous les forums du jeu -- filtre forum_id=in.(...)) -- cout borne par le volume
//    PROPRE de ces forums, jamais par le volume global du jeu ni par le comportement de visite
//    du joueur (voir le rejet argumente de l'alternative "borne = dernierPassage" lors de la
//    revue du 22 aout : elle restait bloquee arbitrairement loin dans le passe des qu'un seul
//    forum accessible restait longtemps sans visite, recreant un rescan periodique complet).
//  - sbActiviteForumDepuis() : sondage INCREMENTAL a chaque poll suivant, filtre a la fois par
//    idsAccessibles (in.()) ET par curseur (created_at=gte.<curseur>) -- cout borne par
//    l'activite reelle depuis le dernier sondage, jamais par l'historique ni par le nombre de
//    forums silencieux. gte. (pas gt.) : created_at n'est pas garanti unique (plusieurs lignes
//    pourraient partager exactement le meme timestamp) -- gt. exclurait definitivement une ligne
//    soeur du curseur jamais vue lors du sondage precedent ; gte. la re-recupere, sans
//    consequence puisque l'agregation n'est qu'un MAX par forum (idempotente).
//
// forum_posts n'a pas de colonne forum_id (verifie) mais a une relation topic_id ->
// forum_topics.id deja exploitable par l'embed PostgREST, y compris comme filtre EMBARQUE
// (verifie par sondes reelles : forum_posts?select=created_at,forum_topics!inner(forum_id)
// &forum_topics.forum_id=in.(local,sport) renvoie correctement les posts des SEULS forums
// demandes) -- capacites EXISTANTES, aucune fonction SQL/RPC ni nouvelle architecture serveur.
// idsForums/idsAccessibles sont des parametres d'ENTREE, jamais un filtre de permission recree
// ici : forum.js calcule et transmet cette liste avec !f.private || canAccessForum(id),
// l'expression EXACTE deja utilisee par renderForumNavItem -- aucune deuxieme logique
// d'autorisation dans ce fichier.

// Sommet de chaque flux (curseur de depart), 2 requetes O(1) independantes du volume total --
// utilise UNE SEULE FOIS par session pour amorcer le curseur incremental.
async function sbDernierHorodatageForum() {
  const [t, p] = await Promise.all([
    sbGet('forum_topics', 'select=created_at&order=created_at.desc&limit=1').catch(() => null),
    sbGet('forum_posts', 'select=created_at&order=created_at.desc&limit=1').catch(() => null)
  ]);
  return { topics: t?.[0]?.created_at || null, posts: p?.[0]?.created_at || null };
}

// Resolution ciblee d'un sous-ensemble precis de forum_id. Le filtre in.() borne le flux a
// epuiser au volume PROPRE de ces forums -- un forum sans aucun contenu parmi idsForums
// n'entraine plus un scan de tout forum_posts, juste l'epuisement de son propre sous-ensemble
// filtre (generalement 1 page). Aucun MAX_PAGES : la seule condition d'arret correcte reste
// restants vide OU derniere page incomplete (flux scope epuise) -- jamais un plafond arbitraire.
async function sbActiviteForumCibles(idsForums, pageSize) {
  pageSize = pageSize || 200;
  const cibles = new Set(idsForums || []);
  if (cibles.size === 0) return {};
  const idsFiltre = Array.from(cibles).map(encodeURIComponent).join(',');

  async function dernierParForum(table, select, filtre, extraireForumId) {
    const resultats = {};
    const restants = new Set(cibles);
    let offset = 0;
    while (restants.size > 0) {
      // Pas de .catch(() => null) ici (revue du 22 aout 2026) : un echec reseau doit remonter
      // (verifierActiviteForumNonVue() a deja son try/catch) plutot que d'etre confondu avec un
      // flux reellement epuise -- sinon un id encore non resolu se voyait ecrit `null` ("confirme
      // vide") a la fin de cette fonction alors que sbGet avait simplement echoue, un faux negatif
      // permanent (le curseur, deja au sommet a ce moment du bootstrap, ne le retrouverait plus
      // jamais pendant la session). sbGet() renvoie null sur echec HTTP (voir plus haut) -- lignes
      // est donc null uniquement en cas d'echec ; [] (tableau vide) reste le seul signal de page
      // reellement vide, recue AVEC succes.
      const lignes = await sbGet(table, `select=${select}&${filtre}&order=created_at.desc&limit=${pageSize}&offset=${offset}`);
      if (lignes === null) throw new Error('sbActiviteForumCibles: echec reseau sur ' + table);
      if (lignes.length === 0) break; // flux (scope) epuise (succes, page vide), rien de plus a trouver
      lignes.forEach(l => {
        const fid = extraireForumId(l);
        if (fid && restants.has(fid) && !(fid in resultats)) {
          resultats[fid] = l.created_at; // 1ere occurrence rencontree = la plus recente (ordre desc)
          restants.delete(fid);
        }
      });
      if (lignes.length < pageSize) break; // page incomplete = flux (scope) epuise
      offset += pageSize;
    }
    return resultats;
  }

  const [topics, posts] = await Promise.all([
    dernierParForum('forum_topics', 'forum_id,created_at', `forum_id=in.(${idsFiltre})`, l => l.forum_id),
    dernierParForum('forum_posts', 'created_at,forum_topics!inner(forum_id)', `forum_topics.forum_id=in.(${idsFiltre})`, l => l.forum_topics?.forum_id)
  ]);

  const parForum = {};
  Object.entries(topics).forEach(([id, iso]) => { parForum[id] = iso; });
  Object.entries(posts).forEach(([id, iso]) => { if (!parForum[id] || iso > parForum[id]) parForum[id] = iso; });
  cibles.forEach(id => { if (!(id in parForum)) parForum[id] = null; }); // resolu : confirme vide
  return parForum;
}

// Sondage incremental : uniquement ce qui est arrive depuis le curseur, ET uniquement parmi les
// forums accessibles (idsAccessibles, meme provenance que sbActiviteForumCibles -- calcule et
// transmis par forum.js, jamais recalcule ici). gte. (pas gt.), voir le commentaire d'ensemble
// ci-dessus. Si curseur est null (jamais etabli), aucun filtre created_at n'est applique --
// n'arrive jamais en pratique ici puisque forum.js etablit toujours le curseur via
// sbDernierHorodatageForum() avant le premier appel a cette fonction.
async function sbActiviteForumDepuis(idsAccessibles, curseurTopics, curseurPosts, pageSize) {
  pageSize = pageSize || 200;
  const ids = new Set(idsAccessibles || []);
  if (ids.size === 0) return { parForum: {}, curseurTopics, curseurPosts };
  const idsFiltre = Array.from(ids).map(encodeURIComponent).join(',');

  async function depuis(table, select, filtreScope, extraireForumId, curseur) {
    const parForum = {};
    let dernier = curseur;
    let offset = 0;
    while (true) {
      const filtreCurseur = curseur ? `&created_at=gte.${encodeURIComponent(curseur)}` : '';
      // Pas de .catch(() => null) ici (revue du 22 aout 2026) : sur une pagination a plusieurs
      // pages (rare, seulement si beaucoup de nouveau contenu depuis le dernier sondage), une
      // page 0 reussie avait deja avance `dernier` avant qu'un echec sur la page 1 ne soit
      // confondu avec "flux epuise" -- le curseur retourne aurait alors avance au-dela de
      // donnees jamais recuperees, les faisant sauter definitivement (gte. ne les retrouverait
      // plus). L'echec doit remonter pour que le sondage entier soit abandonne (try/catch de
      // verifierActiviteForumNonVue()) et le curseur laisse intact pour le prochain essai.
      const lignes = await sbGet(table, `select=${select}&${filtreScope}${filtreCurseur}&order=created_at.asc&limit=${pageSize}&offset=${offset}`);
      if (lignes === null) throw new Error('sbActiviteForumDepuis: echec reseau sur ' + table);
      if (lignes.length === 0) break;
      lignes.forEach(l => {
        const fid = extraireForumId(l);
        if (fid) { if (!parForum[fid] || l.created_at > parForum[fid]) parForum[fid] = l.created_at; }
        if (!dernier || l.created_at > dernier) dernier = l.created_at;
      });
      if (lignes.length < pageSize) break;
      offset += pageSize;
    }
    return { parForum, curseur: dernier };
  }

  const [t, p] = await Promise.all([
    depuis('forum_topics', 'forum_id,created_at', `forum_id=in.(${idsFiltre})`, l => l.forum_id, curseurTopics),
    depuis('forum_posts', 'created_at,forum_topics!inner(forum_id)', `forum_topics.forum_id=in.(${idsFiltre})`, l => l.forum_topics?.forum_id, curseurPosts)
  ]);

  const parForum = {};
  Object.entries(t.parForum).forEach(([id, iso]) => { parForum[id] = iso; });
  Object.entries(p.parForum).forEach(([id, iso]) => { if (!parForum[id] || iso > parForum[id]) parForum[id] = iso; });
  return { parForum, curseurTopics: t.curseur, curseurPosts: p.curseur };
}

// authorReal/orgaId/orgIcon (17 aout 2026, publication au nom d'une organisation) : parametres
// optionnels, derniers de la liste (meme convention que contentLayout ci-dessous), UNIQUEMENT
// inclus dans le payload d'insertion quand ils sont fournis (authorIsOrg=true) -- une publication
// personnelle (l'immense majorite du trafic) n'ecrit donc JAMAIS ces 3 colonnes et reste
// entierement fonctionnelle avant meme que la migration migration_forum_organisation.sql ne soit
// appliquee. Seule la publication organisationnelle en depend, et echoue proprement (sbInsert
// renvoie null) tant que la migration n'a pas ete executee -- comportement deja gere par les
// appelants (message "echec de la publication", aucun etat local corrompu).
async function sbCreateTopic(forumId, title, author, country, time, authorIsOrg, authorSecret, authorReal, orgaId, orgIcon) {
  const id = 'topic-' + Date.now();
  const payload = {
    id, forum_id: forumId, title, author, country, time, views: 1, replies: 0,
    last_post_author: author, last_post_time: time,
    author_is_org: !!authorIsOrg, author_secret: !!authorSecret
  };
  if (authorIsOrg) {
    payload.author_real = authorReal || null;
    payload.author_org_id = orgaId || null;
    payload.author_org_icon = orgIcon || null;
  }
  // Comportement de retour volontairement inchange (renvoie toujours id, ne verifie pas
  // sbInsert()) : l'absence de detection d'echec sur sbCreateTopic est un defaut preexistant
  // deja identifie et explicitement laisse hors perimetre par le correctif precedent (458c334) --
  // pas re-ouvert ici.
  await sbInsert('forum_topics', payload);
  return id;
}

// contentLayout (Lot E1.5->E2) : paramètre optionnel, dernier de la liste pour ne rien casser
// des appelants existants (submitNewTopic/submitReply, qui ne le passent jamais -- content_
// layout reste alors null, comportement strictement inchangé pour eux). Extension mineure
// prévue par le plan E2, pas une nouvelle fonction séparée.
// Retour corrigé au passage (E2) : sbInsert() renvoie déjà null en cas d'échec réel, mais
// cette fonction ignorait ce signal et renvoyait toujours l'id généré -- un appelant ne
// pouvait donc jamais détecter un échec d'écriture. Comportement des appelants existants
// inchangé (aucun des deux ne branchait sur cette valeur de retour) ; nécessaire pour que
// submitComposeCanvas() (E2) puisse fiablement annuler un sujet resté sans aucun message si
// l'écriture du post échoue -- voir le commentaire de rollback dans forum.js.
// authorReal/orgaId/orgIcon (17 aout 2026, publication au nom d'une organisation) : meme
// convention que sbCreateTopic ci-dessus -- optionnels, uniquement inclus dans le payload quand
// authorIsOrg est vrai, une publication personnelle n'ecrit donc jamais ces colonnes.
async function sbCreatePost(topicId, author, content, time, authorIsOrg, authorSecret, blocks, contentLayout, authorReal, orgaId, orgIcon) {
  const id = 'post-' + Date.now();
  const payload = { id, topic_id: topicId, author, content, time, author_is_org: !!authorIsOrg, author_secret: !!authorSecret, content_blocks: blocks || [], content_layout: contentLayout || null };
  if (authorIsOrg) {
    payload.author_real = authorReal || null;
    payload.author_org_id = orgaId || null;
    payload.author_org_icon = orgIcon || null;
  }
  const inserted = await sbInsert('forum_posts', payload);
  if (!inserted) return null;
  // Mettre à jour le compteur de réponses + le dernier post (pour le tri par activité)
  const posts = await sbLoadForumPosts(topicId);
  const count = (posts?.length || 1) - 1;
  await sbUpdate('forum_topics', `id=eq.${encodeURIComponent(topicId)}`, { replies: count, last_post_author: author, last_post_time: time });
  return id;
}

// contentLayout (Lot E3) : paramètre optionnel, dernier de la liste pour ne rien casser des
// appelants existants (submitEditPost, éditeur classique, qui ne le passe jamais -- écrit
// alors content_layout: null, comme le ferait explicitement une édition qui repasserait un
// post composé en texte simple -- cas non prévu par ce lot, mais un post classique n'a de
// toute façon jamais eu de content_layout à préserver). sbUpdate() propage déjà correctement
// un échec (renvoie null), aucun correctif de valeur de retour nécessaire ici contrairement
// à sbCreatePost au lot E2.
async function sbEditPost(postId, content, blocks, contentLayout) {
  // content_blocks doit etre synchronise avec content -- sinon renderTopicView (qui
  // privilegie p.blocks des qu'il est non vide) continuerait d'afficher l'ancien texte
  // malgre une sauvegarde de content reussie.
  return sbUpdate('forum_posts', `id=eq.${encodeURIComponent(postId)}`, { content, content_blocks: blocks || [], content_layout: contentLayout || null, edited: true });
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

// A2 (16 aout 2026) : registre local par armurerie -- city obligatoire pour toute consultation
// en jeu (le registre national agrege n'existe plus, cf. afficherRegistreArmes). Parametre
// optionnel uniquement pour ne pas casser un appelant qui ignorerait encore la ville.
async function sbConsulterRegistreArmes(pays, city) {
  let filtre = `pays=eq.${encodeURIComponent(pays)}`;
  if (city) filtre += `&city=eq.${encodeURIComponent(city)}`;
  const rows = await sbGet('registre_ventes_armes', filtre + '&order=created_at.desc');
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

async function sbGetNiveauPrison(key) {
  const rows = await sbGet('niveaux_prison', `id=eq.${encodeURIComponent(key)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveNiveauPrison(key, data) {
  const existing = await sbGet('niveaux_prison', `id=eq.${encodeURIComponent(key)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('niveaux_prison', `id=eq.${encodeURIComponent(key)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('niveaux_prison', { id: key, data, updated_at: new Date().toISOString() });
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

// =====================
// INDICES DE VILLE (chantier "refonte des ordres" / Doctrine V2) — meme schema que
// budgets_municipaux, cle "pays_ville" (ex. "republic_capitale").
// =====================
async function sbGetIndicesVille(key) {
  const rows = await sbGet('indices_villes', `id=eq.${encodeURIComponent(key)}`);
  if (!rows || rows.length === 0) return null;
  return rows[0].data;
}

async function sbSaveIndicesVille(key, data) {
  const existing = await sbGet('indices_villes', `id=eq.${encodeURIComponent(key)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('indices_villes', `id=eq.${encodeURIComponent(key)}`, { data, updated_at: new Date().toISOString() });
  }
  return sbInsert('indices_villes', { id: key, data, updated_at: new Date().toISOString() });
}

// =====================
// INVESTIR / PLACEMENT (chantier "refonte des ordres" / Doctrine V2) — un seul actif a la
// fois par joueur, resolution par le cron de minuit a J+7 (voir api/cron-minuit.js).
// =====================
async function sbGetInvestissementEnCours(nom) {
  const rows = await sbGet('investissements', `joueur=eq.${encodeURIComponent(nom)}&statut=eq.en_cours`).catch(() => []);
  return (rows && rows[0]) || null;
}

// Retour corrige (17 aout 2026, correctif doublon "Envoyes") : renvoyait auparavant le tableau
// brut de sbInsert (jamais exploite par aucun appelant — verifie sur les ~60 sites d'appel,
// tous en fire-and-forget ou await sans capturer le resultat), pendant que sendMail() (forum.js)
// generait sont PROPRE id local independant pour l'echo immediat (nouvel appel Date.now(), donc
// quasi toujours different de celui genere ICI). Au rechargement suivant de la messagerie
// (loadMailsFromSB), la ligne Supabase (id reel) et l'echo local (id different, meme contenu)
// ne sont jamais reconnus comme le meme mail et survivent tous les deux -- doublon PERSISTANT
// dans "Envoyes", pas un artefact d'affichage. Renvoie desormais l'id reellement insere (ou null
// en cas d'echec reel), pour que l'appelant reutilise CET id pour son echo local -- meme
// doctrine que sbCreatePost (forum.js/458c334) : un seul id, jamais deux generes separement.
async function sbSendMail(from, to, subject, body, time, fromReal, fromOrgId, fromOrgIcon) {
  const id = 'mail-' + Date.now();
  // Filet de sécurité universel (lot H2, faille XSS pipeline mail) : sbSendMail est le point
  // d'écriture unique de TOUTE la table mails (mail joueur composé, mais aussi ~60 mails
  // système générés ailleurs dans le jeu). sanitizeRichHtml est un no-op sur du texte sans
  // balise (tous les mails système), donc sans risque ici -- et submitMail (forum.js)
  // sanitise déjà en amont pour le mail joueur, ce qui rend ce passage idempotent.
  const safeBody = typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(body || '') : (body || '');
  const payload = { id, from_player: from, to_player: to, subject, body: safeBody, time, read: false };
  // fromReal/fromOrgId/fromOrgIcon (envoi au nom d'une organisation, meme convention que
  // author_real/author_org_id/author_org_icon du forum) : optionnels, uniquement inclus quand
  // fournis -- un mail personnel (l'immense majorite) n'ecrit donc jamais ces colonnes et reste
  // fonctionnel meme avant que la migration ne soit appliquee.
  if (fromOrgId) {
    payload.from_real = fromReal || null;
    payload.from_org_id = fromOrgId || null;
    payload.from_org_icon = fromOrgIcon || null;
  }
  const inserted = await sbInsert('mails', payload);
  return inserted ? id : null;
}

// from_real.eq ajoute (17 aout 2026, envoi au nom d'une organisation) : pour un mail
// organisationnel, from_player contient le nom PUBLIC de l'organisation, pas celui du
// personnage reel qui a envoye -- sans ce 3e critere, le chef ne retrouverait jamais son
// propre mail dans "Envoyes" apres rechargement (ni to_player ni from_player ne valent alors
// son nom). Repli obligatoire tant que la migration n'est pas appliquee : PostgREST rejette
// (400/42703) toute requete referencant une colonne absente, meme dans un simple filtre --
// vérifié en direct sur Supabase avant d'écrire ce code. Sans ce repli, TOUS les mails
// personnels cesseraient de charger des le deploiement, avant meme la migration manuelle
// (regression bien plus grave que le doublon corrige par ce meme lot). Une fois la migration
// appliquee, la requete enrichie reussit toujours et le repli n'est plus jamais invoque.
async function sbGetMailsFor(playerName) {
  const q = encodeURIComponent(playerName);
  const enrichi = await sbGet('mails', `or=(to_player.eq.${q},from_player.eq.${q},from_real.eq.${q})&order=created_at.desc`);
  if (enrichi) return enrichi;
  return sbGet('mails', `or=(to_player.eq.${q},from_player.eq.${q})&order=created_at.desc`);
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
async function sbUpdatePresence(name, country, city, buildingId, roomId, groupePnj) {
  if (!name) return;
  // Upsert — name est cle primaire, on remplace la ligne existante (sinon conflit silencieux)
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/presences`, {
      method: 'POST',
      headers: { ...SB_HEADERS, 'Prefer': 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify({
        name, country, city, building_id: buildingId, room_id: roomId,
        groupe_pnj: groupePnj || [],
        updated_at: new Date().toISOString()
      })
    });
    if (!res.ok) { console.error('sbUpdatePresence error', await res.text()); return null; }
    // Journal des deplacements (append-only, pour la filature policiere)
    if (typeof state !== 'undefined' && buildingId && roomId) {
      const hLog = String(state.hour || 0).padStart(2, '0');
      fetch(`${SUPABASE_URL}/rest/v1/historique_deplacements`, {
        method: 'POST', headers: SB_HEADERS,
        body: JSON.stringify({ name, country, city, building_id: buildingId, room_id: roomId, jour: state.day || 1, heure: hLog + 'h' })
      }).catch(() => {});
    }
    return res.json();
  } catch(e) { return null; }
}

async function sbGetHistoriqueDeplacements(name, depuisJour) {
  const filtre = `name=eq.${encodeURIComponent(name)}&jour=gte.${depuisJour}&order=created_at.desc&limit=50`;
  return sbGet('historique_deplacements', filtre) || [];
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
    sbSaveTimer = null;
    if (state?.char?.name) {
      await sbSavePersonnage(state);
    }
  }, 3000); // Sauvegarde 3s après la dernière action
}

// Filet de secours au dechargement de la page (correctif, 20 aout 2026) : sbAutoSave() ci-dessus
// debounce de 3s -- un refresh/fermeture pendant cette fenetre tue le setTimeout en cours et perd
// les mutations non encore ecrites (inventory notamment, qui n'a par ailleurs aucun repli
// localStorage, voir updateUI()/plateau-core.js). Appelee depuis les gestionnaires
// pagehide/beforeunload (plateau-core.js) -- PAS depuis un flux normal du jeu.
//
// Deux choix deliberes, pour rester honnete sur ce qui est reellement garanti par le navigateur
// (jamais un simple `await fetch()` dans beforeunload, connu pour etre annule sans preavis) :
//  1) keepalive:true sur le fetch -- garantie standard du navigateur de laisser la requete
//     s'achever meme apres le dechargement du document. C'est cette option, pas l'evenement
//     choisi, qui rend l'envoi fiable ; pagehide et beforeunload y recourent donc tous les deux.
//  2) UN SEUL PATCH direct, sans la lecture prealable de sbSavePersonnage (qui decide entre
//     INSERT/UPDATE) : cette lecture ne peut pas etre garantie de s'achever dans la fenetre de
//     dechargement, meme avec keepalive, et de toute facon la ligne existe deja a ce stade (un
//     personnage a necessairement ete sauvegarde au moins une fois avant de pouvoir jouer).
//     Ne couvre donc que les champs les plus critiques a ne pas perdre (inventory/arg/liquide/
//     banque/pa/hp/moral/resources/position), pas l'objet complet (journal, historique_crimes,
//     etc. restent couverts par le cours normal de sbAutoSave()) -- volume garde petit pour rester
//     sous la limite de charge utile des requetes keepalive.
// Aucune transaction metier rejouee ici : uniquement une ecriture de l'etat personnage deja
// mute en memoire, jamais un nouvel achat/deduction.
function sbSauvegardeUrgenceDechargement() {
  if (sbSaveTimer) { clearTimeout(sbSaveTimer); sbSaveTimer = null; }
  if (!state?.char?.name) return;
  const body = JSON.stringify({
    inventory: state.inventory || [],
    arg: state.arg || 0,
    liquide: state.liquide || 0,
    banque: state.banque || 0,
    pa: (typeof state.pa === 'number') ? state.pa : 10,
    hp: state.hp || 100,
    moral: state.moral || 75,
    resources: { inf: state.inf || 0, pop: state.pop || 0, dis: state.dis || 50 },
    country: state.country || 'republic',
    current_city: state.currentCity || 'capitale',
    current_building: state.currentBuilding || null,
    current_room: state.currentRoom || null
  });
  try {
    fetch(`${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(state.char.name)}`, {
      method: 'PATCH',
      headers: SB_HEADERS,
      body,
      keepalive: true
    }).catch(() => {});
  } catch (e) {}
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

// Lecture FRAICHE d'une seule organisation (17 aout 2026, publication au nom d'une organisation)
// -- contrairement a state.organisations (charge une fois au demarrage, potentiellement perime
// si le chef a change entre-temps), interroge Supabase directement. Utilisee au moment exact de
// la publication pour verifier que le joueur est toujours chef, jamais a partir du seul cache
// local. Reutilise la meme table 'organisations' (id + data JSON), aucun changement de schema.
async function sbGetOrganisationParId(orgaId) {
  if (!orgaId) return null;
  const rows = await sbGet('organisations', `id=eq.${encodeURIComponent(orgaId)}`).catch(() => []);
  if (!rows || rows.length === 0) return null;
  try { return JSON.parse(rows[0].data); } catch(e) { return null; }
}

async function sbDeleteOrganisation(orgaId) {
  return sbDelete('organisations', `id=eq.${encodeURIComponent(orgaId)}`);
}

// =====================
// STORAGE — AVATAR D'ORGANISATION (17 aout 2026, revu le 17 aout 2026 apres audit securite)
// =====================
// Premiere version rejetee en revue : upload/suppression directs depuis le client avec la cle
// anon, ce qui exigeait des policies Storage INSERT/DELETE ouvertes a tous -- un appel API
// direct pouvait alors contourner sauvegarderOptionsOrga/sbUploadOrgAvatar (format, taille, ET
// la verification du chef). Corrige : l'upload passe desormais PAR UN ENDPOINT SERVEUR
// (api/upload-org-avatar.js, cle service_role uniquement en variable d'environnement Vercel,
// jamais dans ce fichier ni ailleurs cote client) qui fait AUTORITE sur ces trois controles.
// orga.avatar reste LA seule propriete d'avatar (deja existante, deja affichee dans "Mes
// organisations") -- un upload reussi y ecrit simplement l'URL publique renvoyee par le
// serveur, exactement comme une URL saisie a la main. Bucket dedie 'org-avatars' (lecture
// publique uniquement, aucune policy anon en ecriture -- migration_org_avatars_storage.sql).
//
// Renvoie l'URL publique (ou null en cas d'echec reel : format refuse, fichier trop
// volumineux, chef plus a jour, service pas encore configure cote Vercel). Validation de forme
// faite cote client ICI en plus (retour rapide sans requete reseau pour un fichier evidemment
// invalide) -- le serveur revalide integralement de toute facon, c'est lui qui fait foi.
const ORG_AVATAR_MAX_BYTES = 2 * 1024 * 1024; // 2 Mo -- raisonnable pour un logo/avatar, evite les uploads aberrants
const ORG_AVATAR_MIME_EXT = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' };

async function sbUploadOrgAvatar(orgaId, file) {
  if (!orgaId || !file) return null;
  if (file.size > ORG_AVATAR_MAX_BYTES) return null;
  if (!ORG_AVATAR_MIME_EXT[file.type]) return null;
  const nom = (typeof state !== 'undefined' && state.char?.name) || '';
  if (!nom) return null;
  const url = `/api/upload-org-avatar?orgaId=${encodeURIComponent(orgaId)}&characterName=${encodeURIComponent(nom)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': file.type },
    body: file
  }).catch(() => null);
  if (!res || !res.ok) { console.error('sbUploadOrgAvatar error', await res?.text().catch(() => '') || 'reseau'); return null; }
  const json = await res.json().catch(() => null);
  return json?.url || null;
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

// Don direct d'objet a un vrai joueur — reellement persiste (contrairement a l'ancien
// mecanisme purement local qui faisait juste disparaitre l'objet chez l'expediteur sans
// jamais l'ajouter chez le destinataire). Recupere a la prochaine connexion du destinataire.
async function sbDonnerObjetJoueur(objet, destinataire, expediteur) {
  const data = { id: 'objet-recu-' + Date.now() + '-' + Math.floor(Math.random()*1000), destinataire, expediteur, data: JSON.stringify(objet) };
  return sbInsert('objets_recus', data);
}

async function sbGetObjetsRecus(nom) {
  const rows = await sbGet('objets_recus', `destinataire=eq.${encodeURIComponent(nom)}`);
  if (!rows) return [];
  return rows.map(r => {
    try { return { id: r.id, expediteur: r.expediteur, objet: JSON.parse(r.data) }; }
    catch(e) { return null; }
  }).filter(Boolean);
}

async function sbSupprimerObjetRecu(objetId) {
  return sbDelete('objets_recus', `id=eq.${encodeURIComponent(objetId)}`);
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

async function sbGetEtatUrgence(country) {
  const rows = await sbGet('etats_urgence', `country=eq.${encodeURIComponent(country)}`);
  return (rows && rows[0]) || null;
}

async function sbSetEtatUrgence(country, actif, activePar, jour) {
  const existant = await sbGetEtatUrgence(country).catch(() => null);
  if (existant) {
    return sbUpdate('etats_urgence', `country=eq.${encodeURIComponent(country)}`, { actif, active_par: activePar, jour_debut: jour });
  }
  return sbInsert('etats_urgence', { country, actif, active_par: activePar, jour_debut: jour });
}

async function sbCreerDetention(data) {
  const id = 'det-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
  return sbInsert('detentions', { id, ...data });
}

async function sbLoadDetentions(country) {
  return sbGet('detentions', `country=eq.${encodeURIComponent(country)}&order=jour_debut.desc`);
}

async function sbCreerJugement(data) {
  const id = 'jug-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
  return sbInsert('jugements', { id, ...data });
}

async function sbLoadJugements(country) {
  return sbGet('jugements', `country=eq.${encodeURIComponent(country)}&order=jour.desc`);
}

async function sbGetStatsInfluenceJoueur(nom) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nom)}&select=char,resources`).catch(() => []);
  const r = rows?.[0];
  return { per: r?.char?.stats?.PER || 8, inf: r?.resources?.inf || 0 };
}

// Pour un titulaire religieux (grand_pretre) qui serait un PJ different du joueur courant
// (chantier Benediction, doctrine V2).
async function sbGetStatCHA(nom) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nom)}&select=char`).catch(() => []);
  return rows?.[0]?.char?.stats?.CHA ?? 9;
}

async function sbSetTitulairePnj(country, posteId, city, nomPnj) {
  const id = country + '_' + posteId + '_' + (city || 'national');
  const existing = await sbGet('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`).catch(() => []);
  const payload = { id, country, poste_id: posteId, city: city || null, nom_pnj: nomPnj, updated_at: new Date().toISOString() };
  if (existing && existing.length > 0) return sbUpdate('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`, payload);
  return sbInsert('titulaires_pnj', payload);
}

async function sbGetTitulairePnj(country, posteId, city) {
  const id = country + '_' + posteId + '_' + (city || 'national');
  const rows = await sbGet('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`).catch(() => []);
  return rows?.[0]?.nom_pnj || null;
}

async function sbSupprimerTitulairePnj(country, posteId, city) {
  const id = country + '_' + posteId + '_' + (city || 'national');
  return sbDelete('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`);
}

async function sbCreerDemandeMariage(demande) {
  return sbInsert('demandes_mariage', demande);
}

async function sbUpdateDemandeMariage(id, statut) {
  return sbUpdate('demandes_mariage', `id=eq.${encodeURIComponent(id)}`, { statut });
}

async function sbGetDemandesMariagePour(nom) {
  const rows = await sbGet('demandes_mariage', `destinataire=eq.${encodeURIComponent(nom)}&statut=eq.en_attente`);
  return rows || [];
}

async function sbCreerMariage(mariage) {
  return sbInsert('mariages', mariage);
}

async function sbGetMariageActif(nom) {
  if (!nom) return null;
  const rows1 = await sbGet('mariages', `conjoint1=eq.${encodeURIComponent(nom)}&statut=eq.actif`).catch(() => []);
  if (rows1 && rows1.length > 0) return rows1[0];
  const rows2 = await sbGet('mariages', `conjoint2=eq.${encodeURIComponent(nom)}&statut=eq.actif`).catch(() => []);
  if (rows2 && rows2.length > 0) return rows2[0];
  return null;
}

// Dissout un mariage (divorce ou veuvage) sans jamais supprimer la ligne — la memoire de
// l'union reste consultable pour toujours (etat-civil).
async function sbDissoudreMariage(id, raison) {
  return sbUpdate('mariages', `id=eq.${encodeURIComponent(id)}`, { statut: 'dissous', raison_dissolution: raison || 'divorce' });
}

// Recense tous les mariages (actifs ou dissous) impliquant un nom donne, pour l'etat-civil.
async function sbGetMariagesPourNom(nom) {
  if (!nom) return [];
  const rows1 = await sbGet('mariages', `conjoint1=eq.${encodeURIComponent(nom)}`).catch(() => []);
  const rows2 = await sbGet('mariages', `conjoint2=eq.${encodeURIComponent(nom)}`).catch(() => []);
  return [...(rows1 || []), ...(rows2 || [])];
}

// =====================
// TESTAMENTS (refonte testament/succession, 20 aout 2026) -- table dediee (migration a valider
// separement, voir rapport d'implementation), meme doctrine que mariages/etat_civil_deces :
// jamais de suppression de ligne, un nouveau testament remplace l'ancien par changement de statut
// (jamais un UPDATE du contenu), l'historique complet reste consultable pour toujours.
// =====================
async function sbSaveTestament(testament) {
  return sbInsert('testaments', testament);
}

// Defense en profondeur (verification d'idempotence/audit du 21 aout 2026) : soumettreTestament()
// (plateau-personnage.js) sauvegarde le nouveau testament 'actif' PUIS, dans un appel HTTP
// SEPARE et ulterieur, marque l'ancien 'remplace' -- si ce second appel echoue (reseau), les
// deux restent 'actif' simultanement, sans qu'aucune contrainte SQL ne l'empeche (aucune
// migration necessaire pour ce lot). order=created_at.desc&limit=1 garantit un choix
// deterministe (le plus recent) meme dans ce cas exceptionnel, plutot que de dependre de l'ordre
// de retour non garanti de PostgREST. Toujours un tableau en reponse (PostgREST standard, jamais
// un objet nu ici) -- rows[0] reste le bon acces, limit=1 ne change que sa taille maximale (0 ou 1).
async function sbGetTestamentActif(nom) {
  if (!nom) return null;
  const rows = await sbGet('testaments', `testateur=eq.${encodeURIComponent(nom)}&statut=eq.actif&order=created_at.desc&limit=1`).catch(() => []);
  return (rows && rows.length > 0) ? rows[0] : null;
}

// Historique complet (actif + remplaces + revoques + executes), le plus recent en tete.
async function sbGetTousLesTestaments(nom) {
  if (!nom) return [];
  const rows = await sbGet('testaments', `testateur=eq.${encodeURIComponent(nom)}&order=created_at.desc`).catch(() => []);
  return rows || [];
}

// statut : 'remplace' (un nouveau testament vient d'etre redige), 'revoque' (le testateur a
// explicitement annule sans en rediger un autre), 'execute' (consomme par une succession reelle).
async function sbMarquerTestamentStatut(id, statut) {
  return sbUpdate('testaments', `id=eq.${encodeURIComponent(id)}`, { statut });
}

// =====================
// SUCCESSIONS (architecture v3/v4, 20 aout 2026) -- une ligne = un dossier successoral complet,
// du statut 'en_attente' (ouverture, convocations, gel) a 'resolue' (reglement final par le
// cron). Meme table qui sert d'archive notariale une fois resolue -- pas de deuxieme table.
// dispositions (JSONB, tableau) est la SEULE source de verite pour les convocations et leurs
// echeances, y compris pour le conjoint en tant qu'heritier legal potentiel (voir
// dispositions[].chaine[].role === 'legal_conjoint'). successions.conjoint est un champ distinct :
// simple droit d'information globale du conjoint des l'ouverture, jamais une convocation avec
// decision/echeance -- ne pas les confondre (voir rapport d'architecture).
// =====================
async function sbCreerSuccession(succession) {
  return sbInsert('successions', succession);
}

async function sbGetSuccession(id) {
  if (!id) return null;
  const rows = await sbGet('successions', `id=eq.${encodeURIComponent(id)}`).catch(() => []);
  return (rows && rows.length > 0) ? rows[0] : null;
}

async function sbUpdateSuccession(id, patch) {
  return sbUpdate('successions', `id=eq.${encodeURIComponent(id)}`, patch);
}

// Successions en_attente d'un pays -- le filtrage par beneficiaire/conjoint se fait cote client
// (dispositions est un contenu JSONB libre, meme doctrine que enigme1RechercherArchivesNotariales/
// rechercherDossierNotarial : jamais de requete PostgREST fouillant l'interieur d'un tableau JSONB).
async function sbGetSuccessionsEnAttente(country) {
  if (!country) return [];
  const rows = await sbGet('successions', `country=eq.${encodeURIComponent(country)}&statut=eq.en_attente`).catch(() => []);
  return rows || [];
}

// Toutes les successions d'un pays, tous statuts confondus -- utilise par les archives notariales
// (qui ne retiennent ensuite que statut='resolue' cote client, une succession en cours ne doit
// jamais apparaitre dans les archives).
async function sbGetToutesLesSuccessions(country) {
  if (!country) return [];
  const rows = await sbGet('successions', `country=eq.${encodeURIComponent(country)}&order=created_at.desc`).catch(() => []);
  return rows || [];
}

// Archive permanente d'un deces de PJ (le personnage lui-meme est supprime de 'personnages',
// donc c'est la seule trace qui persiste pour l'etat-civil). city (17 aout 2026, mini-lot
// etat-civil) : ville reellement pertinente selon la doctrine validee -- optionnelle (undefined
// tant que la migration migration_etat_civil_ville.sql n'a pas ete appliquee, colonne absente ->
// PGRST204, deja avale par le .catch() du seul appelant, aucune regression sur la suppression du
// personnage elle-meme).
async function sbEnregistrerDeces(nom, country, city) {
  return sbInsert('etat_civil_deces', { id: 'deces-' + Date.now(), nom, country, city: city || null });
}

async function sbGetDecesPourNom(nom) {
  if (!nom) return null;
  const rows = await sbGet('etat_civil_deces', `nom=eq.${encodeURIComponent(nom)}`).catch(() => []);
  return (rows && rows.length > 0) ? rows[0] : null;
}

async function sbGetTousLesDeces(country) {
  const rows = await sbGet('etat_civil_deces', `country=eq.${encodeURIComponent(country)}`).catch(() => []);
  return rows || [];
}

async function sbGetTousLesMariages(country) {
  const rows = await sbGet('mariages', `country=eq.${encodeURIComponent(country)}`).catch(() => []);
  return rows || [];
}

// Naissance (17 aout 2026, mini-lot etat-civil) : AUCUNE colonne ajoutee a 'personnages' (relue/
// resauvegardee integralement a chaque action de chaque joueur -- une colonne manquante y
// romprait toutes les sauvegardes de tous les joueurs tant que la migration n'est pas appliquee,
// risque juge inacceptable). A la place, table dediee minimale, insert-only, exactement sur le
// modele de sbEnregistrerDeces ci-dessus -- ecrite une seule fois, a la creation du personnage.
async function sbEnregistrerNaissance(nom, country, city) {
  return sbInsert('etat_civil_naissances', { id: 'naissance-' + Date.now(), nom, country, city: city || null });
}

async function sbGetToutesLesNaissances(country) {
  const rows = await sbGet('etat_civil_naissances', `country=eq.${encodeURIComponent(country)}`).catch(() => []);
  return rows || [];
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
// Cle id : cause racine du bug multi-ville corrigee le 2026-08-16. Un batiment generique
// (ex. 'centre-affaires') est partage par plusieurs villes du meme pays -- l'ancienne cle
// 'buildingId:roomId' faisait qu'une location a Montrouge ecrasait la MEME ligne qu'une
// location a Luthecia. Les 7 locations qui existaient encore sous l'ancienne cle (sans
// city) ont ete migrees individuellement (INSERT nouvelle cle + verification + DELETE
// ancienne cle) vers 'buildingId:roomId:city' -- plus aucune ligne sans city en base,
// donc plus besoin de repli conditionnel ici ni dans getLocationPourRoom.
async function sbSaveLocation(location) {
  const id = location.buildingId + ':' + location.roomId + ':' + location.city;
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

// Aucun appelant actuellement dans le code (verifie) -- signature alignee sur sbSaveLocation
// par coherence si elle est reutilisee un jour.
async function sbSupprimerLocation(buildingId, roomId, city) {
  const id = buildingId + ':' + roomId + (city ? ':' + city : '');
  return sbDelete('locations_actives', `id=eq.${encodeURIComponent(id)}`);
}

// ---- BOX PORTUAIRE MULTI-TENANT (lot du 25 aout 2026, §13-14) ----
// sbSaveLocation/sbSupprimerLocation ci-dessus construisent un id 'buildingId:roomId:city' SANS
// le locataire -- correct pour les ~15 locations exclusives existantes (un seul bail possible par
// piece), mais dangereux pour un box multi-tenant : deux PJ louant un box dans la MEME piece
// ecraseraient la meme ligne Supabase l'un apres l'autre. Ces deux fonctions dediees ajoutent le
// locataire a l'id, sans toucher sbSaveLocation/sbSupprimerLocation/sbLoadLocations (qui restent
// inchangees et continuent de servir les ~15 autres pieces) -- meme table locations_actives,
// meme forme de ligne {id,country,data}, chargee par le meme sbLoadLocations (qui recupere deja
// TOUTES les lignes du pays sans hypothese d'unicite, donc aucune modification necessaire cote
// lecture pour supporter plusieurs box).
async function sbSaveLocationBox(location) {
  const id = location.buildingId + ':' + location.roomId + ':' + location.city + ':' + location.locataire;
  const data = { id, country: location.country, data: location };
  const existing = await sbGet('locations_actives', `id=eq.${encodeURIComponent(id)}`);
  if (existing && existing.length > 0) {
    return sbUpdate('locations_actives', `id=eq.${encodeURIComponent(id)}`, data);
  }
  return sbInsert('locations_actives', data);
}

async function sbSupprimerLocationBox(buildingId, roomId, city, locataire) {
  const id = buildingId + ':' + roomId + ':' + city + ':' + locataire;
  return sbDelete('locations_actives', `id=eq.${encodeURIComponent(id)}`);
}

// =====================
// LOGEMENTS SOCIAUX DE MONTROUGE (18 aout 2026) — demandes persistantes + archive
// d'attributions. Tables nouvelles (voir migration_logements_sociaux_montrouge.sql, NON
// executee), sur le meme modele que terrains_historique_ventes (append-only, id construit
// cote application, created_at automatique). Toutes les fonctions tolerent l'absence de
// migration (sbGet renvoie null -> [] cote appelant), comme le reste du projet.
// =====================
async function sbDeposerDemandeLogement(country, ville, demandeur, typeSouhaite) {
  const id = 'demande-logement-' + ville + '-' + demandeur.replace(/[^a-zA-Z0-9]/g, '') + '-' + Date.now();
  const inserted = await sbInsert('logements_demandes', {
    id, country, ville, demandeur, type_souhaite: typeSouhaite || null, statut: 'en_attente'
  });
  return inserted ? id : null;
}

async function sbGetDemandeLogementEnAttente(country, ville, demandeur) {
  const rows = await sbGet('logements_demandes',
    `country=eq.${encodeURIComponent(country)}&ville=eq.${encodeURIComponent(ville)}&demandeur=eq.${encodeURIComponent(demandeur)}&statut=eq.en_attente`);
  return (rows && rows[0]) || null;
}

async function sbGetDemandesLogementEnAttente(country, ville) {
  const rows = await sbGet('logements_demandes',
    `country=eq.${encodeURIComponent(country)}&ville=eq.${encodeURIComponent(ville)}&statut=eq.en_attente&order=created_at.asc`);
  return rows || [];
}

async function sbMarquerDemandeLogementTraitee(demandeId, roomId) {
  return sbUpdate('logements_demandes', `id=eq.${encodeURIComponent(demandeId)}`,
    { statut: 'attribuee', room_id_attribue: roomId });
}

// Archive permanente, append-only (jamais mise a jour ni supprimee, y compris a la
// resiliation) -- uniquement des faits (logement/beneficiaire/autorite/date), aucune
// qualification automatique (voir doctrine "le jeu ne juge pas", audit du 18 aout 2026).
async function sbEnregistrerAttributionLogement(country, ville, roomId, beneficiaire, autorite) {
  return sbInsert('logements_attributions_historique', {
    id: 'attrib-' + roomId + '-' + Date.now(),
    country, ville, room_id: roomId, beneficiaire, autorite
  });
}

// Fonction de lecture prevue pour une future interface d'archives municipales (hors perimetre
// de ce lot) -- symetrique a sbGetToutHistoriqueTerrains.
async function sbGetHistoriqueAttributionsLogements(country, ville) {
  const rows = await sbGet('logements_attributions_historique',
    `country=eq.${encodeURIComponent(country)}&ville=eq.${encodeURIComponent(ville)}&order=created_at.asc`);
  return rows || [];
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

// Fix 9 aout 2026 : lisait/ecrivait une colonne personnages.pop qui n'existe pas (verifie en
// direct sur Supabase : "column personnages.pop does not exist") - la vraie POP vit dans
// resources.pop (colonne JSON, voir sbSavePersonnage/sbLoadPersonnage). Consequence : cette
// fonction echouait toujours silencieusement (erreur avalee par le .catch() des appelants),
// la POP d'une cible n'a donc jamais ete reellement modifiee par lancer_rumeur_cible.
async function sbAjusterPopJoueur(nomJoueur, delta) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=resources`);
  const resources = rows?.[0]?.resources || { inf: 0, pop: 50, dis: 50 };
  const nouveauPop = Math.max(0, Math.min(100, (resources.pop ?? 50) + delta));
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomJoueur)}`, { resources: { ...resources, pop: nouveauPop } });
  return nouveauPop;
}

// =====================
// INVITATIONS A DINER (diner d'affaires entre PJ presents dans la meme piece)
// =====================
async function sbCreerInvitationDiner(inviteur, invite, country, city, buildingId, roomId, cout, type, message) {
  return sbInsert('invitations_diner', {
    inviteur, invite, country, city,
    building_id: buildingId, room_id: roomId,
    statut: 'attente', cout, type: type || 'diner_affaires',
    message: message || null
  });
}

// tournee_id=is.null (lot tournees, 20 aout 2026) : exclut les invitations qui appartiennent a
// une tournee (voir plus bas) -- celles-ci ont leur propre ecran de reponse dedie
// (verifierTourneesRecues/repondreTournee, plateau-actions-illegales-rumeurs.js) et ne doivent
// jamais etre captees par l'ancien flux mono-cible diner_affaires/boire_verre
// (verifierInvitationsSocialesRecues, plateau-pnj.js). Aucune ligne diner_affaires/boire_verre
// existante ou future n'a jamais tournee_id renseigne (jamais ecrit par sbCreerInvitationDiner),
// donc ce filtre est un no-op strict pour elles -- seul le comportement des lignes de tournee
// change (elles disparaissent de cette requete).
async function sbGetInvitationsDinerRecues(nomJoueur) {
  const filtre = `invite=eq.${encodeURIComponent(nomJoueur)}&statut=eq.attente&tournee_id=is.null`;
  return sbGet('invitations_diner', filtre) || [];
}

async function sbGetInvitationsDinerTraitees(nomInviteur, nomInvite) {
  const filtre = `inviteur=eq.${encodeURIComponent(nomInviteur)}&invite=eq.${encodeURIComponent(nomInvite)}&statut=neq.attente`;
  return sbGet('invitations_diner', filtre) || [];
}

async function sbRepondreInvitationDiner(id, accepte, reponse) {
  return sbUpdate('invitations_diner', `id=eq.${id}`, { statut: accepte ? 'acceptee' : 'refusee', reponse: reponse || null });
}

async function sbSupprimerInvitationDiner(id) {
  return sbDelete('invitations_diner', `id=eq.${id}`);
}

// =====================
// TOURNEES (offrir un verre a plusieurs cibles simultanement, PJ et/ou PNJ) -- 20 aout 2026.
// invitations_diner.tournee_id relie les invitations PJ d'une tournee a sa ligne "tournees"
// partagee ; reponse/statut/suppression reutilisent tels quels sbRepondreInvitationDiner et
// sbSupprimerInvitationDiner ci-dessus, aucune primitive dupliquee.
// =====================
async function sbCreerTournee(t) {
  const rows = await sbInsert('tournees', t);
  return rows?.[0] || null;
}

async function sbGetTournee(id) {
  const rows = await sbGet('tournees', `id=eq.${encodeURIComponent(id)}`);
  return rows?.[0] || null;
}

async function sbGetTourneesActivesOffreur(nomOffreur) {
  return sbGet('tournees', `offreur=eq.${encodeURIComponent(nomOffreur)}&statut=in.(en_attente,en_resolution)`) || [];
}

// Claim conditionnel (compare-and-swap) : le PATCH ne s'applique que si la ligne est encore
// en_attente au moment ou Postgres l'evalue (verrouillage ligne standard) -- un tableau vide en
// retour signifie qu'un autre client a deja pris la main, jamais une erreur.
async function sbClaimResolutionTournee(id) {
  return sbUpdate('tournees', `id=eq.${encodeURIComponent(id)}&statut=eq.en_attente`,
    { statut: 'en_resolution', resolution_started_at: new Date().toISOString() });
}

// Meme principe, pour reclamer une resolution restee en_resolution au-dela du seuil de
// peremption (crash presume du claimant precedent) -- seuilIso = horodatage ISO en-deca duquel
// resolution_started_at est considere perime.
async function sbReclaimResolutionTourneeExpiree(id, seuilIso) {
  return sbUpdate('tournees', `id=eq.${encodeURIComponent(id)}&statut=eq.en_resolution&resolution_started_at=lt.${encodeURIComponent(seuilIso)}`,
    { statut: 'en_resolution', resolution_started_at: new Date().toISOString() });
}

async function sbMarquerTourneePaDebite(id) {
  return sbUpdate('tournees', `id=eq.${encodeURIComponent(id)}`, { pa_debite: true });
}

async function sbMarquerTourneeResolue(id, paDebite) {
  return sbUpdate('tournees', `id=eq.${encodeURIComponent(id)}`, { statut: 'resolue', pa_debite: !!paDebite });
}

async function sbCreerInvitationsTournee(rows) {
  return sbInsert('invitations_diner', rows);
}

async function sbGetInvitationsTournee(tourneeId) {
  return sbGet('invitations_diner', `tournee_id=eq.${encodeURIComponent(tourneeId)}`) || [];
}

async function sbGetInvitationsTourneeRecues(nomJoueur) {
  return sbGet('invitations_diner', `invite=eq.${encodeURIComponent(nomJoueur)}&statut=eq.attente&tournee_id=not.is.null`) || [];
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
// resolution=ignore-duplicates (Lot 4, 23 aout 2026, audit idempotence) : si un appelant retente
// ce depot avec exactement le meme id (ex. accuse de reception reseau perdu apres un premier
// succes serveur -- lireCartePostale, plateau-personnage.js), Postgres traite la ligne deja
// existante comme "rien a faire" -- succes HTTP propre -- au lieu d'une erreur de contrainte.
// Necessaire pour qu'un appelant puisse determiner de facon fiable "cette ligne existe-t-elle
// reellement en base ?" a partir de la seule valeur de retour (non-null = oui), sans jamais
// pouvoir se retrouver bloque par un doublon qu'il ne peut plus jamais confirmer.
async function sbDeposerImpactIndice(impact) {
  return sbInsert('impacts_indices_attente', impact, 'ignore-duplicates');
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

// Tous les terrains possedes par un joueur donne, quel que soit l'endroit ou il se trouve
// (necessaire pour le revenu passif/bonus au moment de Dormir, qui peut se produire ailleurs
// que sur le terrain lui-meme).
async function sbGetTerrainsPossedesPar(country, nom) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}&proprietaire=eq.${encodeURIComponent(nom)}`);
  return (rows || []).map(function(r) {
    try { return { buildingId: r.building_id, ...JSON.parse(r.data) }; } catch(e) { return null; }
  }).filter(Boolean);
}

// Trois fonctions manquantes decouvertes le 5 aout 2026 : appelees partout dans le code des
// prets bancaires (confirmerPretBancaire, preleverPretsBancaires) mais jamais definies —
// les prets n'etaient donc jamais reellement persistes, juste de l'argent credite en memoire.
// Etat generique par batiment (pas seulement les terrains) — sert de fondation au systeme
// de blocus syndical, mais reutilisable pour d'autres mecaniques futures liees a un batiment
// precis (pas a la ville entiere).
async function sbGetBatimentEtat(country, city, buildingId) {
  const id = country + '_' + city + '_' + buildingId;
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    try { return JSON.parse(rows[0].data); } catch(e) { return {}; }
  }
  return {};
}

async function sbSetBatimentEtat(country, city, buildingId, patch) {
  const id = country + '_' + city + '_' + buildingId;
  const actuel = await sbGetBatimentEtat(country, city, buildingId);
  const fusion = { ...actuel, ...patch };
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(id)}`, { data: JSON.stringify(fusion), updated_at: new Date().toISOString() });
  } else {
    await sbInsert('batiments_etat', { id, country, city, building_id: buildingId, data: JSON.stringify(fusion) });
  }
  return fusion;
}

// Bureau National de l'Emploi (9 aout 2026) — reutilise batiments_etat plutot qu'une nouvelle
// table dediee (pas de DDL possible avec la cle anon). Une seule entree partagee par pays
// ('national'/'bne' comme city/buildingId), contenant l'occupation reelle de TOUTES les
// offres (OFFRES_EMPLOI_BNE, data.js), quelle que soit leur portee ou le bureau physique visite :
// { offres: { [offreId]: [ { pjNom, statut: 'actif'|'en_attente_arbitrage' } ] } }
async function sbGetEtatBNE(country) {
  const etat = await sbGetBatimentEtat(country, 'national', 'bne');
  return etat.offres ? etat : { offres: {} };
}

async function sbSetEtatBNE(country, offres) {
  return sbSetBatimentEtat(country, 'national', 'bne', { offres });
}

async function sbCreerPret(pret) {
  return await sbInsert('prets', pret);
}

async function sbGetPretsEnCours(nom) {
  const rows = await sbGet('prets', `emprunteur=eq.${encodeURIComponent(nom)}&statut=eq.en_cours`);
  return rows || [];
}

async function sbUpdatePret(id, patch) {
  return await sbUpdate('prets', `id=eq.${encodeURIComponent(id)}`, patch);
}

// NOTE : sbGetTerrainsAvecLotsLoues a ete retiree — le paiement des loyers de lots se fait
// desormais cote serveur (preleverLoyersLots, api/cron-minuit.js), pas via ce client.

async function sbGetTerrainsLibres(country) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}`);
  return rows || [];
}

// Historique PERMANENT des ventes de terrains (contrairement a 'terrains_etat' qui n'ecrase
// que l'etat courant) — chaque achat s'y ajoute, sans jamais rien remplacer. Sert de base
// pour les Archives Notariales.
async function sbEnregistrerVenteTerrain(country, buildingId, proprietaire, prix) {
  return sbInsert('terrains_historique_ventes', {
    id: 'vente-' + buildingId + '-' + Date.now(),
    country, building_id: buildingId, proprietaire, prix
  });
}

async function sbGetHistoriqueTerrain(country, buildingId) {
  const rows = await sbGet('terrains_historique_ventes', `country=eq.${encodeURIComponent(country)}&building_id=eq.${encodeURIComponent(buildingId)}&order=created_at.asc`);
  return rows || [];
}

async function sbGetToutHistoriqueTerrains(country) {
  const rows = await sbGet('terrains_historique_ventes', `country=eq.${encodeURIComponent(country)}&order=created_at.asc`);
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

// =====================
// MEMOIRE DES RENSEIGNEMENTS CONNUS (Phase 1, 22 aout 2026)
// =====================
// renseignements_connus est protegee par RLS, sans policy anon (voir migration_
// renseignements_connus.sql) -- un appel direct via sbGet/sbInsert/sbUpdate (cle anon, comme
// tout le reste de ce fichier) serait rejete par Postgres (verifie en test : SELECT anon ->
// 200 [], INSERT anon -> 401 42501 "new row violates row-level security policy"). Ce helper ne
// touche donc JAMAIS SUPABASE_URL/SB_HEADERS pour cette table -- il passe systematiquement par
// api/renseignements.js (SUPABASE_SERVICE_ROLE_KEY, jamais exposee au client).
//
// Seule l'ecriture est exposee dans cette Phase 1 (revue de securite du 22 aout 2026, avant
// commit) : sbGetRenseignementsPour/sbReactiverRenseignement ont ete retires avec l'action
// serveur correspondante -- un endpoint de lecture par "titulaire" declare par le client,
// sans aucune authentification pour verifier cette identite, aurait recree exactement le
// SELECT arbitraire que RLS etait cense empecher. Reviendront avec un mecanisme de controle
// d'acces reel, dans un lot ulterieur.
async function sbEnregistrerRenseignement(entry) {
  try {
    const res = await fetch('/api/renseignements', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'enregistrer', ...entry })
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) { return null; }
}

// Phase 2 (22 aout 2026) : operation metier dediee (tirer_confidence_escort), pas un 'lister'
// generique -- le serveur charge la memoire du client uniquement pour le tirage pondere et ne
// renvoie jamais que {confidenceObtenue:true|false} (voir api/renseignements.js). Correctif du
// 22 aout 2026 (revue avant GO) : le taux complet (CHA_client/pays/ville/jour/piete) est
// desormais calcule entierement cote serveur, a partir de personnages/indices_villes -- ce
// helper ne transmet plus que chaEscort, la seule donnee sans source serveur possible sans
// dupliquer data.js (PNJ_STATS_PAR_JOB/PNJ_STATS_NOMMES, statique cote client uniquement).
async function sbTirerConfidenceEscort(client, escort, chaEscort) {
  try {
    const res = await fetch('/api/renseignements', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'tirer_confidence_escort', client, escort, chaEscort })
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) { return null; }
}

// Phase 3 (22 aout 2026) : echange volontaire "secret contre secret". Le texte libre du
// joueur (declaration) part tel quel vers le serveur -- l'extraction IA, l'ecriture des deux
// memoires et le tirage de la contrepartie se font entierement dans api/renseignements.js
// (action secret_contre_secret). Reponse : {ok, declarationValide, contrepartie} -- jamais la
// memoire complete de l'escort, uniquement le resultat de CET echange precis.
async function sbEchangerSecretEscort(client, escort, declaration) {
  try {
    const res = await fetch('/api/renseignements', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'secret_contre_secret', client, escort, declaration })
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) { return null; }
}

// Phase 4 (22 aout 2026) : interrogatoire cible d'un PNJ. Le poste (commissaire/juge) et la
// CHA de l'enqueteur sont verifies/lus entierement cote serveur (revue de securite du 22 aout
// 2026, avant GO) -- ce helper ne transmet plus ni poste ni CHA, un appel direct ne peut donc
// plus se declarer habilite ni biaiser le taux. Le ciblage/tirage/ecriture/reactivation se
// font entierement dans api/renseignements.js (action interroger_pnj_sujet). Reponse :
// {ok, statut, revelation} -- jamais la memoire complete du PNJ.
async function sbInterrogerPnjSurSujet(enqueteur, pnj, sujet) {
  try {
    const res = await fetch('/api/renseignements', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'interroger_pnj_sujet', enqueteur, pnj, sujet })
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) { return null; }
}

// Phase 5B (22 aout 2026) : evenement commercial escort reel (embauche/prestation). Ecriture
// fire-and-forget best-effort -- jour/id/jour_expiration entierement calcules cote serveur
// (api/renseignements.js, action enregistrer_evenement_escort). Aucune consommation branchee
// dans ce lot (ni Secret contre secret, ni interrogatoire) -- uniquement l'ecriture.
async function sbEnregistrerEvenementEscort(client, escort, typeEvenement) {
  try {
    const res = await fetch('/api/renseignements', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'enregistrer_evenement_escort', client, escort, type_evenement: typeEvenement })
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) { return null; }
}
