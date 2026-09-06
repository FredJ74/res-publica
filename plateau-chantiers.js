// =====================
// PLATEAU-CHANTIERS.JS — FORMULES PURES DU MOTEUR GENERIQUE DE CHANTIER (Lot 1.5.6)
// =====================
// Verite de calcul COMMUNE aux deux types de chantier a venir : 'construction' et
// 'reamenagement'. Ce lot ne pose que les formules -- aucun chantier existant n'est migre, aucun
// gameplay n'est modifie, rien n'est ecrit nulle part.
//
// CONTRAT DE CE MODULE, valable pour chacune de ses fonctions :
//   - pure : meme entree, meme sortie, toujours ;
//   - aucune dependance au DOM, a Supabase, a state, ni a l'heure ;
//   - aucune ecriture, aucun effet de bord ;
//   - tolerante aux entrees invalides (null, undefined, NaN, chaines, negatifs) ;
//   - jamais de progression negative, jamais de depassement des bornes logiques.
//
// POURQUOI UN MODULE DEDIE. Les memes chiffres seront lus par l'interface (afficher le cout et la
// duree d'un projet), par le cron (faire avancer un chantier) et par les futurs controles serveur.
// Les ecrire a trois endroits garantirait une divergence ; ils sont donc definis ici une fois, et
// tout le reste est DERIVE -- y compris le panier de materiaux quotidien, qui n'est pas recopie
// mais recalcule a partir du budget materiaux et des prix de reference.

// ---------------------------------------------------------------------------
// CONSTANTES DE REFERENCE
// ---------------------------------------------------------------------------

// Une journee theorique de construction vaut 5 000 FR. Tous les couts de construction en
// decoulent : cout total = duree x 5 000.
const CHANTIER_FR_PAR_JOUR = 5000;

// Repartition d'un budget de chantier. Exprimee en pourcentage ENTIER, jamais en fraction
// decimale : 30000 * 0.3 ne vaut pas exactement 9000 en virgule flottante, alors que
// 30000 * 3 / 10 si.
const CHANTIER_PCT_MATERIAUX = 30;

// Remuneration de reference du travail de chantier, en FR par heure. Une heure RP coutera 1 PA
// au joueur qui la fournit (Lot 1.5.9) -- ce module ne connait ni PA ni joueur.
const CHANTIER_TAUX_HORAIRE = 70;

// Durees theoriques par palier, en jours. Toutes multiples de 3 : les seuils du tiers et des deux
// tiers tombent donc sur des valeurs exactes, sans arrondi.
// NOTE DE NOMMAGE : le cahier des charges dit "immeuble" ; la cle reellement utilisee partout dans
// le code (NIVEAUX_CONSTRUCTION, PALIER_ORDRE, ZONAGE_VILLES, terrains_etat.niveau_construction)
// est 'building'. On conserve 'building' pour ne pas introduire un second vocabulaire.
const DUREES_CONSTRUCTION = {
  hangar: 6,
  commerce_standard: 12,
  commerce_premium: 18,
  building: 24
};

// Seuils de financement CUMULE d'une construction, en pourcentage du cout total. Le joueur peut
// verser 100 % des J0 ; ce sont des minimums pour progresser, pas un echeancier impose.
//   avant le premier tiers  -> 35 %
//   pour franchir le tiers  -> 70 %
//   pour franchir les 2/3   -> 100 %
const SEUILS_FINANCEMENT_CONSTRUCTION = { demarrage: 35, premierTiers: 70, deuxTiers: 100 };

// Sequence deterministe du metal quotidien en construction. La moyenne visee est 33 1/3 par jour ;
// aucune journee ne peut consommer un tiers d'unite, mais toute tranche de 3 jours en consomme
// exactement 100 -- donc 200 sur 6 jours, 400 sur 12, 600 sur 18, 800 sur 24, sans derive ni
// arrondi cumulatif.
const SEQUENCE_METAL_CONSTRUCTION = [33, 33, 34];

// Reamenagement : 10 FR par m2 reellement concerne, 300 m2 traites par jour.
const REAMENAGEMENT_FR_PAR_M2 = 10;
const REAMENAGEMENT_M2_PAR_JOUR = 300;

// Prix de reference des trois materiaux de chantier. Ils DOIVENT rester egaux aux prixBase de
// RESSOURCES_ECONOMIE (data.js) : la lecture se fait dessus quand le catalogue est charge, et ces
// valeurs ne servent que de repli pour garder ce module utilisable seul (tests, futur usage
// serveur). Un test verifie que les deux sources coincident, pour qu'aucune divergence ne
// s'installe silencieusement.
const PRIX_REFERENCE_MATERIAUX = { bois: 5, minerai: 10, metal: 15 };
const MATERIAUX_CHANTIER = ['bois', 'minerai', 'metal'];

// ---------------------------------------------------------------------------
// OUTILS DE ROBUSTESSE
// ---------------------------------------------------------------------------

// Toute entree numerique passe par ici. null, undefined, NaN, Infinity, chaine, objet -> valeur de
// repli. Aucune fonction de ce module ne doit pouvoir renvoyer NaN.
function nombreFini(valeur, repli) {
  const n = Number(valeur);
  return (typeof valeur !== 'boolean' && valeur !== null && valeur !== '' && isFinite(n))
    ? n : (repli || 0);
}

function borner(valeur, min, max) {
  const n = nombreFini(valeur, min);
  return Math.min(max, Math.max(min, n));
}

function prixMateriau(cle) {
  if (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[cle]
      && isFinite(RESSOURCES_ECONOMIE[cle].prixBase)) {
    return RESSOURCES_ECONOMIE[cle].prixBase;
  }
  return PRIX_REFERENCE_MATERIAUX[cle] || 0;
}

// ---------------------------------------------------------------------------
// DIMENSIONNEMENT COMMUN AUX DEUX TYPES DE CHANTIER
// ---------------------------------------------------------------------------

// Part materiaux d'un budget. Arrondie a l'entier ; la part travail est le RESTE exact, de sorte
// que les deux parts se rendent toujours exactement au cout total (jamais un FR perdu ni cree).
function coutMateriauxDe(coutTotal) {
  return Math.round(Math.max(0, nombreFini(coutTotal, 0)) * CHANTIER_PCT_MATERIAUX / 100);
}

function coutTravailDe(coutTotal) {
  const total = Math.max(0, nombreFini(coutTotal, 0));
  return total - coutMateriauxDe(total);
}

function heuresPourCoutTravail(coutTravail) {
  return Math.max(0, nombreFini(coutTravail, 0)) / CHANTIER_TAUX_HORAIRE;
}

