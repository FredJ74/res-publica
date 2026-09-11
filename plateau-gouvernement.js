// =====================
// PLATEAU-GOUVERNEMENT.JS — PREROGATIVES MINISTERIELLES ET CONSEIL DES MINISTRES (Lot 4.3)
// =====================
// SIMPLIFIER L'ACCES A LA COMPLEXITE, PAS SUPPRIMER LA COMPLEXITE.
//
// Ce fichier ne contient AUCUNE mecanique de jeu nouvelle pour la partie ministerielle : il ne fait
// que regrouper, derriere une fonction politique lisible, des actions qui existaient deja comme
// autant de boutons independants. Chaque sous-action appelle la fonction historique, inchangee.
//
// Le seul moteur reellement nouveau est celui du Conseil des ministres (section 3), et il est PUR :
// aucune ecriture, aucun DOM, aucun reseau. Il est donc testable, et c'est lui qui porte le quorum,
// les mesures d'exception et le report electoral.
//
// ---------------------------------------------------------------------------
// CE QUE L'AUDIT DU 7 SEPTEMBRE 2026 A ETABLI, ET QUI COMMANDE CE FICHIER
// ---------------------------------------------------------------------------
// 1. Le MOTEUR GENERIQUE DES POSTES NOMMES existe et il est solide : POSTES_NOMMES_EXCLUSIFS
//    (data.js), candidatures dans batiments_etat, ouvrirNominerPosteNomme / ouvrirRevoquerPosteNomme
//    / ouvrirGestionCandidatures / getTitulaireActuel. Les regroupements « Gerer ... » ci-dessous ne
//    sont donc que des FACADES : ils n'ajoutent aucune regle de nomination.
//
// 2. TROIS MINISTERES N'AVAIENT PAS D'ECRAN DE CANDIDATURES alors que le cron sanctionne l'autorite
//    passive en DIVISANT SA POPULARITE PAR DEUX au bout de 48 h (api/cron-minuit.js). L'Interieur
//    (chef_douanes) et la Justice (juge) etaient dans ce cas, la Defense et les Finances non. Les
//    facades corrigent l'asymetrie sans toucher au moteur : elles montrent les candidatures qui
//    existaient deja et que ces ministres ne pouvaient voir que dans leurs mails.
//
// 3. IL N'EXISTE AUCUN ORDRE revoquer_commandant dans le jeu. Le Ministre de la Defense pouvait
//    nommer son Commandant sans jamais pouvoir le revoquer, seule asymetrie de ce genre parmi les
//    postes nommes. ouvrirRevoquerPosteNomme('commandant') fonctionne pourtant tel quel : la facade
//    « Gerer le commandement » se contente de l'exposer.
//
// 4. LA SALLE DU CONSEIL EXISTE DEJA, avec orders: [] (data.js) -- une piece decorative. C'est elle
//    qui recoit les trois prerogatives collectives, et non un nouveau lieu.

// ---------------------------------------------------------------------------
// 1. PANNEAU DE FONCTION — LE REMPLACANT DE LA GUERRE DES BOUTONS
// ---------------------------------------------------------------------------
// Un bouton ministeriel = une fonction politique = un panneau qui expose ses sous-actions. On
// reutilise la modale generique deja presente dans la page (modal-postes), celle qui sert deja a
// ouvrirGestionCandidatures et a ouvrirEcranPostes : aucun nouveau conteneur DOM n'est introduit.
//
// Chaque entree porte { label, desc, onclick, indisponible } ; une entree indisponible s'affiche
// grisee AVEC SON MOTIF, plutot que de disparaitre -- une prerogative qu'on ne peut pas exercer
// aujourd'hui reste une prerogative, et la masquer rendrait l'institution moins lisible.
// COUT AFFICHE DANS LE PANNEAU (ajout du 8 septembre 2026, regroupement UX des bureaux).
// Champ OPTIONNEL : les six facades ministerielles existantes ne le renseignent pas et rendent
// donc exactement comme avant. Une entree qui expose un cout doit afficher le MEME que le bouton
// qu'elle remplace, sans quoi le regroupement mentirait au joueur.
function badgeCoutHtml(e) {
  const morceaux = [];
  if (e.pa) morceaux.push(e.pa + ' PA');
  if (e.cout) morceaux.push(e.cout);
  if (morceaux.length === 0) return '';
  return '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;' +
         'color:#8a7a50;margin-top:.25rem">' + morceaux.join(' · ') + '</div>';
}

function panneauFonctionHtml(entrees) {
  let html = '<div style="padding:.5rem 0">';
  (entrees || []).forEach(function (e) {
    if (!e) return;
    const bloque = !!e.indisponible;
    html += '<div style="padding:.7rem 1rem;border-bottom:1px solid #1a1810">';
    html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.8rem">';
    html += '<div style="flex:1">';
    html += '<div style="font-size:.85rem;color:' + (bloque ? '#5a5040' : '#c0b090') + '">' + e.label + '</div>';
    html += badgeCoutHtml(e);
    if (e.desc) {
      html += '<div style="font-size:.75rem;color:#8a8060;margin-top:.2rem">' + e.desc + '</div>';
    }
    if (bloque) {
      html += '<div style="font-size:.72rem;color:#8a6a20;font-style:italic;margin-top:.2rem">' + e.indisponible + '</div>';
    }
    html += '</div>';
    if (!bloque) {
      html += '<button onclick="' + e.onclick + '" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;' +
              'letter-spacing:.06em;padding:.35rem .8rem;border:1px solid #8a6a20;background:transparent;' +
              'color:#C9A84C;cursor:pointer;white-space:nowrap">Ouvrir</button>';
    }
    html += '</div></div>';
  });
  html += '</div>';
  return html;
}

function ouvrirPanneauFonction(titre, entrees, entete) {
  const t = document.getElementById('postes-modal-title');
  const b = document.getElementById('postes-body');
  if (!t || !b) return;
  t.textContent = titre;
  b.innerHTML = (entete || '') + panneauFonctionHtml(entrees);
  document.getElementById('modal-postes').classList.add('open');
}

// Entete commune : qui occupe le poste aujourd'hui. C'est la premiere question qu'on se pose en
// ouvrant un ecran de gestion, et elle etait absente de tous les anciens boutons.
// Lecture tolerante du titulaire d'un poste nomme. En echec on renvoie null, ce qui vaut « poste
// vacant » : la facade s'ouvre quand meme, et chaque handler revalide sa propre condition avant de
// prelever quoi que ce soit. Ne jamais laisser une lecture d'etat fermer un panneau.
async function titulaireOuNull(posteId, city) {
  if (typeof getTitulaireActuel !== 'function') return null;
  try { return await getTitulaireActuel(posteId, city || null); } catch (e) { return null; }
}

async function enteteTitulaire(posteId, city) {
  if (typeof getTitulaireActuel !== 'function') return '';
  let titulaire = null;
  try { titulaire = await getTitulaireActuel(posteId, city || null); } catch (e) { titulaire = null; }
  const regle = (typeof POSTES_NOMMES_EXCLUSIFS !== 'undefined') ? POSTES_NOMMES_EXCLUSIFS[posteId] : null;
  const label = (regle && regle.label) || posteId;
  const qui = titulaire ? (titulaire.nom + (titulaire.estPJ ? '' : ' (PNJ)')) : 'Poste vacant';
  let html = '<div style="padding:.6rem 1rem;font-size:.72rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;' +
             'letter-spacing:.1em;border-bottom:1px solid #1a1810">' + label.toUpperCase() + '</div>';
  html += '<div style="padding:.5rem 1rem;font-size:.85rem;color:#c0b090">Actuellement : ' + qui + '</div>';
  // La protection de 7 jours est une regle existante du moteur : l'annoncer ici evite au ministre
  // d'ouvrir la revocation pour se la voir refuser.
  if (titulaire && titulaire.estPJ && typeof estPosteProtege === 'function' &&
      typeof tempsProtectionRestanteTexte === 'function') {
    try {
      const p = { nommeLe: titulaire.nommeLe };
      if (estPosteProtege(p)) {
        html += '<div style="padding:0 1rem .5rem;font-size:.75rem;color:#8a6a20;font-style:italic">' +
                'Poste protégé — ' + tempsProtectionRestanteTexte(p) + '</div>';
      }
    } catch (e) { /* l'entete ne doit jamais empecher l'ouverture du panneau */ }
  }
  return html;
}

// ---------------------------------------------------------------------------
// 2. FACADES MINISTERIELLES
// ---------------------------------------------------------------------------
// Aucune de ces fonctions ne deduit de PA ni n'ecrit quoi que ce soit : elles orientent. Le cout et
// les gardes restent PORTES PAR LES FONCTIONS HISTORIQUES, exactement comme avant le regroupement.
// C'est la condition pour que le lot soit une refonte d'acces et non une refonte de regles.

// --- INTERIEUR : Gerer le Chef des Douanes -----------------------------------
// Remplace « Nommer un Chef des Douanes » + « Revoquer le Chef des Douanes », et EXPOSE EN PLUS les
// candidatures, qui existaient deja dans le blob mais qu'aucun ecran ne montrait au Ministre de
// l'Interieur -- alors qu'il encourt la sanction de popularite du cron s'il ne repond pas sous 48 h.
async function ouvrirGestionChefDouanes(pa, cost) {
  if (state.poste?.id !== 'min_int') { showToast('Accès refusé', 'Réservé au Ministre de l\'Intérieur.', false); return; }
  const entete = await enteteTitulaire('chef_douanes', null);
  const t = await titulaireOuNull('chef_douanes');
  const entrees = entreesPosteNomme(t, pa || 0, pa || 0,
    'Le poste est déjà pourvu : révoquez le titulaire d\'abord.').map(function (e) {
    const base = { pa: e.pa, indisponible: e.indisponible || null };
    if (e.cle === 'candidatures') {
      return Object.assign(base, { label: 'Candidatures reçues',
               desc: 'Examiner les candidatures déposées pour le poste.',
               onclick: 'ouvrirGestionCandidatures([\'chef_douanes\'],' + (pa || 0) + ',' + (cost || 0) + ')' });
    }
    if (e.cle === 'nommer') {
      return Object.assign(base, { label: 'Nommer', desc: 'Désigner directement un habitant ou un PNJ présent.',
               onclick: 'ouvrirNominerPosteNomme(\'chef_douanes\',' + (pa || 0) + ',' + (cost || 0) + ')' });
    }
    return Object.assign(base, { label: 'Révoquer', desc: 'Retirer le poste au titulaire en fonction.',
             onclick: 'ouvrirRevoquerPosteNomme(\'chef_douanes\',' + (pa || 0) + ',' + (cost || 0) + ')' });
  });
  ouvrirPanneauFonction('Gérer le Chef des Douanes', entrees, entete);
}

// --- JUSTICE : Gerer les juges ----------------------------------------------
// Remplace « Nommer un juge » + « Revoquer un juge ». Meme correction d'asymetrie que pour les
// douanes : le Ministre de la Justice n'avait aucun ecran de candidatures.
async function ouvrirGestionJuges(pa, cost) {
  if (state.poste?.id !== 'min_just') { showToast('Accès refusé', 'Réservé au Ministre de la Justice.', false); return; }
  const entete = await enteteTitulaire('juge', null);
  const t = await titulaireOuNull('juge');
  const entrees = entreesPosteNomme(t, pa || 0, pa || 0,
    'Un magistrat est déjà en fonction : révoquez-le d\'abord.').map(function (e) {
    const base = { pa: e.pa, indisponible: e.indisponible || null };
    if (e.cle === 'candidatures') {
      return Object.assign(base, { label: 'Candidatures reçues',
               desc: 'Examiner les candidatures déposées pour la magistrature.',
               onclick: 'ouvrirGestionCandidatures([\'juge\'],' + (pa || 0) + ',' + (cost || 0) + ')' });
    }
    if (e.cle === 'nommer') {
      return Object.assign(base, { label: 'Nommer un juge', desc: 'Désigner un magistrat.',
               onclick: 'ouvrirNominerPosteNomme(\'juge\',' + (pa || 0) + ',' + (cost || 0) + ')' });
    }
    return Object.assign(base, { label: 'Révoquer le juge', desc: 'Retirer le poste au magistrat en fonction.',
             onclick: 'ouvrirRevoquerPosteNomme(\'juge\',' + (pa || 0) + ',' + (cost || 0) + ')' });
  });
  ouvrirPanneauFonction('Gérer les juges', entrees, entete);
}

// --- DEFENSE : Gerer le commandement -----------------------------------------
// Remplace « Nommer le Commandant » + « Gerer les candidatures au Commandant », et AJOUTE la
// revocation, qui n'existait comme ordre nulle part alors que le moteur la supporte.
//
// La nomination passe desormais par ouvrirNominerPosteNomme, le moteur generique, et non plus par
// envoyerNominationCommandant -- une reimplementation ad-hoc qui perdait l'evenement public, le
// journal et le nettoyage du dossier de candidature. La fonction historique n'est pas supprimee.
// UN SEUL BOUTON, QUI S'ADAPTE (arbitrage du 7 septembre 2026). Le ministre n'a pas trois entrees
// « candidatures / nommer / revoquer » : il a UNE gestion du commandement, et ce qu'elle propose
// depend de l'etat du poste.
//   poste vacant   -> candidatures recues, et nomination d'un candidat eligible
//   poste pourvu   -> revocation
// Nomination comme revocation : 1 PA.
const COUT_PA_NOMINATION_COMMANDANT = 1;
const COUT_PA_REVOCATION_COMMANDANT = 1;

// Ce que le panneau doit proposer, calcule a part pour etre testable sans DOM.
// REGLE UX DU 8 SEPTEMBRE 2026 : UNE FACADE SE CONSULTE TOUJOURS.
// Cette fonction MASQUAIT les entrees inapplicables -- poste vacant, on ne voyait pas la
// revocation ; poste pourvu, on ne voyait plus ni la nomination ni les candidatures. Le joueur ne
// pouvait donc pas decouvrir ce que sa fonction contient : le panneau lui montrait un etat, pas
// une competence.
// Les trois entrees sont desormais TOUJOURS rendues ; seule leur disponibilite varie, avec son
// motif. Les candidatures restent consultables meme poste pourvu -- savoir qui a postule est une
// information legitime, et la consulter ne coute rien.
// Forme generique, partagee par les QUATRE facades « candidatures / nommer / revoquer » du
// gouvernement : Premier ministre, Commandant, juges, Chef des douanes. Elles posaient toutes la
// meme question -- le poste est-il pourvu ? -- et aucune n'y repondait a l'ecran.
// `occupe` est le motif a afficher sur « nommer » quand le siege est deja pris ; il varie parce
// qu'un commandement, une magistrature et un ministere ne se disent pas de la meme facon.
function entreesPosteNomme(titulaire, paNommer, paRevoquer, occupe) {
  const pourvu = !!(titulaire && (typeof titulaire === 'string' ? titulaire : titulaire.nom));
  return [
    { cle: 'candidatures', pa: 0 },
    { cle: 'nommer', pa: paNommer || 0,
      indisponible: pourvu ? (occupe || 'Le poste est déjà pourvu : révoquez le titulaire d\'abord.') : null },
    { cle: 'revoquer', pa: paRevoquer || 0,
      indisponible: pourvu ? null : 'Aucun titulaire en fonction.' }
  ];
}

