// =====================
// PLATEAU-COMMERCE.JS — MOTEUR GENERIQUE DES COMMERCES PJ (Lot 4.0)
// =====================
// Douze familles de commerces, un seul moteur. Ce fichier ne contient AUCUNE regle propre a une
// famille : il porte les registres, les verdicts et les formules communes, et chaque famille n'est
// qu'une configuration.
//
// CONTRAT : pur. Aucune ecriture, aucun DOM, aucun reseau, aucune dependance a state. Les
// mouvements d'argent et de stock appartiennent aux RPC (migration_moteur_commerce.sql).
//
// CE QU'IL REPREND DE L'EXISTANT, sans le reecrire : le calcul du cout de revient sur le cout
// MOYEN REELLEMENT PAYE (coutMoyenMatieres, releve economique du 17 aout 2026), le prix PNJ a
// x2, et la structure de commerce de chargerCommerce/defautCommerce. L'audit du 8 septembre 2026
// a etabli que ces briques fonctionnent : on les generalise, on ne les remplace pas.

// ---------------------------------------------------------------------------
// REGISTRE DES FAMILLES
// ---------------------------------------------------------------------------
// UN FONDS = UNE FAMILLE. La famille contraint ce qu'on peut produire, vendre et faire ; elle ne
// duplique jamais de moteur.
//
//   sousTypes           : sous-types FONCTIONNELS, jamais la forme physique du produit
//   ciblesEffetPermises : ce que les produits de cette famille ont le droit de toucher
//   qualifications      : qualifications susceptibles d'etre exigees par ses recettes
//   individualisation   : 'jamais' | 'possible' | 'systematique'
const FAMILLES_COMMERCE = {
  alimentaire:  { label: 'Alimentaire',              sousTypes: ['energie', 'alicament', 'regressif', 'festif', 'courant'],
                  ciblesEffetPermises: ['pj'],                 individualisation: 'jamais',
                  qualifications: ['restauration'] },
  mobilier:     { label: 'Mobilier',                 sousTypes: ['repos', 'prestige', 'rangement', 'decoration'],
                  ciblesEffetPermises: ['pj', 'lieu', 'collectif'], individualisation: 'possible',
                  qualifications: ['menuiserie'] },
  armement:     { label: 'Armement',                 sousTypes: ['arme', 'explosif', 'arme_lourde', 'protection_individuelle', 'protection_batiment'],
                  ciblesEffetPermises: ['pj', 'lieu'],         individualisation: 'possible',
                  qualifications: ['armurerie'] },
  deplacement:  { label: 'Déplacement',              sousTypes: ['mobilite_legere', 'automobile', 'bus', 'camion', 'utilitaire'],
                  ciblesEffetPermises: ['pj'],                 individualisation: 'systematique',
                  qualifications: ['mecanique'] },
  services:     { label: 'Services',                 sousTypes: ['travail_specialise', 'logistique', 'securite_enquete', 'professionnel', 'personnel'],
                  ciblesEffetPermises: ['pj', 'lieu', 'objet'], individualisation: 'jamais',
                  qualifications: [] },
  communication:{ label: 'Communication',            sousTypes: ['presse', 'materiel', 'agence'],
                  ciblesEffetPermises: ['pj', 'collectif'],    individualisation: 'possible',
                  qualifications: ['communication'] },
  habillement:  { label: 'Habillement',              sousTypes: ['civil', 'militaire'],
                  ciblesEffetPermises: ['pj'],                 individualisation: 'possible',
                  qualifications: ['couture'] },
  sante:        { label: 'Santé / Hygiène',          sousTypes: ['medicament', 'soin_hygiene', 'entretien', 'materiel_soin'],
                  ciblesEffetPermises: ['pj', 'objet', 'lieu'], individualisation: 'jamais',
                  qualifications: ['medecine', 'pharmacie'] },
  culture:      { label: 'Culture / Loisirs',        sousTypes: ['edition', 'audiovisuel', 'sport'],
                  ciblesEffetPermises: ['pj', 'collectif'],    individualisation: 'possible',
                  qualifications: ['edition'] },
  artisanat:    { label: 'Artisanat / Luxe',         sousTypes: ['bijou', 'oeuvre', 'horlogerie', 'trophee', 'commemoratif'],
                  ciblesEffetPermises: ['pj', 'lieu', 'collectif'], individualisation: 'systematique',
                  qualifications: ['artisanat_art'] },
  finance:      { label: 'Finance',                  sousTypes: ['depot', 'credit', 'coffre'],
                  ciblesEffetPermises: [],                     individualisation: 'jamais',
                  qualifications: ['finance'] },
  bazar:        { label: 'Bazar / Quincaillerie',    sousTypes: ['outil', 'appareil', 'entretien', 'cle', 'divers'],
                  ciblesEffetPermises: ['pj', 'objet', 'lieu'], individualisation: 'possible',
                  qualifications: [] }
};

