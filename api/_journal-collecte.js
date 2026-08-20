// =====================
// JOURNAL DU JOUR — LOT A : SOCLE DE DONNÉES ET COLLECTE FACTUELLE
// =====================
// Module partagé, PAS un endpoint Vercel (prefixe "_" -> exclu du routage automatique de
// api/, meme convention que documentee par Vercel pour les fichiers internes non-route).
// Construit uniquement le paquet factuel FACTS/PUBLIC_STATEMENTS/INDICATORS/COMPARISONS/
// EDUCATIONAL_REFERENCE et determine les pays eligibles a une edition. AUCUN appel IA, AUCUNE
// ecriture de ligne journal_editions ici -- reserve au Lot B (generation), non encore autorise.
//
// Duplique volontairement certaines constantes/formules de data.js et api/cron-minuit.js :
// ce module tourne dans un contexte serverless isole, sans acces au code client (meme
// convention deja etablie par cron-minuit.js pour RESSOURCES_ECONOMIE_SERVEUR etc.).
//
// DECISION IMPORTANTE (verifiee en direct sur les donnees reelles de production avant d'ecrire
// ce module) : evenements_globaux N'EST JAMAIS utilise comme source ici, bien qu'elle soit
// documentee ailleurs comme "journal partage entre joueurs". Cette table melange, sans aucune
// colonne pour les distinguer : des evenements systeme reels (ex. nominations), du texte
// integralement invente par genererEvenementAleatoire (plateau-divers.js, absurde/parodique,
// aucun rapport avec un fait reel), et des notifications a caractere prive (ex. "Vous avez ete
// arrete(e) pour Crime...") diffusees par erreur de portee. Aucune heuristique de contenu ne
// permet de trier fiablement le reel de l'invente -- l'inclure risquerait de faire passer une
// invention pour un fait certifie, exactement ce que la doctrine editoriale interdit. Tant que
// cette table ne porte pas de colonne de provenance fiable, elle reste hors peripherie du
// Journal.

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';

const HEADERS = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};

async function sbGet(table, filters = '') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, { headers: HEADERS });
  if (!res.ok) { console.error('sbGet error', table, await res.text()); return null; }
  return res.json();
}

// batiments_etat/budgets_municipaux/organisations stockent "data" en JSON serialise (string) ;
// budgets_nationaux/championnat le stockent en jsonb natif (deja un objet). Les deux formes
// coexistent reellement en production (verifie en direct) -- ce helper absorbe la difference.
function parseBlob(data) {
  if (data == null) return {};
  if (typeof data === 'string') { try { return JSON.parse(data); } catch (e) { return {}; } }
  return data;
}

function idSource(table, row) { return `${table}:${row.id}`; }
function idIndicateur(cle) { return `indicateur:${cle}`; }
function idComparaison(cle) { return `comparaison:${cle}`; }

function filtrePeriode(periode) {
  return `created_at=gte.${encodeURIComponent(periode.debut)}&created_at=lt.${encodeURIComponent(periode.fin)}`;
}

// Plafond simple anti-inondation par domaine (conception validee, §14 : eviter d'envoyer
// l'integralite de la base a l'IA). Pas de tri par pertinence en Lot A -- juste une borne dure.
const LIMITE_PAR_DOMAINE = 50;

// Duplique de COUNTRIES (data.js).
const PAYS_JEU = ['republic', 'narco', 'soviet', 'khalija'];

