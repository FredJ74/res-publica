Titre : Réduire les lectures redondantes et le volume des réponses Supabase

Les rafraîchissements électifs rechargeaient les portraits de tout l'annuaire ; la présence rechargeait toutes les photos et un cache vide ne freinait pas les lectures. Cette PR ajoute des projections ciblées, un cache partagé avec le même TTL et mutualise les deux lectures simultanées de réception d'invitations. Les réponses sauvegarde/présence sont limitées aux métadonnées consommées ; corps écrits et contrôles serveur restent intacts. La garde existante empêche les chevauchements, sans changer les cadences ni suspendre dons/vols/impacts en arrière-plan.

Refs #55. Branche indépendante ; aucun fichier métier immobilier, migration, donnée de joueur, abonnement ou Spend Cap modifié. Aucune fusion automatique.

Validation locale : 24 tests ciblés, 92 bancs client, 90 contre-épreuves, 5 tests calendrier et 69 tests du pilote local et 14 bancs PostgreSQL du workflow réussis ; syntaxe API et payload Vercel conformes. Un mock municipal utilise la nouvelle projection sans modification d'assertions. Contrôles globaux toujours 10/12 : Authority (28 RPC absentes du baseline archivé), Referential (3 empreintes divergentes), sans falsification.

Scénario fictif reproductible : 20 PJ, portraits 32 Kio, 2 PJ visibles, 20 ticks de 30 s, titres/photos uniquement : 19 748 370 → 657 570 octets JSON non compressés (−96,7 %), 30 GET dans les deux cas. Deux réceptions simultanées font 1 GET au lieu de 2. Ce ne sont ni des mesures de facturation ni une vérification en production. Supabase vivant/métriques indisponibles ; CI distante, Preview et bilan de quota restent à observer avant clôture.

Détails et procédure : `outils/audits/OPTIMISATION-SUPABASE-20261020.md`. Résultats : `outils/audits/RESULTATS-OPTIMISATION-SUPABASE-20261020.json`.

Complément de revue : corrige le retour tardif de présences de rue après entrée dans un bâtiment et la troncature des invitations regroupées, désormais paginées par clé. Les projections sont éprouvées sur le schéma archivé, pas sur Supabase vivant. Actions distantes et catalogue/droits/triggers/REST réels restent bloquants pour la fusion. Cette description est préparée dans le dépôt ; sa publication dans la PR #56 est bloquée par l'API GitHub.
