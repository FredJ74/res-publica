// =====================
// PLATEAU-ASSEMBLEE.JS
// Assemblee nationale de Republia — 9 sieges, propositions de loi, sessions, votes,
// intentions PNJ, marchandage, registre officiel, indemnite parlementaire.
// Chantier du 10 septembre 2026.
// =====================
//
// DOCTRINE DE CE FICHIER
//
// 1. LE SERVEUR FAIT AUTORITE. Toute mutation parlementaire passe par une RPC transactionnelle
//    (voir migration_assemblee_nationale.sql). Ce fichier ne calcule JAMAIS un resultat de
//    scrutin, ne decide JAMAIS qu'une session est close, n'ecrit JAMAIS une intention ni un vote
//    en direct. L'horloge du navigateur ne sert qu'a l'affichage ; elle n'autorise rien.
//
// 2. FAIL-CLOSED. Chaque wrapper sb* renvoie null si la RPC est absente (schema non deploye) ou
//    injoignable. Dans ce cas l'action est REFUSEE avec un message clair, et rien n'est debite.
//    Aucun repli local non atomique n'existe : l'audit du 9 septembre a etabli que les primitives
//    de caisse historiques perdent des ecritures concurrentes.
//
// 3. LES PA SE PAIENT AVANT LE JET, JAMAIS APRES. Convention deja generale au projet
//    (deduireCoutOrdre est l'autorite unique). Une tentative ratee reste facturee (§15).
//
// 4. L'UI N'EST PAS UNE SECURITE (§52). Chaque handler revalide ses propres conditions, et le
//    serveur les revalide toutes une seconde fois.

// =====================
// LES NEUF SIEGES
// =====================
// Miroir client de assemblee_sieges (migration, partie 1). Sert a l'affichage et au ciblage
// AVANT toute requete reseau ; l'etat reel (endormi, occupation) vient toujours du serveur.
// L'ordre et les identifiants doivent rester STRICTEMENT identiques a ceux de la migration.
//
// Villes de Republia : capitale = Luthecia · ville_a = Port-Sainte-Marie · ville_b = Montrouge
const ASSEMBLEE_SIEGES = [
  { id: 'republic:capitale:1', city: 'capitale', rang: 1, pnjId: 'dep_vauclerc', nom: 'Étienne Vauclerc' },
  { id: 'republic:capitale:2', city: 'capitale', rang: 2, pnjId: 'dep_marechal', nom: 'Sophie Maréchal' },
  { id: 'republic:capitale:3', city: 'capitale', rang: 3, pnjId: 'dep_delorme',  nom: 'Benoît Delorme' },
  { id: 'republic:ville_b:1',  city: 'ville_b',  rang: 1, pnjId: 'dep_charron',  nom: 'Nathalie Charron' },
  { id: 'republic:ville_b:2',  city: 'ville_b',  rang: 2, pnjId: 'dep_pichon',   nom: 'Gérard Pichon' },
  { id: 'republic:ville_b:3',  city: 'ville_b',  rang: 3, pnjId: 'dep_vasseur',  nom: 'Élodie Vasseur' },
  { id: 'republic:ville_a:1',  city: 'ville_a',  rang: 1, pnjId: 'dep_legall',   nom: 'Yann Legall' },
  { id: 'republic:ville_a:2',  city: 'ville_a',  rang: 2, pnjId: 'dep_leroux',   nom: 'Maëlle Leroux' },
  { id: 'republic:ville_a:3',  city: 'ville_a',  rang: 3, pnjId: 'dep_kermeur',  nom: 'Loïc Kermeur' }
];

const ASSEMBLEE_NB_SIEGES = 9;

// §3 : les neuf PNJ sont VOLONTAIREMENT equivalents. Aucune ideologie, aucune loyaute, aucune
// memoire des marchandages, PER = 6 pour tous (malus de 3 points sur Neutraliser, PER/2).
//
// SOURCE UNIQUE : leurs statistiques vivent dans PNJ_STATS_NOMMES (data.js), lues par
// getPnjStats() comme celles de tous les autres PNJ nommes du jeu. Ce fichier n'en garde AUCUNE
// copie -- une premiere version en tenait un double (ASSEMBLEE_PNJ_STATS), ce qui aurait
// silencieusement diverge le jour ou l'un des deux aurait ete ajuste.

// Image de groupe fournie separement. Les avatars individuels n'existent pas encore : on ne
// reference AUCUN fichier inexistant. photoUrl reste absent, renderPersonsList retombe alors
// proprement sur l'icone de job (PNJ_AVATAR), comportement deja general du projet.
const ASSEMBLEE_IMAGE_GROUPE = 'images/republia-pnj-deputes.png';

function assembleeSiegeParId(siegeId) {
  return ASSEMBLEE_SIEGES.find(s => s.id === siegeId) || null;
}

function assembleeSiegeParNomPnj(nom) {
  const propre = String(nom || '').replace(' (PNJ)', '').trim();
  return ASSEMBLEE_SIEGES.find(s => s.nom === propre) || null;
}

function assembleeEstDeputePnj(nom) {
  return !!assembleeSiegeParNomPnj(nom);
}

// =====================
// CATEGORIES TECHNIQUES D'INTERDICTION (§9, §44)
// =====================
// AUCUNE taxonomie parallele n'est creee. Chaque categorie ne fait que REGROUPER des identifiants
// qui existent deja dans le jeu :
//   - matieres  : cles de RESSOURCES_ECONOMIE (data.js) — circuit commerce/entrepot
//   - typesObjet: valeurs de item.type dans l'inventaire classique
//   - sousTypes : raffinement optionnel sur item.sousType (armes)
//
// L'audit du 9 septembre a montre que ces deux circuits sont DISJOINTS : la viande est une
// matiere premiere de commerce, jamais un objet d'inventaire au sens de la fouille policiere.
// Une categorie peut donc viser l'un, l'autre, ou les deux -- c'est exactement ce que §44 demande.
//
// Les familles LARGES existent volontairement a cote des familles etroites : c'est le coeur de
// l'avertissement du §9 (choisir "Denrees animales" interdit aussi le poisson). L'interface le
// signale explicitement au depot.
const CATEGORIES_INTERDICTION = {
  viandes:            { label: 'Viandes',                    matieres: ['viande'],                         typesObjet: [], sousTypes: [] },
  poissons:           { label: 'Poissons',                   matieres: ['poisson'],                        typesObjet: [], sousTypes: [] },
  denrees_animales:   { label: 'Denrées animales (large)',   matieres: ['viande', 'poisson'],              typesObjet: [], sousTypes: [] },
  alcools:            { label: 'Alcools',                    matieres: ['alcool'],                         typesObjet: [], sousTypes: [] },
  tabac:              { label: 'Tabac',                      matieres: ['tabac'],                          typesObjet: [], sousTypes: [] },
  medicaments:        { label: 'Médicaments',                matieres: ['medicaments'],                    typesObjet: ['medicament'], sousTypes: [] },
  armes_blanches:     { label: 'Armes blanches',             matieres: [],                                 typesObjet: ['arme'], sousTypes: ['blanche'] },
  armes_a_feu:        { label: 'Armes à feu',                matieres: [],                                 typesObjet: ['arme'], sousTypes: ['poing', 'carabine'] },
  armes:              { label: 'Armes (large)',              matieres: [],                                 typesObjet: ['arme'], sousTypes: [] },
  poisons:            { label: 'Poisons',                    matieres: [],                                 typesObjet: ['poison'], sousTypes: [] },
  carburants:         { label: 'Carburants',                 matieres: ['carburant', 'petrole'],           typesObjet: [], sousTypes: [] },
  hydrocarbures:      { label: 'Hydrocarbures (large)',      matieres: ['carburant', 'petrole', 'charbon'], typesObjet: [], sousTypes: [] },
  bois_et_forets:     { label: 'Bois',                       matieres: ['bois'],                           typesObjet: [], sousTypes: [] },
  textile:            { label: 'Textile',                    matieres: ['textile'],                        typesObjet: [], sousTypes: [] },
  produits_exotiques: { label: 'Produits exotiques',         matieres: ['produits_exotiques'],             typesObjet: [], sousTypes: [] }
};

// Liste lisible de ce qu'une categorie recouvre REELLEMENT, affichee au depot et dans le topic
// forum (§9 : "accompagnee si possible de la liste des objets actuellement concernes").
function assembleeContenuCategorie(categorieId) {
  const cat = CATEGORIES_INTERDICTION[categorieId];
  if (!cat) return [];
  const noms = [];
  (cat.matieres || []).forEach(m => {
    const res = (typeof RESSOURCES_ECONOMIE !== 'undefined') ? RESSOURCES_ECONOMIE[m] : null;
    noms.push(res ? res.label : m);
  });
  (cat.typesObjet || []).forEach(t => {
    if ((cat.sousTypes || []).length) {
      cat.sousTypes.forEach(st => noms.push(t + ' / ' + st));
    } else {
      noms.push(t);
    }
  });
  return noms;
}

// =====================
// SOURCE COMMUNE DE LEGALITE (§34 a §39, §44)
// =====================
// C'est le point unique auquel tout le reste du jeu demande « est-ce interdit ici et maintenant ».
// Il ne cree AUCUNE taxonomie parallele : il croise les interdictions en vigueur
// (assemblee_propositions, type='mecanique', statut='adoptee') avec les identifiants deja
// existants du jeu, via CATEGORIES_INTERDICTION.
//
// TERRITORIALITE (§37) : les lois de Republia ne s'appliquent qu'a Republia. Acheter legalement
// a l'etranger reste possible ; c'est l'ENTREE sur le territoire qui rend la possession illegale.
// Toutes les fonctions ci-dessous renvoient donc « legal » des que state.country <> 'republic'.
//
// PAS D'INTERPRETATION DU TEXTE (§9) : seule la categorie technique choisie au depot compte.
// Aucun appel IA, aucune analyse du texte libre, nulle part.

window._assembleeInterdictions = window._assembleeInterdictions || { liste: null, ts: 0 };

async function rafraichirAssembleeInterdictions() {
  if (typeof sbGetAssembleeInterdictions !== 'function') return null;
  const pays = (typeof state !== 'undefined' && state.country) || 'republic';
  const liste = await sbGetAssembleeInterdictions(pays).catch(() => null);
  if (!liste) return null;
  window._assembleeInterdictions = { liste, ts: Date.now() };
  return liste;
}

function assembleeInterdictionsActives() {
  return (window._assembleeInterdictions && window._assembleeInterdictions.liste) || [];
}

// Republia uniquement (§37).
function assembleeLoiApplicable() {
  return (typeof state !== 'undefined') && (state.country || 'republic') === 'republic';
}

// Renvoie la loi qui interdit cette matiere de commerce, ou null.
// adoptee_ts sert a la non-retroactivite (§38) : une transaction anterieure reste legale.
function assembleeInterdictionMatiere(cleMatiere) {
  if (!assembleeLoiApplicable() || !cleMatiere) return null;
  for (const loi of assembleeInterdictionsActives()) {
    const cat = CATEGORIES_INTERDICTION[loi.categorie];
    if (cat && (cat.matieres || []).includes(cleMatiere)) return loi;
  }
  return null;
}

