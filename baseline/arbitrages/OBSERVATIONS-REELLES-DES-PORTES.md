# Ce que la bêta a réellement fait tourner — observations du 10 octobre 2026

> **Aucune mécanique n'a été déclenchée artificiellement pour écrire ce
> document.** Tout ce qui suit est lu dans la base vivante le 10 octobre 2026 à
> 17 h 36 (heure de Paris). Quand un mécanisme n'a pas été observé, c'est écrit
> comme tel — une porte non observée n'est pas une porte en défaut, mais elle
> n'est pas une porte prouvée en conditions réelles non plus.

Le lot du 9 octobre a posé quinze portes serveur, et celui du 10 en a posé
vingt-trois de plus. Les bancs les éprouvent en transaction annulée. Ce document
répond à une autre question : **qu'est-ce que la bêta a réellement exécuté ?**

---

## 1. La passe de minuit — observée, et verte

`cron_journal` donne le compte exact, par tâche et par journée.

| Journée | Tâches | `ok` | non-`ok` |
|---|---:|---:|---:|
| 2026-10-10 | 21 | **21** | 0 |
| 2026-10-09 | 21 | **21** | 0 |
| 2026-10-08 | — | — | — |
| 2026-10-07 | 19 | 19 | 0 |
| 2026-10-06 | 19 | 19 | 0 |
| 2026-10-05 | 19 | 19 | 0 |
| 2026-10-04 | 19 | 19 | 0 |
| 2026-10-03 | 19 | 19 | 0 |

**La passe du 10 octobre a tourné**, à 00:00:03 UTC, en 44 639 ms, sans une seule
tâche en échec et sans une seule tentative au-delà de la première. C'est la
première passe complète postérieure aux quinze portes du 9 octobre.

Ce qu'elle a fait, tâche par tâche — les contextes sont recopiés tels quels :

| Tâche | Contexte |
|---|---|
| `_passe` | `{"traites": 0}` — 44 639 ms |
| `souvenirs_accueil` | `{"fuites": 0, "marquages_echoues": 0}` |
| `taxe_fonciere` | `{"saisies": 0, "collecte": 0, "avertissements": 0}` |
| `preemptions_etat` | `{"payes": 0, "soldes": 0, "reportes": 0}` |
| `budgets_municipaux` | `{"verse": 320, "villes": 3, "conserve": 80}` |
| `livraisons_entrepots` | `{"coutTotal": 657.5, "entrepots": 3, "unitesLivrees": 355, "echecsTechniques": 0}` |
| `production_transformateurs` | `{"transformateurs": 3, "uniteesProduites": 16, "achatsInterUsines": 1}` |
| `exportations_port` | `{"forme": "objet"}` |
| `detentions_pnj` | `{"liberations": 0}` |
| `transits_entrepots` | `{"lignes_livrees": 0, "unites_livrees": 0, "unites_perdues_capacite": 0}` |
| `cellules_renseignement`, `collecte_agents`, `rapports_cellules` | `{"echecs": 0, …}` |
| `affectations_militaires_expirer`, `candidatures_militaires_relancer` | `{"expirees": 0}`, `{"relancees": 0}` |
| `effort_de_guerre`, `effets_blocus` | `{"actif": false}`, `{"appliques": 0}` |
| `arrivage_criee` | `{"arrivee": 0, "stockApres": 125}` |
| `paye_douane`, `paye_police` | `{"ok": true}` |
| `sonde_ia` | `{"fournisseur": "joignable"}` |

**Trois lectures de ce relevé.**

- **De l'argent a réellement bougé** : 320 FR répartis sur trois villes, 657,5 FR
  d'approvisionnement pour 355 unités livrées, 16 unités produites. Le socle
  économique tourne.
- **`souvenirs_accueil` a bien appelé sa porte** (registre 600) et n'a produit
  aucune fuite : `marquages_echoues: 0` dit qu'aucun marquage n'a échoué. Le
  mécanisme est exécuté, son effet est nul faute de souvenir à révéler.
- **Les tâches du 9 et du 10 sont identiques, 21 contre 21, toutes vertes.**
  Aucune régression n'est constatée après les deux lots.

### Un fait à signaler, hors périmètre des chantiers 5 et 6

**La passe du 8 octobre 2026 n'a pas tourné.** Elle est absente de
`cron_journal` *et* de `journal_editions` — ce n'est donc pas un échec de
journal, c'est l'absence de la passe elle-même. Les 7, 9 et 10 ont tourné
normalement. La cause n'est pas dans ce dépôt (ordonnanceur), et ce lot ne la
cherche pas : il la nomme.

