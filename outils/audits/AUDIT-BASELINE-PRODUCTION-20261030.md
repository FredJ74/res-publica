# Audit de synchronisation baseline / Supabase — 30 octobre 2026

**Périmètre** : lecture seule du projet Supabase `jxpwoosmmhohoihxpbuc`. Aucune modification des données ou du schéma de production. Branche de travail indépendante de la PR #219 de Codex.

## Résultats vérifiés en production

| Indicateur | Baseline daté du 13/10/2026 | Catalogue réel le 30/10/2026 |
|---|---:|---:|
| Tables ordinaires (public) | 319 | 375 |
| Fonctions (public, `prokind=f`) | 906 (total historique) | 1199 |
| Triggers non internes | 51 | 79 |
| Policies | 281 | 264 |

**Attention** : ces totaux correspondent à des relevés de dates et de conventions distinctes et ne sont pas un diff objet-par-objet. Ils démontrent que `baseline/CONTROLE-GLOBAL.json` (relevé du 13 octobre) ne représente pas l'état du catalogue actuel. Il est interdit de remplacer ces nombres à la main.

Trois signatures vivantes dont le comportement ne correspond pas aux migrations historiques rejouées par Claude :

| Signature | MD5 DDL production | MD5 corps production |
|---|---|---|
| `inventaire_place_restante(jsonb)` | `1cf40d9f88626c8bdc6bf0eb22356ac7` | `da7514872e7679c707af6ae9caffb03a` |
| `payer_ordre(text,text,integer,integer)` | `37eca91d6eb08c2a6ea97cbe717a216a` | `5cf45c19e4b9559f6b29e2b9207d3969` |
| `personnages_convocations_garder()` | `87802621d1618e1739143831523f090b` | `cf955a8db64b57b3a646143f4a42d4f7` |

La table `public.acquisitions_transactions_internes` est **présente** en production, alors qu'aucune migration rejouable de l'état actuel du dépôt ne la recrée selon la recette de reconstruction de la PR #261. Elle intervient notamment dans la garde de `payer_ordre`.

## État des garanties existantes

- La PR #261 a livré `entrepot_capacite_universelle` ; l'ancienne signature d'achat est toujours fermée à `authenticated`.
- Les fonctions de production ci-dessus ont été relevées avec leurs empreintes, mais **aucun baseline n'a été réécrit**.
- `outils/bancs/jetable-ecarts-production-20261030.sql` contient les trois corps de production employés par la reconstruction jetable de Claude : **rustine de banc**, pas baseline canonique.
- La PR #219 utilise une branche propre à Codex : ne pas intégrer ces écarts sur sa branche pendant qu'il travaille.

## Procédure de clôture obligatoire

1. Relever les quatre exports complets de catalogue selon `outils/baseline/requetes.py --exports`, l'export des droits et `--controle-global`, avec la même fenêtre de stabilité. Ne pas inventer de définitions.
2. Exécuter `outils/baseline/rendre.py`, puis le rendu des seeds dans une base jetable à partir des exports intégralement acquis. Ne jamais exporter les données privées des joueurs en seeds.
3. Traiter explicitement `acquisitions_transactions_internes` dans la classification et dans le DDL canonique, avec permissions, RLS, index et triggers effectifs. Reconstituer les trois corps divergents directement depuis le catalogue.
4. Passer `outils/baseline/controler-tout.py` et la reconstruction PostgreSQL réelle ; comparer les empreintes et l'inventaire objet-par-objet, pas seulement les totaux.
5. Archiver seulement les migrations **déjà réellement appliquées** suivant `WORKFLOW-SUPABASE.md` ; garder les migrations non livrées de #219 hors du nouveau point de coupe. Reprendre le relevé si #219 évolue entre les deux lectures.
6. Préparer une PR séparée et ne fusionner qu'après réussite des contrôles d'autorité, fidélité, référentiels, assemblage, reconstruction et validation des différences.

## Verdict

**Audit initial terminé ; re-génération du baseline non terminée.** Le référentiel daté du 13 octobre est obsolète, les divergences de trois corps et l'absence de DDL rejouable pour `acquisitions_transactions_internes` sont documentées. Aucune migration ou donnée joueur n'a été touchée pendant cet audit. La production reste la source de vérité.

## Détail structurel confirmé de la table manquante dans le rejeu

`public.acquisitions_transactions_internes` comporte six colonnes : `transaction_id bigint NOT NULL`, `acteur text NOT NULL`, `terrain text`, `ordre text`, `pa integer`, `montant integer`. La clé primaire composite est `(transaction_id, acteur)`, portée par l'index unique `acquisitions_transactions_internes_pkey`. RLS activée (non forcée), `relacl` explicite `{postgres=arwdDxtm/postgres}`, aucun trigger utilisateur. Ce constat **ne suffit pas** à publier un DDL de référence : les éventuelles policies, commentaires, dépendances et privilèges par défaut doivent être extraits par les requêtes canoniques.
