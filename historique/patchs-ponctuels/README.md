# Les correctifs ponctuels

Archive. **342 scripts Python à usage unique**, écrits pour appliquer une
modification précise à un fichier du jeu, puis jamais rejoués.

| Préfixe | Nombre | Ce qu'ils faisaient |
|---|---|---|
| `patch_*.py` | 289 | ajouter un bâtiment, brancher un dialogue, poser un crochet, corriger un ordre |
| `fix_*.py` | 53 | réparer un défaut précis, souvent le lendemain du `patch_` qui l'avait introduit |

Ils vivaient à la racine du dépôt. Chacun lisait un `.js` ou un `.html`, y
appliquait une substitution, et réécrivait le fichier — le genre d'outil qui a
exactement une vie.

## Pourquoi ils sont archivés plutôt que supprimés

**Ils racontent l'histoire des chantiers.** Leurs noms disent ce qui a été fait
et dans quel ordre : `patch_01_innerhtml.py` puis `patch_02_textes_garde.py`,
`fix_hotel_republica.py` puis `_2` puis `_3`. Un `git log` le dirait aussi, mais
moins vite.

**Aucun n'est référencé nulle part.** Vérifié : aucun `.js`, `.json`, `.md`,
`.html` ni `.yml` du dépôt ne les mentionne, et aucun n'en importe un autre. Les
déplacer ne casse rien, et leur suppression ne gagnerait rien d'autre que du
vide.

## Ce qu'ils ne sont pas

Ni outils, ni générateurs, ni migrations. Les outils vivent dans `outils/`, les
générateurs reproductibles dans `outils/generateurs/`, et les migrations dans
`migrations/` — voir `../../WORKFLOW-SUPABASE.md`.

`outils/baseline/verifier-workflow.py` refuse qu'un `patch_*.py` ou un
`fix_*.py` réapparaisse à la racine.
