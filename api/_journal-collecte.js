// =====================
// LA TRIBUNE DE RÉPUBLIA — LOT A : SOCLE DE DONNÉES ET COLLECTE FACTUELLE
// =====================
// Module partagé, PAS un endpoint Vercel (prefixe "_" -> exclu du routage automatique de
// api/, meme convention que documentee par Vercel pour les fichiers internes non-route).
// Construit le paquet factuel FACTS/PUBLIC_STATEMENTS/INDICATORS/INTERVIEW_JODIE et determine
// les pays eligibles a une edition. AUCUN appel IA, AUCUNE ecriture de ligne journal_editions ici
// -- reserve au Lot B (generation).
//
// REFONTE (31 aout 2026, "La Tribune de Republia" -- priorite aux PJ) : remplace l'ancien socle
// neutre par un socle qui QUALIFIE chaque fait avant meme que l'IA ne le voie (champ "poids" +
// champ "estPJ"), conformement a la doctrine validee : « Le code doit selectionner et qualifier
// les informations. Claude doit hierarchiser a l'interieur du cadre fourni, pas construire ce
// cadre. » Voir bumpPoids()/qualifierFait() plus bas pour la logique de qualification.
//
// SUPPRESSION DU MECANISME "ABSENCE = ACTUALITE" (audit du 31 aout 2026, section 6) : l'ancien
// calculerComparaisons()/CLES_INDICATEURS_ABSENCE produisait mecaniquement "Zero sur cette
// periode, pour la Neme edition consecutive" des qu'un compteur (naissances/mariages/deces/
// arrestations/condamnations/candidatures) valait 0 -- notamment pour naissances_periode, qui ne
// mesure meme pas une naissance reelle (voir commentaire sur collecterEtatCivil). Ce mecanisme est
// entierement retire du paquet editorial. Les compteurs eux-memes restent calcules (INDICATORS,
// derniere page) : seule la fabrication d'une phrase "absence = actualite" disparait.
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

// Plafond simple anti-inondation par domaine (conception validee, §14 audit original : eviter
// d'envoyer l'integralite de la base a l'IA). Pas de tri par pertinence ici -- juste une borne dure.
const LIMITE_PAR_DOMAINE = 50;

// Duplique de COUNTRIES (data.js).
const PAYS_JEU = ['republic', 'narco', 'soviet', 'khalija'];