---

## 2. Ce qui n'a PAS encore été observé

| Mécanisme | Portes concernées | Compte en base |
|---|---|---:|
| Incarcération réelle | `detention_ouvrir_soi`, `detention_clore_purgee`, `detention_transferer_qhs`, `detention_prolonger_soi` | **0 ligne** dans `detentions` |
| Sentence réelle | `justice_rendre_sentence` | **0 ligne** dans `jugements` |
| Plainte / affaire réelle | `plainte_deposer`, `plainte_traiter`, `affaire_transmettre`, `plainte_defendre`, `plainte_classer_ministere` | **0 ligne** dans `plaintes_en_cours` |
| Vote électoral réel | `election_voter` | **0 bulletin** et **0 candidat** sur les 13 cycles |
| Vente de terrain réelle | `terrain_proprietaire_muter` | **0 ligne** dans `terrains_historique_ventes` |
| Acte nocturne revendiqué | `acte_nocturne_revendiquer` | **0 ligne** dans `actes_nocturnes` |

**Ce que cela veut dire, et ce que cela ne veut pas dire.** Les portes
judiciaires et électorales sont éprouvées par 849 épreuves de banc et par leurs
contre-épreuves, mais **aucun joueur ne les a encore empruntées**. Elles restent
donc à constater en conditions réelles — c'est-à-dire avec une vraie identité,
une vraie RLS et une vraie latence. Le dernier passage d'un joueur date du
9 octobre à 22 h 08.

`actes_nocturnes` vide mérite sa nuance : la passe a bien exécuté `taxe_fonciere`
et `preemptions_etat`, qui revendiquent par cette table — mais elles n'ont
trouvé **aucun sujet** (0 saisie, 0 collecte, 0 avertissement, 0 paiement). Une
table de revendication vide après une passe verte qui n'a rien eu à faire est le
comportement attendu, pas un silence suspect.

---

## 3. Comment refaire ces mesures

```sql
-- La passe, par journée et par tâche.
SELECT jour, tache, statut, duree_ms, tentatives, contexte
  FROM public.cron_journal ORDER BY jour DESC, tache;

-- Les six mécanismes non observés.
SELECT (SELECT count(*) FROM public.detentions)                 AS detentions,
       (SELECT count(*) FROM public.jugements)                  AS jugements,
       (SELECT count(*) FROM public.plaintes_en_cours)           AS plaintes,
       (SELECT count(*) FROM public.terrains_historique_ventes)  AS ventes,
       (SELECT count(*) FROM public.actes_nocturnes)             AS actes_nocturnes,
       (SELECT max(updated_at) FROM public.personnages_donnees)  AS derniere_activite;
```

---

## 4. Ce que la purge des résidus de banc a trouvé dans la bêta

La purge du 10 octobre (registre 623) a archivé puis supprimé **71 lignes de banc
dans 19 tables de jeu**. Le contrôle d'intégrité fait après coup dit deux choses.

**Aucune donnée de joueur n'a été touchée.** Les 8 fiches sont intactes, aux
mêmes montants et aux mêmes PA ; aucun des 14 courriers purgés n'impliquait un
vrai joueur, ni comme expéditeur ni comme destinataire ; les 4 terrains réels
sont là, et les quatre personnages qui servent de décor aux bancs (Ben, May,
Marsault, Lee Capene) ont bien `poste = NULL`, `moral = 75` et un avis de
recherche vide — **aucun décor de banc n'a fui en production**.

**Mais une ligne sur les 71 nommait un vrai joueur, et elle mérite d'être dite.**

```json
{"id": "zztest-fraude-forgee", "type": "bourrage_urnes", "auteur": "Arnie",
 "candidat": "Arnie", "poste_id": "maire", "city": "capitale",
 "delta_voix": 50, "etat": "non_revelee", "detectabilite_pct": 100,
 "created_at": "2026-10-04T17:44:22Z"}
```

Un banc du 4 octobre a laissé dans `fraudes_electorales` une **accusation de
fraude électorale fabriquée, au nom d'un joueur réel** — un bourrage d'urnes de
50 voix sur la mairie de la capitale, `non_revelee` et **révélable à 100 %**.
Elle y est restée six jours. Elle est archivée dans `purges_residus_bancs` et
retirée de la table de jeu.

Ce n'est pas un défaut des chantiers 5 ou 6 : c'est un défaut de **discipline de
banc**, et il dit pourquoi le balayage des résidus devait être fait. Un banc qui
écrit dans une table de jeu doit s'annuler ; celui-là a commité.
