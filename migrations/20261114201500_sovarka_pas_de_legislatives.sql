-- Sovarka : pas de législatives (Fred, 07/11/2026, GAME-DESIGN-NOVOMIRSK.md) — les sièges du
-- Soviet Suprême sont répartis entre les partis à la semaine à la gloire, chaque chef désigne ses
-- députés. candidature_deposer refusait déjà les candidatures de député en Sovarka, mais
-- cycle_electoral_initialiser créait encore un cycle « soviet_depute_<ville> » dès qu'un PJ de
-- Sovarka ouvrait le calendrier ou la salle des élections (audit du 14/11/2026). Aucun cycle de
-- ce genre n'existe en production au 14/11 : la garde ferme la porte avant qu'il en naisse un.
CREATE OR REPLACE FUNCTION public.cycle_electoral_initialiser(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_city text; v_id text; v_data text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_poste NOT IN ('president', 'chef_syndicat', 'maire', 'depute') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_electif'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays = 'soviet' AND p_poste = 'depute' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'depute_designe_par_parti'); END IF;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN nullif(p_city, '') END;
  IF p_poste IN ('maire', 'depute') AND (v_city IS NULL OR v_city NOT IN ('capitale', 'ville_a', 'ville_b')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_invalide'); END IF;
  v_id := v_pays || '_' || p_poste || coalesce('_' || v_city, '');
  INSERT INTO public.cycles_electoraux (id, country, poste_id, city, data, updated_at)
    VALUES (v_id, v_pays, p_poste, v_city, public.cycle_electoral_frais_interne(p_poste, v_city, now())::text, now())
    ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.cycles_electoraux WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'cycle', v_data::jsonb);
END; $function$;

DO $$
BEGIN
  IF position('depute_designe_par_parti' in pg_get_functiondef('public.cycle_electoral_initialiser'::regproc)) = 0 THEN
    RAISE EXCEPTION 'cycle_electoral_initialiser : garde Sovarka absente'; END IF;
  IF EXISTS (SELECT 1 FROM public.cycles_electoraux WHERE country = 'soviet' AND poste_id = 'depute') THEN
    RAISE EXCEPTION 'cycle de législatives de Sovarka présent : à examiner avant de poursuivre'; END IF;
END $$;
