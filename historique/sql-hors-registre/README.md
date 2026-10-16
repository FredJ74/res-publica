# Photographies SQL sans rattachement au registre vérifié

Archivées le 16 octobre 2026 depuis `sql/`, sans modifier un octet. Aucun SQL
n'a été exécuté. Ce dossier n'est ni un registre de migrations appliquées ni
une liste de migrations à appliquer.

Les commentaires des sources du 14 octobre affirment une installation dans
Supabase. Cette affirmation n'a pas pu être vérifiée dans cette session :
conserver les sources ne vaut pas attestation du registre réel. Ne pas les
rejouer automatiquement ; les confronter au catalogue et au registre avec le
connecteur, puis suivre `WORKFLOW-SUPABASE.md` pour toute évolution.

- `catalogue_pnj_statiques_republia_20261014.sql` : photographie du casting
  électoral, susceptible d'être antérieure aux changements de PNJ municipaux.
- `tractage_collectif_stade_20261014.sql` : trois fonctions, dont
  `tracts_electoraux_distribuer_collectif(text,text,text,text,text)` et ses droits.
  Les cinq paramètres correspondent à l'appel littéral du client.

SHA-256 avant/après identiques :

```text
catalogue_pnj_statiques_republia_20261014.sql : c9a2c87c004341724939d87c0a26f9379bbc04b2477eaf5c738eb91dac340980
tractage_collectif_stade_20261014.sql : acdccdb7296e02294516b3e0d461cc7184b05ee9c6cd67ed7272f93569db9d0a
```

Aucun code d'exécution ne chargeait ces chemins de fichiers. Leur déplacement
documentaire corrige le rangement du dépôt sans inventer une application.
