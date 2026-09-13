// =====================
// PLATEAU-EFFORT-GUERRE.JS — 13 septembre 2026
// Effort de guerre : reserve strategique, ravitaillement, production militaire par les
// armureries civiles, armurerie de la caserne (retrait / subtilisation), refectoire.
//
// CE FICHIER NE CONTIENT AUCUNE REGLE DE DUREE NI D'AUTORITE : elles vivent dans
// plateau-gouvernement.js (sections 6-8), en logique pure et testable. Ici on trouve les
// entrees/sorties : lecture d'etat, appels de RPC, panneaux.
//
// DOCTRINE D'ECRITURE. Tout ce qui touche a du stock, a de l'argent ou a un registre passe
// par une RPC SECURITY DEFINER (migration_effort_de_guerre.sql) : verrou de ligne, tout-ou-rien,
// revalidation serveur du poste et de la presence physique. Aucun repli non atomique -- si la
// RPC est injoignable, RIEN ne se passe et on le dit au joueur.
// =====================

// ---------------------------------------------------------------------------
// 1. LES TROIS ENTREPOTS — SOURCE UNIQUE COTE CLIENT
// ---------------------------------------------------------------------------
// L'audit du 13 septembre a releve CINQ enumerations divergentes des entrepots dans le projet
// (plateau-justice-economie.js x2, api/cron-minuit.js x2, api/_journal-collecte.js). On n'en
// supprime aucune ici -- ce serait un refactor hors chantier, avec un risque sans rapport avec
// l'Effort -- mais tout le nouveau code lit CELLE-CI et rien d'autre. Elle porte la forme
// attendue par les RPC ({building, city}), ce qu'aucune des cinq autres ne fait.
const ENTREPOTS_EFFORT = {
  republic: [
    { building: 'entrepot-logistique-luthecia',  city: 'capitale', nom: 'Luthécia' },
    { building: 'entrepot-logistique-psm',       city: 'ville_a',  nom: 'Port-Sainte-Marie' },
    { building: 'entrepot-logistique-montrouge', city: 'ville_b',  nom: 'Montrouge' }
  ]
};

function entrepotsEffort(pays) {
  return ENTREPOTS_EFFORT[pays || 'republic'] || [];
}

// Charge utile des RPC : uniquement {building, city}, le nom est de l'affichage.
function entrepotsEffortRpc(pays) {
  return entrepotsEffort(pays).map(function (e) { return { building: e.building, city: e.city }; });
}

// L'unique caserne nationale, et l'unique armurerie militaire du pays.
const CASERNE_BUILDING_ID = 'caserne-militaire';
const CASERNE_CITY = 'caserne';

// ---------------------------------------------------------------------------
// 2. CATALOGUE MILITAIRE
// ---------------------------------------------------------------------------
// Les deux armes reprennent les IDENTIFIANTS EXISTANTS (arme_de_poing, mitraillette, deja
// CATEGORIES_ARME_STOCK / COEF_ARME_MILITAIRE) : une seule nomenclature, zero migration de
// donnees, et le stock institutionnel deja en place reste lisible tel quel.
//
// QUANTITE DE TRAVAIL : la recette civile correspondante ne facture PAS son travail au prorata
// de son palier d'UT -- toute production d'armurerie coute forfaitairement PA_PRODUCTION_ARMURERIE
// (2 PA, plateau-actions-illegales-rumeurs.js). C'est cette quantite reelle qui est reprise ici,
// pas le champ `ut` qui ne sert plus qu'aux paliers de prix et de stock maximum.
// VISUELS : imageUrl est declare ICI et nulle part ailleurs. Le meme fichier sert l'objet
// d'inventaire (poserObjetMilitaire) et l'apercu du tableau de commande du ministre -- une seule
// serie d'images, jamais deux. Les trois cartes proviennent de la planche fournie le 13/09/2026.
const PA_TRAVAIL_MILITAIRE_DEFAUT = 2;

const RECETTES_MILITAIRES = {
  arme_de_poing: {
    label: 'Pistolet militaire',
    materiaux: { metal: 2, bois: 1 },      // recette du revolver civil
    produitParLot: 1,
    icon: 'ti-crosshair',
    typeObjet: 'arme', sousType: 'militaire',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png',
    desc: 'Arme de poing réglementaire de l\'armée de Républia.'
  },
  mitraillette: {
    label: 'Mitraillette',
    materiaux: { metal: 2, bois: 2 },      // recette de la carabine civile
    produitParLot: 1,
    icon: 'ti-crosshair',
    typeObjet: 'arme', sousType: 'militaire',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png',
    desc: 'Arme automatique réglementaire de l\'armée de Républia.'
  },
  explosif_militaire: {
    label: 'Explosifs militaires',
    materiaux: { metal: 2, minerai: 3 },
    pa: 1,                                  // arbitrage dedie : 1 PA pour 3 explosifs
    produitParLot: 3,
    icon: 'ti-bomb',
    typeObjet: 'explosif', sousType: 'militaire',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-militaires.png',
    desc: 'Explosifs réglementaires de l\'armée de Républia.'
  }
};

const PRODUITS_MILITAIRES = Object.keys(RECETTES_MILITAIRES);

function recetteMilitaire(produit) {
  return RECETTES_MILITAIRES[produit] || null;
}

function paTravailMilitaire(produit) {
  const r = recetteMilitaire(produit);
  if (!r) return 0;
  if (typeof r.pa === 'number') return r.pa;
  return (typeof PA_PRODUCTION_ARMURERIE === 'number') ? PA_PRODUCTION_ARMURERIE : PA_TRAVAIL_MILITAIRE_DEFAUT;
}

