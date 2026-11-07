-- Pouvoir en Sovarka, étape 6 (Fred, 07/11/2026, GAME-DESIGN-NOVOMIRSK.md) : le président de
-- Sovarka, sans pouvoir, a des avantages. Un repas gratuit par jour dans ses appartements du
-- Palais du Parti ; il peut y recevoir un invité et lui offrir à manger. Effets (choix de Fred,
-- 07/11) : ceux du dîner d'affaires, pour lui comme pour l'invité : +10 Santé, +2 Moral,
-- +5 INF, +3 PA au prochain Dormir (pa_bonus_differes source 'diner_affaires').

CREATE TABLE IF NOT EXISTS public.sovarka_repas_presidentiels (
  jour       date PRIMARY KEY,
  president  text NOT NULL,
  invite     text,
  requete    text NOT NULL,
  resultat   jsonb NOT NULL,
  cree_le    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_repas_presidentiels ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_repas_presidentiels FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_repas_presidentiel(p_requete text, p_invite text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_ligne record;
        v_invite text := nullif(btrim(coalesce(p_invite, '')), ''); v_bonus integer; v_r jsonb; v_moi_fiche record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;

  PERFORM pg_advisory_xact_lock(hashtext('sovarka_repas_presidentiel|' || v_jour::text));
  SELECT * INTO v_ligne FROM public.sovarka_repas_presidentiels WHERE jour = v_jour;
  IF FOUND THEN
    IF v_ligne.requete = p_requete AND v_ligne.president = v_moi THEN RETURN v_ligne.resultat || '{"rejeu":true}'; END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_pris_aujourdhui');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cycles_electoraux
                  WHERE id = 'soviet_president' AND data::jsonb ->> 'eluId' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_president');
  END IF;
  SELECT country, current_city, current_building, current_room INTO v_moi_fiche
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_moi_fiche.country IS DISTINCT FROM 'soviet' OR v_moi_fiche.current_city IS DISTINCT FROM 'capitale'
     OR v_moi_fiche.current_building IS DISTINCT FROM 'palais-presidentiel'
     OR v_moi_fiche.current_room IS DISTINCT FROM 'appartements_president' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF v_invite IS NOT NULL THEN
    IF v_invite = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'invite_invalide'); END IF;
    PERFORM 1 FROM public.personnages_donnees
      WHERE name = v_invite AND country = 'soviet' AND current_city = 'capitale'
        AND current_building = 'palais-presidentiel' AND current_room = 'appartements_president'
      FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'invite_absent'); END IF;
  END IF;

  SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'diner_affaires';
  IF v_bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'bonus_diner_incompatible'; END IF;
  UPDATE public.personnages_donnees
     SET hp = least(100, coalesce(hp, 100) + 10), moral = least(100, coalesce(moral, 75) + 2),
         resources = jsonb_set(coalesce(resources, '{}') - 'popBase' - 'infBase', '{inf}',
                               to_jsonb(least(100, coalesce((resources ->> 'inf')::numeric, 0) + 5)), true),
         bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_bonus), updated_at = now()
   WHERE name = v_moi OR name = v_invite;

  SELECT jsonb_build_object('ok', true, 'invite', v_invite, 'hp', hp, 'moral', moral,
                            'inf', (resources ->> 'inf')::numeric, 'bonus_pa_differe', bonus_pa_differe)
    INTO v_r FROM public.personnages_donnees WHERE name = v_moi;
  INSERT INTO public.sovarka_repas_presidentiels (jour, president, invite, requete, resultat)
  VALUES (v_jour, v_moi, v_invite, p_requete, v_r);
  IF v_invite IS NOT NULL THEN
    PERFORM public.mail_systeme_envoyer('Système', v_invite, 'Repas au Palais du Parti',
      v_moi || ', Président de la République de Sovarka, vous a offert un repas dans ses appartements '
      || '(+10 Santé, +2 Moral, +5 INF, +3 PA au prochain Dormir).');
  END IF;
  RETURN v_r;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_repas_presidentiel(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_repas_presidentiel(text, text) TO authenticated;
