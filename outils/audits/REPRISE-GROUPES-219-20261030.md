# #219 — Raccordements du 30 octobre : non intégrable

Branche `codex/groupes-universels-20261028`, code testé `bc6cbd5f`, main
`aab0cfb7` intégré par `918c41d2`. PR #246 intacte ; suppression #252 préservée.

## Code effectivement raccordé

- `27dcbb60` : trois corps vivants lus dans le commentaire 6509677067 de #219,
  empreintes exactes concordantes ; même navigation/géométrie pour les replis
  militaires mixtes et PNJ autonomes, sans téléportation à la caserne ni faux PJ.
- `bafabc43` : poursuite sans clic adverse par la doctrine existante, rattrapage
  du moteur par `cron-minuit`, erreurs visibles ; aucun nouveau minuteur. Le
  rattrapage est quotidien, **pas une garantie d’exécution à la 90e seconde**.
  Une évacuation mutuelle n’annonce plus un anéantissement fictif. Rendu de rue
  corrigé après repli, y compris lorsque ville et bâtiment nul ne changent pas.
- `c824d343` : trois actes camion historiques raccordés au groupe canonique,
  groupes passagers complets, refus aval annulant les écritures, reçus liés
  à l’acteur et aux paramètres. Coût existant de 2 PA/PJ et priorités conservés.
- `bc6cbd5f` : provenance PNJ dérivée des mouvements/déposes, position personnelle
  dans la lecture commune existante, restauration des quatre vues PSM depuis
  le serveur. Pas de table de position ni de synchronisation périodique ajoutée.
  Les nulls sont conservés ; finances/santé/inventaire ne sont pas réécrits.

## Tests et limites

**337/337 SQL jetables** sur les trois corps communiqués, répétés ; **132/132
bancs clients**, dont Chromium local et huit cas de chargement/provenance.
Les 317 cas antérieurs restent présents, exécutés avant les nouveaux compléments ;
les vingt cas supplémentaires exercent leurs installations successives. Ce n’est
pas la preuve que toute la production ou tous les anciens contrats sont conformes.

Contre-épreuves sur les mêmes 337 cas : faux repli sans mouvement → 2 échecs ;
embarquement du seul chef → 3 ; provenance PNJ oubliée → 1. Tests de deux vraies
connexions concurrentes sur PostgreSQL jetable, reçus uniques et refus aval.
Les données sont fictives ; certains décors sont committés pour la concurrence,
les autres cas annulés. Aucune connexion authentifiée Supabase de joueur réel.
Le prédicat d’asile est une dépendance de décor ; son garde vivant est conservé.

Globaux : **5/12**, comme main aab0cfb7 contrôlé séparément. Workflow vert ;
classification, fidélité du baseline, Authority, Referential, fonctions,
assemblage et reconstruction rouges. Authority : 123 RPC absentes du baseline
contre 112 sur main (onze préparations propres à #219). Aucune référence modifiée.

Un remplacement d’étape CI a été rejeté par l’approbation automatique ; l’étape
existante est conservée et la nouvelle suite ajoutée séparément. Les logs bruts
sont compressés dans `preuves-groupes-219-raccordements-20261030/` avec leur synthèse.
La première contre-épreuve du repli avait échoué à compiler à cause de noms
manquants de paramètres : corrigée, puis vraies détections de régression obtenues.

## Migrations préparées, aucune appliquée

Après les compléments jusqu’à `20261029223600`, dans cet ordre :

1. `20261029223700_batailles_repli_navigation_commune.sql`
2. `20261029223800_navigation_geometrie_commune_et_replis_pnj.sql`
3. `20261029223900_batailles_progression_serveur_existante.sql`
4. `20261030001000_camions_groupes_et_refus_atomiques.sql`
5. `20261030001100_navigation_provenance_pnj_et_lecture_commune.sql`

Prévol réel obligatoire ; versions/ACL/dépendances à rapprocher avant activation.
Les cinq compléments sont testés en PostgreSQL jetable et sous 12 500 caractères.
Le prévol SQL versionné demande également les corps camion, doctrine et justice.

## Reste nécessaire pour rendre #219 intégrable

- Ouverture universelle d’agression et combat civil : encore incomplets ; ne pas
  confondre les rounds militaires/policiers testés avec ce parcours complet.
- PNJ unique « squatteurs » : règle consignée, aucun groupe artificiel ni second
  jet de crime. Profils citoyen sans VOL/PER, résistance distincte non chiffrée :
  valeurs ou profils validés toujours nécessaires. Ne pas inventer de valeurs.
- Conséquences judiciaires complètes : trois corps vivants demandés et non reçus :
  `justice_executer_condamnation_soi(text)`,
  `detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)`,
  `crime_neutraliser(text,text,integer)`. Ils sont nécessaires pour préserver les
  conditions/écrous/sanctions, pas pour effectuer un second tirage après combat.
  Le baseline signale une dette de prélèvement d’amendes ; aucun débit ou retrait
  de poste client fictif rétabli. #235 récupérée ne contient pas ce moteur.
- Vérifications Supabase vivantes restantes : catalogue, droits, triggers, anciens
  écrivains réellement déployés, calendrier disponible et réception serveur des
  fonctions. Les trois corps fournis ne démontrent pas ces autres points.
- Revue d’intégration et tests authentifiés isolés, sans joueurs réels.

**CHANTIER NON TERMINÉ. Aucun joueur réel modifié ; aucune fusion, migration
appliquée ou production déployée.** Les lots ci-dessus sont codés et testés,
ils ne justifient pas à eux seuls la promotion de la PR #219.
