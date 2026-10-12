// ============================================================================
// REFERENTIELS DU JEU, POUR LE SERVEUR -- FICHIER GENERE, NE PAS MODIFIER
// ============================================================================
//
// Genere par outils/generateurs/generer_referentiels_serveur.py depuis les
// sources canoniques du navigateur, chargees dans JavaScriptCore. Ce fichier
// est un ARTEFACT TECHNIQUE : il n'est pas une source de verite, et une valeur
// corrigee ici serait perdue a la prochaine generation -- apres avoir fait
// diverger le serveur du jeu, ce que ce chantier existe pour empecher.
//
// Pour changer une de ces valeurs : la changer dans sa source canonique, puis
// rejouer le generateur. Les sources sont nommees ci-dessous, une par
// constante.
//
// verifier-referentiels.py rejoue cette generation a chaque passage et refuse
// si le fichier sur le disque ne correspond plus.
//
// NE CONTIENT QUE CE QUI EST PROUVE EQUIVALENT. Les copies qui divergent de
// leur canon sont restees a la main dans api/cron-minuit.js, et la divergence
// est declaree dans outils/generateurs/referentiels-serveur.json. On ne fait
// pas disparaitre un arbitrage de game design en le regenerant.
// ============================================================================

// GREVE_PALIERS_SERVEUR -- GREVE_PALIERS de data.js
export const GREVE_PALIERS_SERVEUR = [
  {
    "min": 5,
    "max": 24,
    "pop": 10,
    "social": 1,
    "entrepriseReduction": 0.1,
    "orgaInf": 1
  },
  {
    "min": 25,
    "max": 49,
    "pop": 20,
    "social": 1,
    "entrepriseReduction": 0.2,
    "orgaInf": 2
  },
  {
    "min": 50,
    "max": 74,
    "pop": 30,
    "social": 1,
    "entrepriseReduction": 0.3,
    "orgaInf": 3
  },
  {
    "min": 75,
    "max": 99,
    "pop": 40,
    "social": 1,
    "entrepriseReduction": 0.4,
    "orgaInf": 4
  },
  {
    "min": 100,
    "max": Infinity,
    "pop": 50,
    "social": 1,
    "entrepriseReduction": 0.5,
    "orgaInf": 5
  }
];

// GREVE_USURE_JOUR_DEBUT_SERVEUR -- GREVE_USURE_JOUR_DEBUT de data.js
export const GREVE_USURE_JOUR_DEBUT_SERVEUR = 15;

// GREVE_USURE_INF_JOUR_SERVEUR -- GREVE_USURE_INF_JOUR de data.js
export const GREVE_USURE_INF_JOUR_SERVEUR = 2;

// GREVE_ACTIVITE_PLANCHER_SERVEUR -- GREVE_ACTIVITE_PLANCHER de data.js
export const GREVE_ACTIVITE_PLANCHER_SERVEUR = 0.4;

// GREVE_SOCIAL_PLANCHER_SERVEUR -- GREVE_SOCIAL_PLANCHER de data.js
export const GREVE_SOCIAL_PLANCHER_SERVEUR = -10;

// GREVE_GENERALE_NIVEAUX_SERVEUR -- GREVE_GENERALE_NIVEAUX de data.js
export const GREVE_GENERALE_NIVEAUX_SERVEUR = [
  {
    "min": 100,
    "max": 199,
    "niveau": 1,
    "gouvernementPop": 2,
    "autresElusPop": 1,
    "social": 1,
    "economieReduction": 0.1,
    "retournementJour": 11
  },
  {
    "min": 200,
    "max": 299,
    "niveau": 2,
    "gouvernementPop": 4,
    "autresElusPop": 2,
    "social": 1,
    "economieReduction": 0.2,
    "retournementJour": 9
  },
  {
    "min": 300,
    "max": 399,
    "niveau": 3,
    "gouvernementPop": 6,
    "autresElusPop": 3,
    "social": 1,
    "economieReduction": 0.3,
    "retournementJour": 7
  },
  {
    "min": 400,
    "max": 499,
    "niveau": 4,
    "gouvernementPop": 8,
    "autresElusPop": 4,
    "social": 2,
    "economieReduction": 0.4,
    "retournementJour": 6
  },
  {
    "min": 500,
    "max": Infinity,
    "niveau": 5,
    "gouvernementPop": 10,
    "autresElusPop": 5,
    "social": 2,
    "economieReduction": 0.5,
    "retournementJour": 5
  }
];

