-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261027193000_hotels_nuitees_cumulables.sql ; aucun changement de règle.
-- #63 Droits de nuitees persistants, distincts des achats, livres uniquement par le serveur.
BEGIN;
CREATE TABLE IF NOT EXISTS public.hotel_nuitees (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 personnage_id uuid NOT NULL REFERENCES public.personnages_donnees(id),
 country text NOT NULL, city text NOT NULL, building_id text NOT NULL,
 pa_bonus integer NOT NULL CHECK (pa_bonus BETWEEN 0 AND 30),
 moral_bonus integer NOT NULL CHECK (moral_bonus BETWEEN 0 AND 100),
 reference text NOT NULL DEFAULT gen_random_uuid()::text,
 cree_le timestamptz NOT NULL DEFAULT now(),
 consommee_le date,
 UNIQUE(personnage_id,reference)
);
CREATE INDEX IF NOT EXISTS idx_hotel_nuitees_disponibles ON public.hotel_nuitees(personnage_id,building_id,cree_le) WHERE consommee_le IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_hotel_nuitees_repos_journalier ON public.hotel_nuitees(personnage_id,consommee_le) WHERE consommee_le IS NOT NULL;
ALTER TABLE public.hotel_nuitees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hotel_nuitees FROM PUBLIC,anon,authenticated;
-- Les deux droits historiques sont migres une fois, sans suppression du champ historique.
INSERT INTO public.hotel_nuitees(personnage_id,country,city,building_id,pa_bonus,moral_bonus,reference)
SELECT p.id,p.country,
 CASE WHEN p.reservation_hotel->>'buildingId'='hotel-republica' THEN 'capitale'
      WHEN p.reservation_hotel->>'buildingId'='hotel-port' THEN 'ville_a'
      ELSE p.current_city END,
 p.reservation_hotel->>'buildingId',
 COALESCE(h.montant,2),
 GREATEST(0,LEAST(100,COALESCE((p.reservation_hotel->'bonus'->>'moral')::integer,3))),
 'historique-20261027'
FROM public.personnages_donnees p
JOIN public.pa_bonus_hotel h ON h.building_id=p.reservation_hotel->>'buildingId'
WHERE jsonb_typeof(p.reservation_hotel)='object'
ON CONFLICT (personnage_id,reference) DO NOTHING;

CREATE OR REPLACE FUNCTION public.hotel_nuitee_ajouter_interne(p_acteur text,p_hotel text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record; n integer; ville text;
BEGIN
 SELECT id,country,current_city,current_building INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_hotel OR p_hotel NOT IN ('hotel-republica','hotel-port','hotel-mineur')
 THEN RAISE EXCEPTION 'hotel_reservation_lieu_invalide';END IF;
 SELECT montant INTO n FROM public.pa_bonus_hotel WHERE building_id=p_hotel;
 IF n IS NULL THEN RAISE EXCEPTION 'hotel_bonus_absent';END IF;
 INSERT INTO public.hotel_nuitees(personnage_id,country,city,building_id,pa_bonus,moral_bonus)
 VALUES(p.id,p.country,p.current_city,p_hotel,n,3);
 RETURN jsonb_build_object('ok',true,'hotel',p_hotel,'ville',p.current_city);
END;$f$;
REVOKE ALL ON FUNCTION public.hotel_nuitee_ajouter_interne(text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.hotel_reservations_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record; r jsonb;
BEGIN
 SELECT id INTO p FROM public.personnages_donnees WHERE name=public.mon_personnage() AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',n.id,'buildingId',n.building_id,'ville',n.city,
 'country',n.country,'bonus',jsonb_build_object('paBonus',n.pa_bonus,'moral',n.moral_bonus))
 ORDER BY n.cree_le,n.id),'[]'::jsonb) INTO r
 FROM public.hotel_nuitees n WHERE n.personnage_id=p.id AND n.consommee_le IS NULL;
 RETURN r;
END;$f$;
REVOKE ALL ON FUNCTION public.hotel_reservations_lire() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hotel_reservations_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.hotel_nuitee_consommation_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record;n record;out_pa integer;out_moral integer; today_paris date:=(now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
 SELECT id,country,current_city,current_building,current_room,pa_repos_le,pa,moral
 INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND OR p.pa_repos_le IS DISTINCT FROM today_paris THEN RETURN jsonb_build_object('ok',false,'raison','repos_non_valide');END IF;
 IF NOT ((p.current_building='hotel-republica' AND p.current_room='chambres')
 OR (p.current_building='hotel-port' AND p.current_room='chambre_port')
 OR (p.current_building='hotel-mineur' AND p.current_room='chambre_mineur')) THEN
 RETURN jsonb_build_object('ok',false,'raison','hors_chambre');END IF;
 SELECT * INTO n FROM public.hotel_nuitees WHERE personnage_id=p.id AND consommee_le=today_paris LIMIT 1;
 IF FOUND THEN
  IF n.country=p.country AND n.city=p.current_city AND n.building_id=p.current_building THEN
   RETURN jsonb_build_object('ok',true,'rejeu',true,'pa',p.pa,'moral',p.moral,
    'montant',n.pa_bonus,'moralBonus',n.moral_bonus,'hotel',n.building_id);
  END IF;
  RETURN jsonb_build_object('ok',false,'raison','nuit_deja_utilisee');
 END IF;
 SELECT * INTO n FROM public.hotel_nuitees
 WHERE personnage_id=p.id AND country=p.country AND city=p.current_city
 AND building_id=p.current_building AND consommee_le IS NULL
 ORDER BY cree_le,id LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','aucune_reservation'); END IF;
 UPDATE public.hotel_nuitees SET consommee_le=today_paris WHERE id=n.id;
 UPDATE public.personnages_donnees SET pa=LEAST(30,GREATEST(0,COALESCE(pa,0)+n.pa_bonus)),
 moral=LEAST(100,GREATEST(0,COALESCE(moral,0)+n.moral_bonus)),updated_at=now()
 WHERE id=p.id RETURNING pa,moral INTO out_pa,out_moral;
 RETURN jsonb_build_object('ok',true,'pa',out_pa,'moral',out_moral,
 'montant',n.pa_bonus,'moralBonus',n.moral_bonus,'hotel',n.building_id);
END;$f$;
REVOKE ALL ON FUNCTION public.hotel_nuitee_consommation_interne(text) FROM PUBLIC,anon,authenticated;
COMMIT;