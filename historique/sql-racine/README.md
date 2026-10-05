# Les SQL qui vivaient à la racine du dépôt

Archive. **Rien ici n'est rejouable, et rien ici ne doit l'être.**

Ces fichiers encombraient la racine du dépôt jusqu'au 5 octobre 2026. C'est
cette dispersion qui a rendu l'histoire du schéma illisible : des fichiers sans
ordre d'application, sans garantie d'avoir été appliqués, et impossibles à
distinguer des brouillons posés à côté.

Ils sont conservés parce qu'ils sont une **trace** — on y lit l'intention d'une
époque, et plusieurs commentaires du code les citent par leur nom. Ils ne sont
pas une chaîne de reconstruction.

## `migrations/` — 184 fichiers

Les migrations historiques du projet, telles qu'elles ont été écrites.

**Pourquoi elles ne sont pas rejouables** : **162 des 184** dépendent d'une
table qu'aucune d'elles ne crée. Les rejouer échouerait sur la première. La
période fondatrice, du 31 mai au 15 août 2026, n'a produit **aucun** fichier
SQL — le premier fichier du dépôt date du 15 août, alors que le projet a
commencé le 31 mai.

**Leur présence ici ne prouve pas qu'elles ont été appliquées.** La seule trace
d'application qui compte est le registre Supabase, archivé à part dans
`../registre-supabase/` — 539 entrées, dont la correspondance avec ces 184
fichiers est partielle.

## `non-appliquees/` — 3 fichiers

Deux propositions d'architecture et un banc d'essai, du 26 septembre 2026. Ils
**se déclarent eux-mêmes non appliqués**, en en-tête :

- `PROPOSITION_socle_pnj_groupes.sql` — « CE FICHIER N'EST PAS APPLIQUÉ. AUCUNE
  LIGNE N'A ÉTÉ EXÉCUTÉE EN PRODUCTION. »
- `PROPOSITION_socle_pnj_migration_soldats.sql` — l'outillage de copie,
  comparaison et rollback des soldats, éprouvé dans un schéma jetable
  `banc_pnj` contre les 96 soldats réels lus en lecture seule.
- `banc_socle_pnj.sql` — le banc automatisé : il monte le socle complet dans un
  schéma jetable et joue 22 cas dessus.

Ces trois fichiers valent d'être gardés **comme modèles de méthode** : c'est
ainsi qu'on éprouve une bascule lourde sans toucher à la production. Le
processus les cite d'ailleurs en exemple (`../../WORKFLOW-SUPABASE.md`, temps 3).

Ce qui a réellement été appliqué lors de cette bascule est documenté à part,
dans `MIGRATIONS_socle_pnj_appliquees_20260926.md`, resté à la racine du dépôt.

## Et maintenant

Les évolutions futures vivent dans `migrations/`, à la racine du dépôt, une par
fichier horodaté, et chacune est suivie d'une réextraction du baseline. Le
processus complet est dans `WORKFLOW-SUPABASE.md`.

`outils/baseline/verifier-workflow.py` refuse qu'un `.sql` réapparaisse à la
racine, et vérifie que cette archive reste complète.
