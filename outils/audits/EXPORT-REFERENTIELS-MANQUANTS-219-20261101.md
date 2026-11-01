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
  'locale', (SELECT jsonb_build_object('collate',datcollate,'ctype',datctype,'provider',datlocprovider,'datlocale',COALESCE(to_jsonb(d)->>'datlocale',to_jsonb(d)->>'daticulocale'),'version',datcollversion,'version_actuelle',pg_database_collation_actual_version(oid)) FROM pg_database d WHERE datname=current_database()),
  'referentiels', jsonb_build_object(
    'postes_nommes_regles', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.postes_nommes_regles x),
    'chantiers_paliers', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.chantiers_paliers x),
    'entreprises_constantes', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.entreprises_constantes x),
    'recettes_commerce', (SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public.recettes_commerce x)
  )
) AS export_referentiels_manquants_219;
ROLLBACK;
```

## Transfert privé et reprise automatique

L'intégrateur disposant du connecteur peut joindre le résultat complet sous forme
**de fichier JSON dans la conversation**, sans le copier dans un commentaire de
PR, un commit, un gist public ou un journal Actions. Aucun compte ni secret dans
ce fichier. Les seules lignes autorisées sont les quatre tables de la requête.

Destination dans cet environnement : `/tmp/hg219-prives/referentiels-1012.json`
(répertoire privé, fichier mode 600). Le JSON accepte l'objet résultat direct ou
l'enveloppe `[ { "export_referentiels_manquants_219": { ... } } ]` émise par SQL.
Les nombres doivent rester des nombres JSON, pas des montants reformattés. La
locale contient désormais `datlocale`, `version` et `version_actuelle` : le nom
`en_US.UTF-8` et le fournisseur `i` ne suffisent pas à connaître la locale ICU
interne ni sa version. Conserver aussi `releve_le` et le registre.

Le pilote existant accepte maintenant `--referentiels-capture` avec ce chemin,
`--locale-provider icu`, `--locale-clone` et `--icu-locale` tirés du relevé.
Le binaire local compatible ICU est installé dans
`/workspace/hg-postgresql-17-icu/bin`. Ne pas déduire `--icu-locale` du nom libc.
Les autres arguments restent ceux du banc de livraison 95 documenté.

Le chargeur refuse un fichier dans le dépôt, toute table supplémentaire, toute
ligne incomplète et toute différence de registre/locale/empreinte. Il charge
exactement les lignes capturées et vide BNE seulement si son vide est attesté par
la référence inchangée. Les clés étrangères restent actives. Une erreur annule
les quatre tables. **Les douze empreintes complètes sont ensuite revérifiées**
par le garde d'origine ; le chargement n'accorde aucun succès par lui-même.