// Convertit un budget materiaux en quantites, un TIERS DE LA VALEUR dans chaque matiere. C'est
// cette regle -- et non des quantites recopiees a la main -- qui produit le panier quotidien de
// construction : 1 500 FR -> 500 FR par matiere -> 100 bois (5 FR), 50 minerai (10 FR),
// 33,33 metal (15 FR). Quantites exactes, non arrondies : l'arrondi est une decision d'usage,
// prise par l'appelant (voir la sequence du metal en construction).
function panierMateriauxPourValeur(valeurFR) {
  const valeur = Math.max(0, nombreFini(valeurFR, 0));
  const parMatiere = valeur / MATERIAUX_CHANTIER.length;
  const panier = {};
  MATERIAUX_CHANTIER.forEach(function (cle) {
    const prix = prixMateriau(cle);
    panier[cle] = prix > 0 ? parMatiere / prix : 0;
  });
  return panier;
}

// ---------------------------------------------------------------------------
// CONSTRUCTION — DIMENSIONNEMENT
// ---------------------------------------------------------------------------

function dureeConstruction(palier) {
  return DUREES_CONSTRUCTION[palier] || 0;
}

function coutTotalConstruction(palier) {
  return dureeConstruction(palier) * CHANTIER_FR_PAR_JOUR;
}

function coutMateriauxConstruction(palier) { return coutMateriauxDe(coutTotalConstruction(palier)); }
function coutTravailConstruction(palier)   { return coutTravailDe(coutTotalConstruction(palier)); }

function heuresTotalesConstruction(palier) {
  return heuresPourCoutTravail(coutTravailConstruction(palier));
}

// Identique pour tous les paliers : 3 500 FR de travail par jour / 70 FR = 50 heures.
function heuresParJourConstruction() {
  return heuresPourCoutTravail(coutTravailDe(CHANTIER_FR_PAR_JOUR));
}

// Budget materiaux d'une journee theorique : 1 500 FR.
function budgetMateriauxParJourConstruction() {
  return coutMateriauxDe(CHANTIER_FR_PAR_JOUR);
}

// Panier EXACT d'une journee (metal fractionnaire : 33,33...). Sert de reference de valeur.
function materiauxParJourConstruction() {
  return panierMateriauxPourValeur(budgetMateriauxParJourConstruction());
}

// Metal reellement consomme au jour N (1 = premier jour du chantier). Sequence 33 / 33 / 34.
function metalDuJourConstruction(jour) {
  const n = Math.floor(nombreFini(jour, 0));
  if (n < 1) return 0;
  return SEQUENCE_METAL_CONSTRUCTION[(n - 1) % SEQUENCE_METAL_CONSTRUCTION.length];
}

// Panier ENTIER du jour N, tel qu'il sera reellement consomme.
function materiauxDuJourConstruction(jour) {
  const exact = materiauxParJourConstruction();
  return {
    bois: Math.round(exact.bois),
    minerai: Math.round(exact.minerai),
    metal: metalDuJourConstruction(jour)
  };
}

// Materiaux cumules sur nbJours entiers. Le metal est somme par tranches completes de 3 jours
// (100 par tranche) plus le reste, ce qui evite toute derive d'arrondi.
function materiauxCumulesConstruction(nbJours) {
  const n = Math.max(0, Math.floor(nombreFini(nbJours, 0)));
  const parJour = materiauxDuJourConstruction(1);
  const tranches = Math.floor(n / SEQUENCE_METAL_CONSTRUCTION.length);
  const reste = n % SEQUENCE_METAL_CONSTRUCTION.length;
  const sommeTranche = SEQUENCE_METAL_CONSTRUCTION.reduce(function (s, v) { return s + v; }, 0);
  let metal = tranches * sommeTranche;
  for (let i = 0; i < reste; i++) metal += SEQUENCE_METAL_CONSTRUCTION[i];
  return { bois: parJour.bois * n, minerai: parJour.minerai * n, metal: metal };
}

function materiauxTotauxConstruction(palier) {
  return materiauxCumulesConstruction(dureeConstruction(palier));
}

// ---------------------------------------------------------------------------
// PROGRESSION EFFECTIVE
// ---------------------------------------------------------------------------
// La progression n'est JAMAIS calendaire. Une journee de chantier avance de la fraction de
// capacite reellement disponible, et la contrainte la plus dure commande : avoir tout le travail
// mais la moitie des materiaux fait avancer d'une demi-journee, pas d'une journee.

// Fraction de la capacite de travail couverte. Un besoin nul n'est pas une contrainte -> 1.
function fractionTravail(heuresDisponibles, heuresRequises) {
  const requis = Math.max(0, nombreFini(heuresRequises, 0));
  if (requis <= 0) return 1;
  return borner(Math.max(0, nombreFini(heuresDisponibles, 0)) / requis, 0, 1);
}

// Fraction de materiaux couverte : la matiere la PLUS manquante commande. Une matiere dont le
// besoin est nul n'entre pas dans le calcul.
function fractionMateriaux(disponibles, requis) {
  const besoin = requis || {};
  const dispo = disponibles || {};
  let fraction = 1;
  let contrainte = false;
  Object.keys(besoin).forEach(function (cle) {
    const r = Math.max(0, nombreFini(besoin[cle], 0));
    if (r <= 0) return;
    contrainte = true;
    const d = Math.max(0, nombreFini(dispo[cle], 0));
    fraction = Math.min(fraction, borner(d / r, 0, 1));
  });
  return contrainte ? borner(fraction, 0, 1) : 1;
}

// Progression d'une journee, en jours theoriques : entre 0 et 1.
function progressionDuJour(fractionDuTravail, fractionDesMateriaux) {
  return borner(Math.min(borner(fractionDuTravail, 0, 1), borner(fractionDesMateriaux, 0, 1)), 0, 1);
}

// ---------------------------------------------------------------------------
// SEUILS DU TIERS ET DES DEUX TIERS
// ---------------------------------------------------------------------------

function seuilTiers(dureeJours, numerateur) {
  const d = Math.max(0, nombreFini(dureeJours, 0));
  return d * Math.max(0, nombreFini(numerateur, 0)) / 3;
}

function seuilPremierTiers(dureeJours) { return seuilTiers(dureeJours, 1); }
function seuilDeuxTiers(dureeJours)    { return seuilTiers(dureeJours, 2); }

// Avancement en fraction de chantier, entre 0 et 1.
function progressionNormalisee(progressionJours, dureeJours) {
  const d = Math.max(0, nombreFini(dureeJours, 0));
  if (d <= 0) return 0;
  return borner(Math.max(0, nombreFini(progressionJours, 0)) / d, 0, 1);
}