// GREVE_GENERALE_RETOURNEMENT_INF_JOUR_SERVEUR -- GREVE_GENERALE_RETOURNEMENT_INF_JOUR de data.js
export const GREVE_GENERALE_RETOURNEMENT_INF_JOUR_SERVEUR = 5;

// DELAI_DECISION_CANDIDATURE_MS_SERVEUR -- DELAI_DECISION_CANDIDATURE_MS de data.js
export const DELAI_DECISION_CANDIDATURE_MS_SERVEUR = 172800000;

// GREVE_ENTREPRISES_CIBLABLES_SERVEUR -- GREVE_ENTREPRISES_CIBLABLES de data.js
export const GREVE_ENTREPRISES_CIBLABLES_SERVEUR = {
  "usine-pharmaceutique-luthecia": {
    "city": "capitale",
    "country": "republic"
  },
  "pole-tabac-alcools-psm": {
    "city": "ville_a",
    "country": "republic"
  },
  "raffinerie-montrouge": {
    "city": "ville_b",
    "country": "republic"
  }
};

// RESSOURCES_ECONOMIE_SERVEUR -- RESSOURCES_ECONOMIE de data.js
export const RESSOURCES_ECONOMIE_SERVEUR = {
  "cereales": {
    "plafond": 150,
    "prixBase": 3,
    "prixAchatFournisseur": 1.5,
    "source": "livraison"
  },
  "poisson": {
    "plafond": 125,
    "prixBase": 4,
    "prixAchatFournisseur": 2,
    "source": "livraison"
  },
  "viande": {
    "plafond": 125,
    "prixBase": 5,
    "prixAchatFournisseur": 2.5,
    "source": "livraison"
  },
  "bois": {
    "plafond": 750,
    "prixBase": 5,
    "prixAchatFournisseur": 2.5,
    "source": "livraison"
  },
  "charbon": {
    "plafond": 400,
    "prixBase": 7,
    "prixAchatFournisseur": 3.5,
    "source": "livraison"
  },
  "petrole": {
    "plafond": 200,
    "prixBase": 8,
    "prixAchatFournisseur": 4,
    "source": "livraison"
  },
  "minerai": {
    "plafond": 500,
    "prixBase": 10,
    "prixAchatFournisseur": 5,
    "source": "livraison"
  },
  "metal": {
    "plafond": 200,
    "prixBase": 15,
    "prixAchatFournisseur": 7.5,
    "source": "livraison"
  },
  "plantes": {
    "plafond": 300,
    "prixBase": 6,
    "prixAchatFournisseur": 3,
    "source": "livraison"
  },
  "textile": {
    "plafond": 125,
    "prixBase": 5,
    "prixAchatFournisseur": 2.5,
    "source": "livraison"
  },
  "fruits_legumes": {
    "plafond": 150,
    "prixBase": 4,
    "prixAchatFournisseur": 2,
    "source": "livraison"
  },
  "produits_exotiques": {
    "plafond": 125,
    "prixBase": 6,
    "prixAchatFournisseur": 3,
    "source": "livraison"
  },
  "medicaments": {
    "plafond": 100,
    "prixBase": 22,
    "prixAchatFournisseur": 11,
    "source": "transformation"
  },
  "alcool": {
    "plafond": 100,
    "prixBase": 14,
    "prixAchatFournisseur": 7,
    "source": "transformation"
  },
  "tabac": {
    "plafond": 100,
    "prixBase": 18,
    "prixAchatFournisseur": 9,
    "source": "transformation"
  },
  "carburant": {
    "plafond": 100,
    "prixBase": 20,
    "prixAchatFournisseur": 10,
    "source": "transformation"
  },
  "desinfectant": {
    "plafond": 100,
    "prixBase": 18,
    "prixAchatFournisseur": 9,
    "source": "transformation"
  }
};

