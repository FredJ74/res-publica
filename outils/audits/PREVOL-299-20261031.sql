-- PRÉVOL #299 + PRIME DE SIGNATURE (31/10/2026) — LECTURE SEULE, aucune écriture.
-- À jouer dans l'éditeur SQL Supabase (ou execute_sql) avant toute décision ; résultats attendus
-- relevés le 31/10/2026 vers 21 h 30 en commentaire.
BEGIN READ ONLY;

-- 1. Les deux préparations de #299 sont déjà au registre sous d'autres noms.
SELECT version, name FROM supabase_migrations.schema_migrations
 WHERE name ~ '(construction_materiaux_prix_et_dons|chantier_prix_representants|compromis_financement_reel)'
 ORDER BY version;
-- attendu : 20261023164824 construction_materiaux_prix_et_dons_94
--           20261023164942 chantier_prix_representants_94
--           20261025190210 compromis_financement_reel_135

-- 2. Leurs propres gardes d'empreinte échoueraient : les corps vivants ont changé depuis.
SELECT p.oid::regprocedure AS fonction, md5(p.prosrc) AS empreinte,
       p.prosrc ~* '(update|insert\s+into)\s+(public\.)?personnages([^_a-z0-9]|$)' AS ecrit_par_la_vue,
       p.prosrc ~* 'personnages_donnees' AS ecrit_la_table
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
 WHERE p.proname IN ('vendre_materiaux_chantier', 'chantier_prix_definir', 'compromis_expire_resoudre', 'chantier_lancer');
-- attendu : vendre_materiaux_chantier(6 args) 4da24ab0… (garde du fichier : 454957…/ad2871… → échec)
--           vendre_materiaux_chantier(7 args) 29869c27… (état final visé par le fichier : déjà là)
--           chantier_prix_definir 992a2563… (garde du fichier : 4dcd27… → échec)
--           compromis_expire_resoudre 5ae161c7… (garde du fichier : d3e35… ou e683b… → échec)
--           aucune n'écrit par la vue ; elles écrivent personnages_donnees.
SELECT to_regclass('public.chantier_requetes') AS table_requetes;   -- attendu : chantier_requetes

-- 3. Préconditions de 20261031220000 (prime de signature).
SELECT md5(regexp_replace(prosrc, E'\\n[ \\t]*--[^\\n]*', '', 'g')) AS conclure
  FROM pg_proc WHERE oid = 'public.club_transfert_conclure(text)'::regprocedure;   -- attendu 057d4b8e51e41eae3bc59d615a4df391
SELECT md5(regexp_replace(prosrc, E'\\n[ \\t]*--[^\\n]*', '', 'g')) AS garde, prosecdef
  FROM pg_proc WHERE oid = 'public.transferts_clubs_garder()'::regprocedure;       -- attendu 57b1fac354c1140d9644954909424b1f, false
SELECT has_function_privilege('authenticated', 'public.assemblee_crediter_joueur(text,integer)', 'EXECUTE') AS credit_expose,
       has_function_privilege('anon', 'public.club_transfert_conclure(text)', 'EXECUTE') AS conclure_anon;  -- attendu false, false
SELECT statut, count(*) AS n, count(*) FILTER (WHERE data ? 'prixJoueur') AS avec_prime
  FROM public.transferts_clubs GROUP BY statut;                                    -- 31/10 : aucune ligne

ROLLBACK;