// Un seuil est franchi quand on passe strictement en dessous a "au moins". Le futur verrou du plan
// au deux-tiers (Lot 1.5.11) s'appuiera dessus -- il n'est PAS pose ici.
function franchitSeuil(progressionAvant, progressionApres, seuil) {
  const avant = Math.max(0, nombreFini(progressionAvant, 0));
  const apres = Math.max(0, nombreFini(progressionApres, 0));
  const s = nombreFini(seuil, 0);
  return avant < s && apres >= s;
}

function franchitPremierTiers(avant, apres, dureeJours) {
  return franchitSeuil(avant, apres, seuilPremierTiers(dureeJours));
}

function franchitDeuxTiers(avant, apres, dureeJours) {
  return franchitSeuil(avant, apres, seuilDeuxTiers(dureeJours));
}

// ---------------------------------------------------------------------------
// FINANCEMENT D'UNE CONSTRUCTION
// ---------------------------------------------------------------------------
// Tout repose sur totalVerse, CUMUL des apports du proprietaire -- jamais sur un echeancier a
// paliers. Les comparaisons se font en entiers (montant x 100 contre pourcentage x cout) pour
// qu'aucun arrondi flottant ne fasse basculer un seuil.

// Pourcentage cumule exige pour se trouver a cette progression.
function seuilFinancementRequis(progressionJours, dureeJours) {
  const d = Math.max(0, nombreFini(dureeJours, 0));
  if (d <= 0) return SEUILS_FINANCEMENT_CONSTRUCTION.deuxTiers;
  const p = Math.max(0, nombreFini(progressionJours, 0));
  if (p < seuilPremierTiers(d)) return SEUILS_FINANCEMENT_CONSTRUCTION.demarrage;
  if (p < seuilDeuxTiers(d))    return SEUILS_FINANCEMENT_CONSTRUCTION.premierTiers;
  return SEUILS_FINANCEMENT_CONSTRUCTION.deuxTiers;
}

function montantFinancementRequis(progressionJours, dureeJours, coutTotal) {
  const total = Math.max(0, nombreFini(coutTotal, 0));
  return Math.ceil(total * seuilFinancementRequis(progressionJours, dureeJours) / 100);
}

function montantManquant(totalVerse, progressionJours, dureeJours, coutTotal) {
  const verse = Math.max(0, nombreFini(totalVerse, 0));
  return Math.max(0, montantFinancementRequis(progressionJours, dureeJours, coutTotal) - verse);
}

function peutProgresser(totalVerse, progressionJours, dureeJours, coutTotal) {
  return montantManquant(totalVerse, progressionJours, dureeJours, coutTotal) <= 0;
}

// Progression la plus avancee que le financement deja verse autorise. Sert a plafonner l'avancee
// d'une journee : un chantier finance a 70 % ne peut pas depasser les deux tiers.
function progressionMaxFinancee(totalVerse, dureeJours, coutTotal) {
  const d = Math.max(0, nombreFini(dureeJours, 0));
  const total = Math.max(0, nombreFini(coutTotal, 0));
  const verse = Math.max(0, nombreFini(totalVerse, 0));
  if (d <= 0) return 0;
  if (total <= 0) return d;                                   // rien a financer
  if (verse * 100 >= SEUILS_FINANCEMENT_CONSTRUCTION.deuxTiers * total)    return d;
  if (verse * 100 >= SEUILS_FINANCEMENT_CONSTRUCTION.premierTiers * total) return seuilDeuxTiers(d);
  if (verse * 100 >= SEUILS_FINANCEMENT_CONSTRUCTION.demarrage * total)    return seuilPremierTiers(d);
  return 0;
}

// Progression du jour effectivement retenue, plafonnee par le financement. Ne fait AUCUN debit.
function progressionAutorisee(progressionActuelle, progressionDuJourCalculee, totalVerse, dureeJours, coutTotal) {
  const actuelle = Math.max(0, nombreFini(progressionActuelle, 0));
  const gain = Math.max(0, nombreFini(progressionDuJourCalculee, 0));
  const plafond = progressionMaxFinancee(totalVerse, dureeJours, coutTotal);
  return Math.max(0, Math.min(actuelle + gain, plafond) - actuelle);
}

// ---------------------------------------------------------------------------
// REGRESSION
// ---------------------------------------------------------------------------
// Un chantier durablement bloque faute de financement pourra regresser. La cadence et le
// declencheur appartiennent au lot qui branchera le cron -- ici, seulement le calcul.
// Un chantier ne descend jamais sous J0, et il EXISTE toujours a J0 : regresser n'est pas annuler.
function appliquerRegression(progressionJours, quantite) {
  const p = Math.max(0, nombreFini(progressionJours, 0));
  const q = Math.max(0, nombreFini(quantite, 0));
  return Math.max(0, p - q);
}

// ---------------------------------------------------------------------------
// REAMENAGEMENT — DIMENSIONNEMENT
// ---------------------------------------------------------------------------
// 10 FR par m2 reellement concerne, 300 m2 par jour, au moins un jour. Meme repartition 30/70 et
// meme taux horaire que la construction : ce sont les memes briques, avec un dimensionnement
// different.

function dureeReamenagement(surfaceConcernee) {
  const m2 = Math.max(0, nombreFini(surfaceConcernee, 0));
  if (m2 <= 0) return 0;                                       // aucune surface : aucun chantier
  return Math.max(1, Math.ceil(m2 / REAMENAGEMENT_M2_PAR_JOUR));
}

function coutTotalReamenagement(surfaceConcernee) {
  return Math.max(0, nombreFini(surfaceConcernee, 0)) * REAMENAGEMENT_FR_PAR_M2;
}

function coutMateriauxReamenagement(surfaceConcernee) {
  return coutMateriauxDe(coutTotalReamenagement(surfaceConcernee));
}

function coutTravailReamenagement(surfaceConcernee) {
  return coutTravailDe(coutTotalReamenagement(surfaceConcernee));
}

function heuresTotalesReamenagement(surfaceConcernee) {
  return heuresPourCoutTravail(coutTravailReamenagement(surfaceConcernee));
}

// ---------------------------------------------------------------------------
// CYCLE DE VIE D'UN CHANTIER (Lot 1.5.7)
// ---------------------------------------------------------------------------
// Structure generique unique, partagee a terme par 'construction' et 'reamenagement'. Toujours
// pure : ces fonctions fabriquent ou transforment un objet, elles n'ecrivent nulle part.