function entreesGestionCommandement(titulaire) {
  return entreesPosteNomme(titulaire, COUT_PA_NOMINATION_COMMANDANT, COUT_PA_REVOCATION_COMMANDANT,
    'Le commandement est déjà pourvu : révoquez le titulaire d\'abord.');
}

async function ouvrirGestionCommandement() {
  if (state.poste?.id !== 'min_def') { showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false); return; }
  const titulaire = await titulaireOuNull('commandant');
  const entete = await enteteTitulaire('commandant', null);
  const entrees = entreesGestionCommandement(titulaire).map(function (e) {
    const base = { pa: e.pa, indisponible: e.indisponible || null };
    if (e.cle === 'revoquer') {
      return Object.assign(base, { label: 'Révoquer le Commandant',
               desc: 'Retirer son commandement au titulaire en fonction.',
               onclick: 'ouvrirRevoquerPosteNomme(\'commandant\',' + COUT_PA_REVOCATION_COMMANDANT + ',0)' });
    }
    if (e.cle === 'candidatures') {
      return Object.assign(base, { label: 'Candidatures reçues',
               desc: 'Examiner les candidatures déposées pour le commandement.',
               onclick: 'ouvrirGestionCandidatures([\'commandant\'],' + COUT_PA_NOMINATION_COMMANDANT + ',0)' });
    }
    return Object.assign(base, { label: 'Nommer le Commandant',
             desc: 'Désigner un candidat éligible.',
             onclick: 'ouvrirNominerPosteNomme(\'commandant\',' + COUT_PA_NOMINATION_COMMANDANT + ',0)' });
  });
  ouvrirPanneauFonction('Gérer le commandement', entrees, entete);
}

// --- FINANCES : Fiscalite et budget ------------------------------------------
// Trois boutons pour une seule fonction de pilotage financier : le taux national, le redressement et
// la repartition. Aucune regle, aucun cout, aucun historique ne change -- seul le chemin change.
function ouvrirPilotageFiscalBudgetaire(pa, cost) {
  if (state.poste?.id !== 'min_fin') { showToast('Accès refusé', 'Réservé au Ministre des Finances.', false); return; }
  // Le panneau s'ouvre TOUJOURS : le ministre doit pouvoir consulter sa fonction, meme quand aucune
  // action n'est immediatement executable. Aucune de ces trois entrees n'a d'ailleurs de condition
  // de disponibilite au-dela du poste -- verifie : leurs handlers ne controlent que min_fin. Les
  // couts sont ceux transmis par l'ordre ; la repartition budgetaire preleve 1 PA a la validation,
  // arbitrage du 7 septembre 2026 (validerRepartitionBudget), et non a l'ouverture.
  ouvrirPanneauFonction('Fiscalité et budget', [
    { label: 'Taux d\'imposition national', pa: pa || 0, desc: 'Fixer le taux prélevé sur l\'ensemble du pays.',
      onclick: 'ouvrirFixerImpotNational(' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Répartition budgétaire', pa: 1, desc: 'Répartir le budget national entre les institutions. Le coût est prélevé à la validation de la répartition.',
      onclick: 'ouvrirGestionBudget()' },
    { label: 'Ordonner un redressement', pa: pa || 0, desc: 'Redressement fiscal contre un citoyen, un club, une entreprise ou une organisation.',
      onclick: 'ouvrirChoixTypeCibleFiscale(\'redressement_fiscal\',\'Redressement fiscal contre\')' }
  ]);
}

// --- FINANCES : Gestion industrielle et portuaire ----------------------------
// Regroupe les directeurs d'usine, le virement vers une usine et le Commandant du Port. Ce sont
// quatre boutons pour une seule fonction : la tutelle de l'Etat sur ses etablissements.
//
// L'audit a confirme que la SUBVENTION et la PREEMPTION ne sont PAS la meme chose -- don d'argent
// d'un cote, nationalisation financee par emprunt de l'autre, aucun code partage hormis les
// primitives de caisse. Elles restent donc deux prerogatives distinctes et ne sont pas absorbees ici.
async function ouvrirGestionIndustriellePortuaire(pa, cost) {
  if (state.poste?.id !== 'min_fin') { showToast('Accès refusé', 'Réservé au Ministre des Finances.', false); return; }
  const entete = await enteteTitulaire('capitaine_port', null);
  ouvrirPanneauFonction('Gestion industrielle et portuaire', [
    { label: 'Candidatures de directeurs', desc: 'Candidatures aux directions des trois usines nationales.',
      onclick: 'ouvrirGestionCandidatures([\'directeur_pharma\',\'directeur_tabac_alcools\',\'directeur_raffinerie\'],' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Virement vers une usine', desc: 'Verser des fonds du ministère à une usine nationale.',
      onclick: 'doOuvrirVirementMinistereUsine(' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Nommer le Commandant du Port', desc: 'Désigner le Commandant du Port.',
      onclick: 'ouvrirNominerPosteNomme(\'capitaine_port\',' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Révoquer le Commandant du Port', desc: 'Retirer le poste au titulaire en fonction.',
      onclick: 'ouvrirRevoquerPosteNomme(\'capitaine_port\',' + (pa || 0) + ',' + (cost || 0) + ')' }
  ], entete);
}

// --- AFFAIRES ETRANGERES : Ambassades et ambassadeurs ------------------------
// Quatre boutons regroupes. L'audit a etabli qu'ambassadeur N'EST PAS un poste de
// POSTES_NOMMES_EXCLUSIFS : il vit dans ambassades_ouvertes.data.ambassadeur, sans candidatures, et
// la nomination ne peut viser qu'un contact du repertoire du ministre. Ce lot ne change pas cette
// mecanique -- il la rassemble. L'absence de candidatures est donc SIGNALEE, pas comblee en douce.
function ouvrirGestionAmbassades(pa, cost) {
  if (state.poste?.id !== 'min_ae') { showToast('Accès refusé', 'Réservé au Ministre des Affaires Étrangères.', false); return; }
  ouvrirPanneauFonction('Ambassades et ambassadeurs', [
    { label: 'Ouvrir une ambassade', desc: 'Établir une représentation diplomatique auprès d\'un empire.',
      onclick: 'ouvrirModalEmpireCible(\'ouvrir_ambassade\',\'Ouvrir une ambassade a\',' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Nommer un ambassadeur', desc: 'Désigner un contact de votre répertoire comme ambassadeur.',
      onclick: 'ouvrirModalNommerAmbassadeur(' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Démettre un ambassadeur', desc: 'Mettre fin à la mission de votre propre ambassadeur.',
      onclick: 'ouvrirModalDemettreAmbassadeur(' + (pa || 0) + ',' + (cost || 0) + ')' },
    { label: 'Expulser un ambassadeur étranger', desc: 'Déclarer persona non grata un ambassadeur présent sur le territoire.',
      onclick: 'ouvrirModalExpulserAmbassadeur(' + (pa || 0) + ',' + (cost || 0) + ')' }
  ],
  '<div style="padding:.6rem 1rem;font-size:.75rem;color:#8a6a20;font-style:italic;border-bottom:1px solid #1a1810">' +
  'Le poste d\'ambassadeur ne passe pas par le système de candidatures : il se nomme depuis votre répertoire de contacts.' +
  '</div>');
}

// ===========================================================================
// 3. CONSEIL DES MINISTRES — MOTEUR PUR
// ===========================================================================
// CONTRAT : pur. Aucune ecriture, aucun DOM, aucun reseau, aucune lecture de state. Tout entre par
// les parametres, tout sort par la valeur de retour. C'est ce qui rend le quorum, l'expiration des
// mesures et l'unicite du report electoral reellement testables.
//
// ---------------------------------------------------------------------------
// CE QUE L'AUDIT A ETABLI, ET QUI COMMANDE CETTE SECTION
// ---------------------------------------------------------------------------
// LE MOT « QUORUM » N'APPARAIT NULLE PART DANS LE DEPOT. Il n'existe ni Conseil des ministres, ni
// deliberation collective, ni seance, ni convocation. La Salle du Conseil existe (data.js,
// salle_conseil) mais avec orders: [] -- c'est un decor. Ce moteur est donc entierement nouveau.
//
// IL N'EST POURTANT PAS SANS PRECEDENT, et on ne reinvente rien :
//   - COLLEGE FIGE + SEUIL QUALIFIE : greves_generales fige la liste des syndicats eligibles au
//     lancement et exige 2/3 du COLLEGE (pas des votants). Meme doctrine ici : le college est fige a
//     la convocation, et le quorum se calcule sur lui.
//   - BULLETINS NOMINATIFS A ECHEANCE : votes_confiance porte { bulletins jsonb, cloture_ts }.
//     Meme forme ici.
//   - DRAPEAU « DEJA UTILISE UNE FOIS », auto-reinitialise : cycle.dissolutionUtilisee, pose
//     fail-closed avant toute autre operation. C'est exactement le patron du report electoral.
//
// PARTICIPATION PLUTOT QUE PRESENCE. Le jeu sait dire qui est dans une piece depuis moins de
// 5 minutes (table presences) et qui s'est connecte recemment (personnages.updated_at). Mais exiger
// une presence simultanee dans la Salle du Conseil rendrait toute decision impossible dans un jeu
// asynchrone. Le quorum porte donc sur la PARTICIPATION AU SCRUTIN -- un ministre qui a voté est
// present au Conseil -- ce qui est aussi la seule donnee que le serveur peut constater sans mentir.

// Les sept membres du Conseil. Derives du catalogue existant, jamais recopies : si un ministere est
// ajoute ou retire de POSTES_NOMMES_EXCLUSIFS, le college suit sans qu'une ligne bouge ici.
function collegeConseil() {
  if (typeof POSTES_NOMMES_EXCLUSIFS === 'undefined') return [];
  return Object.keys(POSTES_NOMMES_EXCLUSIFS)
    .filter(function (id) { return id === 'pm' || id.indexOf('min_') === 0; });
}

const QUORUM_CONSEIL_PCT = 60;
// L'EFFORT DE GUERRE N'EST PLUS UNE DECISION DU CONSEIL (arbitrage du 7 septembre 2026) : c'est une
// prerogative personnelle du President, chef des armees. Voir section 6. Les sanctions restent une
// prerogative du Conseil dans le design, mais ne sont pas exposees tant qu'elles n'ont rien a
// atteindre -- aucun effet placebo n'est fabrique.
const DECISIONS_CONSEIL = ['restriction_libertes', 'prolongation'];
// SEUL LE PREMIER MINISTRE LANCE LA PROCEDURE : il en endosse la responsabilite politique.
const INITIATEUR_CONSEIL = 'pm';
const DUREE_MESURES_EXCEPTION_MS = 3 * 24 * 60 * 60 * 1000;   // 3 jours REELS
const PROLONGATIONS_MAX = 2;                                   // au-dela : aucune troisieme
const DUREE_MAX_EXCEPTION_MS = 9 * 24 * 60 * 60 * 1000;        // 3 + 3 + 3, plafond absolu
const REPORT_ELECTORAL_MS = 7 * 24 * 60 * 60 * 1000;          // 7 jours REELS

// Sieges REELLEMENT pourvus. Un poste vacant ne compte pas dans le college : sinon un gouvernement
// incomplet serait mecaniquement incapable d'atteindre son propre quorum, ce qui reviendrait a
// punir le Conseil pour une vacance qu'il ne maitrise pas.
function collegeEffectif(titulaires) {
  const t = titulaires || {};
  return collegeConseil().filter(function (id) {
    const v = t[id];
    return !!(v && (typeof v === 'string' ? v : v.nom));
  });
}

function seuilQuorum(tailleCollege) {
  const n = Math.max(0, Math.floor(Number(tailleCollege) || 0));
  return n === 0 ? 0 : Math.ceil(n * QUORUM_CONSEIL_PCT / 100);
}

// Un bulletin = { posteId: 'pour' | 'contre' | 'abstention' }.
//
// DEUX DENOMINATEURS DISTINCTS, et c'est tout le sujet :
//   - le QUORUM se calcule sur les PARTICIPANTS. Une abstention EST une participation : le ministre
//     a siege, il a pris part a la deliberation, il a simplement refuse de trancher.
//   - la MAJORITE se calcule sur les SUFFRAGES EXPRIMES. Les abstentions en sont exclues.
// Confondre les deux reviendrait soit a permettre au Conseil de decider a quelques-uns, soit a
// transformer chaque abstention en opposition.
//
// VOIX PREPONDERANTE DU PREMIER MINISTRE en cas d'egalite des exprimes : il a lance la procedure et
// il en repond, il tranche donc son propre partage. Une abstention du PM ne departage rien -- il
// faut avoir vote pour departager.
function depouillerConseil(seance) {
  const s = seance || {};
  const college = Array.isArray(s.college) ? s.college : [];
  const bulletins = s.bulletins || {};
  const seuil = seuilQuorum(college.length);

  let pour = 0, contre = 0, abstentions = 0, participants = 0;
  college.forEach(function (id) {
    const b = bulletins[id];
    if (b === 'pour') { pour++; participants++; }
    else if (b === 'contre') { contre++; participants++; }
    else if (b === 'abstention') { abstentions++; participants++; }
  });
  const exprimes = pour + contre;

  const quorumAtteint = college.length > 0 && participants >= seuil;
  const voixPm = bulletins[INITIATEUR_CONSEIL];
  const departageParPm = (pour === contre) && exprimes > 0 &&
                         (voixPm === 'pour' || voixPm === 'contre');
  let adoptee;
  if (!quorumAtteint || exprimes === 0) adoptee = false;
  else if (pour !== contre) adoptee = pour > contre;
  else adoptee = departageParPm && voixPm === 'pour';

  return {
    college: college.length, participants: participants, exprimes: exprimes,
    pour: pour, contre: contre, abstentions: abstentions,
    seuil: seuil, quorumAtteint: quorumAtteint, departageParPm: departageParPm,
    // La decision n'est acquise QUE si le quorum est atteint. Une majorite obtenue sans quorum
    // n'est pas une decision : c'est une reunion de couloir.
    adoptee: adoptee
  };
}