// MATIERES ELIGIBLES A LA RESERVE — DEDUITES DES RECETTES, jamais maintenues a la main.
// Ajouter un produit militaire suffit a etendre la reserve ; il n'existe aucune seconde liste
// a tenir a jour, et donc aucune divergence possible.
function ressourcesMilitairesEligibles() {
  const vues = {};
  PRODUITS_MILITAIRES.forEach(function (p) {
    Object.keys(RECETTES_MILITAIRES[p].materiaux || {}).forEach(function (m) { vues[m] = true; });
  });
  return Object.keys(vues).sort();
}

// COUT DE REVIENT D'UN LOT = matieres + travail. Regle definitive du 13 septembre :
// le montant verse a l'armurier EST ce cout de revient, une seule fois. Pas de second paiement
// des matieres, pas de main-d'oeuvre versee a part, pas de salarie fictif, pas de seconde marge.
// Prix des matieres : celui de l'entrepot (getPrixRessourceEntrepot = prixBase), source unique.
// Travail : COUT_HORAIRE_TRAVAIL (1 PA = 50 FR), la reference deja utilisee par plateau-commerce.
function coutRevientLotMilitaire(produit) {
  const r = recetteMilitaire(produit);
  if (!r) return 0;
  const tarifPa = (typeof COUT_HORAIRE_TRAVAIL === 'number') ? COUT_HORAIRE_TRAVAIL : 50;
  let total = 0;
  Object.keys(r.materiaux || {}).forEach(function (m) {
    const prix = (typeof getPrixRessourceEntrepot === 'function') ? getPrixRessourceEntrepot(m) : 0;
    total += (Number(r.materiaux[m]) || 0) * (Number(prix) || 0);
  });
  return Math.round(total + paTravailMilitaire(produit) * tarifPa);
}

// Detail affichable/facturable du cout de revient, pour que le mail au proprietaire et le
// montant reellement credite soient calcules par la MEME fonction -- ils ne peuvent donc pas
// diverger, ce que le cahier des charges exige explicitement.
function detailCoutRevientMilitaire(produit) {
  const r = recetteMilitaire(produit);
  if (!r) return null;
  const tarifPa = (typeof COUT_HORAIRE_TRAVAIL === 'number') ? COUT_HORAIRE_TRAVAIL : 50;
  const lignes = [];
  let matieres = 0;
  Object.keys(r.materiaux || {}).forEach(function (m) {
    const qte = Number(r.materiaux[m]) || 0;
    const prix = (typeof getPrixRessourceEntrepot === 'function') ? getPrixRessourceEntrepot(m) : 0;
    lignes.push({ matiere: m, quantite: qte, prixUnitaire: prix, valeur: qte * prix });
    matieres += qte * prix;
  });
  const pa = paTravailMilitaire(produit);
  return {
    produit: produit, label: r.label, produitParLot: r.produitParLot,
    lignes: lignes, valeurMatieres: matieres,
    paTravail: pa, tarifPa: tarifPa, valeurTravail: pa * tarifPa,
    coutRevientLot: Math.round(matieres + pa * tarifPa),
    coutRevientUnitaire: Math.round((matieres + pa * tarifPa) / Math.max(1, r.produitParLot))
  };
}

// ---------------------------------------------------------------------------
// 3. ETAT DE L'EFFORT
// ---------------------------------------------------------------------------
async function chargerEffortGuerre(pays) {
  if (typeof chargerBudgetNational !== 'function') return null;
  const bn = await chargerBudgetNational(pays || 'republic').catch(function () { return null; });
  return bn ? (bn.effortGuerre || null) : null;
}

// GUERRE EN COURS. sbGetGuerresPays filtre deja statut != 'terminee' cote requete : toute ligne
// rendue EST une guerre en cours. On ne teste surtout pas g.statut, qui est toujours undefined
// sur ces objets (le spread ne recopie que `data`, ou statut n'existe pas) -- bug connu, laisse
// en l'etat parce que le corriger changerait le comportement d'estImmuniteMilitaire, hors chantier.
async function effortGuerreGuerreEnCours(pays) {
  if (typeof sbGetGuerresPays !== 'function') return false;
  const g = await sbGetGuerresPays(pays || 'republic').catch(function () { return []; });
  return Array.isArray(g) && g.length > 0;
}

function effortGuerreCache() {
  return state.effortGuerreCache || null;
}

function effortGuerreEstActif() {
  return typeof effortDeGuerreActif === 'function' && effortDeGuerreActif(effortGuerreCache(), Date.now());
}

// Rafraichit le cache client. Meme doctrine que rafraichirCacheImmuniteMilitaire : un cache
// memoire, jamais persiste sur la fiche du joueur, relu a chaque entree de batiment.
async function rafraichirCacheEffortGuerre() {
  state.effortGuerreCache = await chargerEffortGuerre(state.country || 'republic')
    .catch(function () { return null; });
  return state.effortGuerreCache;
}

// Curseurs effectifs. Hors Effort, les deux priorites sont nulles : aucune reserve, aucun
// ravitaillement prioritaire, aucune production. C'est la traduction mecanique de « hors Effort,
// aucune arme militaire n'est produite ni acquise : la caserne vit sur son stock ».
function prioritesEffort(effort) {
  const actif = typeof effortDeGuerreActif === 'function' && effortDeGuerreActif(effort, Date.now());
  if (!actif) return { ravitaillement: 0, production: 0 };
  const d = (typeof PRIORITE_MILITAIRE_DEFAUT === 'number') ? PRIORITE_MILITAIRE_DEFAUT : 50;
  const lire = function (v) {
    const n = Number(v);
    return isFinite(n) ? Math.max(0, Math.min(100, Math.round(n))) : d;
  };
  return { ravitaillement: lire(effort.prioriteRavitaillement), production: lire(effort.prioriteProductionMilitaire) };
}

