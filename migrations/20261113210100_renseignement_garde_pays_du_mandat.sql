-- Un mandat ministeriel national ne suit pas le personnage lorsqu'il voyage.
-- La garde commune du renseignement controle le PAYS DU POSTE, et pas seulement son ID.
-- Les autres actes sovarkiens sont deja proteges par sovarka_titulaire_interne,
-- qui consulte postes_attribues avec country='soviet'.
CREATE OR REPLACE FUNCTION public.renseignement_lieu_refus_interne(p_nom text,p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $fn$
DECLARE
  v_ici_pays text;
  v_ici_bat text;
  v_ici_piece text;
  v_lieu text;
  v_poste text;
  v_pays_mandat text;
BEGIN
  SELECT country,current_building,current_room
    INTO v_ici_pays,v_ici_bat,v_ici_piece
    FROM public.personnages_donnees WHERE name=p_nom;
  IF v_ici_pays IS DISTINCT FROM p_pays THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_de_son_pays','pays_poste',p_pays);
  END IF;
  SELECT a.poste_id,a.pays INTO v_poste,v_pays_mandat
    FROM public.acteur_poste_courant() a WHERE a.nom=p_nom;
  IF v_pays_mandat IS DISTINCT FROM p_pays THEN
    RETURN jsonb_build_object('ok',false,'raison','mandat_autre_pays','pays_poste',v_pays_mandat);
  END IF;
  IF p_pays='soviet' THEN
    IF v_ici_bat IS DISTINCT FROM 'palais-gouvernement'
      OR NOT ((v_poste='min_def' AND v_ici_piece='bureau_min_def')
           OR (v_poste='min_int' AND v_ici_piece='bureau_min_int')) THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place','lieu','palais-gouvernement');
    END IF;
    RETURN NULL;
  END IF;
  v_lieu := CASE WHEN EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
      WHERE pays=p_pays AND batiment='siege-renseignement')
      THEN 'siege-renseignement' ELSE 'palais-gouvernement' END;
  IF v_ici_bat IS DISTINCT FROM v_lieu THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place','lieu',v_lieu);
  END IF;
  RETURN NULL;
END $fn$;
