# Migrations appliquées — l'archive du cycle 2G

Une migration qui vit ici a été **appliquée à la base**, et le baseline a été
**réextrait après**. Son effet n'est donc plus dans ce fichier : il est dans
`baseline/`, qui fait foi.

C'est pour cela qu'elle a quitté `migrations/`. Ce répertoire-là ne contient que
les évolutions **futures**, et l'invariant 4 de `verifier-autorite.py`… non :
l'invariant 4 de `../../outils/baseline/verifier-workflow.py` refuse qu'une
migration antérieure au point de coupe du baseline y traîne. Il a raison —
la rejouer serait au mieux inutile.

**Ces fichiers ne sont pas rejouables, et n'ont pas à l'être.** On les garde pour
une seule raison : lire, dans six mois, *pourquoi* un droit a disparu. Le registre
Supabase dit qu'une migration est passée ; ces fichiers disent ce qu'elle voulait.

Ne pas confondre avec `../sql-racine/migrations/` : ces 184 fichiers sont
d'avant le baseline, dispersés à la racine du dépôt, sans garantie
d'application — 162 d'entre eux dépendent d'une table qu'aucun ne crée. Ici,
tout a été appliqué, dans l'ordre, et mesuré après.

## Ce qu'elles contiennent

| Fichier | Registre | Effet mesuré après application |
|---|---|---|
| `20261005214500_autorite_defauts_fermes.sql` | 540 | privilèges de maintenance aux rôles clients 547 → 0 · `UPDATE` de séquence 40 → 0 · défaut d'une table neuve réduit à `SELECT` |
| `20261005214600_autorite_socle_acteur_identifie.sql` | 541 | `acteur_identifie()` créée · tables sans RLS 27 → 0 · policies 213 → 284 (28 permissives retirées, 99 posées) · droits d'écriture clients 233 → 132 |
| `20261006013000_autorite_rpc_sans_anon.sql` | 542 | fonctions mutantes appelables par `anon` 34 → 0 |
| `20261006160000_autorite_declencheurs_public.sql` | 543 | fonctions de déclencheur appelables par un rôle client 24 → 0 |

La quatrième répare la première. La migration 1 avait révoqué `EXECUTE` sur ces
24 fonctions « FROM anon, authenticated » en laissant le `GRANT` à **PUBLIC**,
qui vaut pour tous les rôles : la révocation était sincère et sans effet. C'est
l'invariant 9 de `verifier-autorite.py`, relu après la réextraction du baseline,
qui l'a vu — il lit les droits tels qu'ils sont, pas tels qu'on a cru les
écrire. **Révoquer sur une fonction, c'est toujours `FROM PUBLIC` en plus des
rôles nommés.**

Aucune n'a touché une donnée : ni `INSERT`, ni `UPDATE` de ligne, ni `DELETE`,
ni `TRUNCATE`, ni `DROP TABLE`. Les 7 personnages de la bêta sont intacts.
