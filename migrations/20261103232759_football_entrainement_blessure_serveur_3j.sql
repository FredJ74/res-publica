-- #309. Modifie UNIQUEMENT la blessure d'entrainement football.
-- Paiement/limite et blessure atomiques. Pas de retouche retroactive PJ.
-- La blessure de match ne fait PAS partie de ce ticket.
CREATE OR REPLACE FUNCTION public.football_entrainement_consommer(p_stat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2;
        v_moi text; v_jour integer; v_nb integer; v_paie jsonb; v_id text;
        v_blesse boolean; v_grave boolean := false; v_duree integer := 0;
        v_degats integer := 0; v_hp integer; v_blessure jsonb := null;
BEGIN
  IF p_stat NOT IN ('defense','technique','endurance') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stat_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- DOUBLE CLIC : le second appel attend ici, puis constate la limite.
  PERFORM pg_advisory_xact_lock(hashtext('football_entrainement|' || v_moi));

  SELECT public.jour_de_jeu_pays(d.country) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_nb := public.football_entrainements_compter_interne(v_moi,(now() AT TIME ZONE 'Europe/Paris')::date);

  IF v_nb >= c_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'limite_quotidienne_atteinte',
                              'nb', v_nb, 'max', c_max, 'jour', v_jour);
  END IF;

  -- LE PAIEMENT EN DERNIER, ET PAR L'AUTORITE HABITUELLE (miroir des couts + verrou).
  v_paie := public.payer_ordre(v_moi, 'tenue_entrainement', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'));
  END IF;

  v_id := 'ef-' || (extract(epoch from clock_timestamp())*1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.entrainements_football (id, personnage, jour, stat)
  VALUES (v_id, v_moi, v_jour, p_stat);

  -- Le hasard et la persistance de la blessure appartiennent à la même
  -- transaction que l'entraînement. L'écran ne tire plus le résultat.
  v_blesse := random() < 0.05;
  IF v_blesse THEN
    v_grave := random() < 0.30;
    -- Nouvelle règle : 3 jours maximum, même en cas de gravité élevée.
    -- Blessure légère : 2 ou 3 jours, taux/gravité/PV inchangés.
    v_duree := CASE WHEN v_grave THEN 3 ELSE 2 + floor(random() * 2)::integer END;
    v_degats := CASE WHEN v_grave THEN 30 ELSE 15 END;
    v_blessure := jsonb_build_object(
      'jusquauJour', v_jour + v_duree,
      'gravite', CASE WHEN v_grave THEN 'grave' ELSE 'legere' END);
    UPDATE public.personnages_donnees
       SET blessure_sportive = v_blessure,
           hp = greatest(1,coalesce(hp,100) - v_degats)
     WHERE name = v_moi
     RETURNING hp INTO v_hp;
    IF NOT FOUND THEN RAISE EXCEPTION 'football_personnage_introuvable_apres_paiement'; END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'nb', v_nb + 1, 'max', c_max,
                            'jour', v_jour, 'pa', v_paie->'pa',
                            'blesse', v_blesse, 'blessure', v_blessure,
                            'duree', v_duree, 'degatsPV', v_degats, 'hp', v_hp);
END;
$function$;
