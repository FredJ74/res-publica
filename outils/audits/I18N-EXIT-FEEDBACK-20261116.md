# Sorties refusées — 16 novembre 2026

Audit du parcours réel `sortirBatiment` → `confirmerSortieBatimentServeur` → `signalerEchecSortie`. Les huit corps fixes de `sortieBatimentMessage` n'étaient pas reconnus par le catalogue commun des notifications (#924). Sous Chromium avec les catalogues chargés et une session anglaise, ils restaient effectivement en français.

Huit corps et six titres sont ajoutés au catalogue **navigation existant** : 14 textes français identiques, 112 traductions étrangères. Deux titres sont réutilisés sans traduction dupliquée : `toastTitles.sessionExpired` et `forumFeedback.titleConnection`. Une annotation `markToast` dans `signalerEchecSortie` raccorde le rendu au moteur commun. Le calcul du message, les verdicts, les appels serveur, les diagnostics, la reconnexion et la reprise des combats restent identiques.

## Vérifications

Trois tests ciblés : français et anciennes ressources préservés ; fichier de navigation intégralement identique au commit de référence après retrait de la seule annotation UI ; 459 bascules Chromium sur 17 situations (priorités session/incertitude, réseau, HTTP 403/500, sortie inconnue, réponse illisible, refus métier et combat), neuf langues, 320/390/1280 px. Toast réel, CSS réelle, fonctions réelles de notification et de signalement ; transports, combat et bannière de reconnexion simulés et comparés à la version précédente. Aucun acteur de production n'est connecté.

Le changement de langue conserve PA, argent, position, inventaire, progression, saisie, sélection, focus, défilement et délai de fermeture du toast. Les diagnostics originaux sont identiques ; aucune répétition des appels de reconnexion, combat ou RPC. Arabe RTL, textes longs et limites horizontales vérifiés. Le français est le repli lorsqu'une clé étrangère manque ; un texte libre ultérieur reste opaque et supprime naturellement le marquage précédent.

Brotli régénéré et manifeste actualisé. Aucun nouveau moteur, style ou composant, aucune migration, aucun prix ou coût modifié. Les fenêtres métier restent hors périmètre ; la bannière de reconnexion est déjà traduite à sa création et n'est pas modifiée ici.

## Livraison

Lot préparé sur la branche `codex/i18n-sorties-refusees-20261116` au-dessus de #1018, dont la livraison complète doit précéder sa fusion. CI, fusion et vérification de production à terminer. Ni PJ connecté, ni téléphone physique, ni relecture linguistique native annoncés.

Lacunes prioritaires restant à auditer : noms/catégories des bâtiments, fenêtres de gestion et messages contextuels de commerce. Pas de pourcentage global sans audit exhaustif.
