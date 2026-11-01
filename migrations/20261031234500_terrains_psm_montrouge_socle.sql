-- Audit des bâtiments de Montrouge et Port-Sainte-Marie par rapport au socle de Luthécia
-- (Claude, 01/11/2026). Indépendante de l'écran ; aucune donnée de joueur touchée.
--
-- Constat en production (31/10, 23 h) : terrains_etat ne contient que les cinq lots de Luthécia.
-- terrain_occupation_lire et terrain_acquisition_commande répondent « terrain_introuvable »
-- sur les dix parcelles de Montrouge et de PSM : aucune ne peut être visitée ni achetée,
-- y compris par la commune. De plus, le référentiel n'a pas de surface pour les quatre lots
-- de PSM ni pour le lot 6 de Montrouge (« prix_ou_surface_non_reference »).
--
-- Décisions de Fred (01/11/2026) : lots 8 à 11 de PSM à 1 500 m² et 12 FR/m² (18 000 FR) ;
-- lot 6 de Montrouge à 2 100 m² (25 200 FR). Le gabarit lot 6 est partagé : le référentiel
-- des trois autres empires suit data.js, comme le générateur generer_terrains_occupation.cjs.
--
-- 1. référentiel aligné sur le générateur ; 2. état initial vierge des dix parcelles, au format
-- des lots de Luthécia (ville, surface, valeur, constructionAutorisee=false ; l'occupation est
-- tirée par le serveur à la première visite) ; 3. miroir des coûts : (acheter_terrain, 2, 25200)
-- et (service_etage, 0, 50) déclarés, (acheter_terrain, 2, 3500) et (corrompre_chantier, 2, 1500) retirés, plus aucun
-- ordre ne les déclare.
BEGIN;

UPDATE public.terrains_referentiel r SET surface=v.surface, prix_achat=v.prix
FROM (VALUES
 ('republic','ville_a','terrain-a-batir-8',1500,18000),
 ('republic','ville_a','terrain-a-batir-9',1500,18000),
 ('republic','ville_a','terrain-a-batir-10',1500,18000),
 ('republic','ville_a','terrain-a-batir-11',1500,18000),
 ('republic','ville_b','terrain-a-batir-6',2100,25200),
 ('khalija','capitale','terrain-a-batir-6',2100,25200),
 ('narco','capitale','terrain-a-batir-6',2100,25200),
 ('soviet','capitale','terrain-a-batir-6',2100,25200)
) AS v(pays,ville,batiment,surface,prix)
WHERE r.pays=v.pays AND r.ville=v.ville AND r.batiment=v.batiment;

INSERT INTO public.terrains_etat(id,country,building_id,proprietaire,data,updated_at)
SELECT 'republic_'||r.batiment,'republic',r.batiment,NULL,
       jsonb_build_object('city',r.ville,'surface',r.surface,'valeur_totale',r.prix_achat,
                          'constructionAutorisee',false)::text,
       now()
FROM public.terrains_referentiel r
WHERE r.pays='republic' AND r.ville IN ('ville_a','ville_b')
ON CONFLICT (id) DO NOTHING;

-- Service d'étage des hôtels de province à 50 FR (décision de Fred, 01/11/2026), même audit.
INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('acheter_terrain',2,25200),('service_etage',0,50)
ON CONFLICT DO NOTHING;
DELETE FROM public.ordres_couts WHERE (fn,pa,cost) IN (('acheter_terrain',2,3500),('corrompre_chantier',2,1500));

DO $verification$
BEGIN
 IF EXISTS (SELECT 1 FROM public.terrains_referentiel
            WHERE pays='republic' AND (surface IS NULL OR prix_achat IS NULL)) THEN
  RAISE EXCEPTION 'referentiel_republia_incomplet';
 END IF;
 IF (SELECT count(*) FROM public.terrains_referentiel r JOIN public.terrains_etat t
       ON t.id='republic_'||r.batiment AND t.country='republic' AND t.building_id=r.batiment
      WHERE r.pays='republic' AND (t.data::jsonb)->>'city'=r.ville) <> 15 THEN
  RAISE EXCEPTION 'parcelles_republia_sans_etat';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='acheter_terrain' AND pa=2 AND cost=25200)
    OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='service_etage' AND pa=0 AND cost=50)
    OR EXISTS (SELECT 1 FROM public.ordres_couts WHERE (fn,pa,cost) IN (('acheter_terrain',2,3500),('corrompre_chantier',2,1500))) THEN
  RAISE EXCEPTION 'miroir_couts_terrains_divergent';
 END IF;
END;
$verification$;

COMMIT;
