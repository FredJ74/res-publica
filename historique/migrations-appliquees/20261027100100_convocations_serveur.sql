-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027112114.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027112114.
-- Eprouvee avant application en transaction annulee, au role authenticated (traitee et echeance forcees par le serveur, justification unique, sanction de nuit). Baseline NON reextrait.
-- ============================================================================
-- LES CONVOCATIONS TENUES PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », passe de minuit cote ecran. Une convocation au commissariat
-- (achat d'arme refuse, douane, transaction interdite, Assemblee) devait etre honoree sous 24 h
-- (36 h pour l'Assemblee). Tout se jouait dans le navigateur du convoque :
--   * l'echeance etait comptee avec son compteur de jours personnel ;
--   * la sanction de non-presentation (2 jours) n'etait appliquee que par SON ecran, a minuit ou
--     au reveil -- il suffisait de ne pas jouer, ou de marquer la convocation « traitee » ;
--   * se justifier (50 % + (CHA + DUP) / 2) etait tire par son ecran.
-- Desormais :
--   * toute nouvelle convocation recoit une echeance reelle (24 h) posee par la base, et seule une
--     fonction du serveur peut la dire traitee ;
--   * convocation_se_justifier fait la justification : delai, paiement, jet, retrait du motif ou
--     1 jour de detention ;
--   * la passe de nuit (minuit_convocations) sanctionne chaque convocation echue non honoree :
--     2 jours, une convocation par nuit et par personne, comme avant.
-- La confiscation des marchandises interdites reste demandee par l'ecran (inventaire_confisquer).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.personnages_convocations_garder()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_elem jsonb; v_old jsonb; v_out jsonb := '[]'::jsonb;
BEGIN
  IF NEW.convocations IS NOT DISTINCT FROM OLD.convocations THEN RETURN NEW; END IF;
  IF public.est_appel_serveur() OR coalesce(current_setting('request.path', true), '') LIKE '/rpc/%' THEN RETURN NEW; END IF;
  FOR v_elem IN SELECT value FROM jsonb_array_elements(coalesce(NEW.convocations, '[]'::jsonb)) LOOP
    SELECT o.value INTO v_old FROM jsonb_array_elements(coalesce(OLD.convocations, '[]'::jsonb)) o
     WHERE public.assemblee_cle_convocation(o.value) = public.assemblee_cle_convocation(v_elem) LIMIT 1;
    IF v_old IS NOT NULL THEN
      -- Le navigateur ne dit pas qu'une convocation est honoree, ni ne recule son echeance.
      v_elem := v_elem || jsonb_build_object('traitee', coalesce(v_old -> 'traitee', 'false'::jsonb));
      IF v_old ? 'limiteTs' THEN v_elem := v_elem || jsonb_build_object('limiteTs', v_old -> 'limiteTs'); END IF;
    ELSE
      v_elem := v_elem || jsonb_build_object('traitee', false,
        'limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    END IF;
    v_out := v_out || jsonb_build_array(v_elem);
    v_old := NULL;
  END LOOP;
  NEW.convocations := v_out;
  RETURN NEW;
END; $function$;
DROP TRIGGER IF EXISTS trg_personnages_zz_convocations_garder ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_zz_convocations_garder BEFORE UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_convocations_garder();

-- Echeance reelle pour les convocations en cours qui n'en ont pas (delai de grace de 24 h).
UPDATE public.personnages_donnees d
   SET convocations = (SELECT jsonb_agg(CASE WHEN NOT (e ? 'limiteTs') AND NOT coalesce((e ->> 'traitee')::boolean, false)
                                             THEN e || jsonb_build_object('limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
                                             ELSE e END)
                         FROM jsonb_array_elements(d.convocations) e)
 WHERE jsonb_typeof(d.convocations) = 'array' AND jsonb_array_length(d.convocations) > 0
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(d.convocations) e
                WHERE NOT (e ? 'limiteTs') AND NOT coalesce((e ->> 'traitee')::boolean, false));

CREATE OR REPLACE FUNCTION public.convocation_echue_interne(p_c jsonb)
 RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT NOT coalesce((p_c ->> 'traitee')::boolean, false)
         AND (coalesce((p_c ->> 'echue')::boolean, false)
              OR (p_c ? 'limiteTs' AND now() >= (p_c ->> 'limiteTs')::timestamptz)) $$;

-- Marque une convocation traitee (par sa cle) et rend le tableau.
CREATE OR REPLACE FUNCTION public.convocation_marquer_interne(p_nom text, p_c jsonb)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ UPDATE public.personnages_donnees
         SET convocations = (SELECT jsonb_agg(CASE WHEN public.assemblee_cle_convocation(e) = public.assemblee_cle_convocation(p_c)
                                                   THEN e || jsonb_build_object('traitee', true) ELSE e END)
                               FROM jsonb_array_elements(convocations) e)
       WHERE name = p_nom $$;

CREATE OR REPLACE FUNCTION public.convocation_detention_interne(p_nom text, p_raison text, p_jours integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record;
BEGIN
  SELECT country, coalesce(current_city, 'capitale') AS city INTO d FROM public.personnages_donnees WHERE name = p_nom;
  RETURN public.detention_ouvrir_interne(p_nom, p_raison, p_jours, d.city, d.country,
    jsonb_build_array(jsonb_build_object('type', p_raison, 'jours', p_jours, 'city', d.city, 'source', 'convocation',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
    'Commissariat', 'convocation');
END; $function$;

CREATE OR REPLACE FUNCTION public.convocation_se_justifier(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_convs jsonb; v_c jsonb; v_stats jsonb; v_taux integer; v_roll integer; v_paie jsonb; v_det jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT convocations, stats INTO v_convs, v_stats FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT e INTO v_c FROM jsonb_array_elements(coalesce(v_convs, '[]'::jsonb)) e
   WHERE NOT coalesce((e ->> 'traitee')::boolean, false) LIMIT 1;
  IF v_c IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation'); END IF;

  IF public.convocation_echue_interne(v_c) THEN
    PERFORM public.convocation_marquer_interne(v_moi, v_c);
    v_det := public.convocation_detention_interne(v_moi, 'Non-présentation à une convocation', 2);
    RETURN jsonb_build_object('ok', true, 'issue', 'non_presentation', 'jours', 2,
      'detention_ouverte', coalesce((v_det ->> 'ok')::boolean, false), 'detention_id', v_det ->> 'detention_id');
  END IF;

  v_paie := public.payer_ordre(v_moi, 'se_justifier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  PERFORM public.convocation_marquer_interne(v_moi, v_c);
  v_taux := greatest(0, least(100, round(50 + (coalesce((v_stats ->> 'CHA')::numeric, 8) + coalesce((v_stats ->> 'DUP')::numeric, 8)) / 2)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    PERFORM set_config('rp.recherche_interne', 'on', true);
    UPDATE public.personnages_donnees
       SET recherche = (SELECT coalesce(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(
                          CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END) e
                         WHERE e ->> 'acte' IS DISTINCT FROM v_c ->> 'motif')
     WHERE name = v_moi;
    PERFORM set_config('rp.recherche_interne', '', true);
    RETURN jsonb_build_object('ok', true, 'issue', 'classee', 'motif', v_c ->> 'motif', 'taux', v_taux) || jsonb_build_object('paie', v_paie);
  END IF;
  v_det := public.convocation_detention_interne(v_moi, 'Justification rejetée au commissariat', 1);
  RETURN jsonb_build_object('ok', true, 'issue', 'rejetee', 'jours', 1, 'motif', v_c ->> 'motif', 'taux', v_taux,
    'detention_ouverte', coalesce((v_det ->> 'ok')::boolean, false), 'detention_id', v_det ->> 'detention_id')
    || jsonb_build_object('paie', v_paie);
END; $function$;

CREATE OR REPLACE FUNCTION public.minuit_convocations()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_c jsonb; v_n integer := 0; v_det jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR r IN SELECT name, convocations FROM public.personnages_donnees
            WHERE jsonb_typeof(convocations) = 'array' AND jsonb_array_length(convocations) > 0 LOOP
    SELECT e INTO v_c FROM jsonb_array_elements(r.convocations) e WHERE public.convocation_echue_interne(e) LIMIT 1;
    IF v_c IS NOT NULL THEN
      PERFORM public.convocation_marquer_interne(r.name, v_c);
      v_det := public.convocation_detention_interne(r.name, 'Non-présentation à une convocation', 2);
      PERFORM public.mail_systeme_poser_interne('Commissariat', r.name, 'Non-présentation',
        'Vous ne vous êtes pas présenté(e) dans le délai imparti suite à votre convocation. Vous êtes arrêté(e) pour deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
      v_n := v_n + 1;
    END IF;
    v_c := NULL;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'sanctionnees', v_n);
END; $function$;

REVOKE ALL ON FUNCTION public.personnages_convocations_garder() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.convocation_echue_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.convocation_marquer_interne(text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.convocation_detention_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.convocation_se_justifier(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.convocation_se_justifier(integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.minuit_convocations() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.minuit_convocations() TO service_role;
