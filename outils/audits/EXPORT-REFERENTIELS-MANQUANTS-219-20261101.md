# Extraction ciblée pour l’intégrateur — PR #219

Requête documentaire de lecture seule, à exécuter avec le connecteur autorisé.
Conserver le résultat hors du dépôt public. Aucune intervention demandée à Fred.

```sql
-- Lecture seule, destinée à l'intégrateur ayant le connecteur Supabase.
-- Résultat privé à transmettre hors dépôt public ; aucun personnage ni compte.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT jsonb_build_object(
  'releve_le', clock_timestamp(),
  'registre', (SELECT jsonb_build_object('lignes',count(*),'derniere',max(version)) FROM supabase_migrations.schema_migrations),
  'locale', (SELECT jsonb_build_object('collate',datcollate,'ctype',datctype,'provider',datlocprovider) FROM pg_database WHERE datname=current_database()),
  'referentiels', jsonb_build_object(
    'postes_nommes_regles', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.postes_nommes_regles x),
    'chantiers_paliers', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.chantiers_paliers x),
    'entreprises_constantes', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.entreprises_constantes x),
    'recettes_commerce', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.recettes_commerce x)
  )
) AS export_referentiels_manquants_219;
ROLLBACK;
```
