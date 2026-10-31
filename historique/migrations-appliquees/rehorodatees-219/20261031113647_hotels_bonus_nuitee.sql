-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261027200700_hotels_bonus_nuitee.sql ; aucun changement de règle.
-- #63 : la nuitee payee est consommee uniquement apres repos reussi,
-- et son credit PA/Moral est atomique, idempotent en cas de reponse perdue.
CREATE OR REPLACE FUNCTION public.pa_bonus_chambre(p_acteur text,p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 SELECT current_building INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_batiment THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_dans_hotel');
 END IF;
 RETURN public.hotel_nuitee_consommation_interne(p_acteur);
END;$f$;
