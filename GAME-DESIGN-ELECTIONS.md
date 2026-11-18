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

## Nationalité, domicile et élections (décisions de Fred, 18/11/2026, nuit)

Constat du 18/11 : la colonne « pays » d'un personnage changeait quand il voyageait, et son domicile aussi.
Un républicain domicilié à Luthécia est apparu « Sovarka · Domicile : Novomirsk » sans l'avoir demandé, et
sa candidature à la présidentielle de Républia a disparu pendant son séjour en Sovarka. Les villes partagent
leurs clés (ville_a = Montrouge et Starovka…) : un étranger pouvait être inscrit dans un scrutin de son
propre pays depuis une mairie étrangère.

**Règles, pour tous les pays :**
- **Deux données distinctes et stables** : la **nationalité** (un pays) et le **domicile** (une ville, dans
  n'importe quel pays). Voyager, se déplacer ou agir ne change **ni l'une ni l'autre**.
- **Naturalisation** (seul moyen de changer de nationalité) : ordre à l'accueil de **n'importe quelle mairie du
  pays visé**, quel que soit le domicile ; **2 PA et 50** dans la monnaie de ce pays (FR / PSK). La demande va
  au **ministre de l'Intérieur** de ce pays (Sécurité du Peuple en Sovarka), qui accepte ou refuse. Ministre
  PNJ ou poste vacant : **acceptée d'office au bout de 7 jours** ; si un PJ est nommé entre-temps, il reprend
  la main. Après un refus, on peut redemander aussitôt. Une fois naturalisé, le personnage **perd tout poste,
  tout mandat et son appartenance à un parti** dans l'ancien pays.
- **Domiciliation** (seul moyen de changer de domicile) : **1 PA et 50** dans la monnaie du pays de la ville,
  automatique (remplace le tarif de 200).
- **Vote** : présidentielle selon la **nationalité** ; municipales selon le **domicile** (un Sovarkien domicilié
  à Port-Sainte-Marie vote aux municipales de Port-Sainte-Marie et à la présidentielle de Sovarka, pas à
  celle de Républia).
- **Candidature à une mairie** : **nationalité du pays ET domicile dans cette ville**. Un étranger domicilié
  vote mais ne peut pas se présenter.
- **Une candidature ne disparaît jamais** parce que le candidat voyage.
- **Personnages existants** : nationalité = pays de création.
- **Partage des usages du « pays »** : par défaut, les **prix, les tarifs nationaux et la monnaie suivent le
  lieu** où l'on se trouve ; les **droits politiques, les postes et la conscription suivent la nationalité**.
  Un cas non tranché par ces règles est soumis à Fred.
- **Précisions de Fred (18/11/2026)** :
  - **Poste à l'étranger** : le PJ **garde** son poste quand il est à l'étranger mais **ne peut pas l'exercer** tant qu'il y est (refus « hors de son pays », déjà codé) ; aucune perte du poste, ni immédiate ni après une durée d'absence.
  - **Forums et journal** : le PJ garde toujours les forums et le journal de **son pays** (nationalité), où qu'il soit. En plus, il voit ceux du **pays où il se trouve** : forum national de ce pays en **lecture seule** ; forums locaux de la **ville où il se trouve** en **lecture et écriture** ; journal du pays où il se trouve **lisible**.
  - **Vote depuis l'étranger : non.** Il faut être dans son pays pour voter.

### Compléments de Fred (18/11/2026, « Décisions du 18/11 »)
- Investiture gratuite : confirmée. Programme par défaut de l'investi : « X est investi par le parti Y, qui viendra détailler son programme personnellement. »
- Naturalisation : un ministre joueur a 48 h pour répondre ; sans réponse, la demande est acceptée 7 jours après son dépôt (comme sans ministre).
- À l'étranger, lecture du forum Local de sa ville de domicile : confirmée.

## Départ d'un maire (Fred, 18/11/2026 ; tous motifs, tous les empires)
- Motifs : décès, démission, destitution, emprisonnement, naturalisation, etc. Pas d'élection partielle.
- L'adjoint reçoit une proposition de devenir maire, valable 72 h. S'il accepte, il devient maire jusqu'à la fin du mandat en cours et nomme un nouvel adjoint. S'il refuse ou ne répond pas, il reste adjoint ; la mairie reste sans maire jusqu'à la prochaine municipale (l'adjoint assure les fonctions déjà prévues).
- Sans adjoint : la mairie passe sous tutelle du ministre — Économie collective (`min_fin`) en Sovarka ; Intérieur (`min_int`) en Républia (équivalent retenu par Claude). Le ministre a les boutons du bureau du maire, pas ceux de l'adjoint. La tutelle cesse à l'élection d'un maire. Codé : au serveur, le ministre présent dans le bureau du maire est reconnu comme maire de la ville (acteur_poste_courant) pour les impôts locaux, le budget et les subventions ; la campagne de sécurité et les nominations relisent encore le poste de la fiche et restent réservées au maire élu (à reprendre).
- Détail complet : [`GAME-DESIGN-NOVOMIRSK.md`](GAME-DESIGN-NOVOMIRSK.md), « Décisions du 18/11/2026 ».

## Candidature (rappel des règles en vigueur)

- Une candidature n'existe que par la publication de son programme (16/09/2026) ; elle coûte
  2 PA. Depuis le 02/11, la publication inscrit le candidat sur le bulletin du scrutin.