// Duplique de CLUBS_SPORTIFS (data.js) -- seuls les champs necessaires ici (id/nom/country).
const CLUBS_SPORTIFS = [
  { id: 'olympique-luthecia',  nom: 'Olympique de Luthécia',        country: 'republic' },
  { id: 'brise-mariannaise',   nom: 'La Brise Mariannaise',         country: 'republic' },
  { id: 'cheminote-montrouge', nom: 'Union Cheminote de Montrouge', country: 'republic' },
  { id: 'rojos-cartel',        nom: 'Rojos del Cartel',             country: 'narco' },
  { id: 'fronterizos-unidos',  nom: 'Fronterizos Unidos',           country: 'narco' },
  { id: 'jaguares-selva',      nom: 'Jaguares de la Selva',         country: 'narco' },
  { id: 'dynamo-novomirsk',    nom: 'Dynamo Novomirsk',             country: 'soviet' },
  { id: 'spartak-sibirsk',     nom: 'Spartak Sibirsk-9',            country: 'soviet' },
  { id: 'kolkhoze-ouvrier',    nom: 'Kolkhoze Ouvrier FC',          country: 'soviet' },
  { id: 'nadi-al-madina',      nom: 'Nadi Al-Madina',               country: 'khalija' },
  { id: 'al-baraka-fc',        nom: 'Al-Baraka FC',                 country: 'khalija' },
  { id: 'sharq-al-nour',       nom: 'Sharq Al-Nour',                country: 'khalija' }
];

// Duplique de RESSOURCES_ECONOMIE (data.js, plafond+prixBase seulement) et de sa formule
// getPrixRessource (data.js:5825) -- stock eleve = prix bas, stock faible = prix haut.
const RESSOURCES_ECONOMIE = {
  cereales:    { plafond: 150, prixBase: 1.5 },
  poisson:     { plafond: 125, prixBase: 2 },
  viande:      { plafond: 125, prixBase: 2.5 },
  bois:        { plafond: 750, prixBase: 2.5 },
  charbon:     { plafond: 400, prixBase: 3.5 },
  petrole:     { plafond: 200, prixBase: 4 },
  minerai:     { plafond: 500, prixBase: 5 },
  metal:       { plafond: 200, prixBase: 7.5 },
  plantes:     { plafond: 300, prixBase: 3 },
  // Lot boissons (20 aout 2026) : valeurs miroir de RESSOURCES_ECONOMIE.fruits_legumes/
  // produits_exotiques, data.js -- meme convention que le reste de cette table (prixBase
  // contient ici prixAchatFournisseur, pas le prixBase reel).
  fruits_legumes:     { plafond: 150, prixBase: 2 },
  produits_exotiques: { plafond: 125, prixBase: 3 },
  medicaments: { plafond: 100, prixBase: 11 },
  alcool:      { plafond: 100, prixBase: 7 },
  tabac:       { plafond: 100, prixBase: 9 },
  carburant:   { plafond: 100, prixBase: 10 },
  // Filiere alcool->desinfectant (20 aout 2026) : valeurs miroir de RESSOURCES_ECONOMIE.desinfectant, data.js.
  desinfectant: { plafond: 100, prixBase: 9 }
};

function getPrixRessource(cle, quantiteEnStock) {
  const res = RESSOURCES_ECONOMIE[cle];
  if (!res) return null;
  const tauxRemplissage = Math.max(0, Math.min(1, quantiteEnStock / res.plafond));
  const variation = (0.5 - tauxRemplissage) * 0.8;
  return Math.round(res.prixBase * (1 + variation) * 100) / 100;
}

// Duplique de ENTREPOTS_VILLES (api/cron-minuit.js) -- UNIQUEMENT republic aujourd'hui : aucune
// liste equivalente n'existe dans le code actuel pour narco/soviet/khalija (l'automatisation
// entrepot/usine quotidienne du cron ne tourne que pour republic). Ce n'est pas un cas special
// code pour Republia : la fonction qui l'utilise reste generique et interroge simplement ce qui
// EST enregistre ici pour le pays demande -- si rien n'y figure, l'indicateur revient
// honnetement indisponible, sans rien inventer.
const ENTREPOTS_PAR_PAYS = {
  republic: [
    { buildingId: 'entrepot-logistique-luthecia',  city: 'capitale' },
    { buildingId: 'entrepot-logistique-psm',       city: 'ville_a' },
    { buildingId: 'entrepot-logistique-montrouge', city: 'ville_b' }
  ]
};