function familleConnue(famille) {
  return Object.prototype.hasOwnProperty.call(FAMILLES_COMMERCE, famille);
}

function familleDe(fonds) {
  const f = fonds && fonds.famille;
  return familleConnue(f) ? f : null;
}

function sousTypeAutorise(famille, sousType) {
  const f = FAMILLES_COMMERCE[famille];
  return !!(f && f.sousTypes.indexOf(sousType) !== -1);
}

function cibleEffetAutorisee(famille, cible) {
  const f = FAMILLES_COMMERCE[famille];
  return !!(f && f.ciblesEffetPermises.indexOf(cible) !== -1);
}

// ---------------------------------------------------------------------------
// QUALIFICATIONS PROFESSIONNELLES
// ---------------------------------------------------------------------------
// PROPRIETE != QUALIFICATION != TRAVAIL. Principe definitivement valide : n'importe qui peut
// posseder et gerer un commerce, un heritier ne perd jamais le sien faute de diplome. Seule
// l'EXECUTION d'une tache peut etre refusee.
//
// Qualifications LARGES, jamais un diplome par produit. Ce registre porte l'architecture ; les
// cursus, durees et prix universitaires seront definis plus tard -- ils n'ont pas a exister pour
// que le socle fonctionne.
//
//   origines : d'ou elle peut venir. 'etudes' = accordee par le parcours initial (school/career),
//              'universite' = acquise plus tard, 'terrain' = reserve pour un futur acquis pratique.
const QUALIFICATIONS = {
  restauration:   { label: 'Restauration',              origines: ['etudes', 'universite'] },
  menuiserie:     { label: 'Menuiserie',                origines: ['etudes', 'universite'] },
  armurerie:      { label: 'Armurerie',                 origines: ['etudes', 'universite'] },
  mecanique:      { label: 'Mécanique',                 origines: ['etudes', 'universite'] },
  communication:  { label: 'Communication',             origines: ['etudes', 'universite'] },
  couture:        { label: 'Couture',                   origines: ['etudes', 'universite'] },
  medecine:       { label: 'Médecine',                  origines: ['universite'] },
  pharmacie:      { label: 'Pharmacie',                 origines: ['universite'] },
  edition:        { label: 'Édition',                   origines: ['etudes', 'universite'] },
  artisanat_art:  { label: "Artisanat d'art",           origines: ['etudes', 'universite'] },
  finance:        { label: 'Finance',                   origines: ['etudes', 'universite'] }
};

// CONFIGURATION PROVISOIRE — correspondance carriere initiale -> qualification.
//
// Elle reutilise career, persiste depuis toujours mais que l'audit a trouve inerte apres la
// creation du personnage. Le MOTEUR ne depend pas de cette table : il lit
// QUALIFICATIONS_PAR_CARRIERE, quel qu'en soit le contenu, et fonctionne identiquement si elle
// est vide. C'est une donnee de configuration, pas une regle du moteur.
//
// DELIBEREMENT MINIMALE. Seules figurent ici les deux carrieres dont l'intitule NOMME lui-meme le
// domaine -- "Medecin / Universitaire" et "Medias & Communication". Toutes les autres restent sans
// qualification automatique : deduire "menuiserie" de "Monde ouvrier" ou "armurerie" de "Officier
// superieur" serait choisir une nomenclature que le game design n'a pas arretee, et sur-specialiser
// des qualifications qui doivent rester larges. Le chantier Universite/qualifications tranchera ;
// d'ici la, personne ne recoit une qualification qu'on ne lui a pas accordee.
const QUALIFICATIONS_PAR_CARRIERE = {
  doctor: ['medecine'],
  press:  ['communication']
};

function qualificationConnue(cle) {
  return Object.prototype.hasOwnProperty.call(QUALIFICATIONS, cle);
}

// Qualifications d'un personnage : celles de son parcours initial, plus celles acquises ensuite.
// Le cumul est la regle -- on n'oublie pas un metier en en apprenant un autre.
function qualificationsDe(perso) {
  const p = perso || {};
  const acquises = Array.isArray(p.qualifications) ? p.qualifications : [];
  const initiales = QUALIFICATIONS_PAR_CARRIERE[p.career] || [];
  const toutes = {};
  initiales.concat(acquises).forEach(function (q) {
    const c = (typeof q === 'string') ? q.trim() : (q && q.cle);
    if (c && qualificationConnue(c)) toutes[c] = true;
  });
  return Object.keys(toutes);
}

function possedeQualification(perso, cle) {
  if (!cle) return true;                          // aucune exigence : tout le monde passe
  return qualificationsDe(perso).indexOf(cle) !== -1;
}