function verdictConvocationConseil(decision, titulaires, demandeurPosteId) {
  if (DECISIONS_CONSEIL.indexOf(decision) === -1) return { ok: false, raison: 'decision_inconnue' };
  const college = collegeEffectif(titulaires);
  if (college.length === 0) return { ok: false, raison: 'aucun_ministre_en_fonction' };
  // L'INITIATIVE APPARTIENT AU SEUL PREMIER MINISTRE. Un ministre ne convoque pas le Conseil pour
  // restreindre les libertes : c'est le chef du gouvernement qui engage sa responsabilite.
  if (demandeurPosteId !== INITIATEUR_CONSEIL) return { ok: false, raison: 'initiative_reservee_au_pm' };
  if (college.indexOf(demandeurPosteId) === -1) return { ok: false, raison: 'pas_membre_du_conseil' };
  return { ok: true, raison: null,
           seance: { decision: decision, college: college, bulletins: {},
                     seuil: seuilQuorum(college.length), statut: 'ouverte' } };
}

function verdictVoteConseil(seance, posteId, choix) {
  const s = seance || {};
  if (s.statut !== 'ouverte') return { ok: false, raison: 'seance_close' };
  if ((s.college || []).indexOf(posteId) === -1) return { ok: false, raison: 'pas_membre_du_conseil' };
  if (choix !== 'pour' && choix !== 'contre' && choix !== 'abstention') {
    return { ok: false, raison: 'choix_invalide' };
  }
  // Un ministre ne revote pas : le bulletin depose est definitif, comme dans votes_confiance.
  if (s.bulletins && Object.prototype.hasOwnProperty.call(s.bulletins, posteId)) {
    return { ok: false, raison: 'deja_vote' };
  }
  return { ok: true, raison: null };
}

// ---------------------------------------------------------------------------
// 3 bis. REGROUPEMENTS UX DES BUREAUX (8 septembre 2026)
// ---------------------------------------------------------------------------
// REMONTEE TERRAIN : le bureau presidentiel et celui de l'Interieur presentaient chaque ordre
// comme un bouton independant -- douze d'un cote, six de l'autre -- alors que plusieurs
// appartiennent manifestement a la meme famille.
//
// CE QUI CHANGE : l'organisation des entrees, rien d'autre. Chaque sous-entree appelle le handler
// EXISTANT, avec le cout PA d'ORIGINE de l'ordre qu'elle remplace, code en dur ici. Aucune
// mecanique, aucune condition, aucun effet n'est touche.
//
// POURQUOI CES COUTS SONT SURS. Verifie fonction par fonction avant d'ecrire une ligne : de tous
// les ordres regroupes, un seul preleve ses PA a l'OUVERTURE (doDissoudreAssemblee, qui n'a pas
// d'etape de confirmation separee) -- il recoit donc bien ses 4 PA ci-dessous. Tous les autres
// prelevent a la CONFIRMATION, en propageant le pa qu'on leur passe. Une entree de regroupement
// qui aurait oublie de transmettre le cout aurait rendu l'ordre gratuit : c'est le piege de ce
// chantier, et il est ferme par ces valeurs explicites.
//
// Chaque facade REVALIDE le poste, comme les six facades ministerielles existantes : un panneau ne
// doit jamais devenir un chemin d'acces plus permissif que le bouton qu'il remplace.

// ---- BUREAU PRESIDENTIEL ----

// nommer_ministre (2 PA) + revoquer_pm (1 PA). Meme poste, meme mecanique de poste nomme : c'est
// la facade jumelle de ouvrirGestionChefDouanes, appliquee au Premier ministre. Elle expose en
// prime l'ecran de candidatures, qui existait deja sans qu'aucun bouton presidentiel n'y mene.
async function ouvrirGestionPremierMinistre() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Seul le Président peut gérer le Premier ministre.', false); return;
  }
  const entete = await enteteTitulaire('pm', null);
  const t = await titulaireOuNull('pm');
  const entrees = entreesPosteNomme(t, 2, 1,
    'Un Premier ministre est déjà en fonction : révoquez-le d\'abord.').map(function (e) {
    const base = { pa: e.pa, indisponible: e.indisponible || null };
    if (e.cle === 'candidatures') {
      return Object.assign(base, { label: 'Candidatures reçues',
               desc: 'Examiner les candidatures déposées pour le poste.',
               onclick: "ouvrirGestionCandidatures(['pm'],2,0)" });
    }
    if (e.cle === 'nommer') {
      return Object.assign(base, { label: 'Nommer', desc: 'Désigner un habitant ou un PNJ présent.',
               onclick: "ouvrirNominerPosteNomme('pm',2,0)" });
    }
    return Object.assign(base, { label: 'Révoquer', desc: 'Retirer le poste au titulaire en fonction.',
             onclick: "ouvrirRevoquerPosteNomme('pm',1,0)" });
  });
  ouvrirPanneauFonction('Le Premier ministre', entrees, entete);
}

// creer_poste_ministre (3 PA) + creer_comite (3 PA) + supprimer_poste_custom (0 PA).
// Les trois pilotent le MEME objet state.postesCustom {ministre, comite} : c'est une seule famille.
// La limite d'un poste et d'un comite s'apprenait jusqu'ici par un toast APRES le clic ; elle est
// desormais lisible avant, l'etat etant deja disponible en memoire.
function ouvrirPostesParDecret() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Seul le Président peut créer un poste par décret.', false); return;
  }
  const custom = state.postesCustom || {};
  const rien = !custom.ministre && !custom.comite;
  ouvrirPanneauFonction('Postes et comités créés par décret', [
    { label: 'Créer un poste ministériel', pa: 3, desc: 'Un ministère supplémentaire, salarié, occupable par un autre joueur.',
      onclick: 'creerPosteMinistre(3,0)',
      indisponible: custom.ministre ? 'Un poste ministériel a déjà été créé : supprimez-le d\'abord.' : null },
    { label: 'Créer un comité', pa: 3, desc: 'Une instance consultative, sur le même principe.',
      onclick: 'creerComite(3,0)',
      indisponible: custom.comite ? 'Un comité a déjà été créé : supprimez-le d\'abord.' : null },
    { label: 'Supprimer un poste créé', desc: 'Dissoudre le poste ou le comité créé par décret.',
      onclick: 'supprimerPosteCustom()',
      indisponible: rien ? 'Aucun poste ni comité créé par décret.' : null }
  ]);
}

// etat_urgence (3 PA) + declarer_guerre (5 PA) + dissoudre_assemblee (4 PA).
// Trois moteurs distincts et non fusionnables -- sbSetEtatUrgence, sbCreerGuerre, CYCLES_ELECTORAUX --
// mais une meme nature : des actes qui engagent l'Etat au-dela de la gestion ordinaire, et dont on
// ne revient pas d'un clic. Ils restent trois entrees ; ils cessent d'etre trois boutons.
function ouvrirPouvoirsExceptionnels() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Réservé au Président.', false); return;
  }
  ouvrirPanneauFonction('Pouvoirs exceptionnels', [
    { label: 'État d\'urgence', pa: 3, desc: 'Déclarer ou lever l\'état d\'urgence.',
      onclick: 'doEtatUrgence(3,0)' },
    { label: 'Déclarer la guerre', pa: 5, desc: 'Ouvrir un conflit avec un empire étranger. Visible de tous, y compris de l\'empire visé.',
      onclick: 'ouvrirModalGuerreEmpire(5,0)' },
    { label: 'Dissoudre l\'Assemblée', pa: 4, desc: 'Mettre fin au mandat des députés et convoquer de nouvelles législatives.',
      onclick: 'doDissoudreAssemblee(4,0)' }
  ]);
}

// decret_referendum (3 PA) + jour_deuil (1 PA). Ce ne sont pas seulement deux actes voisins :
// c'est LITTERALEMENT le meme appel, ouvrirForumNationalSousForumPresident(type, pa, cost), au
// parametre `type` pres, et les deux publient dans le meme sous-forum presidentiel.
// « Signer un décret » emprunte le meme canal mais reste volontairement un bouton distinct, dans
// l'attente de l'arbitrage demande a son sujet.
function ouvrirAdresseALaNation() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Réservé au Président.', false); return;
  }
  ouvrirPanneauFonction('S\'adresser à la Nation', [
    { label: 'Ordonner un référendum', pa: 3, desc: 'Soumettre une question au pays. Publié sur le forum présidentiel.',
      onclick: "ouvrirForumNationalSousForumPresident('referendum',3,0)" },
    { label: 'Décret de deuil national', pa: 1, desc: 'Décréter un deuil national.',
      onclick: "ouvrirForumNationalSousForumPresident('deuil',1,0)" },
    // Rejoint la facade apres arbitrage du 8 septembre 2026 : sa mecanique a ete tracee de bout en
    // bout et elle est reelle -- decret redige par l'IA, effets POP/INF persistes sur le
    // personnage, et surtout publication d'un vrai sujet dans le MEME sous-forum presidentiel que
    // le referendum et le deuil. Meme canal, donc meme famille. Cout inchange : 1 PA.
    { label: 'Signer un décret', pa: 1, desc: 'Un décret rédigé pour vous, publié sur le forum présidentiel. Effets sur la popularité et l\'influence.',
      onclick: 'signerDecretInutile(1,0)' }
  ]);
}

// ---- BUREAU DU MINISTRE DE L'INTERIEUR ----

// traiter_manifestations (1 PA) + interdire_manif (2 PA) + reprimer_manif (3 PA).
// Une seule famille : le traitement des manifestations, de l'autorisation prealable a la
// dispersion. Les trois handlers restent strictement separes -- aucune logique metier fusionnee.
// L'impossibilite de reprimer quand un syndicat de police est en greve etait un toast d'echec
// APRES le clic ; elle devient une indisponibilite lisible, lue sur le meme etat que le handler.
function ouvrirGestionManifestations() {
  if (state.poste?.id !== 'min_int') {
    showToast('Accès refusé', 'Réservé au Ministre de l\'Intérieur.', false); return;
  }
  const pays = state.country || 'republic';
  const policeEnGreve = (typeof syndicatPoliceEnGreve === 'function') && syndicatPoliceEnGreve(pays);
  ouvrirPanneauFonction('Gérer les manifestations', [
    { label: 'Traiter les demandes', pa: 1, desc: 'Autoriser ou refuser les demandes de manifestation déposées.',
      onclick: 'doTraiterManifestations(1,0)' },
    { label: 'Interdire une manifestation', pa: 2, desc: 'Interdire un rassemblement déjà autorisé ou annoncé.',
      onclick: 'ouvrirInterdireManif(2,0)' },
    { label: 'Réprimer une manifestation', pa: 3, desc: 'Ordonner la dispersion par les forces de l\'ordre.',
      onclick: 'ouvrirReprimerManif(3,0)',
      indisponible: policeEnGreve
        ? 'Un syndicat de policiers est en grève : la répression est impossible tant qu\'il n\'y met pas fin.'
        : null }
  ]);
}

// ---- BUREAU DU MINISTRE DE LA DEFENSE ----
// AUDIT PREALABLE (8 septembre 2026). Le regroupement demande portait sur quatre ordres :
// Mobiliser / Demobiliser / Cessez-le-feu / Requisition civile. Trois seulement forment une chaine.
//
// CE QUI LES RELIE REELLEMENT : un unique drapeau persiste, budgetNat.mobilisationNationaleActive.
//   mobiliser_armee     l'ecrit a true   (plateau-politique.js:8698)
//   demobiliser         l'ecrit a false  (plateau-politique.js:9615)
//   requisition_civile  en depend        (plateau-politique.js:9841, refus si absent)
// C'est un cycle de vie, pas une ressemblance de vocabulaire : ouvrir, exploiter, refermer.
//
// CE QUI N'EN FAIT PAS PARTIE : « Activer un cessez-le-feu » travaille sur guerres.data.ceasefire,
// une autre table et un autre objet -- une treve bilaterale par guerre, pas l'etat mobilise du pays.
// Il reste un ordre autonome. (Son etat reel est rapporte separement : la branche qui ecrirait
// ceasefire.accepteePar n'a aucun appelant, l'ordre ne peut donc rien lister aujourd'hui. C'est un
// constat de mecanique, hors du perimetre de cette passe UX -- rien n'est corrige ici.)
//
// COUTS : d'origine, codes en dur. Les trois prelevent a la CONFIRMATION -- confirmerMobilisation
// et confirmerRequisitionCivile recoivent le pa qu'on leur propage ; doDemobiliser code ses 2 PA
// en interne et ignore ce qu'on lui passe. Aucun ne preleve a l'ouverture : la facade est sure.
const COUT_PA_MOBILISER = 4;
const COUT_PA_DEMOBILISER = 2;
const COUT_PA_REQUISITION = 3;

// REGLE UX DU 8 SEPTEMBRE 2026 : UNE FACADE SE CONSULTE TOUJOURS.
// Les trois entrees sont rendues quel que soit l'etat ; seule leur disponibilite varie.
//
// « Mobiliser » N'EST JAMAIS BLOQUEE, y compris mobilisation deja active : doMobiliserArmee ne
// porte aucune garde de ce type, remobiliser est une nouvelle feuille de route pour le Commandant.
// Inventer ici un « deja en cours » AJOUTERAIT une condition au jeu -- ce que cette passe s'interdit.
function entreesMobilisationNationale(mobilisee) {
  const active = !!mobilisee;
  return [
    { cle: 'mobiliser', pa: COUT_PA_MOBILISER },
    { cle: 'requisition', pa: COUT_PA_REQUISITION,
      indisponible: active ? null : 'Uniquement pendant une mobilisation nationale.' },
    { cle: 'demobiliser', pa: COUT_PA_DEMOBILISER,
      indisponible: active ? null : 'Aucune mobilisation nationale en cours.' }
  ];
}

