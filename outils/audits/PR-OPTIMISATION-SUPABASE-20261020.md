Les navigateurs inactifs ne sondent plus Supabase. Les lecteurs existants sont déclenchés par la connexion, la reconnexion ou une interaction, avec contrôle du contexte et attente des requêtes déjà engagées. Les sauvegardes différées sont figées à l’action. Aucun moteur métier parallèle.

**PR non fusionnable en l’état.** La migration de présence est préparée seulement. Le contre-exemple PostgreSQL démontre que le moteur d’agression archivé diffère encore l’effet sur la victime au navigateur ; l’autorité atomique de tous les ordres n’est donc pas démontrée. Les définitions vivantes de déplacement et les traitements autonomes restent à vérifier. Aucun déploiement ni modification de données de production.

Validation locale : 46 tests ciblés, 94/94 bancs client, 90/90 contre-épreuves, 5/5 projections PostgreSQL et banc PostgreSQL des présences réussis. Le contre-exemple agression reste rouge et bloquant. Contrôles globaux : 10/12, Authority 29 RPC absentes du baseline (dont la nouvelle RPC préparée), Referential trois empreintes divergentes, sans référence falsifiée. Chromium utilise un serveur simulé, pas une session de production.

Les cinq commits concurrents de la branche ont été intégrés sans force. La baisse historique de 96,7 % concerne une fixture, jamais le trafic facturé. Mesures réelles avant/après à effectuer après autorisation de déploiement.

Rapport et préconditions : `outils/audits/REALITES-PR56-20261021.md`. Résultats : `outils/audits/RESULTATS-REALITES-PR56-20261021.json`.
