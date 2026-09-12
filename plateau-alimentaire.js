// =====================
// PLATEAU-ALIMENTAIRE.JS — COMMERCE ALIMENTAIRE PJ (Lot 4.2)
// =====================
// CE FICHIER N'EST PAS UN MOTEUR. C'est la CONFIGURATION de la famille 'alimentaire' du moteur
// generique (plateau-commerce.js), plus la seule regle qui lui soit propre : le barême prix -> effet.
//
// Il n'existe donc toujours qu'un seul moteur de commerce. Boulangerie, boucherie, restaurant,
// salon de the, traiteur ne sont pas cinq mecaniques : ce sont cinq CATALOGUES. C'est le catalogue
// cree par le joueur qui donne son identite reelle a son commerce, et rien d'autre.
//
// CE QU'IL REUTILISE, sans le reecrire (plateau-commerce.js) :
//   coutRevientUnitaire   cout matieres + valeur travail, divise par le rendement
//   valeurTravailRecette  valeur comptable du travail
//   prixMaximumPJ         le plafond x4 GENERIQUE -- aucun multiplicateur alimentaire concurrent
//   verdictPrixVente      le verdict de prix
//   FAMILLES_COMMERCE.alimentaire   sous-types, cibles d'effet, individualisation
//
// CONTRAT : pur. Aucune ecriture, aucun DOM, aucun reseau, aucune dependance a state.
//
// ---------------------------------------------------------------------------
// CE QUE L'AUDIT DU 7 SEPTEMBRE 2026 A ETABLI, ET QUI COMMANDE TOUT CE FICHIER
// ---------------------------------------------------------------------------
// LE BAREME PRIX -> EFFET N'EXISTAIT PAS. Ni table, ni palier, ni seuil : dans le systeme
// historique (RECETTES_ALIMENTAIRES, plateau-actions-illegales-rumeurs.js) les effets sont ECRITS
// EN DUR recette par recette, et le prix en est independant. Le Menu gastronomique du Republica a
// 120 FR donne exactement les memes effets (hp 10, moral 1, paDiffere 3) que le menu PSM a ~30 FR,
// et les quatre boissons ont ete deliberement uniformisees a +2 Moral quel que soit leur prix.
//
// CONSEQUENCE DIRECTE : ce barême ne peut PAS etre applique retroactivement aux 19 recettes PNJ
// existantes sans changer leur equilibre. Il ne vaut donc QUE pour les references creees par un PJ
// dans un fonds de famille 'alimentaire'. Les deux systemes coexistent, et c'est voulu.
//
// LES STATS REELLES, verifiees : state.hp (Sante), state.moral (Moral), state.pa / state.paMax
// (Energie), state.bonusPaProchainDormir (PA differe). Il n'existe aucun state.char.sante ni
// state.energie -- ce fichier ne nomme donc jamais autre chose que hp, moral, pa et paDiffere.

// ---------------------------------------------------------------------------
// 1. CATEGORIES DE MATIERES ALIMENTAIRES
// ---------------------------------------------------------------------------
// LA RECETTE EST ABSTRAITE PAR LA DIVERSITE DES CATEGORIES, jamais par des quantites. Le moteur
// n'a pas a connaitre des grammes de farine, de beurre ou d'abricots : une "Tarte aux abricots"
// declare Cereales + Fruits et legumes + Sucre + Matieres grasses, et cela suffit a etablir un
// cout et une exigence de qualite.
//
// UNE CATEGORIE = UNE UNITE DE MATIERE. Chaque categorie retenue consomme une unite de la
// ressource correspondante et en ajoute le cout. Une matiere au-dela du minimum est donc
// autorisee et coute REELLEMENT plus cher -- c'est le seul levier qui empeche de declarer des
// categories gratuitement pour faire joli.
//
// 'ressource' pointe la cle reelle de RESSOURCES_ECONOMIE (data.js) et de stockMatieres :
// AUCUNE matiere n'est dupliquee sous un autre nom, les quatre premieres existent deja.
//
// ⚠ ARBITRAGE EN ATTENTE — les trois dernieres n'existent PAS dans RESSOURCES_ECONOMIE. Les
// ajouter suppose de leur donner un prixBase et un prixFournisseur, c'est-a-dire une decision
// economique qui n'a pas ete prise. 'ressource: null' les rend donc INUTILISABLES : le moteur
// refuse toute reference qui en contient (raison 'matiere_non_tarifee'), plutot que d'inventer un
// prix. Le jour de l'arbitrage, une seule ligne change ici et une entree s'ajoute a
// RESSOURCES_ECONOMIE -- rien d'autre.
const CATEGORIES_MATIERES_ALIMENTAIRES = {
  cereales:                 { label: 'Céréales',                 ressource: 'cereales' },
  fruits_legumes:           { label: 'Fruits et légumes',        ressource: 'fruits_legumes' },
  viande:                   { label: 'Viande',                   ressource: 'viande' },
  poisson:                  { label: 'Produits de la mer',       ressource: 'poisson' },
  sucre:                    { label: 'Sucre',                    ressource: null },
  matieres_grasses:         { label: 'Matières grasses',         ressource: null },
  produits_pharmaceutiques: { label: 'Produits pharmaceutiques', ressource: null }
};

