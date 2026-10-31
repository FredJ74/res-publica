-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027185556.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027185556.
-- Eprouvee au role authenticated (recrutement, plafond, interrogation 1 PA, ecriture directe ignoree, nuits payees/depart, rejeu sans double prelevement).
-- ============================================================================
-- INFORMATEURS : TENUS PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite ». La liste des informateurs etait ecrite par l'ecran (fiche libre), leur
-- salaire preleve a minuit par l'ecran sur le total AFFICHE (state.arg, pas l'argent reel), et
-- « interroger » donnait de l'influence sans limite ni cout. Desormais :
--   * informateur_recruter : max 2, un par niveau, premier jour de salaire preleve, +niveau INF.
--     Ordres declares : recruter_informateur_2 (1 PA, 400 = premier jour) et recruter_info_4
--     (3 PA ; les 1 500 du premier jour preleves en plus, comme l'ecran) ;
--   * informateur_interroger : 1 PA (decision de Fred, 27/10/2026), +moitie du niveau en INF
--     (arrondie au-dessus). « Consulter la Taupe N4 » est cet ordre (il recrutait par erreur) ;
--   * informateur_congedier ;
--   * minuit_informateurs : la passe de nuit preleve chaque salaire (liquide puis compte national) ;
--     faute de fonds, l'informateur part et le joueur est prevenu ;
--   * la colonne informateurs n'est plus ecrite par l'ecran (declencheur).
-- Idempotente. Aucun informateur n'existait en base au moment de l'application.
-- ============================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('interroger_informateur', 1, 0), ('informateur_salaire_1', 0, 150), ('informateur_salaire_2', 0, 400),
  ('informateur_salaire_3', 0, 700), ('informateur_salaire_4', 0, 1500)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.informateur_niveau_interne(p_niveau integer)
 RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $$ SELECT CASE p_niveau
    WHEN 1 THEN '{"label":"Informateur de rue","cout":150}'::jsonb
    WHEN 2 THEN '{"label":"Informateur politique","cout":400}'::jsonb
    WHEN 3 THEN '{"label":"Informateur criminel","cout":700}'::jsonb
    WHEN 4 THEN '{"label":"Taupe","cout":1500}'::jsonb END $$;

CREATE OR REPLACE FUNCTION public.informateur_inf_ajouter_interne(p_nom text, p_delta integer)
 RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v numeric;
BEGIN
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{inf}',
           to_jsonb(least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'inf') = 'number'
                                                          THEN (resources ->> 'inf')::numeric END, 0) + p_delta))))
   WHERE name = p_nom
  RETURNING (resources ->> 'inf')::numeric INTO v;
  RETURN v;
END; $function$;