// Duplique de VILLES_PAR_EMPIRE (plateau-navigation.js) -- meme convention que les autres
// constantes de ce fichier (module serverless isole, sans acces au code client).
const NOMS_VILLES = {
  republic: { capitale: 'Luthécia',       ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' },
  narco:    { capitale: 'Ciudad Roja',    ville_a: 'Puerto Oscuro',     ville_b: 'La Selva' },
  soviet:   { capitale: 'Novomirsk',      ville_a: 'Stalinova',         ville_b: 'Kolkhoz-7' },
  khalija:  { capitale: 'Al-Madina',      ville_a: 'Oasis Al-Zafar',    ville_b: 'Port Al-Nour' }
};

function resoudreNomVille(pays, villeId) {
  if (!villeId) return null;
  return (NOMS_VILLES[pays] && NOMS_VILLES[pays][villeId]) || villeId;
}

// Duplique de CLUBS_SPORTIFS (data.js) -- champs necessaires ici, plus imageStade (duplique des
// imageUrl reels des salles "terrain" des batiments 'stade', un par club -- jamais invente : seuls
// les 3 clubs republic ont une image dupliquee ici car verifiee reellement presente dans data.js ;
// les autres pays gardent imageStade:null, resolu proprement en "fallback" plutot qu'en URL fausse).
const CLUBS_SPORTIFS = [
  { id: 'olympique-luthecia',  nom: 'Olympique de Luthécia',        country: 'republic', city: 'capitale', imageStade: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-olympique-luthecia.png' },
  { id: 'brise-mariannaise',   nom: 'La Brise Mariannaise',         country: 'republic', city: 'ville_a',  imageStade: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-brise-mariannaise.png' },
  { id: 'cheminote-montrouge', nom: 'Union Cheminote de Montrouge', country: 'republic', city: 'ville_b',  imageStade: 'images/montrouge/montrouge-stade-pelouse-accueil.jpg' },
  { id: 'rojos-cartel',        nom: 'Rojos del Cartel',             country: 'narco', city: 'capitale', imageStade: null },
  { id: 'fronterizos-unidos',  nom: 'Fronterizos Unidos',           country: 'narco', city: 'ville_a',  imageStade: null },
  { id: 'jaguares-selva',      nom: 'Jaguares de la Selva',         country: 'narco', city: 'ville_b',  imageStade: null },
  { id: 'dynamo-novomirsk',    nom: 'Dynamo Novomirsk',             country: 'soviet', city: 'capitale', imageStade: null },
  { id: 'spartak-sibirsk',     nom: 'Spartak Sibirsk-9',            country: 'soviet', city: 'ville_a',  imageStade: null },
  { id: 'kolkhoze-ouvrier',    nom: 'Kolkhoze Ouvrier FC',          country: 'soviet', city: 'ville_b',  imageStade: null },
  { id: 'nadi-al-madina',      nom: 'Nadi Al-Madina',               country: 'khalija', city: 'capitale', imageStade: null },
  { id: 'al-baraka-fc',        nom: 'Al-Baraka FC',                 country: 'khalija', city: 'ville_a',  imageStade: null },
  { id: 'sharq-al-nour',       nom: 'Sharq Al-Nour',                country: 'khalija', city: 'ville_b',  imageStade: null }
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
  fruits_legumes:     { plafond: 150, prixBase: 2 },
  produits_exotiques: { plafond: 125, prixBase: 3 },
  medicaments: { plafond: 100, prixBase: 11 },
  alcool:      { plafond: 100, prixBase: 7 },
  tabac:       { plafond: 100, prixBase: 9 },
  carburant:   { plafond: 100, prixBase: 10 },
  desinfectant: { plafond: 100, prixBase: 9 }
};

function getPrixRessource(cle, quantiteEnStock) {
  const res = RESSOURCES_ECONOMIE[cle];
  if (!res) return null;
  const tauxRemplissage = Math.max(0, Math.min(1, quantiteEnStock / res.plafond));
  const variation = (0.5 - tauxRemplissage) * 0.8;
  return Math.round(res.prixBase * (1 + variation) * 100) / 100;
}

// Duplique de ENTREPOTS_VILLES (api/cron-minuit.js) -- UNIQUEMENT republic aujourd'hui (voir
// commentaire d'origine, inchange par cette refonte).
const ENTREPOTS_PAR_PAYS = {
  republic: [
    { buildingId: 'entrepot-logistique-luthecia',  city: 'capitale' },
    { buildingId: 'entrepot-logistique-psm',       city: 'ville_a' },
    { buildingId: 'entrepot-logistique-montrouge', city: 'ville_b' }
  ]
};

// =====================
// QUALIFICATION EDITORIALE DETERMINISTE — score d'interet, jamais visible du joueur, jamais une
// usine a gaz (conception validee, section 4 du cahier des charges refonte) : 4 paliers ordonnes,
// une regle de base par type de fait, un "bonus PJ" qui fait monter d'un ou deux paliers. Le
// modele IA ne choisit jamais ce champ -- il le recoit deja pose sur chaque fait.
// =====================
const POIDS_ORDRE = ['mineur', 'secondaire', 'important', 'majeur'];
function bumpPoids(poidsBase, crans) {
  const i = POIDS_ORDRE.indexOf(poidsBase);
  const cible = Math.min(POIDS_ORDRE.length - 1, Math.max(0, i) + crans);
  return POIDS_ORDRE[cible];
}

// =====================
// IDENTIFICATION PJ — méthode validée par l'audit (31 aout 2026) : la table "personnages" ne
// contient QUE des personnages joueurs (une ligne par creation de PJ, creation.js). Un nom qui y
// figure est un PJ ; un nom absent est un PNJ (les PNJ n'ont jamais de ligne dans cette table).
// Meme convention deja utilisee ailleurs dans le code (champ "isPJ", plateau-communication.js/
// plateau-actions-illegales-rumeurs.js) -- ici generalisee a n'importe quel nom trouve dans un
// fait, pas seulement aux personnes presentes dans une salle.
// =====================
async function chargerPersonnagesConnus(pays) {
  const rows = await sbGet('personnages',
    `country=eq.${encodeURIComponent(pays)}&select=name,photo_url,poste,current_city`);
  const map = new Map();
  (rows || []).forEach(r => map.set(r.name, { photo_url: r.photo_url || null, poste: r.poste || null, current_city: r.current_city || null }));
  return map;
}

function identifierActeur(nom, personnagesConnus) {
  if (!nom) return { estPJ: false, photo_url: null };
  const p = personnagesConnus.get(nom);
  return p ? { estPJ: true, photo_url: p.photo_url } : { estPJ: false, photo_url: null };
}

// Un PJ recemment mis en avant (Une/article "majeur" des 2 dernieres editions publiees) -- utilise
// UNIQUEMENT comme signal de diversite editoriale pour l'IA (§9 refonte : "a interet comparable,
// favoriser la diversite" -- jamais un veto code, la verite factuelle reste toujours prioritaire).
// Volontairement leger : pas de nouvelle table, relit simplement faits_sources.FACTS des editions
// deja archivees.
async function chargerExpositionRecente(pays) {
  const precedentes = await sbGet('journal_editions',
    `country=eq.${encodeURIComponent(pays)}&statut=eq.publiee&order=date_edition.desc&limit=2&select=faits_sources`)
    .catch(() => null);
  const noms = new Set();
  (precedentes || []).forEach(edition => {
    const facts = (edition.faits_sources && edition.faits_sources.FACTS) || [];
    facts.forEach(f => {
      if (f.poids === 'majeur' && f.estPJ && f.acteur) noms.add(f.acteur);
    });
  });
  return noms;
}

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
// personnage, non fiable comme horloge partagée). Fenêtre réelle ancrée sur [dernière édition
// PUBLIÉE de ce pays, maintenant], repli 24h si aucune n'existe encore.
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
// 3. FACTS — sources classées "disponible immédiatement" ou "calculable". Chaque fait porte
// desormais : estPJ, acteur (nom du protagoniste principal, pour le suivi d'exposition), photo_url
// (si un PJ identifie en possede une) et poids (voir qualification ci-dessus).
// =====================

async function collecterEtatCivil(periode, personnagesConnus) {
  const f = filtrePeriode(periode);
  const [naissances, mariages, deces] = await Promise.all([
    sbGet('etat_civil_naissances', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`),
    sbGet('mariages', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`),
    sbGet('etat_civil_deces', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`)
  ]);
  const facts = [];
  // "arrivee" (jamais "naissance", voir audit 31 aout 2026) : etat_civil_naissances enregistre la
  // date de creation du personnage (creation.js/sbEnregistrerNaissance), pas un evenement
  // demographique. Poids toujours "mineur" (une arrivee de PJ est une information de carnet, pas
  // un evenement editorial en soi) -- jamais remontee comme "actualite" par ce module ; elle ne
  // finira sur la derniere page (carnet) que si l'IA ne la cite dans aucun article, ce qui sera
  // presque toujours le cas et c'est le comportement voulu.
  (naissances || []).forEach(r => {
    const acteur = identifierActeur(r.nom, personnagesConnus);
    facts.push({
      id: idSource('etat_civil_naissances', r), domaine: 'etat_civil', type: 'arrivee',
      ville: resoudreNomVille(r.country, r.city), pays: r.country,
      resume: `Arrivée de ${r.nom}` + (r.city ? ` à ${resoudreNomVille(r.country, r.city)}` : ''),
      acteur: r.nom, estPJ: acteur.estPJ, photo_url: acteur.photo_url, poids: 'mineur',
      created_at: r.created_at
    });
  });
  (mariages || []).forEach(r => {
    const a1 = identifierActeur(r.conjoint1, personnagesConnus);
    const a2 = identifierActeur(r.conjoint2, personnagesConnus);
    const estPJ = a1.estPJ || a2.estPJ;
    facts.push({
      id: idSource('mariages', r), domaine: 'etat_civil', type: 'mariage',
      ville: resoudreNomVille(r.country, r.city), pays: r.country,
      resume: `Mariage de ${r.conjoint1} et ${r.conjoint2}` + (r.city ? ` à ${resoudreNomVille(r.country, r.city)}` : ''),
      acteur: a1.estPJ ? r.conjoint1 : r.conjoint2, estPJ,
      photo_url: a1.photo_url || a2.photo_url,
      poids: bumpPoids('secondaire', estPJ ? 1 : 0),
      created_at: r.created_at
    });
  });
  // Divorces/veuvages volontairement exclus : "mariages" n'a pas de date de dissolution distincte.
  (deces || []).forEach(r => {
    const acteur = identifierActeur(r.nom, personnagesConnus);
    facts.push({
      id: idSource('etat_civil_deces', r), domaine: 'etat_civil', type: 'deces',
      ville: resoudreNomVille(r.country, r.city), pays: r.country,
      resume: `Décès de ${r.nom}` + (r.city ? ` à ${resoudreNomVille(r.country, r.city)}` : ''),
      acteur: r.nom, estPJ: acteur.estPJ, photo_url: acteur.photo_url,
      poids: bumpPoids('mineur', acteur.estPJ ? 1 : 0),
      created_at: r.created_at
    });
  });
  return facts;
}

async function collecterJustice(periode, personnagesConnus) {
  const f = filtrePeriode(periode);
  const [detentions, jugements] = await Promise.all([
    sbGet('detentions', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`),
    sbGet('jugements', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`)
  ]);
  const facts = [];
  (detentions || []).forEach(r => {
    const acteur = identifierActeur(r.nom, personnagesConnus);
    facts.push({
      id: idSource('detentions', r), domaine: 'justice', type: 'arrestation',
      ville: resoudreNomVille(r.country, r.city), pays: r.country,
      resume: `${r.nom} a été placé(e) en détention (${r.raison})`,
      acteur: r.nom, estPJ: acteur.estPJ, photo_url: acteur.photo_url,
      poids: bumpPoids('secondaire', acteur.estPJ ? 2 : 0),
      created_at: r.created_at
    });
  });
  (jugements || []).forEach(r => {
    const acteur = identifierActeur(r.accuse, personnagesConnus);
    facts.push({
      id: idSource('jugements', r), domaine: 'justice', type: 'condamnation',
      ville: resoudreNomVille(r.country, r.city), pays: r.country,
      resume: `${r.accuse} a été condamné(e) pour ${r.motif} : ${r.peine}`,
      acteur: r.accuse, estPJ: acteur.estPJ, photo_url: acteur.photo_url,
      poids: bumpPoids('secondaire', acteur.estPJ ? 2 : 0),
      created_at: r.created_at
    });
  });
  return facts;
}

async function collecterCandidatures(periode, personnagesConnus) {
  const f = filtrePeriode(periode);
  const rows = await sbGet('candidatures', `${f}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  return (rows || []).map(r => {
    const acteur = identifierActeur(r.nom, personnagesConnus);
    return {
      id: idSource('candidatures', r), domaine: 'politique', type: 'candidature',
      ville: resoudreNomVille(r.country, r.city), pays: r.country,
      resume: `${r.nom} a déposé sa candidature au poste de ${r.poste_id}` + (r.city ? ` à ${resoudreNomVille(r.country, r.city)}` : ''),
      acteur: r.nom, estPJ: acteur.estPJ, photo_url: acteur.photo_url,
      poids: bumpPoids('mineur', acteur.estPJ ? 1 : 0),
      created_at: r.created_at
    };
  });
}

// Football — résultats ET performances individuelles (refonte 31 aout 2026, cas test triplé).
// championnat.data.calendrier[].matchs[].evenements contient les evenements minute par minute du
// match, y compris {type:'but', joueur} (plateau-organisations-quetes.js, genererBut()) : l'ancien
// module ne lisait jamais ce tableau, seulement scoreHome/scoreAway. Cette version agrege les buts
// par joueur ET par match, ce qui fait exister un triplé comme UN SEUL fait structuré plutot que
// 3 evenements de but non relies. "titulaires" (donc tout "joueur" issu de m.evenements) provient
// TOUJOURS de sbListJoueursLicencies() (calculerContributionEquipe(), plateau-organisations-
// quetes.js:1898-1900) : un buteur reel est donc TOUJOURS un PJ licencie -- seul club.vedettes
// (jamais pousse dans evenements) designe un PNJ, et n'apparait donc jamais ici.
function qualifierPerformanceSportive(buts, estPJ) {
  if (buts >= 4) return 'majeur';
  if (buts === 3) return estPJ ? 'majeur' : 'important';
  if (buts === 2) return estPJ ? 'important' : 'secondaire';
  return estPJ ? 'secondaire' : 'mineur'; // buts === 1
}

async function collecterFootball(periode, personnagesConnus) {
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
      const matchId = idSource('championnat', { id: `j${journee.numero}-${m.home}-${m.away}` });

      // Agrégation des buts par joueur (m.evenements peut être absent sur d'anciens matchs
      // persistés avant cette fonctionnalité — traité comme vide, jamais une erreur).
      const butsParJoueur = new Map();
      (m.evenements || []).forEach(ev => {
        if (ev.type !== 'but' || !ev.joueur) return;
        butsParJoueur.set(ev.joueur, (butsParJoueur.get(ev.joueur) || 0) + 1);
      });
      const performances = [];
      butsParJoueur.forEach((buts, joueur) => {
        const acteur = identifierActeur(joueur, personnagesConnus);
        performances.push({
          id: idSource('championnat', { id: `${matchId}-but-${joueur}` }),
          domaine: 'sport', type: 'performance_sportive',
          ville: null, pays: [clubHome && clubHome.country, clubAway && clubAway.country].filter(Boolean),
          resume: `${joueur} inscrit ${buts === 1 ? 'un but' : buts + ' buts'} lors de ${(clubHome && clubHome.nom) || m.home} ${m.scoreHome} - ${m.scoreAway} ${(clubAway && clubAway.nom) || m.away}`,
          acteur: joueur, estPJ: acteur.estPJ, photo_url: acteur.photo_url, buts,
          match_ref: matchId, club_image: (clubHome && clubHome.imageStade) || (clubAway && clubAway.imageStade) || null,
          poids: qualifierPerformanceSportive(buts, acteur.estPJ),
          created_at: new Date(dateJournee).toISOString()
        });
      });

      const performanceNotable = performances.some(p => POIDS_ORDRE.indexOf(p.poids) >= POIDS_ORDRE.indexOf('important'));
      facts.push({
        id: matchId,
        domaine: 'sport', type: 'resultat_match',
        ville: null,
        pays: [clubHome && clubHome.country, clubAway && clubAway.country].filter(Boolean),
        resume: `${(clubHome && clubHome.nom) || m.home} ${m.scoreHome} - ${m.scoreAway} ${(clubAway && clubAway.nom) || m.away}`,
        acteur: null, estPJ: performances.some(p => p.estPJ), photo_url: null,
        club_image: (clubHome && clubHome.imageStade) || (clubAway && clubAway.imageStade) || null,
        poids: bumpPoids('mineur', performanceNotable ? 1 : (performances.some(p => p.estPJ) ? 1 : 0)),
        created_at: new Date(dateJournee).toISOString()
      });
      performances.forEach(p => facts.push(p));
    });
  });
  if (facts.length > LIMITE_PAR_DOMAINE) facts.length = LIMITE_PAR_DOMAINE;
  return facts;
}

// =====================
// 4. PUBLIC_STATEMENTS — forum uniquement, catégories publiques seulement.
// =====================

function estForumPublic(forumId) {
  if (!forumId) return false;
  if (forumId === 'gouvernement' || forumId === 'presse') return false;
  if (forumId.indexOf('org_') === 0) return false;
  return true;
}

async function collecterDeclarationsPubliques(periode, personnagesConnus) {
  const f = filtrePeriode(periode);
  const topics = await sbGet('forum_topics',
    `${f}&select=id,forum_id,title,author,author_is_org,country,created_at&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  const topicsPublics = (topics || []).filter(t => estForumPublic(t.forum_id) && t.author !== 'Ligue Officielle');
  const statements = topicsPublics.map(t => {
    const acteur = t.author_is_org ? { estPJ: false, photo_url: null } : identifierActeur(t.author, personnagesConnus);
    return {
      id: idSource('forum_topics', t), domaine: 'forum', type: 'sujet',
      auteur: t.author, auteur_est_organisation: !!t.author_is_org,
      forum_id: t.forum_id, pays: t.country,
      extrait: t.title, created_at: t.created_at,
      acteur: t.author, estPJ: acteur.estPJ, photo_url: acteur.photo_url,
      poids: bumpPoids('secondaire', acteur.estPJ ? 1 : 0)
    };
  });

  const posts = await sbGet('forum_posts',
    `${f}&select=id,topic_id,author,content,author_is_org,created_at&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  if (posts && posts.length > 0) {
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
      const acteur = p.author_is_org ? { estPJ: false, photo_url: null } : identifierActeur(p.author, personnagesConnus);
      statements.push({
        id: idSource('forum_posts', p), domaine: 'forum', type: 'reponse',
        auteur: p.author, auteur_est_organisation: !!p.author_is_org,
        forum_id: parent.forum_id, pays: parent.country,
        extrait: (p.content || '').slice(0, 400), created_at: p.created_at,
        acteur: p.author, estPJ: acteur.estPJ, photo_url: acteur.photo_url,
        poids: bumpPoids('secondaire', acteur.estPJ ? 1 : 0)
      });
    });
  }
  return statements;
}

// =====================
// 4bis. INTERVIEW JODIE MOITOUT — double une publication qui existe déjà (forum_id "presse",
// author "Jodie Moitout"), jamais un second circuit d'interview (voir plateau-communication.js :
// jodiePortraitPublier()). "presse" est un forum PRIVATE au sens de estForumPublic() (exclu de
// collecterDeclarationsPubliques ci-dessus) -- cette collecte est donc volontairement séparée et
// ne réutilise pas ce filtre : seul le contenu de Jodie doit franchir cette porte, rien d'autre.
// Contenu transmis TEL QUEL (titre + texte du post) : l'IA ne doit jamais le reformuler, voir
// prompt Lot B -- Lot B recopie ce texte verbatim dans l'edition, en dehors de tout appel IA.
// =====================
const JODIE_PORTRAIT_TITRE_PREFIXE = 'Un jour, un portrait : ';

async function collecterInterviewJodie(periode, pays, personnagesConnus) {
  const f = filtrePeriode(periode);
  const topics = await sbGet('forum_topics',
    `${f}&forum_id=eq.presse&author=eq.${encodeURIComponent('Jodie Moitout')}&country=eq.${encodeURIComponent(pays)}&order=created_at.desc&limit=1&select=id,title,created_at`);
  const topic = topics && topics[0];
  if (!topic) return null;
  const posts = await sbGet('forum_posts', `topic_id=eq.${encodeURIComponent(topic.id)}&order=created_at.asc&limit=1&select=content`);
  const texte = posts && posts[0] && posts[0].content;
  if (!texte) return null;
  const nom = topic.title.indexOf(JODIE_PORTRAIT_TITRE_PREFIXE) === 0
    ? topic.title.slice(JODIE_PORTRAIT_TITRE_PREFIXE.length)
    : topic.title;
  const acteur = identifierActeur(nom, personnagesConnus);
  return { nom, titre: topic.title, texte, photo_url: acteur.photo_url, created_at: topic.created_at };
}

// =====================
// 5. INDICATORS — snapshots ordinaires (destinés à la dernière page, jamais à un article, voir
// doctrine §7 refonte : « le journal ne doit plus transformer arbitrairement un stock/prix ordinaire
// en article »).
// =====================

async function collecterIndicateursPopulation(pays) {
  const rows = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=current_city&limit=2000`);
  const liste = rows || [];
  const parVille = {};
  Object.keys(NOMS_VILLES[pays] || {}).forEach(villeId => {
    parVille[resoudreNomVille(pays, villeId)] = 0;
  });
  liste.forEach(r => {
    const v = r.current_city ? resoudreNomVille(pays, r.current_city) : 'inconnue';
    parVille[v] = (parVille[v] || 0) + 1;
  });
  return [
    { id: idIndicateur(`population_totale_${pays}`), cle: 'population_totale', valeur: liste.length, pays, disponible: true },
    { id: idIndicateur(`population_par_ville_${pays}`), cle: 'population_par_ville', valeur: parVille, pays, disponible: true }
  ];
}

// Prix/stock — respecte prixManuel (fixé par un directeur PJ) avant la formule automatique.
// Republic-only en pratique aujourd'hui (voir ENTREPOTS_PAR_PAYS).
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
        valeur: prix, ville: resoudreNomVille(pays, entrepot.city), pays, disponible: prix != null, prix_manuel: prixFixeManuel
      });
      indicateurs.push({
        id: idIndicateur(`stock_${cle}_${pays}_${entrepot.city}`), cle: `stock_${cle}`,
        valeur: enStock, ville: resoudreNomVille(pays, entrepot.city), pays, disponible: true,
        plafond: (RESSOURCES_ECONOMIE[cle] && RESSOURCES_ECONOMIE[cle].plafond) || null
      });
    });
  }
  return indicateurs;
}

// Événements économiques REMARQUABLES (refonte §7) — seuils déterministes raisonnables, jamais une
// extrapolation demandée à l'IA. Rupture/quasi-pénurie détectées sur le snapshot courant ; variation
// forte détectée par comparaison avec la dernière édition PUBLIÉE (une seule édition en arrière,
// suffisant pour une variation d'une période à l'autre — pas besoin de l'historique à 8 éditions de
// l'ancien mécanisme d'absence, retiré par cette refonte).
const SEUIL_QUASI_PENURIE = 0.1; // 10% du plafond
const SEUIL_VARIATION_FORTE = 0.5; // 50% de variation stock, à la hausse ou à la baisse

async function calculerEvenementsEconomiquesRemarquables(pays, indicateursEcoActuels) {
  const facts = [];
  const precedentes = await sbGet('journal_editions',
    `country=eq.${encodeURIComponent(pays)}&statut=eq.publiee&order=date_edition.desc&limit=1&select=faits_sources`)
    .catch(() => null);
  const precedent = precedentes && precedentes[0];
  const indicateursPrecedents = (precedent && precedent.faits_sources && precedent.faits_sources.INDICATORS) || [];

  indicateursEcoActuels.forEach(ind => {
    if (ind.cle.indexOf('stock_') !== 0 || !ind.disponible || !ind.plafond) return;
    const ressource = ind.cle.replace('stock_', '');
    const tauxRemplissage = ind.valeur / ind.plafond;

    if (ind.valeur === 0) {
      facts.push({
        id: idComparaison(`rupture_${ressource}_${pays}_${ind.ville}`), domaine: 'economie', type: 'economie_remarquable',
        ville: ind.ville, pays, resume: `Rupture de stock de ${ressource} à ${ind.ville}.`,
        acteur: null, estPJ: false, photo_url: null, poids: 'important', created_at: new Date().toISOString()
      });
    } else if (tauxRemplissage < SEUIL_QUASI_PENURIE) {
      facts.push({
        id: idComparaison(`quasi_penurie_${ressource}_${pays}_${ind.ville}`), domaine: 'economie', type: 'economie_remarquable',
        ville: ind.ville, pays, resume: `Stock de ${ressource} au plus bas à ${ind.ville} (${ind.valeur} unités, sur un plafond de ${ind.plafond}).`,
        acteur: null, estPJ: false, photo_url: null, poids: 'secondaire', created_at: new Date().toISOString()
      });
    }

    const ancien = indicateursPrecedents.find(i => i.id === ind.id);
    if (ancien && ancien.disponible && typeof ancien.valeur === 'number' && ancien.valeur > 0) {
      const variation = (ind.valeur - ancien.valeur) / ancien.valeur;
      if (Math.abs(variation) >= SEUIL_VARIATION_FORTE) {
        const sens = variation > 0 ? 'augmenté' : 'chuté';
        facts.push({
          id: idComparaison(`variation_${ressource}_${pays}_${ind.ville}`), domaine: 'economie', type: 'economie_remarquable',
          ville: ind.ville, pays,
          resume: `Le stock de ${ressource} à ${ind.ville} a ${sens} de ${Math.round(Math.abs(variation) * 100)}% par rapport à la dernière édition (${ancien.valeur} → ${ind.valeur}).`,
          acteur: null, estPJ: false, photo_url: null, poids: 'important', created_at: new Date().toISOString()
        });
      }
    }
  });
  return facts;
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
  const perso = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=current_city&limit=2000`);
  const villes = [...new Set((perso || []).map(r => r.current_city).filter(Boolean))];
  for (const ville of villes) {
    const rows = await sbGet('budgets_municipaux', `id=eq.${encodeURIComponent(pays + '_' + ville)}&select=data`);
    if (!rows || !rows[0]) continue;
    const data = parseBlob(rows[0].data);
    indicateurs.push({
      id: idIndicateur(`caisse_municipale_${pays}_${ville}`), cle: 'caisse_municipale',
      valeur: data.caisse != null ? data.caisse : null, ville: resoudreNomVille(pays, ville), pays, disponible: data.caisse != null
    });
  }
  return indicateurs;
}