// CLUBS_SPORTIFS_SERVEUR -- CLUBS_SPORTIFS de data.js
export const CLUBS_SPORTIFS_SERVEUR = [
  {
    "id": "olympique-luthecia",
    "country": "republic",
    "city": "capitale",
    "nom": "Olympique de Luthécia"
  },
  {
    "id": "brise-mariannaise",
    "country": "republic",
    "city": "ville_a",
    "nom": "La Brise Mariannaise"
  },
  {
    "id": "cheminote-montrouge",
    "country": "republic",
    "city": "ville_b",
    "nom": "Union Cheminote de Montrouge"
  },
  {
    "id": "rojos-cartel",
    "country": "narco",
    "city": "capitale",
    "nom": "Estudiantes de la Ciudad"
  },
  {
    "id": "fronterizos-unidos",
    "country": "narco",
    "city": "ville_a",
    "nom": "Atlético Puerto Negro"
  },
  {
    "id": "jaguares-selva",
    "country": "narco",
    "city": "ville_b",
    "nom": "Independiente de Villa Sangre"
  },
  {
    "id": "dynamo-novomirsk",
    "country": "soviet",
    "city": "capitale",
    "nom": "Dynamo Novomirsk"
  },
  {
    "id": "spartak-sibirsk",
    "country": "soviet",
    "city": "ville_a",
    "nom": "Partizan de Starovka"
  },
  {
    "id": "kolkhoze-ouvrier",
    "country": "soviet",
    "city": "ville_b",
    "nom": "Étoile Rouge de Krasnov"
  },
  {
    "id": "nadi-al-madina",
    "country": "khalija",
    "city": "capitale",
    "nom": "Shabab Al Madina"
  },
  {
    "id": "al-baraka-fc",
    "country": "khalija",
    "city": "ville_a",
    "nom": "Oasis City FC"
  },
  {
    "id": "sharq-al-nour",
    "country": "khalija",
    "city": "ville_b",
    "nom": "Al-Petrol United FC"
  }
];

// PERMIS_STATUT_LEGACY_ATTENTE_SERVEUR -- PERMIS_STATUT_LEGACY_ATTENTE de plateau-immobilier.js
export const PERMIS_STATUT_LEGACY_ATTENTE_SERVEUR = "attente_validation";

// DUREE_MESURES_EXCEPTION_MS_SERVEUR -- DUREE_MESURES_EXCEPTION_MS de plateau-gouvernement.js
export const DUREE_MESURES_EXCEPTION_MS_SERVEUR = 259200000;

// COUT_HORAIRE_TRAVAIL_SERVEUR -- COUT_HORAIRE_TRAVAIL de plateau-commerce.js
export const COUT_HORAIRE_TRAVAIL_SERVEUR = 50;

// PA_PRODUCTION_ARMURERIE_SERVEUR -- PA_PRODUCTION_ARMURERIE de plateau-actions-illegales-rumeurs.js
export const PA_PRODUCTION_ARMURERIE_SERVEUR = 2;

// ENTREPOTS_EFFORT_SERVEUR -- ENTREPOTS_EFFORT de plateau-effort-guerre.js
export const ENTREPOTS_EFFORT_SERVEUR = {
  "republic": [
    {
      "building": "entrepot-logistique-luthecia",
      "city": "capitale"
    },
    {
      "building": "entrepot-logistique-psm",
      "city": "ville_a"
    },
    {
      "building": "entrepot-logistique-montrouge",
      "city": "ville_b"
    }
  ]
};