function categorieAlimentaireConnue(cle) {
  return Object.prototype.hasOwnProperty.call(CATEGORIES_MATIERES_ALIMENTAIRES, cle);
}

function categorieAlimentaireTarifee(cle) {
  const c = CATEGORIES_MATIERES_ALIMENTAIRES[cle];
  return !!(c && c.ressource);
}

function categoriesAlimentairesDisponibles() {
  return Object.keys(CATEGORIES_MATIERES_ALIMENTAIRES).filter(categorieAlimentaireTarifee);
}

// Categories distinctes, dans l'ordre du registre, sans doublon ni valeur inconnue. Un joueur qui
// coche deux fois la meme categorie n'obtient pas deux unites : ce serait un contournement du
// minimum de diversite.
function categoriesDistinctes(liste) {
  const vues = {};
  return (Array.isArray(liste) ? liste : []).filter(function (c) {
    if (typeof c !== 'string' || !categorieAlimentaireConnue(c) || vues[c]) return false;
    vues[c] = true;
    return true;
  });
}

// ---------------------------------------------------------------------------
// 2. EXIGENCE DE DIVERSITE MINIMALE
// ---------------------------------------------------------------------------
// MECANISME, PAS ENCYCLOPEDIE. Le moteur verifie un NOMBRE minimal de categories distinctes, et
// rien d'autre : il ne sait pas ce qu'est une tarte, et n'a pas a le savoir.
//
// ⚠ ARBITRAGE EN ATTENTE — quel sous-type exige 2 ou 3 categories reste a decider. La table est
// donc VIDE et tous les sous-types retombent sur le defaut. Le mecanisme, lui, est complet : y
// ajouter { alicament: 3 } suffit a l'activer, sans toucher une ligne de moteur.
const MIN_CATEGORIES_PAR_SOUS_TYPE = {};
const MIN_CATEGORIES_DEFAUT = 1;

function minimumCategories(sousType) {
  const v = MIN_CATEGORIES_PAR_SOUS_TYPE[sousType];
  return Math.max(1, Math.floor(Number(v) || 0) || MIN_CATEGORIES_DEFAUT);
}

// ---------------------------------------------------------------------------
// 3. MAIN-D'OEUVRE
// ---------------------------------------------------------------------------
// EN REPUBLIA, LE COUT MINIMAL EST DE 50 FR PAR LOT. Ce n'est pas une valeur inventee : c'est
// exactement COUT_MAIN_OEUVRE_PA_ALIMENTAIRE (plateau-actions-illegales-rumeurs.js), le prix d'un
// PA de travail deja pratique par tous les commerces du jeu. On le generalise, on ne le remplace
// pas.
//
// PORTEE PAR PAYS des l'origine, pour qu'un autre empire puisse un jour avoir son propre minimum
// sans qu'aucune ligne de moteur ne bouge. Les trois autres pays retombent aujourd'hui sur le
// defaut, qui est la valeur historique globale -- ce n'est donc pas un choix, c'est l'existant.
//
// ⚠ ARBITRAGE EN ATTENTE : un minimum different pour narco / soviet / khalija.
const MAIN_OEUVRE_MINIMUM_PAR_LOT = { republic: 50 };
const MAIN_OEUVRE_MINIMUM_DEFAUT = 50;

function mainOeuvreMinimum(pays) {
  const v = MAIN_OEUVRE_MINIMUM_PAR_LOT[pays];
  return Math.max(0, Math.floor(Number(v) || 0) || MAIN_OEUVRE_MINIMUM_DEFAUT);
}

