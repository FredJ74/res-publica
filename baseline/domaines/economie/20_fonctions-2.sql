-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- fret_dedouaner(uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fret_dedouaner(p_caisse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; c record; v_val numeric; v_jours int; v_factures int;
  v_douane numeric; v_gard numeric; v_total numeric; v_caisse text; v_mvt jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  IF c.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF COALESCE(c.dedouanee, false) THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'deja_dedouanee');
  END IF;
  IF COALESCE(c.statut, '') <> 'arrivee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide', 'statut', c.statut);
  END IF;

  v_val := GREATEST(0, COALESCE(c.valeur_declaree, 0));
  v_douane := round(v_val * 10 / 100.0);
  v_gard := 0;
  IF c.date_arrivee_reelle IS NOT NULL THEN
    v_jours := floor(EXTRACT(epoch FROM (now() - c.date_arrivee_reelle)) / 86400)::int;
    v_factures := GREATEST(0, v_jours - 7);
    IF v_factures > 0 THEN v_gard := round(v_val * 1 / 100.0 * v_factures); END IF;
  END IF;
  v_total := v_douane + v_gard;

  IF v_total > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                                'douane', v_douane, 'gardiennage', v_gard);
    END IF;
    -- Credit de la caisse du port DANS LA MEME TRANSACTION que le debit.
    v_caisse := c.pays_destination || '_' || c.building_destination;
    v_mvt := public.caisse_institution_mouvement(v_caisse, v_total, false);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'credit_caisse_port_impossible: %', COALESCE(v_mvt->>'raison','?');
    END IF;
  END IF;

  UPDATE public.caisses_fret
     SET dedouanee = true, date_dedouanement = now()
   WHERE id = p_caisse_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'douane', v_douane,
    'gardiennage', v_gard, 'jours_factures', COALESCE(v_factures, 0), 'caisse', v_caisse,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

-- fret_unitaire_international() -> numeric | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fret_unitaire_international()
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT 0.40::numeric; $function$;

