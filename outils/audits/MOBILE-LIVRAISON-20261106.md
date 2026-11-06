# Mobile — réalisation L0, L1, L2, L3, puis L6 — 6 novembre 2026

**Codé et éprouvé localement, pas fusionné ni déployé.** Les PR restent bloquées par
l'accès API GitHub ; les cinq branches distinctes sont sauvegardées. L'audit #523 et
l'arbitrage #524 sont pris en compte. Claude conserve Sovarka ; aucun de ses fichiers
métier, données ou migrations modifié.

## Résultat

- L0 : contrat de recette et seuils, cinq formats mobiles/tablette + bureau témoin.
- L1 : un DOM unique, panneaux Personnage/Présents/Menu repliables sous 1024 px.
  Les boutons et commandes existants sont conservés ; aucun ordre réimplémenté.
- L2 : scènes pleine largeur, onglets accessibles, liste tactile des zones réellement
  présentes et clavier. La liste appelle le gestionnaire existant ; une scène retirée
  ne peut pas activer un déplacement. Tables et variantes PSM inchangées.
- L3 : fenêtres dans la hauteur visible, saisie >=16 px, focus contenu/restauré, fermeture
  via les boutons prévus et chat paysage borné. Flèches isolées derrière les modales.
- L6 : même moteur de composition étendu à Pointer Events (repli souris), nettoyage sur
  annulation/perte de focus et séparation des champs/boutons natifs d'une poignée.
  Rubriques, sujets et réponses repliés sur petit écran. Format des posts, règles
  d'accès et caches inchangés. Les anciens posts à mise en page libre conservent un
  défilement horizontal local ; aucune réécriture des publications.

Pas de modification des finances, PA, inventaires, personnages, permissions ou
échéances serveur. Aucun compte utilisé, aucune écriture Supabase, aucune migration.
`plateau-mobile.js` est une adaptation de présentation, sans accès réseau ou état métier.
Les activations tactiles passent par le clic déjà protégé du jeu.

## Vérifications

Bancs : `banc-mobile-coque.cjs`, `banc-navigation-rues.cjs`,
`banc-caisses-dialogue-lisibilite-20261031.cjs`.
Le banc mobile est repris automatiquement par le contrôleur existant (pas de second pipeline).

- L1 : 6 cas mobiles, dont PNG bureau strictement identique à 1440 px.
- L2 : 8 cas mobiles cumulatifs ; lieux, clavier, scène obsolète et onglets.
- L3 : 10 cas mobiles cumulatifs ; modale longue, hauteur 350 px, focus/retour, chat.
- L6 : 14 cas mobiles cumulatifs, dont reproduction de l'ancien défaut tactile,
  souris conservée, resize, pointeur étranger, cancel/blur, bouton historique dans
  une poignée, rubriques/listes et comparaison PNG du forum bureau.
- Intégration finale : **38/38** cas mobiles et historiques concernés, incluant les
  quatre variantes du carrefour PSM et les 31 scènes de Luthécia/PSM.
- Les contrôles de chaque branche finale sont également exécutés séparément : L1
  30 cas (6 + 24), L2 32 (8 + 24), L3 34 (10 + 24).

Le témoin HTML/CSS/canvas `728010c8` est embarqué et vérifié SHA-256 ; les comparaisons
ne dépendent ni d'un historique complet ni d'un fetch réseau dans GitHub Actions.
Les PNG avant/après du plateau et du forum bureau sont conservés avec leurs empreintes.
Tout réseau extérieur est bloqué dans ces essais ; polices et icônes utilisent donc
leur repli. Les scènes, personnes et contenus métier sont des fixtures, pas un jeu
connecté. La réduction de hauteur ne constitue pas un véritable clavier système.

## Régressions trouvées et réparées pendant les essais

1. Menu placé sous son fond : corrigé après un vrai clic refusé, sans clic forcé.
2. Priorité historique des tailles de champs : corrigée pour que le calcul CSS soit
   réellement >=16 px sur mobile.
