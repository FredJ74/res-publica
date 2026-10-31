-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261018210000_rue_sortie_batiment_autorite.sql ; aucun changement de règle.
-- Référentiel des sorties : lecture du noeud autorisé pour le personnage connecté.
-- Appliqué sur Supabase le 18 octobre 2026.
CREATE OR REPLACE FUNCTION public.rue_sortie_batiment_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_noeud text;
BEGIN
 v_nom := public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 IF v_pj.current_building IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_dans_un_batiment'); END IF;
 SELECT s.noeud INTO v_noeud FROM public.rue_sorties_batiments s
 JOIN public.rue_noeuds_serveur n ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
 WHERE s.country=v_pj.country AND s.city=v_pj.current_city AND s.building=v_pj.current_building
 ORDER BY (s.noeud=v_pj.current_street) DESC,s.noeud LIMIT 1;
 IF v_noeud IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sortie_non_referencee'); END IF;
 RETURN jsonb_build_object('ok',true,'noeud',v_noeud);
END;
$function$;
REVOKE ALL ON FUNCTION public.rue_sortie_batiment_lire() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rue_sortie_batiment_lire() TO authenticated;
