# Déploiements sobres et contrôles — 18 octobre 2026

## Politique versionnée

Le déploiement automatique Git de `main` reste conservé. **État versionné vérifié le 28/10 :** `vercel.json` autorise les déploiements Git de `main` et désactive ceux des autres branches (`deploymentEnabled: {"*": false, "main": true}`). La mention antérieure de Preview automatiques conservées ne correspondait donc plus à cette configuration. Les réglages distants et les possibilités de Preview manuelles ne sont pas observables ici ; ce chantier ne les modifie pas. Aucun forfait n'est modifié. Aucun workflow du dépôt n'appelle `vercel deploy`, un Deploy Hook ou l'API de déploiement. Le constructeur `@vercel/node` du banc est uniquement local : il compile des fixtures, sans publier.

`vercel.json` raccorde `ignoreCommand` à `node vercel-ignore-build.cjs`. Selon le contrat Vercel, sortie **0 = ignorer**, **1 = construire**. Le script est disponible à la racine, sans dépendance npm. Il n'ignore que les changements constitués exclusivement de Markdown racine ou sous `outils/`, `historique/`, `baseline/`, déjà exclus du payload. Les autres documents restent volontairement conservateurs.

La comparaison porte sur **tout le diff depuis `VERCEL_GIT_PREVIOUS_SHA` jusqu'au commit courant**, pas seulement le dernier commit. Un commit de documentation après un commit de code non déployé ne masque donc pas ce code. Le SHA courant doit correspondre au checkout. Premier déploiement, SHA absent, clone incomplet, historique réécrit, erreur Git, diff vide ou exclusion documentaire incertaine : construire. Suppression, renommage, configuration, SQL, assets, API et fichiers inconnus : construire. La même règle s'applique à main et aux Preview.

Ce filtre évite des compilations ; il ne désactive pas l'intégration Git et ne garantit pas que Vercel ne comptabilise aucune création de déploiement ou exécution de l'étape d'ignorance. Sa prise en compte réelle dépend aussi des réglages distants, non observables ici. Ce n'est **pas une preuve de résolution d'un `build-rate-limit`**.

## Déclencheurs et économie des exécutions

- Les workflows de cohérence et payload tournent sur PR vers main et sur main. Le contrôle post-intégration reste utile : il ne teste pas forcément le même commit que la PR.
- Les deux petits workflows calendrier ciblent des chemins spécifiques et conservent leurs noms de contrôles existants, afin de ne pas casser une protection de branche inconnue. Le calendrier est désormais aussi testé dans le workflow de cohérence lors d'un push sur main.
- Les quatre workflows de validation annulent seulement leurs anciennes exécutions **d'une même PR**. Ils ne s'annulent pas entre workflows et n'annulent pas les exécutions de main. Cela économise GitHub Actions, **pas les builds Vercel**, qui sont indépendants.
- Le workflow d'ajustement saisonnier du cron ne pousse qu'en présence d'un diff ; son exécution quotidienne sans diff ne provoque pas de commit. Sa logique métier n'est pas modifiée.
- `.vercelignore` et la garde de 330 Mo existaient déjà ; aucun second mécanisme de payload n'a été ajouté.

Pour les travaux futurs : commits locaux cohérents, pushes regroupés aux points de sauvegarde utiles ; pas de push supplémentaire uniquement pour tester Vercel. Une Preview nécessaire à une PR reste légitime. Ne pas ajouter un déploiement CLI à côté de l'intégration Git.

## Contrôles avant intégration

Le pipeline existant est réutilisé, sans nouveau workflow : syntaxe API rapide sous Node sur Linux, bancs client dont conditionnement réel par `@vercel/node`, achats et réception sur PostgreSQL jetable. La garde de payload reste séparée. Les contrôles calendrier dédiés restent sur PR et tournent aussi sur main. Le banc `banc-deploiement-sobre.cjs` éprouve le filtre sur de vrais dépôts Git temporaires, ses codes de sortie, la syntaxe et les refus du vérificateur de référentiels.

Commandes locales :

```sh
npm ci --prefix outils/vercel --no-audit --no-fund
python3 outils/bancs/verifier-syntaxe-api.py
node --test outils/bancs/banc-deploiement-sobre.cjs outils/bancs/test-*.mjs
python3 outils/payload-vercel.py --garde
python3 outils/bancs/controler-client.py --rapport /tmp/hg-bancs
```

