-- Distillerie de Krasnov : le local loué devient la salle des ventes (le comptoir où le client achète).
-- Constat (audit du 14/11/2026) : depuis les trois salles illustrées (20261114170000), les ordres « Demande de location »
-- et « Ce commerce » figuraient aussi dans la salle des ventes, alors que le serveur rattache le local à l'atelier :
-- la demande y était refusée (local introuvable) et le commerce y paraissait absent.
-- Le local n'a ni bail, ni demande, ni commerce : on le déplace sans rien perdre. L'atelier et le bureau restent
-- visitables (décor et PNJ), sans ordre.
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
                  WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'distillerie-krasnov' AND pieces ? 'salle_ventes') THEN
    RAISE EXCEPTION 'Distillerie de Krasnov : salle des ventes absente de la navigation';
  END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_locaux
              WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'distillerie-krasnov' AND piece = 'atelier_distillerie'
                AND (demande_id IS NOT NULL OR public.sovarka_exploitant_interne(ville, batiment, piece) IS NOT NULL))
     OR EXISTS (SELECT 1 FROM public.sovarka_demandes
                 WHERE (local_souhaite_batiment = 'distillerie-krasnov' OR local_batiment = 'distillerie-krasnov')
                   AND statut NOT IN ('refusee', 'annulee'))
     OR EXISTS (SELECT 1 FROM public.locations_actives WHERE data->>'buildingId' = 'distillerie-krasnov') THEN
    RAISE EXCEPTION 'Distillerie de Krasnov : local déjà demandé ou exploité, déplacement refusé';
  END IF;
  UPDATE public.sovarka_locaux SET piece = 'salle_ventes'
   WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'distillerie-krasnov' AND piece = 'atelier_distillerie';
  IF (SELECT count(*) FROM public.sovarka_locaux WHERE batiment = 'distillerie-krasnov' AND piece = 'salle_ventes') <> 1
     OR EXISTS (SELECT 1 FROM public.sovarka_locaux WHERE batiment = 'distillerie-krasnov' AND piece <> 'salle_ventes') THEN
    RAISE EXCEPTION 'Distillerie de Krasnov : déplacement du local non confirmé';
  END IF;
END $$;

COMMIT;
