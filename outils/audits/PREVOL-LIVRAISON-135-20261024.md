# Prévol de livraison #135 — 24 octobre 2026

Lecture réelle du catalogue Supabase via le connecteur, sans acte métier ni donnée de personnage. Les cinq SELECT du prévol Codex ont été exécutés séparément pour conserver tous les résultats.

Résultats : 104 migrations pertinentes, 22 définitions de fonctions, 166 colonnes, 19 policies et 15 triggers. Les trois nouvelles portes police/occupation ne sont pas installées ; les sept portes d’organisations restent absentes. Le prêt national installé accepte uniquement `travaux`, 1 000–1 000 000 FR, durées 10/15/20/25/30 jours, présence en Banque Nationale. Dette et crédit sont déjà réunis ; la consommation et le financement intégré d’acquisition ne sont pas implémentés par cette porte.

Les coûts et produits bancaires existants doivent être retrouvés dans le dépôt ; ces contraintes constatées ne constituent pas une nouvelle décision de game design. Aucun taux ni durée nouveau n’est autorisé par ce relevé.

Répartition : Codex termine les commandes et tests locaux sur sa branche de stabilisation. L’agent de la session principale prend en charge le prévol vivant, la sélection/application des migrations vérifiées, la réextraction officielle, les PR/CI, la fusion et le contrôle du déploiement. Codex ne doit pas présenter un manque d’accès Supabase/Vercel/GraphQL comme une lacune de code bloquante ni modifier le baseline à la main.