// Librement modifiable A LA HAUSSE, jamais a la baisse. Le serveur applique la meme borne : le
// formulaire n'est jamais la garantie.
function verdictMainOeuvre(pays, montant) {
  const min = mainOeuvreMinimum(pays);
  const m = Math.floor(Number(montant));
  if (!isFinite(m)) return { ok: false, raison: 'main_oeuvre_invalide', minimum: min };
  if (m < min) return { ok: false, raison: 'main_oeuvre_sous_minimum', minimum: min };
  return { ok: true, raison: null, montant: m, minimum: min };
}

// ---------------------------------------------------------------------------
// 4. COUT DU LOT ET COUT DE REVIENT
// ---------------------------------------------------------------------------
// cout du lot        = cout des matieres + cout de main-d'oeuvre
// cout de revient    = cout du lot / nombre de portions
//
// LE NOMBRE DE PORTIONS EST LE LEVIER ECONOMIQUE CENTRAL, et il appartient au commercant. Aucune
// plage de rendement n'est imposee : seuls des garde-fous techniques ecartent 0, le negatif, NaN
// et l'infini. Plus de portions abaisse le cout unitaire, donc le plafond x4, donc la tranche
// d'effet -- et inversement. La regulation est entierement portee par cet enchainement.
//
// Le cout matiere reutilise la doctrine deja en place : le cout MOYEN REELLEMENT PAYE
// (coutMoyenMatieres), jamais un cours theorique.
const PORTIONS_MAXIMUM_TECHNIQUE = 100000;   // garde-fou, pas une regle de jeu

function verdictPortions(portions) {
  const n = Number(portions);
  if (!isFinite(n)) return { ok: false, raison: 'portions_invalides' };
  const p = Math.floor(n);
  if (p <= 0) return { ok: false, raison: 'portions_invalides' };
  if (p > PORTIONS_MAXIMUM_TECHNIQUE) return { ok: false, raison: 'portions_absurdes', maximum: PORTIONS_MAXIMUM_TECHNIQUE };
  return { ok: true, raison: null, portions: p };
}

// Une categorie = une unite de la ressource correspondante, au cout moyen paye par le fonds.
function coutMatieresAlimentaire(categories, coutMoyenMatieres) {
  const couts = coutMoyenMatieres || {};
  const cats = categoriesDistinctes(categories);
  let total = 0;
  for (let i = 0; i < cats.length; i++) {
    if (!categorieAlimentaireTarifee(cats[i])) return null;   // fail-closed, jamais un prix invente
    const res = CATEGORIES_MATIERES_ALIMENTAIRES[cats[i]].ressource;
    total += Math.max(0, Number(couts[res]) || 0);
  }
  return total;
}

// Traduit les categories en 'matieres' au format attendu par le moteur generique : une unite par
// categorie. C'est ce qui permet a coutRevientUnitaire et a la production existante de traiter une
// reference alimentaire sans savoir qu'elle est alimentaire.
function matieresDepuisCategories(categories) {
  return categoriesDistinctes(categories).reduce(function (acc, c) {
    const res = CATEGORIES_MATIERES_ALIMENTAIRES[c].ressource;
    if (res) acc[res] = 1;
    return acc;
  }, {});
}

function coutLotAlimentaire(categories, coutMoyenMatieres, mainOeuvre) {
  const mat = coutMatieresAlimentaire(categories, coutMoyenMatieres);
  if (mat === null) return null;
  return mat + Math.max(0, Math.floor(Number(mainOeuvre) || 0));
}

function coutRevientAlimentaire(categories, coutMoyenMatieres, mainOeuvre, portions) {
  const vp = verdictPortions(portions);
  if (!vp.ok) return null;
  const lot = coutLotAlimentaire(categories, coutMoyenMatieres, mainOeuvre);
  if (lot === null) return null;
  return lot / vp.portions;
}

