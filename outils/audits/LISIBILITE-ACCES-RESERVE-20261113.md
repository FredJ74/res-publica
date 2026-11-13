# Lisibilité des fenêtres d’accès réservé — 13 novembre 2026

## Audit et périmètre

Référence initiale : `main` au commit `616122e`. `plateau-acces-reserve.js`
centralise six vues dans `accesModal` : refus d’entrée, garde, information du
Pavillon, réservation, location et mini-bar de la Résidence. Les refus ont trois
variantes : dignitaires, location requise, groupe comportant trop d’invités.

Deux bâtiments utilisent actuellement ce module :

- **Résidence impériale de Novomirsk**, hall et accès aux quatre appartements
  et au grand appartement impérial ; réservation, location et mini-bar.
- **Pavillon des Ambassadeurs de Novomirsk**, hall d’information et refus d’accès
  au bar, à la salle de réception et aux trois suites.

Aucun autre bâtiment ne raccorde ces fonctions. Le conteneur `#modal-postes`,
`vehModal` et `sovModal` servent à de nombreux autres modules : ils ne sont pas
modifiés. Les autres écrans du Pavillon, les fenêtres du Palais des Ambassades,
les véhicules, PNJ et institutions ne sont pas redimensionnés par ce lot.
Les raccordements sont vérifiés dans `plateau-navigation.js`, `plateau-router.js`,
`data.js` et le référentiel historique `acces_piece_reservee_interne` ; aucune
requête ni modification Supabase n’est nécessaire.

Cause : le titre commun fait 1rem ; une ancienne règle de `style.css` force les
paragraphes et boutons de `#modal-postes` à `max(.82rem,12px) !important` et un
interligne de 1,4. Elle écrase même les tailles héritées du dialogue.

## Correction

Un seul marqueur de présentation, `.acces-reserve-dialogue`, enveloppe le contenu
émis par `accesModal`, dans les deux voies existantes (`sovModal` et repli `vehModal`).
Les règles sont limitées à ce marqueur ; `:has()` adapte son conteneur et son titre
sans laisser de classe persistante lors de la réutilisation de la fenêtre.

- Titre : 1,9rem, police existante conservée.
- Paragraphes et notes : 1,12rem, interligne 1,6, espacement vertical 1rem.
- Boutons : 1rem, hauteur minimale 44px, retour à la ligne autorisé.
- Largeur maximale 720px ; marges, hauteur visible et défilement adaptés au mobile.
- Couleurs, fonds bleu-gris, bordures dorées et typographies conservés.

Les seules surcharges `!important` compensent la règle historique sur les
paragraphes et boutons ; aucune modification globale de cette règle. Les versions
CSS et JavaScript sont actualisées dans `plateau.html`.

## Vérification et limites

Banc existant `banc-acces-reserve-20261112.cjs`, plus
`banc-lisibilite-acces-reserve-20261113.cjs` sous Chromium : comparaison exacte du
module après retrait du seul adaptateur visuel, et comparaison des fichiers métier
avec le point de branchement ; aucun changement des traductions, conditions, RPC,
coûts, locations, combats ou sanctions.

Huit variantes d’écran, neuf langues existantes (sans traduction nouvelle),
320×640, 390×780, 1280×900 et 390×360 : **288 rendus**. Les textes et arguments
des boutons sont comparés à main ; tailles calculées, couleurs/polices, défilement,
fermeture au clavier, activation du bouton et absence de débordement vérifiés.
Une fenêtre voisine réutilisant le conteneur retrouve exactement ses dimensions et
sa typographie initiales. La voie sans `sovModal` est également vérifiée.
Les appels sont simulés : aucun joueur ni paiement réel, aucun combat réel.

Résultat local : deux tests du nouveau banc verts, banc historique d’accès réservé
vert, six tests du Palais des Ambassades verts et banc des six illustrations WebP
de la Résidence vert. Mesures calculées : titre 16 → 30,4px, paragraphes/notes
13,12 → 17,92px, boutons 13,12 → 16px. Voir le JSON `-mesures.json` associé.
Tous les boutons sont activés au clavier avec les mêmes destinataires et arguments
que main et une seule invocation par activation, sans débit sur la fixture.

Comparaison des contrôles transversaux : les 14 tests SSM reproduisent les mêmes
11 succès et 3 échecs sur `616122e` et la branche. Le run main initial
`43465910660` échoue déjà sur quatre tests du calendrier global (312/316 verts :
raccordements profils/routes, géométrie des vitrines, personnalités des musées de
province, contrat RPC). Ces chantiers étrangers ne sont pas modifiés.

Captures avant/après et mesures produites par `ACCESS_SCREENSHOTS`, conservées comme
artefact de CI. Recette avec compte authentifié et téléphone physique non réalisée.
CI, fusion et déploiement : statut vivant dans la PR et `RELAIS.md`.

## Livraison vérifiée

- **PR #880 fusionnée**, commit `7df7525ea0d19264bda3b054759384831123c4be`
  (code `813f095`, preuves `b3d3e50`).
- CI PR : **37 contrôles verts**, seul contrôle SSM rouge avec les trois échecs
  préexistants. Un premier démarrage Chromium du banc transversal a expiré avant
  les assertions d’interface ; relance inchangée du run `43469269085` : verte.
  Les neuf essais Chromium complémentaires infobulles/modalités passent en local
  après installation des dépendances verrouillées, sans modification de code.
- Vercel production **READY**, `dpl_t9Xaxv4Zdzik3iMUTpHfJd5GuoAC`, sur le commit
  de fusion ; alias `res-publica.vercel.app` confirmé.
- **Cinq fichiers publics identiques octet pour octet** au commit fusionné :
  `plateau.html`, `style.css`, `plateau-acces-reserve.js`, `plateau-vehicules.js`,
  `plateau-sovarka-droits.js`. Empreintes dans le JSON `-production.json` associé.
- Nouveau banc rejoué avec ces fichiers publics et la référence initiale `616122e` :
  **deux tests verts**, dont les **288 rendus**. Les essais restent isolés, sans
  compte joueur, accès réel, dépense, combat ni écriture serveur.
- CI du commit fusionné terminée : vérifications dédiées vertes ; le banc global
  conserve les quatre échecs initiaux, **320/324 verts** (avant : 312/316). Runs comparés :
  `43465910660` (avant) et `43470328981` (après), mêmes intitulés d’échec.

### Fichiers modifiés

`style.css`, `plateau-acces-reserve.js`, `plateau.html`,
`outils/bancs/banc-lisibilite-acces-reserve-20261113.cjs`,
`.github/workflows/lisibilite-acces-reserve.yml`, `RELAIS.md`, et les trois preuves
`outils/audits/LISIBILITE-ACCES-RESERVE-20261113.md`,
`outils/audits/LISIBILITE-ACCES-RESERVE-20261113-mesures.json`,
`outils/audits/LISIBILITE-ACCES-RESERVE-20261113-production.json`.

Aucune traduction, donnée PNJ/PJ, règle ou fonction Supabase modifiée.
**Non réalisés :** session authentifiée et téléphone physique. Les captures et
les mesures sont celles des fixtures Chromium utilisant les scripts et styles du
jeu ; elles ne constituent pas une navigation réelle d’un joueur connecté.
