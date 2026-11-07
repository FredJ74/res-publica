# Revalidation des six branches mobiles — 7 novembre 2026

Lecture AGENTS.md et RELAIS.md sur main `a5e32332`. Les six lots étaient déjà
fusionnés et en bêta : cette reprise conserve leur code, sans les réimplémenter.
Les branches reçoivent main puis la validation précédente dans l'ordre demandé.

| Lot | Branche | SHA testé avant ajout du compte rendu | Tests UI / clients |
|---|---|---|---|
| L5 | `codex/mobile-l5-transactions-20261106` | `a5e32332` | 2 / 31 |
| L8 | `codex/mobile-l8-reprise-20261106` | `ee4ec1fd` | 4 / 19 |
| L4 | `codex/mobile-l4-creation-20261106` | `1340808d` | 2 / 7 |
| L7 | `codex/mobile-l7-institutions-20261106` | `3f480599` | 2 / 17 |
| L9 | `codex/mobile-l9-chargement-20261106` | `c3c1f7b3` | 2 / 8 |
| L10 | `codex/mobile-l10-recette-20261106` | `0fbf015e` | 21 / 37 |

Les tests UI incluent le témoin bureau 1440 à chaque lot. L4 exécute les vraies
étapes de création dans six langues sur fixtures, conserve les lignes « En jeu »
et ne crée aucun compte. L7 ne lance aucun combat, arrestation ou ordre à effets.
L9 vérifie les vraies miniatures dans le panneau fermé puis ouvert. L8/L10 simulent
réseau perdu, retour visible, session refusée, authentification tardive et autre
onglet ; ce dernier n'est pas un test de deux appareils authentifiés.

## Protection du chargement #579

Seul changement technique par rapport à main : trois cas ajoutés au banc existant
`banc-mobile-restauration-retardee.cjs`, dans L8 puis propagés aux lots suivants.
Ils exécutent le vrai `forceRenderCity`, la vraie minuterie d'initialisation et la
restauration différée : bâtiment conservé avec `garderBatiment`, reproduction de
l'abandon sans l'option, rendu de rue maintenu si aucun bâtiment n'est restauré.
Aucune modification de la fonction, du chargeur, de la position ou du cache client.
Aucun fichier applicatif, ordre, montant, règle de jeu ou migration modifié.

## Préparation de l'intégration

Chaque branche porte sa rubrique dans RELAIS.md : SHA testé, titre, description de
PR et contrôles attendus. Corps REST prêts dans
`outils/livraison/MOBILE-REPRISE-PR-20261107.json` ; Claude assure création, CI et fusion.
Les références testées précèdent leurs commits de comptes rendus (documentation et
preuves seulement) ; la CI devra contrôler les têtes finales des PR.

Ordre : **L5 → L8 → L4 → L7 → L9 → L10**. Comme ces fonctionnalités sont déjà en bêta,
vérifier le diff après chaque fusion : pas de seconde livraison des anciens lots.
Aucune PR créée ou fusionnée depuis cette session, aucun déploiement commandé.

Empreintes des trois paires PNG 1440 identiques :
`outils/audits/MOBILE-REPRISE-TEMOINS-20261107.json`. Les captures de fixtures et
journaux bruts restent locaux ; aucun compte ou secret n'a été utilisé.

## Vérifications de clôture

**199/199 bancs clients réussis**, aucun SQL exécuté. Résultat structuré dans
`MOBILE-REPRISE-CONTROLES-20261107.json`. Vérificateur Workflow conforme. `git diff --check` conforme.

Reste la CI distante sur chaque PR et la recette sur Safari/Android réels,
verrouillage OS/clavier réel et deux appareils authentifiés avec compte isolé
explicitement autorisé. Aucun fonctionnement authentifié en production n'est
certifié par les fixtures Chromium. Pas d'arbitrage de game design nécessaire.