async function ouvrirMobilisationNationale() {
  if (state.poste?.id !== 'min_def') { showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false); return; }
  // LECTURE STRICTE, VOLONTAIREMENT PAS chargerBudgetNational : celle-ci CREE la ligne de budget
  // national quand elle n'existe pas encore (plateau-justice-economie.js:10910, sbSaveBudgetNational).
  // Ouvrir un panneau pour le consulter ne doit rien ecrire. Pas de ligne = pas de mobilisation.
  // Si la lecture echoue, on ouvre quand meme : la facade se consulte toujours, et les handlers
  // reverifient chacun leur propre condition avant de prelever quoi que ce soit.
  let mobilisee = false;
  if (typeof sbGetBudgetNational === 'function') {
    const b = await sbGetBudgetNational(state.country || 'republic').catch(() => null);
    mobilisee = !!(b && b.mobilisationNationaleActive);
  }
  const entete = '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">'
    + (mobilisee ? 'Mobilisation nationale EN COURS.' : 'Aucune mobilisation nationale en cours.')
    + '</div>';
  const entrees = entreesMobilisationNationale(mobilisee).map(function (e) {
    const base = { pa: e.pa, indisponible: e.indisponible || null };
    if (e.cle === 'mobiliser') {
      return Object.assign(base, { label: 'Mobiliser l\'armée',
               desc: 'Choisir une destination et donner une feuille de route secrète au Commandant.',
               onclick: 'doMobiliserArmee(' + COUT_PA_MOBILISER + ',0)' });
    }
    if (e.cle === 'requisition') {
      return Object.assign(base, { label: 'Réquisition civile',
               desc: 'Tirage au sort de 24 citoyens pour doubler l\'effectif d\'une section.',
               onclick: 'ouvrirRequisitionCivile(' + COUT_PA_REQUISITION + ',0)' });
    }
    return Object.assign(base, { label: 'Démobiliser',
             desc: 'Lever la mobilisation. Les réquisitions cessent et l\'immunité militaire prend fin.',
             onclick: 'doDemobiliser()' });
  });
  ouvrirPanneauFonction('Mobilisation nationale', entrees, entete);
}

// ---- BUREAU DU MINISTRE DES AFFAIRES ETRANGERES ----
// AUDIT PREALABLE (8 septembre 2026). Question posee : « Signer un traite » partage-t-il une chaine
// reelle avec « Ouvrir des negociations » et « Repondre aux propositions » ? OUI.
//
// LA CHAINE COMMUNE est la table propositions_diplomatiques, et le passage oblige proposerDiplomatie
// (plateau-politique.js:5647), qui les parametre par un meme DIPLOMATIE_CONFIG :
//   accord_diplomatique   -> proposerDiplomatie('negociation', ...)  INSERT statut 'en_attente'
//   signer_traite         -> proposerTraite -> proposerDiplomatie('traite', ...)  meme INSERT
//   reponses_diplomatiques-> repondreDiplomatie   SELECT en_attente, UPDATE acceptee|refusee
//
// MAIS LA FORME N'EST PAS CELLE QUE LES LIBELLES SUGGERENT, et cela ne se corrige pas ici :
// ce ne sont pas trois etapes successives mais DEUX EMETTEURS ET UN REPONDEUR. Une negociation
// aboutie ne conditionne aucun traite ulterieur -- on peut « signer » avec un empire avec qui on
// n'a jamais rien negocie. Et « Signer un traite » ne signe pas : il PROPOSE ; la signature reelle
// est faite en face, par « Repondre aux propositions ». Le regroupement rend cette parente visible ;
// il ne prétend pas la corriger, et ne touche ni aux couts ni aux effets.
//
// N'EN FONT PAS PARTIE : « Proposer une treve » (table guerres, colonne ceasefire) et
// « Ambassades et ambassadeurs » (table ambassades_ouvertes, deja une facade). Ils restent autonomes.
//
// COUTS d'origine. Les trois prelevent a la CONFIRMATION, en propageant le pa recu.
const COUT_PA_NEGOCIATION = 2;
const COUT_PA_TRAITE = 3;
const COUT_PA_REPONSE_DIPLO = 1;

// REGLE UX : les trois entrees sont toujours rendues et toujours ouvrables.
// « Repondre aux propositions » n'est deliberement PAS marquee indisponible quand la corbeille est
// vide : ouvrir la liste ne coute rien (le PA part a la reponse), et constater qu'on n'a rien recu
// est precisement l'usage de cet ordre. La bloquer reviendrait a interdire de consulter.
function ouvrirDiplomatieBilaterale() {
  if (state.poste?.id !== 'min_ae') { showToast('Accès refusé', 'Réservé au Ministre des Affaires Étrangères.', false); return; }
  ouvrirPanneauFonction('Diplomatie bilatérale', [
    { label: 'Ouvrir des négociations diplomatiques', pa: COUT_PA_NEGOCIATION,
      desc: 'Établir un canal diplomatique avec un empire étranger.',
      onclick: 'ouvrirModalNegociationDiplomatique(' + COUT_PA_NEGOCIATION + ',0)' },
    { label: 'Signer un traité', pa: COUT_PA_TRAITE,
      desc: 'Proposer un accord bilatéral. Il n\'entre en vigueur qu\'une fois accepté en face.',
      onclick: 'ouvrirModalTraite(' + COUT_PA_TRAITE + ',0)' },
    { label: 'Répondre aux propositions', pa: COUT_PA_REPONSE_DIPLO,
      desc: 'Consulter et répondre aux propositions reçues (traités, négociations).',
      onclick: 'ouvrirReponsesDiplomatiques(' + COUT_PA_REPONSE_DIPLO + ',0)' }
  ]);
}

// ---------------------------------------------------------------------------
// 4. MESURES D'EXCEPTION
// ---------------------------------------------------------------------------
// 3 JOURS REELS, AUCUN RENOUVELLEMENT AUTOMATIQUE. L'expiration est une DATE ABSOLUE : la mesure est
// morte quand l'heure est passee, que quelqu'un se connecte ou non. C'est la lecon du couvre-feu
// existant, dont l'audit a montre qu'il ne s'eteint que si un joueur non exempte entre dans un
// batiment -- et dont la degradation quotidienne continue donc indefiniment si personne ne joue.
// LA DISSOLUTION D'ASSOCIATION N'EN FAIT PAS PARTIE (correction du 7 septembre 2026) : elle releve
// de la gestion ORDINAIRE du Ministre de l'Interieur, pas d'un regime d'exception. Voir section 8.
const MESURES_EXCEPTION = ['manifestations_interdites', 'greve_suspendue', 'arrestations_arbitraires',
                           'couvre_feu_general'];

function mesuresActives(regime, maintenantMs) {
  const r = regime || {};
  const t = Number(maintenantMs) || 0;
  if (!r.actif) return [];
  const fin = echeanceEffective(r);
  if (!(fin !== null && fin > t)) return [];
  return (r.mesures || []).filter(function (m) { return MESURES_EXCEPTION.indexOf(m) !== -1; });
}

function mesureActive(regime, mesure, maintenantMs) {
  return mesuresActives(regime, maintenantMs).indexOf(mesure) !== -1;
}

function ouvrirRegimeException(mesures, maintenantMs) {
  const t = Number(maintenantMs) || 0;
  const retenues = (mesures || []).filter(function (m) { return MESURES_EXCEPTION.indexOf(m) !== -1; });
  // debutA est l'ancre du PLAFOND ABSOLU de 9 jours : il ne bouge jamais, meme prolonge. Sans ancre
  // fixe, deux prolongations decalees repousseraient indefiniment la limite qu'elles sont censees
  // respecter.
  return { actif: true, mesures: retenues, debutA: t, expireA: t + DUREE_MESURES_EXCEPTION_MS,
           prolongations: 0, plafondA: t + DUREE_MAX_EXCEPTION_MS };
}

// L'ECHEANCE EFFECTIVE est le MINIMUM de l'echeance courante et du plafond absolu. Une mesure ne
// peut donc jamais survivre au 9e jour, quelle que soit la suite des prolongations -- y compris si
// un regime anterieur a ce plafond est relu depuis la base.
function echeanceEffective(regime) {
  const r = regime || {};
  const e = Number(r.expireA);
  const p = Number(r.plafondA);
  if (!isFinite(e)) return null;
  return isFinite(p) ? Math.min(e, p) : e;
}

// PROLONGER, C'EST DECIDER A NOUVEAU. La prolongation n'est pas un bouton : c'est une seance
// complete, avec le meme college et le meme quorum. Sans cela, un Conseil ayant atteint le quorum
// une fois pourrait maintenir un regime d'exception indefiniment sans jamais le reunir a nouveau.
function verdictProlongation(regime, seance, maintenantMs) {
  const r = regime || {};
  const t = Number(maintenantMs) || 0;
  // DEUX PROLONGATIONS AU MAXIMUM, verifiees AVANT le depouillement : une troisieme deliberation
  // n'a pas a etre organisee puisqu'elle ne peut rien produire. Fail-closed, comme le drapeau de
  // dissolution electorale.
  const deja = Math.max(0, Math.floor(Number(r.prolongations) || 0));
  if (deja >= PROLONGATIONS_MAX) {
    return { ok: false, raison: 'prolongations_epuisees', maximum: PROLONGATIONS_MAX };
  }
  const d = depouillerConseil(seance);
  if (!d.quorumAtteint) return { ok: false, raison: 'quorum_non_atteint', depouillement: d };
  if (!d.adoptee) return { ok: false, raison: 'prolongation_rejetee', depouillement: d };
  // « Prolonger les mesures TELLES QUELLES » : la liste des mesures n'est pas rouverte a la
  // negociation, seule l'echeance repart. Changer les mesures suppose une decision distincte.
  const ancre = isFinite(Number(r.debutA)) ? Number(r.debutA) : t;
  const plafond = isFinite(Number(r.plafondA)) ? Number(r.plafondA) : ancre + DUREE_MAX_EXCEPTION_MS;
  return { ok: true, raison: null,
           regime: { actif: true, mesures: (r.mesures || []).slice(),
                     debutA: ancre,
                     // La prolongation repart pour 3 jours, mais jamais au-dela du 9e jour.
                     expireA: Math.min(t + DUREE_MESURES_EXCEPTION_MS, plafond),
                     plafondA: plafond,
                     prolongations: deja + 1 },
           depouillement: d };
}

// ---------------------------------------------------------------------------
// 5. REPORT D'UNE ECHEANCE ELECTORALE
// ---------------------------------------------------------------------------
// 7 JOURS, UNE SEULE FOIS PAR ECHEANCE. L'audit a montre que cycles_electoraux.id identifie un
// POSTE, pas un scrutin : il est reecrit a chaque nouveau cycle. La cle durable retenue par le
// projet est cycle.dateDebutCandidatures, deja utilisee telle quelle comme cycle_debut dans
// fraudes_electorales. On l'emploie ici, et le drapeau vit sur le cycle lui-meme -- donc un nouveau
// cycle repart naturellement a zero, sans purge.
//
// FAIL-CLOSED : le drapeau est teste AVANT toute autre condition, comme dissolutionUtilisee.
//
// POUR LE FUTUR PUTSCH, ET RIEN DE PLUS : la trace conserve qui a reporte, quand, et depuis quelle
// echeance. Aucune consequence militaire n'est calculee ici -- ce lot ne code pas le putsch.
function cleEcheanceElectorale(cycle) {
  const c = cycle || {};
  const d = Number(c.dateDebutCandidatures);
  return isFinite(d) && d > 0 ? d : null;
}

// PORTEE DU REPORT — seules les elections NATIONALES sont reportables.
//
// Les trois listes sont explicites et disjointes, et le moteur refuse tout ce qui n'est pas
// formellement national. 'maire' est municipal : il ne peut JAMAIS etre reporte par cette
// mecanique, c'est une regle figee.
//
// ARBITRE LE 7 SEPTEMBRE 2026 : la presidentielle ET les legislatives sont reportables. Le depute
// est elu par circonscription (scope 'ville' dans POSTES_ELECTIFS) mais siege a l'Assemblee
// nationale : c'est bien une election nationale. Restent exclues les municipales et les elections
// internes aux organisations et syndicats -- l'Etat ne reporte pas le scrutin d'un syndicat.
const ELECTIONS_NATIONALES_REPORTABLES = ['president', 'depute'];
const ELECTIONS_MUNICIPALES = ['maire'];
const ELECTIONS_INTERNES_ORGANISATION = ['chef_syndicat'];

function verdictPorteeReport(posteId) {
  if (ELECTIONS_NATIONALES_REPORTABLES.indexOf(posteId) !== -1) return { ok: true, raison: null };
  if (ELECTIONS_MUNICIPALES.indexOf(posteId) !== -1) return { ok: false, raison: 'election_municipale' };
  if (ELECTIONS_INTERNES_ORGANISATION.indexOf(posteId) !== -1) {
    return { ok: false, raison: 'election_interne_organisation' };
  }
  return { ok: false, raison: 'poste_inconnu' };
}

function verdictReportElection(cycle, regime, maintenantMs, auteur) {
  const c = cycle || {};
  const t = Number(maintenantMs) || 0;

  if (c.reportUtilise) return { ok: false, raison: 'report_deja_utilise' };

  const portee = verdictPorteeReport(c.posteId);
  if (!portee.ok) return { ok: false, raison: portee.raison };

  const cle = cleEcheanceElectorale(c);
  if (cle === null) return { ok: false, raison: 'echeance_non_identifiable' };

  // Le report est une mesure d'exception : hors regime actif, il n'existe pas.
  if (!mesuresActives(regime, t).length) return { ok: false, raison: 'hors_regime_exception' };

  const dateVote = Number(c.dateVote);
  if (!isFinite(dateVote) || dateVote <= 0) return { ok: false, raison: 'scrutin_sans_date' };
  if (dateVote <= t) return { ok: false, raison: 'scrutin_deja_tenu' };

  // Calendrier du dimanche (12 septembre 2026) : le report decale d'une semaine CALENDAIRE a Paris
  // (le vote reste un dimanche 00:01 meme a travers un changement d'heure), plus de 7 x 24 h brutes.
  const decale = function (v) {
    const n = Number(v);
    if (!(isFinite(n) && n > 0)) return v;
    return typeof decalerSemainesParis === 'function' ? decalerSemainesParis(n, 1) : n + REPORT_ELECTORAL_MS;
  };
  return { ok: true, raison: null,
           cycle: Object.assign({}, c, {
             dateDebutCampagne: decale(c.dateDebutCampagne),
             dateVote: decale(c.dateVote),
             dateResultats: decale(c.dateResultats),
             // dateDebutCandidatures n'est JAMAIS decalee : c'est la cle d'identite du scrutin.
             reportUtilise: true,
             // TRACE HISTORIQUE DURABLE : auteur, date de la decision, echeance d'origine et
             // nouvelle date. C'est le materiau qu'une future mecanique de putsch ou de crise
             // institutionnelle exploitera -- rien de tel n'est calcule ici.
             reportTrace: { par: auteur || null, leTs: t, echeance: cle, posteId: c.posteId || null,
                            ancienneDateVote: dateVote, nouvelleDateVote: decale(dateVote),
                            dureeMs: REPORT_ELECTORAL_MS }
           }) };
}

