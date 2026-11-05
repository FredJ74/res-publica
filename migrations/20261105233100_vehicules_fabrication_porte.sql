-- APPLIQUEE le 06/11/2026 par Claude (registre vehicules_fabrication_porte_20261105233100), puis banc annule outils/bancs/banc-vehicules-fabrication.sql joue en production : vert.
-- 6 novembre 2026 -- VEHICULES PERSONNELS, etape 5 bis : la porte vehicule_acte accepte « fabriquer » et
-- « travailler », la lecture vehicules_lire montre la fabrication en cours du garage ou l'on se trouve.
-- Patchs en place (WORKFLOW-SUPABASE.md), reconnus a leur marque : idempotente.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.vehicule_acte(uuid,text,jsonb)'::regprocedure);
  IF strpos(v_def, 'vehicules_fabrication_v1') = 0 THEN
    v_new := replace(v_def, $a$'trajet', 'depanner', 'reviser') THEN$a$,
      $b$'trajet', 'depanner', 'reviser', 'fabriquer', 'travailler') THEN -- vehicules_fabrication_v1$b$);
    v_new := replace(v_new, $a$      WHEN 'depanner'  THEN public.vehicule_depanner_interne(a, p_parametres)$a$,
      $b$      WHEN 'depanner'  THEN public.vehicule_depanner_interne(a, p_parametres)
      WHEN 'fabriquer' THEN public.vehicule_fabriquer_interne(a, p_parametres)
      WHEN 'travailler' THEN public.vehicule_travailler_interne(a, p_parametres)$b$);
    IF (length(v_new) - length(v_def)) < 150 THEN RAISE EXCEPTION 'patch vehicule_acte non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.vehicules_lire()'::regprocedure);
  IF strpos(v_def, 'vehicules_fabrication_v1') = 0 THEN
    v_new := replace(v_def, $a$           'pieces', coalesce((e.data->'stockMatieres'->>'derives_petrochimiques')::numeric, 0))$a$,
      $b$           'pieces', coalesce((e.data->'stockMatieres'->>'derives_petrochimiques')::numeric, 0),
           'matieres', e.data->'stockMatieres', 'stock_max', e.data->'parametres'->'stockMax', -- vehicules_fabrication_v1
           'fabrication', (SELECT jsonb_build_object('modele', f.modele, 'jours_faits', f.jours_faits, 'jours_total', f.jours_total,
               'etat', f.etat, 'lance_par', f.lance_par,
               'besoin_jour', public.vehicule_tranche_interne(f.pa_total, f.jours_faits + 1, f.jours_total),
               'pa_pj', f.pa_pj,
               'matieres_jour', (SELECT jsonb_object_agg(k, public.vehicule_tranche_interne((q#>>'{}')::numeric, f.jours_faits + 1, f.jours_total))
                                   FROM jsonb_each(f.materiaux) x(k, q)))
             FROM public.garage_fabrications f WHERE f.entreprise = e.id AND f.etat <> 'achevee'),
           'modeles', (SELECT jsonb_object_agg(vm.modele, jsonb_build_object('jours', vm.jours, 'pa', rc.pa, 'materiaux', rc.materiaux))
             FROM public.vehicules_modeles vm JOIN public.recettes_commerce rc ON rc.id = vm.modele AND rc.source = 'garage'))$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch vehicules_lire non applique'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;
