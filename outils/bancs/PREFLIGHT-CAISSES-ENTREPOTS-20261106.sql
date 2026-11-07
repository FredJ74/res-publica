-- Lecture seulement : à jouer en une transaction cohérente par l'intégrateur.
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
-- Les migrations sont identifiées par NOM, pas par présence d'un fichier dans migrations/.
SELECT version,name FROM supabase_migrations.schema_migrations
 WHERE name ~ '(entrepot.*caisse|budgets_municipaux_serveur|exportations_|entrepot_capacite_universelle)'
 ORDER BY version;
SELECT e.id,e.country,e.city,
 public.batiment_etat_lire(e.data)->'entrepot'->'caisse' AS ancien_solde,
 c.id AS caisse_id,c.data->'solde' AS solde_canonique
 FROM public.batiments_etat e
 LEFT JOIN public.caisses_batiments c ON c.id=public.entrepot_caisse_id(e.id)
 WHERE e.building_id LIKE 'entrepot-logistique-%'
 ORDER BY e.country,e.city,e.id;
-- Tous les corps potentiellement concurrents, y compris une redéfinition non archivée.
SELECT p.oid::regprocedure::text AS signature,md5(pg_get_functiondef(p.oid)) AS md5,
 pg_get_functiondef(p.oid) AS definition,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS client_executable
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND
 (p.proname ~ '(entrepot|exportation|trading|offre_achat|approvisionner_chantier|effort_ravitailler)'
  OR p.prosrc ~ 'entrepot.*caisse|caisse.*entrepot')
 ORDER BY p.oid::regprocedure::text;
ROLLBACK;