// ---------------------------------------------------------------------------
// 6. EFFORT DE GUERRE — PREROGATIVE PERSONNELLE DU PRESIDENT
// ---------------------------------------------------------------------------
// CE N'EST PLUS UNE DECISION DU CONSEIL (arbitrage du 7 septembre 2026). Le President le declenche
// en sa qualite de chef des armees : sans vote, meme en temps de paix, meme contre l'avis du
// Premier ministre. Il n'a AUCUNE duree maximale et ne prend fin que par une seconde decision
// presidentielle explicite -- il ne s'eteint donc jamais tout seul, contrairement aux mesures
// d'exception du Conseil.
//
// C'est une asymetrie voulue : les libertes publiques sont rendues au bout de 9 jours au plus,
// l'effort de guerre non.
const AUTORITE_EFFORT_DE_GUERRE = 'president';

function verdictDeclencherEffortDeGuerre(posteId, effortActuel) {
  if (posteId !== AUTORITE_EFFORT_DE_GUERRE) return { ok: false, raison: 'reserve_au_president' };
  if (effortDeGuerreActif(effortActuel)) return { ok: false, raison: 'deja_actif' };
  return { ok: true, raison: null };
}

function verdictTerminerEffortDeGuerre(posteId, effortActuel) {
  if (posteId !== AUTORITE_EFFORT_DE_GUERRE) return { ok: false, raison: 'reserve_au_president' };
  if (!effortDeGuerreActif(effortActuel)) return { ok: false, raison: 'pas_actif' };
  return { ok: true, raison: null };
}

// Aucune echeance : l'absence de champ d'expiration est le fait mecanique qui traduit « sans duree
// maximale ». On ne pose pas une echeance lointaine, qui serait une duree maximale deguisee.
function ouvrirEffortDeGuerre(auteur, maintenantMs) {
  return { actif: true, debutA: Number(maintenantMs) || 0, par: auteur || null, finA: null };
}

function fermerEffortDeGuerre(effort, auteur, maintenantMs) {
  const e = effort || {};
  return { actif: false, debutA: e.debutA || null, par: e.par || null,
           finA: Number(maintenantMs) || 0, terminePar: auteur || null };
}

function effortDeGuerreActif(effort) {
  return !!(effort && effort.actif === true);
}

// ---------------------------------------------------------------------------
// 7. CONSEQUENCES ECONOMIQUES DE L'EFFORT DE GUERRE
// ---------------------------------------------------------------------------
// DEUX CONSEQUENCES, ET DEUX SEULEMENT. La mobilisation industrielle est un chantier economique
// dedie : aucun circuit production -> armureries -> casernes n'est fabrique ici, aucun quota
// artificiel, aucune ressource fictive. Les deux points d'accroche ci-dessous sont concus pour
// qu'un futur chantier s'y raccorde sans avoir a defaire quoi que ce soit.

// (1) BUDGET : le plafond de la Defense saute. Voir section 8, parametre 'effortDeGuerre'.

// (2) VENTES LEGALES D'ARMES AUX PARTICULIERS : bloquees. Les armes vont en priorite aux casernes.
// Predicat pur, a interposer devant confirmerAchatArme -- il ne touche NI au stock, NI au prix, NI
// a la production : seule la vente au particulier est refusee. Le marche noir n'est pas concerne,
// c'est precisement ce qui rend la mesure interessante.
function verdictVenteLegaleArme(effort) {
  if (effortDeGuerreActif(effort)) {
    return { ok: false, raison: 'effort_de_guerre_ventes_suspendues' };
  }
  return { ok: true, raison: null };
}

// POINT D'ACCROCHE POUR LE FUTUR CHANTIER ECONOMIQUE. Rend l'etat de mobilisation sous une forme
// stable que la mobilisation industrielle pourra lire, sans qu'aucun flux n'existe aujourd'hui.
// Volontairement descriptif : il ne CALCULE rien et n'oriente aucune matiere.
function contexteMobilisation(effort) {
  return {
    effortDeGuerre: effortDeGuerreActif(effort),
    ventesParticuliersSuspendues: effortDeGuerreActif(effort),
    plafondDefenseLeve: effortDeGuerreActif(effort),
    // Non implemente : le circuit matieres -> armureries -> casernes n'existe pas.
    mobilisationIndustrielle: false
  };
}

// ---------------------------------------------------------------------------
// 8. BORNES DU BUDGET NATIONAL
// ---------------------------------------------------------------------------
// L'audit a etabli que ces bornes N'EXISTAIENT PAS : le seul garde-fou etait un attribut HTML
// max="50", jamais revalide a la soumission -- un min_def a 98 % passait si le total faisait 100.
// Elles sont donc creees ici, en logique pure, testable, et opposable cote appelant.
//
//   plancher      5 % pour chaque institution
//   plafond       20 % pour la Defense en temps normal
//   total         exactement 100 %
//
// ARBITRE LE 7 SEPTEMBRE 2026 : pendant l'effort de guerre, le plafond de la Defense saute ET les
// autres ministeres peuvent descendre sous leur plancher de 5 %. Le total reste a 100 % : l'effort
// de guerre redistribue, il ne cree pas d'argent. Hors effort, plancher et plafond s'appliquent.
const BUDGET_PLANCHER_PCT = 5;
const BUDGET_PLAFOND_DEFENSE_PCT = 20;
const BUDGET_TOTAL_PCT = 100;
const POSTE_BUDGET_DEFENSE = 'min_def';
const EFFORT_DE_GUERRE_LEVE_LES_PLANCHERS = true;

// A QUI LE PLANCHER S'APPLIQUE-T-IL. La regle dit « chaque MINISTERE », et la repartition livree
// tranche la question a elle seule : elle place 'reserve' a 2 %, donc sous 5 %. Appliquer le
// plancher a toutes les lignes rendrait invalide la repartition par defaut du jeu, ce qui ne peut
// pas etre l'intention. Le plancher porte donc sur les MEMBRES DU CONSEIL -- Premier ministre et
// ministres -- derives du meme catalogue que le college, jamais recopies.
//
// ⚠ A CONFIRMER : 'presidence', 'assemblee', 'tribunal', 'commissariat', 'mairie' et 'reserve' ne
// sont pas des ministeres et ne sont donc pas planchees par cette lecture. Si le plancher devait
// aussi les couvrir, c'est cette seule fonction qui changerait.
function estPosteMinisteriel(posteBudget) {
  return collegeConseil().indexOf(posteBudget) !== -1;
}

function bornesBudget(posteBudget, effortDeGuerre) {
  const guerre = !!effortDeGuerre;
  const plancherApplicable = estPosteMinisteriel(posteBudget);
  const plancher = (!plancherApplicable || (guerre && EFFORT_DE_GUERRE_LEVE_LES_PLANCHERS))
                   ? 0 : BUDGET_PLANCHER_PCT;
  let plafond = BUDGET_TOTAL_PCT;
  if (posteBudget === POSTE_BUDGET_DEFENSE && !guerre) plafond = BUDGET_PLAFOND_DEFENSE_PCT;
  return { plancher: plancher, plafond: plafond };
}

// Verdict complet d'une repartition. Rend TOUTES les violations, pas seulement la premiere : un
// ministre qui corrige son tableau a besoin de voir d'un coup ce qui cloche.
function verdictRepartitionBudget(repartition, effortDeGuerre) {
  const rep = repartition || {};
  const cles = Object.keys(rep);
  if (cles.length === 0) return { ok: false, raison: 'repartition_vide', violations: [] };

  const violations = [];
  let total = 0;
  cles.forEach(function (k) {
    const v = Number(rep[k]);
    if (!isFinite(v) || Math.floor(v) !== v || v < 0) {
      violations.push({ poste: k, motif: 'valeur_invalide', valeur: rep[k] });
      return;
    }
    total += v;
    const b = bornesBudget(k, effortDeGuerre);
    if (v < b.plancher) violations.push({ poste: k, motif: 'sous_le_plancher', valeur: v, plancher: b.plancher });
    if (v > b.plafond) violations.push({ poste: k, motif: 'au_dessus_du_plafond', valeur: v, plafond: b.plafond });
  });

  if (total !== BUDGET_TOTAL_PCT) {
    violations.push({ poste: null, motif: 'total_incorrect', valeur: total, attendu: BUDGET_TOTAL_PCT });
  }

  return { ok: violations.length === 0, raison: violations.length ? violations[0].motif : null,
           violations: violations, total: total };
}

// ---------------------------------------------------------------------------
// 9. EFFETS DU REGIME D'EXCEPTION SUR L'ORDRE PUBLIC
// ---------------------------------------------------------------------------
// Predicats purs, a interposer devant les moteurs existants. Ils ne suppriment rien et n'ecrivent
// rien : ils REFUSENT, ou signalent qu'une interruption est due.

// --- MANIFESTATIONS ---------------------------------------------------------
// Aucune nouvelle manifestation pendant le regime, et celles en cours sont interrompues
// IMMEDIATEMENT. L'interruption est definitive : rien ne reprend a la levee du regime.
//
// A brancher devant confirmerDemandeManifestation (depot) et sur les demandes deja 'autorisee'.
function verdictNouvelleManifestation(regime, maintenantMs) {
  if (mesureActive(regime, 'manifestations_interdites', maintenantMs)) {
    return { ok: false, raison: 'manifestations_interdites' };
  }
  return { ok: true, raison: null };
}

// Rend le SORT a appliquer a une manifestation existante. 'interrompue' est un etat terminal :
// il n'existe volontairement aucune transition qui en sorte.
function sortManifestationSousRegime(demande, regime, maintenantMs) {
  const d = demande || {};
  if (!mesureActive(regime, 'manifestations_interdites', maintenantMs)) {
    return { interrompre: false, statut: d.statut || null };
  }
  if (d.statut === 'interrompue') return { interrompre: false, statut: 'interrompue' };
  return { interrompre: true, statut: 'interrompue', cause: 'restriction_libertes',
           reprendAutomatiquement: false };
}

// --- GREVES -----------------------------------------------------------------
// Meme doctrine. La greve en cours est interrompue et ne repart pas : le syndicat devra la relancer
// explicitement, ce qui est une decision politique et non un retour a l'etat anterieur.
function verdictNouvelleGreve(regime, maintenantMs) {
  if (mesureActive(regime, 'greve_suspendue', maintenantMs)) {
    return { ok: false, raison: 'droit_de_greve_suspendu' };
  }
  return { ok: true, raison: null };
}

function sortGreveSousRegime(greve, regime, maintenantMs) {
  const g = greve || {};
  if (!mesureActive(regime, 'greve_suspendue', maintenantMs)) {
    return { interrompre: false, actif: g.actif === true };
  }
  if (g.actif !== true) return { interrompre: false, actif: false };
  return { interrompre: true, actif: false, cause: 'restriction_libertes',
           reprendAutomatiquement: false };
}

// --- GARDE A VUE ARBITRAIRE -------------------------------------------------
// LA PREROGATIVE TRANSITE PAR LE MINISTRE DE LA JUSTICE, pas par l'Interieur. L'ordre redescend de
// facon CONCOMITANTE vers les juges et les commissariats : ce sont deux destinataires du meme acte,
// pas deux etapes successives.
//
// CE N'EST PAS UNE CONDAMNATION. Aucune ligne de 'jugements' n'est creee, aucun statut de recherche
// n'est pose. Mais la detention est REELLE, donc elle est inscrite au registre : l'audit a etabli
// que 'detentions' trace les detentions EXECUTEES et non les condamnations prononcees -- et que
// l'arrestation d'etat d'urgence existante contourne ce registre, ce qui la rend invisible aux
// archives de police. On ne reproduit pas ce defaut.
const GAV_EXCEPTION_HEURES = 24;
const DESTINATAIRES_ORDRE_GAV = ['juge', 'commissaire'];

function verdictGardeAVueArbitraire(posteId, regime, cible, maintenantMs) {
  if (!mesureActive(regime, 'arrestations_arbitraires', maintenantMs)) {
    return { ok: false, raison: 'hors_regime_exception' };
  }
  if (posteId !== 'min_just') return { ok: false, raison: 'reserve_au_ministre_de_la_justice' };
  const nom = (typeof cible === 'string') ? cible.trim() : '';
  if (!nom) return { ok: false, raison: 'cible_requise' };
  return { ok: true, raison: null, dureeHeures: GAV_EXCEPTION_HEURES,
           destinataires: DESTINATAIRES_ORDRE_GAV.slice() };
}

// Ligne de registre. 'source' distingue cette mesure de tout le reste, et 'autorite' nomme le
// ministre : la trace doit permettre de dire que c'etait une detention exceptionnelle ordonnee dans
// le cadre des restrictions des libertes, et par qui.
function ligneRegistreGardeAVue(cible, auteurNom, country, city, jour, maintenantMs) {
  const t = Number(maintenantMs) || 0;
  return {
    country: country || null, city: city || null, nom: cible || null,
    raison: 'garde_a_vue_exceptionnelle',
    jour_debut: jour, jour_fin: jour,
    qhs: false,
    issue_judiciaire: null,          // AUCUNE condamnation
    autorite: auteurNom ? ('Ministre de la Justice — ' + auteurNom) : 'Ministre de la Justice',
    motifs: [{ type: 'garde_a_vue_exceptionnelle', source: 'restriction_libertes',
               jours: 1, dureeHeures: GAV_EXCEPTION_HEURES, city: city || null,
               jour_fait: jour, date_evenement: t,
               detail: 'Mesure administrative d\'exception — restrictions des libertés publiques' }]
  };
}

// --- COUVRE-FEU GENERAL -----------------------------------------------------
// Reutilise le moteur existant : 20h-6h, 45 % de risque a l'entree d'un batiment, aucun blocage
// physique du deplacement. Ce sont les valeurs deja en vigueur, pas de nouvelles.
//
// SEULE CHANGE SA DUREE : elle suit desormais celle du regime (3 jours, jusqu'a 9 prolonge) au lieu
// des 2 jours de jeu du couvre-feu ministeriel. L'audit avait montre que celui-ci ne s'eteint que
// si un joueur non exempte entre dans un batiment ; l'echeance absolue du regime corrige cela.
const COUVRE_FEU_HEURE_DEBUT = 20;
const COUVRE_FEU_HEURE_FIN = 6;
const COUVRE_FEU_RISQUE_ARRESTATION = 0.45;

function couvreFeuGeneralActif(regime, maintenantMs) {
  return mesureActive(regime, 'couvre_feu_general', maintenantMs);
}

function dansPlageCouvreFeu(heure) {
  const h = Number(heure);
  if (!isFinite(h)) return false;
  return h >= COUVRE_FEU_HEURE_DEBUT || h < COUVRE_FEU_HEURE_FIN;
}