// =====================
// 1. PAYS ÉLIGIBLES — COUNT(personnages) WHERE country = X >= 1, générique, aucun cas spécial.
// =====================
async function determinerPaysEligibles() {
  const eligibles = [];
  for (const pays of PAYS_JEU) {
    const rows = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=id&limit=1`);
    if (rows && rows.length >= 1) eligibles.push(pays);
  }
  return eligibles;
}

// =====================
// 2. PÉRIODE — jamais state.day (personnel, dépendant de la consommation de PA de chaque
// personnage, non fiable comme horloge partagée — verifié dans l'audit). Fenêtre réelle ancrée
// sur [dernière édition PUBLIÉE de ce pays, maintenant], repli 24h si aucune n'existe encore —
// auto-cicatrisant si une génération a été manquée, sans dépendre de l'heure de connexion d'un
// joueur.
// =====================
async function calculerPeriode(pays) {
  const fin = new Date();
  let debut = new Date(fin.getTime() - 24 * 60 * 60 * 1000);
  const dernieres = await sbGet('journal_editions',
    `country=eq.${encodeURIComponent(pays)}&statut=eq.publiee&order=generated_at.desc&limit=1`).catch(() => null);
  if (dernieres && dernieres[0] && dernieres[0].generated_at) {
    debut = new Date(dernieres[0].generated_at);
  }
  return { debut: debut.toISOString(), fin: fin.toISOString() };
}

// =====================
// 3. FACTS — sources classées "disponible immédiatement" ou "calculable" dans l'audit validé.
// Exclues explicitement : terrains_historique_ventes (incomplète — reventes joueur-à-joueur non
// couvertes, décision validée), tout volume vendu (aucune table de transaction n'existe),
// production/livraison quotidienne (jamais persistée), historique entreprises (daté en jour de
// jeu, non fiable), evenements_globaux (voir décision en tête de fichier).
// =====================

async function collecterEtatCivil(periode) {
  const f = filtrePeriode(periode);
  const [naissances, mariages, deces] = await Promise.all([
    sbGet('etat_civil_naissances', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`),
    sbGet('mariages', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`),
    sbGet('etat_civil_deces', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`)
  ]);
  const facts = [];
  (naissances || []).forEach(r => facts.push({
    id: idSource('etat_civil_naissances', r), domaine: 'etat_civil', type: 'naissance',
    ville: r.city || null, pays: r.country,
    resume: `Naissance de ${r.nom}` + (r.city ? ` à ${r.city}` : ''),
    created_at: r.created_at
  }));
  (mariages || []).forEach(r => facts.push({
    id: idSource('mariages', r), domaine: 'etat_civil', type: 'mariage',
    ville: r.city || null, pays: r.country,
    resume: `Mariage de ${r.conjoint1} et ${r.conjoint2}` + (r.city ? ` à ${r.city}` : ''),
    created_at: r.created_at
  }));
  // Divorces/veuvages volontairement exclus : "mariages" n'a pas de date de dissolution
  // distincte de created_at (qui reste toujours la date du mariage lui-même) — la période d'une
  // dissolution éventuelle n'est donc jamais garantie.
  (deces || []).forEach(r => facts.push({
    id: idSource('etat_civil_deces', r), domaine: 'etat_civil', type: 'deces',
    ville: r.city || null, pays: r.country,
    resume: `Décès de ${r.nom}` + (r.city ? ` à ${r.city}` : ''),
    created_at: r.created_at
  }));
  return facts;
}

async function collecterJustice(periode) {
  const f = filtrePeriode(periode);
  const [detentions, jugements] = await Promise.all([
    sbGet('detentions', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`),
    sbGet('jugements', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`)
  ]);
  const facts = [];
  (detentions || []).forEach(r => facts.push({
    id: idSource('detentions', r), domaine: 'justice', type: 'arrestation',
    ville: r.city || null, pays: r.country,
    resume: `${r.nom} a été placé(e) en détention (${r.raison})`,
    created_at: r.created_at
  }));
  (jugements || []).forEach(r => facts.push({
    id: idSource('jugements', r), domaine: 'justice', type: 'condamnation',
    ville: r.city || null, pays: r.country,
    resume: `${r.accuse} a été condamné(e) pour ${r.motif} : ${r.peine}`,
    created_at: r.created_at
  }));
  return facts;
}

