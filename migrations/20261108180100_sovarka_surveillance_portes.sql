-- Sovarka : surveillance, portes et passe de nuit (suite de 20261108180000 ; séparation technique,
-- limite de transport du canal de migration).

-- Lecture : surveillances en cours du ministère et leurs rapports, cibles possibles.
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.sovarka_est_titulaire_interne(a, 'min_int') THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  RETURN jsonb_build_object('ok', true, 'max', 3, 'pa', 2, 'cout', 150,
    'caisse', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = 'soviet_gouvernement-min_int'),
    'cibles', (SELECT coalesce(jsonb_agg(d.name ORDER BY d.name), '[]'::jsonb) FROM public.personnages_donnees d WHERE d.name <> a),
    'surveillances', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'ts', s.ts, 'cible', s.cible, 'ministre', s.ministre,
        'statut', s.statut, 'rapports_restants', s.rapports_restants,
        'rapports', (SELECT coalesce(jsonb_agg(jsonb_build_object('jour', r.jour, 'depuis', r.depuis, 'jusqua', r.jusqua,
                       'deplacements', r.deplacements) ORDER BY r.jour DESC), '[]'::jsonb)
                       FROM public.sovarka_surveillance_rapports r WHERE r.surveillance = s.id)) ORDER BY s.ts DESC), '[]'::jsonb)
      FROM public.sovarka_surveillances s WHERE s.statut = 'active' OR s.ts > now() - interval '7 days'));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_surveillance_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_surveillance_lire() TO authenticated;

