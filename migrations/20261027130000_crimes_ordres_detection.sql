-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027183729.
-- Eprouvee au role authenticated : faux cout refuse, corruptions (PA puis prix a la reussite), douane, contrebande et faux document en inventaire.
-- ============================================================================
-- DETECTION DES ORDRES ILLEGAUX ET CORRUPTIONS : PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », famille « Crime », troisieme lot. La detection d'un acte illegal
-- (checkDetection) etait tiree par l'ecran du joueur APRES coup : un tricheur ne l'appelait
-- simplement pas. Elle est desormais tiree dans la fonction serveur de l'acte :
--   1. ordre_generique_executer : tout ordre generique inscrit a actes_illegaux, reussi (partiel,
--      reussite, critique), passe la detection (regles de checkDetection).
--   2. crime_corrompre (corrompre_fonct / _police / _gardien) : PA a la tentative, prix a la seule
--      reussite (comme l'ecran) ; taux 65 - malus de securite ; reussite : -5 discretion, trace.
--   3. crime_corrompre_douanier : PA et prix a la tentative ; taux 55 + DUP/10 + INF/10 + 20.
--   4. crime_contrebande : PA a la tentative ; taux 55 + DIS/10 + DUP/10 + 15 + empire (narco
--      +25, soviet -20, khalija +10) - malus ; reussite : cargaison en inventaire, -5 discretion.
--   5. crime_falsifier : PA a la tentative, prix a la reussite ; taux 45 - malus ; reussite :
--      document falsifie en inventaire (quatre documents connus, jamais un texte libre).
-- Chaque reponse rend l'avis de recherche, que l'ecran recopie.
-- Restent a l'ecran : le passage en douane debloque (state.douanePassee), le blocus portuaire
-- (son echec seul etait « detecte », sans effet), tracts calomnieux et fausse rumeur (chantier
-- des rumeurs).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

-- Paiement en deux temps : la tentative (PA) puis la reussite (prix), declares separement.
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT DISTINCT fn || '#tentative', pa, 0 FROM public.ordres_couts
 WHERE fn IN ('corrompre_fonct', 'corrompre_police', 'corrompre_gardien', 'falsifier_document')
ON CONFLICT DO NOTHING;
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT DISTINCT fn || '#reussite', 0, cost FROM public.ordres_couts
 WHERE fn IN ('corrompre_fonct', 'corrompre_police', 'corrompre_gardien', 'falsifier_document')
ON CONFLICT DO NOTHING;

-- 1. Ordres generiques.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.ordre_generique_executer(text,integer,integer)'::regprocedure);
  IF position('v_repere' IN v_def) = 0 THEN
    v_def := replace(v_def, 'v_rembourse numeric := 0;', 'v_rembourse numeric := 0; v_repere boolean := false;');
    v_def := replace(v_def, E'  RETURN jsonb_build_object(''ok'', true, ''resultat'', v_res,',
      E'  -- DETECTION PAR LE SERVEUR (27/10/2026) : l''ecran la tirait apres coup, un tricheur s''en dispensait.\n'
      || E'  IF v_res IN (''partial'', ''success'', ''crit'') AND EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = p_fn) THEN\n'
      || E'    v_repere := public.crime_detecter_interne(v_moi, p_fn, true);\n'
      || E'    SELECT CASE WHEN jsonb_typeof(resources) = ''object'' THEN resources ELSE ''{}''::jsonb END INTO v_res_j\n'
      || E'      FROM public.personnages_donnees WHERE name = v_moi;\n'
      || E'  END IF;\n'
      || E'  RETURN jsonb_build_object(''ok'', true, ''resultat'', v_res, ''repere'', v_repere,\n'
      || E'    ''recherche'', (SELECT recherche FROM public.personnages_donnees WHERE name = v_moi),');
    IF position('v_repere := public.crime_detecter_interne' IN v_def) = 0 THEN RAISE EXCEPTION 'ordre_generique_executer : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;

-- Commun : retour des jauges et de l'avis de recherche.
CREATE OR REPLACE FUNCTION public.crime_etat_acteur_interne(p_nom text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT jsonb_build_object('pa', pa, 'arg', arg, 'liquide', liquide, 'dis', resources -> 'dis',
              'recherche', recherche, 'inventaire', inventory)
        FROM public.personnages_donnees WHERE name = p_nom $$;

CREATE OR REPLACE FUNCTION public.crime_dis_ajuster_interne(p_nom text, p_delta integer)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}',
               to_jsonb(least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'dis') = 'number'
                                                              THEN (resources ->> 'dis')::numeric END, 50) + p_delta))))
       WHERE name = p_nom $$;

