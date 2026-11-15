-- Krasnov : quatre bureaux individuels de même catégorie, seuls à remplacer
-- les trois bureaux du gabarit partagé pour cette ville. Ne pas modifier les baux.
BEGIN;
DO $$
DECLARE actuelle jsonb;
BEGIN
 SELECT pieces INTO actuelle FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-affaires' FOR UPDATE;
 IF actuelle IS DISTINCT FROM '["hall","bureau_prestige","bureau_standard","open_space","tribune_republia"]'::jsonb
 THEN RAISE EXCEPTION 'Le parcours du centre d affaires de Krasnov a évolué : migration suspendue'; END IF;
 IF EXISTS (SELECT 1 FROM public.locations_actives
   WHERE country='soviet' AND data->>'city'='ville_b' AND data->>'buildingId'='centre-affaires'
   AND data->>'roomId' IN ('bureau_prestige','bureau_standard','open_space','tribune_republia'))
 THEN RAISE EXCEPTION 'Baux actifs sur les anciens bureaux : migration suspendue'; END IF;
 IF EXISTS (SELECT 1 FROM public.locations_archives
   WHERE country='soviet' AND city='ville_b' AND building_id='centre-affaires'
   AND room_id IN ('bureau_prestige','bureau_standard','open_space','tribune_republia'))
 THEN RAISE EXCEPTION 'Historique de baux existant sur les anciens bureaux : arbitrage requis'; END IF;
END $$;
UPDATE public.navigation_lieux_regles
SET pieces='["hall","bureau_1","bureau_2","bureau_3","bureau_4"]'::jsonb
WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-affaires';
INSERT INTO public.locaux_loyers_referentiel
(batiment,piece,ville,prix,bonus_pop,bonus_inf,bonus_dis,label,louable,signature_serveur)
SELECT 'centre-affaires','bureau_'||n,'ville_b',prix,bonus_pop,bonus_inf,bonus_dis,
       'Bureau '||n,true,true
FROM public.locaux_loyers_referentiel
CROSS JOIN generate_series(1,4) AS n
WHERE batiment='centre-affaires' AND piece='bureau_standard' AND ville='*'
ON CONFLICT (batiment,piece,ville) DO NOTHING;
DO $$
BEGIN
 IF (SELECT count(*) FROM public.locaux_loyers_referentiel
 WHERE batiment='centre-affaires' AND ville='ville_b'
   AND piece IN ('bureau_1','bureau_2','bureau_3','bureau_4')
   AND prix=500 AND louable AND signature_serveur) <> 4
 OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-affaires'
 AND pieces='["hall","bureau_1","bureau_2","bureau_3","bureau_4"]'::jsonb)
 THEN RAISE EXCEPTION 'Contrôle des quatre bureaux de Krasnov échoué'; END IF;
END $$;
COMMIT;