// ---------------------------------------------------------------------------
// 4. RESERVE MILITAIRE
// ---------------------------------------------------------------------------
// Appliquee par RPC sur les trois entrepots a la fois. Le pourcentage porte sur le stock
// NATIONAL de chaque matiere eligible ; la repartition suit le prorata des stocks reels, si bien
// qu'un entrepot deficitaire est automatiquement compense par les autres, sans quota par ville.
async function appliquerReserveMilitaire(pays, pct) {
  if (typeof sbEffortReserveAppliquer !== 'function') return null;
  return sbEffortReserveAppliquer(pays || 'republic', entrepotsEffortRpc(pays),
                                  ressourcesMilitairesEligibles(), Math.max(0, Math.min(100, pct)));
}

// Reserve portee par UN entrepot, lue sur son blob. Jamais devinee ni recalculee cote client :
// l'autorite est la valeur ecrite par la RPC.
function reserveMilitaireEntrepot(etatBatiment) {
  const e = (etatBatiment || {}).entrepot || {};
  return (e.reserveMilitaire && typeof e.reserveMilitaire === 'object') ? e.reserveMilitaire : {};
}

// STOCK REELLEMENT DISPONIBLE AUX USAGES CIVILS = stock physique - reserve militaire.
// C'est LA fonction que doivent appeler tous les consommateurs non militaires : achat d'un PJ a
// la Salle des Ventes, et approvisionnement des chantiers. La marchandise reservee reste
// physiquement dans l'entrepot -- elle est seulement indisponible.
function stockCivilDisponible(etatBatiment) {
  const e = (etatBatiment || {}).entrepot || {};
  const stock = (e.stock && typeof e.stock === 'object') ? e.stock : {};
  const reserve = reserveMilitaireEntrepot(etatBatiment);
  const dispo = {};
  Object.keys(stock).forEach(function (cle) {
    dispo[cle] = Math.max(0, (Number(stock[cle]) || 0) - (Number(reserve[cle]) || 0));
  });
  return dispo;
}

// Total national reserve, par matiere — pour l'affichage du panneau du ministre.
async function totauxReserveMilitaire(pays) {
  const liste = entrepotsEffort(pays);
  const detail = [];
  const totaux = {};
  for (let i = 0; i < liste.length; i++) {
    const e = liste[i];
    const etat = (typeof sbGetBatimentEtat === 'function')
      ? await sbGetBatimentEtat(pays, e.city, e.building).catch(function () { return {}; })
      : {};
    const res = reserveMilitaireEntrepot(etat);
    detail.push({ nom: e.nom, reserve: res, stock: ((etat.entrepot || {}).stock) || {} });
    Object.keys(res).forEach(function (m) { totaux[m] = (totaux[m] || 0) + (Number(res[m]) || 0); });
  }
  return { totaux: totaux, detail: detail };
}

// ---------------------------------------------------------------------------
// 5. PANNEAU DU PRESIDENT — « EFFORT NATIONAL »
// ---------------------------------------------------------------------------
function ouvrirEffortNational() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Réservé au Président de la République.', false);
    return;
  }
  rafraichirCacheEffortGuerre().then(function () { rendreEffortNational(); });
}