// Renvoie la loi qui interdit cet objet d'inventaire, ou null.
// Un objet est vise si son type figure dans la categorie ET, quand la categorie precise des
// sousTypes, si son sousType y figure aussi. Une categorie large ('armes') n'a pas de sousTypes
// et attrape donc toute la famille -- c'est exactement l'avertissement du §9.
// Les objets empilables issus du commerce portent stackKey = cle de RESSOURCES_ECONOMIE : ils
// sont donc aussi couverts par les categories de matieres.
function assembleeInterdictionObjet(item) {
  if (!assembleeLoiApplicable() || !item) return null;
  for (const loi of assembleeInterdictionsActives()) {
    const cat = CATEGORIES_INTERDICTION[loi.categorie];
    if (!cat) continue;
    if (item.stackKey && (cat.matieres || []).includes(item.stackKey)) return loi;
    if (item.type && (cat.typesObjet || []).includes(item.type)) {
      if (!(cat.sousTypes || []).length) return loi;
      if (item.sousType && cat.sousTypes.includes(item.sousType)) return loi;
    }
  }
  return null;
}

// Tous les objets interdits actuellement portes. Utilise par les controles (§39) : la possession
// d'un objet devenu interdit apres son acquisition entraine la confiscation, mais JAMAIS une
// trace retroactive de transaction.
function assembleeObjetsInterditsPortes() {
  return (state.inventory || []).filter(i => assembleeInterdictionObjet(i));
}

// =====================
// LES LOIS D'INTERDICTION APPLIQUEES AUX VENTES (arbitrage du 11 septembre 2026)
// =====================
// 1. VENTE LEGALE OU INSTITUTIONNELLE : refusee des qu'une loi en vigueur vise l'objet ou la
//    matiere, quel que soit le fournisseur (entrepot, usine, criee, fret, armurerie, commerce,
//    guichets qui rachetent des matieres aux joueurs...). La decision est SERVEUR
//    (assemblee_verifier_vente) : correspondance categorie -> objet, loi adoptee, entree en
//    vigueur adoptee_ts <= instant de la transaction, horloge du serveur. Le cache local
//    (assembleeInterdictionMatiere/Objet) ne sert plus qu'a l'affichage et a la confiscation.
// 2. CIRCUIT ILLEGAL (marche noir) : la vente est conservee ; sa qualification judiciaire est
//    tranchee par le serveur (assemblee_achat_illegal) -- detection de chaque partie JOUEUR avec
//    son propre jet, trace protegee, convocation sous 36 h. Plus aucun jet ni trace calcules ici.
// 3. Aucune retroactivite : seule la transaction du moment est evaluee, contre les lois en vigueur
//    a cet instant. La possession d'un objet devenu interdit reste traitee par la confiscation.

// Controle d'une vente LEGALE, a appeler AVANT tout debit. objets : [{stackKey, type, sousType}].
// true = vente autorisee. false = refusee (interdite, ou legalite non verifiable : fail-closed) ;
// le joueur en est informe ici et rien n'a ete debite.
async function assembleeControlerVenteLegale(objets) {
  if (!assembleeLoiApplicable()) return true;   // §37 : Republia uniquement
  const pays = (typeof state !== 'undefined' && state.country) || 'republic';
  const res = (typeof sbAssembleeVerifierVente === 'function')
    ? await sbAssembleeVerifierVente(objets || [], pays).catch(() => null)
    : null;
  if (!res) {
    showToast('Vente impossible', 'La légalité de cette marchandise n\'a pas pu être vérifiée. Rien n\'a été débité.', false);
    return false;
  }
  if (res.ok === false) {
    const loi = res.interdits && res.interdits[0] && res.interdits[0].loi;
    if (!loi) {
      showToast('Vente impossible', 'La légalité de cette marchandise n\'a pas pu être vérifiée. Rien n\'a été débité.', false);
      return false;
    }
    showToast('Vente interdite', 'Cette marchandise est interdite à la vente par la loi « ' + (loi.titre || '?') + ' ».', false);
    if (typeof rafraichirAssembleeInterdictions === 'function') rafraichirAssembleeInterdictions().catch(() => {});
    return false;
  }
  return true;
}

// Qualification judiciaire d'un achat conclu sur un circuit ILLEGAL (circuit, ref : voir
// assemblee_catalogue_illegal). A appeler APRES la vente, qui reste acquise quoi qu'il arrive.
// Idempotent : un identifiant de requete unique, rejoue une fois si la reponse est perdue. Recopie
// la trace, la convocation et la discretion ecrites par le serveur sur la ligne du joueur.
async function assembleeSignalerAchatIllegal(circuit, ref) {
  if (!assembleeLoiApplicable() || typeof sbAssembleeAchatIllegal !== 'function' || !state.char?.name) return null;
  if (typeof sbSavePersonnage === 'function') {
    try { await sbSavePersonnage(state); } catch (e) {}
  }
  const requete = assembleeNouvelleRequete();
  let res = await sbAssembleeAchatIllegal(state.char.name, circuit, ref, requete).catch(() => null);
  if (!res) res = await sbAssembleeAchatIllegal(state.char.name, circuit, ref, requete).catch(() => null);
  if (!res || !res.ok || !res.interdit || !res.acheteur) return res;

  const a = res.acheteur;
  if (typeof a.dis === 'number') state.dis = a.dis;
  if (a.trace && a.trace.id) {
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    if (!state.historiqueCrimes.some(h => h && h.id === a.trace.id)) state.historiqueCrimes.push(a.trace);
  }
  if (a.convocation && a.convocation.id) {
    if (!state.convocations) state.convocations = [];
    if (!state.convocations.some(c => c && c.id === a.convocation.id)) state.convocations.push(a.convocation);
    showToast('Convocation reçue',
      'Votre transaction a été repérée. Présentez-vous au commissariat sous 36 h.', false, true);
    addJournalEntry('Convocation au commissariat : transaction sur marchandise interdite.', 'event-bad');
  }
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  updateUI();
  return res;
}

// Echeance depassee ? Par ordre d'autorite :
//   1. le VERDICT SERVEUR (echue = true), pose par assemblee_marquer_convocations_echues et rendu
//      irrevocable par le trigger personnages_preserver_judiciaire -- c'est la seule source qui
//      fait foi, l'horloge du navigateur etant reglable ;
//   2. limiteTs, l'instant absolu, pour le cas ou le cron n'est pas encore passe ;
//   3. l'ancien couple jourLimite/heureLimite pour les convocations anterieures a ce chantier.
function assembleeConvocationEchue(c) {
  if (!c || c.traitee) return false;
  if (c.echue === true) return true;
  if (c.limiteTs) return Date.now() >= new Date(c.limiteTs).getTime();
  const jour = state.day || 1;
  return jour > c.jourLimite || (jour === c.jourLimite && (state.hour || 0) >= c.heureLimite);
}

function assembleeConvocationEnAttente() {
  return (state.convocations || []).find(c => !c.traitee) || null;
}

function assembleeHeuresRestantes(c) {
  if (!c || !c.limiteTs) return null;
  const ms = new Date(c.limiteTs).getTime() - Date.now();
  return ms <= 0 ? 0 : Math.ceil(ms / 3600000);
}


// =====================
// CONFISCATION (§39, §42)
// =====================
// Retrait DEFINITIF de l'inventaire : pas de scelles, pas de restitution (§39). Reutilise
// confisquerObjets (plateau-justice-economie.js), le moteur generique deja en place, plutot que
// d'en ecrire un second.
//
// S'applique a tout objet devenu interdit, MEME acquis legalement avant l'entree en vigueur :
// c'est la possession au moment du controle qui compte. En revanche cela ne cree JAMAIS de trace
// de transaction retroactive (§39) -- l'achat passe reste un achat passe.
async function assembleeConfisquerInterdits() {
  const vises = assembleeObjetsInterditsPortes();
  if (!vises.length) return '';
  const noms = (typeof confisquerObjets === 'function')
    ? confisquerObjets(vises)
    : (state.inventory = (state.inventory || []).filter(i => !vises.includes(i)), vises.map(o => o.name).join(', '));
  if (typeof sauvegarderPersonnageImmediat === 'function') await sauvegarderPersonnageImmediat();
  return noms;
}


// =====================
// CACHE PARTAGE
// =====================
// Meme patron que window._titulairesPostes (plateau-multijoueur.js) : un cache rafraichi de
// facon asynchrone, lu de facon synchrone par le rendu. Jamais une source de verite.
window._assembleeCache = window._assembleeCache || {
  sieges: null,        // lignes assemblee_sieges (etat 'endormi' reel)
  deputesPJ: null,     // [{ nom, city }] tries par nom
  occupation: null,    // [{ siegeId, city, rang, pnjNom, pnjId, endormi, pjNom, estPnj }]
  sessions: null,      // propositions au statut 'session'
  ts: 0
};

// Regle d'attribution des rangs — REPLIQUE EXACTE de assemblee_occupation_sieges (migration,
// partie 6). Les deputes PJ d'une ville, tries par nom, prennent les rangs 1, 2, 3 ; les rangs
// restants demeurent aux PNJ.
//
// Cette duplication est assumee et documentee : le serveur reste l'autorite (toutes les RPC
// recalculent l'occupation elles-memes). Cette copie ne sert qu'a l'affichage et au ciblage,
// exactement comme construireNouveauCycleElectoral est duplique entre client et cron.
function assembleeCalculerOccupation(sieges, deputesPJ) {
  const parVille = {};
  (deputesPJ || []).forEach(d => {
    if (!d || !d.city) return;
    (parVille[d.city] = parVille[d.city] || []).push(d.nom);
  });
  // Tri par defaut de Array.prototype.sort() = ordre des unites de code UTF-16. Il DOIT rester
  // identique au ORDER BY p.name COLLATE "C" de assemblee_occupation_sieges (migration, partie 6).
  // Surtout ne PAS utiliser localeCompare ici : sur des noms accentues, il classerait "Émile"
  // avant "Fabien" la ou COLLATE "C" le classe apres, et les deux moteurs attribueraient des
  // rangs differents -- l'ecran montrerait alors un autre assistant parlementaire que celui que
  // le serveur retient pour les votes.
  Object.keys(parVille).forEach(v => parVille[v].sort());

  return (sieges || []).map(s => {
    const pjNom = (parVille[s.city] || [])[s.rang - 1] || null;
    return {
      siegeId: s.id,
      city: s.city,
      rang: s.rang,
      pnjId: s.pnj_id || s.pnjId,
      pnjNom: s.pnj_nom || s.nom,
      endormi: !!s.endormi,
      pjNom,
      estPnj: !pjNom
    };
  });
}

// Recharge sieges + deputes PJ + sessions en cours. Silencieux en cas d'echec : l'Assemblee
// s'affiche alors comme indisponible plutot que de mentir sur un etat qu'on n'a pas.
async function rafraichirAssemblee() {
  const pays = (typeof state !== 'undefined' && state.country) || 'republic';
  if (typeof sbGetAssembleeSieges !== 'function') return null;

  try {
    const [sieges, joueurs, sessions] = await Promise.all([
      sbGetAssembleeSieges(pays).catch(() => null),
      (typeof sbListPersonnages === 'function' ? sbListPersonnages() : Promise.resolve([])).catch(() => []),
      sbGetAssembleePropositions(pays, ['session']).catch(() => [])
    ]);
    if (!sieges || !sieges.length) return null;

    const deputesPJ = (joueurs || []).map(j => {
      let pd = j.poste_depute;
      if (typeof pd === 'string') { try { pd = JSON.parse(pd); } catch (e) { pd = null; } }
      if (!pd || pd.id !== 'depute' || !pd.city) return null;
      return { nom: j.name, city: pd.city };
    }).filter(Boolean);

    window._assembleeCache = {
      sieges,
      deputesPJ,
      occupation: assembleeCalculerOccupation(sieges, deputesPJ),
      sessions: sessions || [],
      ts: Date.now()
    };
    return window._assembleeCache;
  } catch (e) {
    return null;
  }
}

