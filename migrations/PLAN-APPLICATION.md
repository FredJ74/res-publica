# Plan d'application — une migration en attente

> **État au 7 octobre 2026, après l'arbitrage « revenu universel / salaire de
> direction ».**

## Ce qui est APPLIQUÉ

| Registre Supabase | Fichier | Sujet |
|---|---|---|
| `20261007140910` | `20261007040000_direction_etablissements_salaire_serveur.sql` | le salaire, la ville et le bâtiment d'un poste de direction ne viennent plus du navigateur ; les barèmes civils sont dimensionnés par empire |
| `20261007150500` | `20261007150500_directions_etablissements_sans_roles_clients.sql` | correctif : la table neuve n'accorde plus `SELECT` à `anon` ni à `authenticated` |

Le baseline a été réextrait et commité avec elles. Les deux fichiers sont partis
dans `historique/migrations-appliquees/`.

> **Le registre horodate à l'application, pas à l'écriture.** Le nom du premier
> fichier garde son horodatage de rédaction (`20261007040000`) alors que le
> registre l'a inscrit à `20261007140910`. C'est le comportement constaté sur
> toutes les migrations de ce dépôt, et la correspondance est écrite dans
> l'en-tête de chaque fichier.

### Pourquoi deux applications et non une

La première a créé `directions_etablissements` avec, en commentaire, la
déclaration qu'elle suivait « le même régime que `caisses_autorites` » : RLS
active, aucune policy, aucun droit client. Elle ne portait pourtant qu'un
`REVOKE ALL … FROM PUBLIC`.

**C'est le piège symétrique de celui déjà rencontré trois fois sur les
fonctions.** `FROM PUBLIC` ne retire que le privilège de `PUBLIC` ; Supabase
accorde `SELECT` à `anon` et à `authenticated` **nommément** sur toute table
neuve du schéma public, via `ALTER DEFAULT PRIVILEGES`. La table est donc née
avec `anon=r` et `authenticated=r`.

Ce que cela exposait : **rien**. La RLS est active et la table n'a aucune
policy — une lecture par un rôle client rend zéro ligne. Le privilège était
inerte. Mais le dépôt déclarait une chose et la base en disait une autre, et une
policy ajoutée plus tard l'aurait réveillé sans que personne ne se demande s'il
avait lieu d'être.

C'est la **réextraction du baseline** qui l'a vu, pas un contrôle : les deux
`GRANT SELECT … TO anon/authenticated` sont apparus dans le diff de
`70_droits.sql`. C'est exactement la raison pour laquelle le workflow impose de
relire ce diff.

Les deux fichiers sont corrigés — celui d'origine pour qu'une rejouée soit
juste, et celui de la migration encore en attente, qui crée deux tables et
portait le même défaut.

---

## Ce qui RESTE en attente : **1 confirmation**

| Fichier | Sujet |
|---|---|
| `20261008000000_villes_referentiel_et_caisses_fail_closed.sql` | référentiel des villes, portée territoriale d'une caisse, fermeture du *fail-open* d'autorité, 5 caisses vestigiales |

> **Renommée** depuis `20261007003000`. Le point de coupe du baseline est
> désormais postérieur à cet horodatage, et l'invariant 4 du garde-fou refuse —
> à raison — une migration antérieure au point de coupe : son effet est censé
> être déjà dans le baseline. Celui-ci n'y est pas, puisqu'elle n'est pas
> appliquée. La redater est la seule réponse juste ; son contenu n'a pas bougé
> d'une ligne, hormis les deux `REVOKE` ajoutés ci-dessus.

### Pourquoi elle est sûre

| Validation | Résultat |
|---|---|
| grammaire PostgreSQL 17.7 (`pglast`) | **passée** |
| invariant 12 de `verifier-autorite.py` | **passé** — chaque table, signature et policy nommée existe, ou est créée par la migration |
| table de décision de `caisse_territoire()` | **rejouée en lecture seule sur les 151 caisses réelles** : 48 nationales, 36 de ville (contre 34 : les 4 `mairie-capitale` sont récupérées), 61 sans règle, 6 indéterminées |
| effet sur les postes réellement pourvus | **mesuré** : les deux seuls postes tenus (`min_def`, `lieutenant`) sont nationaux → **zéro** chemin légitime fermé |
| chemins serveur | **intacts** : les trois blocs d'autorité restent enveloppés dans `rp.caisse_interne <> 'on' AND NOT est_appel_serveur()` |
| crédits | **intacts** : les contrôles ne portent que sur les sorties d'argent |
| droits clients sur les deux tables neuves | **fermés par les trois `REVOKE`**, leçon du 7 octobre |

**Données touchées** : `DELETE` de 5 lignes de `caisses_batiments`
(`republic_mairie_caserne`, `republic_commissariat`,
`republic_commissariat-local`, `republic_tribunal`, `republic_tribunal-local`).
Les cinq ont **solde 0** et **zéro mouvement** depuis juillet–août 2026, et la
clause `DELETE` **revérifie ces deux conditions au moment de s'exécuter**.

### Après son application — tout est de mon côté

1. mesurer les empreintes du miroir `villes` et porter les valeurs dans
   `outils/baseline/referentiels.json` (la ligne y est, à `null`) ;
2. vérifier les 5 suppressions et les 36 caisses de ville ;
3. réextraire le baseline et le commiter **avec** le déplacement du fichier dans
   `historique/migrations-appliquees/` ;
4. relancer les dix contrôles et les treize invariants ;
5. **relire le diff du baseline**, ligne par ligne — c'est ce qui a attrapé le
   défaut de droits aujourd'hui ;
6. constater que les soldes de la bêta sont inchangés.
