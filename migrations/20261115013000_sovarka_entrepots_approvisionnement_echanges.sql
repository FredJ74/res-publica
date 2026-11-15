-- Sovarka : approvisionnement de nuit des entrepôts par le port de Starovka et échanges entre entrepôts
-- (Claude, 15/11/2026, décisions et feu vert de Fred du 15/11, 0 h 52 – 1 h 03 ; GAME-DESIGN-NOVOMIRSK.md,
-- « Approvisionnement et échanges des entrepôts de Sovarka »).
--
-- 1. Approvisionnement « exactement comme la Républia » (règle de livrerEntrepotsQuotidien, api/cron-minuit.js) :
--    chaque entrepôt de Sovarka achète aux fournisseurs, par le port de Starovka, ce qui lui manque pour
--    atteindre ses stocks cibles (desideratas du directeur PJ encore en poste, sinon le plafond de la
--    matière) ; matières de source « livraison », jamais une matière interdite par la loi ; capacité 5 000
--    par matière, marchandise déjà en route comptée ; 800 unités au plus par entrepôt et par nuit ; payé
--    au prix fournisseur sur la caisse de l'entrepôt, réduit à proportion si la caisse ne suffit pas.
-- 2. Échanges entre entrepôts : chaque nuit, chaque paire (Novomirsk–Starovka, Novomirsk–Krasnov,
--    Starovka–Krasnov) échange 250 PSK dans chaque sens au prix de base, répartis à parts égales entre les
--    matières de la ville expéditrice (Novomirsk : métal, tissu ; Starovka : pétrole, viande, poisson,
--    laitages ; Krasnov : bois, poisson, laitages, viande). Si un côté manque de stock, l'autre envoie moins
--    d'autant (valeurs égales). Achat et vente : chaque entrepôt paie ce qu'il reçoit et touche ce qu'il
--    envoie ; tout passe par les caisses et le journal.
-- Une seule passe par jour de Sovarka (sovarka_entrepots_passes) : un rejeu ne fait rien.
-- Aucune donnée de Républia n'est touchée.

