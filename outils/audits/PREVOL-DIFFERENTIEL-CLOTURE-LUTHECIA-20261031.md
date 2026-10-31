# Clôture Luthécia — rapprochement différentiel contrôlé du 31 octobre 2026

## Statut de livraison
Critère du game designer : **toutes les fonctionnalités arrêtées pour Luthécia déployées** ; les PJ bêta-testeurs assurent la recette fonctionnelle en jeu. Le présent prévol est une photographie de vérifications techniques, pas une attestation de clôture.

- #275 caisses des 21 bâtiments communaux : fusionnée/déployée.
- #280 arrondis et lisibilité : fusionnée, Vercel `READY` sur `5082d6e4`.
- #281 genre des nouveaux PJ : **livrée côté Supabase** par migration appliquée avec succès le 31/10, enregistrée sous la version effective `20261031113025`. Les deux fonctions `personnages_vue_inserer` et `pnj_contexte_public` ont été relues après application : respectivement garde `genre_requis` et contexte `v_genre`. Cinq workflows GitHub au vert ; PR fusionnée `d214ea5a`. Vercel en construction lors de la dernière lecture, sa mise en ligne reste à constater `READY`.
- #219 groupes universels / combats / navigation / migration et prévol de reconstruction : **non intégrée**, relève de Codex.
- #278 i18n pilote non activée : prévue après clôture de Luthécia.
- #263 journal d'exécution nocturne : PR toujours ouverte ; à considérer pour une livraison indépendante après vérification.

## Source de vérité : registre Supabase
Requêtes exécutées uniquement en lecture seule. Une requête sur `supabase_migrations.schema_migrations` identifie **24 versions citées dans RELAIS.md qui ne sont pas présentes sous ces numéros exacts** :

`20261030210000`, `20261030211000`, `20261030212000`, `20261030200000`, `20261030100000`, `20261030110000`,
`20261029210000`, `20261029220000`, `20261029222000`, `20261029223000`, `20261029224000`, `20261029203500`, `20261029200000`, `20261029190000`, `20261029190100`, `20261029180000`, `20261029181000`, `20261029160000`,
`20261028210000`, `20261028210500`, `20261028210600`, `20261028210700`, `20261028210800`, `20261028210900`.

**Attention : l'absence du numéro n'est pas la preuve d'une fonctionnalité absente.** La base utilise des versions réhorodatées par l'outil de migration. Il est interdit d'appliquer ces 24 vieux fichiers par simple comparaison des numéros.

### Présence des corps serveur vérifiée
Ces fonctions existent effectivement sur Supabase :
- `local_louer`, `minuit_amendes`, `amende_imposer_interne`, `banque_virement`, `terrain_acquisition_commande`, `caisse_commissariat_lire`, `pnj_contexte_public`.
- `acheter_a_entrepot` : deux surcharges ; `deposer_helvetia` et `retirer_helvetia` : deux surcharges chacune.
- `inventaire_sauver_revision` et `minuit_decouverte_crimes` toujours présents : vérifier les privilèges exacts et la logique installée avant toute fermeture d'ancienne porte.

La présence ne démontre **ni l'identité du corps**, ni les droits d'exécution, ni la conformité du scénario. Des prévols précis doivent comparer `pg_get_functiondef`, les arguments, privilèges, dépendances et les tests.

## Chantiers à faire statuer pour la livraison de Luthécia
1. **#219 et dépendances** : intégration universelle groupes, vigiles, police, armée, squatteurs, radio, combattants mixtes, inventaire, transports ; reconstruire la base fidèle et prévoler les migrations de Codex.
2. **Protection de l'argent et banque** : rapprochement des changements Helvetia, des régularisations prévues et des gardes de fiche avec les corps de production (ne jamais appliquer deux fois une compensation). Anomalie de caisse Helvetia #267 à diagnostiquer.
3. **Terrain / immobilier / location / logement social / municipalités** : comparer les fonctions installées avec le parcours complet validé et les versions antérieures signalées dans RELAIS ; ne pas confondre traces historiques et travail actuel.
4. **Justice, amendes, nuits** : vérifier que la collecte, les dettes et les journaux de cron tournent selon la règle actuelle ; PR #263 encore ouverte et compatible sans SQL.
5. **Coffres et successions** : état des fonctionnalités #69/#95 et des protections à rapprocher de la base vivante.
6. **Douanes** : PR #215 historique non terminée ; séparer les contrôles entre villes de l'extension « voyage entre empires » qui a été explicitement reportée.
7. **P0 source de vérité serveur** : réévaluer l'audit `AUDIT_UNE_SEULE_VERITE.md` à la lumière des changements déjà installés, puis recenser uniquement les écritures client réellement encore autorisées.

## Périmètre volontairement différé
- Internationalisation intégrale et duplication des autres empires.
- Voyage entre empires, naturalisation et transfert inter-empires ; incompatibles avec la version Luthécia seule tant que les empires ne sont pas ouverts.
- Refonte esthétique générale #143, sauf défaut de lisibilité bloquant.

## Discipline de livraison
Chaque ligne doit être passée à un statut prouvé : **déployé**, **remplacé par version attestée**, **à déployer**, **reporté par décision** ou **bloqué**. Une PR WIP n'est ni une nouvelle fonctionnalité ni une preuve de retard à elle seule. Ne pas fusionner les vieilles PR empilées ou réappliquer les migrations sans un diff contre `main` et un prévol du catalogue Supabase.