// ---------------------------------------------------------------------------
// 5. BAREME PRIX -> EFFET
// ---------------------------------------------------------------------------
// L'EFFET N'EST JAMAIS CHOISI PAR LE JOUEUR. Il decoule du prix de vente, et de lui seul. C'est ce
// qui rend le plafond x4 et le nombre de portions structurants : on ne peut pas vendre cher un
// produit qu'on a rendu bon marche a produire.
//
// ⚠ CE BAREME EST INCOMPLET, ET C'EST DELIBERE. L'audit a etabli qu'aucun barême prix -> effet
// n'existait dans le jeu ; les deux seuls paliers ci-dessous sont ceux qui ont ete EXPLICITEMENT
// confirmes. Les tranches au-dela de 15 FR n'ont jamais ete arbitrees, et les extrapoler --
// meme en suivant la regularite apparente (+5 FR, +3 points) -- serait inventer de l'equilibrage.
//
// COMPORTEMENT AU-DELA DU DERNIER PALIER : l'effet du dernier palier defini s'applique, et le
// verdict porte baremeIncomplet: true. C'est le choix CONSERVATEUR -- aucun bonus invente n'est
// accorde -- et il rend le manque visible dans l'interface au lieu de le cacher. Il cree
// temporairement un plateau d'effet au-dessus de 15 FR : c'est precisement ce que l'arbitrage
// devra corriger, et le drapeau est la pour qu'on ne l'oublie pas.
//
// EN DESSOUS DU PREMIER PALIER : aucun effet. Ce n'est pas une invention, c'est l'absence de
// palier -- un produit a 3 FR ne nourrit personne.
const BAREME_EFFETS_ALIMENTAIRES = [
  { prixMin: 5,  prixMax: 9.99,  effets: { hp: 5, moral: 5 } },
  { prixMin: 10, prixMax: 14.99, effets: { hp: 8, moral: 8 } }
];

function effetAlimentairePourPrix(prix) {
  const p = Number(prix);
  if (!isFinite(p) || p <= 0) {
    return { effets: {}, palier: null, baremeIncomplet: false, raison: 'prix_invalide' };
  }
  if (p < BAREME_EFFETS_ALIMENTAIRES[0].prixMin) {
    return { effets: {}, palier: null, baremeIncomplet: false, raison: 'sous_le_premier_palier' };
  }
  for (let i = 0; i < BAREME_EFFETS_ALIMENTAIRES.length; i++) {
    const t = BAREME_EFFETS_ALIMENTAIRES[i];
    if (p >= t.prixMin && p <= t.prixMax) {
      return { effets: Object.assign({}, t.effets), palier: i, baremeIncomplet: false, raison: null };
    }
  }
  // Au-dela du dernier palier defini : effet du dernier, et le manque est signale.
  const dernier = BAREME_EFFETS_ALIMENTAIRES[BAREME_EFFETS_ALIMENTAIRES.length - 1];
  return { effets: Object.assign({}, dernier.effets), palier: BAREME_EFFETS_ALIMENTAIRES.length - 1,
           baremeIncomplet: true, raison: 'palier_non_arbitre' };
}

// Le prix a partir duquel la tranche change : sert a l'interface pour montrer immediatement au
// commercant ce que son prix lui achete, et ce qu'un franc de plus lui apporterait.
function prochainPalierAlimentaire(prix) {
  const p = Number(prix) || 0;
  for (let i = 0; i < BAREME_EFFETS_ALIMENTAIRES.length; i++) {
    if (p < BAREME_EFFETS_ALIMENTAIRES[i].prixMin) return BAREME_EFFETS_ALIMENTAIRES[i];
  }
  return null;
}

// ---------------------------------------------------------------------------
// 6. CREATION D'UNE REFERENCE ALIMENTAIRE
// ---------------------------------------------------------------------------
// NIVEAU 1 DE LA VALIDATION : tout ce qui est objectivement verifiable est traite ici, sans IA.
// Minimum de categories, categories autorisees et tarifees, salaire minimum, rendement, cout,
// plafond x4, prix, effet. Aucune de ces verifications n'a besoin de comprendre du francais.
const REFERENCE_ALIMENTAIRE_VERSION = 1;
const NOM_REFERENCE_LONGUEUR_MAX = 80;
const DESCRIPTION_REFERENCE_LONGUEUR_MAX = 400;

