-- RÉGULATION DE LA PRODUCTION ; RÉCOLTE À 1 PA ; PRIX DE SOVARKA À MOITIÉ (Fred, 16/11/2026, nuit).
-- Décisions : GAME-DESIGN-REGULATION-PRODUCTION.md.
--  1. Plus de plafond fixe de récoltes par jour ; une récolte coûte 1 PA et rapporte une quantité fixe :
--     poisson 10 (PSM), charbon 6 et métal 3 (Montrouge), pétrole 4 (Starovka), bois 6 (Krasnov) ;
--     forêt profonde de Krasnov : 1 PA la coupe, 12 bois.
--  2. L'adjoint au maire de chaque ville (tous les empires) règle, par ressource, un maximum de
--     récoltes par joueur et par jour et/ou un plafond total de la ville par jour ; la règle reste en
--     vigueur jusqu'à ce qu'un adjoint la change ou la lève.
--  3. Prix des matières en Sovarka = moitié des prix de Républia (entrepôts, usines, trading,
--     commerces, chantiers, passes de Sovarka). Pas de taux de change : les importations de Sovarka
--     restent payées au prix du pays d'origine.
BEGIN;

-- ---------------------------------------------------------------------------------------------
-- 3. Prix par pays
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.coef_prix_matieres(p_pays text)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_pays = 'soviet' THEN 0.5 ELSE 1 END::numeric;
$$;

