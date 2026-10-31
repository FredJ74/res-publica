-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261017180000_detention_jours_civils_universels.sql ; aucun changement de règle.
-- Une peine est comptée en passages de minuit Europe/Paris.
-- Le serveur conserve l'autorité et clôture atomiquement la détention.
CREATE OR REPLACE FUNCTION public.detention_clore_purgee()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text;
  v_peine jsonb;
  v_det record;
  v_debut_ts numeric;
  v_jours numeric;
  v_jour_debut date;
  v_jour_fin date;
  v_aujourdhui date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
  END IF;
  SELECT est_emprisonne INTO v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu');
  END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- Fail-closed si l'ancre est absente : aucune libération devinée.
  IF coalesce(v_peine->>'debutTs','') !~ '^[0-9]+(\.[0-9]+)?$'
     OR coalesce(v_peine->>'jours','') !~ '^[0-9]+(\.[0-9]+)?$' THEN
    RETURN jsonb_build_object('ok',false,'raison','ancre_calendaire_absente');
  END IF;
  v_debut_ts := (v_peine->>'debutTs')::numeric;
  v_jours := (v_peine->>'jours')::numeric;
  IF v_debut_ts <= 0 OR v_jours <= 0 OR v_jours > 36500 THEN
    RETURN jsonb_build_object('ok',false,'raison','ancre_calendaire_invalide');
  END IF;
  v_jour_debut := (to_timestamp(v_debut_ts / 1000) AT TIME ZONE 'Europe/Paris')::date;
  v_jour_fin := v_jour_debut + ceil(v_jours)::integer;
  IF v_aujourdhui < v_jour_fin THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_non_purgee',
                              'jour_fin',v_jour_fin,'aujourdhui',v_aujourdhui);
  END IF;
  RETURN public.detention_clore_interne(v_moi,'purgee')
         || jsonb_build_object('ok',true,'jour_fin',v_jour_fin);
END;
$function$;
