# Énigme n° 1 de Luthécia — « Le Portrait Disparu » (musée de la Ville)

Code : `plateau-enigme-portrait.js` (écran), RPC `enigme_objet_recevoir` (déclenchement, coffre),
`jodie_enquete_contact` (appels de Jodie Moitout), `enigme1_musee` (musée, depuis le 13/11/2026).

## Déclenchement (règle en production, migration `20261109230000_jodie_declenchement_j1`)

- À chaque chargement, l'écran demande au serveur ; l'enquête s'ouvre **24 h après la création du
  personnage**, **une fois la quête d'accueil terminée** (carrière terminée, terminée sans aide,
  refusée, présentation en cours ou publiée), une seule fois par personnage.
- Le serveur tire une variante de rumeur (maire, criminel, entrepreneur, plume) et dépose le calepin.
- Relance dans le journal à **J+6 après la création** si l'enquête n'a pas avancé (le commentaire du
  code « 3 jours après le déclenchement » est inexact).
- Jodie Moitout appelle pour envoyer le joueur au musée ; rappel 3 jours après son premier appel.
- **La visite du musée ne déclenche rien** : elle montre les cadres vides si l'enquête est ouverte.

## Départ lisible au musée (décisions de Fred, 13/11/2026, 0 h 42-0 h 48)

Constat : une fois l'enquête ouverte, la visite restait équivoque (hall muet, seule l'image des
salles changeait, zone cliquable invisible et sans signal sur téléphone, rien dans le calepin).

1. **Quelqu'un met sur la voie, mais pas le coupable.** Le coupable démasqué au débarras est le
   gardien **Gérard Poinçon** : il ne dit rien. C'est **Valérie Loisillon**, l'hôtesse d'accueil.
2. **Hall, spontanément.** Pendant l'enquête, à la première entrée dans le hall, Valérie s'adresse
   au joueur **une seule fois** : elle **s'excuse que la visite soit amputée des tableaux
   disparus** et signale des cadres vides dans plusieurs salles.
3. **Salles des Maires, des Criminels, des Entrepreneurs, des Plumes.** Pendant l'enquête, la
   description de la salle signale un cadre vide, et un **ordre gratuit « Examiner le cadre vide »**
   ouvre la plaque et l'indice. La zone cliquable sur l'image reste (même effet).
4. **Calepin.** Examiner un cadre ajoute « Musée : portrait manquant de [nom] ([dates]) », une ligne
   par salle (jusqu'à 4), **au-dessus** des sept cases existantes.

Implémentation : RPC `enigme1_musee(p_action, p_salle)` (migration `20261112234900`) — `accueil`
(drapeau `accueilValerie`), `examiner` (liste `cadresVus`), `debarras` (résolution : lieu, clé
`cle-debarras-musee` et étape jugés au serveur ; l'écran n'écrit plus `etape = 'resolue'`).

## Reste ouvert (non bloquant)

- Les cases du calepin (mairie, commissariat, notaire, presse, EHPAD) sont encore cochées par
  l'écran (sauvegarde de fiche), pas par le serveur.
- Textes de l'énigme en français uniquement (comme le reste de l'énigme de Luthécia).
