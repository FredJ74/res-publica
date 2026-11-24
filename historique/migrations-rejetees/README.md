# Migrations rejetées (jamais appliquées)

Fichiers retirés de `migrations/` parce que Fred les a rejetés. Ils ne figurent pas dans le registre de production
(`supabase_migrations.schema_migrations`, vérifié en lecture le 24/11/2026) : les retirer ne change rien à
l'historique des migrations appliquées. Ils sont gardés ici pour mémoire ; ne jamais les remettre dans `migrations/`.

| Fichier | Auteur | Motif du rejet | Retiré le |
|---|---|---|---|
| `20261123170047_plan_renommage_images_non_appliquee.sql` | Codex, 23/11/2026 | Plan de renommage en masse des chemins d'images rejeté par Fred (mission Purge, point 1.5). Les vraies fautes de noms d'images sont corrigées une à une, avec redirections (point E.2). | 24/11/2026 |
