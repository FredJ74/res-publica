-- SALLES DE REUNION DE NOVOMIRSK : EVENEMENTS (Claude, 07/11/2026, decision de Fred : idees 5 et 6)
--
-- Le PJ qui a reserve une salle pour la journee peut y organiser des evenements. Les participants
-- sont les PJ presents dans la salle au moment ou il lance l'evenement (position serveur).
-- Chaque type d'evenement : une fois par salle et par jour ; chaque PJ n'en profite qu'une fois
-- par jour et par type, quelle que soit la salle. Valeurs proposees par Claude, a valider par Fred :
--   * conference_presse : organisateur +3 POP, +1 POP par autre PJ present (au plus +10 au total) ;
--   * reseautage        : chaque autre PJ present +2 INF ; organisateur +1 INF par participant (au plus +8) ;
--   * seminaire         : tous les presents, organisateur compris, +1 a la caracteristique choisie
--                         jusqu'a minuit, sans cumul de seminaires ;
--   * buffet            : l'organisateur paie 40 PSK par present au restaurant du Grand Hotel de Sovarka
--                         (encaissement commun : taxe locale, caisse, journal) ; chaque present +2 PA.
-- Chaque evenement coute 1 PA a l'organisateur. Les participants sont prevenus par courrier.

CREATE TABLE IF NOT EXISTS public.sovarka_reunions_evenements (
  jour date NOT NULL,
  salle text NOT NULL,
  type text NOT NULL CHECK (type IN ('conference_presse','reseautage','seminaire','buffet')),
  organisateur text NOT NULL,
  participants jsonb NOT NULL DEFAULT '[]'::jsonb,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour, salle, type)
);
CREATE TABLE IF NOT EXISTS public.sovarka_reunions_beneficiaires (
  jour date NOT NULL, type text NOT NULL, personnage text NOT NULL,
  PRIMARY KEY (jour, type, personnage)
);
ALTER TABLE public.sovarka_reunions_evenements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_reunions_beneficiaires ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.sovarka_reunions_evenements, public.sovarka_reunions_beneficiaires FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'sovarka_reunion_evenement', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'sovarka_reunion_evenement');