-- local_vocation_commerciale(text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.local_vocation_commerciale(p_building_id text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_building_id
    when 'centre-commercial' then 'commerce'
    when 'centre-artisanal'  then 'artisanat'
    when 'centre-affaires'   then 'services'
    else null
  end;
$function$;

-- matiere_circuits_disponibles(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.matiere_circuits_disponibles(p_matiere text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_matiere)
    THEN NULL
    ELSE jsonb_build_object(
      'matiere', p_matiere,
      'achat_entrepot', EXISTS (
        SELECT 1 FROM public.batiments_etat b
         WHERE b.id LIKE '%entrepot%'
           AND public.batiment_etat_lire(b.data)->'entrepot'->'stock' ? p_matiere),
      'achat_criee', EXISTS (
        SELECT 1 FROM public.batiments_etat b
         WHERE public.batiment_etat_lire(b.data)->'port'->'criee'->'stock' ? p_matiere),
      'vente_commerce', EXISTS (
        SELECT 1 FROM public.recettes_commerce r WHERE r.materiaux ? p_matiere),
      'vente_armurerie', EXISTS (
        SELECT 1 FROM public.recettes_production r WHERE r.materiaux ? p_matiere),
      'vente_usine', EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.matiere = p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.usines_rachat_config u
         WHERE coalesce(u.matieres_hors_chaine, '[]'::jsonb) ? p_matiere),
      'vente_medical', EXISTS (
        SELECT 1 FROM public.structures_medicales s
         WHERE coalesce(s.ressources, '[]'::jsonb) ? p_matiere),
      'production_usine', EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.produit = p_matiere),
      'recolte', p_matiere IN ('metal', 'poisson', 'charbon', 'bois'),
      'transformation', EXISTS (
        SELECT 1 FROM public.recettes_commerce r WHERE r.materiaux ? p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.recettes_production r WHERE r.materiaux ? p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.matiere = p_matiere),
      'categories', coalesce((
        SELECT jsonb_agg(c.categorie ORDER BY c.categorie)
          FROM public.assemblee_categories_interdiction c
         WHERE p_matiere = ANY (c.matieres)), '[]'::jsonb)
    ) END;
$function$;

-- matiere_refus_circuit_legal(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.matiere_refus_circuit_legal(p_acteur text, p_matiere text, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_loi jsonb; v_mode text := lower(btrim(coalesce(p_mode, '')));
BEGIN
  IF coalesce(p_acteur, '') = '' OR coalesce(p_matiere, '') = '' THEN RETURN NULL; END IF;

  -- LE DON N'EST PAS UN CIRCUIT ECONOMIQUE. Seul endroit du serveur ou cette
  -- exception est ecrite. Un transfert gratuit reste possible, et sa trace au
  -- registre est justement ce qui rendra une filiere reperable.
  IF v_mode = 'don' THEN RETURN NULL; END IF;

  -- LA JURIDICTION EST CELLE DU PERSONNAGE, LUE EN BASE. Jamais un pays transmis
  -- par l'appelant : plusieurs des RPC gardees ici recoivent le leur du navigateur.
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_pays IS NULL THEN RETURN NULL; END IF;

  -- assemblee_loi_en_vigueur n'est vraie que pour une loi ADOPTEE **ET MISE EN
  -- APPLICATION** depuis le 30 septembre 2026 : une loi votee que le Ministre de
  -- l'Interieur n'a pas encore prononcee ne bloque donc rien.
  v_loi := public.assemblee_loi_en_vigueur(v_pays,
             jsonb_build_object('stackKey', p_matiere), now());
  IF v_loi IS NULL THEN RETURN NULL; END IF;

  -- LA TRANSFORMATION EST LA SEULE DIMENSION VOTEE. Un stock deja possede reste
  -- transformable, sauf si l'Assemblee l'a expressement interdit (cas B). Le
  -- niveau vient de la loi, jamais du client ni du ministre.
  IF v_mode = 'transformation'
     AND coalesce((v_loi -> 'portee' ->> 'transformation_stock_interdite')::boolean, false) IS NOT TRUE THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object('ok', false, 'raison', 'matiere_interdite',
                            'matiere', p_matiere, 'mode', v_mode, 'loi', v_loi);
END $function$;

-- matiere_refus_circuit_legal_lot(text,jsonb,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.matiere_refus_circuit_legal_lot(p_acteur text, p_panier jsonb, p_mode text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.matiere_refus_circuit_legal(p_acteur, k.cle, p_mode)
    FROM jsonb_object_keys(
           CASE WHEN jsonb_typeof(p_panier) = 'object' THEN p_panier ELSE '{}'::jsonb END
         ) AS k(cle)
   WHERE public.matiere_refus_circuit_legal(p_acteur, k.cle, p_mode) IS NOT NULL
   ORDER BY k.cle
   LIMIT 1;
$function$;

-- ordres_couts_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ordres_couts_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(fn || '|' || pa || '|' || cost, E'\n'
                             ORDER BY fn COLLATE "C", pa, cost)), 16)
  FROM public.ordres_couts;
$function$;

-- payer_ordre(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v_fn) INTO v_connu;

  IF NOT v_connu THEN
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu', 'fn', v_fn);
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                 WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
    INTO v_valide;
  IF NOT v_valide THEN
    INSERT INTO public.ordres_couts_ecarts (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn, pa, cost)
      DO UPDATE SET occurrences = public.ordres_couts_ecarts.occurrences + 1, vu_le = now();
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', v_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

  v_pris_liquide := least(coalesce(v_liquide,0), coalesce(p_cost,0));
  v_pris_national := coalesce(p_cost,0) - v_pris_liquide;

  UPDATE public.personnages_donnees
     SET pa = v_pa - coalesce(p_pa,0),
         liquide = coalesce(v_liquide,0) - v_pris_liquide,
         arg = coalesce(v_arg,0) - coalesce(p_cost,0)
   WHERE name = p_acteur;

  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national,
           updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pa', v_pa - coalesce(p_pa,0),
    'liquide', coalesce(v_liquide,0) - v_pris_liquide,
    'arg', coalesce(v_arg,0) - coalesce(p_cost,0),
    'solde_national', v_solde - v_pris_national,
    'pa_preleves', coalesce(p_pa,0), 'montant_preleve', coalesce(p_cost,0));
END; $function$;

-- prix_ressource_selon_stock(text,numeric) -> numeric | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.prix_ressource_selon_stock(p_cle text, p_en_stock numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_base numeric; v_plafond numeric; v_taux numeric;
BEGIN
  SELECT prix_base, plafond INTO v_base, v_plafond FROM public.ressources_economie WHERE cle = p_cle;
  IF v_base IS NULL THEN RETURN NULL; END IF;   -- jamais de tarif invente
  v_taux := greatest(0, least(1, coalesce(p_en_stock,0) / nullif(v_plafond,0)));
  RETURN round(v_base * (1 + (0.5 - v_taux) * 0.8), 2);
END; $function$;

-- produire_en_usine(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.produire_en_usine(p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ville text; v_bat text; v_matiere text; v_salaire numeric;
  v_id text; v_etat jsonb; v_usine jsonb; v_vd jsonb; v_sm jsonb;
  v_caisse numeric; v_stock_mat numeric; v_stock_prod numeric; v_place numeric; v_produits int;
  v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, matiere, salaire_pa INTO v_ville, v_bat, v_matiere, v_salaire
  FROM public.chaines_production_usine WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'chaine_inconnue'); END IF;

  -- PRODUCTION LEGALE (30 septembre 2026). Une loi appliquee visant la matiere
  -- PRODUITE ferme la chaine : on ne fabrique plus legalement ce qui est
  -- interdit, dans les deux cas A et B.
  IF public.matiere_refus_circuit_legal(p_acteur, p_produit, 'production') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, p_produit, 'production');
  END IF;
  -- TRANSFORMATION. La chaine CONSOMME aussi une matiere : si c'est elle qui
  -- est interdite et que la loi a vote le cas B, la chaine s'arrete aussi.
  IF public.matiere_refus_circuit_legal(p_acteur, v_matiere, 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, v_matiere, 'transformation');
  END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_vd := coalesce(v_usine->'venteDirecte', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);
  v_stock_mat := coalesce((v_sm->>v_matiere)::numeric, 0);
  v_stock_prod := coalesce((v_vd->>p_produit)::numeric, 0);

  -- Memes trois conditions qu'avant, dans le meme ordre.
  IF v_stock_mat < 5 THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'matiere', v_matiere); END IF;
  IF v_caisse < v_salaire THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  v_place := greatest(0, 50 - v_stock_prod);
  IF v_place <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein'); END IF;

  v_produits := least(10, v_place)::int;   -- PRODUIT_PAR_PA_USINE, plafonne par la place
  v_sm := jsonb_set(v_sm, ARRAY[v_matiere], to_jsonb(v_stock_mat - 5));  -- MATIERE_PAR_PA_USINE
  v_vd := jsonb_set(v_vd, ARRAY[p_produit], to_jsonb(v_stock_prod + v_produits));
  v_caisse := v_caisse - v_salaire;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('caisse', v_caisse, 'venteDirecte', v_vd, 'stockMatieres', v_sm)))::text),
         updated_at = now()
   WHERE id = v_id;

  -- Le salaire sort de la caisse de l'usine et entre en liquide : aucune valeur
  -- creee, exactement comme le credit generique du jeu (crediterFondsOrdinaires).
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg,0) + v_salaire, liquide = coalesce(liquide,0) + v_salaire
   WHERE name = p_acteur
   RETURNING arg, liquide INTO v_arg, v_liquide;
  IF v_arg IS NULL THEN RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501'; END IF;

  RETURN jsonb_build_object('ok', true, 'produits', v_produits, 'salaire', v_salaire,
    'arg', v_arg, 'liquide', v_liquide, 'caisse_usine', v_caisse,
    'stock_produit', v_stock_prod + v_produits, 'stock_matiere', v_stock_mat - 5);
