-- #295 — Prévol d'autorité financière des clubs et organisations.
-- Lecture seule. Aucun UPDATE ni changement de rôle/JWT en production.
-- Les règles RLS autorisent aujourd'hui tout personnage identifié à écrire,
-- sans rattacher la ligne au chef, au fondateur ou au club concerné.
-- Les RPC légitimes doivent être mises en place et éprouvées AVANT de fermer les accès.
SELECT c.relname AS table_cible,
       c.relrowsecurity AS rls_active,
       has_table_privilege('authenticated',c.oid,'SELECT') AS lecture,
       has_table_privilege('authenticated',c.oid,'INSERT') AS insertion,
       has_table_privilege('authenticated',c.oid,'UPDATE') AS modification,
       has_table_privilege('authenticated',c.oid,'DELETE') AS suppression
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('budgets_clubs','organisations','comptes_bancaires')
ORDER BY c.relname;

SELECT c.relname AS table_cible,p.polname,p.polcmd,
       pg_get_expr(p.polqual,p.polrelid) AS predicat,
       pg_get_expr(p.polwithcheck,p.polrelid) AS verification
FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('budgets_clubs','organisations')
ORDER BY c.relname,p.polname;

SELECT pg_get_functiondef(p.oid) AS acteur_identifie_implementation
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='acteur_identifie';

-- Contrôle uniquement des clés de JSON, aucune valeur ni identité copiée.
SELECT table_cible, cle, count(*) AS occurrence
FROM (
 SELECT 'budgets_clubs' AS table_cible,k AS cle
 FROM public.budgets_clubs b CROSS JOIN LATERAL jsonb_object_keys(b.data) k
 UNION ALL
 SELECT 'organisations',k
 FROM public.organisations o CROSS JOIN LATERAL jsonb_object_keys(o.data::jsonb) k
) champs
GROUP BY table_cible,cle
ORDER BY table_cible,cle;