// RECETTES_MILITAIRES_SERVEUR -- RECETTES_MILITAIRES de plateau-effort-guerre.js
export const RECETTES_MILITAIRES_SERVEUR = {
  "arme_de_poing": {
    "label": "Pistolet militaire",
    "materiaux": {
      "metal": 2,
      "bois": 1
    },
    "produitParLot": 1
  },
  "mitraillette": {
    "label": "Mitraillette",
    "materiaux": {
      "metal": 2,
      "bois": 2
    },
    "produitParLot": 1
  },
  "explosif_militaire": {
    "label": "Explosifs militaires",
    "materiaux": {
      "metal": 2,
      "minerai": 3
    },
    "pa": 1,
    "produitParLot": 3
  },
  "gilet_pare_balles": {
    "label": "Gilet pare-balles",
    "materiaux": {
      "metal": 2,
      "textile": 2
    },
    "pa": 3,
    "produitParLot": 1
  },
  "radio": {
    "label": "Radio de campagne",
    "materiaux": {
      "metal": 1,
      "textile": 1,
      "minerai": 1
    },
    "pa": 3,
    "produitParLot": 1
  },
  "tente": {
    "label": "Tente de campagne",
    "materiaux": {
      "metal": 1,
      "textile": 1
    },
    "pa": 2,
    "produitParLot": 1
  },
  "jumelles": {
    "label": "Jumelles",
    "materiaux": {
      "metal": 1,
      "textile": 1,
      "minerai": 1
    },
    "pa": 2,
    "produitParLot": 1
  },
  "tenue_camouflage": {
    "label": "Tenue de camouflage",
    "materiaux": {
      "textile": 1,
      "charbon": 1,
      "fruits_legumes": 1
    },
    "pa": 2,
    "produitParLot": 1
  }
};

// CAISSES_LEGACY_SERVEUR -- CAISSES_LEGACY de data.js
export const CAISSES_LEGACY_SERVEUR = {
  "mairie": {
    "capitale": "mairie-capitale"
  }
};

// VILLES_SERVEUR -- VILLES de data.js
export const VILLES_SERVEUR = {
  "republic": {
    "capitale": {
      "nom": "Luthécia",
      "capitale": true
    },
    "ville_a": {
      "nom": "Port-Sainte-Marie",
      "capitale": false
    },
    "ville_b": {
      "nom": "Montrouge",
      "capitale": false
    }
  },
  "soviet": {
    "capitale": {
      "nom": "Novomirsk",
      "capitale": true
    },
    "ville_a": {
      "nom": "Starovka",
      "capitale": false
    },
    "ville_b": {
      "nom": "Krasnov",
      "capitale": false
    }
  },
  "narco": {
    "capitale": {
      "nom": "Ciudad Roja",
      "capitale": true
    },
    "ville_a": {
      "nom": "Puerto Negro",
      "capitale": false
    },
    "ville_b": {
      "nom": "Villa Sangre",
      "capitale": false
    }
  },
  "khalija": {
    "capitale": {
      "nom": "Al Madina",
      "capitale": true
    },
    "ville_a": {
      "nom": "Oasis City",
      "capitale": false
    },
    "ville_b": {
      "nom": "Al-Petrol",
      "capitale": false
    }
  }
};