CREATE OR REPLACE FUNCTION public.ressources_economie_pays(p_pays text)
RETURNS TABLE(cle text, prix_base numeric, prix_achat_fournisseur numeric, plafond integer, source text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT r.cle, round(r.prix_base * public.coef_prix_matieres(p_pays), 2),
         round(r.prix_achat_fournisseur * public.coef_prix_matieres(p_pays), 2), r.plafond, r.source
    FROM public.ressources_economie r;
$$;
REVOKE ALL ON FUNCTION public.ressources_economie_pays(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ressources_economie_pays(text) TO authenticated;

-- Chaque fonction qui lit un prix dans un pays connu lit désormais le tableau de ce pays.
CREATE OR REPLACE FUNCTION pg_temp.hg_prix_pays(p_sig text, p_expr text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE d text;
BEGIN
  d := pg_get_functiondef(p_sig::regprocedure);
  IF position('ressources_economie_pays(' IN d) > 0 THEN RETURN; END IF;
  IF NOT d ~ 'public\.ressources_economie\M' THEN RAISE EXCEPTION 'prix_pays % : aucune lecture de prix', p_sig; END IF;
  EXECUTE regexp_replace(d, 'public\.ressources_economie\M', 'public.ressources_economie_pays(' || p_expr || ')', 'g');
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.hg_remplacer(p_sig text, p_avant text, p_apres text, p_nb integer DEFAULT 1) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE d text;
BEGIN
  d := pg_get_functiondef(p_sig::regprocedure);
  IF position(p_apres IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> p_nb THEN
    RAISE EXCEPTION 'remplacement % : motif attendu % fois', p_sig, p_nb;
  END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $f$;

SELECT pg_temp.hg_prix_pays('public.acheter_a_entrepot(text,text,text,text,jsonb)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.vendre_matiere_a_usine(text,text,text,text,text,integer)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.vendre_ressource_medicale(text,text,text,text,text,integer)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.fixer_prix_vente_directe(text,text,jsonb)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.fixer_prix_entrepot(text,text,jsonb)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.approvisionner_chantier(text,text,text,text,jsonb,jsonb,numeric)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.chantier_lancer(text,text,text,text,numeric)', 'p_pays');
SELECT pg_temp.hg_prix_pays('public.commerce_apporter_matiere(text,text,text,text,integer,text)', 'v_pays');
SELECT pg_temp.hg_prix_pays('public.commerce_fixer_parametres(text,text,jsonb,jsonb,jsonb)', 'v_pays');
SELECT pg_temp.hg_prix_pays('public.fonds_matieres_accessibles(text)', 'v_pays');
SELECT pg_temp.hg_prix_pays('public.fonds_matieres_recherchees(text)', 'v_pays');
SELECT pg_temp.hg_prix_pays('public.sovarka_entrepots_passe(date,text[])', '''soviet''');
SELECT pg_temp.hg_prix_pays('public.sovarka_echange_lot_interne(text,text[],numeric)', '''soviet''');
SELECT pg_temp.hg_prix_pays('public.sovarka_echange_valeur_interne(jsonb)', '''soviet''');
SELECT pg_temp.hg_prix_pays('public.exportations_sovarka_executer(date,jsonb)', '''soviet''');
SELECT pg_temp.hg_prix_pays('public.trading_acheter(text,text,text,integer,text)', 'v_pays_ent');
SELECT pg_temp.hg_prix_pays('public.trading_cours()', 'ep.pays');
SELECT pg_temp.hg_prix_pays('public.entrepot_commander(text,text,integer,text,text)',
  'CASE WHEN p_fournisseur_type IN (''entrepot'', ''port'') THEN split_part(v_dest_id, ''_'', 1) ELSE p_fournisseur_id END');
SELECT pg_temp.hg_remplacer('public.fournisseurs_etrangers()',
  'CROSS JOIN public.ressources_economie r', 'CROSS JOIN LATERAL public.ressources_economie_pays(p.code) r');
SELECT pg_temp.hg_remplacer('public.acheter_vente_directe_usine(text,text,text,text,jsonb)',
  'public.prix_ressource_selon_stock(v_cle, v_stock)',
  'round(public.prix_ressource_selon_stock(v_cle, v_stock) * public.coef_prix_matieres(p_pays), 2)');

-- ---------------------------------------------------------------------------------------------
-- 1. Récolte : ressources de chaque ville, quantité par PA
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recolte_matieres_ville(p_pays text, p_ville text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays || ':' || coalesce(p_ville, '')
    WHEN 'republic:ville_a' THEN ARRAY['Poisson'] WHEN 'republic:ville_b' THEN ARRAY['Charbon', 'Métal']
    WHEN 'narco:ville_a' THEN ARRAY['Bois', 'Cuir'] WHEN 'narco:ville_b' THEN ARRAY['Bois exotique', 'Caoutchouc']
    WHEN 'soviet:ville_a' THEN ARRAY['Pétrole'] WHEN 'soviet:ville_b' THEN ARRAY['Bois']
    WHEN 'khalija:ville_a' THEN ARRAY['Épices', 'Coton'] WHEN 'khalija:ville_b' THEN ARRAY['Pétrole', 'Poisson']
    ELSE ARRAY[]::text[] END;
$$;

-- Quantités fixes validées par Fred (16/11/2026) ; les empires non ouverts gardent 1 ou 2 au hasard.
CREATE OR REPLACE FUNCTION public.recolte_quantite_par_pa(p_pays text, p_ville text, p_matiere text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays || ':' || coalesce(p_ville, '') || ':' || coalesce(p_matiere, '')
    WHEN 'republic:ville_a:Poisson' THEN 10
    WHEN 'republic:ville_b:Charbon' THEN 6
    WHEN 'republic:ville_b:Métal' THEN 3
    WHEN 'soviet:ville_a:Pétrole' THEN 4
    WHEN 'soviet:ville_b:Bois' THEN 6
    ELSE NULL END;
$$;

-- ---------------------------------------------------------------------------------------------
-- 2. Régulation de la production
-- ---------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.production_regulations (
  pays text NOT NULL, ville text NOT NULL, matiere text NOT NULL,
  max_par_joueur integer CHECK (max_par_joueur IS NULL OR max_par_joueur BETWEEN 0 AND 10000),
  plafond_ville integer CHECK (plafond_ville IS NULL OR plafond_ville BETWEEN 0 AND 100000),
  fixe_par text, fixe_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, ville, matiere));
CREATE TABLE IF NOT EXISTS public.production_recoltes_jour (
  jour date NOT NULL, pays text NOT NULL, ville text NOT NULL, matiere text NOT NULL, nom text NOT NULL,
  nb integer NOT NULL DEFAULT 0, PRIMARY KEY (jour, pays, ville, matiere, nom));
ALTER TABLE public.production_regulations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_recoltes_jour ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.production_regulations, public.production_recoltes_jour FROM anon, authenticated;

-- Refus (jsonb) si une règle de la ville l'interdit aujourd'hui, NULL sinon. Verrouille la règle :
-- deux récoltes simultanées ne dépassent pas le plafond de la ville.
CREATE OR REPLACE FUNCTION public.regulation_production_refus_interne(p_nom text, p_pays text, p_ville text, p_matiere text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_moi integer; v_ville integer;
BEGIN
  SELECT * INTO g FROM public.production_regulations
   WHERE pays = p_pays AND ville = p_ville AND matiere = p_matiere FOR UPDATE;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT coalesce(sum(nb) FILTER (WHERE nom = p_nom), 0), coalesce(sum(nb), 0) INTO v_moi, v_ville
    FROM public.production_recoltes_jour
   WHERE jour = v_jour AND pays = p_pays AND ville = p_ville AND matiere = p_matiere;
  IF g.max_par_joueur IS NOT NULL AND v_moi >= g.max_par_joueur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'regulation_joueur', 'limite', g.max_par_joueur, 'matiere', p_matiere);
  END IF;
  IF g.plafond_ville IS NOT NULL AND v_ville >= g.plafond_ville THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'regulation_ville', 'limite', g.plafond_ville, 'matiere', p_matiere);
  END IF;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.regulation_production_compter_interne(p_nom text, p_pays text, p_ville text, p_matiere text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.production_recoltes_jour (jour, pays, ville, matiere, nom, nb)
  VALUES ((now() AT TIME ZONE 'Europe/Paris')::date, p_pays, p_ville, p_matiere, p_nom, 1)
  ON CONFLICT (jour, pays, ville, matiere, nom) DO UPDATE SET nb = public.production_recoltes_jour.nb + 1;
$$;
REVOKE ALL ON FUNCTION public.regulation_production_refus_interne(text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.regulation_production_compter_interne(text,text,text,text) FROM PUBLIC, anon, authenticated;

-- L'adjoint au maire attesté d'une ville (pays, ville du poste), NULL s'il ne l'est pas.
CREATE OR REPLACE FUNCTION public.regulation_production_adjoint_interne(p_nom text)
RETURNS TABLE(pays text, ville text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT d.country, d.poste->>'city' FROM public.personnages_donnees d
   WHERE d.name = p_nom AND d.poste->>'id' = 'maire_adjoint' AND d.poste->>'city' IS NOT NULL
     AND public.poste_est_atteste(d.name, d.poste, d.country);
$$;
REVOKE ALL ON FUNCTION public.regulation_production_adjoint_interne(text) FROM PUBLIC, anon, authenticated;

-- Lecture : les ressources de la ville (celle du poste pour l'adjoint, sinon la ville où l'on est),
-- leur rendement par PA, les règles en vigueur et l'usage du jour.
CREATE OR REPLACE FUNCTION public.regulation_production_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); m record; a record; v_pays text; v_ville text;
        v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi;
  SELECT * INTO a FROM public.regulation_production_adjoint_interne(v_moi);
  v_pays := coalesce(a.pays, m.country); v_ville := coalesce(a.ville, m.current_city);
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'ville', v_ville, 'est_adjoint', a.pays IS NOT NULL,
    'matieres', coalesce((SELECT jsonb_agg(jsonb_build_object(
        'matiere', x.mat, 'par_pa', public.recolte_quantite_par_pa(v_pays, v_ville, x.mat),
        'max_par_joueur', g.max_par_joueur, 'plafond_ville', g.plafond_ville,
        'fixe_par', g.fixe_par, 'fixe_le', g.fixe_le,
        'recoltes_ville_jour', (SELECT coalesce(sum(j.nb), 0) FROM public.production_recoltes_jour j
                                 WHERE j.jour = v_jour AND j.pays = v_pays AND j.ville = v_ville AND j.matiere = x.mat),
        'mes_recoltes_jour', (SELECT coalesce(sum(j.nb), 0) FROM public.production_recoltes_jour j
                                 WHERE j.jour = v_jour AND j.pays = v_pays AND j.ville = v_ville AND j.matiere = x.mat AND j.nom = v_moi))
        ORDER BY x.ord)
      FROM unnest(public.recolte_matieres_ville(v_pays, v_ville)) WITH ORDINALITY AS x(mat, ord)
      LEFT JOIN public.production_regulations g ON g.pays = v_pays AND g.ville = v_ville AND g.matiere = x.mat), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.regulation_production_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.regulation_production_lire() TO authenticated;

-- Ordre « Régulation de la production » : adjoint au maire, dans la mairie de sa ville, 1 PA.
-- Deux valeurs vides lèvent la régulation de la ressource ; 0 interdit toute récolte.
CREATE OR REPLACE FUNCTION public.regulation_production_fixer(p_matiere text, p_max_joueur integer, p_plafond_ville integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); m record; a record; v_paie jsonb;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO a FROM public.regulation_production_adjoint_interne(v_moi);
  IF a.pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu'); END IF;
  IF m.country IS DISTINCT FROM a.pays OR m.current_city IS DISTINCT FROM a.ville
     OR coalesce(m.current_building, '') NOT IN ('mairie', 'mairie-capitale') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF p_matiere IS NULL OR NOT (p_matiere = ANY (public.recolte_matieres_ville(a.pays, a.ville))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_produite');
  END IF;
  IF (p_max_joueur IS NOT NULL AND (p_max_joueur < 0 OR p_max_joueur > 10000))
     OR (p_plafond_ville IS NOT NULL AND (p_plafond_ville < 0 OR p_plafond_ville > 100000)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide');
  END IF;
  v_paie := public.payer_ordre(v_moi, 'regulation_production', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  IF p_max_joueur IS NULL AND p_plafond_ville IS NULL THEN
    DELETE FROM public.production_regulations WHERE pays = a.pays AND ville = a.ville AND matiere = p_matiere;
  ELSE
    INSERT INTO public.production_regulations (pays, ville, matiere, max_par_joueur, plafond_ville, fixe_par, fixe_le)
    VALUES (a.pays, a.ville, p_matiere, p_max_joueur, p_plafond_ville, v_moi, now())
    ON CONFLICT (pays, ville, matiere) DO UPDATE
      SET max_par_joueur = EXCLUDED.max_par_joueur, plafond_ville = EXCLUDED.plafond_ville,
          fixe_par = EXCLUDED.fixe_par, fixe_le = EXCLUDED.fixe_le;
  END IF;
  RETURN jsonb_build_object('ok', true, 'matiere', p_matiere, 'max_par_joueur', p_max_joueur,
    'plafond_ville', p_plafond_ville, 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
END $$;
REVOKE ALL ON FUNCTION public.regulation_production_fixer(text,integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.regulation_production_fixer(text,integer,integer) TO authenticated;

-- Coûts déclarés : récolte et coupe à 1 PA, régulation à 1 PA.
UPDATE public.ordres_couts SET pa = 1 WHERE fn IN ('recolter_matiere', 'foret_couper') AND pa = 2 AND cost = 0;
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'regulation_production', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'regulation_production');

-- ---------------------------------------------------------------------------------------------
-- 1 et 2. Récolte : 1 PA, quantité fixe, régulation de la ville (plus de limite de 2 par jour)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recolte_effectuer(p_matiere text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_nb integer; v_paie jsonb;
  v_q integer; v_cle text; v_dep jsonb; k integer; v_refus jsonb;
BEGIN
  -- regulation_production_v1 (16/11/2026) : 1 PA, quantité fixe, règles de l'adjoint au maire.
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT (p_matiere = ANY (public.recolte_matieres_ville(m.country, m.current_city))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_recolter_ici'); END IF;
  v_refus := public.regulation_production_refus_interne(v_moi, m.country, m.current_city, p_matiere);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  v_q := coalesce(public.recolte_quantite_par_pa(m.country, m.current_city, p_matiere), floor(random() * 2)::integer + 1);
  v_cle := CASE p_matiere WHEN 'Métal' THEN 'metal' WHEN 'Poisson' THEN 'poisson' WHEN 'Charbon' THEN 'charbon' WHEN 'Bois' THEN 'bois' WHEN 'Pétrole' THEN 'petrole' END;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < v_q THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'quantite', v_q); END IF;
  v_paie := public.payer_ordre(v_moi, 'recolter_matiere', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  PERFORM public.regulation_production_compter_interne(v_moi, m.country, m.current_city, p_matiere);
  INSERT INTO public.recoltes_journalieres (nom, jour, nb) VALUES (v_moi, v_jour, 1)
  ON CONFLICT (nom, jour) DO UPDATE SET nb = public.recoltes_journalieres.nb + 1
  RETURNING nb INTO v_nb;
  IF v_cle IS NOT NULL THEN
    v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('name', p_matiere,
      'icon', CASE v_cle WHEN 'metal' THEN 'ti-bolt' WHEN 'poisson' THEN 'ti-fish' WHEN 'charbon' THEN 'ti-flame' WHEN 'petrole' THEN 'ti-droplet' ELSE 'ti-trees' END,
      'stackable', true, 'stackKey', v_cle, 'qty', v_q, 'desc', 'Récolté localement.'));
  ELSE
    FOR k IN 1..v_q LOOP
      v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('type', 'matiere_premiere', 'matiere', p_matiere,
        'name', p_matiere, 'icon', 'ti-package'));
    END LOOP;
  END IF;
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'recolte_effectuer: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', v_q, 'recoltes_jour', v_nb, 'pa', v_paie -> 'pa')
    || (v_dep - 'ok' - 'qte');
END; $function$;

-- Forêt profonde de Krasnov : 1 PA la coupe, 12 bois (6 par PA, doublé), régulation du bois de Krasnov.
SELECT pg_temp.hg_remplacer('public.sovarka_foret_couper(uuid)', 'v_bonus integer; v_alerte text;',
  'v_bonus integer; v_alerte text; v_reg jsonb;');
SELECT pg_temp.hg_remplacer('public.sovarka_foret_couper(uuid)',
  '  v_paie := public.payer_ordre(a, ''foret_couper'', 2, 0);',
  '  v_reg := public.regulation_production_refus_interne(a, ''soviet'', ''ville_b'', ''Bois'');
  IF v_reg IS NOT NULL THEN RETURN v_reg; END IF;
  v_paie := public.payer_ordre(a, ''foret_couper'', 1, 0);
  IF coalesce((v_paie->>''ok'')::boolean, false) IS TRUE THEN
    PERFORM public.regulation_production_compter_interne(a, ''soviet'', ''ville_b'', ''Bois'');
  END IF;');
SELECT pg_temp.hg_remplacer('public.sovarka_foret_couper(uuid)',
  'v_q := (floor(random() * 2)::integer + 1) * 2;', 'v_q := 12; /* regulation_production_v1 */', 2);
SELECT pg_temp.hg_remplacer('public.sovarka_foret_couper(uuid)',
  'FROM public.personnages_donnees WHERE name = a) < 4 THEN', 'FROM public.personnages_donnees WHERE name = a) < 12 THEN');

-- Contrôles
DO $c$
BEGIN
  IF public.coef_prix_matieres('soviet') <> 0.5 OR public.coef_prix_matieres('republic') <> 1 THEN RAISE EXCEPTION 'coef'; END IF;
  IF (SELECT prix_base FROM public.ressources_economie_pays('soviet') WHERE cle = 'petrole')
     <> round((SELECT prix_base FROM public.ressources_economie WHERE cle = 'petrole') / 2, 2) THEN RAISE EXCEPTION 'prix_soviet'; END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('acheter_a_entrepot','vendre_matiere_a_usine','trading_cours','trading_acheter','entrepot_commander','sovarka_entrepots_passe')
     AND pg_get_functiondef(p.oid) ~ 'public\.ressources_economie\M') THEN RAISE EXCEPTION 'prix_non_raccordes'; END IF;
  IF (SELECT pa FROM public.ordres_couts WHERE fn = 'recolter_matiere') <> 1 THEN RAISE EXCEPTION 'cout_recolte'; END IF;
  IF position('v_q := 12;' IN pg_get_functiondef('public.sovarka_foret_couper(uuid)'::regprocedure)) = 0 THEN RAISE EXCEPTION 'foret'; END IF;
END $c$;
COMMIT;
