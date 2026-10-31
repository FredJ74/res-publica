# Correction de prévol du payeur #219 — 31/10/2026

La garde `migrations/20261031115805_transport_encaissement_existant.sql` teste **`md5(prosrc)`**, non `md5(pg_get_functiondef(...))`.

Lecture SQL réelle sur Supabase `jxpwoosmmhohoihxpbuc` :

```sql
SELECT md5(prosrc) AS source_md5,
       md5(pg_get_functiondef(p.oid)) AS definition_md5
FROM pg_proc p
WHERE oid = 'public.payer_ordre(text,text,integer,integer)'::regprocedure;
```

- Corps vivant : `5cf45c19e4b9559f6b29e2b9207d3969` — **déjà admis** par la garde #219.
- Définition complète : `37eca91d6eb08c2a6ea97cbe717a216a` — mesure différente, non comparable à la garde.
- Les deux fonctions `payer_ordre_interne(text,text,integer,integer)` et `payer_ordre_interne(text,text,integer,integer,integer)` sont absentes : cohérent avec l'état initial attendu.

**Conclusion bornée :** la prétendue collision d'empreinte payeur est une erreur de comparaison dans le précédent prévol. Il ne faut ni élargir ni supprimer les gardes de migration. Les autres préconditions du paquet 95, les contrôles 10/12 et la recette GoTrue restent non vérifiés. Aucune mutation de production.

Signalement #219 : https://github.com/FredJ74/res-publica/pull/219#issuecomment-6548347589
