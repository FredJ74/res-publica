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

## Candidature (rappel des règles en vigueur)

- Une candidature n'existe que par la publication de son programme (16/09/2026) ; elle coûte
  2 PA. Depuis le 02/11, la publication inscrit le candidat sur le bulletin du scrutin.
