-- MALADIES, PÉREMPTION ET CLIMAT — LOT 2b : contrôle à la réception et bandelettes réactives (GAME-DESIGN-MALADIES-CLIMAT.md § 3).
-- • Quand un PJ vend ou donne des aliments à un commerce (moteur historique et fonds de commerce PJ), chaque unité avariée est
--   détectée à 70 % ; détectée = refusée, détruite, non payée. Les unités non détectées entrent dans le stock sans marque et
--   sont comptées à part (`matieresAvariees`) pour les plats cuisinés (lot 2c).
-- • Bandelettes réactives : vendues dans les pharmacies (points de vente du lot 1) ; déposées dans un commerce par n'importe qui
--   de présent (c'est un don) ; chaque livraison d'aliments reçue en consomme une et fait passer la détection à 95 %.
-- • Si le vendeur avait reçu le message d'avarie de ces aliments, la tentative est un acte illégal (fraude alimentaire) tracé.
-- • Le registre des apports garde la quantité livrée (refusés compris) ; le montant payé ne compte que les unités reçues.
-- • Taux et prix réglables par le MJ (`aliments_parametres`). Aucun fichier du goulag.
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES
  ('detection_base', 70), ('detection_bandelette', 95), ('prix_bandelette', 4)
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.aliments_param_interne(p_cle text, p_defaut numeric)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT valeur FROM public.aliments_parametres WHERE cle = p_cle), p_defaut);
$$;