// ---------------------------------------------------------------------------
// EMPLOI PJ -> PJ
// ---------------------------------------------------------------------------
// Un fonds peut employer des PJ. C'est le seul moyen, pour un proprietaire non qualifie,
// d'exercer une activite qui exige une qualification -- et c'est voulu : cela cree une
// dependance entre joueurs plutot qu'un clic solitaire.
//
// Les salaries vivent DANS le fonds (entreprises.data.salaries[]), pas dans une table separee :
// un salarie n'a de sens que rattache a son employeur, et le fonds est deja un document.
//
// 1 heure de travail = 1 PA. La remuneration est LIBRE ; le minimum legal n'est pas code ici,
// seulement rendu possible (voir SALAIRE_MINIMUM_HORAIRE, configurable et nul par defaut).
const SALAIRE_MINIMUM_HORAIRE = { republic: 0, narco: 0, soviet: 0, khalija: 0 };

function salaireMinimumHoraire(pays) {
  const v = SALAIRE_MINIMUM_HORAIRE[pays];
  return (typeof v === 'number' && isFinite(v) && v > 0) ? v : 0;
}

function salariesDe(fonds) {
  const s = (fonds && Array.isArray(fonds.salaries)) ? fonds.salaries : [];
  return s.filter(function (e) { return e && e.actif !== false; });
}

function estSalarieDe(fonds, refPersonne) {
  const r = (typeof refPersonne === 'string') ? refPersonne.trim() : '';
  if (!r) return false;
  return salariesDe(fonds).some(function (e) { return e.ref === r; });
}

function verdictEmbauche(fonds, refEmployeur, refSalarie, contrat) {
  if (!fonds) return { ok: false, raison: 'fonds_absent' };
  if (fonds.proprietaire !== refEmployeur) return { ok: false, raison: 'pas_proprietaire' };
  if (!refSalarie) return { ok: false, raison: 'salarie_invalide' };
  if (refSalarie === refEmployeur) return { ok: false, raison: 'auto_embauche' };
  if (estSalarieDe(fonds, refSalarie)) return { ok: false, raison: 'deja_salarie' };
  const c = contrat || {};
  const taux = Math.max(0, Math.floor(Number(c.tauxHoraire) || 0));
  const mini = salaireMinimumHoraire(c.pays);
  if (mini > 0 && taux < mini) return { ok: false, raison: 'sous_minimum_legal', minimum: mini };
  const role = (typeof c.role === 'string' && c.role.trim()) ? c.role.trim() : 'Employé';
  return { ok: true, raison: null, contrat: { ref: refSalarie, role: role, tauxHoraire: taux, actif: true } };
}

// Qui a le droit d'EXECUTER une tache pour ce fonds ? Le proprietaire ou un salarie actif -- et
// seulement s'il detient la qualification exigee. Un proprietaire non qualifie garde son commerce,
// il ne peut simplement pas faire ce travail-la lui-meme.
function verdictExecutionTache(fonds, refActeur, persoActeur, qualificationRequise) {
  if (!fonds) return { ok: false, raison: 'fonds_absent' };
  const estProprietaire = fonds.proprietaire === refActeur;
  const estSalarie = estSalarieDe(fonds, refActeur);
  if (!estProprietaire && !estSalarie) return { ok: false, raison: 'pas_habilite' };
  if (qualificationRequise && !possedeQualification(persoActeur, qualificationRequise)) {
    return { ok: false, raison: 'qualification_manquante', qualification: qualificationRequise,
             // La sortie est nommee : un proprietaire non qualifie doit savoir qu'il peut embaucher.
             remede: estProprietaire ? 'embaucher_pj_qualifie' : null };
  }
  return { ok: true, raison: null, role: estProprietaire ? 'proprietaire' : 'salarie' };
}

// ---------------------------------------------------------------------------
// MATIERES PREMIERES ACHETEES PAR LE COMMERCE
// ---------------------------------------------------------------------------
// Le commerce n'achete que ce qu'il a explicitement ACTIVE, au prix qu'il fixe. Un visiteur peut
// alors lui vendre cette matiere. Le suivi du cout moyen pondere reel reste celui de l'existant --
// on ne le reecrit pas.

function matieresRecherchees(fonds) {
  const m = (fonds && fonds.matieresRecherchees) || {};
  return Object.keys(m).filter(function (k) { return m[k] && m[k].active === true; })
    .map(function (k) { return { matiere: k, prixAchat: Math.max(0, Math.floor(Number(m[k].prixAchat) || 0)) }; });
}

