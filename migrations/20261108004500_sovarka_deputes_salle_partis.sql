-- Soviet Suprême retiré de Novomirsk (décision de Fred, 08/11/2026, GAME-DESIGN-NOVOMIRSK.md) :
-- pas de chambre des députés. Le chef de parti désigne ou retire ses députés depuis « Mon parti »,
-- dans la salle des partis d'une mairie de Sovarka. Seule la garde de lieu change.
CREATE OR REPLACE FUNCTION public.sovarka_depute_designer(p_nom text, p_retirer boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_parti text; v_d jsonb; v_g jsonb; v_liste jsonb; v_sieges integer;
        v_fiche record; v_nom text := btrim(coalesce(p_nom, ''));
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT o.id INTO v_parti FROM public.organisations o
   WHERE o.data::jsonb ->> 'type' = 'politique'
     AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = 'soviet'
     AND o.data::jsonb ->> 'chef' = v_moi
   ORDER BY o.created_at LIMIT 1;
  IF v_parti IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_parti'); END IF;
  -- Plus de chambre des députés (Fred, 08/11/2026) : désignation depuis « Mon parti », dans la
  -- salle des partis d'une des trois mairies de Sovarka (même garde que sovarka_parti_commande).
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                  WHERE name = v_moi AND country = 'soviet' AND current_room = 'salle_partis'
                    AND ((current_city = 'capitale' AND current_building = 'mairie-capitale')
                      OR (current_city IN ('ville_a', 'ville_b') AND current_building = 'mairie'))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  SELECT data::jsonb INTO v_d FROM public.cycles_electoraux WHERE id = 'soviet_gloire_partis' FOR UPDATE;
  v_g := coalesce(v_d -> 'gloire', '{}'::jsonb);
  v_sieges := coalesce((v_g -> 'sieges' ->> v_parti)::integer, 0);
  v_liste := CASE WHEN jsonb_typeof(v_g -> 'deputes' -> v_parti) = 'array' THEN v_g -> 'deputes' -> v_parti ELSE '[]'::jsonb END;

  IF p_retirer THEN
    IF NOT v_liste ? v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute_du_parti'); END IF;
    v_liste := v_liste - v_nom;
    UPDATE public.personnages_donnees SET poste_depute = NULL
     WHERE name = v_nom AND poste_depute ->> 'country' = 'soviet';
    PERFORM public.mail_systeme_envoyer('Système', v_nom, 'Soviet Suprême',
      v_moi || ', chef de votre parti, vous a retiré votre siège de député du Soviet Suprême.');
  ELSE
    IF v_sieges <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_siege'); END IF;
    IF jsonb_array_length(v_liste) >= v_sieges THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'sieges_pourvus', 'sieges', v_sieges);
    END IF;
    SELECT name, poste_depute INTO v_fiche FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
    IF public.sovarka_parti_de(v_nom) IS DISTINCT FROM v_parti THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_parti');
    END IF;
    IF v_fiche.poste_depute IS NOT NULL AND jsonb_typeof(v_fiche.poste_depute) = 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_depute');
    END IF;
    v_liste := v_liste || to_jsonb(v_nom);
    -- Registre (cycle) d'abord : personnages_attester_poste n'accepte la fiche qu'attestée.
    v_g := jsonb_set(v_g, '{deputes}', coalesce(v_g -> 'deputes', '{}'::jsonb) || jsonb_build_object(v_parti, v_liste));
    v_d := jsonb_set(v_d, '{gloire}', v_g);
    UPDATE public.cycles_electoraux SET data = v_d::text, updated_at = now() WHERE id = 'soviet_gloire_partis';
    UPDATE public.personnages_donnees
       SET poste_depute = jsonb_build_object('id', 'depute', 'name', 'Député du Soviet Suprême',
                                             'city', NULL, 'country', 'soviet', 'designePar', v_moi)
     WHERE name = v_nom;
    PERFORM public.mail_systeme_envoyer('Système', v_nom, 'Soviet Suprême',
      v_moi || ', chef de votre parti, vous a désigné(e) député(e) du Soviet Suprême.');
  END IF;

  IF p_retirer THEN
    v_g := jsonb_set(v_g, '{deputes}', coalesce(v_g -> 'deputes', '{}'::jsonb) || jsonb_build_object(v_parti, v_liste));
    UPDATE public.cycles_electoraux SET data = jsonb_set(v_d, '{gloire}', v_g)::text, updated_at = now()
     WHERE id = 'soviet_gloire_partis';
  END IF;
  RETURN jsonb_build_object('ok', true, 'parti', v_parti, 'deputes', v_liste, 'sieges', v_sieges);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_depute_designer(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_depute_designer(text, boolean) TO authenticated;
