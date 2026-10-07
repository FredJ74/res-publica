# Plan d'application — deux migrations en attente

> **État au 7 octobre 2026, fin du lot de nuit.**
> Deux migrations sont écrites, éprouvées hors ligne, et **non appliquées**.
> Aucune n'a jamais atteint la base. Le baseline n'a pas été réextrait, et les
> registres le disent.

## Nombre de confirmations humaines nécessaires : **2**

Une par `apply_migration`. Je ne les ai pas fusionnées : elles traitent deux
sujets distincts (identité territoriale des caisses / autorité sur le salaire des
directions), et un seul fichier de 900 lignes serait moins relisible et moins
révocable. Fusionner pour gagner un clic aurait coûté la traçabilité.

**Aucune autre action n'est demandée.** Pas de SQL à exécuter à la main, pas de
commande à lancer : seulement accepter les deux appels MCP.

---

## Ordre d'application

**1 puis 2.** La seconde ne dépend pas de la première, mais la première crée le
référentiel `villes` dont tout le reste du chantier d'identité dépend — et c'est
elle qui ferme une faille d'autorité ouverte.

| # | Fichier | Sujet |
|---|---|---|
| 1 | `20261007003000_villes_referentiel_et_caisses_fail_closed.sql` | référentiel des villes, portée territoriale d'une caisse, fermeture du *fail-open* d'autorité, 5 caisses vestigiales |
| 2 | `20261007040000_direction_etablissements_salaire_serveur.sql` | le salaire, la ville et le bâtiment d'un poste de direction ne viennent plus du navigateur |

---

## Pourquoi elles sont sûres

### Toutes les deux

- **Idempotentes** : `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`,
  `DROP POLICY IF EXISTS` avant `CREATE POLICY`, `DELETE` + `INSERT` sur les
  seules lignes qu'elles possèdent. Rejouées, elles ne cassent rien.
- **Aucun droit à `PUBLIC` ni à `anon`** : chaque fonction créée est révoquée
  explicitement de `PUBLIC` **avant** tout `GRANT`. PostgreSQL accorde `EXECUTE`
  à `PUBLIC` par défaut sur toute fonction neuve, et un `GRANT` nominatif ne
  l'annule pas — piège rencontré trois fois sur ce dépôt.
- **Grammaire validée** par l'analyseur réel de PostgreSQL 17.7 (`pglast`) :
  44 instructions pour la première, 12 pour la seconde.
- **Invariant 12** de `verifier-autorite.py` : chaque table, signature et policy
  nommée existe en base, ou est créée par la migration elle-même.

### La première

| Validation | Résultat |
|---|---|
| table de décision de `caisse_territoire()` rejouée **en lecture seule sur les 151 caisses réelles** | 48 nationales, 36 de ville (contre 34 avant : les 4 `mairie-capitale` sont récupérées), 61 sans règle, 6 indéterminées |
| effet du resserrement sur les postes **réellement pourvus** | les deux seuls postes tenus dans la bêta (`min_def`, `lieutenant`) sont **nationaux** → **zéro** chemin légitime fermé. Ce qui se ferme : 25 caisses sans règle par acteur |
| chemins serveur | **intacts** : les trois blocs d'autorité restent enveloppés dans `rp.caisse_interne <> 'on' AND NOT est_appel_serveur()` |
| crédits | **intacts** : les contrôles ne portent que sur les sorties d'argent. Les 8 mouvements clients existants sur les caisses sans règle sont tous des crédits |

**Données touchées** : `DELETE` de 5 lignes de `caisses_batiments`
(`republic_mairie_caserne`, `republic_commissariat`,
`republic_commissariat-local`, `republic_tribunal`,
`republic_tribunal-local`). Les cinq ont **solde 0** et **zéro mouvement**
depuis juillet–août 2026, et la clause `DELETE` **revérifie ces deux conditions
au moment de s'exécuter** — une mesure vieille de quelques heures ne peut pas
autoriser une suppression qui ne serait plus justifiée. Rien d'autre n'est
modifié : aucun solde, aucune règle d'autorité, aucun renommage.

### La seconde

| Validation | Résultat |
|---|---|
| résolution poste → établissement rejouée en lecture seule, 10 cas | les 6 couples déclarés rendent **exactement une** ligne avec le bon bâtiment et 500 FR ; les 4 cas de refus rendent 0 ou 3 lignes → refus |
| existence des établissements | les 6 lignes `batiments_etat` correspondantes **existent** → la bêta continue de payer |
| compatibilité de déploiement | **la signature ne change pas**. `p_pays`, `p_ville`, `p_batiment`, `p_souscle` et `p_montant` restent dans la signature et sont **ignorés**. Le navigateur actuel fonctionne à l'identique avant comme après, dans les deux ordres |
| empires non déclarés | `soviet`/`narco`/`khalija` → refus explicite `direction_non_declaree`, **jamais** les valeurs de Républia |

**Données touchées** : `INSERT` de 6 lignes dans une table neuve
(`directions_etablissements`). Aucune donnée existante n'est lue ni écrite.

---

## Après l'application — ce qu'il reste à faire, et qui le fait

Tout est de mon côté, rien du vôtre :

1. mesurer les empreintes du miroir `villes` (`villes_empreinte_reelle()`) et
   porter les valeurs dans `outils/baseline/referentiels.json` — la ligne y est
   déjà, à `null`, avec `fonction_reelle_en_base: false` ;
2. vérifier que les 5 suppressions ont bien eu lieu et que les 36 caisses de
   ville résolvent leur territoire ;
3. réextraire le baseline (les deux migrations ajoutent 3 tables, 6 fonctions,
   1 policy) et le commiter **avec** le déplacement des deux fichiers dans
   `historique/migrations-appliquees/` — jamais séparément ;
4. relancer les dix contrôles et les treize invariants ;
5. constater que les soldes de la bêta sont inchangés.

---

## Ce qui n'attend PAS une confirmation

Tout le reste du lot de nuit est **livré et poussé** : référentiel des villes et
résolveur unique côté navigateur, répartition fiscale territoriale portée au
cron, fondation `sbTransportRest`, treize `sbSave*` passés en upsert, douze
`sbCreer*` qui vérifient leur écriture, la trésorerie municipale protégée d'une
panne de lecture, le forum qui distingue une panne d'un vide, et le pays
transmis à la résolution des établissements municipaux.

Ces changements **ne dépendent d'aucune des deux migrations** et ne cassent rien
si elles ne sont jamais appliquées.
