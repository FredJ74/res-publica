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


### 07/11 — réconciliation mobile/Sovarka et menu tactile (suite de #377)

- **Conflit Git levé** : `main` au SHA `8329bd2a` a été réintégré dans le brouillon de la PR #377 via [PR technique #570](https://github.com/FredJ74/res-publica/pull/570), fusion interne SHA `30d8201b`. La première tentative #569 avait rencontré un conflit sur quatre fichiers (`index.html`, `plateau.html`, `plateau-politique.js`, `style.css`), résolu en appliquant les modifications i18n sur les fichiers récents de main. **Aucune fusion dans main** et aucune activation publique. À ce point, branche i18n : **0 commit de retard** sur main examiné, avec les éléments mobiles/Sovarka conservés.
- **Preuve CI au SHA de fusion `30d8201b`** : workflow « Internationalisation — catalogues et accueil » `42316603840` **vert**, garde Vercel `42316603896` **verte**, contrôle du catalogue civique `42316603844` **vert** ; le contrôle clients général était encore en cours lors de ce relevé. Les commits ultérieurs nécessitent leur propre certification CI.
- Le code i18n conserve **197 ordres canoniques × neuf langues**, sans changer les paramètres serveur. Relecture exacte des labels français contre le `data.js` réconcilié : **197/197** et parité des catalogues : **1 773/1 773 libellés présents**.
- Trois boutons ajoutés par Codex au menu tactile (personnage, présents, menu) sont localisés par `data-i18n` ; `aria-label` du fond est localisé par `data-i18n-aria-label`. Contrôleurs, styles, clics et mécanismes mobiles préservés, sans modification de `plateau-mobile.js`.
- Tests JavaScript isolés exécutés à partir des fichiers GitHub : **14 tests catalogue**, **19 tests moteur/pont/plateau**, **16 tests accueil/création** et **16 tests ressources/guide/mobile**, tous réussis avec un adaptateur V8 (pas une exécution native Node CI). Six simulations de langues navigateur ont également réussi.
- **Reste ouvert** : autres ordres contextuels, messages serveur, forums, presse et dialogues PNJ ; traduction authentifiée avec lecture RLS, quota/cache persistants et maîtrise des coûts ; recette visuelle mobile/RTL et audit linguistique. Aucune migration SQL de traduction, aucun appel DeepSeek payant et aucune publication.


### 07/11 — industrie, santé et simplification de la CI (dernier lot)

- **217 ordres canoniques × neuf langues = 1 953 libellés** dans le catalogue pilote. Le lot supplémentaire de vingt ordres concerne véhicules, logement, pharmacie, carburant, stocks, production industrielle et visite/interrogatoire de détenus. Contrôles de parité et ancrage au `data.js` ajoutés. Cette couverture ne comprend pas l'intégralité des textes dynamiques ou messages serveur.
- **Nettoyage CI** : retrait des trois workflows ponctuels `.github/workflows/i18n-reconcile-main-20261106.yml`, `i18n-ordres-29-20261106.yml` et `i18n-lot-civique-temp.yml`. Le workflow unique `i18n-tests.yml` conserve les contrôles de sécurité, du catalogue et des ressources ; le workflow temporaire de fusion automatique (droit `contents: write`) n'est plus susceptible d'écraser le brouillon.
- **Menu mobile** : seuls les trois libellés tactiles et le nom accessible du fond ont été localisés (neuf langues). Aucun changement de la logique `plateau-mobile.js` de Codex. Tests d'invariance et clés d'accessibilité ajoutés.
- **Intégration dans main : toujours interdite** avant activation explicitement autorisée, relecture linguistique et recette utilisateur. Aucun appel fournisseur payant, aucune migration de traduction, aucune fusion de la PR #377.


### 07/11 — ordres militaires et synthèse de couverture

- **237 identifiants d'ordres × neuf langues = 2 133 libellés**, dont vingt nouveaux ordres militaires (nomination d'officiers, affectations, caserne, armement, unités, mutinerie, renseignement). Ces traductions ne changent ni la hiérarchie ni les règles de combat et n'ajoutent aucune autorité cliente.
- Vérification directe V8 des ressources du dépôt après le nouveau lot : **237/237 libellés français retrouvés exactement dans `data.js`**, neuf catalogues de 237 entrées, **aucune clé manquante** ; l'affichage des variantes contextuelles reste en français, par sécurité.
- Recette GitHub : les workflows du dernier SHA doivent être terminés avant déclaration de validation ; les résultats V8 ne remplacent ni la CI, ni les tests navigateur avec session réelle. PR #377 toujours brouillon, sans fusion dans `main`.


### 07/11 — services essentiels et prévention des régressions

