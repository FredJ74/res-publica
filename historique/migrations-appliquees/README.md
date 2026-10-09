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

**Ce tableau ne décrit que le cycle de l'autorité** (registre 540 à 543) et la
dernière entrée en date. Les 21 fichiers de ce répertoire ne sont donc pas tous
listés ici : les migrations des chantiers 4B à 4F et des budgets municipaux
portent leur résumé **dans leur propre en-tête**, qui est la source à lire. Le
tableau n'a jamais été complété au fil de l'eau ; c'est une lacune
documentaire, pas une incertitude sur ce qui a été appliqué — le registre
Supabase, lui, est complet.

| Fichier | Registre | Effet mesuré après application |
|---|---|---|
| `20261005214500_autorite_defauts_fermes.sql` | 540 | privilèges de maintenance aux rôles clients 547 → 0 · `UPDATE` de séquence 40 → 0 · défaut d'une table neuve réduit à `SELECT` |
| `20261005214600_autorite_socle_acteur_identifie.sql` | 541 | `acteur_identifie()` créée · tables sans RLS 27 → 0 · policies 213 → 284 (28 permissives retirées, 99 posées) · droits d'écriture clients 233 → 132 |
| `20261006013000_autorite_rpc_sans_anon.sql` | 542 | fonctions mutantes appelables par `anon` 34 → 0 |
| `20261006160000_autorite_declencheurs_public.sql` | 543 | fonctions de déclencheur appelables par un rôle client 24 → 0 |
| `20261008214206_pays_declare_et_retrait_des_defauts_republic.sql` | 560 | `personnage_pays_declare()` + son déclencheur créés · `p_country text DEFAULT 'republic'` 11 → 0 · signatures 663 → 664 · droits EXECUTE des onze **restitués à l'identique**, ni perdu ni apparu · 3 commentaires reposés · `authenticated` sur les 7 fonctions de cron 7 → 0 |
| `20261008221846_defaut_des_privileges_de_fonction_ferme.sql` | 561 | ACL d'une fonction **neuve** : `PUBLIC authenticated postgres service_role` → **`postgres service_role`** · `has_function_privilege` rend désormais `false` pour `anon` et `authenticated` · droits des 664 fonctions existantes **inchangés** (37 / 58 / 421 / 664) · `catalogue_generiques_raccordes` passée en `security_invoker` (84 lignes avant comme après, pour les trois rôles) · `personnages` **non modifiée** |
| `20261008235521_idempotence_prets_helvetia.sql` | 562 | `traiter_prets_helvetia_quotidien` porte un marqueur de journée · trois appels le même jour prélèvent **une seule** mensualité (5000 → 4500 → 4500), le lendemain reprend (→ 4000) · verdict `deja_traite_aujourdhui` rendu · **et ses propres preuves ont laissé 1 000 FR dans `republic_banque-privee`, restitués dans la minute** — lire son en-tête |

La quatrième répare la première. La migration 1 avait révoqué `EXECUTE` sur ces
24 fonctions « FROM anon, authenticated » en laissant le `GRANT` à **PUBLIC**,
qui vaut pour tous les rôles : la révocation était sincère et sans effet. C'est
l'invariant 9 de `verifier-autorite.py`, relu après la réextraction du baseline,
qui l'a vu — il lit les droits tels qu'ils sont, pas tels qu'on a cru les
écrire. **Révoquer sur une fonction, c'est toujours `FROM PUBLIC` en plus des
rôles nommés.**

Les six premières n'ont touché aucune donnée : ni `INSERT`, ni `UPDATE` de
ligne, ni `DELETE`, ni `TRUNCATE`, ni `DROP TABLE`. Les 7 personnages de la bêta
sont intacts.

> **La septième, si — et il faut le dire ici et non seulement dans son en-tête.**
> `20261008235521_idempotence_prets_helvetia` a prouvé son effet en **faisant
> tourner la mécanique** : prêt témoin créé, RPC appelée quatre fois, témoin
> supprimé. Mais cette RPC crédite aussi la caisse de la banque privée à chaque
> prélèvement, et une migration **commite** — y compris les effets de bord de
> ses preuves, sur des tables auxquelles on ne pensait pas. 1 000 FR sont restés
> dans `republic_banque-privee` ; détectés par l'empreinte des caisses, qui ne
> correspondait plus, et restitués dans la minute à `{"solde": 0}`.
>
> **La règle qui en sort, et qui vaut pour toute migration future :** dans une
> migration, les preuves sont **structurelles** — lire le corps d'une fonction,
> compter des droits, vérifier une contrainte. L'épreuve **comportementale**
> appartient au banc en transaction annulée, avant application, et à lui seul.
> Les six premières respectaient déjà cette règle sans qu'elle soit écrite ;
> elle l'est maintenant.
