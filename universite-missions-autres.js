// Catalogue préparatoire des stages non médicaux. Aucune validation client ne confère une carrière.
// Les lieux sont des catégories de bâtiment à raccorder aux identifiants serveur réels.
(function(root){'use strict';
const parcours=Object.freeze([
  {
    "carriere": "business",
    "titre": "Économie et affaires",
    "missions": [
      {
        "id": "business_s02",
        "semaine": 2,
        "ville": "luthecia",
        "lieu": "commerce",
        "titre": "Observer les besoins des clients",
        "objectif": "Observer les besoins des clients",
        "action": "Observer les besoins des clients",
        "consigne": "Votre maître de stage vous demande de : observer les besoins des clients.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "business_s03",
        "semaine": 3,
        "ville": "luthecia",
        "lieu": "commerce",
        "titre": "Dresser un inventaire",
        "objectif": "Dresser un inventaire",
        "action": "Dresser un inventaire",
        "consigne": "Votre maître de stage vous demande de : dresser un inventaire.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "business_s04",
        "semaine": 4,
        "ville": "luthecia",
        "lieu": "commerce",
        "titre": "Comparer recettes et dépenses",
        "objectif": "Comparer recettes et dépenses",
        "action": "Comparer recettes et dépenses",
        "consigne": "Votre maître de stage vous demande de : comparer recettes et dépenses.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "business_s05",
        "semaine": 5,
        "ville": "port-sainte-marie",
        "lieu": "port",
        "titre": "Rencontrer un acteur économique du port",
        "objectif": "Rencontrer un acteur économique du port",
        "action": "Rencontrer un acteur économique du port",
        "consigne": "Votre maître de stage vous demande de : rencontrer un acteur économique du port.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "business_s06",
        "semaine": 6,
        "ville": "port-sainte-marie",
        "lieu": "port",
        "titre": "Établir un budget d'approvisionnement",
        "objectif": "Établir un budget d'approvisionnement",
        "action": "Établir un budget d'approvisionnement",
        "consigne": "Votre maître de stage vous demande de : établir un budget d'approvisionnement.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "business_s07",
        "semaine": 7,
        "ville": "port-sainte-marie",
        "lieu": "port",
        "titre": "Résoudre une rupture de stock",
        "objectif": "Résoudre une rupture de stock",
        "action": "Résoudre une rupture de stock",
        "consigne": "Votre maître de stage vous demande de : résoudre une rupture de stock.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "business_s08",
        "semaine": 8,
        "ville": "port-sainte-marie",
        "lieu": "port",
        "titre": "Présenter un bilan d'activité",
        "objectif": "Présenter un bilan d'activité",
        "action": "Présenter un bilan d'activité",
        "consigne": "Votre maître de stage vous demande de : présenter un bilan d'activité.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      }
    ]
  },
  {
    "carriere": "magistrat",
    "titre": "Droit et justice",
    "missions": [
      {
        "id": "magistrat_s02",
        "semaine": 2,
        "ville": "luthecia",
        "lieu": "tribunal",
        "titre": "Accueillir un justiciable",
        "objectif": "Accueillir un justiciable",
        "action": "Accueillir un justiciable",
        "consigne": "Votre maître de stage vous demande de : accueillir un justiciable.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "magistrat_s03",
        "semaine": 3,
        "ville": "luthecia",
        "lieu": "tribunal",
        "titre": "Classer les pièces d'un dossier fictif",
        "objectif": "Classer les pièces d'un dossier fictif",
        "action": "Classer les pièces d'un dossier fictif",
        "consigne": "Votre maître de stage vous demande de : classer les pièces d'un dossier fictif.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "magistrat_s04",
        "semaine": 4,
        "ville": "luthecia",
        "lieu": "tribunal",
        "titre": "Reconstituer une chronologie",
        "objectif": "Reconstituer une chronologie",
        "action": "Reconstituer une chronologie",
        "consigne": "Votre maître de stage vous demande de : reconstituer une chronologie.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "magistrat_s05",
        "semaine": 5,
        "ville": "port-sainte-marie",
        "lieu": "tribunal",
        "titre": "Recevoir une demande",
        "objectif": "Recevoir une demande",
        "action": "Recevoir une demande",
        "consigne": "Votre maître de stage vous demande de : recevoir une demande.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "magistrat_s06",
        "semaine": 6,
        "ville": "port-sainte-marie",
        "lieu": "tribunal",
        "titre": "Vérifier les pièces d'un dossier",
        "objectif": "Vérifier les pièces d'un dossier",
        "action": "Vérifier les pièces d'un dossier",
        "consigne": "Votre maître de stage vous demande de : vérifier les pièces d'un dossier.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "magistrat_s07",
        "semaine": 7,
        "ville": "port-sainte-marie",
        "lieu": "tribunal",
        "titre": "Rédiger une note de synthèse",
        "objectif": "Rédiger une note de synthèse",
        "action": "Rédiger une note de synthèse",
        "consigne": "Votre maître de stage vous demande de : rédiger une note de synthèse.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "magistrat_s08",
        "semaine": 8,
        "ville": "port-sainte-marie",
        "lieu": "tribunal",
        "titre": "Transmettre le dossier au greffe",
        "objectif": "Transmettre le dossier au greffe",
        "action": "Transmettre le dossier au greffe",
        "consigne": "Votre maître de stage vous demande de : transmettre le dossier au greffe.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      }
    ]
  },
  {
    "carriere": "officer",
    "titre": "Formation militaire",
    "missions": [
      {
        "id": "officer_s02",
        "semaine": 2,
        "ville": "luthecia",
        "lieu": "caserne",
        "titre": "Identifier le matériel de la section",
        "objectif": "Identifier le matériel de la section",
        "action": "Identifier le matériel de la section",
        "consigne": "Votre maître de stage vous demande de : identifier le matériel de la section.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "officer_s03",
        "semaine": 3,
        "ville": "luthecia",
        "lieu": "caserne",
        "titre": "Préparer une dotation logistique",
        "objectif": "Préparer une dotation logistique",
        "action": "Préparer une dotation logistique",
        "consigne": "Votre maître de stage vous demande de : préparer une dotation logistique.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "officer_s04",
        "semaine": 4,
        "ville": "luthecia",
        "lieu": "caserne",
        "titre": "Transmettre un ordre d'exercice",
        "objectif": "Transmettre un ordre d'exercice",
        "action": "Transmettre un ordre d'exercice",
        "consigne": "Votre maître de stage vous demande de : transmettre un ordre d'exercice.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "officer_s05",
        "semaine": 5,
        "ville": "port-sainte-marie",
        "lieu": "caserne",
        "titre": "Rencontrer le chef de section",
        "objectif": "Rencontrer le chef de section",
        "action": "Rencontrer le chef de section",
        "consigne": "Votre maître de stage vous demande de : rencontrer le chef de section.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "officer_s06",
        "semaine": 6,
        "ville": "port-sainte-marie",
        "lieu": "caserne",
        "titre": "Contrôler le ravitaillement",
        "objectif": "Contrôler le ravitaillement",
        "action": "Contrôler le ravitaillement",
        "consigne": "Votre maître de stage vous demande de : contrôler le ravitaillement.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "officer_s07",
        "semaine": 7,
        "ville": "port-sainte-marie",
        "lieu": "caserne",
        "titre": "Préparer un compte rendu de manœuvre",
        "objectif": "Préparer un compte rendu de manœuvre",
        "action": "Préparer un compte rendu de manœuvre",
        "consigne": "Votre maître de stage vous demande de : préparer un compte rendu de manœuvre.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      },
      {
        "id": "officer_s08",
        "semaine": 8,
        "ville": "port-sainte-marie",
        "lieu": "caserne",
        "titre": "Remettre le rapport de fin de stage",
        "objectif": "Remettre le rapport de fin de stage",
        "action": "Remettre le rapport de fin de stage",
        "consigne": "Votre maître de stage vous demande de : remettre le rapport de fin de stage.",
        "reaction": "Votre maître de stage prend connaissance du travail et confirme que l'objectif est rempli."
      }
    ]
  }
]);
function missionPourSemaine(carriere,semaine){const p=parcours.find(x=>x.carriere===carriere);return p?p.missions.find(m=>m.semaine===semaine)||null:null;}
function objectifAtteint(carriere,missionId,action){const p=parcours.find(x=>x.carriere===carriere);return !!p&&p.missions.some(m=>m.id===missionId&&m.action===action);}
const catalogue=Object.freeze({parcours,missionPourSemaine,objectifAtteint});
if(typeof module!=='undefined'&&module.exports)module.exports=catalogue;else root.UNIVERSITE_MISSIONS_AUTRES=catalogue;
})(typeof globalThis!=='undefined'?globalThis:this);
