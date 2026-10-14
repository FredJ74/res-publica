// Catalogue declaratif des missions medicales de seconde carriere.
// Aucun acces aux PA, a la base ni aux dialogues IA ici : le serveur valide
// la progression, les interfaces affichent ces textes. Ne pas confondre avec
// l'ancien systeme de formation supprime.
(function (root) {
  'use strict';
  const missions = Object.freeze([
    { id: 'med_s02_ecouter', semaine: 2, ville: 'luthecia', lieu: 'ehpad',
      titre: 'Premiere rencontre', objectif: 'Rencontrer un pensionnaire et recueillir son motif de consultation.',
      action: 'Recueillir le motif de consultation',
      consigne: 'Prenez le temps de rencontrer notre pensionnaire. Demandez-lui ce qui le preoccupe, puis consignez son motif de consultation.',
      reaction: 'Merci de m’avoir ecoute. On se sent deja mieux quand quelqu’un prend le temps.' },
    { id: 'med_s03_observer', semaine: 3, ville: 'luthecia', lieu: 'ehpad',
      titre: 'Observer les symptomes', objectif: 'Echanger avec un pensionnaire sur ses symptomes.',
      action: 'Noter les symptomes',
      consigne: 'Votre patient vous attend. Ecoutez son recit et relevez ses symptomes sans poser de diagnostic premature.',
      reaction: 'Vous avez bien compris ce qui me gene. Je vous remercie.' },
    { id: 'med_s04_suivre', semaine: 4, ville: 'luthecia', lieu: 'ehpad',
      titre: 'Assurer le suivi', objectif: 'Revoir le pensionnaire et enregistrer son suivi.',
      action: 'Consigner le suivi',
      consigne: 'Retournez voir le pensionnaire. La continuite des soins compte autant que la premiere visite.',
      reaction: 'Ah, vous etes revenu ! C’est rassurant de ne pas devoir tout raconter depuis le debut.' },
    { id: 'med_s05_accueillir', semaine: 5, ville: 'port-sainte-marie', lieu: 'dispensaire',
      titre: 'Accueillir un patient', objectif: 'Accueillir un patient et recueillir le motif de consultation.',
      action: 'Recueillir le motif de consultation',
      consigne: 'Notre dispensaire recoit des habitants du port. Accueillez ce patient et relevez la raison de sa visite.',
      reaction: 'Je suis pecheur. Depuis quelques jours, mon epaule me fait mal quand je remonte les filets.' },
    { id: 'med_s06_evaluer', semaine: 6, ville: 'port-sainte-marie', lieu: 'dispensaire',
      titre: 'Premiere evaluation', objectif: 'Interroger le patient puis consigner une premiere evaluation.',
      action: 'Consigner l’evaluation',
      consigne: 'Posez quelques questions utiles au patient et notez les elements importants pour le medecin responsable.',
      reaction: 'D’accord, je vais vous expliquer depuis quand cela a commence.' },
    { id: 'med_s07_accompagner', semaine: 7, ville: 'port-sainte-marie', lieu: 'dispensaire',
      titre: 'Accompagner la prise en charge', objectif: 'Expliquer au patient la suite de son parcours.',
      action: 'Expliquer la prise en charge',
      consigne: 'Le patient a besoin de comprendre les prochaines etapes. Expliquez-lui calmement son parcours.',
      reaction: 'Merci, je sais maintenant ce qui va se passer.' },
    { id: 'med_s08_prioriser', semaine: 8, ville: 'port-sainte-marie', lieu: 'dispensaire',
      titre: 'Situation imprevue', objectif: 'Recevoir un nouveau patient et transmettre ses informations au maitre de stage.',
      action: 'Transmettre le dossier',
      consigne: 'Une consultation imprevue arrive. Accueillez la personne, recueillez son motif et transmettez son dossier.',
      reaction: 'Merci de m’avoir pris en charge si rapidement.' }
  ]);
  function consigneMaitreDeStage(semaine) {
    const mission = missionPourSemaine(semaine);
    if (!mission) return null;
    return { titre: mission.titre, texte: mission.consigne, objectif: mission.objectif, action: mission.action };
  }
  function reactionPatient(missionId, action) {
    const mission = missions.find(m => m.id === missionId);
    if (!mission || mission.action !== action) return null;
    return mission.reaction;
  }
  function missionPourSemaine(semaine) {
    return missions.find(m => m.semaine === semaine) || null;
  }
  function objectifAtteint(missionId, action) {
    const mission = missions.find(m => m.id === missionId);
    return !!mission && mission.action === action;
  }
  const catalogue = Object.freeze({ missions, missionPourSemaine, objectifAtteint, consigneMaitreDeStage, reactionPatient });
  if (typeof module !== 'undefined' && module.exports) module.exports = catalogue;
  else root.UNIVERSITE_MISSIONS_MEDECIN = catalogue;
})(typeof globalThis !== 'undefined' ? globalThis : this);
