-- Camion militaire de Novomirsk : NAZ-66 « Bourlak » (Fred, 13/11/2026, 23 h 18 – 23 h 34, feu vert 23 h 34 ;
-- GAME-DESIGN-NOVOMIRSK.md, « Camion militaire de Novomirsk »).
-- Socle du camion de Républia, sans mécanique nouvelle : une ligne de données pour le camion de l'armée de
-- Sovarka, garé au corps de garde de la caserne de Novomirsk (25 places, comme en Républia), et ses deux
-- destinations hors de sa caserne : Starovka (Poste de Vigilance Glaciale) et Krasnov (station radar).
-- Le goulag sera ajouté à la fin de Sovarka (lieu non encore créé).
INSERT INTO public.camions_militaires (id, pays, institution, perimetre, libelle, capacite, image_url,
       caserne_ville, caserne_building, caserne_room, caserne_libelle, ville, building_id, room_id, statut)
VALUES ('camion-soviet-caserne-novomirsk-1', 'soviet', 'militaire', 'caserne-novomirsk', 'NAZ-66 « Bourlak »', 25,
        'images/Sovarka/Novomirsk/Novomirsk_camion_NAZ66_interieur.webp',
        'capitale', 'caserne-militaire', 'corps_garde', 'Caserne centrale de Novomirsk',
        'capitale', 'caserne-militaire', 'corps_garde', 'actif')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.camions_destinations (pays, cle, ville, building_id, room_id, libelle, rang) VALUES
  ('soviet', 'starovka_poste_vigilance', 'ville_a', 'poste-vigilance-glaciale', 'salle_ecoute', 'Poste de Vigilance Glaciale (Starovka)', 1),
  ('soviet', 'krasnov_station_radar', 'ville_b', 'station-radar-krasnov', 'salle_ecoute', 'Station radar de Krasnov', 2)
ON CONFLICT (pays, cle) DO NOTHING;

DO $preuve$
BEGIN
  IF (SELECT count(*) FROM public.camion_destinations('camion-soviet-caserne-novomirsk-1')) <> 2 THEN
    RAISE EXCEPTION 'destinations du camion de Novomirsk incomplètes'; END IF;
  IF EXISTS (SELECT 1 FROM public.camion_destinations('camion-soviet-caserne-novomirsk-1') d
              LEFT JOIN public.navigation_lieux_regles n ON n.pays = 'soviet' AND n.ville = d.ville AND n.batiment = d.building_id
             WHERE d.cle <> '__caserne__' AND NOT coalesce(n.pieces ? d.room_id, false)) THEN
    RAISE EXCEPTION 'destination non référencée dans la navigation'; END IF;
  IF (SELECT count(*) FROM public.camions_destinations WHERE pays = 'republic') <> 4 THEN
    RAISE EXCEPTION 'destinations de la Républia modifiées'; END IF;
END $preuve$;
