Raccordement partiel du parcours construction de l'issue #57, depuis `main` `baa9cb7`. Refs #57 ; **ne pas clôturer l'issue, ne pas fusionner ni déployer cet état**.

- Réutilisation du registre d'ordres et des dossiers existants : démarches, choix de permis, menus partagés des terrains, friche existante et informations de chantier/locaux.
- Conservation des surfaces et prix individuels ; correction du prix forfaitaire injecté dans un état non initialisé. Surface absente du terrain 6 de Port-Sainte-Marie signalée, achat refusé avant débit.
- Tirage/stabilité d'occupation dans le mécanisme client existant. Combat commun non raccordé : refus explicite sans débit, aucun second moteur.
- Extension préparée du moteur existant de transfert de matériaux : dons, tarifs propriétaire, reçus de rejeu, concurrence et rollback. Client sans deltas locaux. Migration locale uniquement, gardée et non appliquée. Paiement fractionnaire refusé avant mutation si colonnes entières.
- Prévol vivant en lecture seule et inventaire des obstacles de découpage, financement/cron et réception. Dépôt sous compromis arrêté avant tout frais tant que son serveur atomique manque.

Validation locale : 93/93 bancs client, 90/90 contre-épreuves, 14 groupes PostgreSQL jetables. Contrôles globaux **10/12**, Authority et Referential rouges, expliqués et non masqués. Audit des 15 parcelles non vert : une surface absente. Aucune vérification authentifiée Supabase ou en jeu.

Travaux encore nécessaires : atomicité permis/acquisitions/prêts, persistance partagée des occupations et combat PNJ, prélèvements/approvisionnement/cron atomiques, premier plan au dernier tiers et marqueur historique, réception physique et caisse/stock du bâtiment, baux. Cette PR est une sauvegarde de travail à garder en brouillon.

Rapport détaillé : `outils/audits/CONSTRUCTION-PARCOURS-57.md`. Résultats : `outils/audits/VERIFICATIONS-CONSTRUCTION-57.json`. Aucun fichier de la PR d'optimisation #56 incorporé, aucune donnée réelle modifiée.