function assembleeOccupation() {
  return (window._assembleeCache && window._assembleeCache.occupation) || null;
}

function assembleeOccupationSiege(siegeId) {
  const occ = assembleeOccupation();
  if (!occ) return null;
  return occ.find(o => o.siegeId === siegeId) || null;
}

// Le PJ courant occupe-t-il reellement un siege ? Utilise pour griser/afficher, jamais pour
// autoriser (la RPC assemblee_voter revalide systematiquement).
function assembleeMonSiege() {
  const moi = (typeof state !== 'undefined' && state.char && state.char.name) || null;
  if (!moi) return null;
  const occ = assembleeOccupation();
  if (!occ) return null;
  return occ.find(o => o.pjNom === moi) || null;
}

// =====================
// RENDU DES NEUF PNJ DANS L'HEMICYCLE (§2)
// =====================
// Injecte dans renderPersonsList via le meme pipeline que appliquerRemplacantesEscort /
// filtrerPnjPostesPourvus. Les neuf PNJ ne sont PAS declares en dur dans data.js : leur role
// change selon l'occupation reelle des sieges, ce qu'une liste statique ne peut pas exprimer.
//
// Siege libre  -> "Député (PNJ)"          : vote, questionnable, marchandable, neutralisable
// Siege PJ     -> "Assistant parlementaire": ne vote plus, aucune interaction parlementaire (§2)
// Endormi      -> le role l'annonce, et toutes les interactions parlementaires sont refusees
function appliquerDeputesAssemblee(persons) {
  // Uniquement dans l'hemicycle de l'Assemblee de Republia.
  if (typeof state === 'undefined') return persons;
  if (state.currentBuilding !== 'assemblee' || state.currentRoom !== 'hemicycle') return persons;
  if ((state.country || 'republic') !== 'republic') return persons;

  const occ = assembleeOccupation();
  const cartes = ASSEMBLEE_SIEGES.map(s => {
    const o = occ ? occ.find(x => x.siegeId === s.id) : null;
    const estPnj = o ? o.estPnj : true;   // avant chargement : suppose depute, corrige au refresh
    const endormi = o ? o.endormi : false;
    const villeNom = (typeof WORLD !== 'undefined' && WORLD.republic && WORLD.republic[s.city])
      ? WORLD.republic[s.city].name : s.city;

    let role;
    if (!estPnj) {
      role = 'Assistant parlementaire de ' + o.pjNom + ' (PNJ)';
    } else if (endormi) {
      role = 'Député de ' + villeNom + ' — Endormi (PNJ)';
    } else {
      role = 'Député de ' + villeNom + ' (PNJ)';
    }

    return {
      name: s.nom + ' (PNJ)',
      role,
      rel: 'neutral',
      job: 'depute',
      // Marqueurs lus par les handlers parlementaires et par openPnjModal.
      assembleeSiegeId: s.id,
      assembleePnjId: s.pnjId,
      assembleeEstDepute: estPnj,
      assembleeEndormi: endormi,
      // §2 : jamais recrutables. Drapeau lu par la fiche PNJ.
      nonRecrutable: true
    };
  });

  return [...(persons || []), ...cartes];
}

// =====================
// TEMPS PARLEMENTAIRE (§4)
// =====================
// Le temps collectif est une reference REELLE et COMMUNE. state.day n'est jamais utilise ici :
// il est propre a chaque joueur (le projet l'a deja acte pour les lois et les baux).
//
// Ces deux fonctions ne servent QU'A L'AFFICHAGE et a la preparation d'un timestamp envoye au
// serveur. Elles n'autorisent jamais une action : c'est la RPC qui tranche, sur son horloge.

// Prochain mercredi 22:00 Europe/Paris, en ISO. Calcule via une date locale puis convertie --
// suffisant pour proposer une echeance ; l'autorite reste cote base (now() >= cloture_ts).
function assembleeProchaineCloture(depuis) {
  const base = depuis ? new Date(depuis) : new Date();
  // Decalage Paris approxime par l'offset local du navigateur : la valeur envoyee au serveur est
  // un instant absolu (ISO avec fuseau), donc sans ambiguite une fois stockee en timestamptz.
  const d = new Date(base.getTime());
  d.setHours(22, 0, 0, 0);
  // 3 = mercredi
  while (d.getDay() !== 3 || d.getTime() <= base.getTime()) {
    d.setDate(d.getDate() + 1);
    d.setHours(22, 0, 0, 0);
  }
  return d.toISOString();
}

function assembleeFormaterEcheance(iso) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('fr-FR', {
      weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit'
    });
  } catch (e) { return String(iso); }
}

// Indication d'affichage uniquement. NE JAMAIS s'en servir pour autoriser un vote : l'horloge du
// navigateur est reglable par le joueur.
function assembleeSessionParaitClose(prop) {
  if (!prop || !prop.cloture_ts) return false;
  return Date.now() >= new Date(prop.cloture_ts).getTime();
}

// =====================
// ELIGIBILITE AU DEPOT (§5)
// =====================
// Deputes PJ, Premier ministre et ministres. Revalide cote serveur par assemblee_peut_deposer :
// cette version client ne sert qu'a afficher/griser.
const ASSEMBLEE_POSTES_DEPOSANTS = ['pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae'];

function assembleePeutDeposer() {
  if (typeof state === 'undefined' || !state.char) return false;
  if (state.posteDepute && state.posteDepute.id === 'depute') return true;
  return !!(state.poste && ASSEMBLEE_POSTES_DEPOSANTS.includes(state.poste.id));
}

// =====================
// MESSAGE D'INDISPONIBILITE
// =====================
// Un seul endroit ou l'on explique que le moteur parlementaire n'est pas joignable. Utilise par
// tous les handlers en fail-closed, pour que le joueur ne confonde jamais "refuse" et "casse".
function assembleeIndisponible(detail) {
  showToast('Assemblée indisponible',
    detail || 'Le registre parlementaire est momentanément injoignable. Aucune action n\'a été effectuée, rien n\'a été débité.',
    false);
}

// Traduction des motifs de refus renvoyes par les RPC en messages joueur. Centralisee ici pour
// que les onze handlers ne divergent pas.
const ASSEMBLEE_RAISONS = {
  ineligible:                  'Seuls les députés, le Premier ministre et les ministres peuvent déposer un projet.',
  champs_requis:               'Le titre et le texte sont obligatoires.',
  loi_cible_introuvable:       'Cette loi n\'est plus en vigueur : elle ne peut pas être abrogée.',
  introuvable:                 'Ce projet n\'existe plus.',
  pas_auteur:                  'Seul l\'auteur du projet peut le modifier ou le retirer.',
  hors_phase_debat:            'Le texte est figé : la session est ouverte.',
  session_ouverte:             'Le projet ne peut plus être retiré : la session est ouverte.',
  hors_session:                'Ce projet n\'est pas en session.',
  scrutin_clos:                'Le scrutin est clos. Votre action arrive trop tard.',
  pas_depute:                  'Vous n\'occupez aucun des neuf sièges de l\'Assemblée.',
  choix_invalide:              'Choix de vote invalide.',
  intention_invalide:          'Intention invalide.',
  siege_introuvable:           'Ce siège n\'existe pas.',
  siege_tenu_par_pj:           'Ce siège est occupé par un député joueur : son assistant parlementaire ne vote pas.',
  statut_incompatible:         'Ce projet ne peut pas entrer en session.',
  semaine_de_debat_non_ecoulee:'La semaine de débat n\'est pas écoulée.',
  deja_verse_aujourdhui:       'Votre indemnité parlementaire a déjà été versée aujourd\'hui.',
  // Refus des RPC d'action joueur (option A, 11 septembre 2026). Tous sont prononces AVANT le
  // moindre debit : un refus ne coute jamais rien.
  pa_insuffisants:             'Vous n\'avez pas assez de PA.',
  fonds_insuffisants:          'Fonds insuffisants (liquide et Banque nationale).',
  hors_lieu:                   'Vous n\'êtes pas au bon endroit pour cette action.',
  deja_endormi:                'Ce député dort déjà. Rien ne vous a été facturé.',
  deja_eveille:                'Ce député est déjà éveillé. Rien ne vous a été facturé.',
  sels_manquants:              'Il vous faut un flacon de sels d\'ammoniaque.',
  arme_manquante:              'Vous n\'avez pas l\'arme nécessaire dans votre inventaire.',
  bonus_deja_acquis:           'Le lobbyiste vous a déjà promis son appui pour votre prochain marchandage.',
  mode_invalide:               'Mode d\'action invalide.',
  type_invalide:               'Nature de projet invalide.',
  categorie_invalide:          'Choisissez une catégorie technique existante.',
  titre_trop_long:             'Le titre ne doit pas dépasser 120 caractères.',
  texte_trop_long:             'Le texte ne doit pas dépasser 20 000 caractères.',
  personnage_introuvable:      'Votre personnage est introuvable côté serveur.',
  requete_invalide:            'Requête invalide.',
  requete_en_cours:            'Cette action est déjà en cours de traitement.',
  topic_invalide:              'Sujet du forum introuvable.',
  topic_deja_lie:              'Ce projet est déjà relié à un sujet du forum.'
};

function assembleeMessageRefus(res) {
  if (!res) return null;
  return ASSEMBLEE_RAISONS[res.raison] || ('Action refusée (' + (res.raison || 'motif inconnu') + ').');
}


// =====================
// ACTIONS JOUEUR : LE SERVEUR FAIT FOI (option A, 11 septembre 2026)
// =====================
// Chaque action parlementaire est UNE transaction serveur (migration_assemblee_actions_joueur.sql)
// qui relit lieu, PA, fonds, inventaire et statistiques, debite, tire le jet et applique l'effet.
// Ce fichier ne debite plus rien lui-meme et ne rembourse plus rien : il RECOPIE ce que le serveur
// a ecrit. L'ancien schema debit-local-puis-remboursement est supprime -- il reposait sur un
// resultat de jet choisi par le client.
//
// Trois garanties portees par assembleeActionServeur :
//   1. SAUVEGARDE PREALABLE : la base doit voir l'etat reel du joueur (PA regeneres, deplacement,
//      achat) avant qu'une RPC ne le relise. sbSavePersonnage serialise deja toutes les
//      ecritures ; attendre sa tache garantit que les precedentes sont passees.
//   2. UN SEUL CLIC A LA FOIS : un second clic pendant qu'une action est en vol est ignore.
//   3. REPONSE PERDUE : le MEME identifiant de requete est rejoue une fois. Si la premiere
//      transaction a abouti, le serveur renvoie son resultat sans rien refaire ; sinon il
//      l'execute. Jamais de double effet, jamais d'effet serveur ignore par le client.
let _assembleeActionEnVol = false;

function assembleeNouvelleRequete() {
  return 'rq-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
}

