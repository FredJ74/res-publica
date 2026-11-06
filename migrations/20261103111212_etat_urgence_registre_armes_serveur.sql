-- =============================================================================================
-- ÉTAT D'URGENCE ET REGISTRE DES VENTES D'ARMES ÉCRITS PAR LE SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, point 4). Deux tables encore écrivables par tout joueur identifié :
--   . etats_urgence : n'importe qui pouvait déclarer ou lever l'état d'urgence d'un pays
--     (arrestations sans plainte préalable) ; le contrôle du poste n'était fait qu'à l'écran, et
--     le malus POP / bonus INF du Président était tiré par le navigateur ;
--   . registre_ventes_armes : l'achat légal était fait par le serveur (arme_acheter), mais
--     l'inscription au registre par l'écran — on pouvait donc acheter sans être inscrit, ou
--     inscrire n'importe qui pour un achat qu'il n'avait pas fait.
--
-- Porte etat_urgence_decider(p_activer) : Président du pays, 3 PA (coût de l'écran, déclaré), refus
-- si l'état demandé est déjà en vigueur ; à la déclaration, POP −(5 à 19) et INF +(5 à 14) du
-- Président, tirés au serveur (barème d'origine).
-- arme_acheter inscrit désormais la vente au registre (joueur, arme, prix payé, pays, ville, jour)
-- dans la même transaction et rend `registre_id`.
-- INSERT/UPDATE fermés à l'écran sur les deux tables ; lecture conservée.
-- =============================================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('etat_urgence', 3, 0) ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.etat_urgence_decider(p_activer boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_jour integer; v_actif boolean; v_paie jsonb; v_pop integer := 0; v_inf integer := 0;
        v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(day, 1) INTO v_pays, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('president', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  SELECT actif INTO v_actif FROM public.etats_urgence WHERE country = v_pays FOR UPDATE;
  IF coalesce(v_actif, false) = coalesce(p_activer, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN p_activer THEN 'deja_en_vigueur' ELSE 'pas_en_vigueur' END);
  END IF;

  v_paie := public.payer_ordre(v_moi, 'etat_urgence', 3, 0);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  INSERT INTO public.etats_urgence (country, actif, active_par, jour_debut)
  VALUES (v_pays, p_activer, v_moi, v_jour)
  ON CONFLICT (country) DO UPDATE SET actif = EXCLUDED.actif, active_par = EXCLUDED.active_par,
                                      jour_debut = EXCLUDED.jour_debut;

  IF p_activer THEN
    v_pop := -(floor(random() * 15)::integer + 5);
    v_inf := floor(random() * 10)::integer + 5;
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
             '{pop}', to_jsonb(greatest(0, least(100, coalesce(CASE WHEN jsonb_typeof(resources->'pop') = 'number' THEN (resources->>'pop')::numeric END, 50) + v_pop)))),
             '{inf}', to_jsonb(greatest(0, least(100, coalesce(CASE WHEN jsonb_typeof(resources->'inf') = 'number' THEN (resources->>'inf')::numeric END, 0) + v_inf)))),
           updated_at = clock_timestamp()
     WHERE name = v_moi
    RETURNING resources INTO v_res;
  END IF;
  RETURN jsonb_build_object('ok', true, 'actif', p_activer, 'paiement', v_paie, 'delta_pop', v_pop, 'delta_inf', v_inf,
                            'pop', v_res->'pop', 'inf', v_res->'inf');
END $function$;
REVOKE ALL ON FUNCTION public.etat_urgence_decider(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.etat_urgence_decider(boolean) TO authenticated;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.arme_acheter(text,text)'::regprocedure);
  IF position('registre_ventes_armes' IN v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$DECLARE v_moi text; v_objet jsonb; v_r jsonb; v_dep jsonb;$a$,
                          $n$DECLARE v_moi text; v_objet jsonb; v_r jsonb; v_dep jsonb; v_registre bigint;$n$);
  v_new := replace(v_new, $a$  RETURN v_r || (v_dep - 'ok' - 'qte') || jsonb_build_object('objet', v_objet ->> 'name');$a$,
                          $n$  -- Inscription au registre officiel, dans la même transaction que la vente (03/11/2026).
  INSERT INTO public.registre_ventes_armes (joueur, arme, prix, pays, city, jour, heure)
  SELECT v_moi, v_objet ->> 'name', coalesce((v_r ->> 'total')::numeric, 0)::integer, d.country,
         coalesce(d.current_city, 'capitale'), coalesce(d.day, 1),
         extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer
    FROM public.personnages_donnees d WHERE d.name = v_moi
  RETURNING id INTO v_registre;
  RETURN v_r || (v_dep - 'ok' - 'qte') || jsonb_build_object('objet', v_objet ->> 'name', 'registre_id', v_registre);$n$);
  IF position('v_registre bigint' IN v_new) = 0 OR position('RETURNING id INTO v_registre' IN v_new) = 0 THEN
    RAISE EXCEPTION 'patch arme_acheter non appliqué';
  END IF;
  EXECUTE v_new;
END $mig$;

REVOKE INSERT, UPDATE, DELETE ON public.etats_urgence FROM authenticated, anon;
DROP POLICY IF EXISTS etats_urgence_ecriture_acteur ON public.etats_urgence;
DROP POLICY IF EXISTS etats_urgence_maj_acteur ON public.etats_urgence;
REVOKE INSERT, UPDATE, DELETE ON public.registre_ventes_armes FROM authenticated, anon;
DROP POLICY IF EXISTS registre_ventes_armes_ecriture_acteur ON public.registre_ventes_armes;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.etats_urgence', 'INSERT')
     OR has_table_privilege('authenticated', 'public.etats_urgence', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.registre_ventes_armes', 'INSERT') THEN
    RAISE EXCEPTION 'tables encore écrivables par l''écran';
  END IF;
  IF NOT has_table_privilege('authenticated', 'public.etats_urgence', 'SELECT')
     OR NOT has_table_privilege('authenticated', 'public.registre_ventes_armes', 'SELECT') THEN
    RAISE EXCEPTION 'lecture perdue';
  END IF;
  IF has_function_privilege('anon', 'public.etat_urgence_decider(boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'etat_urgence_decider ouvert à anon';
  END IF;
END $$;
