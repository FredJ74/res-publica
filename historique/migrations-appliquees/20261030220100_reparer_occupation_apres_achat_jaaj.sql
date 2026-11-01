-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030193635.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Réparation strictement ciblée : occupant créé sur le lot 5 après réservation notariée de Jean Jaaj.
-- Le code général est corrigé par sceller_occupation_achat_direct.
DO $fix$
DECLARE e jsonb; t text:='republic_terrain-a-batir-5'; n jsonb; v_count integer;
BEGIN
 SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=t FOR UPDATE;
 IF e IS NULL
 OR e->'achatDirect'->>'demandeur' IS DISTINCT FROM 'Jean Jaaj'
 OR e->>'pnj' IS DISTINCT FROM 'squatter_agr'
 OR e->>'dateGeneration' IS DISTINCT FROM '1793388777750'
 OR coalesce(e->>'occupationScellee','false') = 'true'
 OR (e->'achatDirect'->>'dateLimite')::numeric <= extract(epoch from clock_timestamp())*1000
 THEN RAISE EXCEPTION 'lot 5 : conditions de réparation non confirmées'; END IF;
 n := jsonb_build_object('pnj',NULL,'pnjData',NULL,'occupationScellee',true,'occupationInitialisee',true);
 PERFORM public.terrain_etat_fusionner_interne(t,n,'republic');
END $fix$;