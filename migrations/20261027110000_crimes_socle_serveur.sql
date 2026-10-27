-- A APPLIQUER par Claude via MCP apply_migration.
-- ============================================================================
-- LE SOCLE PENAL DU SERVEUR : DETECTION, TRACE, DECOUVERTE DIFFEREE (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », famille « Crime ». La detection d'un acte illegal (checkDetection),
-- la trace d'un crime (historiqueCrimes) et sa decouverte apres coup (verifierDecouverteCrimesPasses)
-- etaient tirees par le navigateur DU CRIMINEL : un tricheur n'etait jamais repere.
-- Ce socle donne au serveur les memes regles, pour les actes qui passent desormais par lui :
--   * actes_illegaux : le miroir de ACTES_ILLEGAUX (type, taux de detection) et des baremes
--     propres de PEINES_ACTES (jours, amende) ;
--   * crime_detecter_interne : jet de detection ; s'il touche, l'acte est inscrit a l'avis de
--     recherche. Variante « checkDetection » : immunite du President, des ministres pour un delit
--     mineur, taux diminue de la discretion / 10, et -10 de discretion si repere ;
--   * crime_tracer_interne : trace d'origine serveur dans historique_crimes (8 jours) ;
--   * minuit_decouverte_crimes : chaque nuit, une trace decouvrable peut etre mise au jour (taux
--     de detection de l'acte, 25 par defaut) ; le coupable est ecroue, peine et amende doublees
--     (demasque), une affaire par personne et par nuit. Les traces d'origine serveur etaient deja
--     exclues de la decouverte par l'ecran : aucun double traitement.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.actes_illegaux (
  fn           text PRIMARY KEY,
  type         text NOT NULL,
  detect_rate  integer NOT NULL,
  peine_jours  integer,          -- bareme propre (PEINES_ACTES.republic) ; NULL : bareme du type
  amende       integer,
  decouvrable  boolean NOT NULL DEFAULT false,
  maj_le       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.actes_illegaux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.actes_illegaux FROM anon, authenticated;

INSERT INTO public.actes_illegaux (fn, type, detect_rate, peine_jours, amende, decouvrable) VALUES
  ('corrompre_fonct','delit_mineur',30,NULL,NULL,false), ('corrompre_police','delit_mineur',35,NULL,NULL,false),
  ('corrompre_juge','delit_grave',40,NULL,NULL,false), ('corrompre_journaliste','delit_mineur',25,NULL,NULL,false),
  ('blanchiment','delit_grave',35,NULL,NULL,false), ('societe_ecran','delit_mineur',25,NULL,NULL,false),
  ('falsifier_document','delit_grave',40,NULL,NULL,false), ('acheter_arme_illegale','delit_mineur',20,NULL,NULL,false),
  ('acheter_bombe_illegale','crime',55,2,2000,true), ('fabriquer_bombe','crime',60,NULL,NULL,false),
  ('incendier','crime',70,2,2000,true), ('utiliser_explosifs','crime',65,2,2000,true),
  ('arreter','delit_grave',40,NULL,NULL,false), ('fabriquer_scandale','delit_grave',45,NULL,NULL,false),
  ('fuite_info','delit_grave',40,NULL,NULL,false), ('imprimer_tracts_calomnieux','delit_mineur',30,NULL,NULL,false),
  ('tentative_evasion','crime',90,NULL,NULL,false), ('se_rebeller','delit_mineur',60,NULL,NULL,false),
  ('fausse_rumeur','delit_mineur',35,NULL,NULL,false), ('vol','delit_mineur',30,1,500,false),
  ('vol_materiel_chantier','delit_mineur',30,NULL,NULL,false),
  ('assassiner_mains','crime',30,NULL,NULL,false), ('assassiner_arme','crime',40,NULL,NULL,false),
  ('assassiner_feu','crime',60,NULL,NULL,false), ('empoisonnement','crime',25,2,2000,true),
  ('corrompre_douanier','delit_mineur',35,NULL,NULL,false), ('contrebande_port','delit_mineur',20,NULL,NULL,false),
  ('corrompre_gardien','delit_mineur',35,NULL,NULL,false),
  -- Actes decouvrables sans taux de detection propre (25 par defaut cote ecran) et baremes propres.
  ('assassinat','crime',25,2,1500,true), ('tentative_assassinat','crime',25,2,1500,false),
  ('achat_arme_illegal','delit_mineur',25,1,500,true), ('hooliganisme','delit_mineur',25,1,500,true),
  ('corruption_fonctionnaire','delit_mineur',25,1,1000,true)
ON CONFLICT (fn) DO UPDATE SET type = EXCLUDED.type, detect_rate = EXCLUDED.detect_rate, peine_jours = EXCLUDED.peine_jours,
  amende = EXCLUDED.amende, decouvrable = EXCLUDED.decouvrable, maj_le = now();

-- Peine d'un acte (getPeineParActe) : bareme propre, sinon bareme du type.
CREATE OR REPLACE FUNCTION public.crime_peine_interne(p_acte text, p_demasque boolean)
 RETURNS TABLE(jours integer, amende integer) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT (coalesce(a.peine_jours, CASE a.type WHEN 'delit_grave' THEN 4 WHEN 'crime' THEN 8 WHEN 'crime_etat' THEN 30 ELSE 2 END)
               * CASE WHEN p_demasque AND a.peine_jours IS NOT NULL THEN 2 ELSE 1 END)::integer,
              (coalesce(a.amende, CASE a.type WHEN 'delit_grave' THEN 1500 WHEN 'crime' THEN 5000 WHEN 'crime_etat' THEN 0 ELSE 500 END)
               * CASE WHEN p_demasque AND a.peine_jours IS NOT NULL THEN 2 ELSE 1 END)::integer
        FROM (SELECT * FROM public.actes_illegaux WHERE fn = p_acte
              UNION ALL SELECT p_acte, 'delit_mineur', 25, NULL, NULL, false, now()
              WHERE NOT EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = p_acte)) a LIMIT 1 $$;

-- Inscription a l'avis de recherche (meme forme que recherche_inscrire).
CREATE OR REPLACE FUNCTION public.crime_rechercher_interne(p_nom text, p_acte text, p_type text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees
     SET recherche = (CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END)
                     || jsonb_build_array(jsonb_build_object('acte', p_acte, 'type', p_type, 'jour', coalesce(day, 1), 'country', country))
   WHERE name = p_nom;
  PERFORM set_config('rp.recherche_interne', '', true);
END; $function$;

-- Detection. p_selon_checkdetection : regles de checkDetection (immunites, discretion).
-- p_acte_recherche : le motif inscrit (par defaut l'acte detecte). Rend true si repere.
CREATE OR REPLACE FUNCTION public.crime_detecter_interne(p_nom text, p_acte text, p_selon_checkdetection boolean,
                                                        p_acte_recherche text DEFAULT NULL)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a record; d record; v_dis numeric; v_taux integer;
BEGIN
  SELECT * INTO a FROM public.actes_illegaux WHERE fn = p_acte;
  IF NOT FOUND THEN RETURN false; END IF;
  SELECT poste ->> 'id' AS poste, resources INTO d FROM public.personnages_donnees WHERE name = p_nom;
  v_dis := coalesce(CASE WHEN jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric END, 50);
  IF p_selon_checkdetection THEN
    IF d.poste = 'president' THEN RETURN false; END IF;
    IF d.poste IN ('pm','min_int','min_fin','min_just','min_def','min_info','min_ae') AND a.type = 'delit_mineur' THEN RETURN false; END IF;
    v_taux := greatest(5, a.detect_rate - floor(v_dis / 10)::integer);
  ELSE
    v_taux := a.detect_rate;
  END IF;
  IF floor(random() * 100)::integer + 1 > v_taux THEN RETURN false; END IF;
  PERFORM public.crime_rechercher_interne(p_nom, coalesce(p_acte_recherche, p_acte), a.type);
  IF p_selon_checkdetection THEN
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                                 '{dis}', to_jsonb(greatest(0, v_dis - 10)))
     WHERE name = p_nom;
  END IF;
  RETURN true;
END; $function$;

-- Trace d'origine serveur, decouvrable pendant 8 jours.
CREATE OR REPLACE FUNCTION public.crime_tracer_interne(p_nom text, p_acte text, p_cible text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ UPDATE public.personnages_donnees
         SET historique_crimes = (CASE WHEN jsonb_typeof(historique_crimes) = 'array' THEN historique_crimes ELSE '[]'::jsonb END)
           || jsonb_build_array(jsonb_build_object('id', 'crime-' || replace(gen_random_uuid()::text, '-', ''),
                'acte', p_acte, 'cible', p_cible, 'jour', coalesce(day, 1), 'expireJour', coalesce(day, 1) + 8,
                'origine', 'serveur',
                'expireTs', to_char((now() + interval '8 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
       WHERE name = p_nom $$;

CREATE OR REPLACE FUNCTION public.minuit_decouverte_crimes()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; t jsonb; v_rate integer; v_jours integer; v_amende integer; v_n integer := 0; v_label text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR r IN SELECT name, country, coalesce(current_city, 'capitale') AS city, historique_crimes FROM public.personnages_donnees
            WHERE jsonb_typeof(historique_crimes) = 'array' AND jsonb_array_length(historique_crimes) > 0 LOOP
    FOR t IN SELECT e FROM jsonb_array_elements(r.historique_crimes) e
              WHERE e ->> 'origine' = 'serveur' AND NOT coalesce((e ->> 'decouvert')::boolean, false)
                AND (e ->> 'expireTs') IS NOT NULL AND now() < (e ->> 'expireTs')::timestamptz
                AND EXISTS (SELECT 1 FROM public.actes_illegaux a WHERE a.fn = e ->> 'acte' AND a.decouvrable) LOOP
      SELECT detect_rate INTO v_rate FROM public.actes_illegaux WHERE fn = t ->> 'acte';
      IF floor(random() * 100)::integer + 1 <= coalesce(v_rate, 25) THEN
        UPDATE public.personnages_donnees
           SET historique_crimes = (SELECT jsonb_agg(CASE WHEN e ->> 'id' = t ->> 'id' THEN e || '{"decouvert": true}'::jsonb ELSE e END)
                                      FROM jsonb_array_elements(historique_crimes) e)
         WHERE name = r.name;
        SELECT p.jours, p.amende INTO v_jours, v_amende FROM public.crime_peine_interne(t ->> 'acte', true) p;
        v_label := 'Affaire résolue : ' || replace(t ->> 'acte', '_', ' ');
        PERFORM public.detention_ouvrir_interne(r.name, v_label, v_jours, r.city, r.country,
          jsonb_build_array(jsonb_build_object('type', v_label, 'jours', v_jours, 'city', r.city, 'source', 'decouverte_differee',
            'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
          'Brigade Criminelle', 'decouverte_differee');
        UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_amende) WHERE name = r.name;
        PERFORM public.mail_systeme_poser_interne('Brigade Criminelle', r.name, 'Affaire résolue',
          'Une enquête a permis de vous identifier comme responsable d''un acte commis récemment. Vous êtes arrêté(e) : '
          || v_jours || ' jour(s), amende de ' || v_amende || ' FR.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
        v_n := v_n + 1;
        EXIT;   -- une seule affaire par personne et par nuit
      END IF;
    END LOOP;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'decouvertes', v_n);
END; $function$;

REVOKE ALL ON FUNCTION public.crime_peine_interne(text, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_rechercher_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_detecter_interne(text, text, boolean, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_tracer_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.minuit_decouverte_crimes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.minuit_decouverte_crimes() TO service_role;
