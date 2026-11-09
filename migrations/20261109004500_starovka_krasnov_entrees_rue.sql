-- STAROVKA ET KRASNOV : ENTREES DES BATIMENTS DEPUIS LA RUE (Claude, 09/11/2026)
--
-- Fred a fait la navigation rue par rue des deux villes (images et fleches), mais seules la gare,
-- l'entrepot et le port (Starovka) et la gare, l'entrepot, le stade, le commissariat et la station
-- (Krasnov) avaient une sortie serveur. Les autres batiments du gabarit etaient donc inaccessibles :
-- mairie (demande de commerce, salle des partis), centres, terrain municipal, hotel.
-- Onze facades identifiees sur les images de Fred, chacune dans la rue qui porte son nom. Les pieces
-- sont deja autorisees (navigation_lieux_regles) ; aucune piece ni aucun ordre nouveau.
DO $entrees$
DECLARE attendu constant integer := 11;
BEGIN
  IF (SELECT count(*) FROM public.rue_noeuds_serveur WHERE country = 'soviet' AND noeud IN (
        'starovka-rue-hotel', 'starovka-rue-terrains', 'starovka-rue-stade', 'starovka-rue-mairie-marche',
        'starovka-rue-lycee-commissariat', 'starovka-rue-bureaux-caserne', 'krasnov-rue-terrains',
        'krasnov-centre-artisanal', 'krasnov-rue-immeubles-centre-commercial', 'krasnov-rue-mairie-place',
        'krasnov-rue-bureaux')) <> attendu THEN
    RAISE EXCEPTION 'noeuds de rue de Starovka ou Krasnov absents du serveur';
  END IF;

  INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
    ('soviet', 'ville_a', 'starovka-rue-hotel',                       'hotel-mineur'),
    ('soviet', 'ville_a', 'starovka-rue-terrains',                    'terrain-a-batir-3'),
    ('soviet', 'ville_a', 'starovka-rue-stade',                       'stade'),
    ('soviet', 'ville_a', 'starovka-rue-mairie-marche',               'mairie'),
    ('soviet', 'ville_a', 'starovka-rue-lycee-commissariat',          'commissariat-local'),
    ('soviet', 'ville_a', 'starovka-rue-bureaux-caserne',             'centre-affaires'),
    ('soviet', 'ville_b', 'krasnov-rue-terrains',                     'terrain-a-batir-2'),
    ('soviet', 'ville_b', 'krasnov-centre-artisanal',                 'centre-artisanal'),
    ('soviet', 'ville_b', 'krasnov-rue-immeubles-centre-commercial',  'centre-commercial'),
    ('soviet', 'ville_b', 'krasnov-rue-mairie-place',                 'mairie'),
    ('soviet', 'ville_b', 'krasnov-rue-bureaux',                      'centre-affaires')
  ON CONFLICT DO NOTHING;

  -- Chaque batiment raccorde a bien ses pieces autorisees dans sa ville.
  IF EXISTS (
    SELECT 1 FROM public.rue_sorties_batiments s
     WHERE s.country = 'soviet' AND s.city IN ('ville_a', 'ville_b')
       AND NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles r
                        WHERE r.pays = 'soviet' AND r.ville = s.city AND r.batiment = s.building)
  ) THEN RAISE EXCEPTION 'sortie vers un batiment sans pieces autorisees';
  END IF;
  IF (SELECT count(*) FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city IN ('ville_a', 'ville_b')) < 8 + attendu THEN
    RAISE EXCEPTION 'entrees de Starovka et Krasnov incompletes';
  END IF;
END
$entrees$;