function verdictCouvreFeuGeneral(regime, heure, maintenantMs) {
  if (!couvreFeuGeneralActif(regime, maintenantMs)) return { soumis: false, risque: 0 };
  if (!dansPlageCouvreFeu(heure)) return { soumis: false, risque: 0 };
  // Ne bloque PAS le deplacement : il expose a un risque.
  return { soumis: true, risque: COUVRE_FEU_RISQUE_ARRESTATION, bloqueDeplacement: false };
}

// ---------------------------------------------------------------------------
// 10. DISSOLUTION D'ASSOCIATION — ARCHITECTURE SEULE
// ---------------------------------------------------------------------------
// ELLE NE FAIT PAS PARTIE DU REGIME D'EXCEPTION : c'est une prerogative ORDINAIRE du Ministre de
// l'Interieur (correction du 7 septembre 2026).
//
// L'audit a etabli que dissoudreOrga fait aujourd'hui un DELETE dur : caisse perdue, baux orphelins,
// membres jamais prevenus, et seule une ligne de chronique survit. Les principes figes imposent
// l'inverse -- dissolution douce, patrimoine et historique conserves, organisation neutralisee,
// rehabilitation possible.
//
// COUT ET FORME DE L'ACTE (arbitrage du 7 septembre 2026).
//   2 PA, reussite 100 %, aucun jet, aucun cooldown, aucune limite quotidienne hors PA.
//   Motif texte libre OBLIGATOIRE -- un seul mot suffit, mais des espaces seuls ne sont pas un motif.
// Dissolution et rehabilitation obeissent aux MEMES regles : chaque acte est independant, et une
// organisation peut etre redissoute immediatement apres une rehabilitation.
//
// AUCUN CONTROLE SEMANTIQUE DU MOTIF. Un ministre peut invoquer un pretexte mensonger : la sanction
// est politique, elle n'appartient pas au moteur.
// ELIGIBILITE A LA DISSOLUTION (arbitrage du 7 septembre 2026).
// Dissolvables : TOUTES les organisations constituees par les joueurs.
// Exclues      : les organisations SECRETES, et les structures institutionnelles/publiques qui
//                partagent la meme table sans etre des organisations de joueurs.
//
// LE SECRET SE LIT SUR LE TYPE, pas sur l'instance. TYPES_ORGANISATIONS[type].secret est la source
// de verite ; le champ 'visible' de l'instance en derive a la creation mais peut etre bascule par
// le chef d'une organisation criminelle -- s'y fier permettrait de rendre dissolvable une
// organisation secrete simplement en la rendant visible un instant.
function organisationSecrete(orga) {
  const o = orga || {};
  if (typeof TYPES_ORGANISATIONS !== 'undefined' && TYPES_ORGANISATIONS[o.type]) {
    return TYPES_ORGANISATIONS[o.type].secret === true;
  }
  // Type inconnu du catalogue : on ne peut pas etablir qu'elle n'est pas secrete. Fail-closed.
  return true;
}

// STRUCTURE INSTITUTIONNELLE : une ligne de la table qui n'a pas ete constituee par un joueur. Le
// marqueur retenu est l'absence de fondateur reel -- confirmerCreationOrga pose toujours
// 'fondateur' pour une organisation de joueur, tandis que les structures auto-creees par le moteur
// (clubs de supporters par ville, syndicat des dockers) n'en ont pas.
function organisationInstitutionnelle(orga) {
  const o = orga || {};
  if (o.institutionnelle === true) return true;
  const f = (typeof o.fondateur === 'string') ? o.fondateur.trim() : '';
  return f === '';
}

function organisationDissolvable(orga) {
  const o = orga || {};
  if (organisationSecrete(o)) return { ok: false, raison: 'organisation_secrete' };
  if (organisationInstitutionnelle(o)) return { ok: false, raison: 'structure_institutionnelle' };
  return { ok: true, raison: null };
}

const COUT_PA_DISSOLUTION = 2;
const COUT_PA_REHABILITATION = 2;

function motifValide(motif) {
  return typeof motif === 'string' && motif.trim().length > 0;
}

// Etat du bouton pour l'interface : desactive tant que le motif est vide. Fonction pure, pour que
// la regle soit la meme dans l'UI et dans le verdict.
function boutonActeOrganisationActif(motif) {
  return motifValide(motif);
}

function verdictDissolutionAssociation(orga, posteId, motif) {
  if (posteId !== 'min_int') return { ok: false, raison: 'reserve_au_ministre_de_l_interieur' };
  const o = orga || {};
  if (!o.type) return { ok: false, raison: 'organisation_invalide' };
  if (o.dissoute === true) return { ok: false, raison: 'deja_dissoute' };
  if (!organisationDissolvable(o).ok) return organisationDissolvable(o);
  if (!motifValide(motif)) return { ok: false, raison: 'motif_requis' };
  // Le ministre peut dissoudre une organisation dont il est membre ou dirigeant : la trahison fait
  // partie du jeu, aucun garde-fou de conflit d'interets n'est pose.
  return { ok: true, raison: null, pa: COUT_PA_DISSOLUTION, motif: motif.trim() };
}

// NEUTRALISATION, JAMAIS DESTRUCTION. Le patrimoine (caisse) et l'historique restent intacts et
// lisibles ; seuls les DROITS de l'organisation cessent. Les membres sont perdus -- mais la liste
// d'avant dissolution est conservee pour l'histoire, sans etre reactivable automatiquement.
function neutraliserOrganisation(orga, auteurNom, maintenantMs) {
  const o = orga || {};
  return Object.assign({}, o, {
    dissoute: true,
    dissoutePar: auteurNom || null,
    dissouteLe: Number(maintenantMs) || 0,
    membresAvantDissolution: (o.membres || []).slice(),
    membres: [],
    // Droits eteints. Aucun de ces trois champs n'est lu aujourd'hui : ils sont le contrat que le
    // branchement devra respecter.
    peutManifester: false, peutPublierForum: false, peutEnvoyerMails: false
  });
}

// LA REHABILITATION NE REINSCRIT PERSONNE. Une organisation rehabilitee repart sans membres : ceux
// qui veulent y revenir doivent le decider a nouveau. La liste d'avant dissolution reste consultable
// comme trace, elle n'est jamais reinjectee.
function rehabiliterOrganisation(orga, auteurNom, maintenantMs) {
  const o = orga || {};
  return Object.assign({}, o, {
    dissoute: false,
    rehabiliteePar: auteurNom || null,
    rehabiliteeLe: Number(maintenantMs) || 0,
    membres: [],
    peutManifester: true, peutPublierForum: true, peutEnvoyerMails: true
  });
}

function verdictRehabilitation(orga, posteId, motif) {
  if (posteId !== 'min_int') return { ok: false, raison: 'reserve_au_ministre_de_l_interieur' };
  const o = orga || {};
  if (o.dissoute !== true) return { ok: false, raison: 'pas_dissoute' };
  if (!motifValide(motif)) return { ok: false, raison: 'motif_requis' };
  return { ok: true, raison: null, pa: COUT_PA_REHABILITATION, motif: motif.trim() };
}

// ---------------------------------------------------------------------------
// 11. BAREME DE LA REPRESSION D'UNE MANIFESTATION
// ---------------------------------------------------------------------------
// Arbitre le 7 septembre 2026. Miroir pur du calcul reellement applique par confirmerReprimerManif
// (plateau-politique.js) : il sert de table de decision testable, et toute divergence entre les deux
// est un defaut de ce module.
//
// LES DEUX INDICES SONT LOCAUX ET PERSISTES -- indices_villes, cles 'social' et 'isn', ecrites par
// modifierIndiceVille. Le support existe reellement ; l'ancien ISN national (INDICES_NATIONAUX) est
// une constante en memoire jamais persistee, et n'est deliberement pas utilise ici.
const REPRESSION_MANIF = {
  autorisee:  { social: -5, securite: 5 },
  interdite:  { social: -8, securite: 8 }
};

function effetRepressionManifestation(interdictionRecente) {
  const e = interdictionRecente ? REPRESSION_MANIF.interdite : REPRESSION_MANIF.autorisee;
  return { social: e.social, securite: e.securite,
           cleSocial: 'social', cleSecurite: 'isn', portee: 'ville', persiste: true };
}

// ---------------------------------------------------------------------------
// 12. DISSOLUTION — CONTINUITE, SUCCESSION ET LIQUIDATION
// ---------------------------------------------------------------------------
// ⚠ CE QUE L'AUDIT DU 7 SEPTEMBRE 2026 A ETABLI, ET QUI LIMITE CETTE SECTION.
//
// LE ROLE DE TRESORIER N'EXISTE PAS. Une organisation n'a qu'un seul responsable, orga.chef ;
// « president » n'est qu'un libelle d'affichage (titreChefOrga). Le maillon « tresorier » de la
// chaine de succession est donc ecrit et teste, mais restera INERTE tant que le role n'existera
// pas : aucun champ ne le remplit aujourd'hui, et en inventer un reviendrait a creer un role de
// jeu qui n'a pas ete decide.
//
// UNE ORGANISATION N'EST NI LOCATAIRE NI PROPRIETAIRE. locations_actives.locataire est toujours un
// nom de PJ ; orgaId n'y designe qu'une DOMICILIATION. terrains_etat.proprietaire n'est jamais
// ecrit sous la forme 'orga:'. prets.emprunteur est toujours un PJ. Il n'existe donc aujourd'hui
// AUCUN bail, AUCUN pret et AUCUN bien immobilier au nom d'une organisation -- les regles de
// loyers, d'impayes et de liquidation immobiliere n'ont litteralement rien sur quoi s'appliquer.

// Nom encore existant en jeu ? L'appelant fournit le predicat (personnageExisteReellement, async)
// ou une liste de noms vivants : le moteur reste pur.
function premierParOrdreAlphabetique(noms) {
  // Tri deterministe et stable : localeCompare('fr') est deja la convention du projet
  // (plateau-pnj.js, plateau-organisations-quetes.js). Depart d'egalite par comparaison brute pour
  // que deux graphies distinctes ne dependent jamais de l'ordre d'entree.
  const l = (noms || []).filter(function (n) { return typeof n === 'string' && n.trim() !== ''; });
  if (l.length === 0) return null;
  return l.slice().sort(function (a, b) {
    const c = a.localeCompare(b, 'fr', { sensitivity: 'base' });
    return c !== 0 ? c : (a < b ? -1 : (a > b ? 1 : 0));
  })[0];
}

// CHAINE DE SUCCESSION A LA REHABILITATION.
//   1. ancien president encore existant     -> il redevient president
//   2. sinon, ancien tresorier existant     -> il devient president   (INERTE : role inexistant)
//   3. sinon, premier ancien membre A-Z     -> president provisoire
//   4. sinon                                -> orpheline
// Dans TOUS les cas, les autres anciens membres NE SONT PAS reintegres : l'organisation repart
// avec un seul responsable et devra se reconstruire.
function verdictSuccessionRehabilitation(orga, nomsEncoreExistants) {
  const o = orga || {};
  const vivants = {};
  (nomsEncoreExistants || []).forEach(function (n) { if (n) vivants[n] = true; });

  const president = o.chefAvantDissolution || o.chef || null;
  if (president && vivants[president]) {
    return { ok: true, cas: 'president', president: president, provisoire: false };
  }
  const tresorier = o.tresorierAvantDissolution || o.tresorier || null;
  if (tresorier && vivants[tresorier]) {
    return { ok: true, cas: 'tresorier', president: tresorier, provisoire: false };
  }
  const anciens = (o.membresAvantDissolution || [])
    .map(function (m) { return (m && m.nom) ? m.nom : (typeof m === 'string' ? m : null); })
    .filter(function (n) { return n && vivants[n]; });
  const premier = premierParOrdreAlphabetique(anciens);
  if (premier) {
    return { ok: true, cas: 'membre_alphabetique', president: premier, provisoire: true,
             aNotifier: anciens.slice() };
  }
  return { ok: false, cas: 'orpheline', president: null, raison: 'organisation_orpheline' };
}

// LIQUIDATION D'UNE ORGANISATION ORPHELINE — CE QUI EST REELLEMENT FAISABLE.
//
// Tresorerie : elle existe (organisations.data.caisse) et la caisse du ministere des Finances est
// crediteable par crediterCaisseBatiment(pays, 'gouvernement-min_fin', montant). C'est le SEUL
// volet de la liquidation qui ait un support technique reel.
//
// Immobilier et mobilier : voir le rapport. Une organisation ne possede jamais de bien, et le
// mobilier pose dans un local n'existe pas. Ces deux volets ne sont donc PAS implementes -- et ne
// sont pas non plus simules.
const CAISSE_LIQUIDATION_ORPHELINE = 'gouvernement-min_fin';

function verdictLiquidationOrpheline(orga, nomsEncoreExistants) {
  const o = orga || {};
  const succession = verdictSuccessionRehabilitation(o, nomsEncoreExistants);
  if (succession.ok) return { ok: false, raison: 'non_orpheline', cas: succession.cas };
  const montant = Math.max(0, Math.floor(Number(o.caisse) || 0));
  return { ok: true, raison: null,
           tresorerie: { montant: montant, versA: CAISSE_LIQUIDATION_ORPHELINE },
           // Explicitement rendus pour que l'appelant ne les devine pas.
           immobilier: { applicable: false, motif: 'aucune_propriete_organisationnelle' },
           mobilier:   { applicable: false, motif: 'mobilier_pose_inexistant' } };
}

// NOTIFICATIONS. sbSendMail n'a qu'UN destinataire : une notification collective est donc une
// LISTE d'envois, pas un envoi groupe. Ce constructeur rend cette liste sans rien envoyer.
function mailsNotificationActeOrganisation(orga, acte, auteurNom, motif) {
  const o = orga || {};
  const noms = (acte === 'dissolution' ? (o.membres || []) : (o.membresAvantDissolution || []))
    .map(function (m) { return (m && m.nom) ? m.nom : (typeof m === 'string' ? m : null); })
    .filter(Boolean);
  const sujet = acte === 'dissolution'
    ? 'Dissolution de ' + (o.nom || 'votre organisation')
    : 'Réhabilitation de ' + (o.nom || 'votre organisation');
  const corps = (acte === 'dissolution'
    ? 'Le Ministre de l\'Intérieur a prononcé la dissolution de ' + (o.nom || 'votre organisation') + '.'
    : (o.nom || 'Votre organisation') + ' a été réhabilitée par le Ministre de l\'Intérieur.')
    + '\n\nMotif invoqué : ' + (motif || '(non précisé)')
    + '\n\nAutorité : ' + (auteurNom || 'Ministère de l\'Intérieur');
  return noms.map(function (n) {
    return { de: 'Ministère de l\'Intérieur', a: n, sujet: sujet, corps: corps };
  });
}