// Situation de caisse exceptionnelle (§7 refonte) — seuil déterministe simple et sans invention :
// une caisse dans le rouge est objectivement remarquable, quel que soit le contexte.
function calculerCaissesRemarquables(pays, indicateursCaisses) {
  const facts = [];
  indicateursCaisses.forEach(ind => {
    if (!ind.disponible || typeof ind.valeur !== 'number' || ind.valeur >= 0) return;
    const lieu = ind.cle === 'caisse_nationale' ? 'la caisse nationale' : `la caisse municipale de ${ind.ville}`;
    facts.push({
      id: idComparaison(`${ind.cle}_deficit_${pays}${ind.ville ? '_' + ind.ville : ''}`), domaine: 'economie', type: 'economie_remarquable',
      ville: ind.ville || null, pays, resume: `${lieu[0].toUpperCase()}${lieu.slice(1)} est dans le rouge (${ind.valeur} FR).`,
      acteur: null, estPJ: false, photo_url: null, poids: 'important', created_at: new Date().toISOString()
    });
  });
  return facts;
}

// Classement — snapshot recalculé (pas d'historique de progression).
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

// Petites annonces actives — La Tribune de Republia (31 aout 2026). Expiration TOUJOURS via
// expire_at (horodatage reel), jamais state.day, même doctrine que le Journal lui-même. Assemblée
// en dernière page par le Lot B, jamais vue par l'IA (pure lecture, aucune invention possible).
async function collecterPetitesAnnoncesActives(pays) {
  const nowIso = new Date().toISOString();
  const rows = await sbGet('petites_annonces',
    `country=eq.${encodeURIComponent(pays)}&statut=eq.active&expire_at=gt.${encodeURIComponent(nowIso)}&order=created_at.asc&limit=${LIMITE_PAR_DOMAINE}`);
  return (rows || []).map(r => ({
    texte: r.texte, categorie: r.categorie || null, ville: resoudreNomVille(pays, r.ville_depot) || r.ville_depot
  }));
}

