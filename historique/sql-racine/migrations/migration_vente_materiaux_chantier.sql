-- =====================================================================
-- LOT 1.5.10 — VENTE DE MATERIAUX PAR UN PJ A UN CHANTIER
-- RPC transactionnelle : tout ou rien
-- 6 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Le client est fail-closed : tant que la RPC n'existe pas, sbRpc renvoie null et la vente est
-- refusee avec un message explicite -- jamais de repli sur un chemin client non transactionnel.
--
-- POURQUOI UNE RPC. La vente touche DEUX lignes de deux tables differentes : personnages
-- (inventaire + argent) et terrains_etat (stock + tresorerie + journal). Via l'API REST ce sont
-- forcement deux ecritures separees : une panne entre les deux laisse un joueur paye sans avoir
-- livre, ou depouille sans avoir ete paye. Meme doctrine qu'au Lot 1.4 pour les loyers : la RPC
-- est l'autorite transactionnelle unique.
--
-- LE CLIENT N'EST JAMAIS CRU. Ni la quantite, ni le montant, ni le stock ne sont acceptes tels
-- quels : la fonction relit tout sous verrou et RECALCULE la quantite reellement transferable.
-- Le client ne transmet qu'une intention -- matiere, quantite voulue, prix demande.
--
-- GAME DESIGN INCHANGE : prix totalement libre (aucun plafond, le prix de l'entrepot n'intervient
-- nulle part), reserve possible bien au-dela du besoin quotidien, bornes uniquement reelles
-- (stock du vendeur, tresorerie du chantier), journal nominatif.