END; $function$;

-- recevoir_soin(text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recevoir_soin(p_acteur text, p_pays text, p_ville text, p_batiment text, p_type text, p_cout integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_sante jsonb; v_sm jsonb;
  v_jour int; v_stats jsonb; v_marqueur text;
  v_hp numeric; v_pa numeric; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_taxe jsonb; v_net numeric; v_gain_hp int; v_gain_pa int;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_type NOT IN ('public','clinique') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts
                 WHERE fn = CASE WHEN p_type='public' THEN 'soin_public' ELSE 'soins' END
                   AND cost = coalesce(p_cout,0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare', 'cout', p_cout);
  END IF;
  v_marqueur := CASE WHEN p_type='public' THEN 'soinPublicJour' ELSE 'soinCliniqueJour' END;

  SELECT coalesce(stats,'{}'::jsonb), coalesce(day,1), coalesce(hp,0), coalesce(pa,0),
         coalesce(liquide,0), coalesce(arg,0)
    INTO v_stats, v_jour, v_hp, v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_stats IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF coalesce((v_stats->>v_marqueur)::int, -1) = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soigne_aujourdhui');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'structure_introuvable'); END IF;
  v_sante := coalesce(v_etat->'sante', '{}'::jsonb);
  v_sm := coalesce(v_sante->'stockMatieres', '{}'::jsonb);

  IF p_type = 'public' THEN
    IF coalesce((v_sm->>'desinfectant')::numeric,0) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock');
    END IF;
    v_gain_hp := 10; v_gain_pa := 1;      -- valeurs REELLES du jeu
  ELSE
    IF coalesce((v_sm->>'desinfectant')::numeric,0) < 1
       OR coalesce((v_sm->>'medicaments')::numeric,0) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock');
    END IF;
    v_gain_hp := 30; v_gain_pa := 2;
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  IF v_liquide + v_solde < coalesce(p_cout,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'disponible', v_liquide + v_solde);
  END IF;
  v_pris_liquide := least(v_liquide, coalesce(p_cout,0));
  v_pris_national := coalesce(p_cout,0) - v_pris_liquide;

  IF p_type = 'public' THEN
    v_sm := jsonb_set(v_sm, '{desinfectant}', to_jsonb(coalesce((v_sm->>'desinfectant')::numeric,0) - 1));
    v_sante := v_sante || jsonb_build_object('stockMatieres', v_sm);
  ELSE
    v_taxe := public.appliquer_taxe_transaction(p_pays, p_ville, coalesce(p_cout,0));
    v_net := (v_taxe->>'net')::numeric;
    v_sm := jsonb_set(jsonb_set(v_sm,
              '{desinfectant}', to_jsonb(coalesce((v_sm->>'desinfectant')::numeric,0) - 1)),
              '{medicaments}', to_jsonb(coalesce((v_sm->>'medicaments')::numeric,0) - 1));
    v_sante := v_sante || jsonb_build_object('stockMatieres', v_sm,
                 'caisse', coalesce((v_sante->>'caisse')::numeric,0) + v_net);
  END IF;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante))::text), updated_at = now()
   WHERE id = v_id;
  UPDATE public.personnages_donnees
     SET liquide = v_liquide - v_pris_liquide, arg = v_arg - coalesce(p_cout,0),
         hp = least(100, v_hp + v_gain_hp), pa = least(30, v_pa + v_gain_pa),
         stats = jsonb_set(v_stats, ARRAY[v_marqueur], to_jsonb(v_jour))
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hp', least(100, v_hp + v_gain_hp),
    'pa', least(30, v_pa + v_gain_pa), 'liquide', v_liquide - v_pris_liquide,
    'arg', v_arg - coalesce(p_cout,0), 'solde_national', v_solde - v_pris_national,
    'gain_hp', v_gain_hp, 'gain_pa', v_gain_pa, 'taxe', v_taxe);
