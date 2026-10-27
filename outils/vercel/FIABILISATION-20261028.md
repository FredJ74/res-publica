# Fiabilisation GitHub / Vercel — 28 octobre 2026

Branche : `codex/fiabilisation-ci-20261028`. Départ : main `da5ecc0` récupéré
explicitement. Travail distinct de l'inventaire confié à Claude : aucune reprise
de ses migrations, de son verrou, de son contrôle Workflow ou de sa PR.

## Constats vérifiés et limites

- Les garde-fous existent : `vercel-ignore-build.cjs`, `.vercelignore`, garde du
  payload, constructeur `@vercel/node` épinglé, initialisation Chromium CDP,
  annulation des vieilles exécutions PR sur quatre workflows. Ils sont conservés.
- Aucun workflow n'appelle `vercel deploy` : pas de second canal de publication à
  supprimer. Le constructeur des bancs compile localement sans publier.
- `vercel.json` n'autorise actuellement les déploiements Git que de main. Les
  affirmations anciennes du document de déploiement sur les Preview automatiques
  étaient contradictoires avec ce fichier ; documentation corrigée, configuration
  inchangée. Impossible de déduire les paramètres distants de ce seul fichier.
- **Défaut reproduit** : le contrôleur utilisait `subprocess.run(..., timeout=120)`
  puis remplaçait l'exception par une phrase. Dans un essai borné, son enfant
  restait vivant après le timeout et son diagnostic disponible était jeté. Le
  parent, lui, était bien arrêté : aucun blocage permanent du parent n'est établi.
- Les résultats JSON n'étaient écrits qu'en fin de campagne : une annulation
  pouvait perdre la liste des bancs déjà terminés.
- Les workflows parcours immobilier et placement ne possédaient pas la politique
  d'annulation PR déjà adoptée par quatre autres workflows. L'exécution de chaque
  commit périmé restait possible ; aucune consommation distante n'est mesurée.
- Git fetch/push fonctionnent. `gh run list` et `gh pr list` sont refusés par l'API
  (`Forbidden`). L'appel HTTPS public de production est refusé au tunnel proxy
  (`CONNECT ... 403`), avant l'application. **Ce refus n'est pas une panne du jeu.**
  Aucun statut de production ou de quota n'est vérifié par cette session.

## Corrections

`outils/bancs/controler-client.py` démarre chaque banc dans son groupe privé et
capture les deux flux dans un fichier temporaire. Après 120 secondes, TERM puis
KILL arrêtent ce groupe ; les journaux partiels sont conservés avec le code 124.
Un exécutable absent est distingué (125) d'une assertion en échec (code d'origine).
Les erreurs ne deviennent jamais des réussites et le contrôleur poursuit les
bancs suivants après un refus ou un timeout.

Les résultats sont enregistrés après chaque banc, par remplacement atomique du
fichier JSON. `execution.json` indique `en_cours`, `terminee` ou `interrompue`, les
nombres attendus/terminés et les échecs. `terminee` signifie que tous les bancs ont
rendu un verdict, **pas** que tous ont réussi : il faut vérifier `echecs` et les
codes. INT et TERM passent par le nettoyage. Après une interruption, les anciens
journaux restent disponibles ; KILL et l'arrêt brutal de la machine ne sont pas
interceptables et la dernière photographie peut rester `en_cours`.

Le nettoyage cible le groupe POSIX du banc, pas les processus d'autres sessions.
Un descendant qui crée explicitement sa propre session doit toujours gérer son
nettoyage dans son lanceur ; le lanceur Chromium existant le fait déjà, avec ses
propres délais bornés. On ne prétend pas intercepter arbitrairement tous les
processus détachés du système. Le banc de cycle de vie Chromium reste inchangé.

Deux blocs `concurrency` réutilisent exactement la politique existante dans
`test-parcours-immobilier-135.yml` et `garde-placement-national.yml` : annulation
uniquement d'une ancienne exécution de la **même PR et du même workflow**. Main
n'est pas annulé, les workflows ne s'annulent pas entre eux. Aucun nom de contrôle,
job, déclencheur ou assertion métier retiré. Aucun nouveau pipeline ajouté.

## Validation locale

| Vérification | Résultat |
| --- | --- |
| Contrôleur entier, lanceur Linux du dépôt | **106/106 bancs**, zéro échec |
| Régressions Python du cycle de vie | **7/7**, vrais processus locaux |
| Déploiements sobres + nouveau banc du contrôleur | **24/24** tests Node |
| Pilote joueur local | **105/105**, aucun compte réel |
| Infobulles (3) + cycle de vie Chromium (6), trois répétitions | **27/27**, zéro échec |
| Calendrier et placements (`test-*.mjs`) | **11/11** |
| Syntaxe API | **23 modules** |
| Payload Vercel | **256,5 Mo / 330 Mo**, marge 73,5 Mo |
| YAML des workflows | **12 fichiers analysés**, pas de validation distante GitHub |
| Trois contre-épreuves du nouveau contrôleur | **3 détectées** par assertions ciblées |

Ces comptes se recouvrent : les modules ciblés sont aussi dans les 106 bancs.
Le pilote est local, non une campagne Arnie ni une connexion de production. Les
contre-épreuves travaillent dans des copies temporaires, sans changer les sources
suivies : suppression des journaux partiels, arrêt du seul parent laissant un
enfant actif, faux rapport complet après interruption. Toutes provoquent bien
l'assertion attendue et les processus de test sont nettoyés.

Les sept tests couvrent succès/refus d'assertion, lancement impossible, timeout
avec deux flux conservés, enfant ignorant TERM sans toucher une session étrangère,
parent ignorant TERM, annulation TERM réelle et bilan interrompu persistant. Les
fixtures ont des délais d'initialisation tolérants ; aucun test métier n'est sauté.

Le premier lancement ciblé sous le bac à sable restreint a échoué sans diagnostic
exploitable. Les essais de processus et Chromium ont ensuite été exécutés avec
les permissions locales nécessaires, avec succès. La validation Linux finale
utilise **le repli Node versionné du dépôt**, sans `PYTHONPATH` de compatibilité ni
`HG_JSC` externe. Node 24.19.0 local ; les dépendances épinglées Vercel et pilote
proviennent des installations locales déjà présentes, sans modification des locks.

Preuves brutes et manifeste de sources : `preuves-20261028/`. Le manifeste lie les
résultats aux empreintes des fichiers testés ; aucune preuve de succès distant
n'est fabriquée. Les bancs SQL métier n'ont pas été rejoués : aucun SQL ni métier
modifié. Le contrôle Workflow et les références Supabase ne sont ni modifiés ni
présentés comme verts ; Claude reprend ce point dans son lot inventaire.

## Reprise et publication

Corrections destinées à une PR isolée, **sans fusion automatique ni déploiement**
dans cette session. Le push de sauvegarde ne prouve aucune exécution Actions ni
aucun déploiement. Résultats distants/protections de branche et observation Vercel
restent à vérifier avec un accès autorisé. Aucun contournement d'API, changement
de forfait ou de paramètres distants n'est tenté.

L'ajustement saisonnier du cron appelle toujours le contrôleur Workflow global.
Les anomalies de rangement déjà confiées à Claude peuvent donc le bloquer ;
l'heure actuellement déployée n'est pas vérifiable ici. Cette dépendance est
signalée, sans supprimer le contrôle ni toucher au calendrier du jeu.

Aucune donnée de joueur lue ou modifiée, aucun compte utilisé, aucune migration,
aucune modification d'argent, d'inventaire, de navigation ou de règle métier.
Aucun fichier JavaScript servi n'est modifié : pas de version de cache à relever.