function verdictCreationReferenceAlimentaire(saisie, fonds, contexte) {
  const s = saisie || {};
  const f = fonds || {};
  const ctx = contexte || {};
  const pays = ctx.pays || f.country || 'republic';

  if (familleDe(f) !== 'alimentaire') return { ok: false, raison: 'fonds_non_alimentaire' };

  const nom = (typeof s.nom === 'string') ? s.nom.trim() : '';
  if (!nom) return { ok: false, raison: 'nom_requis' };
  if (nom.length > NOM_REFERENCE_LONGUEUR_MAX) return { ok: false, raison: 'nom_trop_long' };
  const description = (typeof s.description === 'string') ? s.description.trim() : '';
  if (description.length > DESCRIPTION_REFERENCE_LONGUEUR_MAX) {
    return { ok: false, raison: 'description_trop_longue' };
  }

  // Sous-type : ceux de la famille alimentaire du moteur generique, jamais une liste concurrente.
  const sousType = s.sousType || 'courant';
  if (!sousTypeAutorise('alimentaire', sousType)) return { ok: false, raison: 'sous_type_invalide' };

  const cats = categoriesDistinctes(s.categories);
  const min = minimumCategories(sousType);
  if (cats.length < min) {
    return { ok: false, raison: 'categories_insuffisantes', minimum: min, obtenu: cats.length };
  }
  for (let i = 0; i < cats.length; i++) {
    if (!categorieAlimentaireTarifee(cats[i])) {
      return { ok: false, raison: 'matiere_non_tarifee', categorie: cats[i] };
    }
  }

  const vm = verdictMainOeuvre(pays, s.mainOeuvre);
  if (!vm.ok) return vm;

  const vp = verdictPortions(s.portions);
  if (!vp.ok) return vp;

  const coutMatieres = coutMatieresAlimentaire(cats, f.coutMoyenMatieres);
  if (coutMatieres === null) return { ok: false, raison: 'matiere_non_tarifee' };
  const coutLot = coutMatieres + vm.montant;
  const coutRevient = coutLot / vp.portions;

  const vpr = verdictPrixVente(coutRevient, s.prixVente);
  if (!vpr.ok) return vpr;

  const effet = effetAlimentairePourPrix(vpr.prix);

  return {
    ok: true, raison: null,
    economie: { coutMatieres: coutMatieres, coutMainOeuvre: vm.montant, coutLot: coutLot,
                coutRevient: coutRevient, prixMaximum: prixMaximumPJ(coutRevient), prix: vpr.prix },
    effet: effet,
    reference: {
      version: REFERENCE_ALIMENTAIRE_VERSION,
      famille: 'alimentaire', sousType: sousType,
      nom: nom, description: description || null,
      categories: cats,
      matieres: matieresDepuisCategories(cats),   // format du moteur generique
      heures: 0,                                  // la main-d'oeuvre alimentaire est au LOT
      mainOeuvre: vm.montant,
      produit: vp.portions,
      prixVente: vpr.prix,
      stock: 0, active: true,
      image: (typeof s.image === 'string' && s.image) ? s.image : null,
      statutValidation: 'valide',
      produiteAuMoinsUneFois: false
    }
  };
}

// ---------------------------------------------------------------------------
// 7. FIGEMENT APRES LA PREMIERE PRODUCTION
// ---------------------------------------------------------------------------
// DES QU'UNE UNITE EXISTE, LA RECETTE EST FIGEE. Sans cela, un joueur produirait un stock a bas
// cout puis transformerait retroactivement ce stock en produit economiquement superieur : le stock
// deja en rayon deviendrait autre chose que ce qu'il a coute.
//
// LE PRIX RESTE MODIFIABLE, et c'est necessaire, pas une tolerance : l'effet decoule du prix
// COURANT. Un commercant qui baisse son prix baisse l'effet de ce qu'il vend, immediatement, y
// compris sur le stock deja produit -- ce qui est coherent, puisque c'est le prix paye par le
// client qui determine ce qu'il obtient.
//
// Nom, description et illustration restent editables : ils ne portent aucune propriete mecanique.
const CHAMPS_REFERENCE_FIGES = ['categories', 'matieres', 'sousType', 'famille', 'produit',
                                'mainOeuvre', 'heures', 'version'];
const CHAMPS_REFERENCE_LIBRES = ['nom', 'description', 'image', 'prixVente', 'active'];

function referenceFigee(reference) {
  const r = reference || {};
  return r.produiteAuMoinsUneFois === true || Math.max(0, Number(r.stock) || 0) > 0;
}

