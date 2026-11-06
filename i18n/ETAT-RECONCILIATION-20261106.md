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


## Avancée du 7 novembre — non activée

- **117 identifiants d'ordres** localisés dans chacune des neuf langues : aux 77 initiaux s'ajoutent 20 ordres de présidence/gouvernement, presse et économie, puis 20 ordres sportifs et judiciaires. Le catalogue français du nouveau lot reprend volontairement les libellés exacts de `data.js`, y compris leur graphie historique. Ce chiffre ne représente PAS tous les ordres et variantes du jeu.
- Les tests de catalogue contrôlent la stricte parité des neuf langues, la présence des nouvelles commandes dans `data.js` et l'absence de mutation des paramètres métier (`fn`, `label`, `pa`, `cost`, `requiresPost`). Les variantes non cataloguées conservent le français original.
- Le plateau n'affiche plus une clé technique si une traduction statique manque : le texte français déjà présent dans le DOM est conservé. Test dédié ajouté.
- Le traducteur de contenu refuse désormais les caractères de contrôle avant réservation du quota ; le cache doit respecter les contraintes de taille et de caractères de contrôle avant d'être servi, après lecture RLS. Contre-épreuves ajoutées. **Il reste interne**, sans endpoint public, ni cache/quota persistants opérationnels.
- **Statut de validation** : commits poussés dans la branche brouillon, test CI au dernier SHA non encore attesté depuis le connecteur. Aucun test authentifié ni vraie revue linguistique, aucune activation ni fusion de #377. `main` a continué d'évoluer et exige un rapprochement prudent.