END; $function$;

-- refectoire_repas(text,text,integer,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.refectoire_repas(p_pays text, p_joueur text, p_jour integer, p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pj personnages%ROWTYPE; v_pays text; v_jour text; v_stats jsonb;
  v_data jsonb; v_ref jsonb; v_commun jsonb; v_rations integer;
  v_cer integer; v_via integer; v_poi integer; v_prot text; v_fab boolean := false; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- Ni le pays ni le jour ne sont crus : le batiment 'caserne-militaire' existe dans les quatre
  -- empires, et p_jour etait un robinet de PA. p_pays, p_jour, p_gain et p_pa_max sont ignores.
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_pj.country, '')), ''), 'republic');
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE(v_stats ->> 'repasCaserneJour', '') = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange', 'jourCle', v_jour);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_ref := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object'
                THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_commun := CASE WHEN jsonb_typeof(v_data -> 'caserneMatieres') = 'object'
                   THEN v_data -> 'caserneMatieres' ELSE '{}'::jsonb END;
  v_rations := GREATEST(0, COALESCE((v_ref ->> 'rations')::integer, 0));

  IF v_rations <= 0 THEN
    -- Fabrication automatique d'un lot de 10, sur le STOCK COMMUN : 1 cereale + 1 (viande OU poisson).
    v_cer := GREATEST(0, COALESCE((v_commun ->> 'cereales')::integer, 0));
    v_via := GREATEST(0, COALESCE((v_commun ->> 'viande')::integer, 0));
    v_poi := GREATEST(0, COALESCE((v_commun ->> 'poisson')::integer, 0));
    IF v_cer < 1 OR (v_via + v_poi) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
                                'cereales', v_cer, 'viande', v_via, 'poisson', v_poi);
    END IF;
    v_prot := CASE WHEN v_via >= 1 THEN 'viande' ELSE 'poisson' END;
    v_commun := v_commun || jsonb_build_object('cereales', v_cer - 1,
                  v_prot, (CASE WHEN v_prot = 'viande' THEN v_via ELSE v_poi END) - 1);
    v_rations := 10;
    v_fab := true;
  END IF;

  v_rations := v_rations - 1;
  v_data := v_data
            || jsonb_build_object('caserneMatieres', v_commun)
            || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_rations));
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = v_pays;

  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa, stats = v_stats || jsonb_build_object('repasCaserneJour', v_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot,
                            'pays', v_pays, 'jourCle', v_jour);