Ces contrôles n'accèdent pas à la production. Le vérificateur syntaxique utilise JavaScriptCore lorsqu'il est disponible, sinon Node analyse les modules originaux sans charger leurs imports. Le banc de bundle reste nécessaire pour vérifier leur conditionnement.

GitHub Actions ne bloque **pas automatiquement** le déploiement Git Vercel. Sans observer/modifier les protections de branche ou l'intégration distante, on ne peut pas prétendre avoir instauré un verrou de mise en production. La PR doit rester non fusionnée tant que les contrôles pertinents ne sont pas examinés. Un échec de syntaxe, bundle ou test est un échec code ; Authority/Referential concernent aussi la photographie Supabase ; `build-rate-limit` est une limite fournisseur, pas un verdict de test.

## Authority et Referential

Les attentes restent valides : les RPC doivent exister avec les bonnes signatures, et les miroirs doivent être confrontés à leurs sources. Un SQL préparé ne prouve pas une fonction déployée.

- **Authority** reste rouge : `inventaire_reception_etat`, `inventaire_reclamer_livraison`, `inventaire_sauver_revision`, `tracts_electoraux_distribuer_collectif` absentes du baseline. Les trois premières figurent dans la migration préparée `migrations/20261016131932_reception_objets_atomique.sql` ; la dernière dans `historique/sql-hors-registre/tractage_collectif_stade_20261014.sql`. Ni le baseline ni le registre vivant ne sont remplacés par ces sources.
- **Referential** reste rouge sur les mesures de `ordres_couts` (calcul actuel `79ecb2f9d4bf71f5`, déclaration `20e52d8f9bbe8e3f`) et `postes_nommes_regles` (`694f117ace57b0b1` contre `6c0c7aa0d29bf852`). Les mesures datées et leurs observations serveur restent intactes.
- Défaut confirmé du **diagnostic** : quand le générateur dérivait, un `continue` empêchait l'examen du miroir puis déclarait ses clés de divergence inexistantes. Le contrôle examine maintenant aussi la mesure historique et conserve l'échec de dérive. Les trois faux messages disparaissent, sans rendre le contrôle vert. Les cas dérive, clé réellement orpheline, divergence non déclarée, divergence disparue et générateur muet sont testés et restent en échec.

La lecture du catalogue vivant et des empreintes réelles reste nécessaire avant une réconciliation. Aucune migration n'est exécutée par ces changements.

## Audit et validation de cette intervention

Faits observés : main de départ `8db174f8b85c32a91d5d76d6907c20ef38c26fa3`, aucun changement local initial. Son déploiement réussi est **confirmé par le propriétaire**, pas observé par cette session. Aucun journal de quota, inventaire des déploiements ni réglage distant Vercel accessible. L'API GitHub et le schéma officiel Vercel sont refusés par le proxy HTTPS (403) ; Git fetch fonctionne. Aucun token Vercel/Supabase disponible. La fréquence des pushes et Preview est une hypothèse plausible de consommation du quota, **pas la cause racine prouvée** du blocage.

Résultats locaux : **74/74 bancs client**, dont bundle des API ; **22/22 tests ciblés de déploiement/diagnostic** ; **5/5 tests calendrier** ; **90/90 contre-épreuves** ; **23 modules API** syntaxiquement valides ; payload **313,1 Mo / 330 Mo**. Contrôle global **10/12**, Authority et Referential rouges pour les raisons précises ci-dessus. Aucun déploiement de test déclenché par commande CLI. La sauvegarde de la branche pour la PR peut naturellement créer sa Preview via l'intégration Git ; aucun push de test supplémentaire n'est requis.

Les quatre YAML modifiés sont analysés avec succès. Les tests SQL locaux des pipelines restent inchangés. Aucun achat, inventaire, solde, règle économique ou donnée de production modifié. Aucun paramètre distant, forfait ou protection de sécurité modifié. Les PR existantes ne sont pas fusionnées.

## Suivi PR 42 — démarrage Chromium des bancs

Le banc `banc-infobulles-navigateur.cjs` attendait uniquement le texte stderr « DevTools listening » pendant cinq secondes. Il ne distinguait pas une initialisation lente, une sortie de Chromium et une assertion du scénario. La fragilité de cette condition est confirmée dans le code ; la panne intermittente sur les runners GitHub Actions n'a pas été reproduite localement.

Le lanceur partagé de banc `fixtures/chromium-cdp.cjs` :