function verdictVenteMatiereAuCommerce(fonds, matiere, quantite, stockVendeur) {
  if (!fonds) return { ok: false, raison: 'fonds_absent' };
  const recherchee = matieresRecherchees(fonds).find(function (m) { return m.matiere === matiere; });
  if (!recherchee) return { ok: false, raison: 'matiere_non_recherchee' };
  if (recherchee.prixAchat <= 0) return { ok: false, raison: 'prix_achat_nul' };
  const q = Math.floor(Number(quantite) || 0);
  if (q <= 0) return { ok: false, raison: 'quantite_invalide' };
  const dispo = Math.max(0, Math.floor(Number(stockVendeur) || 0));
  if (q > dispo) return { ok: false, raison: 'stock_insuffisant' };
  const caisse = Math.max(0, Math.floor(Number(fonds.caisse) || 0));
  const payables = Math.floor(caisse / recherchee.prixAchat);
  const retenue = Math.min(q, payables);
  if (retenue <= 0) return { ok: false, raison: 'caisse_insuffisante' };
  return { ok: true, raison: null, quantite: retenue, prixUnitaire: recherchee.prixAchat,
           montant: retenue * recherchee.prixAchat };
}

// ---------------------------------------------------------------------------
// COUT DE REVIENT ET PRIX
// ---------------------------------------------------------------------------
// Formule reprise telle quelle de l'existant : (cout REEL des matieres + valeur du travail) /
// quantite produite. Les matieres sont toujours valorisees au cout moyen effectivement paye,
// jamais a un cours theorique.
//
// DEUX GRANDEURS DISTINCTES, ET C'EST DELIBERE :
//   - la VALEUR COMPTABLE du travail (valeurTravailRecette), qui entre dans le cout de revient
//     pour que le prix ait un sens, meme quand personne n'a ete paye ;
//   - la REMUNERATION REELLEMENT VERSEE (remunerationTravail), qui sort de la caisse.
// Les confondre reviendrait a inventer un paiement la ou il n'y en a pas. Un proprietaire qui
// travaille lui-meme ne se verse rien : le moteur ne lui impose aucun salaire, et aucune sortie
// monetaire automatique n'est creee. La maniere de valoriser comptablement ce travail-la
// appartient a un arbitrage de game design a venir.
const COUT_HORAIRE_TRAVAIL = 50;                 // 1 PA = 1 heure = 50 FR, reference existante
const COEF_PRIX_PNJ = 2;                         // prix PNJ = cout de revient x2, existant
// Plafond du prix libre d'un PJ. HYPOTHESE DE GAME DESIGN PROVISOIRE, centralisee ici et nulle
// part ailleurs : elle n'apparait dans aucune RPC (le serveur relit le prix deja fixe dans le
// catalogue, il ne le replafonne pas) ni dans aucune migration. La rendre globale, dependante de
// la famille ou nulle se fera en changeant cette constante et la seule fonction qui la lit.
const COEF_PRIX_MAX_PJ = 4;

// VALEUR COMPTABLE du travail contenu dans une recette. Convention de calcul, jamais un
// paiement : elle sert a etablir un cout de revient meme lorsque le travail n'a coute aucun FR
// (proprietaire travaillant lui-meme). Aucun mouvement d'argent ne decoule de cette fonction.
function valeurTravailRecette(recette) {
  return Math.max(0, Number((recette || {}).heures) || 0) * COUT_HORAIRE_TRAVAIL;
}

function coutRevientUnitaire(fonds, recette) {
  const r = recette || {};
  const couts = (fonds && fonds.coutMoyenMatieres) || {};
  const matieres = Object.keys(r.matieres || {}).reduce(function (s, m) {
    return s + (Number(r.matieres[m]) || 0) * (Number(couts[m]) || 0);
  }, 0);
  const produit = Math.max(1, Math.floor(Number(r.produit) || 1));
  return (matieres + valeurTravailRecette(r)) / produit;
}

function prixPNJ(coutRevient) {
  return Math.round(Math.max(0, Number(coutRevient) || 0) * COEF_PRIX_PNJ);
}

function prixMaximumPJ(coutRevient) {
  return Math.ceil(Math.max(0, Number(coutRevient) || 0) * COEF_PRIX_MAX_PJ);
}

function verdictPrixVente(coutRevient, prixDemande) {
  const p = Math.floor(Number(prixDemande) || 0);
  if (p <= 0) return { ok: false, raison: 'prix_invalide' };
  const max = prixMaximumPJ(coutRevient);
  if (max > 0 && p > max) return { ok: false, raison: 'prix_au_dessus_du_plafond', maximum: max };
  return { ok: true, raison: null, prix: p };
}

// ---------------------------------------------------------------------------
// CATALOGUE : REFERENCES ACTIVES ET INACTIVES
// ---------------------------------------------------------------------------
// L'audit a montre que data.carte ne connait que "presente" ou "retiree" : desactiver une
// reference lui faisait perdre son prix et son stock. Une reference devient ici un OBJET durable
// qu'on active ou desactive sans rien perdre.
//
// Le plafond de references ACTIVES est configurable. Le premium pourra plus tard l'augmenter --
// jamais debloquer une fonctionnalite : un commerce gratuit reste pleinement fonctionnel, il
// propose seulement moins de choses a la fois.
//
// VALEUR TECHNIQUE PROVISOIRE, pas une regle de jeu arretee. Aucune mecanique ne depend de 6 en
// particulier : le nombre n'apparait qu'ici, il n'est compare nulle part ailleurs, il ne figure
// dans aucune migration et aucune interface ne l'annonce comme definitif. Le remplacer se fait en
// changeant cette seule ligne, sans migration ni reecriture. Meme statut pour fonds.bonusReferences,
// simple increment additif lu ci-dessous.
const PLAFOND_REFERENCES_ACTIVES_BASE = 6;

