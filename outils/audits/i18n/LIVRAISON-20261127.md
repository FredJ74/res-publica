# Clôture des lots i18n du 23 novembre — vérification du 27/11/2026

> **Mise à jour CI** : fonctionnalités #1183/#1184 fusionnées et vérifiées ; clôture documentaire **#1216 non fusionnée**, bloquée par le miroir `ordres_couts` déjà incohérent sur main. Voir `BLOCAGE-CLOTURE-20261127.md`. Les contrôles push verts cités ci-dessous étaient filtrés et ne certifient pas tous les bancs hors sélection. Aucun seed ni coût modifié.


## Codé et fusionné

- PR #1183, commit `8b2c2bffa60f7993b185fa696c5854ab6dce46da`, fusionnée le 24/11 : université, **51 textes français couverts**, **368 nouvelles traductions étrangères**, **40 traductions réutilisées**. Les 41 originaux restent strictement identiques ; cinq intitulés longs réels et cinq familles de carrières sont raccordés. Progression conservée sous son identifiant brut ; aucune réactivation des quatre cursus fermés.
- PR #1184, commit `e4ef92bfbdf2bb64548ba955cc1a3411f52de5ba`, fusionnée le 24/11 : nom et description de création de parti LTR hors arabe, RTL arabe ; aucune nouvelle traduction, 22 clés existantes inchangées. Valeur, focus et sélection conservés.
- Ces fusions ont été constatées à la reprise du 27/11 ; elles n’ont pas été exécutées une seconde fois. Aucun nouveau lot de traduction engagé.

## Testé

Rejeu sur `6ebbbd9e` : **42/42 tests**, six bancs formation, audit, transport, saisie politique et création d’organisation. Neuf langues, 320/390/1280 px, arabe RTL ; 648 bascules universitaires par largeur, 28 états/756 bascules du banc organisation existant. Comparaison des commandes et paramètres avec l’original, français exact, progression/position/PA/argent/saisies conservés et aucun rejeu métier lors des bascules. Compléments : vraie fonction showToast (81 bascules), 320×568/390×568 (fermeture accessible après défilement, aucun débordement). **87 catalogues Brotli conformes**, restitution sans perte.

Les liens et résultats des contrôles des deux PR sont dans `LIVRAISON-20261127.json` : tous verts sur leurs derniers commits. **82 exécutions push associées au commit main servi sont vertes**, dont la batterie générale **46077425384**. La recherche des exécutions push aux deux anciens SHA de fusion ne renvoie aucun résultat : ces exécutions précises ne sont donc pas revendiquées ; la preuve générale repose sur leur descendant actuellement servi.

Au redémarrage, deux liens locaux de dépendances pointaient vers des chemins macOS absents. Ils ont été réorientés temporairement vers les dépendances installées du workspace pour les tests, puis restaurés. Aucun changement de dépendance ou de fichier du jeu dans ce lot documentaire.

## Déployé et vérifié

Vercel **`dpl_BpzPsoEsaaEu2sHrUbZAA4gmEkLp` READY**, production sur **`6ebbbd9e8158985d2968e3a6d70a67d38410ca69`**, descendant des deux fusions. Alias `human-gambit.com` et `www.human-gambit.com` attachés, sans erreur d’alias. Les GET publics de `i18n/resources.js`, `plateau-universite.js`, `i18n/university-resources.js` et `i18n/organization-creation-resources.js` répondent 200, JavaScript Brotli, et correspondent octet pour octet à ce commit. Ressources universitaires : 46 clés × neuf langues ; références des cinq carrières disponibles dans le catalogue commun. Preuves : `PRODUCTION-20261127.json` et `VERCEL-20261127.json`.

## Couverture et lacunes

L’audit contrôlé avant/après du 23/11 reste `ETAT-I18N-20261123.md`, avec matrices par domaine, neuf langues et pays, inventaires des textes et clés manquantes. Le raccord dynamique universitaire est vérifié séparément : son gain de 51 textes ne doit pas être ajouté sans dédoublonnage au taux de l’extracteur statique.

Actualisation du 27/11, même extracteur, zéro erreur :

| Langue | Textes raccordés statiquement / corpus | Ressources disponibles |
|---|---:|---:|
| fr | 7762/7762 (100 %) | 7762 |
| en | 1854/7762 (23.89 %) | 2581 |
| es | 1860/7762 (23.96 %) | 2597 |
| zh-TW | 1864/7762 (24.01 %) | 2607 |
| ru | 1864/7762 (24.01 %) | 2606 |
| ko | 1864/7762 (24.01 %) | 2607 |
| ar | 1864/7762 (24.01 %) | 2606 |
| pt-BR | 1858/7762 (23.94 %) | 2599 |
| de | 1861/7762 (23.98 %) | 2600 |

Ces valeurs restent des preuves statiques partielles, **pas le pourcentage de tout le jeu traduit**. Les changements intervenus depuis le 23/11 comprennent les travaux de Claude et ne sont pas attribués aux deux lots. La photographie courante est `ACTUALISATION-I18N-20261127.json`. Les tableaux détaillés par domaine/pays du 23/11 gardent leur date, sans les présenter comme une mesure exhaustive au 27/11.

Zones laissées à Claude : personnage/inventaire/patrimoine, journal/chat/navigation, PNJ de Sovarka, musées et bâtiments réservés de Krasnov/Novomirsk, cartes postales et accueil. PR #1132 non reprise. Dans l’université, les consignes et récits libres du serveur, noms propres, dates et lieux ne sont pas traduits par ce lot de présentation. Ils restent à auditer séparément.

## Signalement de Bernard et limites

Journal main **45270169896** lu : 12/13, échec du bouton Envoyer après une longue réponse à 390 px. **Ni instabilité Chromium ni lien causal avec la mauvaise signature/publication de Bernard établis**. Les trois bancs concernés ne couvrent pas Bernard, Sovarka/domicile Krasnov → Vera Pravdina/forum Sovarka. La CI actuelle verte ne prouve pas la correction de son article. Détail dans `INTERVIEW-ACCUEIL-VERIFICATION-20261123.md` ; aucune correction de ce parcours ni accès au personnage dans cette mission.

Aucune écriture en base, aucune migration appliquée ; aucun PJ connecté, téléphone physique ou relecture native testé.

## Difficultés de traduction

- « Seconde carrière » : second métier acquis, sans redémarrage du personnage.
- « Maître de stage » : responsable ou mentor, sans inventer de PNJ.
- « Personnage mineur » : mineur en âge, pas profession minière.
- Intitulés longs réels distincts des titres courts ; français serveur accentué conservé au repli.
- Aucun arbitrage de gameplay ni jeu de mots nouveau nécessaire.