// =====================
// 6. EDUCATIONAL_REFERENCE — aucune bibliothèque de fiches n'existe encore (Lot E, hors périmètre).
// =====================
function collecterReferencePedagogique() {
  return { fiche_id: null, contenu_valide: null };
}

// =====================
// 7. ORCHESTRATEUR — construit le paquet complet pour un pays et une période donnés.
// =====================
async function construirePaquetFactuel(pays, periode) {
  const personnagesConnus = await chargerPersonnagesConnus(pays);
  const expositionRecente = await chargerExpositionRecente(pays);

  const [etatCivil, justice, candidatures, football, declarations, interviewJodie, petitesAnnonces] = await Promise.all([
    collecterEtatCivil(periode, personnagesConnus),
    collecterJustice(periode, personnagesConnus),
    collecterCandidatures(periode, personnagesConnus),
    collecterFootball(periode, personnagesConnus),
    collecterDeclarationsPubliques(periode, personnagesConnus),
    collecterInterviewJodie(periode, pays, personnagesConnus),
    collecterPetitesAnnoncesActives(pays)
  ]);

  const [indicPopulation, indicEcoBrut, indicCaisses, indicClassement] = await Promise.all([
    collecterIndicateursPopulation(pays),
    collecterIndicateursEconomiques(pays),
    collecterIndicateursCaisses(pays),
    collecterIndicateurClassement(pays)
  ]);

  const [economieRemarquable, caissesRemarquables] = await Promise.all([
    calculerEvenementsEconomiquesRemarquables(pays, indicEcoBrut),
    Promise.resolve(calculerCaissesRemarquables(pays, indicCaisses))
  ]);

  const FACTS = [...etatCivil, ...justice, ...candidatures, ...football, ...economieRemarquable, ...caissesRemarquables]
    .map(f => ({ ...f, expositionRecente: !!(f.estPJ && f.acteur && expositionRecente.has(f.acteur)) }));

  const factsDuPays = f => (Array.isArray(f.pays) ? f.pays.includes(pays) : f.pays === pays);
  const compterType = type => FACTS.filter(f => f.type === type && factsDuPays(f)).length;

  // Compteurs de période — conservés pour la dernière page (indices) UNIQUEMENT : la fabrication
  // "absence = actualité" (ancien calculerComparaisons/CLES_INDICATEURS_ABSENCE) est retirée, voir
  // en-tête de fichier. Ces nombres restent disponibles, mais aucun mécanisme ne les transforme
  // plus automatiquement en "actualité" quand ils valent zéro.
  const INDICATORS = [
    ...indicPopulation,
    { id: idIndicateur(`naissances_periode_${pays}`), cle: 'naissances_periode', valeur: compterType('arrivee'), pays, disponible: true },
    { id: idIndicateur(`mariages_periode_${pays}`), cle: 'mariages_periode', valeur: compterType('mariage'), pays, disponible: true },
    { id: idIndicateur(`deces_periode_${pays}`), cle: 'deces_periode', valeur: compterType('deces'), pays, disponible: true },
    { id: idIndicateur(`arrestations_periode_${pays}`), cle: 'arrestations_periode', valeur: compterType('arrestation'), pays, disponible: true },
    { id: idIndicateur(`condamnations_periode_${pays}`), cle: 'condamnations_periode', valeur: compterType('condamnation'), pays, disponible: true },
    { id: idIndicateur(`candidatures_periode_${pays}`), cle: 'candidatures_periode', valeur: compterType('candidature'), pays, disponible: true },
    ...indicEcoBrut,
    ...indicCaisses,
    ...indicClassement
  ];

  return {
    country: pays,
    periode,
    FACTS,
    PUBLIC_STATEMENTS: declarations,
    INDICATORS,
    INTERVIEW_JODIE: interviewJodie,
    PETITES_ANNONCES: petitesAnnonces,
    EDUCATIONAL_REFERENCE: collecterReferencePedagogique()
  };
}

export {
  PAYS_JEU,
  POIDS_ORDRE,
  determinerPaysEligibles,
  calculerPeriode,
  construirePaquetFactuel,
  estForumPublic,
  getPrixRessource,
  idSource,
  idIndicateur,
  idComparaison,
  parseBlob,
  bumpPoids,
  chargerPersonnagesConnus,
  identifierActeur,
  qualifierPerformanceSportive
};