function plafondReferencesActives(fonds) {
  const bonus = Math.max(0, Math.floor(Number((fonds || {}).bonusReferences) || 0));
  return PLAFOND_REFERENCES_ACTIVES_BASE + bonus;
}

function referencesDe(fonds) {
  const refs = (fonds && fonds.references) || {};
  return Object.keys(refs).map(function (k) {
    const r = refs[k] || {};
    return { id: k, recetteId: r.recetteId || k, active: r.active === true,
             prixVente: Math.max(0, Math.floor(Number(r.prixVente) || 0)),
             stock: Math.max(0, Math.floor(Number(r.stock) || 0)),
             stockMax: Math.max(0, Math.floor(Number(r.stockMax) || 0)) };
  });
}

function referencesActives(fonds) {
  return referencesDe(fonds).filter(function (r) { return r.active; });
}

function verdictActivationReference(fonds, referenceId, activer) {
  if (!fonds) return { ok: false, raison: 'fonds_absent' };
  const refs = (fonds.references) || {};
  if (!Object.prototype.hasOwnProperty.call(refs, referenceId)) {
    return { ok: false, raison: 'reference_absente' };
  }
  if (!activer) return { ok: true, raison: null, active: false };
  const dejaActive = (refs[referenceId] || {}).active === true;
  if (dejaActive) return { ok: true, raison: null, active: true };
  const plafond = plafondReferencesActives(fonds);
  if (referencesActives(fonds).length >= plafond) {
    return { ok: false, raison: 'plafond_references_atteint', plafond: plafond };
  }
  return { ok: true, raison: null, active: true };
}

// ---------------------------------------------------------------------------
// PRODUCTION GENERIQUE
// ---------------------------------------------------------------------------
// Une recette declare ses matieres, ses heures, sa quantite produite, sa famille compatible et
// sa qualification eventuelle. Le moteur ne connait aucun produit en particulier.
//
// PAS D'AUTO-PRODUCTION PNJ pour un commerce PJ : quelqu'un doit travailler, et ce quelqu'un est
// soit le proprietaire, soit un salarie -- avec la qualification requise s'il y en a une.

function verdictProduction(fonds, recette, refActeur, persoActeur, paDisponibles) {
  if (!fonds) return { ok: false, raison: 'fonds_absent' };
  const r = recette || {};
  const famille = familleDe(fonds);
  if (!famille) return { ok: false, raison: 'famille_inconnue' };
  if (r.famille && r.famille !== famille) return { ok: false, raison: 'famille_incompatible' };

  const habilitation = verdictExecutionTache(fonds, refActeur, persoActeur, r.qualification);
  if (!habilitation.ok) return habilitation;

  const heures = Math.max(1, Math.floor(Number(r.heures) || 1));
  const pa = Math.max(0, Math.floor(Number(paDisponibles) || 0));
  if (pa < heures) return { ok: false, raison: 'pa_insuffisants', requis: heures };

  const manquantes = [];
  const stock = fonds.stockMatieres || {};
  Object.keys(r.matieres || {}).forEach(function (m) {
    const requis = Math.max(0, Number(r.matieres[m]) || 0);
    const dispo = Math.max(0, Number(stock[m]) || 0);
    if (dispo < requis) manquantes.push({ matiere: m, requis: requis, dispo: dispo });
  });
  if (manquantes.length > 0) return { ok: false, raison: 'matieres_manquantes', manquantes: manquantes };

  // La caisse n'est opposee QUE s'il y a reellement quelqu'un a payer : un salarie n'accepte pas
  // de travailler a credit. Un proprietaire qui travaille lui-meme ne coute rien a sa caisse, et
  // un commerce sans tresorerie peut donc continuer a produire par son seul travail.
  const remuneration = remunerationTravail(fonds, refActeur, heures);
  const caisse = Math.max(0, Math.floor(Number(fonds.caisse) || 0));
  if (remuneration > 0 && remuneration > caisse) {
    return { ok: false, raison: 'caisse_insuffisante', requis: remuneration };
  }

  const produit = Math.max(1, Math.floor(Number(r.produit) || 1));
  const ref = (fonds.references || {})[r.id] || {};
  const stockMax = Math.max(0, Math.floor(Number(ref.stockMax) || 0));
  const place = stockMax > 0 ? Math.max(0, stockMax - Math.max(0, Math.floor(Number(ref.stock) || 0))) : produit;
  if (place <= 0) return { ok: false, raison: 'stock_plein', stockMax: stockMax };

  return { ok: true, raison: null, heures: heures, remuneration: remuneration,
           quantite: Math.min(produit, place), role: habilitation.role,
           coutRevient: coutRevientUnitaire(fonds, r) };
}

