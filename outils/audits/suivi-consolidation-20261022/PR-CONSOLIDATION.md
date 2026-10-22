Consolidation des lots #62–#70 pour revue, sans mise en production

Cette branche rassemble les travaux existants des PR #56, #58 et #71 et les corrections indépendantes #63, #64, #67, #68, ainsi que les prérequis #69 et les archives #70. Aucun changement n'est fusionné dans main. Ce brouillon ne doit pas être intégré en bloc : la construction et les coffres sont incomplets, le prévol Supabase vivant n'est pas accessible et Authority/Referential restent rouges.

Les lots restent également sauvegardés sur leurs branches distinctes. Les migrations sont préparées et éprouvées sur PostgreSQL jetable, aucune n'est appliquée en production. Préserver l'ordre PR58 → PR71 et la garde successorale #69 → correction des titres #66.

Les validations et limites détaillées figurent dans outils/audits/CONSOLIDATION-20261022.md. Aucun nouveau mécanisme économique et aucune donnée réelle de joueur modifiée.
