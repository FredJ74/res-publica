# res-publica
Jeu de rôle de parodie politique

## Faire évoluer la base

Le schéma PostgreSQL a un **état canonique**, dans `baseline/`, extrait des
catalogues de la base elle-même. Toute évolution part de là.

**Avant de toucher à Supabase, lire [`WORKFLOW-SUPABASE.md`](WORKFLOW-SUPABASE.md).**

En une commande, les huit contrôles :

```
python3 outils/baseline/controler-tout.py
```