// REMUNERATION REELLEMENT VERSEE. Un salarie est paye au taux de SON contrat -- c'est un engagement
// pris envers un autre joueur, la caisse doit pouvoir l'honorer. Un proprietaire qui travaille
// lui-meme ne recoit rien : aucun salaire ne lui est impose, et aucune sortie monetaire
// automatique n'est fabriquee. Il travaille dans son commerce, il ne se facture pas.
function remunerationTravail(fonds, refActeur, heures) {
  const h = Math.max(0, Math.floor(Number(heures) || 0));
  const salarie = salariesDe(fonds).find(function (e) { return e.ref === refActeur; });
  if (!salarie) return 0;
  return h * Math.max(0, Math.floor(Number(salarie.tauxHoraire) || 0));
}

// ---------------------------------------------------------------------------
// ACHAT PAR UN CLIENT
// ---------------------------------------------------------------------------
// ACHETER N'EST PAS UTILISER. La transaction ne fait que deplacer un objet du commerce vers
// l'inventaire ; aucun effet n'est declenche ici. C'est le principe le plus structurant du lot.

function verdictAchat(fonds, referenceId, quantiteVoulue, fondsAcheteur) {
  if (!fonds) return { ok: false, raison: 'fonds_absent' };
  const ref = referencesDe(fonds).find(function (r) { return r.id === referenceId; });
  if (!ref) return { ok: false, raison: 'reference_absente' };
  if (!ref.active) return { ok: false, raison: 'reference_inactive' };
  if (ref.prixVente <= 0) return { ok: false, raison: 'prix_non_fixe' };

  const voulue = Math.floor(Number(quantiteVoulue) || 0);
  if (voulue <= 0) return { ok: false, raison: 'quantite_invalide' };
  if (ref.stock <= 0) return { ok: false, raison: 'rupture_de_stock' };

  const argent = Math.max(0, Math.floor(Number(fondsAcheteur) || 0));
  const abordables = Math.floor(argent / ref.prixVente);
  const quantite = Math.min(voulue, ref.stock, abordables);
  if (quantite <= 0) return { ok: false, raison: 'fonds_insuffisants', prixUnitaire: ref.prixVente };

  return { ok: true, raison: null, quantite: quantite, prixUnitaire: ref.prixVente,
           montant: quantite * ref.prixVente, reference: ref };
}

// ---------------------------------------------------------------------------
// OFFRE / ACCEPTATION GENERIQUE
// ---------------------------------------------------------------------------
// L'audit a identifie ce manque comme bloquant : chaque mecanique bilaterale a aujourd'hui sa
// table et sa logique, et l'absence de canal commun empeche la vente d'objet entre PJ, la vente
// de fonds et l'accord amiable -- dont les RPC sont pretes mais inaccessibles au navigateur.
//
// Une offre est une PROPOSITION datee qu'un tiers accepte ou refuse. Elle ne transfere rien par
// elle-meme.
//
// ETAT ACTUEL, A CONNAITRE : repondre_offre etablit et enregistre le CONSENTEMENT -- exactement la
// preuve qui manquait au jeu -- mais n'execute encore AUCUN transfert d'actif. L'orchestration qui
// enchainera une acceptation vers la RPC specialisee correspondante (vendre_fonds_commerce pour
// une vente de fonds, terminer_bail pour un accord amiable, un transfert d'objet pour une vente
// d'objet) RESTE A BRANCHER, et devra l'etre de facon atomique. En l'etat, une offre acceptee est
// un accord constate, pas une operation realisee.
//
// OU S'ARRETE CE MODULE. La table offres est en ECRITURE FERMEE : le navigateur ne peut pas y
// inserer de ligne, seule la RPC creer_offre le peut. Les verdicts ci-dessous sont donc une
// PRE-VALIDATION D'INTERFACE -- ils evitent un aller-retour reseau pour une offre manifestement
// mal formee -- et NON une autorisation. L'autorite est cote serveur, integralement : c'est elle
// qui pose l'identifiant, la date, l'expiration et le statut, qui verifie l'existence des deux
// parties, et qui exige de l'emetteur qu'il detienne reellement le fonds ou soit partie au bail.
// Contourner ce module ne donne donc rien de plus que de l'appeler.
const TYPES_OFFRE = ['vente_objet', 'vente_fonds', 'resiliation_amiable', 'prestation'];
const OFFRE_STATUTS = ['ouverte', 'acceptee', 'refusee', 'expiree', 'annulee'];
const OFFRE_DUREE_MS_DEFAUT = 3 * 24 * 60 * 60 * 1000;   // 3 jours reels
// Bornes MIROIR de celles de creer_offre : le serveur ramene de toute facon la duree dans cet
// intervalle. Les repeter ici evite que l'interface annonce une echeance que la base ne tiendra
// pas -- si l'une des deux bouge, l'autre doit bouger.
const OFFRE_DUREE_MS_MIN = 60 * 60 * 1000;               // 1 heure
const OFFRE_DUREE_MS_MAX = 30 * 24 * 60 * 60 * 1000;     // 30 jours