function verdictModificationReference(reference, modifications, fonds, contexte) {
  const r = reference || {};
  const m = modifications || {};
  const cles = Object.keys(m);

  for (let i = 0; i < cles.length; i++) {
    if (CHAMPS_REFERENCE_FIGES.indexOf(cles[i]) === -1 && CHAMPS_REFERENCE_LIBRES.indexOf(cles[i]) === -1) {
      return { ok: false, raison: 'champ_inconnu', champ: cles[i] };
    }
  }

  if (referenceFigee(r)) {
    for (let i = 0; i < cles.length; i++) {
      if (CHAMPS_REFERENCE_FIGES.indexOf(cles[i]) !== -1) {
        // Changer la recette impose une NOUVELLE reference : l'ancienne garde son stock et son
        // histoire, la nouvelle part de zero. Rien n'est detruit, rien n'est reecrit.
        return { ok: false, raison: 'reference_figee', champ: cles[i] };
      }
    }
  }

  // Un prix qui change change l'effet : on le revalide contre le plafond x4 du cout de revient
  // REEL de la reference, jamais contre une valeur memorisee.
  if (Object.prototype.hasOwnProperty.call(m, 'prixVente')) {
    const cout = coutRevientReference(r, fonds);
    if (cout === null) return { ok: false, raison: 'cout_indeterminable' };
    const vpr = verdictPrixVente(cout, m.prixVente);
    if (!vpr.ok) return vpr;
    return { ok: true, raison: null, prix: vpr.prix, effet: effetAlimentairePourPrix(vpr.prix),
             coutRevient: cout, prixMaximum: prixMaximumPJ(cout) };
  }

  return { ok: true, raison: null };
}

// Cout de revient d'une reference DEJA CREEE. La main-d'oeuvre alimentaire etant portee au lot
// (mainOeuvre) et non a l'heure, on ne peut pas se contenter de coutRevientUnitaire du moteur
// generique : on lui donne le meme resultat en reinjectant la main-d'oeuvre du lot.
function coutRevientReference(reference, fonds) {
  const r = reference || {};
  const couts = (fonds && fonds.coutMoyenMatieres) || {};
  const produit = Math.max(1, Math.floor(Number(r.produit) || 0));
  if (!isFinite(produit) || produit <= 0) return null;
  const cles = Object.keys(r.matieres || {});
  let mat = 0;
  for (let i = 0; i < cles.length; i++) {
    mat += (Number(r.matieres[cles[i]]) || 0) * (Number(couts[cles[i]]) || 0);
  }
  const travail = Math.max(0, Math.floor(Number(r.mainOeuvre) || 0)) + valeurTravailRecette(r);
  return (mat + travail) / produit;
}

// ---------------------------------------------------------------------------
// 8. CONSOMMATION ET PEREMPTION
// ---------------------------------------------------------------------------
// DECISION DE GAME DESIGN ACTEE : le stock conserve DANS le commerce ne perime pas ; la peremption
// existante ne s'applique qu'aux produits ACHETES A EMPORTER. Aucune peremption supplementaire
// n'est creee -- c'est exactement le mecanisme deja en place (DUREE_FRAICHEUR_ALIMENT_MS, 7 jours
// reels, horodatage item.dateAchat pose a l'achat), et ce fichier ne fait que designer les
// references qui doivent le recevoir.
//
// Magasin et restaurant utilisent LE MEME moteur de production. La seule difference est le mode de
// remise :
//   'sur_place' -- l'effet s'applique immediatement, rien n'entre en inventaire, rien ne perime
//   'emporte'   -- un objet entre en inventaire, horodate, et suit la peremption existante
const MODES_REMISE_ALIMENTAIRE = ['sur_place', 'emporte'];

function modeRemiseValide(mode) {
  return MODES_REMISE_ALIMENTAIRE.indexOf(mode) !== -1;
}