// SNAPSHOT DE LANCEMENT. dureeJours, coutTotal, coutMateriaux, coutTravail et heuresTotales sont
// figes ici et ne sont JAMAIS recalcules ensuite : faire evoluer une constante ne doit pas
// modifier retroactivement un chantier deja commence.
function creerChantierConstruction(palier, jour) {
  const duree = dureeConstruction(palier);
  if (duree <= 0) return null;                       // palier inconnu : aucun chantier
  const coutTotal = coutTotalConstruction(palier);
  return {
    type: 'construction',
    niveau: palier,
    jourDebut: Math.max(0, Math.floor(nombreFini(jour, 0))),

    // --- dimensionnement fige
    dureeJours: duree,
    coutTotal: coutTotal,
    coutMateriaux: coutMateriauxDe(coutTotal),
    coutTravail: coutTravailDe(coutTotal),
    heuresTotales: heuresPourCoutTravail(coutTravailDe(coutTotal)),

    // --- economie
    totalVerse: 0,                                   // cumul des apports, jamais decremente
    tresorerie: 0,                                   // argent encore present dans le chantier
    stockMateriaux: { bois: 0, minerai: 0, metal: 0 },

    // --- avancement
    heuresFaites: 0,
    jourTraite: null,                                // marqueur anti-double-traitement quotidien
    progressionJours: 0,                             // SEULE verite d'avancement
    arrete: null,                                    // null | 'financement' | 'penurie_materiaux'

    // --- journaux
    evenements: [],
    travauxPJ: [],
    ventesMateriauxPJ: []
  };
}

// Apport libre du proprietaire. Aucun echeancier : n'importe quel montant positif, autant de fois
// qu'on veut, y compris 100 % des le premier jour. Renvoie un NOUVEAU chantier.
function verserAuChantier(chantier, montant) {
  if (!chantier) return chantier;
  const m = Math.max(0, nombreFini(montant, 0));
  if (m <= 0) return chantier;
  const maj = Object.assign({}, chantier);
  maj.totalVerse = Math.max(0, nombreFini(chantier.totalVerse, 0)) + m;
  maj.tresorerie = Math.max(0, nombreFini(chantier.tresorerie, 0)) + m;
  return maj;
}

// Le chantier peut-il DEMARRER ? Seule condition financiere : 35 % du cout total deja verses.
// Les conditions non financieres (propriete, permis, cadavre, squatteurs) restent portees par
// leurs mecanismes existants -- ce module ne les connait pas.
function financementSuffisantPourLancer(coutTotal, totalVerse) {
  const total = Math.max(0, nombreFini(coutTotal, 0));
  const verse = Math.max(0, nombreFini(totalVerse, 0));
  if (total <= 0) return true;
  return verse * 100 >= SEUILS_FINANCEMENT_CONSTRUCTION.demarrage * total;
}

function montantMinimalLancement(coutTotal) {
  return Math.ceil(Math.max(0, nombreFini(coutTotal, 0)) * SEUILS_FINANCEMENT_CONSTRUCTION.demarrage / 100);
}

// TRANSITION PROVISOIRE DU LOT 1.5.7 -- A REMPLACER.
// Les materiaux reels (Lot 1.5.8) et le travail reel (Lot 1.5.9) ne sont pas encore branches. En
// leur absence, la capacite du jour est reputee COMPLETE : fractions travail et materiaux a 1.
// C'est le SEUL endroit ou cette hypothese est faite, et elle est volontairement isolee dans une
// fonction dediee pour qu'il suffise de la remplacer -- jamais une seconde logique de progression.
// La progression passe deja par les fonctions generiques : seules les deux fractions sont
// provisoirement forcees.
function capaciteProvisoireCompleteLot157() {
  return { fractionTravail: 1, fractionMateriaux: 1, provisoire: true };
}

// AVANCEE D'UNE JOURNEE. Pure : renvoie un nouveau chantier et un verdict, n'ecrit rien.
// La progression n'est jamais deduite du calendrier : elle vaut min(fractions), puis est plafonnee
// par le financement cumule, puis par la duree theorique. Un seuil ne peut donc jamais etre
// franchi sans le financement requis.
function avancerChantierUnJour(chantier, capacite) {
  if (!chantier) return { chantier: chantier, avance: 0, arrete: 'chantier_absent', verrouAtteint: null };
  const cap = capacite || capaciteProvisoireCompleteLot157();
  const avant = Math.max(0, nombreFini(chantier.progressionJours, 0));
  const duree = Math.max(0, nombreFini(chantier.dureeJours, 0));

  const brut = progressionDuJour(cap.fractionTravail, cap.fractionMateriaux);
  const autorisee = progressionAutorisee(avant, brut, chantier.totalVerse, duree, chantier.coutTotal);
  const apres = Math.min(duree, avant + autorisee);   // jamais au-dela du terme
  const gain = Math.max(0, apres - avant);

  let arrete = null;
  if (gain <= 0 && avant < duree) {
    // Distinguer la cause : financement insuffisant, ou capacite du jour nulle.
    arrete = peutProgresser(chantier.totalVerse, avant, duree, chantier.coutTotal)
      ? 'capacite' : 'financement';
  }

  const maj = Object.assign({}, chantier);
  maj.progressionJours = apres;
  maj.arrete = arrete;

  return {
    chantier: maj,
    avance: gain,
    arrete: arrete,
    termine: duree > 0 && apres >= duree,
    franchitPremierTiers: franchitPremierTiers(avant, apres, duree),
    franchitDeuxTiers: franchitDeuxTiers(avant, apres, duree)
  };
}

// ---------------------------------------------------------------------------
// MATERIAUX REELS ET PENURIE (Lot 1.5.8)
// ---------------------------------------------------------------------------
// La fraction materiaux cesse d'etre forcee a 1 : elle est desormais calculee sur le stock
// reellement present dans le chantier. La matiere la plus manquante commande, et la pénurie n'est
// jamais un tirage aleatoire -- c'est le constat "aucun progres possible aujourd'hui".

// Besoin du jour N pour un chantier de construction, en unites entieres.
function besoinMateriauxJourChantier(chantier, jourNumero) {
  if (!chantier || chantier.type !== 'construction') return { bois: 0, minerai: 0, metal: 0 };
  return materiauxDuJourConstruction(jourNumero);
}

// Numero de la journee de travail a venir : 1 pour la premiere. Fonde sur la progression deja
// acquise, jamais sur le calendrier -- un chantier arrete trois jours reprend a la meme journee.
function numeroJourChantier(chantier) {
  const p = Math.max(0, nombreFini(chantier && chantier.progressionJours, 0));
  return Math.floor(p) + 1;
}