- recherche le fichier Chromium `DevToolsActivePort`, avec stderr comme solution secondaire, puis vérifie `/json/version` sur loopback ; une simple annonce de port ne suffit pas ;
- accorde jusqu'à vingt secondes à l'initialisation, avec requêtes HTTP bornées et surveillance des événements error/exit du processus ;
- distingue lancement impossible (`HG_CHROMIUM_SPAWN`), sortie prématurée (`HG_CHROMIUM_EXIT`), délai d'initialisation (`HG_CHROMIUM_TIMEOUT`), transport CDP et absence de verdict du scénario ;
- borne les journaux conservés, ferme le groupe de processus (SIGTERM puis SIGKILL si nécessaire), attend la fermeture et permet ensuite de supprimer le profil ;
- conserve les trois scénarios originaux, dont la contre-épreuve de l'ancienne infobulle. Aucun retry d'un scénario échoué ni succès de substitution.

Le banc principal borne aussi la découverte de page, l'ouverture WebSocket et l'attente du verdict, puis libère requêtes CDP, socket, serveur HTTP et profil, y compris lors d'une erreur. La création du profil intervient après l'extraction des composants pour éviter un répertoire orphelin si cette extraction échoue.

Validation : **10 passages consécutifs du banc ciblé, 30/30 scénarios réussis**. Le nouveau banc de cycle de vie couvre notamment une initialisation volontairement supérieure à cinq secondes sans annonce stderr (fichier d'abord incomplet), le processus arrêté avant DevTools, l'exécutable absent, un processus ignorant SIGTERM, un port sans API et Chromium réel. Ces six cas passent. Sur Chromium réel local, l'API répond alors que les journaux contiennent bien des messages D-Bus : ils sont non bloquants dans cet essai, et ne justifient pas l'installation d'un service D-Bus ou l'effacement des diagnostics. Cela ne permet pas d'attribuer chaque incident distant à la même cause.

La correction ne touche que les bancs et leur documentation : aucun jeu, donnée, migration ou paramètre Supabase/Vercel modifié. La validation distante relève de la prochaine exécution de la PR 42, pas d'une réussite locale supposée équivalente.

Après les dix répétitions ciblées : `python3 outils/bancs/controler-client.py --rapport /tmp/hg-chromium-complet` : **75/75 bancs réussis**, aucun SQL exécuté.

## Vérification complémentaire — 18 octobre 2026

Contrôle effectué depuis l'intégration connectée à Supabase (projet `jxpwoosmmhohoihxpbuc`) et GitHub :

- Les quatre workflows du commit `21f6a2791120740998a04670dc4019cd98b121b3` sont **réussis** : cohérence client, garde payload, détention et fermetures calendrier.
- La PR 42 est toujours ouverte en brouillon et **non fusionnable en l'état** avec `main` après les intégrations ultérieures. Ne pas forcer la fusion : rebaser ou reporter les changements sur le `main` courant puis relancer les tests.
- Le catalogue vivant des fonctions publiques contient `tracts_electoraux_distribuer_collectif(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text)`.
- Le même catalogue **ne contient pas** `inventaire_reception_etat`, `inventaire_reclamer_livraison`, `inventaire_sauver_revision`. Leur présence dans `migrations/20261016131932_reception_objets_atomique.sql` n'est donc pas une preuve de déploiement. L'écart Authority est réel pour ces trois RPC ; ne pas modifier la base sans audit de dépendances et procédure de migration.
- Les tables `public.ordres_couts` et `public.postes_nommes_regles` existent ; cela ne résout pas les deux divergences d'empreintes Referential, qui nécessitent une comparaison des données et du générateur.
- Aucun déploiement de production ni migration n'a été déclenché par cette vérification.


## Suivi du 28 octobre — cycle de vie du contrôleur CI

Voir `FIABILISATION-20261028.md` et ses preuves : le contrôleur conserve les journaux
en cas de délai dépassé, arrête son groupe de processus et écrit les résultats
progressivement avec un état d'exécution explicite. Une annulation TERM passe par
le nettoyage ; une terminaison forcée KILL reste non interceptable. Le délai de
120 secondes par banc et les verdicts métier restent inchangés.

Les workflows existants « Parcours immobilier cinq terrains » et « Placement
national transactionnel » annulent maintenant les seules exécutions dépassées
d'une même PR, comme les quatre contrôles qui le faisaient déjà. Aucun nom de
contrôle, déclencheur, test ou déploiement n'est supprimé. Cela économise du temps
Actions ; aucun gain de builds ou de facturation Vercel n'est démontré.
