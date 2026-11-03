-- =============================================================================================
-- GRÈVE GÉNÉRALE : CONSULTATION, RÉPONSES ET RETRAITS PAR LE SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, point 4), dernière table écrivable par tout joueur identifié :
-- `greves_generales`. N'importe qui pouvait insérer une grève générale déjà « active » (niveau 5)
-- dans n'importe quel pays, réécrire les réponses des syndicats ou clore une grève en cours ; la
-- passe de minuit appliquait ensuite ses effets (POP du gouvernement, Social, économie).
--
-- Quatre portes, règles d'origine conservées (cahier des charges des grèves, 3 septembre 2026) :
--   . greve_generale_lancer(p_orga, p_revendications) — chef d'un syndicat d'au moins 5 membres,
--     sans grève générale en cours, 1 PA ; liste FIGÉE des syndicats éligibles du pays (au moins
--     5 membres, chef actif depuis 30 jours au plus), l'initiateur acceptant d'office ;
--   . greve_generale_lier_sujet(p_gg, p_topic) — l'initiateur rattache le sujet du Forum National ;
--   . greve_generale_repondre(p_gg, p_orga, p_reponse) — chef du syndicat consulté, une seule
--     réponse ; adoption quand au moins 2/3 des éligibles acceptent ET au moins 100 adhérents
--     uniques, palier de puissance 1 à 5 par tranche de 100 ;
--   . greve_generale_retirer(p_orga) — chef d'un syndicat participant ; sous 100 adhérents
--     restants la grève s'effondre (terminée), sinon le palier est recalculé.
-- L'état des syndicats est recopié par greve_generale_synchroniser. INSERT/UPDATE fermés à
-- l'écran ; la passe de minuit écrit avec la clé de service.
-- =============================================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('appel_greve_generale', 1, 0) ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.greve_generale_palier_interne(p_adherents integer)
 RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_adherents < 100 THEN NULL ELSE least(5, p_adherents / 100) END
$function$;

CREATE OR REPLACE FUNCTION public.greve_generale_adherents_interne(p_participants jsonb)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT count(DISTINCT m->>'nom')::integer
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_participants) = 'array' THEN p_participants ELSE '[]'::jsonb END) p
    JOIN public.organisations o ON o.id = p->>'orgaId'
    CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array'
                                                 THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) m
   WHERE p->>'statut' = 'accepte' AND coalesce(m->>'nom', '') <> ''
$function$;
REVOKE ALL ON FUNCTION public.greve_generale_adherents_interne(jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.greve_generale_lancer(p_orga text, p_revendications text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d jsonb; v_pays text; v_rev text; v_paie jsonb; v_id text; v_part jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data::jsonb, country_origine INTO v_d, v_pays FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF v_d IS NULL OR v_d->>'type' IS DISTINCT FROM 'syndicale' THEN RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_introuvable'); END IF;
  IF v_d->>'chef' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
  IF coalesce(jsonb_array_length(CASE WHEN jsonb_typeof(v_d->'membres') = 'array' THEN v_d->'membres' END), 0) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_trop_petit');
  END IF;
  IF coalesce(v_d->>'greveGeneraleEnCoursId', '') <> '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_engage'); END IF;
  v_rev := left(btrim(coalesce(p_revendications, '')), 4000);
  IF v_rev = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'revendications_requises'); END IF;

  v_paie := public.payer_ordre(v_moi, 'appel_greve_generale', 1, 0);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object('orgaId', o.id, 'orgaNom', o.data::jsonb->>'nom', 'chef', o.data::jsonb->>'chef',
           'statut', CASE WHEN o.id = p_orga THEN 'accepte' ELSE 'en_discussion' END) ORDER BY (o.id <> p_orga), o.id), '[]'::jsonb)
    INTO v_part
    FROM public.organisations o
   WHERE o.id = p_orga
      OR (o.data::jsonb->>'type' = 'syndicale' AND o.country_origine = v_pays
          AND coalesce(o.data::jsonb->>'chef', '') <> ''
          AND coalesce(jsonb_array_length(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array' THEN o.data::jsonb->'membres' END), 0) >= 5
          AND EXISTS (SELECT 1 FROM public.personnages_donnees c WHERE c.name = o.data::jsonb->>'chef'
                                                                   AND c.updated_at >= now() - interval '30 days'));

  v_id := 'greve_generale_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  INSERT INTO public.greves_generales (id, country, statut, initiateur, syndicat_initiateur_id, revendications,
                                       participants, date_lancement, jours_actifs)
  VALUES (v_id, v_pays, 'consultation', v_moi, p_orga, v_rev, v_part, now(), 0);
  PERFORM public.greve_generale_synchroniser(v_id);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'participants', v_part, 'paiement', v_paie);
END $function$;

CREATE OR REPLACE FUNCTION public.greve_generale_lier_sujet(p_gg text, p_topic text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.forum_topics WHERE id = p_topic) THEN RETURN jsonb_build_object('ok', false, 'raison', 'sujet_introuvable'); END IF;
  UPDATE public.greves_generales SET forum_topic_id = p_topic
   WHERE id = p_gg AND initiateur = v_moi AND forum_topic_id IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'refuse'); END IF;
  RETURN jsonb_build_object('ok', true);
END $function$;