END; $function$;

-- repondre_offre(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.repondre_offre(p_offre_id text, p_acteur text, p_acceptee boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_offre offres%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_offre_id,'')='' OR COALESCE(p_acteur,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO v_offre FROM offres WHERE id=p_offre_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','offre_absente'); END IF;
  IF v_offre.statut<>'ouverte' THEN RETURN jsonb_build_object('ok',true,'deja_resolue',true,'statut',v_offre.statut); END IF;
  IF v_offre.expire_a<=now() THEN UPDATE offres SET statut='expiree',resolu_a=now() WHERE id=p_offre_id; RETURN jsonb_build_object('ok',false,'raison','offre_expiree'); END IF;
  IF p_acteur=v_offre.destinataire THEN
    UPDATE offres SET statut=CASE WHEN COALESCE(p_acceptee,false) THEN 'acceptee' ELSE 'refusee' END,resolu_a=now() WHERE id=p_offre_id;
    RETURN jsonb_build_object('ok',true,'deja_resolue',false,'statut',CASE WHEN COALESCE(p_acceptee,false) THEN 'acceptee' ELSE 'refusee' END,'type',v_offre.type,'actif',v_offre.actif,'emetteur',v_offre.emetteur,'destinataire',v_offre.destinataire,'montant',v_offre.montant);
  ELSIF p_acteur=v_offre.emetteur AND COALESCE(p_acceptee,false) IS NOT TRUE THEN
    UPDATE offres SET statut='annulee',resolu_a=now() WHERE id=p_offre_id;
    RETURN jsonb_build_object('ok',true,'deja_resolue',false,'statut','annulee');
  END IF;
  RETURN jsonb_build_object('ok',false,'raison','pas_partie_a_l_offre');
END;
$function$;

-- ressources_economie_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ressources_economie_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      cle || '|' || public.ressources_economie_nombre(prix_base)
          || '|' || public.ressources_economie_nombre(prix_achat_fournisseur)
          || '|' || public.ressources_economie_nombre(plafond::numeric)
          || '|' || coalesce(source, ''),
      E'\n' ORDER BY cle COLLATE "C")), 16)
  FROM public.ressources_economie;
$function$;