-- 2. Corruption generique.
CREATE OR REPLACE FUNCTION public.crime_corrompre(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fn NOT IN ('corrompre_fonct', 'corrompre_police', 'corrompre_gardien')
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = p_fn AND pa = p_pa AND cost = p_cost) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  SELECT d.country, d.current_city, coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale'), 0) AS fonds
    INTO m FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF m.fonds < p_cost THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  v_paie := public.payer_ordre(v_moi, p_fn || '#tentative', p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, 65 - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
  END IF;
  v_paie := public.payer_ordre(v_moi, p_fn || '#reussite', 0, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'raison', 'fonds_insuffisants') || public.crime_etat_acteur_interne(v_moi);
  END IF;
  PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'corruption', NULL);
  v_repere := public.crime_detecter_interne(v_moi, p_fn, true);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- 3. Douanier.
CREATE OR REPLACE FUNCTION public.crime_corrompre_douanier(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_paie := public.payer_ordre(v_moi, 'corrompre_douanier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT stats, resources INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, 55 + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer
            + floor(coalesce(CASE WHEN jsonb_typeof(m.resources -> 'inf') = 'number' THEN (m.resources ->> 'inf')::numeric END, 0) / 10)::integer + 20);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
    v_repere := public.crime_detecter_interne(v_moi, 'corrompre_douanier', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- 4. Contrebande portuaire.
CREATE OR REPLACE FUNCTION public.crime_contrebande(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false; v_dis numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_paie := public.payer_ordre(v_moi, 'contrebande_port', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT country, current_city, stats, resources INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_dis := coalesce(CASE WHEN jsonb_typeof(m.resources -> 'dis') = 'number' THEN (m.resources ->> 'dis')::numeric END, 8);
  v_taux := greatest(5, 55 + floor(v_dis / 10)::integer + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer + 15
            + CASE m.country WHEN 'narco' THEN 25 WHEN 'soviet' THEN -20 WHEN 'khalija' THEN 10 ELSE 0 END
            - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    UPDATE public.personnages_donnees
       SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
         || jsonb_build_array(jsonb_build_object('id', 'contrebande-' || replace(gen_random_uuid()::text, '-', ''),
              'type', 'contrebande', 'name', 'Cargaison de contrebande', 'icon', 'ti-package-off', 'legal', false,
              'desc', 'Marchandises importées illégalement.'))
     WHERE name = v_moi;
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
    v_repere := public.crime_detecter_interne(v_moi, 'contrebande_port', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- 5. Falsification de document.
CREATE OR REPLACE FUNCTION public.crime_falsifier(p_doc text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false; v_doc jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_doc := CASE p_doc
    WHEN 'fausse_identite' THEN '{"name":"Fausse identite","icon":"ti-id-badge","desc":"Change votre nom affiche dans le jeu temporairement."}'
    WHEN 'faux_permis' THEN '{"name":"Faux permis de construire","icon":"ti-building","desc":"Permet de construire sans passer par la mairie."}'
    WHEN 'faux_contrat' THEN '{"name":"Faux contrat commercial","icon":"ti-file-text","desc":"Legitime une transaction illegale ou un transfert."}'
    WHEN 'fausse_convocation' THEN '{"name":"Fausse convocation officielle","icon":"ti-mail","desc":"Attire un PJ dans un lieu de votre choix."}'
  END::jsonb;
  IF v_doc IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'document_inconnu'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'falsifier_document' AND pa = p_pa AND cost = p_cost) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  v_paie := public.payer_ordre(v_moi, 'falsifier_document#tentative', p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, 45 - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
  END IF;
  v_paie := public.payer_ordre(v_moi, 'falsifier_document#reussite', 0, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'raison', 'fonds_insuffisants') || public.crime_etat_acteur_interne(v_moi);
  END IF;
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
       || jsonb_build_array(v_doc || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
            'type', 'document_falsifie', 'docId', p_doc, 'legal', false))
   WHERE name = v_moi;
  v_repere := public.crime_detecter_interne(v_moi, 'falsifier_document', true);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'repere', v_repere, 'nom_document', v_doc ->> 'name', 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

REVOKE ALL ON FUNCTION public.crime_etat_acteur_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_dis_ajuster_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_corrompre(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_corrompre(text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_corrompre_douanier(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_corrompre_douanier(integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_contrebande(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_contrebande(integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_falsifier(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_falsifier(text, integer, integer) TO authenticated;