// POSTES_NOMMES_EXCLUSIFS_SERVEUR -- POSTES_NOMMES_EXCLUSIFS de data.js
export const POSTES_NOMMES_EXCLUSIFS_SERVEUR = {
  "juge": {
    "label": "Juge",
    "nommePar": "min_just",
    "scope": "ville",
    "autoriteScope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "procureur": {
    "label": "Procureur de la Republique",
    "nommePar": "min_just",
    "scope": "pays",
    "autoriteScope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "commissaire": {
    "label": "Commissaire",
    "nommePar": "maire",
    "scope": "ville",
    "compatibles": [
      "depute"
    ]
  },
  "commandant": {
    "label": "Commandant de la Caserne",
    "nommePar": "min_def",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "pm": {
    "label": "Premier Ministre",
    "nommePar": "president",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "min_int": {
    "label": "Ministre de l'Interieur",
    "nommePar": "pm",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "min_fin": {
    "label": "Ministre des Finances",
    "nommePar": "pm",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "min_just": {
    "label": "Ministre de la Justice",
    "nommePar": "pm",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "min_def": {
    "label": "Ministre de la Defense",
    "nommePar": "pm",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "min_info": {
    "label": "Ministre de l'Information",
    "nommePar": "pm",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "min_ae": {
    "label": "Ministre des Affaires Etrangeres",
    "nommePar": "pm",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "directeur_pharma": {
    "label": "Directeur de l'Usine Pharmaceutique",
    "nommePar": "min_fin",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "directeur_tabac_alcools": {
    "label": "Directeur du Pôle Tabac & Alcools",
    "nommePar": "min_fin",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "directeur_raffinerie": {
    "label": "Directeur de la Raffinerie",
    "nommePar": "min_fin",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "directeur_entrepot": {
    "label": "Directeur de l'Entrepôt Logistique",
    "nommePar": "maire_adjoint",
    "scope": "ville",
    "compatibles": [
      "depute"
    ]
  },
  "maire_adjoint": {
    "label": "Maire Adjoint",
    "nommePar": "maire",
    "scope": "ville",
    "compatibles": [
      "depute"
    ]
  },
  "chef_douanes": {
    "label": "Chef des Douanes",
    "nommePar": "min_int",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  },
  "capitaine_port": {
    "label": "Commandant du Port",
    "nommePar": "min_fin",
    "scope": "pays",
    "compatibles": [
      "depute"
    ]
  }
};

// CREATION_ORIGINES_SERVEUR -- ORIGINS de data.js
export const CREATION_ORIGINES_SERVEUR = [
  {
    "id": "poor",
    "name": "Milieu defavorise",
    "arg": 300,
    "bonuses": {
      "VOL": 2,
      "DUP": 2
    },
    "malus": {
      "CHA": -1
    },
    "trait": "Resilience brute, rien a perdre"
  },
  {
    "id": "worker",
    "name": "Classe ouvriere",
    "arg": 600,
    "bonuses": {
      "VOL": 1,
      "PER": 1
    },
    "malus": {
      "DUP": -1
    },
    "trait": "Sens du collectif, mains calleuses, trop honnete pour bien mentir"
  },
  {
    "id": "bourgeois",
    "name": "Petite bourgeoisie",
    "arg": 1000,
    "bonuses": {
      "INT": 1,
      "CHA": 1
    },
    "malus": {
      "ENT": -1
    },
    "trait": "Vernis social, ambitions mesurees, pas encore le bon carnet d'adresses"
  },
  {
    "id": "elite",
    "name": "Haute societe",
    "arg": 2200,
    "bonuses": {
      "ENT": 2
    },
    "malus": {
      "VOL": -2
    },
    "trait": "Carnet d'adresses ancestral, mais n'a jamais connu la difficulte reelle"
  }
];

// CREATION_ECOLES_SERVEUR -- SCHOOLS de data.js
export const CREATION_ECOLES_SERVEUR = [
  {
    "id": "none",
    "name": "Pas d'ecole",
    "bonuses": {
      "DUP": 2,
      "VOL": 1
    },
    "malus": {
      "INT": -1
    },
    "argBonus": 0,
    "blocks": [
      "magistrat",
      "business",
      "doctor"
    ]
  },
  {
    "id": "basic",
    "name": "Ecole basique",
    "bonuses": {
      "PER": 1,
      "ENT": 1
    },
    "malus": {},
    "argBonus": 0,
    "blocks": [
      "magistrat",
      "business"
    ]
  },
  {
    "id": "higher",
    "name": "Etudes superieures",
    "bonuses": {
      "INT": 1,
      "CHA": 1
    },
    "malus": {},
    "argBonus": 0,
    "blocks": [
      "doctor"
    ]
  },
  {
    "id": "elite",
    "name": "Hautes ecoles",
    "bonuses": {
      "INT": 2,
      "ENT": 1
    },
    "malus": {
      "VOL": -1
    },
    "argBonus": 400,
    "blocks": []
  }
];

// CREATION_NATURES_SERVEUR -- ARCHETYPES de data.js
export const CREATION_NATURES_SERVEUR = [
  {
    "id": "politician",
    "name": "Ambitieux",
    "bonuses": {
      "CHA": 2,
      "ENT": 2
    },
    "malus": {
      "DUP": -2
    },
    "desc": "Convaincre, entreprendre, conquerir des positions. Le pouvoir et la reussite l'attirent."
  },
  {
    "id": "authoritarian",
    "name": "Autoritaire",
    "bonuses": {
      "VOL": 2,
      "PER": 2
    },
    "malus": {
      "ENT": -2
    },
    "desc": "Discipline, resistance, rapport de force. Il croit volontiers a l'ordre et a l'autorite."
  },
  {
    "id": "oligarch",
    "name": "Calculateur",
    "bonuses": {
      "INT": 2,
      "DUP": 2
    },
    "malus": {
      "CHA": -2
    },
    "desc": "Raisonnement froid, interet, anticipation, manoeuvre."
  },
  {
    "id": "informer",
    "name": "Curieux",
    "bonuses": {
      "PER": 2,
      "INT": 2
    },
    "malus": {
      "VOL": -2
    },
    "desc": "Observer, comprendre, chercher l'information."
  },
  {
    "id": "legalist",
    "name": "Legaliste",
    "bonuses": {
      "INT": 2,
      "VOL": 2
    },
    "malus": {
      "CHA": -2
    },
    "desc": "Regles, textes, procedures, rigueur -- et connaissance de leurs limites."
  },
  {
    "id": "believer",
    "name": "Idealiste",
    "bonuses": {
      "CHA": 2,
      "ENT": 2
    },
    "malus": {
      "DUP": -2
    },
    "desc": "Convictions, mobilisation, engagement."
  },
  {
    "id": "shadow",
    "name": "Manipulateur",
    "bonuses": {
      "DUP": 2,
      "PER": 2
    },
    "malus": {
      "CHA": -2
    },
    "desc": "Dissimulation, influence indirecte, infiltration, double jeu."
  },
  {
    "id": "anticapitalist",
    "name": "Solidaire",
    "bonuses": {
      "CHA": 2,
      "VOL": 2
    },
    "malus": {
      "INT": -2
    },
    "desc": "Loyaute collective, engagement, resistance, entraide."
  },
  {
    "id": "criminal",
    "name": "Transgressif",
    "bonuses": {
      "DUP": 2,
      "VOL": 2
    },
    "malus": {
      "ENT": -2
    },
    "desc": "Gout du risque, refus des regles, determination."
  }
];

// CREATION_CARRIERES_SERVEUR -- CAREERS de data.js
export const CREATION_CARRIERES_SERVEUR = [
  {
    "id": "officer",
    "name": "Armée — Officier supérieur / Mercenaire",
    "argBonus": 700,
    "statKey": "VOL",
    "comp": "Commandement, Intimidation",
    "blocks": []
  },
  {
    "id": "business",
    "name": "Affaires — Homme d'affaires / Lobbyiste",
    "argBonus": 1200,
    "statKey": "INT",
    "comp": "Lobbying, Blanchiment, Negociation",
    "blocks": [
      "none",
      "basic"
    ]
  },
  {
    "id": "magistrat",
    "name": "Justice — Magistrat / Avocat",
    "argBonus": 800,
    "statKey": "INT",
    "comp": "Droit, Procedure judiciaire, Negociation",
    "blocks": [
      "none",
      "basic"
    ]
  },
  {
    "id": "press",
    "name": "Médias & Communication — Grand journaliste / Influenceur",
    "argBonus": 450,
    "statKey": "PER",
    "comp": "Kompromat, Propagande, Reseaux sociaux",
    "blocks": []
  },
  {
    "id": "clergy",
    "name": "Religion — Chef de culte",
    "argBonus": 150,
    "statKey": "CHA",
    "comp": "Rhetorique, Mobilisation",
    "blocks": []
  },
  {
    "id": "doctor",
    "name": "Professions intellectuelles — Médecin / Universitaire",
    "argBonus": 550,
    "statKey": "INT",
    "comp": "Reseau civil, Discretion, Rhetorique",
    "blocks": [
      "none",
      "basic",
      "higher"
    ]
  },
  {
    "id": "worker",
    "name": "Monde ouvrier — Ouvrier / Syndicaliste",
    "argBonus": 300,
    "statKey": "VOL",
    "comp": "Force, Solidarite, Mobilisation",
    "blocks": []
  },
  {
    "id": "intel",
    "name": "Renseignement — Agent des services",
    "argBonus": 500,
    "statKey": "PER",
    "comp": "Surveillance, Infiltration",
    "blocks": []
  },
  {
    "id": "criminal_c",
    "name": "Crime organisé — Criminel organisé",
    "argBonus": 900,
    "statKey": "DUP",
    "comp": "Milices, Blanchiment",
    "blocks": []
  },
  {
    "id": "escort",
    "name": "Prostitution — Prostitué(e)",
    "argBonus": 450,
    "statKey": "CHA",
    "comp": "Seduction, Kompromat",
    "blocks": []
  }
];
