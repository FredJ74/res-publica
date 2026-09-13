# Sauvegarde de la bêta — 13 septembre 2026

## Sauvegarde principale : DANS LA BASE
Schéma `sauvegarde_beta_20260913` — **119 tables sur 119**, copie intégrale prise
juste avant la réinitialisation. Zéro écart de comptage. Exploitabilité prouvée :
`personnages` restauré dans une table jetable, 15/15 lignes, 0 manquante, 0 en trop,
empreintes MD5 identiques.

Restauration d'une table :
    INSERT INTO public.<table> SELECT * FROM sauvegarde_beta_20260913.<table>;

Le schéma est révoqué pour anon et authenticated : seul le serveur y accède.

## Relevé hors base (second exemplaire)
`personnages.json` — état des 15 personnages au moment du reset.