async function collecterCandidatures(periode) {
  const f = filtrePeriode(periode);
  const rows = await sbGet('candidatures', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  return (rows || []).map(r => ({
    id: idSource('candidatures', r), domaine: 'politique', type: 'candidature',
    ville: r.city || null, pays: r.country,
    resume: `${r.nom} a déposé sa candidature au poste de ${r.poste_id}` + (r.city ? ` à ${r.city}` : ''),
    created_at: r.created_at
  }));
}

// Scores structurés (nombres, pas du texte narratif) tirés directement de championnat.data —
// pas du forum. Chaque journée n'a pas de date stockée ; elle est calculée déterministement à
// partir de dateDebut + (numero-1) semaines, cohérent avec la règle réelle du jeu ("1 journée
// par semaine", plateau-organisations-quetes.js). Un match est inclus si sa journée calculée
// tombe dans la période ET qu'il a réellement été joué (played === true).
async function collecterFootball(periode) {
  const rows = await sbGet('championnat', 'id=eq.1&select=data');
  if (!rows || !rows[0]) return [];
  const data = parseBlob(rows[0].data);
  if (!data.dateDebut || !Array.isArray(data.calendrier)) return [];
  const dateDebut = new Date(data.dateDebut).getTime();
  const debutMs = new Date(periode.debut).getTime();
  const finMs = new Date(periode.fin).getTime();
  const facts = [];
  data.calendrier.forEach(journee => {
    const dateJournee = dateDebut + (journee.numero - 1) * 7 * 24 * 60 * 60 * 1000;
    if (dateJournee < debutMs || dateJournee >= finMs) return;
    (journee.matchs || []).forEach(m => {
      if (!m.played) return;
      const clubHome = CLUBS_SPORTIFS.find(c => c.id === m.home);
      const clubAway = CLUBS_SPORTIFS.find(c => c.id === m.away);
      facts.push({
        id: idSource('championnat', { id: `j${journee.numero}-${m.home}-${m.away}` }),
        domaine: 'sport', type: 'resultat_match',
        ville: null,
        pays: [clubHome && clubHome.country, clubAway && clubAway.country].filter(Boolean),
        resume: `${(clubHome && clubHome.nom) || m.home} ${m.scoreHome} - ${m.scoreAway} ${(clubAway && clubAway.nom) || m.away}`,
        created_at: new Date(dateJournee).toISOString()
      });
    });
  });
  if (facts.length > LIMITE_PAR_DOMAINE) facts.length = LIMITE_PAR_DOMAINE;
  return facts;
}

// =====================
// 4. PUBLIC_STATEMENTS — forum uniquement, catégories publiques seulement (même filtre que
// FORUMS_BASE/getForums(), forum.js : gouvernement/presse = private:true, org_* = private:true,
// tout le reste, y compris tribunal_<ville>, est public). "Ligue Officielle" est exclue : ses
// résultats sont déjà collectés en FACTS structurés via championnat, l'inclure aussi ici ne
// ferait que dupliquer la même information sous une autre forme.
// =====================

function estForumPublic(forumId) {
  if (!forumId) return false;
  if (forumId === 'gouvernement' || forumId === 'presse') return false;
  if (forumId.indexOf('org_') === 0) return false;
  return true;
}

async function collecterDeclarationsPubliques(periode) {
  const f = filtrePeriode(periode);
  const topics = await sbGet('forum_topics',
    `${f}&select=id,forum_id,title,author,author_is_org,country,created_at&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  const topicsPublics = (topics || []).filter(t => estForumPublic(t.forum_id) && t.author !== 'Ligue Officielle');
  const statements = topicsPublics.map(t => ({
    id: idSource('forum_topics', t), domaine: 'forum', type: 'sujet',
    auteur: t.author, auteur_est_organisation: !!t.author_is_org,
    forum_id: t.forum_id, pays: t.country,
    extrait: t.title, created_at: t.created_at
  }));

  const posts = await sbGet('forum_posts',
    `${f}&select=id,topic_id,author,content,author_is_org,created_at&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  if (posts && posts.length > 0) {
    // forum_posts n'a ni forum_id ni country (vérifié dans l'audit) — il faut recharger le
    // sujet parent de chaque post pour connaître son forum/pays et vérifier qu'il est public.
    const topicIds = [...new Set(posts.map(p => p.topic_id))];
    const topicsParents = topicIds.length > 0
      ? await sbGet('forum_topics', `id=in.(${topicIds.map(encodeURIComponent).join(',')})&select=id,forum_id,country`)
      : [];
    const parentById = {};
    (topicsParents || []).forEach(t => { parentById[t.id] = t; });
    posts.forEach(p => {
      const parent = parentById[p.topic_id];
      if (!parent || !estForumPublic(parent.forum_id)) return;
      if (p.author === 'Ligue Officielle') return;
      statements.push({
        id: idSource('forum_posts', p), domaine: 'forum', type: 'reponse',
        auteur: p.author, auteur_est_organisation: !!p.author_is_org,
        forum_id: parent.forum_id, pays: parent.country,
        extrait: (p.content || '').slice(0, 400), created_at: p.created_at
      });
    });
  }
  return statements;
}

// =====================
// 5. INDICATORS — états actuels (snapshots), toujours présentés comme tels, jamais comme un
// événement daté.
// =====================

async function collecterIndicateursPopulation(pays) {
  const rows = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=current_city&limit=2000`);
  const liste = rows || [];
  const parVille = {};
  liste.forEach(r => {
    const v = r.current_city || 'inconnue';
    parVille[v] = (parVille[v] || 0) + 1;
  });
  return [
    { id: idIndicateur(`population_totale_${pays}`), cle: 'population_totale', valeur: liste.length, pays, disponible: true },
    { id: idIndicateur(`population_par_ville_${pays}`), cle: 'population_par_ville', valeur: parVille, pays, disponible: true }
  ];
}

// Prix/stock — respecte prixManuel (fixé par un directeur PJ) avant la formule automatique,
// exigence explicitement validée. Republic-only en pratique aujourd'hui (voir ENTREPOTS_PAR_PAYS
// ci-dessus) ; reste générique, ne fabrique jamais de bâtiment pour un pays qui n'en a pas.
async function collecterIndicateursEconomiques(pays) {
  const entrepots = ENTREPOTS_PAR_PAYS[pays] || [];
  if (entrepots.length === 0) {
    return [{
      id: idIndicateur(`prix_stock_${pays}`), cle: 'prix_stock_ressources', valeur: null,
      pays, disponible: false,
      raison_indisponibilite: 'aucune instrumentation entrepôt/usine enregistrée pour ce pays actuellement'
    }];
  }
  const indicateurs = [];
  for (const entrepot of entrepots) {
    const rows = await sbGet('batiments_etat',
      `id=eq.${encodeURIComponent(pays + '_' + entrepot.city + '_' + entrepot.buildingId)}&select=data`);
    if (!rows || !rows[0]) continue;
    const etat = parseBlob(rows[0].data);
    const stock = (etat.entrepot && etat.entrepot.stock) || {};
    const prixManuel = (etat.entrepot && etat.entrepot.prixManuel) || {};
    Object.keys(stock).forEach(cle => {
      const enStock = stock[cle];
      const prixFixeManuel = prixManuel[cle] != null;
      const prix = prixFixeManuel ? prixManuel[cle] : getPrixRessource(cle, enStock);
      indicateurs.push({
        id: idIndicateur(`prix_${cle}_${pays}_${entrepot.city}`), cle: `prix_${cle}`,
        valeur: prix, ville: entrepot.city, pays, disponible: prix != null, prix_manuel: prixFixeManuel
      });
      indicateurs.push({
        id: idIndicateur(`stock_${cle}_${pays}_${entrepot.city}`), cle: `stock_${cle}`,
        valeur: enStock, ville: entrepot.city, pays, disponible: true
      });
    });
  }
  return indicateurs;
}

async function collecterIndicateursCaisses(pays) {
  const indicateurs = [];
  const rowsNat = await sbGet('budgets_nationaux', `id=eq.${encodeURIComponent(pays)}&select=data`);
  if (rowsNat && rowsNat[0]) {
    const data = parseBlob(rowsNat[0].data);
    indicateurs.push({
      id: idIndicateur(`caisse_nationale_${pays}`), cle: 'caisse_nationale',
      valeur: data.reserveJour != null ? data.reserveJour : null,
      pays, disponible: data.reserveJour != null
    });
  }
  // Villes "connues" = villes où vivent réellement des personnages de ce pays aujourd'hui — pas
  // une liste WORLD statique (WORLD n'a pas narco, voir audit) : ce mécanisme reste générique
  // aux 4 pays sans dépendre de cette lacune préexistante et hors périmètre.
  const perso = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=current_city&limit=2000`);
  const villes = [...new Set((perso || []).map(r => r.current_city).filter(Boolean))];
  for (const ville of villes) {
    const rows = await sbGet('budgets_municipaux', `id=eq.${encodeURIComponent(pays + '_' + ville)}&select=data`);
    if (!rows || !rows[0]) continue;
    const data = parseBlob(rows[0].data);
    indicateurs.push({
      id: idIndicateur(`caisse_municipale_${pays}_${ville}`), cle: 'caisse_municipale',
      valeur: data.caisse != null ? data.caisse : null, ville, pays, disponible: data.caisse != null
    });
  }
  return indicateurs;
}

// Classement — snapshot recalculé (pas d'historique de progression, voir audit : catégorie C
// pour "a gagné des places", catégorie A pour la position actuelle elle-même).
async function collecterIndicateurClassement(pays) {
  const rows = await sbGet('championnat', 'id=eq.1&select=data');
  if (!rows || !rows[0]) return [];
  const data = parseBlob(rows[0].data);
  if (!Array.isArray(data.calendrier)) return [];
  const clubsPays = CLUBS_SPORTIFS.filter(c => c.country === pays).map(c => c.id);
  if (clubsPays.length === 0) return [];
  const table = {};
  CLUBS_SPORTIFS.forEach(c => { table[c.id] = { id: c.id, nom: c.nom, pts: 0, bp: 0, bc: 0 }; });
  data.calendrier.forEach(journee => {
    (journee.matchs || []).forEach(m => {
      if (!m.played) return;
      const home = table[m.home], away = table[m.away];
      if (!home || !away) return;
      home.bp += m.scoreHome; home.bc += m.scoreAway;
      away.bp += m.scoreAway; away.bc += m.scoreHome;
      if (m.scoreHome > m.scoreAway) home.pts += 3;
      else if (m.scoreHome < m.scoreAway) away.pts += 3;
      else { home.pts++; away.pts++; }
    });
  });
  const classement = Object.values(table).sort((a, b) => b.pts - a.pts || (b.bp - b.bc) - (a.bp - a.bc));
  const rangClubsPays = clubsPays.map(id => ({
    club: table[id].nom, rang: classement.findIndex(c => c.id === id) + 1, points: table[id].pts
  }));
  return [{
    id: idIndicateur(`classement_${pays}`), cle: 'classement_clubs_nationaux', valeur: rangClubsPays,
    pays, disponible: true
  }];
}

// =====================
// 6. COMPARISONS — calculées par le code, jamais par l'IA. Auto-amorcées par l'archive des
// éditions publiées elles-même (pas de nouvelle table d'historique) : sans édition antérieure,
// aucune comparaison n'est produite (jamais d'extrapolation).
// =====================
const CLES_INDICATEURS_ABSENCE = [
  'naissances_periode', 'mariages_periode', 'deces_periode',
  'arrestations_periode', 'condamnations_periode', 'candidatures_periode'
];

async function calculerComparaisons(pays, indicateursActuels) {
  const comparaisons = [];
  const precedentes = await sbGet('journal_editions',
    `country=eq.${encodeURIComponent(pays)}&statut=eq.publiee&order=date_edition.desc&limit=8&select=faits_sources`)
    .catch(() => null);
  if (!precedentes || precedentes.length === 0) return comparaisons; // aucun historique -> aucune comparaison

  CLES_INDICATEURS_ABSENCE.forEach(cle => {
    const actuel = indicateursActuels.find(i => i.cle === cle);
    if (!actuel || actuel.valeur !== 0) return; // on ne signale une absence que si c'est réellement zéro
    let editionsConsecutivesAZero = 1;
    for (const edition of precedentes) {
      const anciens = (edition.faits_sources && edition.faits_sources.INDICATORS) || [];
      const ancien = anciens.find(i => i.cle === cle);
      if (ancien && ancien.valeur === 0) editionsConsecutivesAZero++;
      else break;
    }
    const suffixe = editionsConsecutivesAZero >= 2 ? `, pour la ${editionsConsecutivesAZero}ᵉ édition consécutive` : '';
    comparaisons.push({
      id: idComparaison(`${cle}_absence_${pays}`), cle: `${cle}_absence`,
      constat_precalcule: `Zéro sur cette période${suffixe}`, fiable: true
    });
  });
  return comparaisons;
}

// =====================
// 7. EDUCATIONAL_REFERENCE — aucune bibliothèque de fiches n'existe encore (Lot E, hors
// périmètre du Lot A). Le contrat représente proprement cette absence plutôt que d'inventer un
// contenu.
// =====================
function collecterReferencePedagogique() {
  return { fiche_id: null, contenu_valide: null };
}

// =====================
// 8. ORCHESTRATEUR — construit le paquet complet pour un pays et une période donnés.
// =====================
async function construirePaquetFactuel(pays, periode) {
  const [etatCivil, justice, candidatures, football, declarations] = await Promise.all([
    collecterEtatCivil(periode),
    collecterJustice(periode),
    collecterCandidatures(periode),
    collecterFootball(periode),
    collecterDeclarationsPubliques(periode)
  ]);

  const FACTS = [...etatCivil, ...justice, ...candidatures, ...football];

  const factsDuPays = f => (Array.isArray(f.pays) ? f.pays.includes(pays) : f.pays === pays);
  const compterType = type => FACTS.filter(f => f.type === type && factsDuPays(f)).length;

  const [indicPopulation, indicEco, indicCaisses, indicClassement] = await Promise.all([
    collecterIndicateursPopulation(pays),
    collecterIndicateursEconomiques(pays),
    collecterIndicateursCaisses(pays),
    collecterIndicateurClassement(pays)
  ]);

  const INDICATORS = [
    ...indicPopulation,
    { id: idIndicateur(`naissances_periode_${pays}`), cle: 'naissances_periode', valeur: compterType('naissance'), pays, disponible: true },
    { id: idIndicateur(`mariages_periode_${pays}`), cle: 'mariages_periode', valeur: compterType('mariage'), pays, disponible: true },
    { id: idIndicateur(`deces_periode_${pays}`), cle: 'deces_periode', valeur: compterType('deces'), pays, disponible: true },
    { id: idIndicateur(`arrestations_periode_${pays}`), cle: 'arrestations_periode', valeur: compterType('arrestation'), pays, disponible: true },
    { id: idIndicateur(`condamnations_periode_${pays}`), cle: 'condamnations_periode', valeur: compterType('condamnation'), pays, disponible: true },
    { id: idIndicateur(`candidatures_periode_${pays}`), cle: 'candidatures_periode', valeur: compterType('candidature'), pays, disponible: true },
    ...indicEco,
    ...indicCaisses,
    ...indicClassement
  ];

  const COMPARISONS = await calculerComparaisons(pays, INDICATORS);

  return {
    country: pays,
    periode,
    FACTS,
    PUBLIC_STATEMENTS: declarations,
    INDICATORS,
    COMPARISONS,
    EDUCATIONAL_REFERENCE: collecterReferencePedagogique()
  };
}

export {
  PAYS_JEU,
  determinerPaysEligibles,
  calculerPeriode,
  construirePaquetFactuel,
  estForumPublic,
  getPrixRessource,
  idSource,
  idIndicateur,
  idComparaison,
  parseBlob
};