CREATE OR REPLACE FUNCTION vendre_materiaux_chantier(
  p_vendeur     text,
  p_country     text,
  p_building_id text,
  p_matiere     text,
  p_quantite    integer,
  p_prix        integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pj          personnages%ROWTYPE;
  v_terrain     terrains_etat%ROWTYPE;
  v_data        jsonb;
  v_chantier    jsonb;
  v_stock       jsonb;
  v_inv         jsonb;
  v_ligne       jsonb;
  v_idx         integer := -1;
  v_i           integer;
  v_possede     integer := 0;
  v_tresorerie  numeric;
  v_payables    integer;
  v_qte         integer;
  v_montant     numeric;
  v_duree       numeric;
  v_progression numeric;
  v_terrain_id  text := p_country || '_' || p_building_id;
BEGIN
  IF p_matiere NOT IN ('bois', 'minerai', 'metal') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_invalide');
  END IF;
  IF COALESCE(p_quantite, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF COALESCE(p_prix, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide');
  END IF;

  -- VERROUS. Ordre fixe personnages -> terrains_etat, applique a toutes les ventes : deux ventes
  -- simultanees sur le meme chantier se serialisent au lieu de s'ecraser, et l'ordre etant
  -- toujours le meme, aucune de ces deux transactions ne peut en bloquer une autre en sens
  -- inverse.
  SELECT * INTO v_pj FROM personnages WHERE name = p_vendeur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_absent'); END IF;

  SELECT * INTO v_terrain FROM terrains_etat WHERE id = v_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- PRESENCE PHYSIQUE, verifiee sur la donnee faisant autorite cote serveur.
  IF COALESCE(v_pj.current_building, '') <> p_building_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- terrains_etat.data est une colonne TEXT contenant du JSON (meme convention que organisations).
  BEGIN
    v_data := v_terrain.data::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_illisible');
  END;

  v_chantier := v_data -> 'chantier';
  IF v_chantier IS NULL OR jsonb_typeof(v_chantier) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  -- Un chantier arrive a son terme n'accepte plus de marchandise.
  v_duree       := COALESCE((v_chantier ->> 'dureeJours')::numeric, 0);
  v_progression := COALESCE((v_chantier ->> 'progressionJours')::numeric, 0);
  IF v_duree > 0 AND v_progression >= v_duree THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_termine');
  END IF;

  -- STOCK REEL DU VENDEUR, relu sur son inventaire -- jamais celui annonce par le client.
  v_inv := COALESCE(v_pj.inventory, '[]'::jsonb);
  IF jsonb_typeof(v_inv) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_illisible');
  END IF;
  FOR v_i IN 0 .. jsonb_array_length(v_inv) - 1 LOOP
    v_ligne := v_inv -> v_i;
    IF (v_ligne ->> 'stackKey') = p_matiere AND COALESCE((v_ligne ->> 'stackable')::boolean, false) THEN
      v_idx := v_i;
      v_possede := GREATEST(0, floor(COALESCE((v_ligne ->> 'qty')::numeric, 0))::integer);
      EXIT;
    END IF;
  END LOOP;
  IF v_idx < 0 OR v_possede <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant');
  END IF;

  -- TRESORERIE REELLE DU CHANTIER. Aucun plafond de prix : c'est elle, et elle seule, qui borne.
  v_tresorerie := GREATEST(0, COALESCE((v_chantier ->> 'tresorerie')::numeric, 0));
  v_payables   := floor(v_tresorerie / p_prix)::integer;

  -- RECALCUL SERVEUR de la quantite transferable.
  v_qte := LEAST(p_quantite, v_possede, v_payables);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante');
  END IF;
  v_montant := v_qte::numeric * p_prix;

  -- ---- A partir d'ici, tout est applique ou rien ne l'est.

  -- 1. Retrait chez le vendeur. La ligne d'inventaire disparait si elle tombe a zero.
  IF v_possede - v_qte <= 0 THEN
    v_inv := v_inv - v_idx;
  ELSE
    v_inv := jsonb_set(v_inv, ARRAY[v_idx::text, 'qty'], to_jsonb(v_possede - v_qte));
  END IF;

  -- 2. Credit du stock du chantier. Le stock est un VRAI stock : aucune limitation au besoin du
  --    jour, une reserve peut etre constituee pour les jours suivants.
  v_stock := COALESCE(v_chantier -> 'stockMateriaux', '{}'::jsonb);
  v_stock := jsonb_set(v_stock, ARRAY[p_matiere],
               to_jsonb(GREATEST(0, COALESCE((v_stock ->> p_matiere)::numeric, 0)) + v_qte));
  v_chantier := jsonb_set(v_chantier, '{stockMateriaux}', v_stock);

  -- 3. Debit de la tresorerie du chantier.
  v_chantier := jsonb_set(v_chantier, '{tresorerie}', to_jsonb(v_tresorerie - v_montant));

  -- 4. Journal NOMINATIF : contrairement au journal d'un vol, le vendeur est connu.
  v_chantier := jsonb_set(v_chantier, '{ventesMateriauxPJ}',
    COALESCE(v_chantier -> 'ventesMateriauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('vendeur', p_vendeur, 'matiere', p_matiere, 'quantite', v_qte,
                         'prixUnitaire', p_prix, 'montant', v_montant,
                         'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));

  UPDATE terrains_etat
    SET data = (v_data || jsonb_build_object('chantier', v_chantier))::text,
        updated_at = now()
    WHERE id = v_terrain_id;

  -- 5. Paiement du vendeur et ecriture de son inventaire, dans la MEME transaction.
  UPDATE personnages
    SET arg = COALESCE(arg, 0) + v_montant,
        inventory = v_inv
    WHERE name = p_vendeur;

  RETURN jsonb_build_object('ok', true, 'quantite', v_qte, 'montant', v_montant,
                            'prixUnitaire', p_prix, 'matiere', p_matiere);
END;
$$;

-- Droits d'execution : la vente est declenchee par le joueur depuis son navigateur, donc par la
-- cle anon -- meme doctrine que les 14 RPC deja en production (placements, Helvetia). L'invariant
-- n'est pas porte par l'appelant mais par la fonction elle-meme, qui relit et recalcule tout sous
-- verrou. On ne revoque donc PAS anon ici, contrairement a prelever_loyer_bail, qui n'est appelee
-- que par le cron.
REVOKE ALL ON FUNCTION vendre_materiaux_chantier(text, text, text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION vendre_materiaux_chantier(text, text, text, text, integer, integer) TO anon;
GRANT EXECUTE ON FUNCTION vendre_materiaux_chantier(text, text, text, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION vendre_materiaux_chantier(text, text, text, text, integer, integer) TO service_role;

-- CONTROLE POSTERIEUR — attendu : anon, authenticated, service_role (et le proprietaire).
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_name = 'vendre_materiaux_chantier'
ORDER BY grantee;
