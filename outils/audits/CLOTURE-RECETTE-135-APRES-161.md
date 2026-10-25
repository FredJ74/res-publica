# #135 — Reprise de clôture après la PR #161

25 octobre 2026. **Recette en jeu non terminée : aucun personnage connecté et vérifié par cette session.** Aucune nouvelle règle de jeu ou migration.

## Livraison retrouvée

Main distant vérifié par Git : `5dcdc476ed9f57d49c9a0a2cf21a15bb782b15a5`, « permis accessible et tests Chromium fiabilisés ». Le correctif du permis, l'installation explicite d'Acorn et les tests Chromium sont présents. La branche de recette reprend cette version exacte ; les évolutions de Claude sur les ambassades et le Bureau de l'Emploi restent intactes. Aucun ancien handler, cache ou script n'est réintroduit.

Les cinq contrôles GitHub de la PR #161 réussis sont un résultat communiqué par le responsable, non une consultation Actions effectuée ici. Les tests acquis ne sont pas recommencés : 88 du pilote, 105 bancs clients, 324 assertions pour les cinq terrains et 56 sur les permis. Les adaptateurs terrain/banque, les commandes de construction et les trois bancs SQL sont identiques à ceux déjà éprouvés. Les transactions ne sont ni modifiées ni réexécutées sur des personnages réels.

## Vercel : ce qui est vérifié et ce qui ne l'est pas

- La configuration du dépôt conserve le déploiement de `main`.
- Le filtre `vercel-ignore-build.cjs`, exécuté sur le checkout exact de `5dcdc47` et son parent `87f39bb`, **n'ignore pas le build** du correctif. Ce test est local ; il ne constate aucune exécution Vercel.
- Le HTML du dépôt attend `plateau-justice-economie.js?v=permis135-fix-20261025` et le `data.js` actuel de main. Le manifeste `recette-immobilier-135-20261025/LIVRAISON-161-ATTENDUE.json` fournit les URL et empreintes **attendues**, toutes marquées non observées en production.
- L'image locale commune des cinq terrains est `images/terrain-a-vendre-republic.webp`, WebP 1 536 × 1 024. Aucune image n'est retouchée.
- La requête HTTPS réelle vers `https://res-publica.vercel.app/` échoue pendant le tunnel proxy avec un refus 403. Aucun statut applicatif, HTML, JavaScript ni image n'a été obtenu depuis le déploiement.

**État exact de Vercel : non vérifiable depuis cet environnement.** Le refus du proxy n'est pas attribué à Vercel ; aucune panne du déploiement n'est démontrée. Un statut GitHub vert ne remplace pas la comparaison des ressources servies.

## Workflow authentifié : tentative et permissions

Le workflow existant `.github/workflows/beta-testeur-luthecia.yml` réserve son job à `main`, utilise l'environnement `luthecia-e2e`, sérialise les campagnes et limite le job à 45 minutes. Les permissions du jeton du job sont `contents: read`. Le mode manuel `consultation_seule` utilise exclusivement les trois secrets historiques d'Arnie. Le droit de déclencher appartient au compte GitHub appelant ; il ne peut pas être déduit des seules permissions du job.

La tentative réelle avec `gh workflow run … --ref main -f mode=consultation_seule` est refusée dès la lecture des métadonnées du workflow sur `api.github.com`. Aucun déclenchement n'est confirmé. Ce refus ne permet pas de diagnostiquer un défaut des secrets ou du compte Arnie. Aucun outil alternatif GitHub/Vercel ou navigateur distant n'est exposé ici. Le transport Git fonctionne, mais un push n'est pas un déclenchement manuel autorisé : les événements et gardes du workflow ne sont pas modifiés pour contourner cette limite. Aucun polling répété de l'API n'est effectué.

### Intervention minimale déjà demandée

1. Ouvrir [le workflow « Parcours joueur autorise de Luthecia »](https://github.com/FredJ74/res-publica/actions/workflows/beta-testeur-luthecia.yml).
2. Cliquer **Run workflow** ; choisir **Branch: main**, **mode: consultation_seule**.
3. Cliquer une seule fois sur **Run workflow**. Aucun compte, mot de passe, secret ou autorisation JSON à créer/modifier.

Le lien de l'exécution permet de la désigner sans fournir d'identifiant de joueur. Le rapport est dans l'artefact privé **`luthecia-joueur-<run_id>`**, sur la page de cette exécution, y compris si le job est rouge. Il peut contenir `rapport.json` et des captures de scène en cas d'erreur. La rétention actuelle est de trois jours. Ne pas transmettre de trace de session ou de secret.

Un job rouge n'est pas, seul, la preuve d'un échec de connexion : le pilote rend encore le code 2 après une simple consultation initiale, car la recette complète n'est pas couverte. Il faut lire `statut`, `prevolAutomatique`, `protectionsConsultation`, `visites`, `blocages` et les erreurs. `PREVOL_LOCAL_CONFORME_AUTHENTIFICATION_NON_TESTEE` n'atteste jamais une connexion réelle.

## Limite impérative du mode Arnie

Le compte et l'UID doivent être vérifiés par le prévol et la réponse serveur `mon_personnage`. Les finances, caractéristiques, possessions et progression sont protégées par empreinte. Aucun achat, signature, prêt, dépôt de permis, lancement, réception, ordre ou sauvegarde n'est autorisé avec Arnie.

Le pilote actuel reste limité à **la scène déjà occupée**. Ses déplacements sont bloqués parce que l'entrée dans une pièce peut déclencher une sauvegarde générale et que les effets serveur des déplacements n'ont pas été attestés ici. Même une connexion et une consultation initiale réussies ne prouveront donc pas les cinq visites ou les cinq formulaires de production. Aucun état local n'est injecté pour déplacer artificiellement Arnie. Le bouton d'achat engage un dépôt : il ne doit pas être utilisé comme une consultation.

## Couverture à conserver séparément

| Parcours | Preuve acquise | Limite réelle restante |
| --- | --- | --- |
| Cinq terrains, superficies/prix, menus et images | Sources et Chromium local ; caractéristiques distinctes conservées | Scènes et ressources réellement servies non observées ici |
| Acquisition et clauses du compromis | PostgreSQL jetable et formulaires locaux | Aucune signature ou transaction réelle avec Arnie |
| Banque nationale | Crédit/dette et rejeux atomiques éprouvés en isolation ; formulaire et guichet testés | Aucune opération bancaire de production autorisée |
| Permis | 56 assertions isolées, instruction intégrée au parcours de 324 assertions | Aucun dépôt réel avec Arnie |
| Matériaux, délais, appels 35/35/30, réception et persistance | Parcours isolé des cinq terrains, pertes de réponse, concurrence, rollback et relecture | Aucune construction ni réception réelle exécutée pour la recette |

Les contrôles globaux antérieurs restent consignés, sans remise à zéro ou changement d'empreinte. Aucun chantier indépendant n'est ouvert pour les masquer. Le dépôt contient le code intégré ; l'authentification réelle, les ressources Vercel et les cinq visites ne sont pas certifiées. **Ne pas fermer #135 sur cette base.**
