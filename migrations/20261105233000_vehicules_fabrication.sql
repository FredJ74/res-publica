-- APPLIQUEE le 06/11/2026 par Claude (registre vehicules_fabrication_20261105233000), puis banc annule outils/bancs/banc-vehicules-fabrication.sql joue en production : vert.
-- 6 novembre 2026 -- VEHICULES PERSONNELS, etape 5 : la fabrication au garage (decision de Fred du 06/11/2026).
--
-- Decision : 10 jours pour une voiture, 15 pour un utilitaire, 5 pour un deux-roues. Meme principe que les
-- batiments et les bateaux : un PJ peut fournir la main-d'oeuvre de la journee, sinon ce sont les PNJ.
-- Mise en oeuvre (GAME-DESIGN-VEHICULES.md) :
--   * tout PJ present lance une fabrication dans un garage (regle de production du 01/11 : assez de place
--     sous le plafond de stock du proprietaire) ; un vehicule a la fois par garage ;
--   * la main-d'oeuvre totale est le PA de la recette (95 / 190 / 255), repartie jour par jour, comme les
--     matieres (repartition ceil(total*j/D) - ceil(total*(j-1)/D), aucune unite perdue) ;
--   * « Travailler a la fabrication » : le PJ present donne des PA de la journee en cours, payes 50 par PA
--     par la caisse du garage (tarif commun de main-d'oeuvre), sans depasser le besoin du jour ;
--   * a minuit, si les matieres du jour sont au stock du garage et que la caisse paie le reste de la
--     journee aux PNJ (50 par PA), la journee avance ; sinon la fabrication attend, sans jour perdu, et le
--     travail deja fourni par les PJ reste acquis pour le jour suivant ;
--   * a la derniere journee, le vehicule entre en vitrine (stock du garage).
-- Idempotente.

ALTER TABLE public.vehicules_modeles ADD COLUMN IF NOT EXISTS jours integer;
UPDATE public.vehicules_modeles SET jours = CASE modele WHEN 'voiture' THEN 10 WHEN 'vehicule-utilitaire' THEN 15 WHEN 'deux-roues' THEN 5 END;
ALTER TABLE public.vehicules_modeles ALTER COLUMN jours SET NOT NULL;

CREATE TABLE IF NOT EXISTS public.garage_fabrications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entreprise   text NOT NULL,
  modele       text NOT NULL REFERENCES public.vehicules_modeles(modele),
  jours_total  integer NOT NULL CHECK (jours_total > 0),
  jours_faits  integer NOT NULL DEFAULT 0 CHECK (jours_faits >= 0),
  pa_total     integer NOT NULL CHECK (pa_total > 0),
  materiaux    jsonb NOT NULL,
  pa_pj        integer NOT NULL DEFAULT 0 CHECK (pa_pj >= 0),
  etat         text NOT NULL DEFAULT 'en_cours' CHECK (etat IN ('en_cours', 'attente_matieres', 'attente_caisse', 'achevee')),
  dernier_jour date,
  lance_par    text NOT NULL,
  journal      jsonb NOT NULL DEFAULT '[]'::jsonb,
  cree_le      timestamptz NOT NULL DEFAULT now(),
  acheve_le    timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS garage_fabrications_une_par_garage ON public.garage_fabrications (entreprise) WHERE etat <> 'achevee';
ALTER TABLE public.garage_fabrications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.garage_fabrications FROM anon, authenticated;

-- Part du jour j (1..D) d'un total reparti sur D jours.
CREATE OR REPLACE FUNCTION public.vehicule_tranche_interne(p_total numeric, p_jour integer, p_jours integer)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (ceil(p_total * p_jour / p_jours) - ceil(p_total * (p_jour - 1) / p_jours))::integer;
$$;

CREATE OR REPLACE FUNCTION public.vehicule_fabriquer_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; d record; m public.vehicules_modeles; r public.recettes_commerce; v_stock numeric; v_max numeric; v_id uuid;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p->>'entreprise' FOR UPDATE;
  IF v_data IS NULL OR v_data->>'type' IS DISTINCT FROM 'garage' THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_introuvable'); END IF;
  SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = p_moi;
  IF (d.country, d.current_city, d.current_building) IS DISTINCT FROM (v_data->>'country', v_data->>'city', v_data->>'buildingId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO m FROM public.vehicules_modeles WHERE modele = p->>'modele';
  SELECT * INTO r FROM public.recettes_commerce WHERE id = p->>'modele' AND source = 'garage';
  IF m.modele IS NULL OR r.id IS NULL OR NOT (coalesce(v_data->'carte', '[]'::jsonb) @> jsonb_build_array(to_jsonb(m.modele))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose'); END IF;
  IF EXISTS (SELECT 1 FROM public.garage_fabrications WHERE entreprise = p->>'entreprise' AND etat <> 'achevee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fabrication_en_cours'); END IF;
  v_stock := coalesce((v_data->'stockProduits'->>m.modele)::numeric, 0);
  v_max := (v_data->'parametres'->'stockMax'->>m.modele)::numeric;
  IF v_max IS NOT NULL AND v_stock + 1 > v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'plafond', v_max); END IF;
  INSERT INTO public.garage_fabrications (entreprise, modele, jours_total, pa_total, materiaux, lance_par)
    VALUES (p->>'entreprise', m.modele, m.jours, r.pa, r.materiaux, p_moi) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'fabrication', v_id, 'modele', m.modele, 'jours', m.jours,
    'besoin_jour', public.vehicule_tranche_interne(r.pa, 1, m.jours));
END $$;

CREATE OR REPLACE FUNCTION public.vehicule_travailler_interne(p_moi text, p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; d record; f public.garage_fabrications; v_pa integer := (p->>'pa')::integer; v_besoin integer;
  v_taux numeric; v_salaire numeric; v_caisse numeric; v_jour integer;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p->>'entreprise' FOR UPDATE;
  IF v_data IS NULL OR v_data->>'type' IS DISTINCT FROM 'garage' THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_introuvable'); END IF;
  SELECT country, current_city, current_building, coalesce(pa, 0) AS pa, coalesce(day, 1) AS jour INTO d
    FROM public.personnages_donnees WHERE name = p_moi FOR UPDATE;
  IF (d.country, d.current_city, d.current_building) IS DISTINCT FROM (v_data->>'country', v_data->>'city', v_data->>'buildingId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO f FROM public.garage_fabrications WHERE entreprise = p->>'entreprise' AND etat <> 'achevee' FOR UPDATE;
  IF f.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_fabrication'); END IF;
  v_besoin := public.vehicule_tranche_interne(f.pa_total, f.jours_faits + 1, f.jours_total) - f.pa_pj;
  IF v_besoin <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'journee_complete'); END IF;
  IF v_pa IS NULL OR v_pa < 1 OR v_pa > v_besoin THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide', 'besoin', v_besoin); END IF;
  IF d.pa < v_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  v_salaire := v_pa * coalesce(v_taux, 0);
  v_caisse := greatest(0, coalesce((v_data->>'caisse')::numeric, 0));
  IF v_caisse < v_salaire THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_salaire), true);
  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire, 'Fabrication ' || f.modele || ' (' || v_pa || ' PA) — ' || p_moi, d.jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p->>'entreprise';
  UPDATE public.personnages_donnees SET pa = pa - v_pa, updated_at = now() WHERE name = p_moi;
  PERFORM public.argent_crediter_interne(p_moi, v_salaire, 'liquide');
  UPDATE public.garage_fabrications SET pa_pj = pa_pj + v_pa,
    journal = journal || jsonb_build_array(jsonb_build_object('le', now(), 'pj', p_moi, 'pa', v_pa, 'salaire', v_salaire))
   WHERE id = f.id;
  RETURN jsonb_build_object('ok', true, 'pa_donnes', v_pa, 'salaire', v_salaire, 'reste_jour', v_besoin - v_pa)
    || public.vehicule_inventaire_reponse_interne(p_moi);
