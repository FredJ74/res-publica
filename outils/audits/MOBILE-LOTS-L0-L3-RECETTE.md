# Mobile — contrat de recette L0 à L3, puis L6

Autorisation Fred, 06/11/2026 : implémenter L0–L3, une PR par lot, puis L6.
Codex est seul propriétaire de style.css, rue-centrale.css et de la coque plateau.html.
Claude poursuit Sovarka. Base initiale : main 728010c8 (audit #523 intégré).

## L0 : périmètre et critères

- Un même DOM et les mêmes commandes serveur ; aucune transaction ni compte réel.
- Formats : 375×667, 393×852, 412×915, 852×393, 768×1024 ; témoin bureau 1440×900.
- L1 : tous les accès du bandeau/personnage/personnes accessibles ; scène non nulle.
- L2 : image/zones liées, flèches inchangées, accès tactile et clavier sans double action.
- L3 : longues modales, fermeture, focus, clavier simulé et reprise au contexte.
- L6 : forum lisible et contrôleur existant utilisable au doigt, souris préservée.
- À chaque lot : screenshot 1440 identique au parent pour les composants inchangés,
  bancs ciblés puis vérifications transversales. Aucun Safari iOS réel déclaré testé.
- Actions serveur simulées uniquement ; recette authentifiée isolée reste distincte.

## Livraison

Branches/PR séparées et dépendantes ; jamais fusionner un lot si ses contrôles requis
ne passent pas. Aucun changement économique ou Supabase prévu. Les limites d'accès
à GitHub/Vercel doivent rester explicites. Les preuves de test seront ajoutées par lot.

## L1 — coque

Même DOM et mêmes gestionnaires d'ordres. Sous 1024 px : accès Personnage/Présents/Menu,
panneaux repliés, fond de fermeture et retour du focus ; le menu historique reste unique.
Banc `banc-mobile-coque.cjs` : 6/6, cinq formats + comparaison PNG stricte 1440 px
avec `728010c8`. Une erreur de stacking du menu sous le fond a été détectée par
un vrai clic et corrigée (pas de clic forcé). Aucun RPC ni compte dans ces tests.

## L2 — navigation et pièces

Banc coque 8/8 : accès tactile/clavier appelle une fois le gestionnaire de zone,
une zone retirée ne navigue pas ; onglets et sortie accessibles en paysage.
La liste utilise les zones déjà résolues par le moteur, donc respecte les vues
contextuelles (dont PSM) sans recopier les destinations. Données des quatre vues,
coordonnées et gestionnaires métier non modifiés. CSS mobile conserve le ratio de
l'image et isole les flèches des fenêtres superposées. Bureau 1440 pixel identique.

## L3 — fenêtres et clavier

10/10 tests locaux cumulatifs. La hauteur réduite à 350 px conserve une modale
scrollable, les champs à 16 px, le focus et le retour au déclencheur après fermeture
par le bouton existant. Le chat est contenu en paysage. Aucun Escape générique
ne supprime une modale : il active uniquement sa fermeture prévue.
Test réel Safari/clavier et reprise authentifiée non exécuté ; ne pas le confondre
avec le test visualViewport de Chromium. Bureau 1440 pixel identique.
