-- #110 : prevol STRICTEMENT LECTURE SEULE avant activation de la migration.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT p.oid::regprocedure AS rpc,md5(p.prosrc) AS empreinte,
 p.prosecdef AS privilegiée,
 has_function_privilege('anon',p.oid,'EXECUTE') AS accessible_anonyme,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS accessible_joueur
 FROM pg_proc p
 WHERE p.oid IN (
 to_regprocedure('public.acheter_produit_commerce(text,text,text,text,integer)'),
 to_regprocedure('public.consommer_sur_place_commerce(text,text,text,text)'));
SELECT id,data->>'enseigne' AS enseigne,
 data->'references'->'ref-9da82ecc5b7a4974b3b209678c2d66bd'->>'venteSurPlaceUniquement' AS fontaine_sur_place
 FROM public.entreprises WHERE id='fonds-republic-1791927686314-921164';
SELECT p.proname FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
 AND p.prosrc LIKE '%acheter_produit_commerce(%';
SELECT count(*) AS ventes,count(DISTINCT requete) AS operations_uniques FROM public.ventes_snapshots;
ROLLBACK;
