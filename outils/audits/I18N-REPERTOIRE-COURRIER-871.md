# Issue #871 — répertoire des joueurs et retours du courrier

Lot indépendant de Sovarka métier et de l’Aide HRP. Aucun envoi, destinataire,
contenu de joueur, coût ou appel serveur n’est changé.

## Textes raccordés

Huit clés nouvelles, neuf langues : **72 entrées dont 64 traductions étrangères**.
Titre du répertoire, état vide, nombre de joueurs, domicile, information existante
sur l’interception du courrier et trois messages locaux (personnage absent,
champs manquants, confirmation de la voie d’envoi de repli).

« Chargement... » réutilise `inventoryUi.loading`, déjà traduit : aucune copie et
aucune nouvelle traduction revendiquée. Les placeholders/champs de composition et
titres de notification déjà traduits sont conservés.

`texteRepertoireHtml` marque le français et les variables sous `{{values.*}}` ;
`RPI18nPlateau.apply` reste le seul moteur de traduction. Il capture d’abord le
français, avant le premier affichage étranger, ce qui assure le repli français.
Les noms, empires, villes, postes et valeurs dynamiques ne sont pas traduits.

Les trois notifications continuent à recevoir leurs arguments français d’origine
dans `showToast`. Un appel de présentation suivant marque uniquement ce texte s’il
est toujours affiché. Le prochain `textContent` d’une autre notification supprime
naturellement le marqueur : aucune alerte ancienne ne peut revenir par une bascule.
Le journal et tous les arguments d’envoi restent canoniques et inchangés.

Les marqueurs disparaissent également lorsqu’une autre fenêtre remplace le
répertoire. La direction arabe s’applique seulement au contenu du répertoire.
Deux propriétés CSS locales permettent aux noms/postes longs de revenir à la ligne
à 320 px ; pas de refonte des fenêtres.

## Preuves

- Français exact des huit ressources et comparaison du rendu à main `1163bad`.
- Neuf langues, variables et nom Sovarka conservés.
- Corps métier de l’envoi strictement identique après retrait des trois lignes de
  présentation ; réception, destinataires, fermeture et tracts inchangés.
- Chromium : chargement, liste, vide, deux refus et confirmation dans neuf langues
  à 320/390/1280, soit **162 combinaisons état/langue/format** ; arabe RTL,
  noms longs, brouillon, mêmes nœuds/boutons, pas de débordement.
- Aucun nouvel appel de liste/envoi/réseau, ni variation de PA/argent à la bascule.
  Un envoi explicite est simulé pour prouver les arguments originaux ; aucun
  courrier réel, compte de joueur ou appel Supabase effectué.
- Repli d’une traduction absente et non-retour d’un ancien titre/toast testés.

## Mesure

La comparaison utilise le même extracteur sur main et sur le lot. Les marqueurs des
notifications sont reconnus seulement pour un appel `showToast` suivi immédiatement
du marquage du **même argument** et de sa source française attendue. Les expressions
dynamiques seules ne sont plus comptées comme texte français : correction de
mesure distincte des traductions, appliquée aux deux côtés de la comparaison.

Les ressources disponibles, les textes uniques entièrement raccordés et les
occurrences d’une fenêtre restent des mesures différentes. Un texte générique
traduit ici peut rester français ailleurs et ne compte alors pas comme texte
globalement couvert. Relevé chiffré ajouté après rebasage et audit.

Relecture native, visite avec personnage authentifié et appareil physique non
effectués. Les autres messages serveur ou de messagerie restent hors de ce lot.
