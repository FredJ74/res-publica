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
