-- Miroir du seul ordre service_etage declare dans data.js : 0 PA, 150 FR.
-- Corrige le refus payer_ordre pour ce service, sans prélever aucun compte.
BEGIN;
INSERT INTO public.ordres_couts (fn, pa, cost)
VALUES ('service_etage', 0, 150)
ON CONFLICT DO NOTHING;
DO $verification$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='service_etage' AND pa=0 AND cost=150)
 THEN RAISE EXCEPTION 'service_etage_cout_manquant'; END IF;
END;
$verification$;
COMMIT;