CREATE OR REPLACE FUNCTION public.greve_generale_repondre(p_gg text, p_orga text, p_reponse text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_gg public.greves_generales; v_part jsonb; v_idx integer; v_n integer; v_acc integer;
        v_adh integer; v_niveau integer; v_adoptee boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_reponse NOT IN ('accepte', 'refuse') THEN RETURN jsonb_build_object('ok', false, 'raison', 'reponse_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organisations WHERE id = p_orga AND data::jsonb->>'chef' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef');
  END IF;
  SELECT * INTO v_gg FROM public.greves_generales WHERE id = p_gg FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'consultation_introuvable'); END IF;
  IF v_gg.statut IS DISTINCT FROM 'consultation' THEN RETURN jsonb_build_object('ok', false, 'raison', 'consultation_close'); END IF;
  v_part := CASE WHEN jsonb_typeof(v_gg.participants) = 'array' THEN v_gg.participants ELSE '[]'::jsonb END;
  SELECT i - 1 INTO v_idx FROM jsonb_array_elements(v_part) WITH ORDINALITY t(e, i) WHERE e->>'orgaId' = p_orga LIMIT 1;
  IF v_idx IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_concerne'); END IF;
  IF v_part->v_idx->>'statut' IS DISTINCT FROM 'en_discussion' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_repondu'); END IF;
  v_part := jsonb_set(v_part, ARRAY[v_idx::text, 'statut'], to_jsonb(p_reponse));

  v_n := jsonb_array_length(v_part);
  SELECT count(*) INTO v_acc FROM jsonb_array_elements(v_part) e WHERE e->>'statut' = 'accepte';
  v_adh := public.greve_generale_adherents_interne(v_part);
  IF v_n > 0 AND v_acc >= ceil(v_n * 2.0 / 3.0) AND v_adh >= 100 THEN
    v_niveau := public.greve_generale_palier_interne(v_adh);
    UPDATE public.greves_generales SET participants = v_part, statut = 'active', date_entree_vigueur = now(),
           puissance_niveau = v_niveau WHERE id = p_gg;
    v_adoptee := true;
  ELSE
    UPDATE public.greves_generales SET participants = v_part WHERE id = p_gg;
  END IF;
  PERFORM public.greve_generale_synchroniser(p_gg);
  RETURN jsonb_build_object('ok', true, 'adoptee', v_adoptee, 'niveau', v_niveau, 'adherents', v_adh);
END $function$;

CREATE OR REPLACE FUNCTION public.greve_generale_retirer(p_orga text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d jsonb; v_ggid text; v_gg public.greves_generales; v_part jsonb; v_idx integer; v_adh integer;
        v_terminee boolean := false; v_niveau integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data::jsonb INTO v_d FROM public.organisations WHERE id = p_orga;
  IF v_d IS NULL OR v_d->>'chef' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
  v_ggid := v_d->>'greveGeneraleEnCoursId';
  SELECT * INTO v_gg FROM public.greves_generales WHERE id = v_ggid FOR UPDATE;
  IF NOT FOUND OR v_gg.statut IS DISTINCT FROM 'active' THEN
    IF v_ggid IS NOT NULL THEN PERFORM public.greve_generale_synchroniser(v_ggid); END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_greve_active');
  END IF;
  v_part := CASE WHEN jsonb_typeof(v_gg.participants) = 'array' THEN v_gg.participants ELSE '[]'::jsonb END;
  SELECT i - 1 INTO v_idx FROM jsonb_array_elements(v_part) WITH ORDINALITY t(e, i)
   WHERE e->>'orgaId' = p_orga AND e->>'statut' = 'accepte' LIMIT 1;
  IF v_idx IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_concerne'); END IF;
  v_part := jsonb_set(v_part, ARRAY[v_idx::text, 'statut'], '"retire"'::jsonb);
  v_adh := public.greve_generale_adherents_interne(v_part);
  IF v_adh < 100 THEN
    UPDATE public.greves_generales SET participants = v_part, statut = 'terminee' WHERE id = v_ggid;
    v_terminee := true;
  ELSE
    v_niveau := public.greve_generale_palier_interne(v_adh);
    UPDATE public.greves_generales SET participants = v_part, puissance_niveau = v_niveau WHERE id = v_ggid;
  END IF;
  PERFORM public.greve_generale_synchroniser(v_ggid);
  RETURN jsonb_build_object('ok', true, 'id', v_ggid, 'terminee', v_terminee, 'niveau', v_niveau, 'adherents', v_adh);
END $function$;

REVOKE ALL ON FUNCTION public.greve_generale_lancer(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.greve_generale_lier_sujet(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.greve_generale_repondre(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.greve_generale_retirer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.greve_generale_lancer(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.greve_generale_lier_sujet(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.greve_generale_repondre(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.greve_generale_retirer(text) TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON public.greves_generales FROM authenticated, anon;
DROP POLICY IF EXISTS greves_generales_ecriture_acteur ON public.greves_generales;
DROP POLICY IF EXISTS greves_generales_maj_acteur ON public.greves_generales;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.greves_generales', 'INSERT')
     OR has_table_privilege('authenticated', 'public.greves_generales', 'UPDATE') THEN
    RAISE EXCEPTION 'greves_generales encore écrivable par l''écran';
  END IF;
  IF NOT has_table_privilege('authenticated', 'public.greves_generales', 'SELECT') THEN RAISE EXCEPTION 'lecture perdue'; END IF;
  IF has_function_privilege('authenticated', 'public.greve_generale_adherents_interne(jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'moteur exécutable par l''écran';
  END IF;
END $$;