CREATE OR REPLACE FUNCTION public.informateur_recruter(p_niveau integer, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_cfg jsonb; v_fn text; v_liste jsonb; v_fonds numeric; v_paie jsonb; v_inf numeric; v_cout integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cfg := public.informateur_niveau_interne(p_niveau);
  v_fn := CASE p_niveau WHEN 2 THEN 'recruter_informateur_2' WHEN 4 THEN 'recruter_info_4' END;
  IF v_cfg IS NULL OR v_fn IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'niveau_indisponible'); END IF;
  v_cout := (v_cfg ->> 'cout')::integer;
  SELECT CASE WHEN jsonb_typeof(d.informateurs) = 'array' THEN d.informateurs ELSE '[]'::jsonb END,
         coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b WHERE b.personnage = d.name AND b.banque = 'nationale'), 0)
    INTO v_liste, v_fonds FROM public.personnages_donnees d WHERE d.name = v_moi FOR UPDATE;
  IF jsonb_array_length(v_liste) >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'maximum_atteint'); END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_liste) i WHERE (i ->> 'niveau')::integer = p_niveau) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_actif'); END IF;
  IF v_fonds < greatest(p_cost, v_cout) THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  v_paie := public.payer_ordre(v_moi, v_fn, p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  -- Premier jour de salaire : compris dans le prix de l'ordre quand il le couvre, preleve sinon.
  IF p_cost < v_cout THEN
    v_paie := public.payer_ordre(v_moi, 'informateur_salaire_' || p_niveau, 0, v_cout);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'informateur_recruter: salaire refuse'; END IF;
  END IF;
  PERFORM set_config('rp.informateurs_interne', 'on', true);
  UPDATE public.personnages_donnees
     SET informateurs = v_liste || jsonb_build_array(jsonb_build_object('niveau', p_niveau, 'label', v_cfg ->> 'label',
           'cout', v_cout, 'joursActif', 0, 'depuis', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD')))
   WHERE name = v_moi;
  PERFORM set_config('rp.informateurs_interne', '', true);
  v_inf := public.informateur_inf_ajouter_interne(v_moi, p_niveau);
  RETURN jsonb_build_object('ok', true, 'inf', v_inf, 'cout', v_cout)
    || (SELECT jsonb_build_object('informateurs', informateurs, 'pa', pa, 'arg', arg, 'liquide', liquide)
          FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

CREATE OR REPLACE FUNCTION public.informateur_interroger(p_niveau integer, p_pa integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_paie jsonb; v_inf numeric; v_fn text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees d, jsonb_array_elements(CASE WHEN jsonb_typeof(d.informateurs) = 'array'
                   THEN d.informateurs ELSE '[]'::jsonb END) i WHERE d.name = v_moi AND (i ->> 'niveau')::integer = p_niveau) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_d_informateur'); END IF;
  v_fn := CASE WHEN p_niveau = 4 THEN 'consulter_info_4' ELSE 'interroger_informateur' END;
  v_paie := public.payer_ordre(v_moi, v_fn, p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_inf := public.informateur_inf_ajouter_interne(v_moi, ceil(p_niveau / 2.0)::integer);
  RETURN jsonb_build_object('ok', true, 'inf', v_inf, 'gain', ceil(p_niveau / 2.0)::integer, 'pa', v_paie -> 'pa');
END; $function$;

CREATE OR REPLACE FUNCTION public.informateur_congedier(p_niveau integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM set_config('rp.informateurs_interne', 'on', true);
  UPDATE public.personnages_donnees
     SET informateurs = coalesce((SELECT jsonb_agg(i) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(informateurs) = 'array'
                                   THEN informateurs ELSE '[]'::jsonb END) i WHERE (i ->> 'niveau')::integer <> p_niveau), '[]'::jsonb)
   WHERE name = v_moi;
  PERFORM set_config('rp.informateurs_interne', '', true);
  RETURN jsonb_build_object('ok', true, 'informateurs', (SELECT informateurs FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

CREATE OR REPLACE FUNCTION public.minuit_informateurs()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; i jsonb; v_garde jsonb; v_liquide numeric; v_compte text; v_solde numeric; v_cout integer;
  v_payes integer := 0; v_partis integer := 0; v_pris numeric;
BEGIN
  PERFORM set_config('rp.informateurs_interne', 'on', true);
  FOR p IN SELECT name, liquide, informateurs FROM public.personnages_donnees
            WHERE jsonb_typeof(informateurs) = 'array' AND jsonb_array_length(informateurs) > 0 FOR UPDATE LOOP
    v_garde := '[]'::jsonb; v_liquide := coalesce(p.liquide, 0);
    SELECT id, solde INTO v_compte, v_solde FROM public.comptes_bancaires
     WHERE personnage = p.name AND banque = 'nationale' FOR UPDATE;
    v_solde := coalesce(v_solde, 0);
    FOR i IN SELECT * FROM jsonb_array_elements(p.informateurs) LOOP
      v_cout := coalesce((i ->> 'cout')::integer, (public.informateur_niveau_interne((i ->> 'niveau')::integer) ->> 'cout')::integer, 0);
      IF v_liquide + v_solde >= v_cout THEN
        v_pris := least(v_liquide, v_cout);
        v_liquide := v_liquide - v_pris; v_solde := v_solde - (v_cout - v_pris);
        v_garde := v_garde || jsonb_build_array(i || jsonb_build_object('joursActif', coalesce((i ->> 'joursActif')::integer, 0) + 1));
        v_payes := v_payes + 1;
      ELSE
        v_partis := v_partis + 1;
        PERFORM public.mail_systeme_poser_interne('Système', p.name, 'Informateur parti',
          'Votre ' || lower(coalesce(i ->> 'label', 'informateur')) || ' (niveau ' || (i ->> 'niveau') || ') a quitté faute de paiement.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees
       SET informateurs = v_garde, arg = coalesce(arg, 0) - (coalesce(p.liquide, 0) - v_liquide)
                                         - (coalesce((SELECT solde FROM public.comptes_bancaires WHERE id = v_compte), 0) - v_solde),
           liquide = v_liquide
     WHERE name = p.name;
    IF v_compte IS NOT NULL THEN UPDATE public.comptes_bancaires SET solde = v_solde, updated_at = now() WHERE id = v_compte; END IF;
  END LOOP;
  PERFORM set_config('rp.informateurs_interne', '', true);
  RETURN jsonb_build_object('ok', true, 'payes', v_payes, 'partis', v_partis);
END; $function$;

-- La colonne n'est plus ecrite par l'ecran.
CREATE OR REPLACE FUNCTION public.personnages_informateurs_garder()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.informateurs IS DISTINCT FROM OLD.informateurs
     AND coalesce(current_setting('rp.informateurs_interne', true), '') <> 'on'
     AND coalesce(nullif(current_setting('role', true), 'none'), session_user) IN ('anon', 'authenticated') THEN
    NEW.informateurs := OLD.informateurs;
  END IF;
  RETURN NEW;
END; $function$;
DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_personnages_informateurs_garder'
                   AND tgrelid = 'public.personnages_donnees'::regclass) THEN
    CREATE TRIGGER trg_personnages_informateurs_garder BEFORE UPDATE ON public.personnages_donnees
      FOR EACH ROW EXECUTE FUNCTION public.personnages_informateurs_garder();
  END IF;
END $do$;

REVOKE ALL ON FUNCTION public.informateur_inf_ajouter_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.informateur_recruter(integer, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.informateur_recruter(integer, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.informateur_interroger(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.informateur_interroger(integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.informateur_congedier(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.informateur_congedier(integer) TO authenticated;
REVOKE ALL ON FUNCTION public.minuit_informateurs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.minuit_informateurs() TO service_role;