// Ligne de chronique nationale. 'libelle' est une PHRASE COMPLETE : le collecteur du Journal
// l'utilise telle quelle comme resume, et n'a aucun defaut si on l'omet.
function chroniqueActeOrganisation(orga, acte, auteurNom, motif) {
  const o = orga || {};
  const nom = o.nom || 'Une organisation';
  const libelle = acte === 'dissolution'
    ? nom + ' a été dissoute par le Ministre de l\'Intérieur ' + (auteurNom || '') + '. Motif invoqué : ' + (motif || 'non précisé') + '.'
    : nom + ' a été réhabilitée par le Ministre de l\'Intérieur ' + (auteurNom || '') + '. Motif invoqué : ' + (motif || 'non précisé') + '.';
  return {
    type: acte === 'dissolution' ? 'organisation_dissolution' : 'organisation_rehabilitation',
    options: { city: o.city || null, personnages: auteurNom ? [auteurNom] : [],
               libelle: libelle.replace(/\s+/g, ' ').trim(),
               data: { orgaId: o.id || null, acte: acte, motif: motif || null },
               sourceRef: o.id || null }
  };
}

// TRESORERIE PENDANT LA DISSOLUTION. La caisse continue d'exister et reste CREDITEABLE -- un ancien
// membre peut y verser de l'argent pour preserver le patrimoine. Tout DEBIT libre est en revanche
// refuse : la dissolution n'est pas un gel protecteur, mais elle n'est pas non plus un guichet.
// Les prelevements legitimes deja existants (charges) passent par 'conservatoire'.
const MOUVEMENTS_CAISSE_CONSERVATOIRES = ['loyer', 'echeance_pret', 'charge', 'taxe'];

function verdictMouvementCaisseOrganisationDissoute(orga, sens, nature) {
  const o = orga || {};
  if (o.dissoute !== true) return { ok: true, raison: null };
  if (sens === 'credit') return { ok: true, raison: null };
  if (MOUVEMENTS_CAISSE_CONSERVATOIRES.indexOf(nature) !== -1) return { ok: true, raison: null };
  return { ok: false, raison: 'organisation_dissoute_debit_libre_interdit' };
}

// ---------------------------------------------------------------------------
// 13. LES DEUX COUVRE-FEUX — ETATS SEPARES, EXPIRATIONS INDEPENDANTES
// ---------------------------------------------------------------------------
// Ils coexistent et ne doivent JAMAIS s'ecraser (arbitrage du 7 septembre 2026) :
//
//   ORDINAIRE     prerogative du Ministre de l'Interieur, 2 JOURS DE JEU.
//                 Etat : budgets_nationaux[pays].data.couvreFeu = { actif, jourDebut, jourFin }.
//                 Expire sur state.day, le compteur personnel -- c'est l'existant, inchange.
//
//   EXCEPTIONNEL  mesure du regime de restriction des libertes, 3 JOURS REELS,
//                 jusqu'a 9 avec deux prolongations.
//                 Etat : le regime lui-meme, echeance ABSOLUE en millisecondes.
//
// DEUX PORTEURS D'ETAT DISTINCTS, DEUX HORLOGES DISTINCTES : lever l'un ne leve pas l'autre, et
// l'expiration de l'un ne touche pas l'autre. La seule chose qu'ils partagent est l'EFFET -- meme
// plage 20h-6h, meme risque de 45 %, aucun blocage physique -- ce qui est voulu : un joueur ne doit
// pas avoir a savoir lequel des deux le vise.
// ALIGNEMENT DU 8 SEPTEMBRE 2026 : le couvre-feu ordinaire est stocke dans budgets_nationaux, donc
// PARTAGE, et son echeance etait comparee a jourCourant -- c'est-a-dire, chez tous les appelants
// reels, a state.day, un compteur PRIVE a chaque navigateur. Le correctif applique a
// verifierCouvreFeu (plateau-politique.js) lit desormais cf.dateFin, deja posee par
// confirmerCouvreFeu. Cette fonction etant LA definition canonique du couvre-feu ordinaire, elle
// devait suivre, sans quoi le moteur et le runtime auraient diverge sur la meme question.
// jourFin reste le repli pour les couvre-feux poses avant l'ajout de dateFin.
function couvreFeuOrdinaireActif(budgetNational, jourCourant, maintenantMs) {
  const cf = (budgetNational || {}).couvreFeu;
  if (!cf || cf.actif !== true) return false;
  const dateFin = Number(cf.dateFin);
  if (isFinite(dateFin)) {
    const t = isFinite(Number(maintenantMs)) ? Number(maintenantMs) : Date.now();
    return t <= dateFin;
  }
  const fin = Number(cf.jourFin);
  return !isFinite(fin) || Number(jourCourant) <= fin;
}

// Un couvre-feu s'applique des que l'UN des deux est actif. Rend aussi son origine, pour que
// l'interface puisse dire lequel -- sans que cela change quoi que ce soit a l'effet.
function couvreFeuApplicable(budgetNational, jourCourant, regime, maintenantMs) {
  const ord = couvreFeuOrdinaireActif(budgetNational, jourCourant, maintenantMs);
  const exc = couvreFeuGeneralActif(regime, maintenantMs);
  return { actif: ord || exc, ordinaire: ord, exceptionnel: exc,
           origines: [].concat(ord ? ['ministre_interieur'] : []).concat(exc ? ['regime_exception'] : []) };
}

// ---------------------------------------------------------------------------
// 14. DISPERSION D'UN BLOCUS — FORMULE PARTAGEE
// ---------------------------------------------------------------------------
// EXTRAITE de confirmerMobilisationPolice (plateau-politique.js), pas recopiee : cette fonction est
// desormais LA definition du taux, et le handler historique l'appelle. Un second appelant ne peut
// donc plus diverger.
//
// Plus le blocus est intense, plus il resiste : 55 - intensite/3, borne a [10, 90]. Un blocus reste
// toujours dispersable (10 % minimum) et jamais gratuit a disperser (90 % maximum). La dispersion
// n'est JAMAIS automatique.
const BLOCUS_TAUX_BASE = 55;
const BLOCUS_TAUX_MIN = 10;
const BLOCUS_TAUX_MAX = 90;
const BLOCUS_INTENSITE_DEFAUT = 40;

function tauxDispersionBlocus(intensite) {
  const i = isFinite(Number(intensite)) ? Number(intensite) : BLOCUS_INTENSITE_DEFAUT;
  return Math.max(BLOCUS_TAUX_MIN, Math.min(BLOCUS_TAUX_MAX, BLOCUS_TAUX_BASE - i / 3));
}

// Verdict d'un jet deja tire : sert a tester la decision sans dependre du hasard.
function verdictDispersionBlocus(intensite, jet) {
  const taux = tauxDispersionBlocus(intensite);
  const r = Math.floor(Number(jet) || 0);
  return { taux: taux, jet: r, dispersé: r > 0 && r <= taux };
}

// ⚠ CE QUI MANQUE POUR BRANCHER LA REPRESSION MINISTERIELLE SUR UN BLOCUS, et qui arrete ce
// sous-point : le blocus est stocke dans batiments_etat pour le batiment OU L'ON SE TIENT
// (state.currentBuilding), tandis que « Reprimer une manifestation » cible une VILLE choisie dans
// une liste depuis le bureau du ministere. Il n'existe aucun index des blocus actifs, donc aucun
// moyen de proposer au ministre le batiment a debloquer.
//
// Deux issues possibles, toutes deux des decisions de game design :
//   - exiger la presence physique du ministre dans le batiment bloque (mais alors « n'importe
//     quelle ville » ne s'applique plus au volet blocus) ;
//   - construire un index des blocus actifs pour les lui presenter.
// Aucune n'est prise ici. La formule, elle, est desormais partagee et prete a servir.

// ---------------------------------------------------------------------------
// 15. ELIGIBILITE AU POSTE DE COMMANDANT
// ---------------------------------------------------------------------------
// ⚠ LE BNE NE PEUT PAS PORTER CETTE CANDIDATURE. L'audit du 7 septembre 2026 a etabli qu'il n'a
// AUCUN systeme de candidatures : c'est une prise de poste immediate sur un catalogue FERME de sept
// metiers codes en dur (OFFRES_EMPLOI_BNE, data.js), stocke dans un blob batiments_etat sous la
// forme { pjNom, statut }, ou « retirer » signifie supprimer la ligne par .filter(). Rien n'y permet
// de publier une offre pour un poste arbitraire, et rien n'y est archive.
//
// LE MOTEUR DE CANDIDATURES QUI CONVIENT EXISTE DEJA, et il gere deja 'commandant' : le dossier
// batiments_etat/candidatures_postes, avec sa fenetre de 48 h, son tirage au sort a echeance et son
// drapeau 'traitee' -- lequel est exactement l'archivage non destructif demande au §9. C'est donc
// lui qu'on utilise, et non un second moteur.

// --- Niveau d'etudes ---------------------------------------------------------
// Echelle REELLE du build, dans l'ordre (data.js, SCHOOLS) : aucune valeur ne s'appelle « moyennes ».
const NIVEAUX_ETUDES_ORDRE = ['none', 'basic', 'higher', 'elite'];

function rangEtudes(school) {
  const i = NIVEAUX_ETUDES_ORDRE.indexOf(school);
  return i === -1 ? -1 : i;
}

// ARBITRE LE 7 SEPTEMBRE 2026 : le minimum est 'higher'. L'echelle reelle n'ayant pas de niveau
// « moyen », la regle de game design -- pas d'etudes exclu, etudes basses exclues, superieur
// admissible -- se traduit par ce seuil unique :
//   none   refuse      basic  refuse      higher accepte      elite  accepte
const NIVEAU_ETUDES_MINIMUM_COMMANDANT = 'higher';

// --- Qualification militaire -------------------------------------------------
// DEUX SOURCES, comme demande. La premiere existe et fonctionne ; la seconde est prete et inerte.
//   build initial : career === 'officer' (« Armée — Officier supérieur / Mercenaire », data.js)
//   Universite    : une entree 'militaire' dans personnages.qualifications
//
// ⚠ LA VOIE UNIVERSITAIRE EST INERTE, ET LE RESTE VOLONTAIREMENT DANS CE LOT. L'Universite ne
// delivre aujourd'hui qu'un bonus de caracteristique de +2 valable jusqu'au prochain sommeil, et
// AUCUN code du depot n'ecrit jamais dans personnages.qualifications -- la colonne existe (creee par
// migration_moteur_commerce.sql), le catalogue QUALIFICATIONS existe, mais rien ne les alimente.
//
// Fabriquer ici une ecriture serait un faux raccord : ce serait decider ce que l'Universite enseigne,
// combien de temps, a quel prix. L'ECRITURE DURABLE DE LA QUALIFICATION MILITAIRE PAR L'UNIVERSITE
// RELEVE DU FUTUR CHANTIER FORMATIONS / PROFESSIONS. Le predicat lit deja la colonne : le jour ou ce
// chantier l'alimentera, la reconversion fonctionnera sans qu'on revienne ici.
const CARRIERE_MILITAIRE = 'officer';
const QUALIFICATION_MILITAIRE = 'militaire';

function aQualificationMilitaire(perso) {
  const p = perso || {};
  if (p.career === CARRIERE_MILITAIRE) return { ok: true, source: 'build' };
  const q = Array.isArray(p.qualifications) ? p.qualifications : [];
  if (q.indexOf(QUALIFICATION_MILITAIRE) !== -1) return { ok: true, source: 'universite' };
  return { ok: false, source: null };
}

// --- Poste exclusif ----------------------------------------------------------
// NOTION CANONIQUE DU PROJET, reutilisee telle quelle : POSTES_NOMMES_EXCLUSIFS et sa regle de
// cumul, ou 'depute' est le seul poste compatible. On y ajoute les mandats ELECTIFS, qui occupent le
// meme champ personnages.poste sans figurer dans ce catalogue -- c'est precisement le cas du
// President que le lot demande d'empecher.
//
// LES RESPONSABILITES ASSOCIATIVES NE COMPTENT PAS. Etre chef, president ou membre d'une
// organisation de joueurs n'est pas un poste institutionnel : ces roles vivent dans organisations.data,
// jamais dans personnages.poste, et ne sont donc jamais lus ici.
function posteExclusifOccupe(perso, posteVise) {
  const p = perso || {};
  const poste = p.poste || null;
  if (!poste || !poste.id) return null;
  if (poste.id === posteVise) return null;   // deja en poste : ce n'est pas une incompatibilite
  const regle = (typeof POSTES_NOMMES_EXCLUSIFS !== 'undefined') ? POSTES_NOMMES_EXCLUSIFS[posteVise] : null;
  const compatibles = (regle && regle.compatibles) || [];
  if (compatibles.indexOf(poste.id) !== -1) return null;
  return poste.id;
}

// --- Verdict complet ---------------------------------------------------------
// DEPOT : on peut candidater meme en occupant un poste incompatible. La candidature reste visible,
// et porte la mention de son inegibilite du moment -- c'est voulu : le ministre et le candidat se
// parlent, et decident politiquement. Aucune demission automatique n'est provoquee.
function verdictCandidatureCommandant(perso) {
  const p = perso || {};
  const nom = (typeof p.name === 'string') ? p.name.trim() : '';
  if (!nom) return { ok: false, raison: 'candidat_invalide' };
  return { ok: true, raison: null, candidat: nom };
}

// NOMINATION : tout est RECALCULE ici, jamais repris du depot. C'est le seul moment qui compte.
function verdictNominationCommandant(perso) {
  const p = perso || {};

  const mil = aQualificationMilitaire(p);
  if (!mil.ok) return { ok: false, raison: 'qualification_militaire_absente' };

  // ORDRE DELIBERE : les regles ARBITREES sont evaluees avant celle qui ne l'est pas. Sans cela un
  // President se verrait refuser au motif que le seuil d'etudes n'est pas tranche -- un motif
  // provisoire masquant une incompatibilite definitive, et le ministre croirait la nomination
  // possible plus tard.
  const occupe = posteExclusifOccupe(p, 'commandant');
  if (occupe) {
    // REFUS SEC. On ne touche a RIEN : le poste existant reste intact, aucune demission n'est
    // provoquee. C'est le cas explicitement a empecher -- candidat devenu President, nomination
    // refusee, Presidence conservee.
    return { ok: false, raison: 'poste_exclusif_occupe', posteOccupe: occupe, aucunEffet: true };
  }

  if (NIVEAU_ETUDES_MINIMUM_COMMANDANT === null) {
    return { ok: false, raison: 'seuil_etudes_non_arbitre', qualificationMilitaire: mil.source };
  }
  if (rangEtudes(p.school) < rangEtudes(NIVEAU_ETUDES_MINIMUM_COMMANDANT)) {
    return { ok: false, raison: 'etudes_insuffisantes',
             requis: NIVEAU_ETUDES_MINIMUM_COMMANDANT, obtenu: p.school || null };
  }

  // AUCUN SEUIL DE CARACTERISTIQUE. Ni FOR, ni INT, ni VOL : le lot l'exclut explicitement.
  return { ok: true, raison: null, qualificationMilitaire: mil.source };
}