CREATE OR REPLACE FUNCTION public.sovarka_reunion_evenement(p_requete uuid, p_salle text, p_type text, p_carac text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  a text := public.mon_personnage(); act text := 'sovarka:reunion_evenement'; par jsonb;
  v jsonb; dt text; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_presents text[]; v_autres text[]; n text; v_nb int; v_gain int; v_benef text[] := '{}';
  v_paie jsonb; v_enc jsonb; v_now numeric; v_fin numeric; v_eff jsonb; v_titre text; v_corps text;
  c_prix_buffet constant int := 40;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  par := jsonb_build_object('salle', p_salle, 'type', p_type, 'carac', p_carac);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    IF p_type NOT IN ('conference_presse','reseautage','seminaire','buffet') OR p_type IS NULL THEN
      v := jsonb_build_object('ok', false, 'raison', 'evenement_inconnu');
    ELSIF p_type = 'seminaire' AND coalesce(p_carac, '') NOT IN ('CHA','DUP','ENT','INT','PER','VOL') THEN
      v := jsonb_build_object('ok', false, 'raison', 'caracteristique_inconnue');
    ELSIF NOT EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = a AND p.country = 'soviet'
                        AND p.current_city = 'capitale' AND p.current_building = 'centre-affaires' AND p.current_room = p_salle) THEN
      v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
    ELSIF NOT EXISTS (SELECT 1 FROM public.sovarka_reunions_reservations r
                       WHERE r.jour = v_jour AND r.salle = p_salle AND r.reserve_par = a) THEN
      v := jsonb_build_object('ok', false, 'raison', 'salle_non_reservee');
    ELSE
      PERFORM pg_advisory_xact_lock(hashtext('sovarka:evenement:'||v_jour::text||':'||p_salle||':'||p_type));
      IF EXISTS (SELECT 1 FROM public.sovarka_reunions_evenements e WHERE e.jour = v_jour AND e.salle = p_salle AND e.type = p_type) THEN
        v := jsonb_build_object('ok', false, 'raison', 'evenement_deja_tenu');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_reunion_evenement', 1, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
          v := v_paie;
        ELSE
          SELECT array_agg(p.name ORDER BY p.name) INTO v_presents FROM public.personnages_donnees p
           WHERE p.country = 'soviet' AND p.current_city = 'capitale' AND p.current_building = 'centre-affaires'
             AND p.current_room = p_salle AND coalesce(p.hp, 0) > 0;
          v_autres := array_remove(v_presents, a);
          v_nb := coalesce(array_length(v_autres, 1), 0);

          IF p_type = 'conference_presse' THEN
            v_titre := 'Conférence de presse';
            IF NOT EXISTS (SELECT 1 FROM public.sovarka_reunions_beneficiaires WHERE jour = v_jour AND type = p_type AND personnage = a) THEN
              v_gain := least(10, 3 + v_nb);
              PERFORM public.jauges_effet_appliquer_interne(a, v_gain, 0);
              v_benef := ARRAY[a];
            END IF;
            v_corps := 'Conférence de presse donnée par '||a||' au Centre d''affaires de Novomirsk.';
          ELSIF p_type = 'reseautage' THEN
            v_titre := 'Soirée de réseautage';
            FOREACH n IN ARRAY coalesce(v_autres, '{}') LOOP
              IF NOT EXISTS (SELECT 1 FROM public.sovarka_reunions_beneficiaires WHERE jour = v_jour AND type = p_type AND personnage = n) THEN
                PERFORM public.jauges_effet_appliquer_interne(n, 0, 2);
                v_benef := v_benef || n;
              END IF;
            END LOOP;
            IF v_nb > 0 AND NOT EXISTS (SELECT 1 FROM public.sovarka_reunions_beneficiaires WHERE jour = v_jour AND type = p_type AND personnage = a) THEN
              PERFORM public.jauges_effet_appliquer_interne(a, 0, least(8, v_nb));
              v_benef := v_benef || a;
            END IF;
            v_corps := 'Soirée de réseautage organisée par '||a||' : +2 INF pour vous.';
          ELSIF p_type = 'seminaire' THEN
            v_titre := 'Séminaire de formation';
            v_now := extract(epoch FROM clock_timestamp()) * 1000;
            v_fin := extract(epoch FROM ((date_trunc('day', now() AT TIME ZONE 'Europe/Paris') + interval '1 day')
                     AT TIME ZONE 'Europe/Paris')) * 1000;
            FOREACH n IN ARRAY coalesce(v_presents, '{}') LOOP
              SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_eff
                FROM public.personnages_donnees p, jsonb_array_elements(coalesce(p.effets_actifs, '[]'::jsonb)) e
               WHERE p.name = n AND jsonb_typeof(e) = 'object' AND coalesce((e->>'expireA')::numeric, 0) > v_now;
              IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_eff) e WHERE e->>'cle' LIKE 'seminaire\_%')
                 AND NOT EXISTS (SELECT 1 FROM public.sovarka_reunions_beneficiaires WHERE jour = v_jour AND type = p_type AND personnage = n) THEN
                v_eff := v_eff || jsonb_build_array(jsonb_build_object('cle', 'seminaire_'||lower(p_carac), 'cible', 'pj',
                  'deltas', jsonb_build_object(p_carac, 1), 'libelle', 'Séminaire de formation',
                  'poseA', v_now, 'expireA', v_fin));
                UPDATE public.personnages_donnees SET effets_actifs = v_eff WHERE name = n;
                v_benef := v_benef || n;
              END IF;
            END LOOP;
            v_corps := 'Séminaire de formation organisé par '||a||' : '||p_carac||' +1 jusqu''à minuit.';
          ELSE
            v_titre := 'Buffet du Grand Hôtel';
            v_enc := public.vehicule_encaisser_interne(a, 'brasserie-soviet-capitale-hotel-republica',
                       c_prix_buffet * coalesce(array_length(v_presents, 1), 1), 'Buffet en salle de réunion');
            IF (v_enc->>'ok')::boolean IS DISTINCT FROM true THEN
              RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = v_enc::text;
            END IF;
            FOREACH n IN ARRAY coalesce(v_presents, '{}') LOOP
              IF NOT EXISTS (SELECT 1 FROM public.sovarka_reunions_beneficiaires WHERE jour = v_jour AND type = p_type AND personnage = n) THEN
                PERFORM public.pa_crediter_interne(n, 2);
                v_benef := v_benef || n;
              END IF;
            END LOOP;
            v_corps := 'Buffet du Grand Hôtel offert par '||a||' : +2 PA pour vous.';
          END IF;

          INSERT INTO public.sovarka_reunions_beneficiaires (jour, type, personnage)
          SELECT v_jour, p_type, x FROM unnest(v_benef) x ON CONFLICT DO NOTHING;
          INSERT INTO public.sovarka_reunions_evenements (jour, salle, type, organisateur, participants, detail)
          VALUES (v_jour, p_salle, p_type, a, to_jsonb(coalesce(v_presents, '{}')),
                  jsonb_build_object('beneficiaires', to_jsonb(v_benef), 'carac', p_carac));
          FOREACH n IN ARRAY coalesce(v_autres, '{}') LOOP
            IF p_type <> 'conference_presse' AND n = ANY(v_benef) THEN
              PERFORM public.mail_systeme_poser_interne('Centre d''affaires de Novomirsk', n, v_titre, v_corps, NULL);
            END IF;
          END LOOP;
          v := jsonb_build_object('ok', true, 'type', p_type, 'titre', v_titre, 'presents', to_jsonb(coalesce(v_presents, '{}')),
                 'beneficiaires', to_jsonb(v_benef), 'pa', (SELECT pa FROM public.personnages_donnees WHERE name = a),
                 'jauges', (SELECT jsonb_build_object('pop', resources->'pop', 'inf', resources->'inf') FROM public.personnages_donnees WHERE name = a),
                 'effets_actifs', (SELECT effets_actifs FROM public.personnages_donnees WHERE name = a))
               || CASE WHEN p_type = 'buffet' THEN jsonb_build_object('paye', c_prix_buffet * coalesce(array_length(v_presents, 1), 1)) ELSE '{}'::jsonb END;
        END IF;
      END IF;
    END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_reunion_evenement(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_reunion_evenement(uuid, text, text, text) TO authenticated;