END $$;

-- Une journee de fabrication (passe de minuit). Idempotente par jour de Paris.
CREATE OR REPLACE FUNCTION public.garage_fabrication_avancer_interne(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.garage_fabrications; v_data jsonb; v_sm jsonb; k text; q jsonb; v_part integer; v_besoin jsonb := '{}'::jsonb;
  v_pa integer; v_pnj integer; v_taux numeric; v_cout numeric; v_caisse numeric; jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT * INTO f FROM public.garage_fabrications WHERE id = p_id FOR UPDATE;
  IF f.id IS NULL OR f.etat = 'achevee' THEN RETURN jsonb_build_object('ok', true, 'ignore', true); END IF;
  IF f.dernier_jour = jour THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = f.entreprise FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'garage_introuvable'); END IF;
  v_sm := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  FOR k, q IN SELECT key, value FROM jsonb_each(f.materiaux) LOOP
    v_part := public.vehicule_tranche_interne((q#>>'{}')::numeric, f.jours_faits + 1, f.jours_total);
    v_besoin := v_besoin || jsonb_build_object(k, v_part);
    IF coalesce((v_sm->>k)::numeric, 0) < v_part THEN
      UPDATE public.garage_fabrications SET etat = 'attente_matieres', dernier_jour = jour WHERE id = f.id;
      RETURN jsonb_build_object('ok', false, 'raison', 'attente_matieres', 'matiere', k);
    END IF;
  END LOOP;
  v_pa := public.vehicule_tranche_interne(f.pa_total, f.jours_faits + 1, f.jours_total);
  v_pnj := greatest(0, v_pa - f.pa_pj);
  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  v_cout := v_pnj * coalesce(v_taux, 0);
  v_caisse := greatest(0, coalesce((v_data->>'caisse')::numeric, 0));
  IF v_caisse < v_cout THEN
    UPDATE public.garage_fabrications SET etat = 'attente_caisse', dernier_jour = jour WHERE id = f.id;
    RETURN jsonb_build_object('ok', false, 'raison', 'attente_caisse');
  END IF;
  FOR k, q IN SELECT key, value FROM jsonb_each(v_besoin) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[k], to_jsonb(coalesce((v_sm->>k)::numeric, 0) - (q#>>'{}')::numeric));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm, true);
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_cout), true);
  IF v_cout > 0 THEN
    v_data := public.entreprise_ajouter_historique(v_data, -v_cout, 'Fabrication ' || f.modele || ' : ouvriers PNJ (' || v_pnj || ' PA)', 0);
  END IF;
  IF f.jours_faits + 1 >= f.jours_total THEN
    v_data := jsonb_set(v_data, ARRAY['stockProduits', f.modele],
      to_jsonb(coalesce((v_data->'stockProduits'->>f.modele)::numeric, 0) + 1), true);
  END IF;
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = f.entreprise;
  UPDATE public.garage_fabrications SET jours_faits = jours_faits + 1, pa_pj = greatest(0, pa_pj - v_pa), dernier_jour = jour,
    etat = CASE WHEN jours_faits + 1 >= jours_total THEN 'achevee' ELSE 'en_cours' END,
    acheve_le = CASE WHEN jours_faits + 1 >= jours_total THEN now() END,
    journal = journal || jsonb_build_array(jsonb_build_object('jour', jour, 'pa_pnj', v_pnj, 'cout_pnj', v_cout, 'matieres', v_besoin))
   WHERE id = f.id;
  RETURN jsonb_build_object('ok', true, 'jours', f.jours_faits + 1, 'pa_pnj', v_pnj, 'achevee', f.jours_faits + 1 >= f.jours_total);
END $$;

CREATE OR REPLACE FUNCTION public.garage_fabrications_avancer_jour()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c record; r jsonb; n_ok integer := 0; n_att integer := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  FOR c IN SELECT id FROM public.garage_fabrications WHERE etat <> 'achevee' ORDER BY cree_le, id LOOP
    r := public.garage_fabrication_avancer_interne(c.id);
    IF (r->>'ok')::boolean AND r->>'rejeu' IS NULL AND r->>'ignore' IS NULL THEN n_ok := n_ok + 1;
    ELSIF (r->>'ok')::boolean IS NOT TRUE THEN n_att := n_att + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'avancees', n_ok, 'en_attente', n_att);
END $$;

REVOKE ALL ON FUNCTION public.vehicule_tranche_interne(numeric, integer, integer), public.vehicule_fabriquer_interne(text, jsonb),
  public.vehicule_travailler_interne(text, jsonb), public.garage_fabrication_avancer_interne(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.garage_fabrications_avancer_jour() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.garage_fabrications_avancer_jour() TO service_role;