-- Porte : placer un PJ sous surveillance (bureau du ministre de la Sécurité du Peuple).
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_commande(p_requete uuid, p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); act text := 'sovarka:surveillance'; par jsonb; v jsonb; dt text; p record;
  v_paie jsonb; v_caisse jsonb; v_id uuid; v_cible text := btrim(coalesce(p_cible, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  par := jsonb_build_object('cible', v_cible);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    SELECT name, country, current_city, current_building, current_room INTO p
      FROM public.personnages_donnees WHERE name = a FOR UPDATE;
    PERFORM 1 FROM public.caisses_batiments WHERE id = 'soviet_gouvernement-min_int' FOR UPDATE;
    IF p.country IS DISTINCT FROM 'soviet' THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_a_sovarka');
    ELSIF NOT public.sovarka_est_titulaire_interne(a, 'min_int') THEN v := jsonb_build_object('ok', false, 'raison', 'poste_requis');
    ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_int') THEN
      v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
    ELSIF v_cible = a OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_cible) THEN
      v := jsonb_build_object('ok', false, 'raison', 'cible_invalide');
    ELSIF EXISTS (SELECT 1 FROM public.sovarka_surveillances WHERE cible = v_cible AND statut = 'active') THEN
      v := jsonb_build_object('ok', false, 'raison', 'deja_surveille');
    ELSIF (SELECT count(*) FROM public.sovarka_surveillances WHERE statut = 'active') >= 3 THEN
      v := jsonb_build_object('ok', false, 'raison', 'limite_surveillances');
    ELSE
      v_paie := public.payer_ordre_interne(a, 'sovarka_surveiller', 2, 0);
      IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
      ELSE
        PERFORM set_config('rp.caisse_interne', 'on', true);
        v_caisse := public.caisse_institution_mouvement('soviet_gouvernement-min_int', -150, true);
        PERFORM set_config('rp.caisse_interne', 'off', true);
        IF coalesce((v_caisse->>'ok')::boolean, false) IS NOT TRUE THEN
          v := jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
        ELSE
          INSERT INTO public.sovarka_surveillances (ministre, cible) VALUES (a, v_cible) RETURNING id INTO v_id;
          v := jsonb_build_object('ok', true, 'surveillance', v_id, 'cible', v_cible, 'jours', 4,
                 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;
    END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_surveillance_commande(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_surveillance_commande(uuid, text) TO authenticated;

-- Passe de nuit : un rapport par surveillance active, tirage de découverte, fin au quatrième rapport.
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := public.sovarka_jour_paris(); s public.sovarka_surveillances; v_depuis timestamptz;
  v_dep jsonb; v_chance numeric; v_vu boolean; v_texte text; v_dest text; v_n int := 0; v_k int;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR s IN SELECT * FROM public.sovarka_surveillances WHERE statut = 'active' ORDER BY ts FOR UPDATE LOOP
    CONTINUE WHEN NOT public.acte_nocturne_revendiquer('soviet', 'sovarka_surveillance_rapport', s.id::text || ':' || v_jour, NULL);
    v_depuis := coalesce((SELECT max(jusqua) FROM public.sovarka_surveillance_rapports WHERE surveillance = s.id), s.ts);
    v_dep := public.sovarka_surveillance_releve_interne(s.cible, v_depuis, now());
    v_chance := CASE WHEN s.decouverte THEN NULL ELSE public.sovarka_surveillance_chance_interne(s.cible) END;
    v_vu := v_chance IS NOT NULL AND random() * 100 < v_chance;
    INSERT INTO public.sovarka_surveillance_rapports (surveillance, jour, depuis, jusqua, deplacements, chance, decouverte)
    VALUES (s.id, v_jour, v_depuis, now(), v_dep, v_chance, v_vu);
    v_k := 5 - s.rapports_restants;
    UPDATE public.sovarka_surveillances SET rapports_restants = rapports_restants - 1,
           decouverte = decouverte OR v_vu, statut = CASE WHEN rapports_restants <= 1 THEN 'terminee' ELSE 'active' END
     WHERE id = s.id;
    SELECT string_agg('• ' || to_char((e->>'debut')::timestamptz AT TIME ZONE 'Europe/Paris', 'DD/MM HH24"h"MI') || ' — '
             || public.sovarka_surveillance_lieu_interne(e)
             || CASE WHEN jsonb_array_length(e->'croises') > 0
                     THEN ' — en présence de ' || (SELECT string_agg(c, ', ') FROM jsonb_array_elements_text(e->'croises') c) ELSE '' END,
             E'\n' ORDER BY (e->>'debut')::timestamptz)
      INTO v_texte FROM jsonb_array_elements(v_dep) e;
    v_dest := coalesce(public.sovarka_titulaire_interne('min_int'), s.ministre);
    PERFORM public.mail_systeme_poser_interne('Ministère de la Sécurité du Peuple', v_dest,
      'Rapport de surveillance — ' || s.cible || ' (' || v_k || '/4)',
      'Déplacements de ' || s.cible || ' depuis le dernier rapport :' || E'\n'
      || coalesce(v_texte, 'Aucun déplacement enregistré.')
      || CASE WHEN v_k >= 4 THEN E'\n\nFin de la surveillance.' ELSE '' END, NULL);
    IF v_vu THEN
      PERFORM public.mail_systeme_poser_interne('Pressentiment', s.cible, 'Vous avez l''impression d''être suivi',
        'Depuis quelques jours, les mêmes silhouettes reviennent derrière vous, une voiture stationne trop longtemps '
        || 'devant votre porte… Vous avez la certitude d''être surveillé, sans savoir par qui ni pourquoi.', NULL);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_surveillance_passe() FROM PUBLIC, anon, authenticated;

-- Raccordement à la passe de nuit des ministères (patch en place sous empreinte).
DO $patch$
DECLARE v_def text; v_n int;
  v_avant text := $a$'indemnites', v_pay, 'refractaires', v_ref,$a$;
  v_apres text := $b$'indemnites', v_pay, 'refractaires', v_ref, 'surveillances', public.sovarka_surveillance_passe(),$b$;
BEGIN
  v_def := pg_get_functiondef('public.sovarka_pouvoir_passe()'::regprocedure);
  IF position('sovarka_surveillance_passe' IN v_def) > 0 THEN RETURN; END IF;
  v_n := (length(v_def) - length(replace(v_def, v_avant, ''))) / length(v_avant);
  IF v_n <> 1 THEN RAISE EXCEPTION 'fragment non unique dans sovarka_pouvoir_passe (%)', v_n; END IF;
  EXECUTE replace(v_def, v_avant, v_apres);
END $patch$;