// Champs qu'un client ne choisit JAMAIS : ils ne sont pas des parametres de creer_offre, le
// serveur les pose. Cette liste est le contrat, et les tests s'y adossent.
const CHAMPS_OFFRE_SERVEUR = ['id', 'statut', 'creeA', 'expireA', 'resoluA'];

function offreExpiree(offre, maintenantMs) {
  const exp = Number((offre || {}).expireA);
  return isFinite(exp) && exp > 0 && exp <= (Number(maintenantMs) || 0);
}

function offreOuverte(offre, maintenantMs) {
  return !!(offre && offre.statut === 'ouverte' && !offreExpiree(offre, maintenantMs));
}

function verdictCreationOffre(offre, maintenantMs) {
  const o = offre || {};
  if (TYPES_OFFRE.indexOf(o.type) === -1) return { ok: false, raison: 'type_invalide' };
  const em = (typeof o.emetteur === 'string') ? o.emetteur.trim() : '';
  const de = (typeof o.destinataire === 'string') ? o.destinataire.trim() : '';
  if (!em) return { ok: false, raison: 'emetteur_invalide' };
  if (!de) return { ok: false, raison: 'destinataire_invalide' };
  if (em === de) return { ok: false, raison: 'destinataire_identique' };
  const montant = Math.floor(Number(o.montant) || 0);
  if (montant < 0) return { ok: false, raison: 'montant_invalide' };
  let duree = Math.max(0, Math.floor(Number(o.dureeMs) || 0)) || OFFRE_DUREE_MS_DEFAUT;
  duree = Math.min(OFFRE_DUREE_MS_MAX, Math.max(OFFRE_DUREE_MS_MIN, duree));
  // L'objet rendu est RECONSTRUIT champ par champ, jamais copie depuis l'entree : un statut, un id
  // ou une date d'expiration presents dans o sont donc ignores, ici comme dans la RPC.
  return { ok: true, raison: null,
           offre: { type: o.type, emetteur: em, destinataire: de, actif: o.actif || null,
                    montant: montant, statut: 'ouverte',
                    creeA: Number(maintenantMs) || 0, expireA: (Number(maintenantMs) || 0) + duree } };
}

function verdictAcceptationOffre(offre, refAcceptant, maintenantMs) {
  if (!offre) return { ok: false, raison: 'offre_absente' };
  if (offre.statut !== 'ouverte') return { ok: false, raison: 'offre_close', statut: offre.statut };
  if (offreExpiree(offre, maintenantMs)) return { ok: false, raison: 'offre_expiree' };
  if (offre.destinataire !== refAcceptant) return { ok: false, raison: 'pas_destinataire' };
  return { ok: true, raison: null };
}

// ---------------------------------------------------------------------------
// EXECUTION DES OFFRES ACCEPTEES (Lot 4.1)
// ---------------------------------------------------------------------------
// CONSENTEMENT ET OPERATION SONT DEUX CHOSES. Le Lot 4.0 ne savait dire que la premiere, et
// 'acceptee' laissait croire a la seconde. Deux axes desormais :
//
//   statut     ouverte | acceptee | refusee | expiree | annulee     ce que les parties ont voulu
//   execution  sans_objet | executee | non_disponible               ce que le serveur a fait
//
// Les quatre etats a distinguer se lisent directement, sans valeur composite a interpreter :
//   1. ouverte                         statut 'ouverte'    execution 'sans_objet'
//   2. refusee / annulee / expiree     statut ...          execution 'sans_objet'
//   3. acceptee ET executee            statut 'acceptee'   execution 'executee'
//   4. acceptee, moteur absent         statut 'acceptee'   execution 'non_disponible'
//
// Le cas 4 ne concerne que vente_objet et prestation. Une offre vente_fonds ou
// resiliation_amiable acceptee est necessairement executee : si l'operation echoue, l'offre n'est
// pas acceptee du tout et RESTE OUVERTE -- un echec ne doit pas consommer un accord.
const OFFRE_EXECUTIONS = ['sans_objet', 'executee', 'non_disponible'];
// Les seuls types dont le serveur sait executer l'operation. La liste grandira quand un moteur
// existera ; le tableau est le seul endroit a changer.
const TYPES_OFFRE_EXECUTABLES = ['vente_fonds', 'resiliation_amiable'];

function executionOffre(offre) {
  const e = (offre || {}).execution;
  return OFFRE_EXECUTIONS.indexOf(e) === -1 ? 'sans_objet' : e;
}

