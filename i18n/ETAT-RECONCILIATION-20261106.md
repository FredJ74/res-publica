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

- **197 identifiants d'ordres** localisés dans chacune des neuf langues : aux 77 initiaux s'ajoutent cinq lots de 20 ordres : gouvernement/presse/économie, sport/justice, notariat/immobilier, transports/syndicats/vie sociale, puis immobilier/services sociaux/manifestations, et enfin 20 ordres organisations, presse associative, religions et diplomatie. Le catalogue français du nouveau lot reprend volontairement les libellés exacts de `data.js`, y compris leur graphie historique. Ce chiffre ne représente PAS tous les ordres et variantes du jeu.
- Les tests de catalogue contrôlent la stricte parité des neuf langues, la présence des nouvelles commandes dans `data.js` et l'absence de mutation des paramètres métier (`fn`, `label`, `pa`, `cost`, `requiresPost`). Les variantes non cataloguées conservent le français original.
- Le plateau n'affiche plus une clé technique si une traduction statique manque : le texte français déjà présent dans le DOM est conservé. Test dédié ajouté.
- Le traducteur de contenu refuse désormais les caractères de contrôle avant réservation du quota ; le cache doit respecter les contraintes de taille et de caractères de contrôle avant d'être servi, après lecture RLS. Contre-épreuves ajoutées. **Il reste interne**, sans endpoint public, ni cache/quota persistants opérationnels.
- **Statut de validation** : commits poussés dans la branche brouillon, test CI au dernier SHA non encore attesté depuis le connecteur. Aucun test authentifié ni vraie revue linguistique, aucune activation ni fusion de #377. `main` a continué d'évoluer et exige un rapprochement prudent.


### 07/11 — interface du plateau : guide, courrier et inventaire

- Neuf onglets du guide des règles localisés en neuf langues (y compris les emojis du tutoriel et du football), **sans toucher aux `data-section` ni aux handlers `renderRulesContent`**. Le corps du guide demeure à traduire : l'onglet seul ne signifie pas couverture complète.
- Libellés statiques d'inventaire vide, consigne de rue et titre de plan câblés aux clés déjà présentes ; le formulaire courrier localise « À » et l'indication de destinataire sans altérer la valeur saisie.
- `i18n/plateau-init.js` gère désormais `data-i18n-placeholder` avec repli sur l'attribut d'origine quand la clé manque, sans toucher aux icônes, badges ni valeurs de formulaire.
- L'inventaire **vide après un rendu dynamique** réutilise `plateau.noItems` et le moteur du plateau. Aucun calcul de quantité, effet sur l'inventaire ou action serveur modifié.
- Nouveau banc `outils/bancs/banc-i18n-guide-mail.cjs` et contrôle d'initialisation du placeholder, branchés dans la CI de #377. Audit statique des neuf catalogues et de leur câblage réalisé, sans erreurs détectées. **CI GitHub et essai navigateur authentifié du dernier SHA toujours non certifiés.**


### 07/11 — mesure de couverture et backlog non masqué

- Script en lecture seule `outils/audits/etat-i18n-ordres.cjs` : réutilise l'inventaire d'ordres du dépôt, compare les labels exacts aux ressources, distingue identifiants stables couverts, identifiants ambigus partiellement couverts, libellés stables non encore traduits et références de catalogue obsolètes. Il ne prétend pas mesurer les labels générés à l'exécution.
- Test `outils/bancs/banc-i18n-etat-ordres.cjs` : vérifie les **197 entrées françaises ancrées dans le code source** et la parité en neuf langues, sans autoriser à déclarer le jeu intégralement traduit. La CI conserve un artefact `i18n-ordres-restants` pour préparer les prochains lots.
- Les scripts ne se connectent pas à Supabase, ne touchent ni aux personnages ni aux prix, et ne modifient aucun ordre. La CI réelle du dernier commit est toujours à certifier.


### 07/11 — finition du formulaire de courrier

- Les trois placeholders « Destinataire », « Objet du message » et « Votre message » disposent désormais de clés dans chacune des neuf langues. La valeur des champs n'est jamais traduite ou remplacée.
- Les tests du guide et du courrier couvrent les trois emplacements, les neuf langues et les gestionnaires historiques. Le rendu de l'inventaire vide protège aussi les environnements sans objet global `window` (bancs hors navigateur).
- Tests CI ajoutés mais exécution distante sur le SHA courant non disponible ; ne pas présenter cette livraison comme validée sur vrais téléphones ou dans une partie authentifiée.


### 07/11 — continuité multilingue et couverture sociale

- **20 nouveaux ordres sociaux et d'organisation** localisés dans les neuf langues : presse, vie syndicale/associative, religion, relations diplomatiques, manifestations de pouvoir et réseaux. Le catalogue passe à **197 libellés canoniques** par langue. Les ordres hors catalogue restent en français pour éviter les ambiguïtés de prix et de contexte ; les identifiants et les mécaniques restent inchangés.
- Le pont du plateau tire désormais les langues du même `RP_I18N_LANGUAGES` que l'accueil, et la préférence suit le même principe : `localStorage` explicite, sinon langue du navigateur (correspondance régionale prudente), sinon français. Par exemple es-MX → es, zh-Hant-TW → zh-TW, zh-CN reste fr. Aucun nouveau moteur ni sélection automatique selon empire/adresse.
- Exécution directe de cinq modules navigateurs dans un contexte JavaScript isolé : **177 libellés** (lot précédent) correspondants au code source, aucune clé manquante dans les neuf langues, maintien des montants, commandes et fallback. Six simulations de démarrage sur des locales régionales : **6/6 conformes**, placeholder conservant la saisie et direction arabe locale. Le nouveau lot de vingt est soumis aux mêmes tests CI mais non certifié à distance.
- Les vérifications de code ne remplacent ni une recette authentifiée ni une relecture linguistique. La PR demeure en brouillon et aucune activation publique n'est autorisée.
