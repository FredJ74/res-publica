-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261026231435.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261026231435.
-- Eprouvee apres application en transaction annulee (effet du couvre-feu une fois par jour, recherche achevee, expiration). Baseline NON reextrait.
-- ============================================================================
-- PASSE DE MINUIT : COUVRE-FEU ET RECHERCHE MILITAIRE PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §3.3. Deux traitements quotidiens tournaient dans le navigateur du
-- joueur connecte a minuit (runMidnightUpdate) : si personne ne l'etait, rien ne se passait ; si
-- quelqu'un l'etait, c'etait son ecran qui decidait, avec son horloge (Date.now()).
--   * COUVRE-FEU : expire a sa date de fin ; tant qu'il dure, chaque titulaire joueur des huit
--     postes du gouvernement perd 2 points de popularite par jour (une fois par jour civil de
--     Paris). Le navigateur ecrivait aussi la popularite des AUTRES joueurs (ecriture refusee
--     par la base depuis longtemps : la penalite ne touchait donc que celui qui passait minuit).
--   * RECHERCHE MILITAIRE : a sa date de fin, le coefficient de l'arme gagne 0,5, le programme
--     se clot, le Commandant (joueur) recoit un mail, et l'annonce est publique.
-- minuit_couvre_feu_recherche(pays) fait les deux, appelee par la passe de nuit (service). Les
-- regles sont celles d'avant. La baisse de l'indice social national (-3) n'est pas reprise :
-- cet indice n'existe que dans la memoire du navigateur (AUDIT_UNE_SEULE_VERITE.md §4).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.minuit_couvre_feu_recherche(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_jour text := ((now() AT TIME ZONE 'Europe/Paris')::date)::text;
  v_now_ms bigint := (extract(epoch from now()) * 1000)::bigint;
  v_cf jsonb; v_rech jsonb; v_arme text; v_coefs jsonb; v_cmd text; v_touches integer := 0;
  v_out jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data) <> 'object' THEN RETURN jsonb_build_object('ok', true, 'budget', 'absent'); END IF;

  -- COUVRE-FEU
  v_cf := v_data -> 'couvreFeu';
  IF jsonb_typeof(v_cf) = 'object' AND coalesce((v_cf ->> 'actif')::boolean, false) THEN
    IF (v_cf ->> 'dateFin') IS NOT NULL AND v_now_ms > (v_cf ->> 'dateFin')::numeric THEN
      v_data := jsonb_set(v_data, '{couvreFeu,actif}', 'false'::jsonb);
      v_out := v_out || jsonb_build_object('couvre_feu', 'expire');
    ELSIF v_data ->> 'dernierEffetCouvreFeuJour' IS DISTINCT FROM v_jour THEN
      UPDATE public.personnages_donnees d
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(d.resources) = 'object' THEN d.resources ELSE '{}'::jsonb END,
               '{pop}', to_jsonb(greatest(0, coalesce(CASE WHEN jsonb_typeof(d.resources -> 'pop') = 'number'
                                                           THEN (d.resources ->> 'pop')::numeric END, 50) - 2)))
       WHERE d.country = p_pays
         AND d.poste ->> 'id' IN ('president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae');
      GET DIAGNOSTICS v_touches = ROW_COUNT;
      v_data := v_data || jsonb_build_object('dernierEffetCouvreFeuJour', v_jour);
      v_out := v_out || jsonb_build_object('couvre_feu', 'effet', 'titulaires', v_touches);
    END IF;
  END IF;

  -- RECHERCHE MILITAIRE
  v_rech := v_data #> '{rechercheMilitaire,enCours}';
  IF jsonb_typeof(v_rech) = 'object' AND (v_rech ->> 'dateFin') IS NOT NULL
     AND v_now_ms >= (v_rech ->> 'dateFin')::numeric THEN
    v_arme := v_rech ->> 'arme';
    v_coefs := CASE WHEN jsonb_typeof(v_data -> 'coefficientsArmesAcquis') = 'object' THEN v_data -> 'coefficientsArmesAcquis' ELSE '{}'::jsonb END;
    v_coefs := jsonb_set(v_coefs, ARRAY[v_arme], to_jsonb(coalesce((v_coefs ->> v_arme)::numeric, 0) + 0.5));
    v_data := v_data || jsonb_build_object('coefficientsArmesAcquis', v_coefs);
    v_data := jsonb_set(v_data, '{rechercheMilitaire,enCours}', 'null'::jsonb);
    PERFORM public.annonce_publique_interne(p_pays, 'Recherche militaire achevée : le coefficient de tir de « '
      || coalesce(v_arme, '?') || ' » est amélioré pour toute la nation.');
    SELECT name INTO v_cmd FROM public.personnages_donnees WHERE country = p_pays AND poste ->> 'id' = 'commandant' LIMIT 1;
    IF v_cmd IS NOT NULL THEN
      PERFORM public.mail_systeme_poser_interne('Chercheurs Civils', v_cmd, 'Recherche achevée',
        'Le programme de recherche sur « ' || coalesce(v_arme, '?') || ' » est terminé. Coefficient amélioré.');
    END IF;
    v_out := v_out || jsonb_build_object('recherche', v_arme);
  END IF;

  UPDATE public.budgets_nationaux SET data = v_data WHERE id = p_pays;
  RETURN jsonb_build_object('ok', true) || v_out;
END; $function$;
REVOKE ALL ON FUNCTION public.minuit_couvre_feu_recherche(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.minuit_couvre_feu_recherche(text) TO service_role;