// Un accord qui n'a rien produit : c'est la file d'attente du jour ou vente_objet et prestation
// auront un moteur. A ne jamais presenter comme une operation realisee.
function offreAccordSansExecution(offre) {
  return !!offre && offre.statut === 'acceptee' && executionOffre(offre) === 'non_disponible';
}

function offreReellementExecutee(offre) {
  return !!offre && offre.statut === 'acceptee' && executionOffre(offre) === 'executee';
}

// MIROIR EXACT de repondre_offre (migration Lot 4.1). Sert a l'interface pour anticiper le verdict
// sans aller-retour, et de table de decision testable. NON AUTORITAIRE : c'est la RPC qui tranche,
// sous verrou, sur l'etat reel de la base -- ce module lit un contexte que l'appelant lui donne et
// qui peut deja etre perime. Toute divergence entre les deux est un defaut de ce module.
//
// contexte : { fonds: {proprietaire, statut}, bail: {locataireRef|locataire}, bailleur: ref }
function verdictExecutionOffre(offre, refActeur, accepte, contexte, maintenantMs) {
  const ctx = contexte || {};
  if (!offre) return { ok: false, raison: 'offre_absente' };

  if (offre.statut !== 'ouverte') {
    return { ok: true, dejaResolue: true, statut: offre.statut, execution: executionOffre(offre) };
  }
  if (offreExpiree(offre, maintenantMs)) {
    return { ok: false, raison: 'offre_expiree', statut: 'expiree', execution: 'sans_objet' };
  }

  // L'emetteur ne peut qu'annuler la sienne : accepter sa propre offre reviendrait a se donner le
  // consentement de l'autre, c'est-a-dire a supprimer la seule chose que ce canal apporte.
  if (refActeur === offre.emetteur) {
    if (accepte === true) return { ok: false, raison: 'emetteur_ne_peut_accepter' };
    return { ok: true, dejaResolue: false, statut: 'annulee', execution: 'sans_objet' };
  }
  if (refActeur !== offre.destinataire) return { ok: false, raison: 'pas_partie_a_l_offre' };

  if (accepte !== true) {
    return { ok: true, dejaResolue: false, statut: 'refusee', execution: 'sans_objet' };
  }

  // ---- Revalidation : l'offre a pu etre creee il y a trois jours, c'est l'etat d'AUJOURD'HUI qui
  // ---- fait foi. Un echec laisse l'offre OUVERTE, il ne la consomme pas.
  if (offre.type === 'vente_fonds') {
    const f = ctx.fonds;
    if (!offre.actif) return { ok: false, raison: 'fonds_requis', statut: 'ouverte' };
    if (!f) return { ok: false, raison: 'fonds_absent', statut: 'ouverte' };
    if (f.proprietaire !== offre.emetteur) {
      return { ok: false, raison: 'vendeur_plus_proprietaire', statut: 'ouverte' };
    }
    if ((f.statut || 'actif') !== 'actif') {
      return { ok: false, raison: 'fonds_non_vendable', statut: 'ouverte' };
    }
    return { ok: true, dejaResolue: false, statut: 'acceptee', execution: 'executee',
             operation: 'vendre_fonds_commerce' };
  }

  if (offre.type === 'resiliation_amiable') {
    const b = ctx.bail;
    if (!offre.actif) return { ok: false, raison: 'bail_requis', statut: 'ouverte' };
    if (!b) return { ok: false, raison: 'bail_deja_termine', statut: 'ouverte' };
    const loc = b.locataireRef || ('pj:' + (b.locataire || ''));
    // Proprietaire ACTUEL des murs : des murs vendus entre la creation et l'acceptation changent
    // le bailleur, et l'accord ne vaut plus -- le nouveau proprietaire n'a rien signe.
    const bai = ctx.bailleur;
    const paire = (offre.emetteur === loc && offre.destinataire === bai)
               || (offre.emetteur === bai && offre.destinataire === loc);
    if (!paire) return { ok: false, raison: 'parties_ne_correspondent_plus', statut: 'ouverte' };
    return { ok: true, dejaResolue: false, statut: 'acceptee', execution: 'executee',
             operation: 'terminer_bail' };
  }

  // vente_objet et prestation : ACCORD CONSTATE, OPERATION INDISPONIBLE, ET AUCUN FR NE BOUGE.
  // Un objet vit dans l'inventaire que le client reecrit entierement : le serveur ne peut ni
  // prouver que le vendeur le detient encore, ni le lui retirer. Le remettre a l'acheteur le
  // DUPLIQUERAIT. Deplacer l'argent en esperant que l'objet suive serait la creation de valeur que
  // tout ce lot cherche a empecher.
  return { ok: true, dejaResolue: false, statut: 'acceptee', execution: 'non_disponible',
           raison: 'execution_non_disponible', operation: null };
}
