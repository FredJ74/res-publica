# Produits et échanges économiques — 10 novembre 2026

## Reprise et coordination

Main initial et final vérifié : **7aafbb9f**, après intégration Inventaire #688,
Connexion #689, cartes #685 et réparations commerce #690. Ces lots ne sont pas
recréés. Lecture AGENTS, RELAIS, Constitution/architecture et ressources existantes.
L’API GitHub GET/POST est refusée (403). La lecture **web publique** fonctionne :
cinq PR ouvertes observées (#692, #636, #562, #467, #463), sans lot équivalent aux
présentes fiches/catalogues/verdicts. #692 restaure des données Sovarka : pas de
fusion ni d’intervention dessus. Les moteurs PNJ, data.js et modules dédiés à
Sovarka restent intacts. Aucun service de traduction externe ajouté ou appelé.

## Trois lots cumulés — 153 nouvelles clés dans neuf langues

| Lot / branche | Commit de code | Clés | Raccordements effectifs |
|---|---|---:|---|
| `codex/i18n-produits-economie-20261110` | `f8ca377e` | 79 | Fiches officielles/commerciales : rubriques, 42 libellés d’effets, 7 capacités, 4 régimes, booléens, usage, stock, vendeur. Inventaire, armurerie, carte et boutique PJ réutilisent les mêmes rendus. |
| `codex/i18n-matieres-catalogue-20261110` | `c53beaf2` | 63 | 19 matières, 41 noms de produits/menus de Républia et 3 descriptions de souvenirs. Carte commune, compositions, fiche et tableaux de matières PJ. |
| `codex/i18n-production-commandes-20261110` | `88315025` | 11 | Sept refus, confirmation portions/salaire, journal ; deux titres ajoutés au catalogue existant des notifications (101 → 103). |

FR, EN, ES, zh-TW, RU, KO, AR, pt-BR et DE : chaque clé est fournie dans les neuf
locales. **1 420 clés françaises de référence** mesurées, zéro clé ni paramètre
manquant. Ce nombre n’est ni le nombre de textes du jeu ni un taux de couverture.

### Autorité et contenus préservés

Les rendus reçoivent les mêmes objets, valeurs, prix, stocks, conditions, raisons
serveur et callbacks. Aucune logique de permission, de paiement, de PA ou de
production ne change. Les prix restent formatés comme avant ; les monnaies ne
sont ni converties ni remplacées. Les littéraux de l’ancien message « 25 FR » et
« FR de salaire » sont conservés : aucune règle monétaire n’est corrigée sous
couvert de traduction. Les noms des lieux et vendeurs restent canoniques.

Le catalogue d’affichage exige **identifiant + texte français exact**. Un produit
renommé, une description personnalisée, une variante inconnue ou un ID non reconnu
ne sont jamais remplacés par une traduction devinée. Les descriptions RP des PJ,
objets sauvegardés et recettes ne sont pas modifiés. Les quatre recettes Dynamo
traduites par #685 restent sur leur chemin existant, sans duplication.

Le moteur reste i18next : marqueurs `data-i18n` et variables `values.*`, puis
`RPI18nPlateau.apply`. Les rendus purs ne font aucun accès réseau. Le changement
de langue des fiches/cartes/tableaux ne relance aucun ordre ni lecture et ne
réécrit pas les saisies. Le message d’une commande retardée utilise la langue
courante à réception. Les titres français de `showToast` sont conservés pour le
diagnostic d’incident ; seul le titre affiché utilise RPToastI18n. Les notifications
éphémères déjà affichées ne sont pas toutes retraduites à chaud : pas de promesse
nouvelle sur ce fonctionnement commun. Français ou contenu original si clé,
variable ou correspondance manque ; jamais d’attribution d’un effet inconnu.

### Avant / après et preuves ciblées

- Avant : fiches communes et propriétés en français, composants de recettes et
  nombreux noms canoniques français, refus et confirmation de production français.
- Après : ces textes se traduisent dans les neuf langues, sans nouvelle exécution.
- **31/31** cas ciblés (fiches, catalogue, production, notifications, éditorial,
  carte existante). Trois nouveaux bancs totalisent **21 cas** ; leurs scénarios
  parcourent les neuf locales et les largeurs 360/390/768.
- Deux comparaisons **strictes** de PNG à 1440 : fiche française et carte française
  identiques au témoin main 7aafbb9f. Une coupure initiale de texte autour du
  vendeur/stock et des puces a été détectée puis supprimée ; aucun seuil assoupli.
- Stocks zéro, salaires zéro, fractions déjà présentes, inconnus, booléens,
  propriétés sans effet et capacités : préservés. Les contenus personnalisés avec
  caractères HTML restent du texte littéral. AR RTL et textes allemands/non latins
  testés ; aucun débordement horizontal dans les fenêtres ciblées.
- Commande retardée puis bascule AR : une seule commande, pas de mutation locale,
  salaire/portions repris de la réponse. Refus caisse et matière : aucun succès,
  diagnostic français. Un complément ciblé vérifie le nom arabe du bois.
- Deux contre-épreuves nouvelles de l’auditeur : matière arabe retirée et variable
  de salaire allemande renommée → **échecs détectés**. Les deux contre-épreuves
  inventaire précédentes passent aussi.

Les témoins contiennent exclusivement des sources publiques compressées, avec
SHA-256 vérifié, pas de données de personnages ni de dépendance au clone profond.
Deux anciens bancs commerce extraient désormais le vrai helper supplémentaire ;
aucune assertion ni aucun scénario supprimé. Les nouveaux bancs sont découverts
par le contrôleur client existant de CI ; aucun pipeline supplémentaire nécessaire.

## Contrôles complets — succès et échecs distincts

**269/270 bancs clients** sur le code cumulé `88315025`. Seul échec :
`banc-pnj-localisation-psm.mjs`, cas « scènes : régénération exacte depuis le même
moteur de casting que le jeu ». Rejoué sur main intact 7aafbb9f : **même échec,
15/16 cas réussis**. Écart exact, dans le bureau du Dynamo : archive
« Bureau du Président », source actuelle « Bureau du président du Dynamo ».
Diff conservé dans les preuves. Aucune correction de ce fichier PNJ/Sovarka de
Claude dans ce lot. L’intégrateur doit réconcilier cet artefact sans changer le
test. Cette anomalie reste une vraie erreur, pas un succès du contrôleur.

**Globaux 10/12**, Workflow et Authority verts. Baseline et Referential rouges.
Rejoués sur main intact avec les mêmes dépendances : sorties **identiques octet
pour octet**. Écarts : `club_accessoire_acheter`, seeds usines/entreprises,
intégrité SQL et empreintes ordres/PA/entreprises. Aucun SQL ou référence modifié.
Ces vérifications sont locales ; aucune observation du catalogue Supabase vivant.

Les journaux, résultats détaillés compressés, empreintes PNG et métadonnées sont
sous `i18n-economie-20261110/`. Aucun compte réel connecté ; aucune modification
ou migration de production. Chromium n’est pas un essai sur appareil physique.

## Éléments restant non couverts

La capture de surface compte **54 fichiers candidats**, 164 marqueurs relevés,
663 affectations de texte et 838 sites HTML dynamiques. Elle inclut des textes RP,
techniques et déjà traduits : **ce n’est pas 663 ou 838 traductions manquantes**.
Les catalogues ne suffisent pas à prouver que tous les écrans les utilisent.

Lacunes constatées, à reprendre sans activer d’anciens circuits :

- `plateau-actions-illegales-rumeurs.js` : formulaires de vente/don et gestion des
  matières, consommation de boissons, échanges administratifs. Les anciennes
  catégories de marché existent encore, mais le parcours actuel `doFaireAchatsCommerce`
  réutilise déjà la carte commune : ne pas réactiver ce sous-moteur historique.
- `plateau-commerce-pj.js` : nombreux libellés métier déjà centralisés dans son
  dictionnaire FR local ; pas tous raccordés aux neuf catalogues. Les tableaux
  ciblés traduisent les matières, pas l’intégralité de leur environnement.
- `plateau-justice-economie.js` : plusieurs textes d’entrepôts/port/douanes/notaire
  et confirmations. Aucun changement dans ces moteurs lors de cette livraison.
- Fiche officielle : valeurs textuelles inconnues (famille, configuration, types,
  conditions JSON, propriétés futures) restent telles que reçues. Un mapping
  autoritaire vérifié est nécessaire avant de les traduire.
- Lieux, professions, organisations et nombreuses fenêtres secondaires restent
  à examiner contexte par contexte ; aucune traduction libre PNJ, forum, courrier
  ou presse n’est lancée. Les contenus attribués à Claude ne sont pas repris.

## Intégration préparée, pas annoncée comme effectuée

Trois branches poussées, à intégrer **dans l’ordre du tableau**. Pour éviter de
faire apparaître les mêmes commits plusieurs fois : première PR vers main,
deuxième initialement vers branche fiches, troisième vers branche catalogue ;
rediriger chacune vers main après intégration de sa dépendance. Titres et corps
prêts dans RELAIS. Aucun conflit avec main 7aafbb9f, resté ancêtre des trois lots.

L’API GitHub GET/POST répond 403 ; l’alternative web permet la lecture publique
(PR et page du commit), pas une création/fusion authentifiée ni la certification
des workflows. **Aucune PR créée et aucune fusion effectuée ici.** Action restant
à l’intégrateur : ouvrir les PR préparées, traiter le généré PNJ avec Claude,
vérifier la CI sur les SHA intégrés puis fusionner selon les protections.

Accès à `https://res-publica.vercel.app/plateau.html` refusé par le tunnel réseau
(403). **READY, version servie et recette en production non vérifiés.** Ne pas
présenter les branches poussées comme publiées. La publication purement linguistique
est autorisée par Fred, mais les preuves de livraison et la validation linguistique
humaine restent nécessaires. Recette téléphone courte : carte → fiche produit,
bascule FR/DE/AR, vérifier noms, valeurs et saisie inchangés, revenir au français ;
aucun achat réel requis. iPhone Safari et Android Chrome physiques restent à tester.

**Verdict : trois lots développés et testés localement ; couverture globale et
livraison non terminées. Aucun résultat CI ou déploiement inventé.**
