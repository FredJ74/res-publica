-- PNJ DE STAROVKA : RENOMMAGES (Fred, 18/11/2026, « Décisions du 18/11 », point 1 ; doublons de noms).
--  Commandant Gleb Ledokolov → Commandant Arseni Ledokolov (référent du commerce extérieur, titulaire PNJ du port) ;
--  Batbayar Dachiev → Tserenjav Dachiev (PNJ non référent, côté écran seulement).
-- Aucune donnée de joueur touchée. Idempotente.
BEGIN;
UPDATE public.pnj_referents SET referent_id = 'arseni_ledokolov'
 WHERE referent_id = 'gleb_ledokolov' AND NOT EXISTS (SELECT 1 FROM public.pnj_referents WHERE referent_id = 'arseni_ledokolov');
UPDATE public.titulaires_pnj SET nom_pnj = 'Commandant Arseni Ledokolov (PNJ)'
 WHERE id = 'soviet_capitaine_port_national' AND nom_pnj IS DISTINCT FROM 'Commandant Arseni Ledokolov (PNJ)';
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.pnj_referents WHERE referent_id = 'gleb_ledokolov')
     OR NOT EXISTS (SELECT 1 FROM public.pnj_referents WHERE referent_id = 'arseni_ledokolov')
     OR (SELECT nom_pnj FROM public.titulaires_pnj WHERE id = 'soviet_capitaine_port_national') IS DISTINCT FROM 'Commandant Arseni Ledokolov (PNJ)'
  THEN RAISE EXCEPTION 'starovka_renommages : controle structurel en echec'; END IF;
END $$;
COMMIT;
