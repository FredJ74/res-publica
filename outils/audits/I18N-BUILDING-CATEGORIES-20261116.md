# Catégories des bâtiments — 16 novembre 2026

Audit du rendu réel : `enterBuilding` écrit directement `b.cat` dans `bat-cat` ; `minimapCard` concatène la même valeur dans la carte. Aucune ressource n'est marquée pour ces éléments et la bascule de langue ne les met pas à jour. Le jeu expose 58 catégories distinctes dans WORLD, dans les quatre empires. Le français conserve notamment ses variantes historiques accentuées ou non.

53 textes / 424 traductions étrangères sont ajoutés au catalogue navigation. Cinq catégories réutilisent 40 valeurs déjà présentes : Sante (characterSheet.health), Santé (commerceMenu.effectHp), Organisations (plateau.organizations), Économie (plateau.rulesEconomy), Justice (sovarkaJustice.tJustice). La ressource existante Commerce/Shop concerne une boutique : sa traduction n'est pas réutilisée pour la catégorie générale Commerce/Trade. L'indication Accès restreint réutilise en plus toastTitles.restrictedAccess (huit valeurs), sans changer son prédicat.

Les méthodes de présentation du module navigation marquent des spans `data-i18n` ; le moteur commun traduit et rafraîchit sans relancer la carte ou l'entrée du bâtiment. Aucun deuxième moteur ni callback métier ajouté. Les noms propres, noms des cultes, identifiants et attributs d'événement restent identiques. Les cognats légitimes (Finance, Religion, Transport, Port, Education, Services, etc., selon la langue) sont conservés : une valeur identique au français n'est pas remplacée par une fausse traduction.

## Tests

Trois tests ciblés : catalogue complet, réutilisation exacte, français et noms propres préservés ; fichier de navigation identique après retrait des seules écritures UI, données/coûts/permissions/paramètres inchangés ; Chromium sur les vrais contextes WORLD et les vrais renderMinimap/minimapCard, plus le fragment réel de l'en-tête de enterBuilding. 1 566 bascules sur les 58 catégories, neuf langues, 320/390/1280, arabe RTL, état/saisie/sélection/focus/défilement conservés sans requête métier. Comparaison avec le rendu de référence : noms, occupants, icônes, classes, attributs onclick/survol et identifiants identiques ; le clic normal transmet la même intention une seule fois.

Le catalogue courant n'a aucun `b.locked` : le flag de verrou est simulé explicitement dans le décor de test puis restauré, sans modifier de fichier de données. Ce scénario vérifie l'indication traduite et son état inchangé. Repli français après une clé allemande absente, puis catégorie inconnue opaque sans ancien marquage. Aucun test authentifié ou téléphone physique annoncé.

Les dix tests des catégories/en-têtes/refus de sortie passent ensemble, notamment les 1 080 bascules des en-têtes et 459 des refus déjà livrés ; ils ne sont pas recodés. Brotli et manifeste régénérés.

## Autres lacunes auditées et périmètres exclus

Les compteurs personne/personnes de la liste restent aussi hors lot. Les noms de bâtiments restent écrits directement dans `bat-nom` et les cartes ; distinguer les noms propres à conserver des noms génériques à traduire dans un lot ultérieur. Les pièces disposent déjà de leur propre système et ne sont pas reprises ici.

`plateau-commerce-pj.js`, panneau Commerce Premium : titre, annonce prochainement, présentation 3 activités/10 articles/personnalisation, transmission du droit, boutons 4,99 € et 0,99 €, code promotionnel et placeholder restent des chaînes françaises directes. Les autres écrans commerciaux emploient déjà largement commercepj/data-i18n et le catalogue économique : ne pas les retraduire en bloc. Ce panneau est seulement audité ici ; aucune activation, tarif ou règle économique modifié.

Les chantiers #1020 (survie) et #1029/#1031 (décors de Starovka) sont exclus. Le dépôt temporaire de trois PNG dans main avait fait échouer le test historique de Starovka ; la conversion #1031 est désormais fusionnée et intégrée sans modification de ses images ni assouplissement du test. Le nouveau texte du bureau du port #1029 est également préservé.

PR #1032 fusionnée en cf0f218eb27a39acbc29d61bd77d7c5daa1a8eae après livraison vérifiée de #1030 et 51 contrôles CI réussis. Production dpl_2Xmkzj65Tv9Ptc5JTnipQHfe3xUT READY ; alias res-publica.vercel.app et commit exact confirmés. Dix-neuf fichiers publics identiques au dépôt : quatorze tests / 3 375 bascules des catégories, du goulag et des en-têtes/refus déjà livrés rejoués verts sur ces fichiers. Les 86 catalogues sont décompressés nativement par Chromium depuis cet alias, octet pour octet conformes. Le banc général du commit de correction 7f229f59 est aussi passé sur main.

Les 418 test-*.mjs passent sur l’intégration. Les 386 bancs client locaux ont été parcourus : 378 verts immédiatement, six échecs de démarrage dus au disque plein, un ancien test des caisses corrigé dans #1030 et un délai local sur les fenêtres d’accès réservé. Les huit reprises passent (24 sous-tests) ; le dernier banc passe isolément en 112,6 s sans changement de délai/assertion. Les journaux initiaux restent conservés. Le workflow dédié fournit désormais Playwright à toutes ses étapes navigateur ; aucune exigence de test retirée.

Le démarrage du plateau est abonné à DOMContentLoaded : le catalogue navigation et le moteur sont chargés avant le premier rendu. L’en-tête HTML complet, bouton Sortir compris, et le débordement de toutes les cartes ont été vérifiés. Les nouvelles copies de portraits de main sont préservées. Pas de pourcentage global. Non vérifiés : session PJ, téléphone physique et relecture native.
