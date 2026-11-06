-- Sovarka : les trois villes au trading de matières premières, port industriel de Starovka en service
-- (Claude, 06/11/2026, demande de Fred).
--
-- 1. Entrepôt Logistique de Novomirsk : déjà raccordé à la navigation (vue 8), ordres « Bientôt disponible »
--    levés à l'écran. Ligne entrepots_par_ville, état et caisse propres. Directeur PNJ Boris Stockov (Fred).
-- 2. Entrepôt Logistique de Starovka (nouveau, copie de Krasnov) : entrée depuis la rue du port industriel.
--    Directeur PNJ Batzorig Palettov (nom proposé par Claude, à relire par Fred).
-- 3. Stocks de départ proposés par Claude, à relire par Fred (Krasnov reste agricole, choix de Fred du 05/11) :
--    Novomirsk industriel (métal, minerai, charbon, textile, bois) ; Starovka Grand Nord (pétrole, charbon,
--    bois, poisson, viande). Caisse 10 000 comme Krasnov. Toujours pas d'approvisionnement de nuit (économie
--    de Sovarka à décider) : la passe de minuit ne nourrit que les entrepôts de Républia.
-- 4. Port industriel de Starovka (`port-starovka`, déjà déclaré dans fret_port_interne le 05/11) : bâtiment
--    raccordé (quai, entrepôts de fret, douanes), entrée depuis la rue du port industriel. Sa présence dans
--    navigation_lieux_regles le met en service (fret_port_en_service_interne) : Sovarka peut désormais
--    recevoir des achats internationaux et des caisses expédiées, et expédier des caisses depuis Starovka.
-- Aucune donnée de Républia n'est touchée.

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_a', 'entrepot-logistique-starovka', '["salle_ventes", "bureau_direction"]'::jsonb, false, NULL),
  ('soviet', 'ville_a', 'port-starovka', '["quai_principal", "entrepot", "douanes"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'ville_a', 'starovka-rue-port-industriel', 'entrepot-logistique-starovka'),
  ('soviet', 'ville_a', 'starovka-rue-port-industriel', 'port-starovka')
ON CONFLICT DO NOTHING;

INSERT INTO public.entrepots_par_ville(pays, ville, building_id)
SELECT t.p, t.v, t.b FROM (VALUES ('soviet', 'capitale', 'entrepot-logistique-novomirsk'),
                                  ('soviet', 'ville_a',  'entrepot-logistique-starovka')) t(p, v, b)
 WHERE NOT EXISTS (SELECT 1 FROM public.entrepots_par_ville e WHERE e.pays = t.p AND e.ville = t.v);

INSERT INTO public.batiments_etat(id, country, city, building_id, data, updated_at) VALUES
  ('soviet_capitale_entrepot-logistique-novomirsk', 'soviet', 'capitale', 'entrepot-logistique-novomirsk',
   jsonb_build_object('entrepot', jsonb_build_object('stock', jsonb_build_object(
     'metal', 300, 'minerai', 400, 'charbon', 400, 'textile', 250, 'bois', 200))), now()),
  ('soviet_ville_a_entrepot-logistique-starovka', 'soviet', 'ville_a', 'entrepot-logistique-starovka',
   jsonb_build_object('entrepot', jsonb_build_object('stock', jsonb_build_object(
     'petrole', 600, 'charbon', 300, 'bois', 500, 'poisson', 300, 'viande', 200))), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.caisses_batiments(id, data, updated_at) VALUES
  ('soviet_entrepot_capitale', '{"solde": 10000}'::jsonb, now()),
  ('soviet_entrepot_ville_a',  '{"solde": 10000}'::jsonb, now())
ON CONFLICT (id) DO NOTHING;

DO $verif$
BEGIN
  IF (SELECT count(*) FROM public.entrepots_par_ville WHERE pays = 'soviet') <> 3
     OR public.entrepot_caisse_id('soviet_capitale_entrepot-logistique-novomirsk') IS DISTINCT FROM 'soviet_entrepot_capitale'
     OR public.entrepot_caisse_id('soviet_ville_a_entrepot-logistique-starovka') IS DISTINCT FROM 'soviet_entrepot_ville_a'
     OR NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = 'soviet_entrepot_capitale')
     OR NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = 'soviet_entrepot_ville_a')
     OR NOT public.fret_port_en_service_interne('soviet')
     OR NOT public.fret_port_en_service_interne('republic')
     OR (SELECT count(*) FROM public.rue_sorties_batiments
          WHERE country = 'soviet' AND city = 'ville_a' AND noeud = 'starovka-rue-port-industriel') <> 2 THEN
    RAISE EXCEPTION 'sovarka_entrepots_port_incomplet';
  END IF;
END $verif$;