// Recopie les valeurs de la base APRES l'operation. Uniquement des valeurs absolues renvoyees par
// le serveur : aucun delta recalcule ici, donc aucun double debit possible.
function assembleeAppliquerEtatServeur(res) {
  if (!res || typeof res !== 'object' || typeof state === 'undefined') return;
  if (typeof res.pa === 'number') state.pa = res.pa;
  if (typeof res.liquide === 'number') state.liquide = res.liquide;
  if (typeof res.arg === 'number') { state.arg = res.arg; if (state.char) state.char.arg = res.arg; }
  if (typeof res.solde_national === 'number' && state.comptesBancaires && state.comptesBancaires.nationale) {
    state.comptesBancaires.nationale.solde = res.solde_national;
  }
  if (typeof res.dis === 'number') state.dis = res.dis;
  if (typeof res.bonus_lobbyiste === 'number') state.bonusLobbyiste = res.bonus_lobbyiste;
  if (typeof res.sels_restants === 'number') {
    const inv = state.inventory || [];
    const lot = inv.find(i => i.stackKey === SELS_AMMONIAQUE.stackKey);
    if (lot) {
      if (res.sels_restants > 0) lot.qty = res.sels_restants;
      else inv.splice(inv.indexOf(lot), 1);
    }
  }
}

// appel(requete) doit renvoyer le resultat de la RPC (null si injoignable).
// Renvoie { ok, res, enVol } -- res=null : rien n'a ete enregistre, rien n'a ete debite.
async function assembleeActionServeur(appel) {
  if (_assembleeActionEnVol) return { ok: false, res: null, enVol: true };
  _assembleeActionEnVol = true;
  try {
    if (typeof sbSavePersonnage === 'function') {
      try { await sbSavePersonnage(state); } catch (e) {}
    }
    const requete = assembleeNouvelleRequete();
    let res = null;
    try { res = await appel(requete); } catch (e) { res = null; }
    if (res === null || res === undefined) {
      try { res = await appel(requete); } catch (e) { res = null; }
    }
    if (res === null || res === undefined) return { ok: false, res: null };

    assembleeAppliquerEtatServeur(res);
    // Reecrit l'etat recopie : si une sauvegarde partie AVANT la RPC est arrivee apres elle, elle
    // vient d'etre corrigee. sbSavePersonnage serialise, cette ecriture passe en dernier.
    if (res.ok !== false && typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
    return { ok: res.ok !== false, res };
  } finally {
    _assembleeActionEnVol = false;
  }
}

// Traitement standard du retour : panne, refus metier, ou succes. Renvoie true si l'action a abouti.
function assembleeIssueAction(r, messagePanne) {
  if (r.enVol) return false;
  if (!r.res) { assembleeIndisponible(messagePanne); return false; }
  if (!r.ok) { showToast('Action refusée', assembleeMessageRefus(r.res), false); return false; }
  return true;
}


// =====================
// DEPOT D'UNE PROPOSITION (§5, §6, §9, §10)
// =====================
// 1 PA. Aucune limite de nombre de projets, ni par joueur ni simultanement (§5).

const ASSEMBLEE_FORUM_ID = 'assemblee';

function ouvrirDeposerProposition(pa, cost) {
  if (!assembleePeutDeposer()) {
    showToast('Accès refusé', ASSEMBLEE_RAISONS.ineligible, false);
    return;
  }

  const optionsCat = Object.entries(CATEGORIES_INTERDICTION)
    .map(([id, c]) => '<option value="' + id + '">' + c.label + '</option>').join('');

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.9rem">Le projet sera publié au forum de l\'Assemblée et débattu au moins une semaine avant de pouvoir entrer en session.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">TITRE</div>';
  html += '<input id="prop-titre" type="text" maxlength="120" placeholder="Ex : Loi sur la transparence des marchés publics" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.55rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem"/>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">NATURE DU PROJET</div>';
  html += '<select id="prop-type" onchange="assembleeMajFormulaireDepot()" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.7rem">';
  html += '<option value="rp">Loi déclarative (RP) — aucun effet mécanique automatique</option>';
  html += '<option value="mecanique">Loi d\'interdiction — effet mécanique réel</option>';
  html += '</select>';

  // Zone categorie, masquee tant que le type n'est pas 'mecanique'.
  html += '<div id="prop-zone-cat" style="display:none;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">CATÉGORIE TECHNIQUE INTERDITE</div>';
  html += '<select id="prop-categorie" onchange="assembleeMajApercuCategorie()" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem">' + optionsCat + '</select>';
  // §9 : l'avertissement doit etre clair et permanent, pas un detail.
  html += '<div style="margin-top:.5rem;padding:.55rem;border:1px solid #6a2010;background:#1a0a05;font-size:.75rem;color:#cc8866;line-height:1.5">';
  html += '<strong style="color:#cc4444">Attention.</strong> L\'effet mécanique dépend <em>uniquement</em> de la catégorie choisie ici, jamais du texte que vous rédigez. <strong>Toute la catégorie sera concernée.</strong> Elle est verrouillée dès le dépôt : pour en changer, il faudra retirer ce projet et en déposer un nouveau.';
  html += '</div>';
  html += '<div id="prop-apercu-cat" style="margin-top:.5rem;font-size:.75rem;color:#8a8060"></div>';
  html += '</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">TEXTE DU PROJET</div>';
  html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.3rem;font-style:italic">Ce texte est définitif : les amendements viendront s\'ajouter dessous, sans jamais le remplacer.</div>';
  html += '<textarea id="prop-texte" rows="7" placeholder="Exposé des motifs et dispositions..." style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.55rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:vertical;margin-bottom:.8rem"></textarea>';

  html += '<button onclick="confirmerDeposerProposition(' + (pa || 1) + ',' + (cost || 0) + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer le projet (' + (pa || 1) + ' PA)</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Déposer un projet de loi';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  assembleeMajFormulaireDepot();
}

function assembleeMajFormulaireDepot() {
  const type = document.getElementById('prop-type')?.value;
  const zone = document.getElementById('prop-zone-cat');
  if (zone) zone.style.display = (type === 'mecanique') ? 'block' : 'none';
  if (type === 'mecanique') assembleeMajApercuCategorie();
}

function assembleeMajApercuCategorie() {
  const cle = document.getElementById('prop-categorie')?.value;
  const zone = document.getElementById('prop-apercu-cat');
  if (!zone) return;
  const contenu = assembleeContenuCategorie(cle);
  zone.innerHTML = contenu.length
    ? 'Concernerait actuellement : <span style="color:#c0b090">' + contenu.join(' · ') + '</span>'
    : '';
}

async function confirmerDeposerProposition(pa, cost) {
  // §52 : on revalide tout ici, l'etat des champs de l'UI ne fait foi de rien.
  if (!assembleePeutDeposer()) { showToast('Accès refusé', ASSEMBLEE_RAISONS.ineligible, false); return; }
  if (typeof sbAssembleeDeposer !== 'function') { assembleeIndisponible(); return; }

  const titre = document.getElementById('prop-titre')?.value?.trim();
  const texte = document.getElementById('prop-texte')?.value?.trim();
  const type  = document.getElementById('prop-type')?.value || 'rp';
  const categorie = (type === 'mecanique') ? (document.getElementById('prop-categorie')?.value || null) : null;

  if (!titre || !texte) { showToast('Champs requis', ASSEMBLEE_RAISONS.champs_requis, false); return; }
  if (type === 'mecanique' && !CATEGORIES_INTERDICTION[categorie]) {
    showToast('Catégorie invalide', 'Choisissez une catégorie technique existante.', false);
    return;
  }

  // 1 PA debite par le serveur, dans la transaction du depot. L'identifiant est genere par le
  // serveur : on lit celui de la proposition renvoyee.
  const r = await assembleeActionServeur(rq =>
    sbAssembleeDeposer(state.char?.name, titre, type, texte, categorie, null, rq));
  if (!assembleeIssueAction(r, 'Le dépôt n\'a pas pu être enregistré. Aucun projet n\'a été créé, rien n\'a été débité.')) return;
  const id = r.res.proposition?.id;

  document.getElementById('modal-postes').classList.remove('open');

  // Publication du sujet au forum de l'Assemblee (§10). Non bloquant : un projet valablement
  // depose existe meme si le forum echoue -- le registre officiel reste la source institutionnelle.
  // Le lien est pose par RPC : l'ancienne ecriture REST etait refusee silencieusement par la RLS.
  const topicId = id ? await assembleePublierTopic(id, titre, type, categorie, texte).catch(() => null) : null;
  if (topicId && typeof sbAssembleeLierTopic === 'function') {
    await sbAssembleeLierTopic(state.char?.name, id, topicId).catch(() => null);
  }

  showToast('Projet déposé', titre + ' — débat ouvert pour une semaine.', true, true);
  addJournalEntry('Projet de loi déposé à l\'Assemblée : ' + titre + '.', 'event-good');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('ASSEMBLÉE NATIONALE : ' + (state.char?.name || 'Un parlementaire') + ' dépose le projet « ' + titre + ' ».');
  }
  updateUI();
}

// Corps du sujet forum. Contient tout ce que §10 exige, et rien de plus : le forum est une
// vitrine, le registre officiel (§31) reste la source de verite.
function assembleeCorpsTopic(titre, type, categorie, texte, auteur) {
  const lignes = [];
  lignes.push('**' + titre + '**');
  lignes.push('');
  lignes.push('Déposé par ' + (auteur || 'un parlementaire') + '.');
  if (type === 'rp') {
    lignes.push('Nature : loi déclarative (RP). Aucun effet mécanique automatique — son application dépend des joueurs et des institutions.');
  } else if (type === 'mecanique') {
    const cat = CATEGORIES_INTERDICTION[categorie];
    lignes.push('Nature : loi d\'interdiction mécanique.');
    lignes.push('Catégorie technique visée : **' + (cat ? cat.label : categorie) + '**.');
    const contenu = assembleeContenuCategorie(categorie);
    if (contenu.length) lignes.push('Concerne actuellement : ' + contenu.join(' · ') + '.');
  } else if (type === 'abrogation') {
    lignes.push('Nature : proposition d\'abrogation.');
  }
  lignes.push('');
  lignes.push('— — — TEXTE ORIGINAL — — —');
  lignes.push('');
  lignes.push(texte);
  return lignes.join('\n');
}

async function assembleePublierTopic(propId, titre, type, categorie, texte) {
  if (typeof sbCreateTopic !== 'function' || typeof sbCreatePost !== 'function') return null;
  const time = (typeof formatDateHeureJeu === 'function') ? formatDateHeureJeu() : new Date().toLocaleString('fr-FR');
  const auteur = state.char?.name || 'Assemblée';
  const topicId = await sbCreateTopic(
    ASSEMBLEE_FORUM_ID, '[PROJET] ' + titre, auteur, state.country || 'republic', time
  );
  if (!topicId) return null;
  await sbCreatePost(topicId, auteur, assembleeCorpsTopic(titre, type, categorie, texte, auteur), time)
    .catch(() => {});
  return topicId;
}


// =====================
// AMENDEMENT (§7)
// =====================
// 0 PA. Seul l'auteur. L'amendement s'AJOUTE : le texte original n'est jamais reecrit (garanti
// aussi par trigger cote base).

