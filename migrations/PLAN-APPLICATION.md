# Plan d'application — **aucune migration en attente**

> **État au 8 octobre 2026, après les arbitrages « architecture budgétaire de
> Républia » puis « le QHS relève de l'Intérieur ».** Ce répertoire ne contient
> plus que ce fichier et son `README`.

## Ce qui est APPLIQUÉ

| Registre Supabase | Fichier | Sujet |
|---|---|---|
| `20261007140910` | `20261007040000_direction_etablissements_salaire_serveur.sql` | le salaire, la ville et le bâtiment d'un poste de direction ne viennent plus du navigateur ; les barèmes civils sont dimensionnés par empire |
| `20261007141655` | `20261007150500_directions_etablissements_sans_roles_clients.sql` | correctif : la table neuve n'accorde plus `SELECT` à `anon` ni à `authenticated` |
| `20261007150217` | `20261008000000_villes_referentiel_et_caisses_fail_closed.sql` | référentiel des douze villes, portée territoriale d'une caisse, fermeture du *fail-open* d'autorité, 5 caisses vestigiales supprimées |
| `20261007150749` | `20261008010000_repartitions_budgetaires.sql` | la brique budgétaire générique : deux tables, cinq fonctions, la caisse des douanes, la résurrection documentée du Palais du Gouvernement |
| `20261007153134` | `20261008020000_revoquer_authenticated_cinq_fonctions_serveur.sql` | correctif : cinq fonctions serveur perdent le `authenticated` qu'elles n'avaient jamais demandé |
| `20261007181335` | `20261008030000_qhs_releve_de_l_interieur.sql` | le QHS devient bénéficiaire déclaré du Ministère de l'Intérieur, à **0 %** ; `transfere` cesse de prétendre qu'un versement nul est un transfert ; cinquième invariant — une caisse, un financeur |
| `20261007182523` | `20261008040000_virement_qhs_declaration_dit_la_verite.sql` | la déclaration résiduelle de `virementJournalierQHS` garde son verrou et dit ce qu'elle est |

Les sept fichiers sont dans `historique/migrations-appliquees/`, et chacun porte
en tête la version du registre **et ce qui a été vérifié après coup**. Le
baseline a été réextrait et commité avec eux.

> **Le registre horodate à l'application, pas à l'écriture.** Les noms de
> fichiers gardent leur horodatage de rédaction (`20261008000000`…) alors que le
> registre inscrit l'instant de l'application (`20261007150217`…). C'est le
> comportement constaté sur toutes les migrations de ce dépôt, et la
> correspondance est écrite dans l'en-tête de chaque fichier.

---

## La leçon qui s'est répétée cinq fois

**`REVOKE ALL … FROM PUBLIC` ne retire pas les droits NOMMÉS.** Supabase pose un
`ALTER DEFAULT PRIVILEGES` sur le schéma `public` : toute table et toute fonction
qui y naît reçoit un `GRANT` nommé à `anon`, `authenticated` et `service_role`.
Révoquer `PUBLIC` retire le pseudo-rôle, et lui seul.

| Date | Objets | Trouvé par |
|---|---|---|
| 7 oct. | `directions_etablissements` (table) | **le diff du baseline** |
| 8 oct. | `villes_empreinte_reelle`, `ville_est_reelle`, `caisse_territoire`, `caisse_refus_autorite`, `budget_coherence` (fonctions) | **le diff du baseline** |

Trois fois sur trois, c'est la **relecture ligne par ligne du diff de
`70_droits.sql`** qui l'a vu. **Aucun des dix contrôles ne le voit**, et c'est la
dette d'outillage la plus coûteuse qui reste : il manque un contrôle qui compare
les droits réels à l'**intention déclarée dans les migrations**. Tant qu'il
n'existe pas, l'étape « relire le diff » du workflow n'est pas une formalité.

La forme juste, pour une table comme pour une fonction, est **trois `REVOKE`** :

```sql
REVOKE ALL ON TABLE public.x FROM PUBLIC;
REVOKE ALL ON TABLE public.x FROM anon;
REVOKE ALL ON TABLE public.x FROM authenticated;
```

Et la vérifier **dans la transaction**, par un bloc `DO` qui lève plutôt que de
laisser croire que la porte est fermée — c'est ce que fait `20261008020000`.

---

## Deux trous du registre des seeds, trouvés le même jour

Le contrôle de couverture ajouté à `seeds.py` refuse désormais d'écrire si une
table classée `reconstruction_explicite` n'est déclarée **ni** dans
`A_REGENERER` **ni** dans `A_CONSTRUIRE`. Il en a trouvé deux immédiatement :

- **`villes`**, née la veille : classée, rendue dans le schéma, absente des deux
  registres. Un monde reconstruit serait né **sans aucune ville**, et
  `ville_est_reelle()` aurait refusé tout — *fail closed*, donc sans danger, mais
  injouable.
- **`recettes_militaires`**, dont le fichier de seed était écrit **à la main**
  depuis le 6 octobre, hors de tout registre : `seeds.py` ne le connaissait pas
  et l'`INVENTAIRE` ne le hachait pas.

Les deux sont déclarées. Le répertoire `95_a-regenerer/` compte maintenant six
fichiers, et la dette qu'ils portent est la même pour tous les six : **faire
écrire ces seeds par leur générateur**, au lieu de les laisser vides.

---

## Prochaine migration : par où elle passe

Le processus complet est dans **`WORKFLOW-SUPABASE.md`**, et il n'est pas redit
ici. Les trois points sur lesquels ce chantier a buté :

1. **Une migration doit être postérieure au point de coupe du baseline**
   (`baseline/CONTROLE-GLOBAL.json`, clé `releve_le` — désormais
   `2026-10-07T20:23:28`). L'invariant 4 du garde-fou refuse une migration
   antérieure, à raison : son effet est censé être déjà dans le baseline. Si une
   réextraction a lieu entre l'écriture et l'application, **redater le fichier**
   est la seule réponse juste.
2. **Une migration appliquée doit être identique au fichier du dépôt, au
   caractère près.** Le 8 octobre, une application de `20261008010000` avait
   échoué sur « requestState expiré » et la seconde est passée avec un payload
   raccourci. Le dépôt et la base ont donc divergé discrètement pendant une
   journée — sur des commentaires internes et une variable locale inutilisée,
   rien de fonctionnel, mais le dépôt décrivait une fonction que la base n'avait
   pas. `20261008030000`, qui réapplique le corps du dépôt, les a réalignés.
   **La leçon : après une application qui a dû être rejouée avec un payload
   modifié, réextraire et relire le diff de `20_fonctions.sql` — c'est le seul
   endroit où cette divergence se voit.**
3. **Les espaces ne font pas la signature.** L'invariant 12 comparait
   `caisse_territoire(text, text)` — tel qu'un auteur l'écrit — à
   `caisse_territoire(text,text)` — tel que le catalogue le rend — et criait sur
   des fonctions qui existent. Il normalise maintenant les deux côtés ; il était
   doublement faux, puisqu'il serait resté muet sur une vraie inconnue écrite
   sans espace.