CREATE TABLE IF NOT EXISTS public.sovarka_entrepots_passes (
  jour     date PRIMARY KEY,
  resultat jsonb NOT NULL,
  cree_le  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_entrepots_passes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_entrepots_passes FROM PUBLIC, anon, authenticated;

-- Lot d'échange qu'un entrepôt peut envoyer pour une valeur visée : parts égales par matière, borné au stock.
CREATE OR REPLACE FUNCTION public.sovarka_echange_lot_interne(p_entrepot text, p_matieres text[], p_valeur numeric)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_cle text; v_prix numeric; v_q integer; v_lot jsonb := '{}'::jsonb; v_n integer;
BEGIN
  v_n := coalesce(array_length(p_matieres, 1), 0);
  IF v_n = 0 OR coalesce(p_valeur, 0) <= 0 THEN RETURN v_lot; END IF;
  FOREACH v_cle IN ARRAY p_matieres LOOP
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    IF coalesce(v_prix, 0) <= 0 THEN CONTINUE; END IF;
    v_q := least(floor(p_valeur / v_n / v_prix)::integer,
                 coalesce((SELECT coalesce((CASE WHEN jsonb_typeof(b.data) = 'string' THEN (b.data #>> '{}')::jsonb ELSE b.data END)
                                             #>> ARRAY['entrepot','stock',v_cle], '0')::numeric
                             FROM public.batiments_etat b WHERE b.id = p_entrepot), 0)::integer);
    IF v_q > 0 THEN v_lot := v_lot || jsonb_build_object(v_cle, v_q); END IF;
  END LOOP;
  RETURN v_lot;
END $$;

CREATE OR REPLACE FUNCTION public.sovarka_echange_valeur_interne(p_lot jsonb)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(sum((l.value #>> '{}')::numeric * r.prix_base), 0)
    FROM jsonb_each(coalesce(p_lot, '{}'::jsonb)) l JOIN public.ressources_economie r ON r.cle = l.key;
$$;

CREATE OR REPLACE FUNCTION public.sovarka_entrepots_passe(p_jour date, p_interdites text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_ids   constant text[] := ARRAY['soviet_capitale_entrepot-logistique-novomirsk',
                                   'soviet_ville_a_entrepot-logistique-starovka',
                                   'soviet_ville_b_entrepot-logistique-krasnov'];
  c_villes constant text[] := ARRAY['capitale', 'ville_a', 'ville_b'];
  c_noms  constant text[] := ARRAY['Entrepôt de Novomirsk', 'Entrepôt de Starovka', 'Entrepôt de Krasnov'];
  c_capacite constant integer := 5000;
  c_volume   constant integer := 800;
  c_valeur_echange constant numeric := 250;
  v_deja jsonb; v_i integer; v_a integer; v_b integer;
  v_data jsonb; v_ent jsonb; v_des jsonb; v_r record; v_stock integer; v_transit integer;
  v_cible integer; v_besoin integer; v_bes jsonb; v_total integer; v_fv numeric; v_valeur numeric;
  v_solde numeric; v_fb numeric; v_q integer; v_cout numeric; v_unites integer; v_depense numeric;
  v_appro jsonb := '{}'::jsonb; v_echanges jsonb := '[]'::jsonb; v_res jsonb;
  v_mat text[][]; v_ma text[]; v_mb text[]; v_lot_ab jsonb; v_lot_ba jsonb; v_fa numeric; v_fbv numeric;
  v_v numeric; v_va numeric; v_vb numeric; v_cle text; v_qte integer; v_prix numeric;
BEGIN
  IF p_jour IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'jour_absent'); END IF;
  -- Légalité non vérifiable : aucune livraison ni échange ce jour (fail-closed, comme la Républia).
  IF p_interdites IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'legalite_non_verifiable'); END IF;
  SELECT resultat INTO v_deja FROM public.sovarka_entrepots_passes WHERE jour = p_jour;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('sovarka_entrepots_passe'));
  SELECT resultat INTO v_deja FROM public.sovarka_entrepots_passes WHERE jour = p_jour;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;

  -- 1. Approvisionnement par le port de Starovka.
  FOR v_i IN 1..3 LOOP
    SELECT CASE WHEN jsonb_typeof(data) = 'string' THEN (data #>> '{}')::jsonb ELSE data END
      INTO v_data FROM public.batiments_etat WHERE id = c_ids[v_i];
    IF NOT FOUND THEN
      v_appro := v_appro || jsonb_build_object(c_villes[v_i], jsonb_build_object('issue', 'entrepot_absent'));
      CONTINUE;
    END IF;
    v_ent := coalesce(v_data->'entrepot', '{}'::jsonb);
    v_des := NULL;
    IF v_ent ? 'desiderata' AND coalesce(v_ent->>'desiderataPar', '') <> '' AND EXISTS (
         SELECT 1 FROM public.personnages p
          WHERE p.name = v_ent->>'desiderataPar' AND p.country = 'soviet'
            AND p.poste->>'id' = 'directeur_entrepot' AND p.poste->>'city' = c_villes[v_i]) THEN
      v_des := v_ent->'desiderata';
    END IF;

    v_bes := '{}'::jsonb; v_total := 0;
    FOR v_r IN SELECT cle, prix_achat_fournisseur, plafond FROM public.ressources_economie
                WHERE source = 'livraison' AND NOT (cle = ANY (p_interdites)) ORDER BY cle LOOP
      v_cible := least(c_capacite, greatest(0, coalesce((v_des->>v_r.cle)::numeric, v_r.plafond)::integer));
      IF v_cible <= 0 THEN CONTINUE; END IF;
      v_stock := coalesce((v_ent #>> ARRAY['stock', v_r.cle])::numeric, 0)::integer;
      SELECT coalesce(sum(quantite), 0) INTO v_transit FROM public.entrepot_transits
       WHERE destination_id = c_ids[v_i] AND ressource = v_r.cle;
      v_besoin := greatest(0, least(v_cible - v_stock - v_transit, c_capacite - v_stock - v_transit));
      IF v_besoin > 0 THEN
        v_bes := v_bes || jsonb_build_object(v_r.cle, v_besoin);
        v_total := v_total + v_besoin;
      END IF;
    END LOOP;

    v_fv := CASE WHEN v_total > c_volume THEN c_volume::numeric / v_total ELSE 1 END;
    SELECT coalesce(sum(floor((b.value #>> '{}')::numeric * v_fv) * r.prix_achat_fournisseur), 0)
      INTO v_valeur FROM jsonb_each(v_bes) b JOIN public.ressources_economie r ON r.cle = b.key;
    v_solde := coalesce(public.exportation_solde_interne(c_ids[v_i]), 0);
    v_fb := CASE WHEN v_valeur > v_solde AND v_valeur > 0 THEN v_solde / v_valeur ELSE 1 END;

    v_unites := 0; v_depense := 0;
    FOR v_r IN SELECT b.key AS cle, (b.value #>> '{}')::integer AS besoin, r.prix_achat_fournisseur AS prix
                 FROM jsonb_each(v_bes) b JOIN public.ressources_economie r ON r.cle = b.key ORDER BY b.key LOOP
      v_q := floor(floor(v_r.besoin * v_fv) * v_fb)::integer;
      IF v_q <= 0 THEN CONTINUE; END IF;
      v_cout := round(v_q * v_r.prix, 2);
      IF NOT public.exportation_caisse_interne(c_ids[v_i], -v_cout) THEN CONTINUE; END IF;
      PERFORM public.exportation_stock_interne(c_ids[v_i], v_r.cle, v_q);
      INSERT INTO public.entrepot_journal(entrepot_id, jour, operation, sens, contrepartie, ressource, quantite,
                                          prix_unitaire, fret_unitaire, montant, statut)
      VALUES (c_ids[v_i], p_jour, 'approvisionnement_auto', 'entree', 'Fournisseurs (port de Starovka)', v_r.cle, v_q,
              v_r.prix, 0, v_cout, 'livre');
      v_unites := v_unites + v_q; v_depense := v_depense + v_cout;
    END LOOP;
    v_appro := v_appro || jsonb_build_object(c_villes[v_i], jsonb_build_object(
      'issue', CASE WHEN v_unites > 0 THEN 'approvisionne' WHEN v_total > 0 THEN 'sans_tresorerie' ELSE 'rien_a_livrer' END,
      'unites', v_unites, 'cout', v_depense, 'dirige_par_pj', v_des IS NOT NULL));
  END LOOP;

  -- 2. Échanges à valeurs égales entre les trois entrepôts.
  FOR v_a, v_b IN SELECT x, y FROM (VALUES (1, 2), (1, 3), (2, 3)) t(x, y) LOOP
    v_ma := ARRAY(SELECT m FROM unnest(CASE v_a WHEN 1 THEN ARRAY['metal', 'textile']
                                                 WHEN 2 THEN ARRAY['petrole', 'viande', 'poisson', 'laitages']
                                                 ELSE ARRAY['bois', 'poisson', 'laitages', 'viande'] END) m
                   WHERE NOT (m = ANY (p_interdites)));
    v_mb := ARRAY(SELECT m FROM unnest(CASE v_b WHEN 1 THEN ARRAY['metal', 'textile']
                                                 WHEN 2 THEN ARRAY['petrole', 'viande', 'poisson', 'laitages']
                                                 ELSE ARRAY['bois', 'poisson', 'laitages', 'viande'] END) m
                   WHERE NOT (m = ANY (p_interdites)));
    v_lot_ab := public.sovarka_echange_lot_interne(c_ids[v_a], v_ma, c_valeur_echange);
    v_lot_ba := public.sovarka_echange_lot_interne(c_ids[v_b], v_mb, c_valeur_echange);
    v_fa := public.sovarka_echange_valeur_interne(v_lot_ab);
    v_fbv := public.sovarka_echange_valeur_interne(v_lot_ba);
    v_v := least(v_fa, v_fbv);
    IF v_v <= 0 THEN
      v_echanges := v_echanges || jsonb_build_object('de', c_villes[v_a], 'vers', c_villes[v_b], 'issue', 'stock_insuffisant');
      CONTINUE;
    END IF;
    -- Le côté le mieux pourvu réduit son lot à la valeur de l'autre.
    IF v_fa > v_v THEN
      SELECT coalesce(jsonb_object_agg(key, q), '{}'::jsonb) INTO v_lot_ab FROM (
        SELECT key, floor((value #>> '{}')::numeric * v_v / v_fa)::integer AS q FROM jsonb_each(v_lot_ab)) s WHERE q > 0;
    END IF;
    IF v_fbv > v_v THEN
      SELECT coalesce(jsonb_object_agg(key, q), '{}'::jsonb) INTO v_lot_ba FROM (
        SELECT key, floor((value #>> '{}')::numeric * v_v / v_fbv)::integer AS q FROM jsonb_each(v_lot_ba)) s WHERE q > 0;
    END IF;
    v_va := public.sovarka_echange_valeur_interne(v_lot_ab);
    v_vb := public.sovarka_echange_valeur_interne(v_lot_ba);
    IF v_va <= 0 OR v_vb <= 0 THEN
      v_echanges := v_echanges || jsonb_build_object('de', c_villes[v_a], 'vers', c_villes[v_b], 'issue', 'stock_insuffisant');
      CONTINUE;
    END IF;
    -- Paiements : chacun touche d'abord ce qu'il vend, puis paie ce qu'il achète.
    PERFORM public.exportation_caisse_interne(c_ids[v_a], v_va);
    PERFORM public.exportation_caisse_interne(c_ids[v_b], v_vb);
    IF NOT public.exportation_caisse_interne(c_ids[v_b], -v_va) OR NOT public.exportation_caisse_interne(c_ids[v_a], -v_vb) THEN
      RAISE EXCEPTION 'sovarka_echange_caisse_refusee';
    END IF;
    FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::integer FROM jsonb_each(v_lot_ab) LOOP
      SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
      PERFORM public.exportation_stock_interne(c_ids[v_a], v_cle, -v_qte);
      PERFORM public.exportation_stock_interne(c_ids[v_b], v_cle, v_qte);
      INSERT INTO public.entrepot_journal(entrepot_id, jour, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut)
      VALUES (c_ids[v_a], p_jour, 'echange_entrepots', 'sortie', c_noms[v_b], v_cle, v_qte, v_prix, 0, round(v_qte * v_prix, 2), 'livre'),
             (c_ids[v_b], p_jour, 'echange_entrepots', 'entree', c_noms[v_a], v_cle, v_qte, v_prix, 0, round(v_qte * v_prix, 2), 'livre');
    END LOOP;
    FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::integer FROM jsonb_each(v_lot_ba) LOOP
      SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
      PERFORM public.exportation_stock_interne(c_ids[v_b], v_cle, -v_qte);
      PERFORM public.exportation_stock_interne(c_ids[v_a], v_cle, v_qte);
      INSERT INTO public.entrepot_journal(entrepot_id, jour, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut)
      VALUES (c_ids[v_b], p_jour, 'echange_entrepots', 'sortie', c_noms[v_a], v_cle, v_qte, v_prix, 0, round(v_qte * v_prix, 2), 'livre'),
             (c_ids[v_a], p_jour, 'echange_entrepots', 'entree', c_noms[v_b], v_cle, v_qte, v_prix, 0, round(v_qte * v_prix, 2), 'livre');
    END LOOP;
    v_echanges := v_echanges || jsonb_build_object('de', c_villes[v_a], 'vers', c_villes[v_b], 'issue', 'echange',
                                                  'envoi', v_lot_ab, 'valeur_envoi', v_va, 'retour', v_lot_ba, 'valeur_retour', v_vb);
  END LOOP;

  v_res := jsonb_build_object('ok', true, 'approvisionnement', v_appro, 'echanges', v_echanges);
  INSERT INTO public.sovarka_entrepots_passes(jour, resultat) VALUES (p_jour, v_res);
  RETURN v_res;
END $$;

REVOKE ALL ON FUNCTION public.sovarka_echange_lot_interne(text, text[], numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sovarka_echange_valeur_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sovarka_entrepots_passe(date, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_entrepots_passe(date, text[]) TO service_role;

DO $verif$
BEGIN
  IF to_regclass('public.sovarka_entrepots_passes') IS NULL
     OR has_function_privilege('authenticated', 'public.sovarka_entrepots_passe(date, text[])', 'EXECUTE')
     OR has_function_privilege('anon', 'public.sovarka_entrepots_passe(date, text[])', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.sovarka_entrepots_passe(date, text[])', 'EXECUTE')
     OR (SELECT count(*) FROM public.entrepots_par_ville WHERE pays = 'soviet') <> 3 THEN
    RAISE EXCEPTION 'sovarka_entrepots_passe_incomplet';
  END IF;
END $verif$;