// Consommation PROPORTIONNELLE a l'avancee reelle. Avancer d'un demi-jour ne consomme que la
// moitie des materiaux du jour. Les quantites retirees sont arrondies a l'entier inferieur et
// bornees par le stock : on ne peut jamais consommer ce qu'on n'a pas.
function consommerMateriaux(stock, besoin, fraction) {
  const f = borner(fraction, 0, 1);
  const dispo = stock || {};
  const restant = {};
  const consomme = {};
  MATERIAUX_CHANTIER.forEach(function (cle) {
    const enStock = Math.max(0, nombreFini(dispo[cle], 0));
    const voulu = Math.floor(Math.max(0, nombreFini(besoin && besoin[cle], 0)) * f);
    const pris = Math.min(enStock, voulu);
    consomme[cle] = pris;
    restant[cle] = enStock - pris;
  });
  return { stock: restant, consomme: consomme };
}

// Manque a acheter pour couvrir le besoin du jour, matiere par matiere.
function manqueMateriaux(stock, besoin) {
  const dispo = stock || {};
  const manque = {};
  MATERIAUX_CHANTIER.forEach(function (cle) {
    const b = Math.max(0, nombreFini(besoin && besoin[cle], 0));
    const s = Math.max(0, nombreFini(dispo[cle], 0));
    manque[cle] = Math.max(0, b - s);
  });
  return manque;
}

// ---------------------------------------------------------------------------
// VOL DE MATERIAUX (Lot 1.5.8)
// ---------------------------------------------------------------------------
// Base neutre de 50, a laquelle s'ajoutent les bonus/malus de discretion du voleur et le malus
// des vigiles du chantier. Un seul jet : la detection decoule du MEME score final, jamais d'un
// second tirage.

// Malus cumulatif des vigiles : -20 pour le premier, -10 pour chacun des suivants. Deux vigiles
// atteignent -30, soit exactement l'echelle de MALUS_CENTRE_POUVOIR deja arbitree ailleurs.
const MALUS_VIGILE_PREMIER = 20;
const MALUS_VIGILE_SUIVANT = 10;

function malusVigiles(nombreVigiles) {
  const n = Math.max(0, Math.floor(nombreFini(nombreVigiles, 0)));
  if (n <= 0) return 0;
  return MALUS_VIGILE_PREMIER + (n - 1) * MALUS_VIGILE_SUIVANT;
}

// Nombre de vigiles affectes au chantier. Leur recrutement n'existe pas encore (hors perimetre) :
// la structure est simplement lue si elle est presente, et vaut 0 sinon.
function vigilesDuChantier(chantier) {
  if (!chantier) return 0;
  if (Array.isArray(chantier.vigiles)) return chantier.vigiles.length;
  return Math.max(0, Math.floor(nombreFini(chantier.vigiles, 0)));
}

// Score final, borne 0..100.
function scoreVolMateriaux(bonusVoleur, nombreVigiles, jet) {
  const base = 50;
  const b = nombreFini(bonusVoleur, 0);
  const d = nombreFini(jet, 0);                       // ecart de tirage, 0 si non fourni
  return borner(base + b - malusVigiles(nombreVigiles) + d, 0, 100);
}

// Resolution : un seul score, trois issues.
function verdictVolMateriaux(score) {
  const s = borner(score, 0, 100);
  if (s < 20) return { reussite: false, detecte: true,  score: s };
  if (s < 50) return { reussite: false, detecte: false, score: s };
  return { reussite: true, detecte: false, score: s };
}

// Plafond volable d'une matiere : 20 % du besoin QUOTIDIEN de cette matiere. Le metal suit la
// sequence 33/33/34, son plafond vaut donc 6 / 6 / 7 -- soit exactement 20 unites volables pour
// 100 consommees sur trois jours, sans derive.
// Le metal ne peut pas se deduire d'un simple arrondi de 20 % jour par jour : floor(33x0,2)=6 et
// floor(34x0,2)=6 donneraient 6/6/6, round donnerait 7/7/7. La sequence est donc calee sur le
// CUMUL : 20 % de la consommation cumulee, arrondi a l'entier, ce qui donne 6 / 13 / 20 apres
// J1 / J2 / J3 -- soit des increments de 6, 7 puis 7, et exactement 20 unites volables pour 100
// consommees sur trois jours. Alignee sur les memes jours que la consommation 33 / 33 / 34.
const PLAFOND_VOL_METAL = [6, 7, 7];

function plafondVolMatiere(matiere, jourNumero) {
  if (matiere === 'metal') {
    const n = Math.floor(nombreFini(jourNumero, 0));
    if (n < 1) return 0;
    return PLAFOND_VOL_METAL[(n - 1) % PLAFOND_VOL_METAL.length];
  }
  const besoin = materiauxDuJourConstruction(jourNumero);
  const b = Math.max(0, nombreFini(besoin[matiere], 0));
  return Math.floor(b * 0.2);
}

// Quantite volee : proportionnelle a la qualite du succes au-dessus de 50. Un succes de justesse
// rapporte 1 unite, un score parfait approche le plafond. Jamais 0 sur une reussite, jamais plus
// que le plafond, jamais plus que le stock reellement present.
function quantiteVolMateriaux(score, matiere, jourNumero, stockPresent) {
  const v = verdictVolMateriaux(score);
  if (!v.reussite) return 0;
  const plafond = plafondVolMatiere(matiere, jourNumero);
  const enStock = Math.max(0, Math.floor(nombreFini(stockPresent, 0)));
  if (plafond <= 0 || enStock <= 0) return 0;
  const fraction = (v.score - 50) / 50;
  return Math.min(plafond, enStock, Math.max(1, Math.round(fraction * plafond)));
}

// ---------------------------------------------------------------------------
// TRAVAIL PJ ET NPC (Lot 1.5.9)
// ---------------------------------------------------------------------------
// Une heure RP coute 1 PA au joueur et vaut 70 FR, payes par la tresorerie du chantier. Le travail
// PJ REMPLACE du travail NPC : il n'accelere jamais au-dela de la capacite quotidienne. Ce qui
// reste a minuit est effectue par des NPC, si la tresorerie permet de les payer -- et cet argent
// va dans la caisse reelle du ministere des Finances, jamais dans un accumulateur temporaire.

// Capacite de travail d'une journee, en heures. Derivee du dimensionnement fige du chantier :
// coutTravail / duree / taux horaire, soit 50 h/jour en construction.
function capaciteHeuresJourChantier(chantier) {
  if (!chantier) return 0;
  const duree = Math.max(0, nombreFini(chantier.dureeJours, 0));
  if (duree <= 0) return 0;
  return heuresPourCoutTravail(nombreFini(chantier.coutTravail, 0)) / duree;
}

// Heures encore disponibles aujourd'hui. C'est cette valeur, et rien d'autre, qui borne le travail
// d'un PJ : aucun plafond individuel artificiel n'existe, un seul joueur peut prendre toutes les
// heures restantes s'il a les PA.
function heuresRestantesJour(chantier) {
  const cap = capaciteHeuresJourChantier(chantier);
  const faites = Math.max(0, nombreFini(chantier && chantier.heuresFaites, 0));
  return Math.max(0, cap - faites);
}

