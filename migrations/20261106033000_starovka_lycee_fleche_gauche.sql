-- Starovka : le retour lycée/commissariat vers mairie-marché se fait par la flèche gauche.
DO $starovka$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-lycee-commissariat'
   AND 'starovka-rue-mairie-marche'=ANY(voisins))
 THEN RAISE EXCEPTION 'starovka_lycee_mairie_lien_absent'; END IF;
 UPDATE public.rue_noeuds_serveur
 SET directions=jsonb_set(
   COALESCE(directions,'{}'::jsonb),
   '{liens}',
   '{"gauche":"starovka-rue-mairie-marche"}'::jsonb
 )
 WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-lycee-commissariat';
 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-lycee-commissariat'
   AND directions->'liens'='{"gauche":"starovka-rue-mairie-marche"}'::jsonb)
 THEN RAISE EXCEPTION 'starovka_lycee_fleche_gauche_non_appliquee'; END IF;
END $starovka$;
