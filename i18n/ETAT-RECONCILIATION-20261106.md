# Internationalisation — état vérifié du 6 novembre 2026

## Périmètre en préparation (non publié)

- Neuf langues : français, anglais, espagnol, chinois traditionnel (Taïwan), russe, coréen, arabe, portugais brésilien et allemand.
- Écrans d'accueil et création de personnage : **226 clés françaises canoniques, 226 clés présentes dans chacune des neuf langues** après réconciliation avec les ajouts de `main`. Les pluriels russes supplémentaires sont hors décompte.
- Premier catalogue des commandes : **47 identifiants d'ordres** dans les neuf langues, couvrant notamment police, tribunal, notaire, commerce, banque, football, emploi, institutions, sommeil et prison. Les ordres à libellé ambigu, à montants variables ou absents du catalogue gardent leur texte source.
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