- Ajout de **20 ordres prioritaires** dans les neuf langues : soins (clinique, hôpital, urgences, antipoison), banque et virements, tribunal, presse, nourriture, état civil, logement social et perception des opinions. **Total : 257 ordres canoniques dans chaque langue, soit 2 313 libellés.** La version française correspond aux labels de `data.js` ; les variantes à prix ou texte changeant restent en français.
- Contrôles de parité, garde des identifiants, coûts, PA et permissions intégrés au banc i18n. L'ajout de libellés n'implique aucune activation publique et aucun mécanisme métier n'a été modifié.
- La certification CI au dernier SHA doit être vérifiée avant toute fusion ; les tests interactifs authentifiés et la révision linguistique restent ouverts.


### 07/11 — approfondissement des parcours essentiels et variantes contextuelles

- **380 identifiants canoniques** en neuf langues, soit **3 420 libellés**, après quarante-neuf ordres stables supplémentaires : services essentiels, hôpital, justice, police, diplomatie, métiers, syndicats, armée et transports. Le contrôle statique a confronté les labels français aux littéraux de `data.js` avec prise en charge des apostrophes échappées : 380 correspondances, aucune entrée manquante ni duplication dans les neuf langues.
- **Le même `fn` n'impose plus une traduction approximative** : catalogage indépendant `orderVariants` et clé explicite `i18nKey: 'variant.*'`. Les trois ordres de réservation de chambre conservent leurs montants 80/60 FR et leurs handlers ; sept ordres de rumeurs et deux de conférence de presse conservent leur coût, leur PA, leurs droits et leurs sources PNJ. Toutes leurs variantes sont localisées dans neuf langues sans devenir de nouveaux `fn`.
- L'ensemble reste **sur la PR brouillon** et ne doit pas être fusionné ni activé avant la recette authentifiée, la relecture linguistique et l'autorisation du game designer. Les variantes à montant variable (locaux, parcelles), celles dont les coûts changent ou qui nécessitent un contexte non certifié continuent de s'afficher en français.
- Les bancs ciblés nouveaux et les workflows sont ajoutés ; leur succès CI au dernier SHA reste à confirmer séparément.


### 07/11 — commerce quotidien, tarifs variables et cache mutualisé

- Les **380 ordres canoniques** sont complétés par **23 variantes contextuelles** dans neuf langues. **78 occurrences de commandes** dans `data.js` sont balisées : 3 réservations d'hôtel, 7 rumeurs, 2 conférences de presse, et 66 actions de commerce, production, carte, vente de matières, compte bancaire et gestion de local/coffre. Chaque objet conserve son `fn`, le label original envoyé au handler, ses PA, son prix et ses permissions. Le catalogue `orderVariants` n'ajoute aucun identifiant de commande serveur.
- **Tarifs immobiliers à interpolation limitée** : quatre modèles de location (local, suite, coffre, appartement), achat de terrain avec prix et surface, achat sans prix explicite. Les seules valeurs insérées proviennent du label français et sont limitées aux chiffres, espaces et monnaies FR/PSK déjà affichées ; aucune conversion, aucun arrondi, aucun changement de frais. Formes inconnues ou modèles indisponibles : original français inchangé. Banc dédié `banc-i18n-tarifs-variables.cjs`.
- Le moteur interne de traduction de textes joueurs peut **réutiliser une traduction entre plusieurs lecteurs autorisés** : clé de cache sans UID, **lecture RLS sous le JWT du lecteur avant chaque lecture de cache**, quota persistant toujours réservé par UID en cas de cache manquant. Le service reste interne, sans endpoint HTTP ni fournisseur appelé en production ; banc multi-lecteurs avec contre-épreuve de refus RLS.
- L'affichage d'une traduction vide n'efface plus l'original : nouveau banc de repli. Les placeholders et les contrôles HTML restent inactifs tant qu'aucun résultat sécurisé n'est disponible.
- **Exécutions GitHub certifiées** : i18n [42355043547](https://github.com/FredJ74/res-publica/actions/runs/42355043547) et [42355592203](https://github.com/FredJ74/res-publica/actions/runs/42355592203) réussies ; le second inclut les tarifs variables. Les autres tests clients globaux ne sont pas présentés comme verts sans confirmation. Aucune activation ni publication du multilingue.
- **Synchronisation entrante de main** : PR internes [#573](https://github.com/FredJ74/res-publica/pull/573) (documents) et [#574](https://github.com/FredJ74/res-publica/pull/574) (dîner d'affaires Grand Hôtel de Sovarka) fusionnées **dans la branche brouillon i18n uniquement**. Vérification après #574 : zéro commit de `main` en retard ; le socle du jeu conserve son contrat de dîner à 100 PSK. #377 reste draft, pas de merge vers `main`.
