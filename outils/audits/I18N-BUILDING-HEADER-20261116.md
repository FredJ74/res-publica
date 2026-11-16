# En-têtes de bâtiments — 16 novembre 2026

Neuf textes français fixes ou gabarits nouvellement raccordés, 72 valeurs étrangères ajoutées au catalogue plateau existant. Caisse en attente, solde, indisponibilité ; directeur en attente, PJ/PNJ, vacance, indisponibilité ; gestion de son armurerie et son infobulle. Les variables (noms, montants, monnaies) restent opaques et formatées exactement comme auparavant.

Les textes étaient écrits directement par enterBuilding. Leur absence de traduction est démontrée sous Chromium avec le catalogue chargé et la session anglaise : l’ancien rendu reste français. Le nouveau rendu exerce les neuf clés dans les neuf langues, y compris après une réponse différée, sans relancer enterBuilding ou ses lectures.

## Vérification

- Trois tests ciblés verts : anciennes ressources et français exacts, arbre du code métier identique à main hors écritures UI précisément filtrées ; tous les autres fichiers/fonctions préservés.
- 918 bascules principales sous Chromium, neuf langues, 320/390/1280 ; arabe RTL, droits propriétaire/commissaire, trois villes de Sovarka, directeur PJ/PNJ/vacant, erreurs et attente. Paramètres d’entrée/navigation et intentions du clic de gestion identiques à main ; zéro RPC/fetch/PA supplémentaire par bascule ; saisie, sélection, focus, progression et position inchangés. Texte malveillant traité comme texte, pas comme HTML. Repli après changement de solde vérifié sans ancien français mis en cache.
- 27 tests i18n existants verts ; 418 tests test-*.mjs verts sur main et branche avec les mêmes dépendances (pglast/Acorn installés). Les premiers échecs dus aux dépendances locales absentes ont été résolus sans changer les tests.
- Archives Brotli déterministes vérifiées, sources lisibles conservées ; aucun nouveau moteur. Plafond de déploiement inchangé, environ 277 Mo / 330 Mo.

## Périmètre et suites

Usines de Starovka et Krasnov, usines/entrepôts communs, commissariats selon autorisation serveur et armurerie du propriétaire. Aucun changement d’accès, de prix, de PA, de donnée joueur, de RPC ou de serveur. Pas de refonte graphique. PR #924 et #1015/#1016 examinées, travaux déjà livrés non refaits ; PR #993/#994 Ignat exclues.

Les noms/catégories des bâtiments et le reste des fenêtres de gestion ne sont pas annoncés traduits par ce lot. Les prochains textes prioritaires sont les refus dynamiques à l’entrée (détention/fermeture), distincts des corps fixes déjà traduits. Aucun pourcentage global n’est annoncé. Pas de PJ connecté, de téléphone physique ou de relecture native vérifiés.

Livraison : tests locaux réussis, PR/CI/fusion/production à poursuivre. Les preuves finales préciseront les ressources réellement servies.