async function rendreEffortNational() {
  const pays = state.country || 'republic';
  const effort = effortGuerreCache();
  const actif = effortGuerreEstActif();
  const guerre = await effortGuerreGuerreEnCours(pays);
  const cout = (typeof COUT_PA_EFFORT_GUERRE === 'number') ? COUT_PA_EFFORT_GUERRE : 2;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">'
       + 'L\'Effort de guerre est la mobilisation <strong>économique et matérielle</strong> du pays. '
       + 'Il est distinct de la Mobilisation nationale, qui est humaine et relève du Ministre de la Défense.'
       + '</div>';

  if (actif) {
    const fin = (typeof effortDeGuerreEcheance === 'function') ? effortDeGuerreEcheance(effort) : null;
    const restantMs = fin ? Math.max(0, fin - Date.now()) : null;
    const heures = restantMs != null ? Math.floor(restantMs / 3600000) : null;
    const prev = Math.max(0, Math.floor(Number(effort.periodesPreventives) || 0));
    const maxPrev = (typeof PERIODES_PREVENTIVES_MAX === 'number') ? PERIODES_PREVENTIVES_MAX : 2;

    html += '<div style="border:1px solid #6a5a20;background:#12100a;padding:.7rem;margin-bottom:.8rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.95rem;color:#C9A84C">EFFORT DE GUERRE ACTIF</div>';
    html += '<div style="font-size:.76rem;color:#a09070;margin-top:.3rem">Période ' + (effort.periodes || 1)
         + (heures != null ? ' — expire dans ' + heures + ' h' : '') + '</div>';
    html += '<div style="font-size:.72rem;color:#8a8060;margin-top:.2rem">'
         + (guerre ? 'Guerre déclarée : renouvellements illimités, aucune pénalité.'
                   : 'Hors guerre : ' + prev + ' / ' + maxPrev + ' période(s) préventive(s) utilisée(s).')
         + '</div></div>';

    const peutRenouveler = guerre || prev < maxPrev;
    if (peutRenouveler) {
      html += '<button onclick="confirmerRenouvellementEffort()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;margin-bottom:.5rem">Renouveler pour 3 jours (' + cout + ' PA)'
           + (guerre ? '' : ' — coûte 2 IS dans les trois villes') + '</button>';
    } else {
      html += '<div style="font-size:.76rem;color:#8a6a4a;font-style:italic;margin-bottom:.5rem">Prolongation préventive épuisée. Seule une guerre déclarée permettrait de poursuivre au-delà.</div>';
    }
    html += '<button onclick="confirmerArretEffort()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.55rem;border:1px solid #6a3a20;background:transparent;color:#cc6a44;cursor:pointer">Arrêter l\'Effort de guerre (0 PA)</button>';
    html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.5rem;line-height:1.6">L\'arrêt libère immédiatement les matières réservées et annule les reliquats non produits. Les marchandises déjà produites restent acquises.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem;line-height:1.7">'
         + 'Déclencher l\'Effort ouvre une période de <strong>3 jours réels</strong> : plafond budgétaire de la Défense levé, '
         + 'réserve stratégique sur les entrepôts, ravitaillement de la caserne et production militaire par les armureries civiles. '
         + 'Les ventes civiles d\'armes sont suspendues pendant toute la durée.'
         + '</div>';
    html += '<button onclick="confirmerDeclenchementEffort()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déclencher l\'Effort de guerre (' + cout + ' PA)</button>';
    html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.5rem;line-height:1.6">'
         + (guerre ? 'Guerre déclarée : renouvellements illimités.'
                   : 'Hors guerre : une seule prolongation possible, au prix de 2 IS dans chacune des trois villes. Le déclenchement initial, lui, ne coûte aucun indice.')
         + '</div>';
  }
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Effort national';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ECRITURE DE L'ETAT. budgets_nationaux.data est un blob relu-modifie-reecrit : on relit
// toujours juste avant d'ecrire et on ne touche QUE la cle effortGuerre, pour ne jamais
// ecraser une cle posee entre-temps par un autre systeme (mobilisation, couvre-feu, fiscalite).
async function ecrireEffortGuerre(pays, effort) {
  const bn = await chargerBudgetNational(pays).catch(function () { return null; });
  if (!bn) return false;
  bn.effortGuerre = effort;
  await sbSaveBudgetNational(pays, bn).catch(function () {});
  state.effortGuerreCache = effort;
  return true;
}

async function confirmerDeclenchementEffort() {
  const pays = state.country || 'republic';
  const effort = await chargerEffortGuerre(pays);
  const v = verdictDeclencherEffortDeGuerre(state.poste?.id, effort, Date.now());
  if (!v.ok) {
    showToast('Impossible', v.raison === 'deja_actif' ? 'L\'Effort de guerre est déjà actif.' : 'Réservé au Président.', false);
    return;
  }
  const cout = (typeof COUT_PA_EFFORT_GUERRE === 'number') ? COUT_PA_EFFORT_GUERRE : 2;
  const r = await deduireCoutOrdre({ pa: cout, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', cout + ' PA requis.', false); return; }

  const guerre = await effortGuerreGuerreEnCours(pays);
  const nouveau = ouvrirEffortDeGuerre(state.char?.name || 'Le Président', Date.now(), guerre);
  await ecrireEffortGuerre(pays, nouveau);

  // La reserve prend effet immediatement, au niveau du curseur par defaut.
  await appliquerReserveMilitaire(pays, nouveau.prioriteProductionMilitaire).catch(function () {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Effort de guerre déclenché', 'Période de 3 jours ouverte. Le Ministre de la Guerre dispose de son tableau de contrôle.', true, true);
  addJournalEntry('Effort de guerre déclenché pour 3 jours.', 'event-info');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('Le Président a décrété l\'Effort de guerre. L\'économie du pays passe en régime militaire.');
  }
}

async function confirmerRenouvellementEffort() {
  const pays = state.country || 'republic';
  const effort = await chargerEffortGuerre(pays);
  const guerre = await effortGuerreGuerreEnCours(pays);
  const v = verdictRenouvelerEffortDeGuerre(state.poste?.id, effort, Date.now(), guerre);
  if (!v.ok) {
    showToast('Renouvellement impossible',
      v.raison === 'prolongation_preventive_epuisee'
        ? 'Hors guerre déclarée, l\'Effort ne peut dépasser deux périodes consécutives.'
        : (v.raison === 'pas_actif' ? 'Aucun Effort de guerre actif.' : 'Réservé au Président.'), false);
    return;
  }
  const cout = (typeof COUT_PA_EFFORT_GUERRE === 'number') ? COUT_PA_EFFORT_GUERRE : 2;
  const r = await deduireCoutOrdre({ pa: cout, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', cout + ' PA requis.', false); return; }

  const renouvele = renouvelerEffortDeGuerre(effort, Date.now(), guerre);
  await ecrireEffortGuerre(pays, renouvele);

  // PENALITE D'IS : seulement hors guerre. L'IS national est la moyenne des trois villes et
  // n'existe pas en base : on applique donc -2 sur la cle reelle 'social' de CHACUNE des villes,
  // ce qui deplace la moyenne de -2 sans creer aucune notion d'indice nouvelle.
  if (v.penaliteIS && typeof modifierIndiceVille === 'function') {
    const delta = (typeof IS_PROLONGATION_PREVENTIVE === 'number') ? IS_PROLONGATION_PREVENTIVE : -2;
    const villes = ['capitale', 'ville_a', 'ville_b'];
    for (let i = 0; i < villes.length; i++) {
      await modifierIndiceVille(pays, villes[i], 'social', delta).catch(function () {});
    }
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Effort renouvelé', 'Nouvelle période de 3 jours. Commandes, réglages et stocks conservés.'
    + (v.penaliteIS ? ' −2 IS dans les trois villes.' : ''), true, true);
  addJournalEntry('Effort de guerre renouvelé pour 3 jours.' + (v.penaliteIS ? ' −2 IS (prolongation préventive).' : ''), 'event-info');
}

async function confirmerArretEffort() {
  const pays = state.country || 'republic';
  const effort = await chargerEffortGuerre(pays);
  const v = verdictTerminerEffortDeGuerre(state.poste?.id, effort, Date.now());
  if (!v.ok) { showToast('Impossible', v.raison === 'pas_actif' ? 'Aucun Effort de guerre actif.' : 'Réservé au Président.', false); return; }

  await cloturerEffortGuerre(pays, effort, state.char?.name || 'Le Président', 'decision');
  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Effort de guerre arrêté', 'Matières libérées, reliquats annulés. Les marchandises produites restent acquises.', true, true);
  addJournalEntry('Effort de guerre arrêté. Réserve libérée, reliquats annulés.', 'event-info');
}

// CLOTURE — un seul chemin pour l'arret volontaire et pour l'expiration, afin que les deux
// produisent exactement le meme etat. Ordre volontaire : on libere d'abord la matiere (le plus
// visible pour les joueurs), on annule ensuite les reliquats, on clot enfin le drapeau.
async function cloturerEffortGuerre(pays, effort, auteur, motif) {
  await appliquerReserveMilitaire(pays, 0).catch(function () {});

  const commandes = (typeof sbGetCommandesMilitaires === 'function')
    ? await sbGetCommandesMilitaires(pays, 'en_cours').catch(function () { return []; })
    : [];
  for (let i = 0; i < commandes.length; i++) {
    await sbAnnulerCommandeMilitaire(commandes[i].id).catch(function () {});
  }

  const ferme = fermerEffortDeGuerre(effort, auteur, Date.now(), motif || 'decision');
  await ecrireEffortGuerre(pays, ferme);
  return ferme;
}

// ---------------------------------------------------------------------------
// 6. TABLEAU DE CONTROLE DU MINISTRE DE LA GUERRE
// ---------------------------------------------------------------------------
function ouvrirTableauEffortMinistre() {
  if (state.poste?.id !== 'min_def') {
    showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false);
    return;
  }
  rafraichirCacheEffortGuerre().then(function () {
    if (!effortGuerreEstActif()) {
      showToast('Effort inactif', 'Le tableau de contrôle n\'est disponible que pendant un Effort de guerre décrété par le Président.', false);
      return;
    }
    rendreTableauEffortMinistre();
  });
}

async function rendreTableauEffortMinistre() {
  const pays = state.country || 'republic';
  const effort = effortGuerreCache();
  const p = prioritesEffort(effort);
  const res = await totauxReserveMilitaire(pays);
  const commandes = await sbGetCommandesMilitaires(pays, 'en_cours').catch(function () { return []; });
  const cur = COUNTRIES[pays]?.cur || 'FR';

  let html = '<div style="padding:1rem">';

  // --- Curseurs -------------------------------------------------------------
  html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.6rem;line-height:1.6">Réglages gratuits, modifiables à tout moment. Ils n\'agissent que sur l\'avenir : rien n\'est recalculé rétroactivement.</div>';
  html += blocCurseur('ravitaillement', 'Priorité ravitaillement', p.ravitaillement,
    'Part du stock alimentaire national achetée chaque nuit et acheminée à la caserne.');
  html += blocCurseur('production', 'Priorité production militaire', p.production,
    'Part des matières nationales réservée à l\'armement. Les matières réservées sont indisponibles aux achats civils ET aux chantiers.');
  html += '<button onclick="confirmerCurseursEffort()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;margin-bottom:1rem">Appliquer les réglages (0 PA)</button>';

  // --- Stock deja livre a la caserne ---------------------------------------
  html += htmlStockArmurerieMilitaire(await chargerStockMilitaireCaserne(pays),
                                      'LIVRÉ À L\'ARMURERIE DE LA CASERNE');

  // --- Reserve reellement bloquee ------------------------------------------
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;letter-spacing:.08em;margin-bottom:.4rem">MATIÈRES RÉELLEMENT RÉSERVÉES</div>';
  const cles = Object.keys(res.totaux);
  if (!cles.length) {
    html += '<div style="font-size:.76rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Aucune matière réservée.</div>';
  } else {
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem;margin-bottom:.8rem">';
    cles.sort().forEach(function (m) {
      const lbl = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[m]) ? RESSOURCES_ECONOMIE[m].label : m;
      html += '<div style="display:flex;justify-content:space-between;font-size:.78rem;color:#c0b090;padding:.15rem 0">'
           + '<span>' + lbl + '</span><span style="font-variant-numeric:tabular-nums;color:#C9A84C">' + res.totaux[m] + '</span></div>';
    });
    html += '<div style="border-top:1px solid #2a2010;margin-top:.4rem;padding-top:.4rem">';
    res.detail.forEach(function (d) {
      const parts = Object.keys(d.reserve).sort().map(function (m) { return m + ' ' + d.reserve[m]; }).join(' · ');
      html += '<div style="font-size:.68rem;color:#6a5a30">' + d.nom + ' : ' + (parts || '—') + '</div>';
    });
    html += '</div></div>';
  }

  // --- Commande ------------------------------------------------------------
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;letter-spacing:.08em;margin-bottom:.4rem">PASSER UNE COMMANDE</div>';
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.8rem">';
  // Apercu du materiel choisi. La structure du tableau ne change pas : le <select> reste la
  // commande, on lui adjoint simplement l'illustration de la reference selectionnee, qui suit le
  // choix en direct. Le visuel vient de RECETTES_MILITAIRES, la meme source que l'inventaire.
  const premier = PRODUITS_MILITAIRES[0];
  html += '<div style="width:100%;height:190px;overflow:hidden;background:#0a0805;border:1px solid #2a2010;margin-bottom:.4rem">';
  html += '<img id="cmd-mil-visuel" src="' + (recetteMilitaire(premier).imageUrl || '') + '" alt="" '
       + 'style="width:100%;height:100%;object-fit:contain;display:block"/>';
  html += '</div>';
  html += '<select id="cmd-mil-produit" onchange="majVisuelCommandeMilitaire(this.value)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.82rem;margin-bottom:.4rem;box-sizing:border-box">';
  PRODUITS_MILITAIRES.forEach(function (id) {
    const d = detailCoutRevientMilitaire(id);
    html += '<option value="' + id + '">' + d.label + ' — coût de revient ' + d.coutRevientUnitaire + ' ' + cur + '/unité</option>';
  });
  html += '</select>';
  html += '<input id="cmd-mil-qte" type="number" min="1" value="10" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;box-sizing:border-box;margin-bottom:.4rem"/>';
  html += '<button onclick="confirmerCommandeMilitaire()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.45rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Commander (0 PA)</button>';
  html += '<div style="font-size:.68rem;color:#6a5a30;margin-top:.4rem;line-height:1.5">La commande est répartie entre les trois armureries du pays et produite automatiquement, nuit après nuit, au rythme des matières réservées et de la caisse de la caserne.</div>';
  html += '</div>';

  // --- Commandes en attente ------------------------------------------------
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;letter-spacing:.08em;margin-bottom:.4rem">COMMANDES EN COURS</div>';
  if (!commandes.length) {
    html += '<div style="font-size:.76rem;color:#8a8060;font-style:italic">Aucune commande en attente.</div>';
  } else {
    commandes.forEach(function (c) {
      const r = recetteMilitaire(c.produit);
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem;margin-bottom:.4rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + (r ? r.label : c.produit) + '</div>';
      html += '<div style="font-size:.72rem;color:#8a8060;margin:.2rem 0">Produit ' + c.quantite_produite + ' / ' + c.quantite_demandee
           + ' — reliquat ' + (c.quantite_demandee - c.quantite_produite) + '</div>';
      html += '<button onclick="confirmerAnnulationCommande(\'' + c.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #6a3a20;background:transparent;color:#cc6a44;cursor:pointer">Annuler le reliquat (0 PA)</button>';
      html += '</div>';
    });
  }

  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Effort de guerre — tableau de contrôle';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function blocCurseur(id, libelle, valeur, aide) {
  let h = '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.6rem">';
  h += '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:.3rem">';
  h += '<span style="font-size:.8rem;color:#c0b090">' + libelle + '</span>';
  h += '<span id="curseur-val-' + id + '" style="font-family:Bebas Neue,sans-serif;font-size:.95rem;color:#C9A84C;font-variant-numeric:tabular-nums">' + valeur + ' %</span>';
  h += '</div>';
  h += '<input id="curseur-' + id + '" type="range" min="0" max="100" step="5" value="' + valeur + '" '
    + 'oninput="document.getElementById(\'curseur-val-' + id + '\').textContent=this.value+\' %\'" '
    + 'style="width:100%;box-sizing:border-box"/>';
  h += '<div style="font-size:.68rem;color:#6a5a30;margin-top:.3rem;line-height:1.5">' + aide + '</div>';
  h += '</div>';
  return h;
}

async function confirmerCurseursEffort() {
  const pays = state.country || 'republic';
  if (state.poste?.id !== 'min_def') { showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false); return; }
  const rav = Math.max(0, Math.min(100, parseInt(document.getElementById('curseur-ravitaillement')?.value || '0', 10)));
  const pro = Math.max(0, Math.min(100, parseInt(document.getElementById('curseur-production')?.value || '0', 10)));

  const effort = await chargerEffortGuerre(pays);
  if (!effortDeGuerreActif(effort, Date.now())) { showToast('Effort inactif', 'L\'Effort de guerre n\'est plus actif.', false); return; }

  const maj = Object.assign({}, effort, { prioriteRavitaillement: rav, prioriteProductionMilitaire: pro });
  await ecrireEffortGuerre(pays, maj);

  // Le curseur de production commande la reserve : a la hausse elle s'etend, a la baisse
  // l'excedent est libere IMMEDIATEMENT. La RPC recalcule la cible entiere, il n'y a donc
  // jamais de reliquat reserve au-dela du nouveau pourcentage.
  const r = await appliquerReserveMilitaire(pays, pro);
  if (!r || r.ok !== true) {
    showToast('Réglages enregistrés', 'Les curseurs sont à jour, mais la réserve n\'a pas pu être recalculée. Elle le sera à la prochaine nuit.', false);
  } else {
    showToast('Réglages appliqués', 'Ravitaillement ' + rav + ' % · Production ' + pro + ' %.', true);
  }
  addJournalEntry('Effort de guerre : ravitaillement ' + rav + ' %, production militaire ' + pro + ' %.', 'event-info');
  rendreTableauEffortMinistre();
}

// Bascule l'apercu du tableau de commande sur la reference choisie. Presentation pure :
// aucune lecture d'etat, aucune ecriture, aucun effet sur la commande elle-meme.
function majVisuelCommandeMilitaire(produit) {
  const img = document.getElementById('cmd-mil-visuel');
  const r = recetteMilitaire(produit);
  if (img && r) { img.src = r.imageUrl || ''; img.alt = r.label; }
}

async function confirmerCommandeMilitaire() {
  const pays = state.country || 'republic';
  if (state.poste?.id !== 'min_def') { showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false); return; }
  const produit = document.getElementById('cmd-mil-produit')?.value;
  const qte = parseInt(document.getElementById('cmd-mil-qte')?.value || '0', 10);
  if (!recetteMilitaire(produit)) { showToast('Produit inconnu', '', false); return; }
  if (!(qte > 0)) { showToast('Quantité invalide', 'Indiquez une quantité supérieure à zéro.', false); return; }

  const effort = await chargerEffortGuerre(pays);
  if (!effortDeGuerreActif(effort, Date.now())) { showToast('Effort inactif', 'Aucune commande militaire hors Effort de guerre.', false); return; }

  const ok = await sbCreerCommandeMilitaire({
    id: 'cmd-' + Date.now() + '-' + Math.floor(Math.random() * 10000),
    pays: pays, produit: produit, quantite_demandee: qte,
    ministre: state.char?.name || null
  }).catch(function () { return null; });
  if (!ok) { showToast('Commande refusée', 'La commande n\'a pas pu être enregistrée. Rien n\'a été engagé.', false); return; }

  showToast('Commande passée', qte + ' × ' + recetteMilitaire(produit).label + '. Production automatique par les trois armureries.', true, true);
  addJournalEntry('Commande militaire : ' + qte + ' × ' + recetteMilitaire(produit).label + '.', 'event-info');
  rendreTableauEffortMinistre();
}

async function confirmerAnnulationCommande(id) {
  if (state.poste?.id !== 'min_def') { showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false); return; }
  await sbAnnulerCommandeMilitaire(id).catch(function () {});
  showToast('Reliquat annulé', 'Ce qui a déjà été produit, payé et livré reste acquis.', true);
  addJournalEntry('Reliquat d\'une commande militaire annulé.', 'event-info');
  rendreTableauEffortMinistre();
}

// ---------------------------------------------------------------------------
// 7. ARMURERIE MILITAIRE DE LA CASERNE — RETRAIT, SUBTILISATION
// ---------------------------------------------------------------------------
async function chargerStockMilitaireCaserne(pays) {
  const bn = await chargerBudgetNational(pays || 'republic').catch(function () { return null; });
  const s = (bn && bn.stockArmurerieMilitaire && typeof bn.stockArmurerieMilitaire === 'object')
    ? bn.stockArmurerieMilitaire : {};
  // Initialisation RETRO-COMPATIBLE : on ne persiste rien ici, on comble seulement les cles
  // absentes pour l'affichage. Aucune ligne n'existe en production avant ce chantier.
  const out = {};
  PRODUITS_MILITAIRES.forEach(function (p) { out[p] = Math.max(0, Number(s[p]) || 0); });
  return out;
}

// VISIBILITE DES STOCKS MILITAIRES — BRIQUE UNIQUE (13 septembre 2026).
// Les quantites disponibles des trois produits sont visibles par le Lieutenant, le Capitaine, le
// Commandant et le Ministre de la Guerre. VOIR N'EST PAS RETIRER : cette fonction ne rend que du
// texte, et les deux ordres de retrait restent gardes par requiresPost:'lieutenant' (data.js) ET
// revalides cote serveur par militaire_retrait, qui refuse tout poste autre que lieutenant.
// Un seul rendu partage, pour que les quatre ecrans ne puissent pas diverger.
function htmlStockArmurerieMilitaire(stock, titre) {
  let h = '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.6rem">';
  h += '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#e0d5b8;letter-spacing:.06em;margin-bottom:.4rem">'
     + (titre || 'ARMURERIE MILITAIRE — STOCK') + '</div>';
  PRODUITS_MILITAIRES.forEach(function (id) {
    const r = recetteMilitaire(id);
    const q = Math.max(0, Number((stock || {})[id]) || 0);
    h += '<div style="display:flex;justify-content:space-between;font-size:.78rem;padding:.15rem 0;color:'
      + (q > 0 ? '#c0b090' : '#6a5a30') + '">'
      + '<span>' + r.label + '</span>'
      + '<span style="font-variant-numeric:tabular-nums;color:' + (q > 0 ? '#C9A84C' : '#6a5a30') + '">' + q + '</span></div>';
  });
  h += '</div>';
  return h;
}

// Bloc pret a l'emploi pour les ecrans qui n'ont pas deja charge le stock.
async function blocStockArmurerieMilitaire(pays, titre) {
  const stock = await chargerStockMilitaireCaserne(pays || 'republic').catch(function () { return {}; });
  return htmlStockArmurerieMilitaire(stock, titre);
}

// La section du lieutenant, retrouvee par la MEME regle que partout ailleurs dans le projet :
// c'est section.lieutenantNom qui fait foi, jamais state.poste.sectionId.
async function sectionDuJoueurLieutenant() {
  if (state.poste?.id !== 'lieutenant' || typeof sbGetCompagnies !== 'function') return null;
  const compagnies = await sbGetCompagnies(state.country || 'republic').catch(function () { return []; });
  const compagnie = (compagnies || []).find(function (c) { return c.id === state.poste.compagnieId; });
  if (!compagnie) return null;
  const section = (compagnie.sections || []).find(function (s) { return s.lieutenantNom === state.char?.name; });
  return section || null;
}

function doRetirerArmesMilitaires() { ouvrirRetraitMilitaire(['arme_de_poing', 'mitraillette'], 'Retirer des armes'); }
function doRetirerExplosifsMilitaires() { ouvrirRetraitMilitaire(['explosif_militaire'], 'Retirer des explosifs'); }

async function ouvrirRetraitMilitaire(produits, titre) {
  if (state.poste?.id !== 'lieutenant') {
    showToast('Accès refusé', 'Le retrait de matériel est réservé au Lieutenant chef de section.', false);
    return;
  }
  const pays = state.country || 'republic';
  const stock = await chargerStockMilitaireCaserne(pays);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.76rem;color:#8a8060;font-style:italic;margin-bottom:.8rem;line-height:1.6">'
       + 'Retrait sur le stock réel de l\'armurerie militaire. Gratuit, sans coût d\'action. '
       + 'Vous distribuez ensuite vous-même le matériel à vos hommes.'
       + '</div>';
  // Le chef de section voit TOUT l'etat du magasin, pas seulement ce qu'il retire ici.
  html += htmlStockArmurerieMilitaire(stock);
  let quelqueChose = false;
  produits.forEach(function (id) {
    const r = recetteMilitaire(id);
    const dispo = stock[id] || 0;
    if (dispo > 0) quelqueChose = true;
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#e0d5b8">' + r.label + ' — stock : ' + dispo + '</div>';
    html += '<input id="retrait-qte-' + id + '" type="number" min="0" max="' + dispo + '" value="0" '
         + (dispo > 0 ? '' : 'disabled ')
         + 'style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;box-sizing:border-box;margin:.4rem 0"/>';
    html += '<button ' + (dispo > 0 ? '' : 'disabled ') + 'onclick="confirmerRetraitMilitaire(\'' + id + '\')" '
         + 'style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid '
         + (dispo > 0 ? '#8a6a20' : '#2a2010') + ';background:transparent;color:' + (dispo > 0 ? '#C9A84C' : '#5a4a28') + ';cursor:' + (dispo > 0 ? 'pointer' : 'not-allowed') + '">Retirer</button>';
    html += '</div>';
  });
  if (!quelqueChose) {
    html += '<div style="font-size:.76rem;color:#8a6a4a;font-style:italic">L\'armurerie est vide. Seul un Effort de guerre permet de la réapprovisionner.</div>';
  }
  html += '<div style="font-size:.68rem;color:#6a5a30;margin-top:.6rem;line-height:1.5">Chaque retrait est inscrit au registre réglementaire (lot, quantité, jour, responsable, section). Le registre s\'arrête à vous : la distribution à vos hommes n\'y figure pas.</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRetraitMilitaire(produit) {
  const pays = state.country || 'republic';
  const r = recetteMilitaire(produit);
  if (!r) return;
  const qte = parseInt(document.getElementById('retrait-qte-' + produit)?.value || '0', 10);
  if (!(qte > 0)) { showToast('Quantité invalide', 'Indiquez une quantité supérieure à zéro.', false); return; }

  const section = await sectionDuJoueurLieutenant();
  // FAIL-CLOSED : la RPC est l'autorite. Elle revalide le poste, la presence physique et le
  // stock, decremente et inscrit au registre dans la MEME transaction.
  const res = await sbMilitaireRetrait(pays, produit, qte, state.char?.name || '',
                                       section ? section.id : null, state.day || 1);
  if (!res || res.ok !== true) {
    showToast('Retrait impossible', libelleRefusMilitaire(res), false);
    return;
  }

  // L'objet ne rejoint l'inventaire qu'APRES la sortie de stock effective : jamais d'unite
  // creee de rien, jamais d'unite perdue entre les deux.
  const lots = Array.isArray(res.lots) ? res.lots : [];
  let poses = 0;
  lots.forEach(function (l) {
    const n = Math.max(0, Number(l.qte) || 0);
    for (let i = 0; i < n; i++) { if (poserObjetMilitaire(produit, l.lot)) poses++; }
  });

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(function () {});
  showToast('Matériel retiré', poses + ' × ' + r.label + ' — inscrit au registre.', true, true);
  addJournalEntry('Retrait réglementaire : ' + poses + ' × ' + r.label + ' (registre de l\'armurerie militaire).', 'event-info');
}

// Objet d'inventaire militaire. Les armes gardent type:'arme' pour rester fonctionnellement des
// armes partout ailleurs dans le jeu ; ce qui les distingue est sousType:'militaire' et le lot,
// qui voyagent avec l'objet -- donc survivent au don, au depot, au ramassage et au vol.
function poserObjetMilitaire(produit, lot) {
  const r = recetteMilitaire(produit);
  if (!r) return false;
  if (!state.inventory) state.inventory = [];
  const objet = {
    id: 'mil-' + Date.now() + '-' + Math.floor(Math.random() * 100000),
    type: r.typeObjet, sousType: r.sousType,
    origineMilitaire: true, lot: lot || 'legacy', produitMilitaire: produit,
    name: r.label, icon: r.icon, legal: true,
    imageUrl: r.imageUrl || null,
    desc: r.desc + ' Lot ' + (lot || 'legacy') + '.'
  };
  if (typeof addToInventory === 'function') return addToInventory(objet, { automatique: true }) > 0;
  state.inventory.push(objet);
  return true;
}

function libelleRefusMilitaire(res) {
  const raison = res && res.raison;
  if (!res) return 'Le serveur n\'a pas répondu. Rien n\'a été retiré.';
  if (raison === 'stock_insuffisant') return 'Le stock de l\'armurerie ne le permet pas (' + (res.stock || 0) + ' en magasin).';
  if (raison === 'pas_sur_place') return 'Vous devez être physiquement à la caserne.';
  if (raison === 'pas_chef_de_section') return 'Réservé au Lieutenant chef de section.';
  if (raison === 'quantite_invalide') return 'Quantité invalide.';
  return 'Opération refusée.';
}

// ---------------------------------------------------------------------------
// 8. « MANGER SA RATION »
// ---------------------------------------------------------------------------
// Ouvert a TOUT PJ physiquement present a la caserne, quel que soit son statut. 0 PA, 0 FR,
// +2 PA, une fois par jour. Le marqueur quotidien, la consommation de la ration (ou la
// fabrication automatique d'un lot de 10) et le gain de PA sont poses par la MEME transaction
// serveur : un joueur ne peut pas gagner de PA sans avoir reellement mange une ration.
// Reprend le precedent de la clinique privee (doSoinCliniquePrivee) pour le +2 PA et le marqueur.
async function doMangerRation() {
  const pays = state.country || 'republic';
  const paMax = (typeof PA_MAX === 'number') ? PA_MAX : 30;
  const res = await sbRefectoireRepas(pays, state.char?.name || '', state.day || 1, paMax, 2);
  if (!res || res.ok !== true) {
    const raison = res && res.raison;
    if (raison === 'deja_mange') showToast('Déjà servi', 'Une seule ration par jour et par personne.', false);
    else if (raison === 'ingredients_insuffisants') showToast('Réfectoire vide', 'Plus aucune ration, et pas de quoi en préparer. Le ravitaillement dépend de l\'Effort de guerre.', false);
    else if (raison === 'pas_sur_place') showToast('Impossible', 'Vous devez être à la caserne.', false);
    else showToast('Impossible', 'Le réfectoire n\'a rien pu servir.', false);
    return;
  }
  state.pa = res.pa;
  if (!state.char.stats) state.char.stats = {};
  state.char.stats.repasCaserneJour = state.day || 1;
  updateUI();
  showToast('Ration avalée', '+2 PA.' + (res.fabrique ? ' Un lot de rations vient d\'être préparé.' : '')
    + ' Reste ' + res.rations + ' ration(s).', true, true);
  addJournalEntry('Ration prise au réfectoire de la caserne. +2 PA.', 'event-good');
}
