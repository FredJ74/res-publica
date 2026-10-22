# Revue limitée — #95, préparation seulement

Les migrations `20261022184500` et `20261022184501` ferment l'UPDATE direct, autorisent les réponses d'héritiers sous verrou et vérifient la photographie initiale (identité, montants bancaires, fiscalité, parts et titres). 21 assertions PostgreSQL jetables ; ancienne attaque reproduite avant correctif, nouveaux refus vérifiés après. Le client transmet une intention et le cron compare son état de départ.

**Ne pas fusionner/activer sur le seul succès de ces tests.** Les dossiers historiques éventuellement altérés et les définitions/permissions vivantes doivent être examinés. La construction testamentaire initiale reste partiellement cliente ; la réservation/extinction de toutes les contreparties financières entre ouverture et suppression différée n'est pas démontrée. Les modifications de coffres sont sur la branche d'intégration et ont leurs propres dépendances ; elles ne sont pas comprises dans cette branche isolée.

Aucun compte réel ni migration de production utilisé. API GitHub GraphQL/REST et accès Supabase/Vercel refusés dans l'environnement : branche poussée, PR non créée. Le prévol puis les tests authentifiés isolés doivent être repris par un agent disposant des accès, pas par le game designer. Voir le rapport de branche d'intégration `CLOTURE-TECHNIQUE-SUITE-20261022.md` pour les résultats et limites transversales.