// Etat d'affichage d'une candidature : elle survit a l'inegibilite, elle ne disparait pas.
function etatCandidatureCommandant(perso) {
  const v = verdictNominationCommandant(perso);
  return { visible: true, nommable: v.ok, motif: v.raison,
           posteBloquant: v.posteOccupe || null };
}

// --- Cycle de vie ------------------------------------------------------------
// Apres une nomination effective puis une revocation, l'ancienne candidature ne redevient PAS
// disponible : le dossier a ete marque 'traitee' par le moteur generique, et un dossier traite ne se
// rouvre pas. Il faut deposer une NOUVELLE candidature. On lit donc l'etat du moteur existant plutot
// que de tenir un registre parallele.
function candidatureEncoreOuverte(dossier, nomCandidat) {
  const d = dossier || {};
  if (d.traitee === true) return false;
  const c = (d.candidats || []).filter(function (x) { return x && x.nom === nomCandidat && !x.retiree; });
  return c.length > 0;
}

// ---------------------------------------------------------------------------
// 16. INDEX DES BLOCUS ACTIFS
// ---------------------------------------------------------------------------
// AUDIT : aucune nouvelle persistance n'est necessaire. batiments_etat porte deja country, city et
// building_id EN COLONNES, et le blocus dans son blob `data`. Une seule requete par pays
// (sbListerBlocusActifs) suffit donc a reconstruire la liste de facon fiable, et un blocus disparu
// disparait de la liste par construction -- il n'y a rien a synchroniser, donc rien a desynchroniser.
//
// C'est ce qui permet au ministre d'agir a distance : il choisit un blocus dans une liste, sans avoir
// a se rendre physiquement dans le batiment bloque.

// Normalise et ordonne les lignes brutes. Fonction pure : c'est elle qui est testee, la requete
// n'etant qu'un transport.
function blocusActifsDepuisEtats(lignes) {
  return (lignes || [])
    .filter(function (l) { return l && l.blocus && l.buildingId; })
    .map(function (l) {
      const b = l.blocus;
      return {
        cle: l.country + '_' + l.city + '_' + l.buildingId,
        country: l.country, city: l.city, buildingId: l.buildingId,
        intensite: isFinite(Number(b.intensite)) ? Number(b.intensite) : BLOCUS_INTENSITE_DEFAUT,
        syndicatNom: b.syndicatNom || null, syndicatId: b.syndicatId || null,
        revendication: b.revendication || null,
        nbMilitants: Math.max(0, Math.floor(Number(b.nbMilitants) || 0)),
        leaderActuel: b.leaderActuel || null,
        // Le taux vient de la formule PARTAGEE : le ministre voit la meme chance que le commissaire.
        taux: tauxDispersionBlocus(b.intensite)
      };
    })
    // Ordre deterministe : ville puis batiment, pour que la liste ne saute pas d'un affichage a l'autre.
    .sort(function (a, b) {
      const c = String(a.city).localeCompare(String(b.city), 'fr');
      return c !== 0 ? c : String(a.buildingId).localeCompare(String(b.buildingId), 'fr');
    });
}

// Libelle d'identification : ville, batiment, syndicat et intensite -- de quoi choisir sans se
// tromper de blocus.
function libelleBlocus(b) {
  const ville = (typeof NOMS_VILLES_REPUBLIA !== 'undefined' && NOMS_VILLES_REPUBLIA[b.city]) || b.city;
  const bat = (typeof BUILDINGS !== 'undefined' && BUILDINGS[b.buildingId] && BUILDINGS[b.buildingId].name) || b.buildingId;
  return ville + ' — ' + bat + (b.syndicatNom ? ' (' + b.syndicatNom + ')' : '') +
         ' · intensité ' + b.intensite + ' · ' + Math.round(b.taux) + ' % de chances';
}

// ---------------------------------------------------------------------------
// 17. TRESORIER D'ORGANISATION — QUI TIENT LA CAISSE
// ---------------------------------------------------------------------------
// REGLE (arbitrage du 7 septembre 2026) :
//   sans tresorier  -> le chef manipule la caisse
//   avec tresorier  -> LUI SEUL la manipule ; le chef en perd la main tant qu'il est en fonction
//   le chef nomme et revoque le tresorier ; la revocation lui rend la caisse IMMEDIATEMENT
//
// LE TRESORIER DISPOSE REELLEMENT DES FONDS. Il peut donc les detourner, et aucune protection
// artificielle ne l'en empeche : c'est le prix de la delegation, et c'est voulu. Les actes passes
// avant revocation ne sont evidemment pas annules.
//
// AUCUNE MIGRATION : organisations.data est un blob JSON, le champ 'tresorier' s'y ajoute seul.
const ORDRES_ORGA_FINANCIERS = ['orga_collecte', 'orga_dividendes'];

// Qui tient la caisse aujourd'hui ? Une seule reponse, un seul endroit.
function gestionnaireCaisseOrga(orga) {
  const o = orga || {};
  const t = (typeof o.tresorier === 'string') ? o.tresorier.trim() : '';
  return t !== '' ? t : (o.chef || null);
}

function verdictAutoriteCaisseOrga(orga, nomJoueur) {
  const o = orga || {};
  const nom = (typeof nomJoueur === 'string') ? nomJoueur.trim() : '';
  if (!nom) return { ok: false, raison: 'joueur_inconnu' };
  const gestionnaire = gestionnaireCaisseOrga(o);
  if (!gestionnaire) return { ok: false, raison: 'organisation_sans_responsable' };
  if (gestionnaire !== nom) {
    // Message distinct selon la cause : un chef dessaisi doit comprendre qu'il n'est pas exclu,
    // mais qu'il a delegue -- et qu'il peut revoquer.
    const message = (o.tresorier && o.chef === nom)
      ? 'Vous avez nommé un trésorier : lui seul gère la caisse tant qu\'il est en fonction.'
      : 'Vous ne gérez pas la caisse de cette organisation.';
    return { ok: false, raison: 'pas_gestionnaire_caisse', gestionnaire: gestionnaire, message: message };
  }
  return { ok: true, raison: null, gestionnaire: gestionnaire };
}

// Nomination et revocation : reservees au CHEF, jamais au tresorier lui-meme -- sinon il pourrait
// se maintenir seul aux commandes de la caisse.
function verdictNominationTresorier(orga, nomChef, nomTresorier) {
  const o = orga || {};
  if (!o.chef || o.chef !== nomChef) return { ok: false, raison: 'reserve_au_chef' };
  const t = (typeof nomTresorier === 'string') ? nomTresorier.trim() : '';
  if (!t) return { ok: false, raison: 'tresorier_requis' };
  if (t === o.chef) return { ok: false, raison: 'chef_deja_gestionnaire' };
  const membres = (o.membres || []).map(function (m) { return m && m.nom ? m.nom : null; });
  if (membres.indexOf(t) === -1) return { ok: false, raison: 'pas_membre' };
  return { ok: true, raison: null, tresorier: t };
}

function verdictRevocationTresorier(orga, nomChef) {
  const o = orga || {};
  if (!o.chef || o.chef !== nomChef) return { ok: false, raison: 'reserve_au_chef' };
  if (!o.tresorier) return { ok: false, raison: 'aucun_tresorier' };
  return { ok: true, raison: null, ancienTresorier: o.tresorier };
}

// Mutations pures : l'appelant persiste. La revocation rend la caisse au chef par simple absence de
// tresorier -- aucun etat intermediaire, aucune reprise a organiser.
function nommerTresorier(orga, nomTresorier) {
  return Object.assign({}, orga || {}, { tresorier: String(nomTresorier).trim() });
}

function revoquerTresorier(orga) {
  const o = Object.assign({}, orga || {});
  o.tresorierPrecedent = o.tresorier || null;
  o.tresorier = null;
  return o;
}

// ---------------------------------------------------------------------------
// 18. SANCTIONS INTERNATIONALES — ETAT PERSISTANT DU MAE
// ---------------------------------------------------------------------------
// L'ancienne action « Imposer des sanctions » ne faisait que muter INDICES_NATIONAUX, une constante
// EN MEMOIRE CLIENT jamais persistee : l'effet disparaissait au rechargement et n'etait jamais vu
// par l'empire cible. Elle a ete retiree. Ce moteur la remplace par un ETAT REEL.
//
// TROIS MESURES SEPAREES, imposables et levables INDEPENDAMMENT -- c'est la condition pour que les
// futurs moteurs economiques des autres empires puissent s'y raccorder mesure par mesure.
//   embargo             coupe les flux import/export REELLEMENT identifiables
//   rappel_ambassadeur  retire notre ambassadeur de chez eux
//   expulsion_ambassadeur  renvoie le leur de chez nous
//
// EXPLICITEMENT EXCLUS : le gel des avoirs, et la fermeture automatique de l'ambassade. Une sanction
// n'implique pas la rupture : le bureau reste ouvert, seul l'ambassadeur s'en va.
const MESURES_SANCTION = ['embargo', 'rappel_ambassadeur', 'expulsion_ambassadeur'];

function sanctionsActives(etat, empireCible) {
  const e = (etat && etat[empireCible]) || null;
  if (!e || !Array.isArray(e.mesures)) return [];
  return e.mesures.filter(function (m) { return MESURES_SANCTION.indexOf(m) !== -1; });
}

function sanctionActive(etat, empireCible, mesure) {
  return sanctionsActives(etat, empireCible).indexOf(mesure) !== -1;
}

function verdictImposerSanction(posteId, empireCible, mesure, paysSoi) {
  if (posteId !== 'min_ae') return { ok: false, raison: 'reserve_au_mae' };
  if (MESURES_SANCTION.indexOf(mesure) === -1) return { ok: false, raison: 'mesure_inconnue' };
  if (!empireCible) return { ok: false, raison: 'cible_requise' };
  if (empireCible === paysSoi) return { ok: false, raison: 'auto_sanction' };
  return { ok: true, raison: null };
}

// Impose une mesure sans toucher aux autres : l'etat est cumulatif et chaque mesure vit sa vie.
function imposerSanction(etat, empireCible, mesure, auteur, maintenantMs) {
  const e = Object.assign({}, etat || {});
  const courant = e[empireCible] || { mesures: [], histoire: [] };
  const mesures = (courant.mesures || []).slice();
  if (mesures.indexOf(mesure) === -1) mesures.push(mesure);
  e[empireCible] = {
    mesures: mesures,
    histoire: (courant.histoire || []).concat([
      { mesure: mesure, sens: 'imposee', par: auteur || null, leTs: Number(maintenantMs) || 0 }
    ]).slice(-50)
  };
  return e;
}

function leverSanction(etat, empireCible, mesure, auteur, maintenantMs) {
  const e = Object.assign({}, etat || {});
  const courant = e[empireCible] || { mesures: [], histoire: [] };
  e[empireCible] = {
    mesures: (courant.mesures || []).filter(function (m) { return m !== mesure; }),
    histoire: (courant.histoire || []).concat([
      { mesure: mesure, sens: 'levee', par: auteur || null, leTs: Number(maintenantMs) || 0 }
    ]).slice(-50)
  };
  return e;
}

// ---------------------------------------------------------------------------
// 19. EMBARGO — CE QUE LE MOTEUR SAIT REELLEMENT COUPER
// ---------------------------------------------------------------------------
// ON NE SIMULE PAS DES ORIGINES QUE LE MOTEUR NE CONNAIT PAS. L'audit a etabli que le pays partenaire
// n'est disponible qu'a DEUX endroits du flux reel :
//
//   EXPORTATIONS  EXPORTATIONS_PORT[cle].destination -- cereales et viande vers Al-Khalija.
//                 C'est le SEUL point ou le pays partenaire figure dans le code.
//   IMPORT BOIS   BOIS_SOVARKA_JOUR, 150 unites/jour explicitement attribuees a Sovarka.
//
// Partout ailleurs, l'import est un tirage aleatoire local : ORIGINE_IMPORTS_PORT nomme des pays
// mais AUCUN code ne lit ses fractions. Un embargo « par pays » sur ces flux-la serait une fiction.
// Le moteur ne coupe donc que ce qui est reellement attribuable, et le DIT.
const EMBARGO_FLUX_CONNUS = {
  export_cereales: { sens: 'export', ressource: 'cereales', partenaire: 'khalija' },
  export_viande:   { sens: 'export', ressource: 'viande',   partenaire: 'khalija' },
  import_bois:     { sens: 'import', ressource: 'bois',     partenaire: 'soviet', quantiteJour: 150 }
};

function fluxCoupesParEmbargo(etat) {
  const coupes = [];
  Object.keys(EMBARGO_FLUX_CONNUS).forEach(function (cle) {
    const f = EMBARGO_FLUX_CONNUS[cle];
    if (sanctionActive(etat, f.partenaire, 'embargo')) {
      coupes.push(Object.assign({ cle: cle }, f));
    }
  });
  return coupes;
}

// Hook des exportations : rend vrai si le contrat doit etre suspendu ce jour-la.
function exportSuspenduParEmbargo(etat, ressource, destination) {
  return sanctionActive(etat, destination, 'embargo') &&
         Object.keys(EMBARGO_FLUX_CONNUS).some(function (c) {
           const f = EMBARGO_FLUX_CONNUS[c];
           return f.sens === 'export' && f.ressource === ressource && f.partenaire === destination;
         });
}

// Hook de l'import de bois : rend la quantite reellement livree.
function importBoisApresEmbargo(etat, quantiteNormale) {
  const q = Math.max(0, Number(quantiteNormale) || 0);
  return sanctionActive(etat, 'soviet', 'embargo') ? 0 : q;
}

// Ce qu'un embargo NE coupe PAS, rendu explicitement pour que personne ne le croie.
function fluxHorsPorteeEmbargo() {
  return [{ flux: 'imports_generiques', motif: 'origine_non_modelisee',
            detail: 'ORIGINE_IMPORTS_PORT nomme des pays mais ses fractions ne sont lues nulle part' }];
}
