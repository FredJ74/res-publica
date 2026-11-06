# Game design — élections

Décisions de Fred sur la chaîne élective (président, maire, député, chef syndical).
Audit de référence : `outils/audits/AUDIT-CHAINE-ELECTIVE-20261102.md`.

## Fraudes électorales et second tour (décision de Fred, 02/11/2026)

- Une fraude (falsification des listes, bourrage d'urnes, trucage du dépouillement) **ne vaut
  que pour le tour où elle a été commise**. Le second tour repart propre : les voix truquées
  au premier tour ne sont pas reportées sur le candidat qualifié.
- Le plafond de fraudes par type (détectabilité croissante) se compte aussi par tour.
- La contestation d'un tour ne recompte et ne révèle que les fraudes de ce tour.

Mise en œuvre : `cycle.debutTour` posé par la passe de nuit au passage au second tour ;
photographie du scrutin proclamé bornée par `debutTour` / `finTour` ; migration
`20261102222500_chaine_elective_bulletin_fraudes_mairie` (appliquée le 02/11).

## Contestation : le recompte s'impose (décision de Fred, 02/11/2026)

- Quand une contestation révèle une fraude, le résultat recompté **remplace** celui qui avait été
  proclamé, quel que soit l'avancement du scrutin, exactement comme si la passe de minuit l'avait
  proclamé :
  - majorité absolue au recompte → le candidat est élu aussitôt (prise de fonctions à l'instant
    de la proclamation contestée) ; un second tour déjà ouvert est **annulé** ;
  - qualifiés différents au recompte du premier tour → le second tour est **relancé** avec les bons
    qualifiés, à la même date de vote (personne n'a encore voté : la contestation dure 24 h après le
    résultat du lundi, le second tour se vote le dimanche suivant) ;
  - plus aucun verdict → le titulaire en fonction le reste, prolongation de 2 semaines.
- Si l'élection proclamée tombe, le poste revient au titulaire d'avant la proclamation, avec son
  début de mandat (pour un maire, l'archive du mandat clos par erreur est retirée).
- Tout résultat changé par contestation est **annoncé publiquement** ; s'il désigne un élu, il est
  inscrit à la chronique.

Mise en œuvre : `election_contestation_appliquer` (migration
`20261103001000_chaine_elective_contestation_portes`), photographie du scrutin enrichie par
`api/cron-minuit.js` (`titulaireAvant`, `elusAvant`, `debutMandatAvant`, noms affichés).

## Candidature (rappel des règles en vigueur)

- Une candidature n'existe que par la publication de son programme (16/09/2026) ; elle coûte
  2 PA. Depuis le 02/11, la publication inscrit le candidat sur le bulletin du scrutin.
