-- Nettoyage de la recompression ponctuelle des portraits (04/11/2026, Claude, #55/#60).
-- Opération terminée : 6 images réduites (portraits 6,8 Mo -> 0,48 Mo ; éditions 27,9 -> 9,4 Mo).
-- La fonction Edge `recompresser-portraits` est remplacée par une souche qui répond 410.
drop function if exists public.portraits_lourds_lister();
drop function if exists public.portraits_lourds_ignorer(text);
drop function if exists public.editions_portraits_lourds_lister();
drop function if exists public.editions_portraits_lourds_ignorer(text);
drop table if exists public.portraits_recompression_traites;
drop table if exists public.portraits_recompression;
