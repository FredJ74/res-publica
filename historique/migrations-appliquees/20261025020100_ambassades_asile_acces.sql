-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025004941.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025004941.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait.
-- ============================================================================
-- ASILE POLITIQUE -- 2/3 : le refugie entre dans le bureau de son ambassade, les decisions
-- sont constatees aux memes passages que les audiences. Remplace quatre fonctions des
-- migrations 20261024184600 et 20261025010000, a l'identique sauf l'ajout du refuge.
-- Depend de 20261025020000_ambassades_asile.sql. Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.ambassade_acces_bureau(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_expire timestamptz;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF public.ambassade_identite(p_empire) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
              WHERE a.pays_hote = v_pays AND a.empire = p_empire
                AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'ambassadeur');
  END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  IF public.ambassade_refuge_de(v_moi) = p_empire THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'refugie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT expire_le INTO v_expire FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut = 'accordee' AND expire_le > now();
  IF v_expire IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'audience', 'expire_le', v_expire);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sur_audience');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_acces_bureau(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_acces_bureau(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.ambassade_acces_bureaux()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb := '{}'::jsonb; e text; v_expire timestamptz; v_refuge text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  PERFORM public.ambassades_asiles_echoir(v_moi);
  v_refuge := public.ambassade_refuge_de(v_moi);
  FOREACH e IN ARRAY ARRAY['khalija','soviet','narco'] LOOP
    IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                WHERE a.pays_hote = v_pays AND a.empire = e AND a.data ->> 'ambassadeur' = v_moi) THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'immunite'));
      CONTINUE;
    END IF;
    IF v_refuge = e THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'refugie'));
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

-- MES AUDIENCES rend aussi l'asile : `en_attente` compte les demandes d'audience ET d'asile
-- sans reponse, pour que la verification des mails rappelle le serveur tant qu'il en reste.
CREATE OR REPLACE FUNCTION public.ambassade_mes_audiences()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_liste jsonb; v_asile jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'empire', a.empire, 'statut', a.statut,
           'ambassadeur', public.ambassade_identite(a.empire) ->> 'ambassadeur',
           'demandee_le', a.demandee_le, 'accordee_le', a.accordee_le, 'expire_le', a.expire_le)
         ORDER BY a.demandee_le), '[]'::jsonb)
    INTO v_liste
    FROM public.ambassades_audiences a
   WHERE a.demandeur = v_moi AND a.statut IN ('demandee','accordee');
  SELECT jsonb_build_object('empire', s.empire, 'statut', s.statut, 'demandee_le', s.demandee_le, 'decide_le', s.decide_le)
    INTO v_asile
    FROM public.ambassades_asiles s
   WHERE s.demandeur = v_moi AND s.statut IN ('demandee','accorde') LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'audiences', v_liste, 'asile', v_asile,
    'en_attente', (SELECT count(*) FROM jsonb_array_elements(v_liste) e WHERE e ->> 'statut' = 'demandee')
                  + CASE WHEN v_asile ->> 'statut' = 'demandee' THEN 1 ELSE 0 END);
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_mes_audiences() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_mes_audiences() TO authenticated;

CREATE OR REPLACE FUNCTION public.ambassades_audiences_echoir_toutes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  RETURN jsonb_build_object('ok', true,
    'accordees', public.ambassades_audiences_echoir(NULL),
    'asiles', public.ambassades_asiles_echoir(NULL));
END; $function$;
REVOKE ALL ON FUNCTION public.ambassades_audiences_echoir_toutes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ambassades_audiences_echoir_toutes() TO service_role;
