-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025210344.
-- Eprouvee apres application en transaction annulee (asile tranche par l ambassadeur joueur, statut, bureaux). Baseline NON reextrait.
-- ============================================================================
-- AMBASSADES : LA BRANCHE DE L'AMBASSADEUR JOUEUR (decisions de Fred du 25 octobre 2026)
-- ============================================================================
-- 1. ASILE : « l'ambassadeur accepte ou refuse ». Quand un joueur est ambassadeur en poste, la
--    demande lui est transmise par mail (boutons Accepter / Refuser) et il tranche quand il veut,
--    comme pour l'audience ; le PNJ ne decide que s'il n'y a pas d'ambassadeur joueur.
-- 2. SECRETAIRES : quand un joueur est en poste, le PNJ ambassadeur devient « secretaire de
--    l'ambassadeur ». ambassade_acces_bureaux rend donc aussi le nom de l'ambassadeur joueur de
--    chaque ambassade (information publique : la table est lisible de tous).
-- 3. VALISE DIPLOMATIQUE : « pas de passage en douane pour les ambassadeurs ».
--    ambassade_mon_statut dit au controle de l'aeroport si le joueur est ambassadeur en poste.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

ALTER TABLE public.ambassades_asiles ADD COLUMN IF NOT EXISTS ambassadeur_pj text;

-- La demande d'asile, avec la branche de l'ambassadeur joueur.
CREATE OR REPLACE FUNCTION public.ambassade_demander_asile(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_batiment text; v_id uuid; v_paie jsonb; v_ident jsonb; v_statut text; v_pj text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue'); END IF;
  SELECT country, current_building INTO v_pays, v_batiment FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue'); END IF;
  IF v_batiment IS DISTINCT FROM 'quartier-ambassades' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE demandeur = v_moi AND statut IN ('demandee','accorde');
  IF v_statut = 'demandee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  ELSIF v_statut = 'accorde' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_refugie'); END IF;

  -- L'ambassadeur joueur en poste ici, s'il y en a un : c'est lui qui tranche.
  SELECT nullif(btrim(coalesce(a.data ->> 'ambassadeur', '')), '') INTO v_pj
    FROM public.ambassades_ouvertes a WHERE a.pays_hote = v_pays AND a.empire = p_empire;

  BEGIN
    INSERT INTO public.ambassades_asiles (demandeur, pays_hote, empire, decision_prevue_le, ambassadeur_pj)
    VALUES (v_moi, v_pays, p_empire,
            CASE WHEN v_pj IS NULL THEN now() + random() * interval '3 days' ELSE 'infinity'::timestamptz END, v_pj)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  END;

  v_paie := public.payer_ordre(v_moi, 'demander_asile_politique', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_asiles WHERE id = v_id;
    RETURN v_paie;
  END IF;

  PERFORM public.mail_systeme_poser_interne('Quartier des Ambassades', v_moi, 'Demande d''asile transmise',
    'Votre demande d''asile politique auprès de l''<strong>' || (v_ident ->> 'ambassade')
    || '</strong> a bien été transmise.<br><br>Votre dossier sera examiné, et la réponse vous parviendra dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');

  IF v_pj IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Quartier des Ambassades', v_pj, 'Demande d''asile politique',
      '<strong>' || v_moi || '</strong> sollicite l''asile politique auprès de votre ambassade. À vous de l''accorder ou de le refuser.<br><br>'
      || '[[act:asile_accorder|' || v_id::text || ']][[act:asile_refuser|' || v_id::text || ']]');
    RETURN jsonb_build_object('ok', true, 'statut', 'demandee', 'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
  END IF;

  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'statut', v_statut, 'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_demander_asile(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_demander_asile(text) TO authenticated;

-- L'ambassadeur joueur tranche. Il doit etre toujours en poste dans cette ambassade.
CREATE OR REPLACE FUNCTION public.ambassade_trancher_asile(p_id uuid, p_accorder boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record; v_ident jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.ambassades_asiles WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR r.ambassadeur_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable'); END IF;
  IF r.statut <> 'demandee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_tranchee', 'statut', r.statut); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                  WHERE a.pays_hote = r.pays_hote AND a.empire = r.empire AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plus_en_poste'); END IF;
  UPDATE public.ambassades_asiles SET statut = CASE WHEN p_accorder THEN 'accorde' ELSE 'refuse' END, decide_le = now()
   WHERE id = p_id;
  v_ident := public.ambassade_identite(r.empire);
  IF p_accorder THEN
    PERFORM public.mail_systeme_poser_interne(v_ident ->> 'ambassade', r.demandeur, 'Asile politique accordé',
      'Son Excellence <strong>' || v_moi || '</strong> vous accorde l''asile politique.<br><br>'
      || 'Vous êtes en sécurité tant que vous restez au Quartier des Ambassades, et le bureau de l''' || (v_ident ->> 'ambassade')
      || ' vous est ouvert. <strong>Dès que vous en sortez, vous pouvez être arrêté(e).</strong>');
  ELSE
    PERFORM public.mail_systeme_poser_interne(v_ident ->> 'ambassade', r.demandeur, 'Demande d''asile refusée',
      'Son Excellence <strong>' || v_moi || '</strong> ne donne pas suite à votre demande d''asile politique.');
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', CASE WHEN p_accorder THEN 'accorde' ELSE 'refuse' END, 'demandeur', r.demandeur);
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_trancher_asile(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_trancher_asile(uuid, boolean) TO authenticated;

-- Les bureaux, avec le nom de l'ambassadeur joueur en poste (pour les secretaires).
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''bureaux'', v_res);';
  v_ajout text := E'  -- Ambassadeurs joueurs en poste dans le pays (25/10/2026) : leurs PNJ deviennent secretaires.\n  RETURN jsonb_build_object(''ok'', true, ''bureaux'', v_res, ''ambassadeurs'', coalesce((\n    SELECT jsonb_object_agg(a.empire, a.data ->> ''ambassadeur'') FROM public.ambassades_ouvertes a\n     WHERE a.pays_hote = v_pays AND nullif(btrim(coalesce(a.data ->> ''ambassadeur'', '''')), '''') IS NOT NULL), ''{}''::jsonb));';
BEGIN
  v_def := pg_get_functiondef('public.ambassade_acces_bureaux()'::regprocedure);
  IF position('''ambassadeurs''' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment de ambassade_acces_bureaux introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- Statut diplomatique du joueur (valise diplomatique).
CREATE OR REPLACE FUNCTION public.ambassade_mon_statut()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT pays_hote, empire INTO a FROM public.ambassades_ouvertes WHERE data ->> 'ambassadeur' = v_moi LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'ambassadeur', a.empire IS NOT NULL, 'pays_hote', a.pays_hote, 'empire', a.empire);
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_mon_statut() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_mon_statut() TO authenticated;
