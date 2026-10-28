-- Contrôle lecture seule des sorties et des montants bancaires.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT count(*) AS sorties_valides FROM public.rue_sorties_batiments s JOIN public.rue_noeuds_serveur n ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud WHERE s.country='republic' AND s.city='capitale';
SELECT count(*) AS prets_invalides FROM public.prets WHERE montant_initial<=0 OR montant_restant<0;
SELECT count(*) AS placements_invalides FROM public.placements_bancaires WHERE montant<0;
ROLLBACK;
