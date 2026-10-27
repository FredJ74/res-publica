-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027105430.
-- Eprouvee avant application en transaction annulee, au role authenticated (candidat, fenetre et poste refuses, rangs de detectabilite, prison du fraudeur pris). Baseline NON reextrait.
-- ============================================================================
-- LES FRAUDES ELECTORALES PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §1.1 (fraudes_electorales). Falsifier les listes, bourrer les urnes
-- et truquer le depouillement etaient decides par l'ecran : poste, fenetre, jet, nombre de voix,
-- detectabilite, et l'ecran inscrivait lui-meme la fraude. Tout joueur pouvait donc inscrire une
-- « fraude » de n'importe quelle ampleur en faveur de n'importe quel candidat, que le
-- depouillement de minuit appliquait.
-- fraude_electorale_tenter(type, poste, ville, candidat, sens) fait tout. Regles d'avant :
--   * falsification des listes : maire ou adjoint, municipales de la ville ou il se trouve,
--     avant l'ouverture du vote ; 2 PA ; 70 % ; +1 a +10 voix ; echec : 20 jours de prison ;
--   * bourrage des urnes : electeur domicilie dans le pays, pendant le vote ; 1 PA ; 60 % ;
--     +1 a +3 voix ; echec : 1 jour ;
--   * trucage du depouillement : commissaire ou juge, pendant le vote ; 2 PA ; 75 % ; +/-1 a 10
--     voix ; echec : 20 jours et un fait public dans la chronique.
--   Reussite modulee par la discretion : +1 point par tranche de 5 au-dessus de 50 (borne 5-95).
--   Detectabilite selon le rang de la fraude de ce type sur ce scrutin : 10, 30, 60, 90, 100 %.
-- Les joueurs n'ecrivent plus fraudes_electorales. Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fraude_electorale_tenter(p_type text, p_poste text, p_city text, p_candidat text, p_sens integer DEFAULT 1)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_fn text; v_pa integer; v_base integer; v_jours integer; v_city text;
  v_row record; v_cycle jsonb; v_now bigint := (extract(epoch FROM now()) * 1000)::bigint;
  v_paie jsonb; v_dis numeric; v_taux integer; v_roll integer; v_rang integer; v_delta integer;
  v_raison text; v_det jsonb; v_libelle text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, poste ->> 'id' AS poste, domicile, resources INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  CASE p_type
    WHEN 'falsification_listes' THEN v_fn := 'falsifier_listes_electorales'; v_pa := 2; v_base := 70; v_jours := 20;
    WHEN 'bourrage_urnes' THEN v_fn := 'bourrer_urnes'; v_pa := 1; v_base := 60; v_jours := 1;
    WHEN 'trucage_depouillement' THEN v_fn := 'truquer_depouillement'; v_pa := 2; v_base := 75; v_jours := 20;
    ELSE RETURN jsonb_build_object('ok', false, 'raison', 'fraude_inconnue');
  END CASE;

  -- Qui, et sur quel scrutin.
  IF p_type = 'falsification_listes' AND (d.poste IS NULL OR d.poste NOT IN ('maire', 'maire_adjoint') OR p_poste <> 'maire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acces_refuse'); END IF;
  IF p_type = 'trucage_depouillement' AND (d.poste IS NULL OR d.poste NOT IN ('commissaire', 'juge')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acces_refuse'); END IF;
  IF p_type = 'bourrage_urnes' AND coalesce(d.domicile ->> 'country', d.country) IS DISTINCT FROM d.country THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acces_refuse'); END IF;
  IF p_poste NOT IN ('president', 'chef_syndicat', 'maire', 'depute') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN d.current_city END;
  SELECT * INTO v_row FROM public.cycles_electoraux
   WHERE country = d.country AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  v_cycle := v_row.data::jsonb;

  -- Quand.
  IF p_type = 'falsification_listes' THEN
    IF NOT (v_now < coalesce((v_cycle ->> 'dateVote')::bigint, 0)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre'); END IF;
  ELSIF NOT (v_now >= coalesce((v_cycle ->> 'dateVote')::bigint, 0) AND v_now < coalesce((v_cycle ->> 'dateResultats')::bigint, 0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre');
  END IF;

  -- Pour qui.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_cycle -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_invalide'); END IF;

  v_paie := public.payer_ordre(v_moi, v_fn, v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_dis := coalesce(CASE WHEN jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric END, 50);
  v_taux := greatest(5, least(95, v_base + round((v_dis - 50) / 5)::integer));
  v_roll := floor(random() * 100)::integer + 1;

  IF v_roll <= v_taux THEN
    SELECT count(*) + 1 INTO v_rang FROM public.fraudes_electorales
     WHERE country = d.country AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city
       AND cycle_debut = (v_cycle ->> 'dateDebutCandidatures')::bigint AND type = p_type;
    v_delta := CASE p_type
      WHEN 'falsification_listes' THEN floor(random() * 10)::integer + 1
      WHEN 'bourrage_urnes' THEN floor(random() * 3)::integer + 1
      ELSE (CASE WHEN coalesce(p_sens, 1) < 0 THEN -1 ELSE 1 END) * (floor(random() * 10)::integer + 1) END;
    INSERT INTO public.fraudes_electorales (id, country, poste_id, city, cycle_debut, type, auteur, candidat,
                                            delta_voix, etat, detectabilite_pct, created_at)
    VALUES ('fraude-' || p_type || '-' || replace(gen_random_uuid()::text, '-', ''), d.country, p_poste, v_city,
            (v_cycle ->> 'dateDebutCandidatures')::bigint, p_type, v_moi, p_candidat, v_delta, 'non_revelee',
            (ARRAY[10, 30, 60, 90, 100])[least(v_rang, 5)], now());
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'delta', v_delta, 'candidat', p_candidat) || jsonb_build_object('paie', v_paie);
  END IF;

  -- Pris sur le fait.
  v_raison := CASE p_type WHEN 'falsification_listes' THEN 'Falsification des listes électorales — pris(e) sur le fait'
                          WHEN 'bourrage_urnes' THEN 'Bourrage d''urnes — pris(e) sur le fait'
                          ELSE 'Trucage du dépouillement — pris(e) sur le fait' END;
  v_det := public.detention_ouvrir_interne(v_moi, v_raison, v_jours, coalesce(d.current_city, 'capitale'), d.country,
             jsonb_build_array(jsonb_build_object('type', v_raison, 'jours', v_jours, 'city', coalesce(d.current_city, 'capitale'),
               'source', 'fraude_electorale', 'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_moi, 'fraude_electorale');
  IF p_type = 'trucage_depouillement' THEN
    v_libelle := v_moi || ', ' || CASE WHEN d.poste = 'juge' THEN 'le juge' ELSE 'le commissaire' END
      || ', a été pris(e) sur le fait en tentant de truquer le dépouillement d''un scrutin.';
    INSERT INTO public.chronique_nationale (id, country, type, city, personnages, libelle, data)
    VALUES ('chronique-fraude_electorale_dejouee-' || replace(gen_random_uuid()::text, '-', ''), d.country,
            'fraude_electorale_dejouee', v_city, jsonb_build_array(v_moi), v_libelle,
            jsonb_build_object('poste_id', p_poste, 'candidat_vise', p_candidat));
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'jours', v_jours,
    'detention_ouverte', coalesce((v_det ->> 'ok')::boolean, false), 'detention_id', v_det ->> 'detention_id')
    || jsonb_build_object('paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.fraude_electorale_tenter(text, text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fraude_electorale_tenter(text, text, text, text, integer) TO authenticated;

DO $do$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'fraudes_electorales' AND cmd <> 'SELECT' LOOP
    EXECUTE format('DROP POLICY %I ON public.fraudes_electorales', p.policyname);
  END LOOP;
END $do$;
REVOKE INSERT, UPDATE, DELETE ON public.fraudes_electorales FROM anon, authenticated;

-- Une fraude non revelee est un secret : la table etait lisible par tous, auteur compris. Seules
-- les fraudes revelees restent publiques ; chacun voit aussi les siennes.
DROP POLICY IF EXISTS fraudes_electorales_lecture_publique ON public.fraudes_electorales;
DROP POLICY IF EXISTS fraudes_electorales_lecture ON public.fraudes_electorales;
CREATE POLICY fraudes_electorales_lecture ON public.fraudes_electorales FOR SELECT TO anon, authenticated
  USING (etat = 'revelee' OR auteur = public.mon_personnage());
