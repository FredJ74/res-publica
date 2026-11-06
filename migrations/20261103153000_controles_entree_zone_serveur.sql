-- =============================================================================================
-- PATROUILLE DU COUVRE-FEU ET DÉTACHEMENT « ARRÊTER » DANS LE DÉPLACEMENT SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Suite de 20261103140000 : la patrouille du couvre-feu et l'interception par un détachement en
-- mission « arrêter » étaient tirées au serveur, mais c'était l'écran qui les déclenchait à
-- l'entrée d'un bâtiment ou d'une pièce (un tricheur pouvait ne jamais les appeler).
-- Désormais la porte de déplacement intérieur (navigation_interieure) les joue elle-même, dans
-- la même transaction que le déplacement, pour le personnage qui se déplace :
--   . détachement « arrêter » : à chaque entrée dans une pièce, jet min(90, 30 + 2 × soldats) ;
--   . couvre-feu : seulement quand on change de bâtiment (comme l'écran : une vérification par
--     entrée dans un bâtiment), jet de 45 % aux heures et conditions d'origine.
-- L'arrestation éventuelle est rendue dans la réponse du déplacement (clé « arrestation »).
-- Les deux portes appelées par l'écran (couvre_feu_patrouille, militaire_detachement_arrestation)
-- sont fermées : un seul jet par entrée, celui du serveur.
-- Indépendante de l'écran pour l'arrestation elle-même ; l'écran déployé avec elle l'adopte.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.controle_couvre_feu_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE p record; v_cf jsonb; v_heure integer := extract(hour FROM now() AT TIME ZONE 'Europe/Paris'); v_arr jsonb;
BEGIN
  SELECT country, poste, requisition, est_emprisonne INTO p FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND OR p.est_emprisonne IS NOT NULL THEN RETURN NULL; END IF;
  SELECT b.data -> 'couvreFeu' INTO v_cf FROM public.budgets_nationaux b WHERE b.id = p.country;
  IF jsonb_typeof(v_cf) IS DISTINCT FROM 'object' OR NOT coalesce((v_cf ->> 'actif')::boolean, false)
     OR ((v_cf ->> 'dateFin') IS NOT NULL AND (extract(epoch FROM now()) * 1000) > (v_cf ->> 'dateFin')::numeric)
     OR NOT (v_heure >= 20 OR v_heure < 6)
     OR coalesce(p.poste ->> 'id', '') IN ('lieutenant', 'capitaine', 'commandant', 'min_def')
     OR coalesce(p.requisition ->> 'statut', '') IN ('convoque', 'affecte')
     OR random() >= 0.45 THEN
    RETURN NULL;
  END IF;
  v_arr := public.arrestation_flagrant_interne(p_nom, 'violation_couvre_feu', false, 'patrouille_couvre_feu');
  RETURN CASE WHEN coalesce((v_arr ->> 'ok')::boolean, false) THEN v_arr || jsonb_build_object('controle', 'couvre_feu') END;
END $$;

CREATE OR REPLACE FUNCTION public.controle_detachement_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE p record; v_n integer; v_arr jsonb;
BEGIN
  SELECT country, current_city, current_building, current_room, poste, est_emprisonne INTO p
    FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND OR p.est_emprisonne IS NOT NULL OR p.current_building IS NULL
     OR coalesce(p.poste ->> 'id', '') IN ('lieutenant', 'capitaine', 'commandant', 'min_def') THEN
    RETURN NULL;
  END IF;
  SELECT count(*)::integer INTO v_n
    FROM public.pnj_membres m
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
    JOIN public.compagnies_militaires c ON c.id = sm.compagnie_id
    CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
   WHERE m.famille = 'soldat' AND m.statut = 'actif' AND sm.en_reserve = false AND m.pays = p.country
     AND pe.ville = p.current_city AND pe.building_id = p.current_building AND pe.room_id = p.current_room
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.data -> 'sections') = 'array'
                                                         THEN c.data -> 'sections' ELSE '[]'::jsonb END) s
                  WHERE s ->> 'id' = sm.section_id AND s ->> 'mission' = 'arreter');
  IF v_n = 0 OR 1 + floor(random() * 100)::integer > least(90, 30 + v_n * 2) THEN RETURN NULL; END IF;
  v_arr := public.arrestation_flagrant_interne(p_nom, 'intrusion_zone_militaire', false, 'detachement_militaire');
  RETURN CASE WHEN coalesce((v_arr ->> 'ok')::boolean, false) THEN v_arr || jsonb_build_object('controle', 'detachement') END;
END $$;

-- La porte de déplacement intérieur de l'écran joue les deux contrôles après le déplacement.
CREATE OR REPLACE FUNCTION public.navigation_interieure(p_batiment text, p_piece text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text := public.mon_personnage(); v_avant text; v jsonb; v_arr jsonb;
BEGIN
  SELECT current_building INTO v_avant FROM public.personnages_donnees WHERE name = v_moi;
  v := public.navigation_commander_interne('piece', p_batiment, p_piece);
  -- controles_entree_zone_serveur_v1
  IF v_moi IS NOT NULL AND p_batiment IS NOT NULL AND coalesce((v ->> 'ok')::boolean, false) THEN
    v_arr := public.controle_detachement_interne(v_moi);
    IF v_arr IS NULL AND v_avant IS DISTINCT FROM p_batiment THEN
      v_arr := public.controle_couvre_feu_interne(v_moi);
    END IF;
    IF v_arr IS NOT NULL THEN v := v || jsonb_build_object('arrestation', v_arr); END IF;
  END IF;
  RETURN v;
END $$;

REVOKE ALL ON FUNCTION public.controle_couvre_feu_interne(text), public.controle_detachement_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.navigation_interieure(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.navigation_interieure(text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.couvre_feu_patrouille(), public.militaire_detachement_arrestation() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.navigation_interieure(text,text)', 'execute') THEN
    RAISE EXCEPTION 'navigation_interieure doit rester ouverte à authenticated';
  END IF;
  IF has_function_privilege('authenticated', 'public.couvre_feu_patrouille()', 'execute')
     OR has_function_privilege('authenticated', 'public.controle_couvre_feu_interne(text)', 'execute') THEN
    RAISE EXCEPTION 'contrôle du couvre-feu encore joignable par l''écran';
  END IF;
END $$;