function coutHeuresTravail(heures) {
  return Math.max(0, nombreFini(heures, 0)) * CHANTIER_TAUX_HORAIRE;
}

// Combien d'heures un PJ peut-il REELLEMENT prendre ? Le minimum entre ce qu'il demande, ce qu'il
// reste a faire aujourd'hui, ce que ses PA permettent, et ce que la tresorerie peut payer.
function heuresTravaillablesPar(chantier, heuresVoulues, paDisponibles) {
  const voulues = Math.max(0, Math.floor(nombreFini(heuresVoulues, 0)));
  const pa = Math.max(0, Math.floor(nombreFini(paDisponibles, 0)));
  const tresorerie = Math.max(0, nombreFini(chantier && chantier.tresorerie, 0));
  const payables = Math.floor(tresorerie / CHANTIER_TAUX_HORAIRE);
  // Borne materiaux : identique pour les PJ et les NPC. Sans materiaux, aucune heure n'est
  // travaillable -- un joueur ne peut pas etre paye pour un travail qui ne fera rien avancer.
  return Math.max(0, Math.min(voulues, heuresUtilesRestantes(chantier), pa, payables));
}

// Heures encore utiles aujourd'hui : capacite bornee par les materiaux, moins ce qui est deja fait.
function heuresUtilesRestantes(chantier) {
  const utiles = Math.floor(heuresUtilesJour(chantier, fractionMateriauxChantier(chantier)));
  const faites = Math.max(0, nombreFini(chantier && chantier.heuresFaites, 0));
  return Math.max(0, utiles - faites);
}

// Enregistre le travail d'un PJ : heures faites, tresorerie debitee, log NOMINATIF. Pure : renvoie
// un nouveau chantier, ne paie personne (c'est a l'appelant de crediter le joueur).
function enregistrerTravailPJ(chantier, nom, heures, jour) {
  if (!chantier) return { chantier: chantier, heures: 0, montant: 0 };
  const h = Math.max(0, Math.floor(nombreFini(heures, 0)));
  if (h <= 0) return { chantier: chantier, heures: 0, montant: 0 };
  const montant = coutHeuresTravail(h);
  const maj = Object.assign({}, chantier);
  maj.heuresFaites = Math.max(0, nombreFini(chantier.heuresFaites, 0)) + h;
  maj.tresorerie = Math.max(0, nombreFini(chantier.tresorerie, 0) - montant);
  maj.travauxPJ = (chantier.travauxPJ || []).concat([{ nom: nom || null, heures: h, montant: montant, jour: jour || null }]);
  return { chantier: maj, heures: h, montant: montant };
}

// Fraction de materiaux du chantier a cet instant, calculee sur son stock courant et le besoin de
// la journee en cours. Sert de borne COMMUNE au travail PJ, au travail NPC et a l'offre BNE : une
// heure qui ne peut pas contribuer a la progression ne doit etre ni effectuee, ni payee, ni
// proposee.
function fractionMateriauxChantier(chantier) {
  if (!chantier) return 0;
  const besoin = besoinMateriauxJourChantier(chantier, numeroJourChantier(chantier));
  return fractionMateriaux(chantier.stockMateriaux, besoin);
}

// Heures UTILES de la journee : la capacite ne vaut que si les materiaux suivent. Avec 40 % de
// materiaux, une journee de 50 h ne peut produire que 20 h de travail utile -- au-dela, on paierait
// des ouvriers pour un progres qui ne viendra pas.
function heuresUtilesJour(chantier, fractionDesMateriaux) {
  return capaciteHeuresJourChantier(chantier) * borner(fractionDesMateriaux, 0, 1);
}

// Reliquat NPC de la journee. Respecte SIMULTANEMENT quatre bornes : la capacite quotidienne, les
// heures deja faites par des PJ, la fraction de materiaux reellement disponible, et la tresorerie.
// Rien n'est avance a credit, et surtout rien n'est paye pour du travail qui ne peut pas contribuer
// a la progression du jour : 0 % de materiaux -> 0 heure NPC, 0 FR verse.
function reliquatNPC(chantier, fractionDesMateriaux) {
  const utiles = Math.floor(heuresUtilesJour(chantier, fractionDesMateriaux === undefined ? 1 : fractionDesMateriaux));
  const faites = Math.max(0, nombreFini(chantier && chantier.heuresFaites, 0));
  const restantesUtiles = Math.max(0, utiles - faites);
  const tresorerie = Math.max(0, nombreFini(chantier && chantier.tresorerie, 0));
  const payables = Math.floor(tresorerie / CHANTIER_TAUX_HORAIRE);
  const heures = Math.max(0, Math.min(restantesUtiles, payables));
  return { heures: heures, montant: coutHeuresTravail(heures) };
}

// Fraction travail REELLE du jour : heures effectivement faites (PJ + NPC) sur la capacite.
// Remplace la fraction provisoire du Lot 1.5.7.
function fractionTravailChantier(chantier, heuresNPC) {
  const cap = capaciteHeuresJourChantier(chantier);
  if (cap <= 0) return 1;                                   // aucun besoin de travail : pas une contrainte
  const faites = Math.max(0, nombreFini(chantier && chantier.heuresFaites, 0))
               + Math.max(0, nombreFini(heuresNPC, 0));
  return borner(faites / cap, 0, 1);
}

// Un chantier apparait dans la BNE tant qu'il reste des heures a effectuer aujourd'hui ET que sa
// tresorerie peut les payer -- on n'affiche jamais une offre qu'on ne pourrait pas honorer.
function offreBNEChantier(chantier) {
  if (!chantier || chantier.arrete === 'financement') return null;
  // Bornee par les MATERIAUX comme le travail lui-meme : on ne propose jamais une heure qui ne
  // pourrait pas contribuer a la progression.
  const restantes = heuresUtilesRestantes(chantier);
  if (restantes <= 0) return null;
  const payables = Math.floor(Math.max(0, nombreFini(chantier.tresorerie, 0)) / CHANTIER_TAUX_HORAIRE);
  const heures = Math.min(restantes, payables);
  if (heures <= 0) return null;
  return { heuresRestantes: heures, tauxHoraire: CHANTIER_TAUX_HORAIRE, type: chantier.type, niveau: chantier.niveau };
}

// Remise a zero des heures du jour, appelee par le traitement quotidien apres consolidation.
function reinitialiserHeuresJour(chantier) {
  if (!chantier) return chantier;
  const maj = Object.assign({}, chantier);
  maj.heuresFaites = 0;
  return maj;
}

