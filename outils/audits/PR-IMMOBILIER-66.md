Le notaire ne disposait pas d'un acte commun séparant fonds et murs. Cette branche ajoute les offres, le catalogue et la signature atomique des deux droits, avec priorité locataire de 72 heures, notification unique, reprise après réponse perdue et conservation des baux. Les paiements et transferts réutilisent les moteurs existants.

Dépendance empilée : PR #58, base `cda39528ead0df92b5cedfe441ca0898fcbf874b`. À revoir avant retarget vers main. Financement acquisition #65 encore non livré ; aucun nouveau prêt ou condition économique inventé. Clôture #66 non revendiquée.

Validation locale : 95/95 bancs client, 90/90 contre-épreuves, 15/15 bancs PostgreSQL (immobilier relancé à 92 scénarios), 19/19 nouveaux tests client/Chromium, 69/69 fixtures e2e, 5/5 calendrier, syntaxe des 23 API et migrations. Contrôles globaux **10/12** : Authority et Referential restent rouges et documentés.

Aucune migration appliquée, aucune donnée de production modifiée, aucun test authentifié Supabase effectué. Le prévol vivant et les dépendances doivent être levés avant toute fusion/déploiement. Voir `outils/audits/IMMOBILIER-66.md` et `VERIFICATIONS-IMMOBILIER-66.json` pour les limites et la procédure de retour arrière. Ne pas fermer l'issue automatiquement.