-- ressources_economie_nombre(numeric) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ressources_economie_nombre(n numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN n IS NULL THEN ''
              WHEN n = trunc(n) THEN trunc(n)::bigint::text
              ELSE n::text END;
$function$;

-- restituer_reliquats_chantier(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.restituer_reliquats_chantier(p_beneficiaire text, p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pj         personnages%ROWTYPE;
  v_terrain    terrains_etat%ROWTYPE;
  v_data       jsonb;
  v_acheve     jsonb;
  v_reliquats  jsonb;
  v_materiaux  jsonb;
  v_montant    numeric;
  v_matiere    text;
  v_qte        integer;
  v_jour       text;
  v_remis      jsonb := '{}'::jsonb;
  v_libelle    text;
  v_icone      text;
BEGIN
  IF COALESCE(p_beneficiaire, '') = '' OR COALESCE(p_terrain_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM personnages WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_absent'); END IF;

  SELECT * INTO v_terrain FROM terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- terrains_etat.data est une colonne TEXT contenant du JSON (meme convention qu'organisations).
  BEGIN
    v_data := v_terrain.data::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_illisible');
  END;

  v_acheve := v_data -> 'chantierAcheve';
  IF v_acheve IS NULL OR jsonb_typeof(v_acheve) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_chantier_livre');
  END IF;

  v_reliquats := v_acheve -> 'reliquats';
  IF v_reliquats IS NULL OR jsonb_typeof(v_reliquats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_reliquat');
  END IF;

  -- DEJA FAIT : reponse positive, aucune ecriture. C'est le cas normal d'un cron rejoue.
  IF COALESCE((v_reliquats ->> 'restitue')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'deja_restitue', true, 'montant', 0);
  END IF;

  -- LE BENEFICIAIRE EST LE PROPRIETAIRE DES MURS AU MOMENT DE LA LIVRAISON, pas celui qui a lance
  -- ni finance le chantier. On verifie que le nom fourni est bien celui inscrit sur le terrain :
  -- s'il ne l'est pas, on ne paie personne et le cron rejouera avec le bon nom.
  IF COALESCE(v_data ->> 'proprietaire', '') <> p_beneficiaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_incoherent');
  END IF;

  v_montant   := GREATEST(0, COALESCE((v_reliquats ->> 'tresorerie')::numeric, 0));
  v_materiaux := COALESCE(v_reliquats -> 'materiaux', '{}'::jsonb);
  v_jour      := COALESCE(v_acheve ->> 'jourLivraison', 'sansjour');

  -- 1. TRESORERIE. Rien n'est cree : cette somme a ete retiree du chantier par le meme traitement
  --    qui l'a inscrite ici, et elle n'y est plus disponible.
  IF v_montant > 0 THEN
    UPDATE personnages SET arg = COALESCE(arg, 0) + v_montant WHERE name = p_beneficiaire;
  END IF;

  -- 2. MATERIAUX, par le canal de reception AUTOMATIQUE (objets_recus). Ce canal est celui des
  --    objets qu'on n'a pas choisi de prendre : il ignore le plafond de 100 et fait passer son
  --    destinataire en Surcharge, exactement comme prevu au Lot 1.5.4. On n'ecrit surtout pas
  --    directement dans personnages.inventory : un client ouvert reecrit l'inventaire entier a sa
  --    prochaine sauvegarde et ecraserait l'ajout.
  --    L'identifiant est DETERMINISTE (terrain + jour de livraison + matiere) : un rejeu ne peut
  --    pas produire un second lot, meme si la transaction precedente avait echoue apres l'insert.
  FOR v_matiere IN SELECT unnest(ARRAY['bois', 'minerai', 'metal']) LOOP
    v_qte := GREATEST(0, floor(COALESCE((v_materiaux ->> v_matiere)::numeric, 0)))::integer;
    CONTINUE WHEN v_qte <= 0;
    -- Libelle et icone : simple habillage, repris de RESSOURCES_ECONOMIE (data.js). Aucune regle
    -- de jeu ne depend de ces deux chaines ; les quantites, elles, viennent du terrain verrouille.
    v_libelle := CASE v_matiere WHEN 'bois' THEN 'Bois' WHEN 'minerai' THEN 'Minerai' ELSE 'Métal' END;
    v_icone   := CASE v_matiere WHEN 'bois' THEN 'ti-trees' WHEN 'minerai' THEN 'ti-mountain' ELSE 'ti-bolt' END;
    -- Garde ecrite en SQL plutot qu'en ON CONFLICT : la definition d'objets_recus n'est pas
    -- versionnee dans le depot, on ne presume donc d'aucune contrainte d'unicite sur id. Le verrou
    -- deja pris sur terrains_etat serialise de toute facon deux appels concurrents.
    INSERT INTO objets_recus (id, destinataire, expediteur, data)
    SELECT 'reliquat-' || p_terrain_id || '-' || v_jour || '-' || v_matiere,
           p_beneficiaire,
           'Chef de Chantier',
           jsonb_build_object(
             'name', v_libelle, 'icon', v_icone,
             'stackable', true, 'stackKey', v_matiere, 'qty', v_qte,
             'desc', 'Matériaux restitués à la livraison du chantier.'
           )::text
    WHERE NOT EXISTS (
      SELECT 1 FROM objets_recus
      WHERE id = 'reliquat-' || p_terrain_id || '-' || v_jour || '-' || v_matiere
    );
    v_remis := jsonb_set(v_remis, ARRAY[v_matiere], to_jsonb(v_qte));
  END LOOP;

  -- 3. MARQUEUR, dans la MEME transaction que les deux paiements. C'est lui qui rend l'operation
  --    rejouable sans risque : tant qu'il n'est pas pose, rien n'a ete paye ; une fois pose, plus
  --    rien ne le sera.
  v_reliquats := jsonb_set(v_reliquats, '{restitue}', 'true'::jsonb);
  v_reliquats := jsonb_set(v_reliquats, '{dateRestitution}',
                   to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_acheve    := jsonb_set(v_acheve, '{reliquats}', v_reliquats);
  v_data      := jsonb_set(v_data, '{chantierAcheve}', v_acheve);

  UPDATE terrains_etat
    SET data = v_data::text,
        updated_at = now()
    WHERE id = p_terrain_id;

  RETURN jsonb_build_object('ok', true, 'deja_restitue', false,
                            'montant', v_montant, 'materiaux', v_remis,
                            'beneficiaire', p_beneficiaire);
END;
$function$;

-- vendre_fonds_commerce(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vendre_fonds_commerce(p_vendeur text, p_acheteur text, p_fonds_id text, p_prix integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb;
  v_bail_id text;
  v_bail jsonb;
  v_prix integer := GREATEST(0, COALESCE(p_prix, 0));
  v_caisse integer;
  v_premier text;
  v_second text;
BEGIN
  IF COALESCE(p_vendeur, '') = '' OR COALESCE(p_acheteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_vendeur = p_acheteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_identique'); END IF;
  IF left(p_acheteur, 6) = 'ville:' THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_invalide'); END IF;
  IF p_vendeur < p_acheteur THEN v_premier := p_vendeur; v_second := p_acheteur; ELSE v_premier := p_acheteur; v_second := p_vendeur; END IF;
  IF NOT mouvement_titulaire(v_premier, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  IF NOT mouvement_titulaire(v_second, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_vendeur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_prix > 0 THEN
    IF NOT mouvement_titulaire(p_acheteur, -v_prix) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_insolvable'); END IF;
    IF NOT mouvement_titulaire(p_vendeur, v_prix) THEN RAISE EXCEPTION 'vendeur_introuvable'; END IF;
  END IF;
  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_caisse > 0 THEN IF NOT mouvement_titulaire(p_vendeur, v_caisse) THEN RAISE EXCEPTION 'extraction_impossible'; END IF; END IF;
  v_data := jsonb_set(v_data, '{proprietaire}', to_jsonb(p_acheteur));
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(0));
  v_data := jsonb_set(v_data, '{historique}', COALESCE(v_data -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'evenement', 'vente', 'vendeur', p_vendeur, 'acheteur', p_acheteur, 'prix', v_prix, 'caisseExtraite', v_caisse,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
  UPDATE entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  v_bail_id := v_data -> 'implantation' ->> 'bailId';
  IF COALESCE(v_bail_id, '') <> '' THEN
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_bail_id FOR UPDATE;
    IF v_bail IS NOT NULL THEN
      UPDATE locations_actives
        SET data = v_bail || jsonb_build_object(
              'locataire', CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
              'locataireRef', p_acheteur,
              'transferts', COALESCE(v_bail -> 'transferts', '[]'::jsonb) || jsonb_build_array(
                jsonb_build_object('cause', 'vente_fonds', 'de', p_vendeur, 'vers', p_acheteur,
                  'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))))
        WHERE id = v_bail_id;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'prix', v_prix, 'caisseExtraite', v_caisse, 'acheteur', p_acheteur, 'bailTransfere', COALESCE(v_bail_id, ''));
END;
$function$;

-- vendre_materiaux_chantier(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vendre_materiaux_chantier(p_vendeur text, p_country text, p_building_id text, p_matiere text, p_quantite integer, p_prix integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  PERFORM public.exiger_acteur(p_vendeur);
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
$function$;

-- vendre_matiere_a_usine(text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vendre_matiere_a_usine(p_acteur text, p_pays text, p_ville text, p_batiment text, p_matiere text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle text := p_pays || '|' || coalesce(p_ville,'') || '|' || p_batiment;
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_accepte boolean; v_detail boolean;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_cmm jsonb;
  v_plafond numeric; v_stock numeric; v_place numeric;
  v_prix numeric; v_total numeric; v_caisse numeric;
  v_inv jsonb; v_detenu numeric; v_arg numeric; v_liquide numeric;
  v_cout_moyen numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : vente de matiere a une usine.
  -- Une matiere interdite par l'Assemblee ne peut plus y entrer. Le don, lui,
  -- reste licite -- mais ce circuit-ci n'est pas un don. Garde posee avant toute
  -- lecture metier et toute ecriture ; la juridiction est resolue par le serveur.
  IF public.matiere_refus_circuit_legal(p_acteur, p_matiere, 'vente') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, p_matiere, 'vente');
  END IF;
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- Matiere acceptee ? Par une chaine de l'usine, ou par sa liste hors chaine.
  SELECT coalesce(prix_detail, false),
         EXISTS (SELECT 1 FROM public.chaines_production_usine c
                 WHERE c.building_id = p_batiment AND c.matiere = p_matiere)
         OR coalesce(matieres_hors_chaine, '[]'::jsonb) ? p_matiere
    INTO v_detail, v_accepte
  FROM public.usines_rachat_config WHERE cle = v_cle;
  IF v_accepte IS NULL THEN
    v_detail := false;
    SELECT EXISTS (SELECT 1 FROM public.chaines_production_usine c
                   WHERE c.building_id = p_batiment AND c.matiere = p_matiere) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee');
  END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_inv, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_matiere);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_cmm := coalesce(v_usine->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);

  SELECT plafond, CASE WHEN v_detail THEN prix_base ELSE prix_achat_fournisseur END
    INTO v_plafond, v_prix FROM public.ressources_economie WHERE cle = p_matiere;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;

  v_stock := coalesce((v_sm->>p_matiere)::numeric, 0);
  v_place := greatest(0, coalesce(v_plafond,0) - v_stock);
  IF v_place < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
  END IF;

  v_total := v_prix * p_qte;
  IF v_caisse < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  -- Cout moyen pondere, meme calcul que crediterStockMatiereCommerce.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>p_matiere)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, p_matiere, p_qte),
         arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = p_acteur;

  v_usine := v_usine || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_matiere], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_matiere], to_jsonb(v_cout_moyen)),
    'caisse', v_caisse - v_total);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
    'inventory', public.inventaire_retirer(v_inv, p_matiere, p_qte),
    'caisse_usine', v_caisse - v_total);
END; $function$;

-- vendre_ressource_medicale(text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vendre_ressource_medicale(p_acteur text, p_pays text, p_ville text, p_batiment text, p_ressource text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_ressources jsonb; v_financement text;
  v_etat jsonb; v_sante jsonb; v_sm jsonb; v_cmm jsonb;
  v_plafond numeric; v_stock numeric; v_place numeric; v_prix numeric; v_total numeric;
  v_caisse numeric; v_inv jsonb; v_detenu numeric; v_arg numeric; v_liquide numeric;
  v_cout_moyen numeric; v_caisse_id text; v_solde_inst numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : vente de ressource a une structure medicale.
  -- Une matiere interdite par l'Assemblee ne peut plus y entrer. Le don, lui,
  -- reste licite -- mais ce circuit-ci n'est pas un don. Garde posee avant toute
  -- lecture metier et toute ecriture ; la juridiction est resolue par le serveur.
  IF public.matiere_refus_circuit_legal(p_acteur, p_ressource, 'vente') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, p_ressource, 'vente');
  END IF;
  IF p_qte IS NULL OR p_qte <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT ressources, financement INTO v_ressources, v_financement
  FROM public.structures_medicales WHERE building_id = p_batiment;
  IF v_ressources IS NULL OR NOT (v_ressources ? p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_non_acceptee');
  END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_inv, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_ressource);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'structure_introuvable'); END IF;
  v_sante := coalesce(v_etat->'sante', '{}'::jsonb);
  v_sm := coalesce(v_sante->'stockMatieres', '{}'::jsonb);
  v_cmm := coalesce(v_sante->'coutMoyenMatieres', '{}'::jsonb);

  SELECT plafond, prix_achat_fournisseur INTO v_plafond, v_prix
  FROM public.ressources_economie WHERE cle = p_ressource;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_stock := coalesce((v_sm->>p_ressource)::numeric, 0);
  v_place := greatest(0, coalesce(v_plafond,0) - v_stock);
  IF v_place < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
  END IF;
  v_total := v_prix * p_qte;

  -- Deux financements, deux caisses -- exactement comme le client le faisait.
  IF v_financement = 'propre' THEN
    v_caisse := coalesce((v_sante->>'caisse')::numeric, 0);
    IF v_caisse < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_sante := v_sante || jsonb_build_object('caisse', v_caisse - v_total);
  ELSE
    v_caisse_id := p_pays || '_' || p_batiment;
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_inst
    FROM public.caisses_batiments WHERE id = v_caisse_id FOR UPDATE;
    IF v_solde_inst IS NULL OR v_solde_inst < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                                'caisse', coalesce(v_solde_inst, 0));
    END IF;
    UPDATE public.caisses_batiments
       SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}', to_jsonb(v_solde_inst - v_total)),
           updated_at = now()
     WHERE id = v_caisse_id;
  END IF;

  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>p_ressource)::numeric,0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;
  v_sante := v_sante || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_ressource], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_ressource], to_jsonb(v_cout_moyen)));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante))::text), updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, p_ressource, p_qte),
         arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
    'inventory', public.inventaire_retirer(v_inv, p_ressource, p_qte));
END; $function$;

-- ventes_snapshots_append_only() -> trigger | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.ventes_snapshots_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'preuve_immuable: une vente enregistree ne peut etre ni modifiee ni supprimee'
    USING ERRCODE = '42501';
END;
$function$;