// Ce que la remise doit produire, sans rien executer : c'est l'appelant qui ecrit.
// Le champ 'horodater' est le seul point de contact avec la peremption existante -- il demande de
// poser item.dateAchat, comme le fait deja commanderProduitCommerce pour les aliments de marche.
function verdictRemiseAlimentaire(reference, mode) {
  if (!modeRemiseValide(mode)) return { ok: false, raison: 'mode_remise_invalide' };
  const r = reference || {};
  if (Math.max(0, Number(r.stock) || 0) <= 0) return { ok: false, raison: 'rupture_de_stock' };
  const effet = effetAlimentairePourPrix(r.prixVente);
  if (mode === 'sur_place') {
    return { ok: true, raison: null, mode: mode, effetImmediat: effet.effets,
             entreEnInventaire: false, horodater: false, baremeIncomplet: effet.baremeIncomplet };
  }
  // A EMPORTER : acheter n'est pas utiliser. L'effet ne s'applique PAS a l'achat, il attendra la
  // consommation -- exactement la doctrine du Lot 4.0 et le comportement deja applique aux trois
  // aliments de marche.
  return { ok: true, raison: null, mode: mode, effetImmediat: {}, effetALaConsommation: effet.effets,
           entreEnInventaire: true, horodater: true, baremeIncomplet: effet.baremeIncomplet };
}

// ---------------------------------------------------------------------------
// 9. VALIDATION AUTOMATIQUE -> IA -> ADMIN
// ---------------------------------------------------------------------------
// NIVEAU 1 (automatique) : verdictCreationReferenceAlimentaire ci-dessus. Tout ce qui est
// objectivement verifiable y est traite, sans IA, et c'est la tres grande majorite des cas.
//
// NIVEAU 2 (IA) : SEULEMENT EN CAS D'AMBIGUITE SEMANTIQUE, et jamais pour juger de la gastronomie.
// ETRANGE != AMBIGU != FRAUDULEUX -- avec l'internationalisation, une recette deroutante peut etre
// parfaitement legitime, et une IA qui refuserait un plat inhabituel serait un defaut, pas une
// protection.
//
// ⚠ NON BRANCHE. Le projet n'expose aucun service IA generique reutilisable pour cet usage : ce
// fichier prepare donc le STATUT et le point d'accroche, et rien d'autre. Aucune API n'est
// improvisee. Ce qui reste a brancher est enumere dans le rapport.
const STATUTS_VALIDATION_REFERENCE = ['valide', 'examen_ia', 'examen_admin', 'refuse'];

function statutValidationValide(s) {
  return STATUTS_VALIDATION_REFERENCE.indexOf(s) !== -1;
}

// Une reference n'est vendable que si sa validation est acquise. Tant que le niveau 2 n'est pas
// branche, le niveau 1 suffit et rend 'valide' : aucune reference legitime n'est bloquee par une
// mecanique absente.
function referenceVendable(reference) {
  const r = reference || {};
  return r.active !== false && r.statutValidation === 'valide';
}

// Point d'accroche du niveau 2. Rend TOUJOURS null aujourd'hui : aucun service n'est branche, et
// une heuristique locale bricolee ici serait exactement la "securite cosmetique" a eviter. Le jour
// ou un service existera, c'est cette fonction qui decidera de l'appeler -- et elle seule.
function referenceNecessiteExamenSemantique(reference) {
  return null;   // null = indetermine, pas 'false' : on ne pretend pas avoir examine.
}

// ---------------------------------------------------------------------------
// 10. ILLUSTRATION
// ---------------------------------------------------------------------------
// UNE REFERENCE DOIT FONCTIONNER SANS IMAGE. L'illustration est un confort, jamais une condition :
// aucune generation externe n'est requise, et l'absence d'image ne bloque ni la creation, ni la
// production, ni la vente.
//
// L'audit a montre que l'existant n'a AUCUN repli d'image dans "Consulter la carte" (le bloc n'est
// simplement pas rendu), mais un repli d'icone solide en inventaire ('ti-package'). On reprend ce
// second modele, avec une icone par categorie dominante.
const ICONE_ALIMENTAIRE_DEFAUT = 'ti-tools-kitchen-2';
const ICONES_PAR_CATEGORIE_ALIMENTAIRE = {
  cereales: 'ti-bread', fruits_legumes: 'ti-apple', viande: 'ti-meat', poisson: 'ti-fish',
  sucre: 'ti-candy', matieres_grasses: 'ti-droplet', produits_pharmaceutiques: 'ti-pill'
};

function illustrationReference(reference) {
  const r = reference || {};
  if (typeof r.image === 'string' && r.image) return { type: 'image', valeur: r.image };
  const cats = categoriesDistinctes(r.categories);
  const icone = (cats.length && ICONES_PAR_CATEGORIE_ALIMENTAIRE[cats[0]]) || ICONE_ALIMENTAIRE_DEFAUT;
  return { type: 'icone', valeur: icone };
}
