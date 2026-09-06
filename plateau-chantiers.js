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