async function ouvrirAmenderProposition() {
  if (typeof sbGetAssembleePropositions !== 'function') { assembleeIndisponible(); return; }
  const moi = state.char?.name;
  const props = await sbGetAssembleePropositions(state.country || 'republic', ['debat']).catch(() => null);
  if (!props) { assembleeIndisponible(); return; }
  const miens = props.filter(p => p.auteur === moi);

  let html = '<div style="padding:1rem">';
  if (!miens.length) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Vous n\'avez aucun projet en phase de débat. Un projet entré en session ne peut plus être amendé.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Un amendement s\'ajoute sous le texte original, sans jamais le remplacer. Gratuit.</div>';
    miens.forEach(p => {
      const nbAmd = Array.isArray(p.amendements) ? p.amendements.length : 0;
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8C97A">' + p.titre + '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.4rem">' + nbAmd + ' amendement(s) · session possible à partir du ' + assembleeFormaterEcheance(p.eligible_session_ts) + '</div>';
      html += '<button onclick="assembleeOuvrirSaisieAmendement(\'' + p.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem .8rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Amender</button> ';
      html += '<button onclick="confirmerRetraitProposition(\'' + p.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem .8rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Retirer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Mes projets en débat';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function assembleeOuvrirSaisieAmendement(propId) {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Le texte original reste intact. Cet amendement apparaîtra sous lui, daté, dans l\'ordre chronologique.</div>';
  html += '<textarea id="amd-texte" rows="7" placeholder="Texte de l\'amendement..." style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.55rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:vertical;margin-bottom:.8rem"></textarea>';
  html += '<button onclick="confirmerAmendement(\'' + propId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer l\'amendement (gratuit)</button>';
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Amender mon projet';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerAmendement(propId) {
  if (typeof sbAssembleeAmender !== 'function') { assembleeIndisponible(); return; }
  const texte = document.getElementById('amd-texte')?.value?.trim();
  if (!texte) { showToast('Champs requis', 'Le texte de l\'amendement est obligatoire.', false); return; }

  // Idempotent par requete : un double-clic n'ajoute jamais deux amendements.
  const r = await assembleeActionServeur(rq => sbAssembleeAmender(state.char?.name, propId, texte, rq));
  if (!assembleeIssueAction(r, 'L\'amendement n\'a pas pu être enregistré.')) return;
  const res = r.res;

  document.getElementById('modal-postes').classList.remove('open');

  // Publication au forum, dans le meme topic, en zone institutionnelle distincte (§10).
  const prop = res.proposition || {};
  const num = Array.isArray(prop.amendements) ? prop.amendements.length : 1;
  if (prop.forum_topic_id && typeof sbCreatePost === 'function') {
    const time = (typeof formatDateHeureJeu === 'function') ? formatDateHeureJeu() : new Date().toLocaleString('fr-FR');
    await sbCreatePost(prop.forum_topic_id, state.char?.name || 'Assemblée',
      '— — — AMENDEMENT N°' + num + ' — — —\n\n' + texte, time).catch(() => {});
  }

  showToast('Amendement déposé', 'Amendement n°' + num + ' ajouté sous le texte original.', true);
  addJournalEntry('Amendement n°' + num + ' déposé sur « ' + (prop.titre || 'un projet') + ' ».', 'event-info');
}


// =====================
// RETRAIT (§8)
// =====================
// 0 PA, pendant la phase de debat uniquement. Une fois la session ouverte, le projet appartient
// a l'Assemblee, plus a son auteur.

async function confirmerRetraitProposition(propId) {
  if (typeof sbAssembleeRetirer !== 'function') { assembleeIndisponible(); return; }
  const r = await assembleeActionServeur(() => sbAssembleeRetirer(propId, state.char?.name));
  if (!assembleeIssueAction(r, 'Le retrait n\'a pas pu être enregistré.')) return;
  const res = r.res;

  document.getElementById('modal-postes').classList.remove('open');
  const prop = res.proposition || {};
  if (prop.forum_topic_id && typeof sbCreatePost === 'function') {
    const time = (typeof formatDateHeureJeu === 'function') ? formatDateHeureJeu() : new Date().toLocaleString('fr-FR');
    await sbCreatePost(prop.forum_topic_id, 'Secrétariat de l\'Assemblée',
      '— — — PROJET RETIRÉ PAR SON AUTEUR — — —', time).catch(() => {});
  }
  showToast('Projet retiré', (prop.titre || 'Le projet') + ' est retiré de l\'ordre du jour.', true);
  addJournalEntry('Retrait du projet « ' + (prop.titre || '') + ' ».', 'event-info');
}


// =====================
// PROPOSITION D'ABROGATION (§32)
// =====================
// Meme circuit qu'un depot normal, meme cout (1 PA), meme eligibilite. La cible doit etre une loi
// REELLEMENT en vigueur -- verifie cote serveur.

async function ouvrirProposerAbrogation(pa, cost) {
  if (!assembleePeutDeposer()) { showToast('Accès refusé', ASSEMBLEE_RAISONS.ineligible, false); return; }
  if (typeof sbGetAssembleePropositions !== 'function') { assembleeIndisponible(); return; }

  const lois = await sbGetAssembleePropositions(state.country || 'republic', ['adoptee']).catch(() => null);
  if (!lois) { assembleeIndisponible(); return; }

  let html = '<div style="padding:1rem">';
  if (!lois.length) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune loi n\'est actuellement en vigueur.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">L\'abrogation suit exactement le même circuit qu\'un projet ordinaire : forum, une semaine de débat, session, vote.</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">LOI À ABROGER</div>';
    html += '<select id="abr-cible" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.7rem">';
    lois.forEach(l => {
      const marque = l.type === 'mecanique' ? ' [mécanique]' : '';
      html += '<option value="' + l.id + '">' + l.titre + marque + '</option>';
    });
    html += '</select>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">EXPOSÉ DES MOTIFS</div>';
    html += '<textarea id="abr-texte" rows="6" placeholder="Pourquoi cette loi doit-elle être abrogée ?" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.55rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:vertical;margin-bottom:.8rem"></textarea>';
    html += '<button onclick="confirmerProposerAbrogation(' + (pa || 1) + ',' + (cost || 0) + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer la proposition d\'abrogation (' + (pa || 1) + ' PA)</button>';
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Proposer une abrogation';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerProposerAbrogation(pa, cost) {
  if (!assembleePeutDeposer()) { showToast('Accès refusé', ASSEMBLEE_RAISONS.ineligible, false); return; }
  if (typeof sbAssembleeDeposer !== 'function') { assembleeIndisponible(); return; }

  const cibleId = document.getElementById('abr-cible')?.value;
  const texte   = document.getElementById('abr-texte')?.value?.trim();
  if (!cibleId || !texte) { showToast('Champs requis', ASSEMBLEE_RAISONS.champs_requis, false); return; }

  const cible = await sbGetAssembleeProposition(cibleId).catch(() => null);
  if (!cible) { assembleeIndisponible(); return; }

  // Le titre d'une abrogation est construit par le serveur a partir de la loi visee.
  const r = await assembleeActionServeur(rq =>
    sbAssembleeDeposer(state.char?.name, null, 'abrogation', texte, null, cibleId, rq));
  if (!assembleeIssueAction(r, 'Le dépôt n\'a pas pu être enregistré. Rien n\'a été débité.')) return;
  const id = r.res.proposition?.id;
  const titre = r.res.proposition?.titre || ('Abrogation — ' + cible.titre);

  document.getElementById('modal-postes').classList.remove('open');
  const topicId = id ? await assembleePublierTopic(id, titre, 'abrogation', null, texte).catch(() => null) : null;
  if (topicId && typeof sbAssembleeLierTopic === 'function') {
    await sbAssembleeLierTopic(state.char?.name, id, topicId).catch(() => null);
  }

  showToast('Abrogation proposée', titre, true, true);
  addJournalEntry('Proposition d\'abrogation déposée : ' + cible.titre + '.', 'event-good');
  updateUI();
}


// =====================
// VOTE D'UN DEPUTE PJ (§14)
// =====================
// 0 PA. POUR / CONTRE / ABSTENTION. Modifiable autant de fois qu'on veut jusqu'a la cloture.
// ABSTENTION et "N'A PAS VOTE" sont deux etats distincts : voter ABSTENTION cree une ligne, ne
// pas voter n'en cree aucune. Les deux comptent zero, mais sont archives separement (§28).

async function ouvrirVoterLoi(pa, cost) {
  if (typeof sbGetAssembleePropositions !== 'function') { assembleeIndisponible(); return; }

  await rafraichirAssemblee();
  const monSiege = assembleeMonSiege();
  if (!monSiege) {
    showToast('Accès refusé', ASSEMBLEE_RAISONS.pas_depute, false);
    return;
  }

  const pays = state.country || 'republic';
  const sessions = await sbGetAssembleePropositions(pays, ['session']).catch(() => null);
  if (!sessions) { assembleeIndisponible(); return; }

  let html = '<div style="padding:1rem">';
  if (!sessions.length) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun projet n\'est actuellement en session.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Vote gratuit et modifiable jusqu\'à la clôture. Le dernier état enregistré est celui qui compte.</div>';

    // Mes votes actuels, une requete par projet -- le nombre de sessions simultanees reste petit.
    for (const p of sessions) {
      const votes = await sbGetAssembleeVotes(p.id, p.session_num).catch(() => []);
      const mien = votes.find(v => v.votant === state.char?.name);
      const clos = assembleeSessionParaitClose(p);

      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A;margin-bottom:.2rem">' + p.titre + '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.5rem">Déposé par ' + p.auteur + ' · clôture ' + assembleeFormaterEcheance(p.cloture_ts) + '</div>';

      if (mien) {
        html += '<div style="font-size:.78rem;color:#4a8a4a;margin-bottom:.4rem">Votre vote : <strong>' + mien.choix + '</strong> — vous pouvez encore en changer.</div>';
      } else {
        html += '<div style="font-size:.78rem;color:#8a6a20;margin-bottom:.4rem">Vous n\'avez pas encore voté.</div>';
      }

      if (clos) {
        html += '<div style="font-size:.75rem;color:#8a3a2a;font-style:italic">Scrutin clos — en attente du dépouillement.</div>';
      } else {
        html += '<div style="display:flex;gap:.4rem">';
        [['POUR', '#4a8a4a'], ['CONTRE', '#8a2020'], ['ABSTENTION', '#6a6040']].forEach(([c, col]) => {
          const actif = mien && mien.choix === c;
          html += '<button onclick="confirmerVoteLoi(\'' + p.id + '\',\'' + c + '\')" style="flex:1;padding:.42rem;border:1px solid ' + col + ';background:' + (actif ? col + '22' : 'transparent') + ';color:' + col + ';cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">' + c + '</button>';
        });
        html += '</div>';
      }
      html += '</div>';
    }
  }
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Voter une loi';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVoteLoi(propId, choix) {
  if (typeof sbAssembleeVoter !== 'function') { assembleeIndisponible(); return; }

  // Le serveur revalide le mandat, le lieu, le statut de session ET l'heure de cloture sur SON
  // horloge. Le vote est un upsert : le rejouer est sans effet supplementaire.
  const r = await assembleeActionServeur(() => sbAssembleeVoter(propId, state.char?.name, choix));
  if (!assembleeIssueAction(r, 'Votre vote n\'a pas pu être enregistré.')) return;

  showToast('Vote enregistré', choix + '. Vous pouvez encore en changer jusqu\'à la clôture.', true);
  addJournalEntry('Vote à l\'Assemblée : ' + choix + '.', 'event-info');
  ouvrirVoterLoi(0, 0);   // rafraichit l'ecran sur l'etat reel
}


// =====================
// QUESTIONNER UN DEPUTE PNJ (§12)
// =====================
// 0 PA, 100 %, aucun jet. Le PNJ repond SINCEREMENT son intention DU MOMENT : si quelqu'un l'a
// retourne entre deux questions, la reponse change. C'est voulu -- les joueurs doivent pouvoir
// constater qu'un depute a retourne sa veste sans jamais savoir qui l'a payé (§15).

async function questionnerDeputeAssemblee(siegeId) {
  const siege = assembleeSiegeParId(siegeId);
  if (!siege) { showToast('Introuvable', ASSEMBLEE_RAISONS.siege_introuvable, false); return; }
  if (typeof sbGetAssembleePropositions !== 'function') { assembleeIndisponible(); return; }

  await rafraichirAssemblee();
  const occ = assembleeOccupationSiege(siegeId);

  // §2 : un assistant parlementaire n'a plus d'intention. La question n'a plus d'objet.
  if (occ && !occ.estPnj) {
    showToast('Sans objet', siege.nom + ' est désormais assistant parlementaire de ' + occ.pjNom + '. Il ne vote plus.', false);
    return;
  }
  // §12 : endormi, il ne peut pas répondre utilement.
  if (occ && occ.endormi) {
    showToast('Aucune réponse', siege.nom + ' est affalé sur son pupitre et ronfle doucement. Vous n\'en tirerez rien.', false);
    return;
  }

  const pays = state.country || 'republic';
  const sessions = await sbGetAssembleePropositions(pays, ['session']).catch(() => null);
  if (!sessions) { assembleeIndisponible(); return; }

  let html = '<div style="padding:1rem">';
  if (!sessions.length) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">« Aucun texte n\'est à l\'ordre du jour pour l\'instant. Revenez quand l\'Assemblée siégera. »</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Vous interrogez ' + siege.nom + ' sur ses intentions de vote.</div>';
    for (const p of sessions) {
      const intentions = await sbGetAssembleeIntentions(p.id, p.session_num).catch(() => []);
      const mienne = intentions.find(i => i.siege_id === siegeId);
      const col = mienne ? (mienne.intention === 'POUR' ? '#4a8a4a' : '#8a3a2a') : '#6a6040';
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.65rem;margin-bottom:.45rem">';
      html += '<div style="font-size:.84rem;color:#c0b090;margin-bottom:.25rem">' + p.titre + '</div>';
      html += mienne
        ? '<div style="font-size:.82rem;color:' + col + '">« Sur ce texte, je voterai <strong>' + mienne.intention + '</strong>. »</div>'
        : '<div style="font-size:.78rem;color:#6a6040;font-style:italic">« Je n\'ai pas encore d\'avis arrêté sur ce texte. »</div>';
      html += '</div>';
    }
  }
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Questionner ' + siege.nom;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}


// =====================
// OBSERVER LES DEBATS (§13)
// =====================
// 1 PA. Snapshot de TOUS les projets en session -- jamais un seul. Le snapshot n'est pas remis a
// jour ensuite : pour connaitre l'etat plus recent, il faut repayer 1 PA.
//
// REECRITURE COMPLETE de l'ancien observerDebats (plateau-politique.js), dont l'audit du
// 9 septembre a montre qu'il affichait quatre deputes CODES EN DUR avec des positions TIREES AU
// HASARD A CHAQUE OUVERTURE, sans jamais lire les vrais sieges ni la table des lois. L'ancienne
// implementation est supprimee, pas doublee : le projet a deja souffert de fonctions dupliquees
// dont seule la derniere chargee comptait.

async function observerDebats(pa, cost) {
  if (typeof sbGetAssembleePropositions !== 'function') { assembleeIndisponible(); return; }

  const pays = state.country || 'republic';
  await rafraichirAssemblee();
  const occ = assembleeOccupation();
  if (!occ) { assembleeIndisponible(); return; }

  const sessions = await sbGetAssembleePropositions(pays, ['session']).catch(() => null);
  if (!sessions) { assembleeIndisponible(); return; }

  // Le PA se paie APRES avoir verifie qu'on peut reellement produire le snapshot, et AVANT de
  // l'afficher. Un joueur ne doit pas payer pour un ecran d'indisponibilite.
  const r = await deduireCoutOrdre({ pa: pa || 1, cost: cost || 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  const horodatage = new Date().toLocaleString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.9rem">Vous observez la séance depuis les tribunes. État constaté à ' + horodatage + ' — il n\'évoluera plus sur cet écran.</div>';

  if (!sessions.length) {
    html += '<div style="font-size:.85rem;color:#5a5030;font-style:italic">Aucun projet n\'est en session. Les pupitres sont vides et le buffet est déjà entamé.</div>';
  } else {
    for (const p of sessions) {
      const [intentions, votes] = await Promise.all([
        sbGetAssembleeIntentions(p.id, p.session_num).catch(() => []),
        sbGetAssembleeVotes(p.id, p.session_num).catch(() => [])
      ]);

      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.8rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.92rem;color:#E8C97A">' + p.titre + '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.6rem">Déposé par ' + p.auteur + ' · clôture ' + assembleeFormaterEcheance(p.cloture_ts) + '</div>';

      // ---- Deputes PNJ actifs
      const pnjs = occ.filter(o => o.estPnj);
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">DÉPUTÉS PNJ</div>';
      if (!pnjs.length) {
        html += '<div style="font-size:.75rem;color:#5a5030;font-style:italic">Les neuf sièges sont tenus par des joueurs.</div>';
      } else {
        pnjs.forEach(o => {
          const it = intentions.find(i => i.siege_id === o.siegeId);
          let libelle, col;
          if (o.endormi)      { libelle = 'Endormi'; col = '#6a5a8a'; }
          else if (it)        { libelle = it.intention; col = it.intention === 'POUR' ? '#4a8a4a' : '#8a3a2a'; }
          else                { libelle = 'Sans avis'; col = '#6a6040'; }
          html += '<div style="font-size:.76rem;color:#c0b090">' + o.pnjNom + ' : <span style="color:' + col + '">' + libelle + '</span></div>';
        });
      }

      // ---- Deputes PJ
      const pjs = occ.filter(o => !o.estPnj);
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin:.55rem 0 .3rem">DÉPUTÉS JOUEURS</div>';
      if (!pjs.length) {
        html += '<div style="font-size:.75rem;color:#5a5030;font-style:italic">Aucun siège n\'est tenu par un joueur.</div>';
      } else {
        pjs.forEach(o => {
          const v = votes.find(x => x.votant === o.pjNom);
          const libelle = v ? v.choix : 'N\'A PAS VOTÉ';
          const col = !v ? '#8a6a20'
            : v.choix === 'POUR' ? '#4a8a4a'
            : v.choix === 'CONTRE' ? '#8a3a2a' : '#6a6040';
          html += '<div style="font-size:.76rem;color:#c0b090">' + o.pjNom + ' : <span style="color:' + col + '">' + libelle + '</span></div>';
        });
      }
      html += '</div>';
    }
  }

  // Bonus journaliste conserve de l'ancienne implementation. updateUI() est desormais appele
  // dans TOUS les cas (l'audit avait releve que la jauge de PA restait fausse pour les
  // non-journalistes, updateUI n'etant appele que dans cette branche).
  if (state.char?.career === 'press') {
    state.inf = Math.min(100, (state.inf || 0) + 1);
    html += '<div style="font-size:.74rem;color:#C9A84C;margin-top:.5rem">+1 INF (bonus journaliste)</div>';
  }
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Observer les débats';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  updateUI();
}


// =====================
// MARCHANDER UN VOTE (§15)
// =====================
// Accessible a TOUS les PJ, quelle que soit leur fonction. Cible : un depute PNJ occupant
// reellement son siege. 1 PA + 100 FR a CHAQUE TENTATIVE, y compris ratee.
//
// Les 100 FR ne sont pas detruits : ils vont a la caisse 'republic_assemblee' via une RPC
// transactionnelle. L'audit du 9 septembre a montre que l'ancienne implementation
// (soumettreVoteMarchande) lisait state.votesEnCours -- une variable SANS AUCUN PRODUCTEUR --,
// ne debitait qu'en cas de succes, et DETRUISAIT l'argent. Cette chaine morte est supprimee.
//
// LEGALITE (§15) : aucune trace criminelle, aucune convocation, aucune enquete, aucune
// revelation d'identite. On n'appelle donc NI checkDetection, NI tracerActionPourRumeur, NI
// historiqueCrimes -- et la RPC ne recoit jamais le nom du marchandeur.

const ASSEMBLEE_MARCHANDAGE_PA   = 1;
const ASSEMBLEE_MARCHANDAGE_COUT = 100;
const ASSEMBLEE_LOBBYISTE_PA     = 1;
const ASSEMBLEE_LOBBYISTE_COUT   = 150;
const ASSEMBLEE_LOBBYISTE_BONUS  = 20;

// §15 : 50 + (CHA + ENT) / 2, maximum 66 %. §16 : + 20 points si le Lobbyiste a ete consulte,
// maximum 86 %. AFFICHAGE UNIQUEMENT : le taux qui compte est calcule par assemblee_marchander,
// sur les statistiques DE BASE (state.char.stats, defaut 8), sans formation, moyenne de groupe ni
// bonus ENT local -- arbitrage du 11 septembre 2026. Cette fonction reproduit exactement
// assemblee_taux_marchandage pour que le joueur voie le chiffre que le serveur appliquera.
function assembleeStatBase(cle) {
  const v = (typeof state !== 'undefined') ? state.char?.stats?.[cle] : undefined;
  return (typeof v === 'number') ? v : 8;
}

function assembleeTauxMarchandage() {
  const base = Math.max(0, Math.min(66, Math.round(50 + (assembleeStatBase('CHA') + assembleeStatBase('ENT')) / 2)));
  return base + (assembleeBonusLobbyiste() > 0 ? ASSEMBLEE_LOBBYISTE_BONUS : 0);
}

// Bonus persiste (colonne personnages.bonus_lobbyiste), ECRIT UNIQUEMENT PAR LE SERVEUR : pose
// par assemblee_consulter_lobbyiste, consomme par assemblee_marchander. Lu ici pour l'affichage.
function assembleeBonusLobbyiste() {
  if (typeof state === 'undefined') return 0;
  return Math.max(0, state.bonusLobbyiste || 0);
}

async function ouvrirMarchanderVote(pa, cost) {
  if (typeof sbGetAssembleePropositions !== 'function') { assembleeIndisponible(); return; }

  await rafraichirAssemblee();
  const occ = assembleeOccupation();
  if (!occ) { assembleeIndisponible(); return; }

  const pays = state.country || 'republic';
  const sessions = await sbGetAssembleePropositions(pays, ['session']).catch(() => null);
  if (!sessions) { assembleeIndisponible(); return; }

  if (!sessions.length) {
    showToast('Aucune session', 'Aucun projet n\'est en session : il n\'y a rien à marchander.', false);
    return;
  }
  const pnjs = occ.filter(o => o.estPnj);
  if (!pnjs.length) {
    showToast('Aucune cible', 'Les neuf sièges sont tenus par des joueurs. Aucun député PNJ à convaincre.', false);
    return;
  }

  const taux = assembleeTauxMarchandage();
  const bonus = assembleeBonusLobbyiste();
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[pays]?.cur) || 'FR';

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.35rem">Un mot glissé dans un couloir, une enveloppe qui change de main. Parfaitement légal à Républia.</div>';
  html += '<div style="font-size:.8rem;color:#C9A84C;margin-bottom:.8rem">Chance : <strong>' + taux + ' %</strong>'
       + (bonus > 0 ? ' <span style="color:#8a6a20">(dont +' + bonus + ' du lobbyiste)</span>' : '')
       + ' · Coût : ' + ASSEMBLEE_MARCHANDAGE_PA + ' PA + ' + ASSEMBLEE_MARCHANDAGE_COUT + ' ' + cur + ', <em>même en cas d\'échec</em>.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">PROJET</div>';
  html += '<select id="mar-projet" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.6rem">';
  sessions.forEach(p => { html += '<option value="' + p.id + '">' + p.titre + '</option>'; });
  html += '</select>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">DÉPUTÉ À CONVAINCRE</div>';
  html += '<select id="mar-siege" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.6rem">';
  pnjs.forEach(o => {
    const villeNom = (typeof WORLD !== 'undefined' && WORLD.republic?.[o.city]?.name) || o.city;
    html += '<option value="' + o.siegeId + '">' + o.pnjNom + ' (' + villeNom + ')' + (o.endormi ? ' — endormi' : '') + '</option>';
  });
  html += '</select>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">VOTE SOUHAITÉ</div>';
  html += '<select id="mar-intention" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.9rem">';
  html += '<option value="POUR">POUR</option><option value="CONTRE">CONTRE</option></select>';

  html += '<button onclick="confirmerMarchanderVote()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Tenter le marchandage</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Marchander un vote';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMarchanderVote() {
  if (typeof sbAssembleeMarchander !== 'function') { assembleeIndisponible(); return; }

  const propId    = document.getElementById('mar-projet')?.value;
  const siegeId   = document.getElementById('mar-siege')?.value;
  const intention = document.getElementById('mar-intention')?.value;
  if (!propId || !siegeId || !intention) { showToast('Choix incomplet', 'Sélectionnez un projet, un député et une intention.', false); return; }

  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';

  // §52 : on revalide la cible ici, l'UI ne fait foi de rien. Le serveur la revalide ensuite.
  const occ = assembleeOccupationSiege(siegeId);
  if (occ && !occ.estPnj) { showToast('Cible invalide', ASSEMBLEE_RAISONS.siege_tenu_par_pj, false); return; }

  document.getElementById('modal-postes').classList.remove('open');

  // TOUT est serveur (option A) : lieu, PA, fonds (liquide + Banque nationale), taux, jet, bonus
  // Lobbyiste, credit de la caisse, intention. Le client ne transmet ni resultat ni montant.
  // Un jet RATE reste facture (§15) ; une panne technique ne debite rien.
  const r = await assembleeActionServeur(rq =>
    sbAssembleeMarchander(state.char?.name, propId, siegeId, intention, rq));
  if (!assembleeIssueAction(r, 'Le marchandage n\'a pas pu être enregistré. Rien n\'a été débité.')) return;
  const reussi = !!r.res.reussi;

  const siege = assembleeSiegeParId(siegeId);
  const nom = siege ? siege.nom : 'Le député';
  if (reussi) {
    showToast('Marchandage réussi', nom + ' votera ' + intention + '. Personne ne saura d\'où vient ce revirement.', true, true);
    addJournalEntry('Marchandage réussi auprès de ' + nom + ' (' + intention + '). -' + ASSEMBLEE_MARCHANDAGE_COUT + ' ' + cur + '.', 'event-good');
  } else {
    showToast('Marchandage échoué', nom + ' empoche, sourit, et ne promet rien. -' + ASSEMBLEE_MARCHANDAGE_COUT + ' ' + cur + '.', false, true);
    addJournalEntry('Tentative de marchandage ratée auprès de ' + nom + '. -' + ASSEMBLEE_MARCHANDAGE_COUT + ' ' + cur + '.', 'event-bad');
  }
  updateUI();
}


// =====================
// CONSULTER LE LOBBYISTE (§16)
// =====================
// 1 PA + 150 FR. +20 points de pourcentage sur la PROCHAINE tentative de marchandage.
// Le bonus est PERSISTE (colonne dediee) et consomme a la tentative suivante, qu'elle
// reussisse ou echoue.

async function doConsulterLobbyiste(pa, cost) {
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  // Cout FIXE cote serveur (1 PA + 150 FR) : les parametres pa/cost de l'ordre ne servent plus
  // qu'a l'affichage, jamais au debit.
  const coutFR = ASSEMBLEE_LOBBYISTE_COUT;

  if (assembleeBonusLobbyiste() > 0) {
    showToast('Déjà acquis', 'Le lobbyiste vous a déjà promis son appui pour votre prochain marchandage.', false);
    return;
  }
  if (typeof sbAssembleeConsulterLobbyiste !== 'function') { assembleeIndisponible(); return; }

  const r = await assembleeActionServeur(rq => sbAssembleeConsulterLobbyiste(state.char?.name, rq));
  if (!assembleeIssueAction(r, 'La consultation n\'a pas pu être enregistrée. Rien n\'a été débité.')) return;
  updateUI();
  showToast('Accord conclu',
    'Le lobbyiste passera quelques coups de fil : +' + ASSEMBLEE_LOBBYISTE_BONUS + ' points sur votre prochain marchandage. -' + coutFR + ' ' + cur + '.',
    true, true);
  addJournalEntry('Consultation du lobbyiste dans les couloirs de l\'Assemblée (+' + ASSEMBLEE_LOBBYISTE_BONUS + ' au prochain marchandage).', 'event-info');
}


// =====================
// SELS D'AMMONIAQUE (§23) ET REVEIL D'UN DEPUTE (§22)
// =====================
// L'objet est un consommable d'inventaire ordinaire, empilable, sans limite propre de portage :
// seule la limite generale de l'inventaire s'applique (§23).

const SELS_AMMONIAQUE = {
  stackKey: 'sels_ammoniaque',
  nom: 'Sels d\'ammoniaque',
  icon: 'ti-flask',
  prix: 30,
  desc: 'Un flacon piquant. Réveille brutalement quelqu\'un d\'assoupi — un député, par exemple.'
};

function assembleeNbSels() {
  const lot = (state.inventory || []).find(i => i.stackKey === SELS_AMMONIAQUE.stackKey);
  return lot ? (lot.qty || 0) : 0;
}

// §23 : achetable directement a l'usine pharmaceutique. Ordre dedie plutot qu'ajout au stock de
// vente directe : ce dernier n'expose que les produits issus des CHAINES_PRODUCTION_USINE, dont
// le stock peut etre a zero. Or 'Reveiller' est une mecanique centrale du scrutin -- la faire
// dependre de la production du jour la rendrait indisponible sans raison lisible pour le joueur.
// Le produit reste vendu par l'usine, et son prix alimente la caisse de l'usine comme la vente
// directe : le circuit economique existant n'est pas contourne.
async function doAcheterSelsAmmoniaque(pa, cost) {
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' + SELS_AMMONIAQUE.desc + '</div>';
  html += '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.6rem">Prix unitaire : <strong style="color:#C9A84C">' + SELS_AMMONIAQUE.prix + ' ' + cur + '</strong> · Vous en avez ' + assembleeNbSels() + '.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">QUANTITÉ</div>';
  html += '<input id="sels-qte" type="number" min="1" max="20" value="1" style="width:100%;box-sizing:border-box;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.9rem;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerAcheterSels(' + (pa || 0) + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Acheter</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Sels d\'ammoniaque';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAcheterSels(pa) {
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  const qte = Math.max(1, Math.min(20, parseInt(document.getElementById('sels-qte')?.value || 1, 10)));
  const total = qte * SELS_AMMONIAQUE.prix;

  const dispo = (typeof getFondsDisponiblesOrdinaires === 'function') ? getFondsDisponiblesOrdinaires() : (state.arg || 0);
  if (dispo < total) { showToast('Fonds insuffisants', total + ' ' + cur + ' requis.', false); return; }
  // Vente legale de l'usine : soumise a la regle generale des interdictions, avant tout debit.
  if (!(await assembleeControlerVenteLegale([{ stackKey: SELS_AMMONIAQUE.stackKey }]))) return;

  const r = await deduireCoutOrdre({ pa: pa || 0, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  // addToInventory renvoie la quantite REELLEMENT ajoutee (l'inventaire a une limite globale) :
  // on ne facture que ce qui est effectivement entre (§23).
  const ajoute = (typeof addToInventory === 'function')
    ? addToInventory({
        name: SELS_AMMONIAQUE.nom, icon: SELS_AMMONIAQUE.icon,
        stackable: true, stackKey: SELS_AMMONIAQUE.stackKey, qty: qte,
        legal: true, desc: SELS_AMMONIAQUE.desc
      })
    : 0;

  if (!ajoute) { showToast('Inventaire plein', 'Impossible d\'emporter davantage.', false); return; }

  const paye = ajoute * SELS_AMMONIAQUE.prix;
  if (typeof debiterFondsOrdinaires === 'function') await debiterFondsOrdinaires(paye);
  else state.arg = Math.max(0, (state.arg || 0) - paye);

  // Le produit de la vente alimente la caisse de l'usine, comme la vente directe.
  if (typeof crediterCaisseBatiment === 'function') {
    await crediterCaisseBatiment(state.country || 'republic', 'usine-pharmaceutique-luthecia', paye).catch(() => {});
  }

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Achat effectué', ajoute + ' flacon(s) de sels d\'ammoniaque. -' + paye + ' ' + cur + '.', true);
  addJournalEntry('Achat de ' + ajoute + ' sels d\'ammoniaque à l\'usine pharmaceutique.', 'event-info');
}

// §22 : 1 PA + 1 sels. Reussite 100 %. Restaure la capacite a voter et CONSERVE l'intention
// precedente (elle n'a jamais ete effacee : l'etat 'endormi' vit sur le siege, l'intention sur la
// ligne de session -- deux tables distinctes, precisement pour cela).
async function ouvrirReveillerDepute(pa, cost) {
  await rafraichirAssemblee();
  const occ = assembleeOccupation();
  if (!occ) { assembleeIndisponible(); return; }

  const endormis = occ.filter(o => o.estPnj && o.endormi);
  let html = '<div style="padding:1rem">';
  if (!endormis.length) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun député ne dort actuellement. L\'hémicycle est étonnamment vigilant.</div>';
  } else if (assembleeNbSels() <= 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Vous n\'avez aucun sel d\'ammoniaque. L\'usine pharmaceutique en vend.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">1 PA + 1 flacon par réveil. Vous en avez ' + assembleeNbSels() + '.</div>';
    endormis.forEach(o => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.55rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<span style="font-size:.85rem;color:#c0b090">' + o.pnjNom + '</span>';
      html += '<button onclick="confirmerReveillerDepute(\'' + o.siegeId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.3rem .8rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Réveiller</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Réveiller un député';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerReveillerDepute(siegeId) {
  if (typeof sbAssembleeReveillerDepute !== 'function') { assembleeIndisponible(); return; }
  const siege = assembleeSiegeParId(siegeId);
  if (!siege) { showToast('Introuvable', ASSEMBLEE_RAISONS.siege_introuvable, false); return; }

  // Controles d'affichage uniquement : le serveur revalide les quatre conditions sous verrou (siege
  // PNJ, endormi, 1 PA, 1 flacon) et consomme PA et flacon DANS la transaction du reveil. Un depute
  // deja reveille par quelqu'un d'autre est refuse SANS COUT : deux appels simultanes ne brulent
  // jamais deux flacons pour un seul reveil.
  await rafraichirAssemblee();
  const occ = assembleeOccupationSiege(siegeId);
  if (!occ || !occ.estPnj) { showToast('Sans objet', 'Ce siège n\'est pas tenu par un député PNJ.', false); return; }
  if (!occ.endormi)        { showToast('Déjà réveillé', siege.nom + ' est parfaitement éveillé.', false); return; }
  if (assembleeNbSels() <= 0) { showToast('Sels manquants', ASSEMBLEE_RAISONS.sels_manquants, false); return; }

  const r = await assembleeActionServeur(rq => sbAssembleeReveillerDepute(state.char?.name, siegeId, rq));
  if (!assembleeIssueAction(r, 'Le réveil n\'a pas pu être enregistré. Votre PA et votre flacon sont intacts.')) {
    if (r.res && r.res.raison === 'deja_eveille') await rafraichirAssemblee();
    return;
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Député réveillé',
    'Vous avez réussi à réveiller le député ' + siege.nom + '. Il se redresse brusquement et s\'écrie : « Hein ? Où suis-je ? Ah oui… j\'allais voter ! »',
    true, true);
  addJournalEntry('Réveil du député ' + siege.nom + ' aux sels d\'ammoniaque.', 'event-good');

  await rafraichirAssemblee();
  updateUI();
}


// =====================
// REGISTRE OFFICIEL DE L'ASSEMBLEE (§31)
// =====================
// Source institutionnelle de reference des lois actives. Distingue quatre etats : en vigueur,
// rejetees, abrogees, et projets en cours (un projet RENVOYE reste un projet, jamais une loi).

const ASSEMBLEE_LIBELLES_STATUT = {
  debat:    'En débat',
  session:  'En session',
  renvoyee: 'Renvoyée à la prochaine session',
  adoptee:  'En vigueur',
  rejetee:  'Rejetée',
  abrogee:  'Abrogée',
  retiree:  'Retirée par son auteur'
};

async function ouvrirRegistreAssemblee() {
  if (typeof sbGetAssembleeRegistre !== 'function') { assembleeIndisponible(); return; }
  const lignes = await sbGetAssembleeRegistre(state.country || 'republic').catch(() => null);
  if (!lignes) { assembleeIndisponible(); return; }

  const groupes = [
    ['adoptee',  'LOIS EN VIGUEUR',        '#4a8a4a'],
    ['abrogee',  'LOIS ABROGÉES',          '#8a6a20'],
    ['rejetee',  'PROJETS REJETÉS',        '#8a3a2a'],
    ['session',  'EN SESSION',             '#C9A84C'],
    ['renvoyee', 'RENVOYÉS',               '#6a6a8a'],
    ['debat',    'EN DÉBAT',               '#8a8060'],
    ['retiree',  'RETIRÉS',                '#5a5030']
  ];

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.9rem">Registre officiel de l\'Assemblée nationale. Conservation permanente.</div>';

  let vide = true;
  groupes.forEach(([statut, titre, col]) => {
    const lot = lignes.filter(l => l.statut === statut);
    if (!lot.length) return;
    vide = false;
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.12em;color:' + col + ';margin:.7rem 0 .35rem">' + titre + ' (' + lot.length + ')</div>';
    lot.forEach(l => {
      const marque = l.type === 'mecanique'
        ? ' <span style="color:#cc8866">[' + (CATEGORIES_INTERDICTION[l.categorie]?.label || l.categorie) + ']</span>'
        : (l.type === 'abrogation' ? ' <span style="color:#8a6a20">[abrogation]</span>' : '');
      html += '<div onclick="ouvrirDetailProposition(\'' + l.id + '\')" style="padding:.55rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + l.titre + marque + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">' + l.auteur + '</div>';
      html += '</div>';
    });
  });
  if (vide) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Le registre est vide. Aucun projet n\'a encore été déposé.</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Registre de l\'Assemblée';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Fiche complete d'un projet : texte original, amendements chronologiques, et l'historique
// NOMINATIF de chaque scrutin (§28). Un projet renvoye plusieurs fois affiche autant de scrutins.
async function ouvrirDetailProposition(propId) {
  if (typeof sbGetAssembleeProposition !== 'function') { assembleeIndisponible(); return; }
  const [p, scrutins] = await Promise.all([
    sbGetAssembleeProposition(propId).catch(() => null),
    sbGetAssembleeScrutins(propId).catch(() => [])
  ]);
  if (!p) { assembleeIndisponible(); return; }

  const listeNoms = (arr) => {
    const a = Array.isArray(arr) ? arr : [];
    return a.length ? a.join(', ') : '—';
  };

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.15rem">' + (ASSEMBLEE_LIBELLES_STATUT[p.statut] || p.statut) + '</div>';
  html += '<div style="font-family:Playfair Display,serif;font-size:1rem;color:#E8C97A;margin-bottom:.2rem">' + p.titre + '</div>';
  html += '<div style="font-size:.74rem;color:#6a5a30;margin-bottom:.7rem">Déposé par ' + p.auteur + ' le ' + assembleeFormaterEcheance(p.depose_ts) + '</div>';

  if (p.type === 'mecanique') {
    const cat = CATEGORIES_INTERDICTION[p.categorie];
    const contenu = assembleeContenuCategorie(p.categorie);
    html += '<div style="padding:.55rem;border:1px solid #6a2010;background:#1a0a05;margin-bottom:.7rem;font-size:.76rem;color:#cc8866">';
    html += 'Loi d\'interdiction mécanique · catégorie <strong>' + (cat ? cat.label : p.categorie) + '</strong>';
    if (contenu.length) html += '<br/>Concerne : ' + contenu.join(' · ');
    html += '</div>';
  } else if (p.type === 'abrogation') {
    html += '<div style="font-size:.76rem;color:#8a6a20;margin-bottom:.7rem">Proposition d\'abrogation.</div>';
  } else {
    html += '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.7rem">Loi déclarative (RP) — aucun effet mécanique automatique.</div>';
  }

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">TEXTE ORIGINAL</div>';
  html += '<div style="white-space:pre-wrap;font-family:Crimson Pro,serif;font-size:.84rem;color:#c0b090;padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.7rem">' + (p.texte_original || '') + '</div>';

  const amds = Array.isArray(p.amendements) ? p.amendements : [];
  if (amds.length) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">AMENDEMENTS</div>';
    amds.forEach(a => {
      html += '<div style="padding:.55rem;border-left:2px solid #8a6a20;background:#0d0b05;margin-bottom:.35rem">';
      html += '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.2rem">Amendement n°' + a.num + ' — ' + assembleeFormaterEcheance(a.ts) + '</div>';
      html += '<div style="white-space:pre-wrap;font-family:Crimson Pro,serif;font-size:.82rem;color:#c0b090">' + a.texte + '</div>';
      html += '</div>';
    });
    html += '<div style="font-size:.72rem;color:#6a5a30;font-style:italic;margin-bottom:.7rem">Le dernier amendement valable avant l\'ouverture de la session constitue le texte soumis au vote.</div>';
  }

  if (scrutins && scrutins.length) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.6rem 0 .3rem">SCRUTINS</div>';
    scrutins.forEach(s => {
      const col = s.resultat === 'ADOPTEE' ? '#4a8a4a' : s.resultat === 'REJETEE' ? '#8a3a2a' : '#6a6a8a';
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-size:.8rem;color:' + col + ';font-family:Bebas Neue,sans-serif;letter-spacing:.08em">Session ' + s.session_num + ' — ' + s.resultat + ' (' + s.score_pour + ' / ' + s.score_contre + ')</div>';
      html += '<div style="font-size:.7rem;color:#5a4030;margin-bottom:.3rem">' + assembleeFormaterEcheance(s.cloture_ts) + '</div>';
      html += '<div style="font-size:.73rem;color:#4a8a4a">POUR : ' + listeNoms(s.pour) + '</div>';
      html += '<div style="font-size:.73rem;color:#8a3a2a">CONTRE : ' + listeNoms(s.contre) + '</div>';
      html += '<div style="font-size:.73rem;color:#6a6040">ABSTENTION : ' + listeNoms(s.abstention) + '</div>';
      html += '<div style="font-size:.73rem;color:#8a6a20">N\'A PAS VOTÉ : ' + listeNoms(s.non_votants) + '</div>';
      html += '<div style="font-size:.73rem;color:#6a5a8a">ENDORMIS : ' + listeNoms(s.endormis) + '</div>';
      html += '</div>';
    });
  }

  html += '</div>';
  document.getElementById('postes-modal-title').textContent = p.titre;
  document.getElementById('postes-body').innerHTML = html;
}


// =====================
// INDEMNITE PARLEMENTAIRE (§47, §48, §49)
// =====================
// 250 FR/jour, deputes PJ UNIQUEMENT (les PNJ ne touchent rien), preleves sur la caisse de
// l'Assemblee. Cumulable avec le salaire d'un autre poste : un ministre-depute touche les deux.
//
// §48 : le versement est lie a l'ordre DORMIR. Pas de cron, pas de rattrapage, pas de dette --
// un depute qui ne dort pas perd l'indemnite du jour.
//
// §49 : paiement partiel si la caisse ne suit pas, jamais de dette ni de caisse negative.
//
// La garde anti-doublon et le plafonnement vivent cote SERVEUR (assemblee_verser_indemnite) :
// l'audit du 9 septembre a montre que plusieurs plafonds quotidiens du projet, poses en memoire,
// etaient contournables au rafraichissement. Celui-ci ne l'est pas.
//
// state.posteDepute n'est JAMAIS lu ici (§48) : c'est le serveur qui verifie l'occupation reelle
// d'un siege. Rien ne dependrait donc d'un 'depute' present dans state.poste, qui n'y est jamais.
async function verserIndemniteParlementaire() {
  if (typeof sbAssembleeVerserIndemnite !== 'function') return;
  if (!state.char?.name) return;
  if ((state.country || 'republic') !== 'republic') return;

  // Montant FIXE et credit cote serveur (liquide + arg) : le client recopie le solde renvoye, il
  // ne credite plus rien lui-meme (option A, 11 septembre 2026).
  const r = await assembleeActionServeur(() => sbAssembleeVerserIndemnite(state.char.name));
  const res = r.res;
  if (!res || !res.ok) return;   // pas depute, deja verse, ou RPC absente : silencieux

  const montant = res.montant || 0;
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';

  if (montant > 0) {
    const partiel = montant < (res.vise || 250);
    showToast('Indemnité parlementaire',
      '+' + montant + ' ' + cur + (partiel ? ' (caisse de l\'Assemblée insuffisante pour le montant complet)' : '') + '.',
      true);
    addJournalEntry('Indemnité parlementaire perçue : ' + montant + ' ' + cur + '.', 'event-good');
  } else {
    showToast('Indemnité impayée', 'La caisse de l\'Assemblée est vide aujourd\'hui.', false);
    addJournalEntry('Aucune indemnité parlementaire : caisse de l\'Assemblée vide.', 'event-bad');
  }
  updateUI();
}
