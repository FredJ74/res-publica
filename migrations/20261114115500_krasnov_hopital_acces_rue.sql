-- Krasnov : accès à l'hôpital public depuis la place de la mairie.
-- Uniquement Sovarka / ville_b ; pas de changement aux salles, aux patients ou aux autres villes.
-- Le hotspot client est dans plateau-rue-centrale.js.
BEGIN;
DO $krasnov_hopital$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place'
 ) THEN RAISE EXCEPTION 'Rue de la mairie de Krasnov absente'; END IF;
 IF NOT EXISTS (
   SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_b' AND batiment='dispensaire-public-v'
     AND NOT ferme AND pieces @> '["attente","ehpad","chambre"]'::jsonb
 ) THEN RAISE EXCEPTION 'Hôpital de Krasnov absent ou pièces incomplètes'; END IF;

 INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
 VALUES ('soviet','ville_b','krasnov-rue-mairie-place','dispensaire-public-v')
 ON CONFLICT DO NOTHING;

 IF (SELECT count(*) FROM public.rue_sorties_batiments
     WHERE country='soviet' AND city='ville_b' AND building='dispensaire-public-v'
       AND noeud='krasnov-rue-mairie-place') <> 1
 THEN RAISE EXCEPTION 'Sortie d’hôpital de Krasnov non enregistrée'; END IF;
END
$krasnov_hopital$;
COMMIT;