// ---------------------------------------------------------------------------
// APPROVISIONNEMENT (Lot 1.5.9, factorise)
// ---------------------------------------------------------------------------
// DECISION PURE d'achat, partagee par le lancement d'un chantier et par le cron quotidien : une
// seule regle, jamais deux. Les appelants font les entrees/sorties (lire l'entrepot, ecrire les
// deux etats) ; ici on se contente de dire quoi acheter et a quel prix.
// Aucun materiau n'est cree : on n'achete jamais plus que le besoin, plus que le stock reellement
// present dans l'entrepot, ni plus que la tresorerie ne peut payer.
function planifierApprovisionnement(besoin, stockChantier, stockEntrepot, tresorerie, prixParMatiere) {
  const achats = {};
  const nouveauChantier = {};
  const nouvelEntrepot = Object.assign({}, stockEntrepot || {});
  let depense = 0;
  MATERIAUX_CHANTIER.forEach(function (cle) {
    const enChantier = Math.max(0, nombreFini((stockChantier || {})[cle], 0));
    nouveauChantier[cle] = enChantier;
    const manque = Math.max(0, Math.max(0, nombreFini((besoin || {})[cle], 0)) - enChantier);
    if (manque <= 0) return;
    const prix = Math.max(0, nombreFini((prixParMatiere || {})[cle], prixMateriau(cle)));
    const dispo = Math.max(0, Math.floor(nombreFini(nouvelEntrepot[cle], 0)));
    const abordable = prix > 0 ? Math.floor(Math.max(0, nombreFini(tresorerie, 0) - depense) / prix) : 0;
    const qte = Math.min(manque, dispo, abordable);
    if (qte <= 0) return;
    achats[cle] = qte;
    depense += qte * prix;
    nouveauChantier[cle] = enChantier + qte;
    nouvelEntrepot[cle] = dispo - qte;
  });
  return { achats: achats, depense: depense, stockChantier: nouveauChantier, stockEntrepot: nouvelEntrepot };
}

// ---------------------------------------------------------------------------
// VENTE DE MATERIAUX PAR LES PJ (Lot 1.5.10)
// ---------------------------------------------------------------------------
// Un PJ present sur un chantier actif peut lui vendre ses materiaux, AU PRIX QU'IL VEUT. Le moteur
// n'impose aucun plafond : le prix de l'entrepot n'est pas une reference, et un proprietaire peut
// deliberement surpayer. La seule borne est reelle -- la tresorerie du chantier.
//
// Le stock du chantier est un VRAI stock : on peut constituer des reserves bien au-dela du besoin
// du jour. Seul un chantier inexistant ou termine refuse la marchandise.

function chantierAccepteMateriaux(chantier) {
  if (!chantier) return false;
  return !chantierTermine(chantier);
}

// Verdict d'une vente. Renvoie la quantite REELLEMENT transferable et le montant correspondant,
// bornes par ce que le PJ possede, ce qu'il demande, et ce que la tresorerie peut payer. Ne cree
// jamais de matiere ni d'argent.
function verdictVenteMateriaux(chantier, matiere, quantiteVoulue, prixUnitaire, stockPJ) {
  if (!chantier) return { ok: false, raison: 'chantier_absent', quantite: 0, montant: 0 };
  if (!chantierAccepteMateriaux(chantier)) return { ok: false, raison: 'chantier_termine', quantite: 0, montant: 0 };
  if (MATERIAUX_CHANTIER.indexOf(matiere) === -1) return { ok: false, raison: 'matiere_invalide', quantite: 0, montant: 0 };

  const prix = Math.floor(nombreFini(prixUnitaire, 0));
  if (prix <= 0) return { ok: false, raison: 'prix_invalide', quantite: 0, montant: 0 };

  const voulue = Math.floor(nombreFini(quantiteVoulue, 0));
  if (voulue <= 0) return { ok: false, raison: 'quantite_invalide', quantite: 0, montant: 0 };

  const possede = Math.max(0, Math.floor(nombreFini(stockPJ, 0)));
  if (possede <= 0) return { ok: false, raison: 'stock_insuffisant', quantite: 0, montant: 0 };

  const tresorerie = Math.max(0, nombreFini(chantier.tresorerie, 0));
  const payables = Math.floor(tresorerie / prix);
  const quantite = Math.min(voulue, possede, payables);
  if (quantite <= 0) return { ok: false, raison: 'tresorerie_insuffisante', quantite: 0, montant: 0 };

  return { ok: true, raison: null, quantite: quantite, montant: quantite * prix, prixUnitaire: prix };
}

// Applique la vente sur le chantier : stock credite, tresorerie debitee, journal NOMINATIF -- ici
// le vendeur est connu, contrairement au journal d'un vol. Pure : renvoie un nouveau chantier,
// c'est a l'appelant de retirer la marchandise de l'inventaire et de payer le joueur.
function enregistrerVenteMateriauxPJ(chantier, vendeur, matiere, quantite, prixUnitaire, jour) {
  const v = verdictVenteMateriaux(chantier, matiere, quantite, prixUnitaire, quantite);
  if (!v.ok) return { chantier: chantier, quantite: 0, montant: 0, raison: v.raison };
  const stock = Object.assign({ bois: 0, minerai: 0, metal: 0 }, chantier.stockMateriaux || {});
  stock[matiere] = Math.max(0, nombreFini(stock[matiere], 0)) + v.quantite;
  const maj = Object.assign({}, chantier, {
    stockMateriaux: stock,
    tresorerie: Math.max(0, nombreFini(chantier.tresorerie, 0) - v.montant),
    ventesMateriauxPJ: (chantier.ventesMateriauxPJ || []).concat([{
      vendeur: vendeur || null, matiere: matiere, quantite: v.quantite,
      prixUnitaire: v.prixUnitaire, montant: v.montant, jour: jour || null
    }])
  });
  return { chantier: maj, quantite: v.quantite, montant: v.montant, raison: null };
}

// ---------------------------------------------------------------------------
// VERROU DU PLAN AUX DEUX TIERS (Lot 1.5.11)
// ---------------------------------------------------------------------------
// Tant que le chantier n'a pas REELLEMENT atteint les deux tiers, le proprietaire remanie son plan
// librement et gratuitement. Au premier franchissement, le plan est fige pour de bon.
//
// POURQUOI DEUX SOURCES CONCORDANTES ET NON UNE SEULE. Le verrou est a la fois DERIVE de la
// progression reelle et PERSISTE dans un drapeau. Ce n'est pas une redondance de confort :
//   - derive seul, il serait reversible -- une regression de financement ramenant la progression
//     sous les 2/3 rouvrirait le plan, ce que le GD interdit explicitement ;
//   - persiste seul, il serait faillible -- un chantier ancien, ou une ecriture perdue, laisserait
//     modifiable un plan pourtant depasse par les travaux.
// Les deux ensemble donnent la seule regle voulue : le verrou se POSE des que le seuil est atteint
// et ne se retire JAMAIS. Il n'y a pas pour autant deux verites concurrentes -- planEstVerrouille
// est l'unique lecture autorisee, et elle prend le OU des deux.
//
// La progression de reference est celle du moteur generique (progressionJours), jamais un delai
// calendaire : un chantier ouvert depuis trois semaines mais bloque a 10 % reste modifiable.