-- Contrôle d'une livraison de p_qte unités de p_mat prises dans p_inv (les plus anciennes d'abord, comme le retrait).
-- Rend { data (commerce mis à jour : bandelette, avariés cachés), refuses, caches, bandelette, fraude }.
CREATE OR REPLACE FUNCTION public.aliments_reception_interne(p_acteur text, p_data jsonb, p_inv jsonb, p_mat text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb := coalesce(p_data, '{}'::jsonb); v_reste integer := greatest(coalesce(p_qte, 0), 0); r record;
        v_pris integer; v_av integer := 0; v_dates date[] := '{}'; v_taux numeric; v_band boolean := false; v_ref integer := 0;
        k integer; v_fraude boolean := false; v_p public.personnages_donnees%rowtype;
BEGIN
  IF NOT public.aliment_perissable_interne(p_mat) OR v_reste = 0 THEN
    RETURN jsonb_build_object('data', v_data, 'refuses', 0, 'caches', 0, 'bandelette', false, 'fraude', false); END IF;
  FOR r IN SELECT e FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY x(e, o)
            WHERE e->>'stackKey' = p_mat ORDER BY public.aliment_recu_interne(e) NULLS FIRST, o LOOP
    EXIT WHEN v_reste <= 0;
    v_pris := least(v_reste, floor(coalesce((r.e->>'qty')::numeric, 1))::integer);
    IF public.aliment_pile_avariee_interne(r.e) THEN
      v_av := v_av + v_pris;
      IF public.aliment_recu_interne(r.e) IS NOT NULL THEN v_dates := v_dates || public.aliment_recu_interne(r.e); END IF;
    END IF;
    v_reste := v_reste - v_pris;
  END LOOP;
  -- Chaque livraison d'aliments reçue consomme une bandelette s'il en reste.
  IF coalesce((v_data->>'bandelettes')::integer, 0) > 0 THEN
    v_band := true;
    v_data := jsonb_set(v_data, '{bandelettes}', to_jsonb((v_data->>'bandelettes')::integer - 1), true);
  END IF;
  v_taux := CASE WHEN v_band THEN public.aliments_param_interne('detection_bandelette', 95) ELSE public.aliments_param_interne('detection_base', 70) END;
  FOR k IN 1 .. v_av LOOP
    IF random() * 100 < v_taux THEN v_ref := v_ref + 1; END IF;
  END LOOP;
  IF v_av - v_ref > 0 THEN
    v_data := jsonb_set(v_data, '{matieresAvariees}', coalesce(v_data->'matieresAvariees', '{}'::jsonb)
      || jsonb_build_object(p_mat, coalesce((v_data->'matieresAvariees'->>p_mat)::integer, 0) + v_av - v_ref), true);
  END IF;
  -- Fraude alimentaire : le vendeur savait (message d'avarie reçu pour ces piles).
  IF v_av > 0 AND EXISTS (SELECT 1 FROM public.aliments_avaries_annonces WHERE nom = p_acteur AND cle = p_mat AND vu AND recu = ANY (v_dates)) THEN
    v_fraude := true;
    SELECT * INTO v_p FROM public.personnages_donnees WHERE name = p_acteur;
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
    VALUES ('fraude-' || v_p.id::text || '-' || md5(random()::text || clock_timestamp()::text), p_acteur, NULL, 'fraude_alimentaire',
            coalesce(v_p.country, 'republic'), v_p.current_city, public.jour_de_jeu_pays(coalesce(v_p.country, 'republic')),
            public.jour_de_jeu_pays(coalesce(v_p.country, 'republic')) + 7);
  END IF;
  RETURN jsonb_build_object('data', v_data, 'refuses', v_ref, 'caches', v_av - v_ref, 'bandelette', v_band, 'fraude', v_fraude);
END $$;
REVOKE ALL ON FUNCTION public.aliments_reception_interne(text, jsonb, jsonb, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.aliments_param_interne(text, numeric) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Moteur historique : commerce_apporter_matiere ────────────────────────────────────────────────
DO $$
DECLARE f regprocedure := 'public.commerce_apporter_matiere(text,text,text,text,integer,text)'::regprocedure; d text; n integer;
  paires text[][] := ARRAY[
    ARRAY['v_accepte boolean; v_place numeric; v_refus jsonb;', 'v_accepte boolean; v_place numeric; v_refus jsonb; v_ctl jsonb; v_recus integer; /* aliments_reception_v1 */'],
    ARRAY['  v_total := round(v_prix * p_qte, 2);',
          '  -- Contrôle à la réception (lot 2b), après les refus de stock et de prix : les unités avariées détectées
  -- sont refusées, détruites, non payées.
  v_ctl := public.aliments_reception_interne(p_acteur, v_data, v_inv, v_mat, p_qte);
  v_data := v_ctl->''data'';
  v_recus := p_qte - (v_ctl->>''refuses'')::integer;
  v_total := round(v_prix * v_recus, 2);'],
    ARRAY['  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0', '  v_cout_moyen := CASE WHEN v_stock + v_recus = 0 THEN 0'],
    ARRAY['(v_prix * p_qte))
               / (v_stock + p_qte), 4) END;', '(v_prix * v_recus))
               / (v_stock + v_recus), 4) END;'],
    ARRAY['jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + p_qte)),', 'jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_recus)),'],
    ARRAY['  RETURN jsonb_build_object(''ok'', true, ''mode'', v_mode, ''matiere'', v_mat,', '  RETURN jsonb_build_object(''ok'', true, ''mode'', v_mode, ''matiere'', v_mat, ''refuses'', p_qte - v_recus, ''bandelette'', v_ctl->''bandelette'','],
    ARRAY['    ''stock'', v_stock + p_qte,', '    ''stock'', v_stock + v_recus,']
  ];
  i integer;
BEGIN
  d := pg_get_functiondef(f);
  IF position('aliments_reception_v1' IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(paires, 1) LOOP
    n := (length(d) - length(replace(d, paires[i][1], ''))) / length(paires[i][1]);
    IF n <> 1 THEN RAISE EXCEPTION 'commerce_apporter_matiere : ancrage % (% trouvé(s))', i, n; END IF;
    d := replace(d, paires[i][1], paires[i][2]);
  END LOOP;
  EXECUTE d;
END $$;

-- ── Fonds de commerce PJ : fonds_matiere_apporter ────────────────────────────────────────────────
DO $$
DECLARE f regprocedure := 'public.fonds_matiere_apporter(text,text,text,text,integer,text)'::regprocedure; d text; n integer;
  paires text[][] := ARRAY[
    ARRAY['v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb; v_reste integer; v_refus jsonb;', 'v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb; v_reste integer; v_refus jsonb; v_ctl jsonb; v_recus integer; /* aliments_reception_v1 */'],
    ARRAY['  v_montant := round(v_prix * v_qte, 2);',
          '  -- Contrôle à la réception (lot 2b).
  v_ctl := public.aliments_reception_interne(p_acteur, v_data, v_inv, v_mat, v_qte);
  v_data := v_ctl->''data'';
  v_recus := v_qte - (v_ctl->>''refuses'')::integer;
  v_montant := round(v_prix * v_recus, 2);'],
    ARRAY['(v_prix * v_qte)) / (v_stock + v_qte), 4);', '(v_prix * v_recus)) / greatest(v_stock + v_recus, 1), 4);'],
    ARRAY['jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_qte)),', 'jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_recus)),'],
    ARRAY['    ''quantite'', v_qte, ''demandee'', v_veut,', '    ''quantite'', v_recus, ''refuses'', v_qte - v_recus, ''bandelette'', v_ctl->''bandelette'', ''demandee'', v_veut,'],
    ARRAY['    ''stock'', v_stock + v_qte, ''maximum''', '    ''stock'', v_stock + v_recus, ''maximum''']
  ];
  i integer;
BEGIN
  d := pg_get_functiondef(f);
  IF position('aliments_reception_v1' IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(paires, 1) LOOP
    n := (length(d) - length(replace(d, paires[i][1], ''))) / length(paires[i][1]);
    IF n <> 1 THEN RAISE EXCEPTION 'fonds_matiere_apporter : ancrage % (% trouvé(s))', i, n; END IF;
    d := replace(d, paires[i][1], paires[i][2]);
  END LOOP;
  EXECUTE d;
END $$;

-- ── Bandelettes : achat en pharmacie, dépôt dans un commerce ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pharmacie_bandelettes_acheter(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('qte', p_qte); v jsonb; pv public.pharmacies_points_vente;
        v_prix numeric; v_total numeric; v_fonds numeric; v_debit numeric; v_dep jsonb; v_rep jsonb; v_flag text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'pharmacie_bandelettes_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_qte IS NULL OR p_qte < 1 OR p_qte > 20 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  pv := public.pharmacie_point_interne(a);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  v_prix := public.aliments_param_interne('prix_bandelette', 4);
  v_total := v_prix * p_qte;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b WHERE b.personnage = d.name AND b.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = a;
  IF v_fonds < v_total THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(a, 'pharmacie_medicaments', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(a, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'bandelettes: debit incomplet'; END IF;
  IF pv.caisse_entreprise IS NOT NULL THEN
    UPDATE public.entreprises SET data = jsonb_set(data, '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_total)), updated_at = now()
     WHERE id = pv.caisse_entreprise;
  ELSIF pv.caisse_institution IS NOT NULL THEN
    v_flag := current_setting('rp.caisse_interne', true);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(pv.caisse_institution, v_total, true);
    PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
    IF (v_rep->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'bandelettes: caisse refusee %', v_rep; END IF;
  END IF;
  v_dep := public.inventaire_deposer_interne(a, jsonb_build_object('name', 'Bandelettes réactives', 'icon', 'ti-test-pipe',
    'type', 'bandelette_reactive', 'stackable', true, 'stackKey', 'bandelette_reactive', 'qty', p_qte, 'legal', true));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'bandelettes: depot refuse %', v_dep; END IF;
  v := jsonb_build_object('ok', true, 'quantite', p_qte, 'prix', v_prix, 'paye', v_total)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'pharmacie_bandelettes_acheter', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.pharmacie_bandelettes_acheter(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pharmacie_bandelettes_acheter(uuid, integer) TO authenticated;

-- Le commerce de la pièce où se trouve le personnage (moteur historique ou fonds PJ), pièce exacte d'abord.
CREATE OR REPLACE FUNCTION public.commerce_de_la_piece_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT e.id FROM public.entreprises e JOIN public.personnages_donnees d ON d.name = p_nom
   WHERE (e.data->>'country' = d.country AND e.data->>'city' = d.current_city AND e.data->>'buildingId' = d.current_building
          AND (e.data->>'roomId' IS NULL OR e.data->>'roomId' = d.current_room))
      OR (e.data->'implantation'->>'country' = d.country AND e.data->'implantation'->>'city' = d.current_city
          AND e.data->'implantation'->>'buildingId' = d.current_building AND e.data->'implantation'->>'roomId' = d.current_room)
   ORDER BY (coalesce(e.data->>'roomId', e.data->'implantation'->>'roomId') = d.current_room) DESC NULLS LAST, e.id LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.commerce_de_la_piece_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.commerce_bandelettes_deposer(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('qte', p_qte); v jsonb; v_ent text; v_inv jsonb; v_n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'commerce_bandelettes_deposer', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_qte IS NULL OR p_qte < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v_ent := public.commerce_de_la_piece_interne(a);
  IF v_ent IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_commerce'); END IF;
  PERFORM 1 FROM public.entreprises WHERE id = v_ent FOR UPDATE;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF public.inventaire_quantite(v_inv, 'bandelette_reactive') < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_bandelettes'); END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(v_inv, 'bandelette_reactive', p_qte), updated_at = now() WHERE name = a;
  UPDATE public.entreprises SET data = jsonb_set(data, '{bandelettes}', to_jsonb(coalesce((data->>'bandelettes')::integer, 0) + p_qte), true), updated_at = now()
   WHERE id = v_ent RETURNING (data->>'bandelettes')::integer INTO v_n;
  v := jsonb_build_object('ok', true, 'quantite', p_qte, 'reserve', v_n)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'commerce_bandelettes_deposer', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.commerce_bandelettes_deposer(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commerce_bandelettes_deposer(uuid, integer) TO authenticated;

-- La fenêtre de pharmacie montre aussi les bandelettes et leur prix.
SELECT pg_temp.rp_raccorder('public.pharmacie_etat()'::regprocedure,
  $a$  RETURN jsonb_build_object('ok', true, 'point', pv.id, 'medicaments', ($a$,
  $b$  RETURN jsonb_build_object('ok', true, 'point', pv.id, 'prix_bandelette', public.aliments_param_interne('prix_bandelette', 4), /* aliments_bandelettes_v1 */ 'medicaments', ($b$,
  'aliments_bandelettes_v1');

-- ── Contrôle structurel ──────────────────────────────────────────────────────────────────────────
DO $$
DECLARE r jsonb;
BEGIN
  r := public.aliments_reception_interne('__essai__', '{"bandelettes":1}', '[{"stackKey":"bois","qty":3}]', 'bois', 2);
  IF (r->>'refuses')::int <> 0 OR (r->'data'->>'bandelettes')::int <> 1 THEN RAISE EXCEPTION 'controle structurel en echec (non perissable)'; END IF;
  r := public.aliments_reception_interne('__essai__', '{"bandelettes":1}', '[{"stackKey":"viande","qty":3,"recu":"2026-01-01"}]', 'viande', 3);
  IF (r->>'refuses')::int + (r->>'caches')::int <> 3 OR (r->'data'->>'bandelettes')::int <> 0 OR (r->>'bandelette')::boolean IS NOT TRUE
  THEN RAISE EXCEPTION 'controle structurel en echec (avarie)'; END IF;
  IF position('aliments_reception_v1' IN pg_get_functiondef('public.commerce_apporter_matiere(text,text,text,text,integer,text)'::regprocedure)) = 0
     OR position('aliments_reception_v1' IN pg_get_functiondef('public.fonds_matiere_apporter(text,text,text,text,integer,text)'::regprocedure)) = 0
     OR position('aliments_bandelettes_v1' IN pg_get_functiondef('public.pharmacie_etat()'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'controle structurel en echec (raccords)'; END IF;
END $$;

COMMIT;
