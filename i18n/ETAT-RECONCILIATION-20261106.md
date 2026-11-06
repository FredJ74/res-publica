# Internationalisation — état vérifié du 6 novembre 2026

## Périmètre en préparation (non publié)

- Neuf langues : français, anglais, espagnol, chinois traditionnel (Taïwan), russe, coréen, arabe, portugais brésilien et allemand.
- Écrans d'accueil et création de personnage : **226 clés françaises canoniques, 226 clés présentes dans chacune des neuf langues** après réconciliation avec les ajouts de `main`. Les pluriels russes supplémentaires sont hors décompte.
- Premier catalogue des commandes : **77 identifiants d'ordres** dans les neuf langues, couvrant notamment police, tribunal, notaire, commerce, banque, football, emploi, institutions, sommeil et prison. Les ordres à libellé ambigu, à montants variables ou absents du catalogue gardent leur texte source.
- Le renderer existant de `plateau-politique.js` traduit exclusivement le texte visible, avec échappement HTML. Les fonctions, coûts, PA, habilitations et le libellé historique transmis à `doOrder` ne changent pas.
- Plateau : libellés statiques et navigation de base câblés, repli français conservé ; premier niveau RTL limité aux textes en arabe.
- Textes des joueurs : original conservé, bouton original/traduction sans remplacement serveur. Traduction profonde non exposée ; garde RLS + quotas simulée uniquement.

## Réconciliation technique

La branche de la [PR #377](https://github.com/FredJ74/res-publica/pull/377) a intégré les derniers commits de `main` par fusion Git **sans conflit restant** le 6 novembre 2026. Les ajouts au socle sont conservés ; l'ancien ordre `virement_joueur`, retiré de `main`, est remplacé dans le catalogue pilote par l'ordre réel `se_rebeller`.

Le banc `outils/audits/reconcilier-i18n-main-20261106.cjs` rapproche les huit nouveaux libellés d'accueil et création dans les trois dernières langues, et restaure la traduction des variantes de boutons touchées par les conflits. Il fonctionne lors des fusions successives sans réinsérer les ressources déjà présentes.

Les deux workflows i18n du brouillon, la réconciliation de `main` et le contrôle des catalogues ont été exécutés avec succès le 6 novembre. Les tests valident la couverture, les paramètres d'interpolation, les ordres canoniques et l'absence de modification des contrats métier.

## Ce qui reste à certifier AVANT publication

1. Relecture linguistique des neuf catalogues, y compris nuances satiriques et politiques, sans traduire les noms propres.
2. Traduction des centaines d'autres ordres et menus dynamiques en respectant leurs variantes contextuelles.
3. Messages serveur, notifications, courriers, presse, forums et dialogues PNJ, avec droits de lecture RLS.
4. Stockage persistant sécurisé du budget et du cache de traduction, contrôle anti-abus, mesure des coûts et essais sous JWT réel. Aucun nouvel endpoint public de traduction avant ces garanties.
5. Parcours Chromium authentifiés, tests visuels RTL et navigateur Safari/Android, tests de panne, absence de régression FR.
6. Décision explicite du game designer pour rendre la fonctionnalité visible publiquement.

**Statut : développement isolé dans une PR en brouillon. Rien n'est fusionné en production ; aucune migration SQL ni activation publique.**

## Lot civique du 6 novembre — 20 ordres supplémentaires

- Catalogue pilote passé de **57 à 77 ordres** dans les neuf langues (FR, EN, ES, zh-TW, RU, KO, AR, pt-BR, DE) : liste des produits, annonces BNE, manifestations, naturalisations, couvre-feu, douanes, budget, QHS, mobilisation, cessez-le-feu, médias, sondages, élections, Parlement, diplomatie et divorce.
- La correspondance du **libellé français source** a été confrontée à `data.js` sur la version de `main` du jour. Les 9 traductions restent soumises à relecture éditoriale.
- Régression exécutée sur une branche de test fondée sur `main`, **PR #563 non destinée à être fusionnée** : **12/12 tests ciblés verts** (8 catalogues, 4 invariance du moteur), sur 77 identifiants, sans changer coûts, PA, permissions, identifiants d'ordre ni données des PJ.
- La PR #377 reste séparée, non fusionnée et sans activation publique ; sa divergence avec `main` impose une réconciliation globale avant déploiement.

## Navigation supérieure du plateau — 6 novembre, lot suivant

- Huit boutons du bandeau `plateau.html` reçoivent une traduction visible en neuf langues : indices impériaux, règles, messages/forums, joueurs, organisations, élections, carte et plan.
- Huit infobulles associées sont traduites par l'attribut `data-i18n-title` ; le moteur existant `plateau-init.js` ne remplace **jamais** le contenu entier du bouton (icônes, notifications, compteurs et fonctions `onclick` restent intacts).
- L'arabe applique `dir=rtl` aux seuls textes traduits, pas à la mise en page ni aux éléments interactifs du bandeau.
- Contrôle isolé via [PR de test #564](https://github.com/FredJ74/res-publica/pull/564), **29/29 tests verts** (8 catalogue, 4 moteur, 4 rendu, 2 ressources, 5 câblage, 3 initialisation, 3 navigation) exécutés directement sur la branche de la PR #377. Syntaxe JS également vérifiée.
- La PR #377 demeure en brouillon, non activée : tests visuels Chrome, Firefox, Safari, mobile et relecture linguistique toujours requis avant toute publication.