// Le seuil est-il REELLEMENT atteint maintenant ? Lecture instantanee, sans memoire.
function progressionAtteintDeuxTiers(chantier) {
  if (!chantier) return false;
  const duree = Math.max(0, nombreFini(chantier.dureeJours, 0));
  if (duree <= 0) return false;
  return Math.max(0, nombreFini(chantier.progressionJours, 0)) >= seuilDeuxTiers(duree);
}

// LECTURE UNIQUE du verrou. Tout controle -- interface, confirmation, futur controle serveur --
// passe par ici.
function planEstVerrouille(chantier) {
  if (!chantier) return false;
  return chantier.planVerrouille === true || progressionAtteintDeuxTiers(chantier);
}

// POSE du verrou. Appelee apres CHAQUE modification de la progression, d'ou qu'elle vienne (cron
// quotidien, acceleration par corruption). Ne retire jamais un verrou existant, et ne le pose que
// si le seuil est reellement atteint. Pure : renvoie un nouveau chantier.
function appliquerVerrouPlan(chantier, jour) {
  if (!chantier) return chantier;
  if (chantier.planVerrouille === true) return chantier;      // deja verrouille : rien a refaire
  if (!progressionAtteintDeuxTiers(chantier)) return chantier;
  const maj = Object.assign({}, chantier);
  maj.planVerrouille = true;
  maj.jourVerrouPlan = (jour === undefined || jour === null) ? null : jour;
  return maj;
}

// Verdict unique sur la modification du plan initial. Ne connait ni proprietaire ni PA : la
// propriete est verifiee par l'appelant, avec le mecanisme existant (estTitulaire).
function verdictModificationPlan(chantier) {
  if (!chantier) return { ok: false, raison: 'chantier_absent' };
  if (chantierTermine(chantier)) return { ok: false, raison: 'chantier_livre' };
  if (planEstVerrouille(chantier)) return { ok: false, raison: 'plan_verrouille' };
  return { ok: true, raison: null };
}

// ---------------------------------------------------------------------------
// LIVRAISON DU BATIMENT (Lot 1.5.12)
// ---------------------------------------------------------------------------
// A 100 % de progression reelle, le chantier de construction se solde : le batiment existe, le
// plan verrouille devient les VRAIS lots de l'architecture immobiliere (terrains_etat.subdivisions,
// Lot 1.1), et le chantier quitte la place vivante qu'il occupait.
//
// ETAT RETENU. etat.chantier reste ce qu'il a toujours ete : le chantier VIVANT, et lui seul. Un
// chantier livre en sort et devient etat.chantierAcheve, que rien dans le moteur ne lit. Deux
// consequences, obtenues sans toucher a un seul appelant :
//   - toute activite de chantier cesse d'elle-meme -- vente de materiaux, travail PJ, travail NPC,
//     offre BNE, approvisionnement automatique et vol testent tous etat.chantier, qui n'existe
//     plus ;
//   - l'historique est integralement conserve -- evenements, travauxPJ, ventesMateriauxPJ et
//     dimensionnement figé restent lisibles, simplement inertes.
// C'est un DEPLACEMENT, pas une duplication : le chantier n'existe jamais aux deux endroits a la
// fois, donc aucune seconde source de verite.
//
// LE PLAN N'EST PAS RECOPIE AVANT L'HEURE. Les lots naissent de permis.decoupageInitial au moment
// meme de la livraison. C'est licite precisement parce que le verrou des 2/3 garantit que ce plan
// ne peut plus bouger depuis longtemps : le figer une seconde fois dans le chantier creerait deux
// exemplaires du meme plan, donc deux verites possibles.

function chantierTermine(chantier) {
  if (!chantier) return false;
  const duree = Math.max(0, nombreFini(chantier.dureeJours, 0));
  if (duree <= 0) return false;
  return Math.max(0, nombreFini(chantier.progressionJours, 0)) >= duree;
}

// Traduit le plan administratif en lots reels. Meme forme exactement que les lots crees a la main
// par doAjouterSubdivision (id, label, surface, destination, locataire, loyer) : aucune structure
// parallele, les lots livres sont indiscernables des lots ajoutes ensuite.
// LOYER : le plan de permis n'en porte pas -- le GD n'en a jamais demande au depot. On n'en invente
// donc aucun : le lot nait a 0, et son proprietaire le fixe ensuite comme pour tout autre lot.
function lotsLivrablesDepuisPlan(plan) {
  const lots = Array.isArray(plan) ? plan : [];
  const vus = {};
  const sortie = [];
  lots.forEach(function (l, i) {
    if (!l || typeof l !== 'object') return;
    const surface = Math.max(0, nombreFini(l.surface, 0));
    if (surface <= 0) return;                          // un lot sans surface n'est pas un local
    // Identite : celle du plan si elle est exploitable, sinon une identite de secours DETERMINISTE
    // (jamais Date.now : deux livraisons du meme plan doivent donner exactement les memes lots).
    let id = (typeof l.id === 'string' && l.id.trim()) ? l.id.trim() : ('lot-livre-' + (i + 1));
    if (vus[id]) id = id + '-' + (i + 1);
    vus[id] = true;
    sortie.push({
      id: id,
      label: (typeof l.label === 'string' && l.label.trim()) ? l.label.trim() : ('Lot ' + (i + 1)),
      surface: surface,
      destination: (l.destination === 'appartement') ? 'appartement' : 'commerce',
      locataire: null,
      loyer: 0
    });
  });
  return sortie;
}

// La LIVRAISON elle-meme n'est pas ici : elle n'a qu'un seul point d'execution, le traitement
// quotidien (livrerChantierServeur, api/cron-minuit.js), parce qu'elle ecrit dans terrains_etat et
// qu'aucun chemin client ne peut mener un chantier a son terme -- l'acceleration par corruption
// avance de la moitie du travail restant, donc approche le terme sans jamais l'atteindre. Poser ici
// une seconde implementation donnerait deux facons de livrer un batiment pour aucun usage reel.
// Seule la traduction du plan en lots, elle, est ecrite des deux cotes et verrouillee par un test
// d'egalite : c'est la partie ou une divergence produirait des lots differents selon l'endroit.