3. Cache CSS : préfixe historique conservé, suffixe de version majoré à chaque lot.
4. Fixture de rues : ajout des méthodes DOM standard setAttribute/getAttribute, sans
   retirer les assertions de destinations, vues, session ou positions.
5. Pointer Events : champs et boutons exclus du démarrage de drag, afin de conserver
   duplication/suppression et menus natifs. Taps et clics vérifiés.
6. Clone CI superficiel : témoin compressé vérifié, sans augmentation du fetch-depth.

## Échecs hérités — ne pas les présenter comme des réussites

Les contrôles globaux donnent **8/12**, même résultat sur le `main` de départ `728010c8` :
- Workflow : SQL égaré `outils/corrections/RATTRAPAGE-SALAIRE-MINISTRE-STAROVKA-20261106.sql`.
- Baseline : écarts de seeds/empreintes, dont ressources_economie et ordres_couts.
- Authority : contrats de fonctions/migrations en écart, notamment trading_acheter.
- Referential : artefacts serveur déclarés RENDU ; voir journal complet.

Aucune référence, seed ou empreinte de production n'a été changée pour obtenir du vert.
Le SQL de salaire n'a pas été déplacé ou appliqué dans ce chantier mobile.
Le premier passage du contrôleur clients signalait trois échecs : deux régressions de
fixture/cache corrigées dans leurs lots d'origine et le rangement hérité ci-dessus.
**Nouveau passage complet : 195/196 bancs réussis**, seul le rangement SQL hérité
reste rouge. Les deux régressions du lot sont résolues.

## Branches et intégration

Ordre : L0 → L1 → L2 → L3 → L6. Descriptions et bases des PR :
`outils/livraison/MOBILE-PR-PAR-LOT-20261106.md`.
Dernier main examiné `bba6dec9` : uniquement confirmation de répartition #524 depuis
`728010c8`, intégrée dans L6 sans conflit. Pas de modification concurrente des trois
fichiers réservés. Les tests bureau gardent le témoin applicatif antérieur.

`gh pr create` pour L0 est refusé : `Post https://api.github.com/graphql: Forbidden`.
Le push Git est fonctionnel. Aucune PR ni CI distante verte inventée. La création des
cinq PR séparées par l'intégrateur est la seule opération GitHub restante ; aucune
manipulation de secret ou SQL n'est demandée à Fred.

Pas de fusion ni de déploiement réalisés : CI distante non consultable/certifiée et
contrôles hérités non verts. Une Preview automatique éventuelle relève de l'intégration
Git existante, pas d'une commande de déploiement exécutée ici ; elle n'est pas vérifiée.

## Limites et suite

Pas de vrai Safari iOS ni Android physique, pas de recette authentifiée isolée ou de
transaction réelle. Ces validations restent nécessaires avant d'annoncer la version
mobile entièrement jouable. L4 (création) et L5 (toutes les interfaces d'inventaire,
banque/commerce) ne sont pas réalisés par cette mission. Leurs coques bénéficient des
adaptations communes, mais leurs parcours complets ne sont pas certifiés ici.
Les mots de passe, statuts serveur et objets restent sous l'autorité des moteurs existants.

## Preuves conservées

[Résultats structurés](preuves-mobile-lots-20261106/RESULTATS.json) et [SHA-256](preuves-mobile-lots-20261106/SHA256.json).
Les PNG avant/après du plateau et du forum bureau ont des empreintes identiques.
Exemples : [menu](preuves-mobile-lots-20261106/mobile-375-menu.png),
[forum avec contenu fixture](preuves-mobile-lots-20261106/mobile-375-forum.png),
[fenêtre à hauteur réduite](preuves-mobile-lots-20261106/mobile-375-hauteur-350.png).
Les captures ont été inspectées : aucun compte ou donnée de joueur.
La publication groupée des journaux bruts a été rejetée par le contrôle automatique
pour risque de contenu non inspecté. Après vérification, ils sont conservés localement ;
seuls résultats structurés, empreintes et captures de fixtures sont publiés.
