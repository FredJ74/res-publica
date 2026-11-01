-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025002311.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025002311.
-- Eprouvee avant application en transaction annulee (visiteur avec audience, ambassadeur en poste).
-- Baseline NON reextrait (comme les autres migrations de ce repertoire).
-- ============================================================================
-- ACCES AUX TROIS BUREAUX D'AMBASSADE, EN UNE LECTURE (25 octobre 2026, arbitrage de Fred)
-- ============================================================================
-- Les trois portes du hall deviennent cliquables, et leurs onglets aussi. Au survol, l'ecran
-- doit dire si la porte s'ouvre pour ce joueur ; sans invitation : « Acces limite : il faut
-- avoir une invitation. » Ce que l'ecran affiche vient d'ici, et nulle part ailleurs.
--
-- ONT ACCES (decision de Fred) : une audience accordee et non expiree ; l'immunite
-- diplomatique (le joueur ambassadeur en poste) ; le statut de refugie politique (a brancher
-- avec le chantier de l'asile, qui remplacera cette fonction).
--
-- ambassade_acces_bureau(p_empire) reste l'autorite au moment d'entrer : cette lecture ne sert
-- qu'a l'affichage, et la porte re-verifie toujours.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureaux()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb := '{}'::jsonb; e text; v_expire timestamptz;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  FOREACH e IN ARRAY ARRAY['khalija','soviet','narco'] LOOP
    IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                WHERE a.pays_hote = v_pays AND a.empire = e AND a.data ->> 'ambassadeur' = v_moi) THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'immunite'));
      CONTINUE;
    END IF;
    SELECT expire_le INTO v_expire FROM public.ambassades_audiences
     WHERE demandeur = v_moi AND empire = e AND statut = 'accordee' AND expire_le > now();
    IF v_expire IS NOT NULL THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'audience', 'expire_le', v_expire));
    ELSE
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', false));
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'bureaux', v_res);
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_acces_bureaux() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_acces_bureaux() TO authenticated;
