# Sorties refusées — 16 novembre 2026

Audit du parcours réel `sortirBatiment` → `confirmerSortieBatimentServeur` → `signalerEchecSortie`. Les huit corps fixes de `sortieBatimentMessage` n'étaient pas reconnus par le catalogue commun des notifications (#924). Sous Chromium avec les catalogues chargés et une session anglaise, ils restaient effectivement en français.

Huit corps et six titres sont ajoutés au catalogue **navigation existant** : 14 textes français identiques, 112 traductions étrangères. Deux titres sont réutilisés sans traduction dupliquée : `toastTitles.sessionExpired` et `forumFeedback.titleConnection`. Une annotation `markToast` dans `signalerEchecSortie` raccorde le rendu au moteur commun. Le calcul du message, les verdicts, les appels serveur, les diagnostics, la reconnexion et la reprise des combats restent identiques.

## Vérifications

Trois tests ciblés : français et anciennes ressources préservés ; fichier de navigation intégralement identique au commit de référence après retrait de la seule annotation UI ; 459 bascules Chromium sur 17 situations (priorités session/incertitude, réseau, HTTP 403/500, sortie inconnue, réponse illisible, refus métier et combat), neuf langues, 320/390/1280 px. Toast réel, CSS réelle, fonctions réelles de notification et de signalement ; transports, combat et bannière de reconnexion simulés et comparés à la version précédente. Aucun acteur de production n'est connecté.

Le changement de langue conserve PA, argent, position, inventaire, progression, saisie, sélection, focus, défilement et délai de fermeture du toast. Les diagnostics originaux sont identiques ; aucune répétition des appels de reconnexion, combat ou RPC. Arabe RTL, textes longs et limites horizontales vérifiés. Le français est le repli lorsqu'une clé étrangère manque ; un texte libre ultérieur reste opaque et supprime naturellement le marquage précédent.

Brotli régénéré et manifeste actualisé. Aucun nouveau moteur, style ou composant, aucune migration, aucun prix ou coût modifié. Les fenêtres métier restent hors périmètre ; la bannière de reconnexion est déjà traduite à sa création et n'est pas modifiée ici.

## Livraison

PR #1021 fusionnée après livraison vérifiée de #1018. Commit de fusion da1c508e4ed7f1836cc318749a030b376ca6a35f (tête 2ddd6aa), 47 contrôles CI réussis, dont le banc général JavaScript et PostgreSQL jetable. Production Vercel dpl_GHiRpj6jhrtiTa6gEAP14JiAFSaU READY ; alias res-publica.vercel.app et commit exact confirmés. Quatorze fichiers publics identiques au dépôt ; sept tests rejoués sur ces fichiers : 459 bascules des refus et 1 080 des en-têtes, toutes vertes. Les 84 catalogues sont également chargés par Chromium depuis l’alias public et décompressés nativement, octet pour octet conformes.

41 tests ciblés/régression, 14 tests du plan et 418 test-*.mjs verts sur branche (418 sur référence). Les 384 bancs client ont été parcourus localement : 375 verts immédiatement, neuf échecs de dépendances locales absentes. Dépendances rétablies, huit bancs repris avec succès ; le dernier contrôle global repris avec le Python/pglast prévu passe également. Aucun résultat brut effacé et aucune assertion affaiblie pour ces dépendances. Le test du plan vérifie toujours la présence de son marqueur de cache historique, en acceptant désormais les préfixes ultérieurs. La CI complète sur checkout propre est entièrement verte. Ni PJ connecté, ni téléphone physique, ni relecture linguistique native annoncés.

Lacunes prioritaires restant à auditer : noms/catégories des bâtiments (`bat-nom`/`bat-cat` restent alimentés directement par le contexte), fenêtres de gestion et messages contextuels de commerce. Le chantier actif #1017 de Claude modifie data.js, les caisses, les entrepôts, les coûts et les catalogues communs : attendre son intégration avant un lot voisin dans ces parcours pour éviter les doublons. Aucun de ses changements n’est inclus ici. Pas de pourcentage global sans audit exhaustif.
