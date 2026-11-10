-- Plafond de loyer des deux locaux à louer de Starovka : 30 PSK/jour au lieu de 50
-- (décision de Fred du 10/11/2026 : en Sovarka on gagne peu et on paie peu, sauf à Novomirsk).
-- Le loyer en cours est ramené sous le plafond s'il le dépasse (aucun cas au 10/11 : loyers à 0, locaux libres).
UPDATE public.sovarka_locaux
   SET plafond = 30,
       loyer = LEAST(loyer, 30)
 WHERE pays = 'soviet' AND ville = 'ville_a' AND batiment = 'locaux-starovka'
   AND piece IN ('local_1', 'local_2');
