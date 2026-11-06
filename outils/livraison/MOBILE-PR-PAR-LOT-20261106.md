# Intégration mobile — une PR par lot

Les créations de PR par `gh pr create` sont refusées par GraphQL (`Forbidden`).
Toutes les branches sont poussées. Ne pas annoncer de numéro de PR non créé.
Les descriptions ci-dessous sont prêtes pour l'intégrateur disposant d'un accès fonctionnel.
Ne pas fusionner l'ensemble en une PR et ne pas contourner les contrôles hérités rouges.

| Lot | Branche source | Base initiale de sa PR | Titre |
|---|---|---|---|
| L0 | `codex/mobile-l0-l3-20261106` | `main` | Mobile L0 — contrat de recette |
| L1 | `codex/mobile-l1-coque-20261106` | `codex/mobile-l0-l3-20261106` | Mobile L1 — coque et panneaux repliables |
| L2 | `codex/mobile-l2-navigation-20261106` | `codex/mobile-l1-coque-20261106` | Mobile L2 — navigation et pièces tactiles |
| L3 | `codex/mobile-l3-fenetres-20261106` | `codex/mobile-l2-navigation-20261106` | Mobile L3 — fenêtres, clavier et focus |
| L6 | `codex/mobile-l6-forum-20261106` | `codex/mobile-l3-fenetres-20261106` | Mobile L6 — forum et gestes du contrôleur commun |

Après fusion d'une base, réconcilier puis rediriger la suivante vers main. Les branches
sont dépendantes, pas cinq fonctions économiques parallèles. Les correctifs des bancs
ont été propagés dans les lots dépendants par des merges explicites.
Les workflows actuels visent les PR vers main : une PR empilée vers une branche de lot
ne prétend pas avoir ces contrôles ; les relancer sur le SHA d'intégration avant fusion.
Aucune migration Supabase n'est nécessaire ou préparée.

## Corps L0

Contrat de recette sur cinq formats téléphone/tablette et témoin bureau 1440 px.
Aucun changement de jeu. Les lots suivants conservent DOM, commandes et autorité serveur.

## Corps L1

Sous 1024 px, les panneaux existants Personnage/Présents/Menu sont repliés en tiroirs.
Même DOM et mêmes gestionnaires ; fermeture et focus préservés. 6 tests mobiles +
24 contrôles historiques ; bureau 1440 comparé pixel pour pixel. Témoin 728010c8
embarqué sous forme de fixture compressée avec empreinte, compatible clone CI superficiel.
Préfixe historique de cache CSS conservé et suffixe mobile ajouté.

## Corps L2

Liste tactile construite à partir des zones déjà résolues, activant leur clic existant.
Clavier accessible ; coordonnées, destinations et quatre variantes de PSM inchangées.
Pièces/actions utilisables en paysage. 8 tests mobiles et 24 contrôles historiques.
Fixture DOM complétée, sans suppression d'assertions. Bureau 1440 pixel identique.

## Corps L3

Coques existantes adaptées à la hauteur visible, champs >=16 px, focus contenu et
restauré, chat paysage borné. Escape passe par le vrai bouton de fermeture et n'enlève
jamais arbitrairement une fenêtre métier. 10 tests mobiles et 24 contrôles historiques ;
bureau 1440 pixel identique. Aucun vrai clavier iOS ni compte connecté testé.

## Corps L6

Même contrôleur canvas pour souris et tactile : Pointer Events avec repli souris,
filtrage du pointeur et nettoyage sur cancel/blur. Boutons et champs d'une poignée
conservent leurs gestes natifs. Forums repliés en mobile ; sérialisation, droits,
notifications et publications historiques inchangés. 14 tests mobiles dont ancienne
panne reproduite, et 24 contrôles historiques. Plateau et forum bureau 1440 identiques.
Les mises en page composées historiques restent lisibles par défilement horizontal
local, sans écrasement de leurs coordonnées. Aucun message réel publié.

## Conditions avant intégration

Consulter `outils/audits/MOBILE-LIVRAISON-20261106.md` et les preuves. Le rangement SQL,
Baseline, Authority et Referential rouges étaient déjà présents dans la base de départ.
Ne pas annoncer de CI verte avant exécution distante. Pas de déploiement effectué par
cette session. Recette authentifiée isolée et vrais appareils restent à réaliser.

## SHA des dépendances sauvegardées

- `codex/mobile-l0-l3-20261106` : `83cbe1d41c173f110146ee95340eff0ed5b5a743`
- `codex/mobile-l1-coque-20261106` : `aa653bbf21af2f8038c9149b9d23a26dbd729138`
- `codex/mobile-l2-navigation-20261106` : `bee63c9134b06cb22c22860eb9f043e53efcb280`
- `codex/mobile-l3-fenetres-20261106` : `9f8e89125bb77fc9aa88a3f1fedceb849dcc58a0`
- L6 : dernier commit de `codex/mobile-l6-forum-20261106` ; les preuves sont ajoutées après le code validé.
