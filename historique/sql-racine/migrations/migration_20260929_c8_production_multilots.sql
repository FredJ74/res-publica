-- ===========================================================================
-- C8 — PRODUIRE PLUSIEURS LOTS EN UNE COMMANDE
-- 29 septembre 2026
-- ===========================================================================
-- POURQUOI CE N'EST PAS UNE BOUCLE CLIENTE. Le navigateur pourrait appeler N
-- fois fonds_reference_produire : ce serait N transactions independantes. Les
-- trois premieres passeraient, la quatrieme manquerait de matiere, et le joueur
-- se retrouverait avec une demi-production qu'il n'a pas demandee -- des PA
-- depenses, une caisse entamee, un stock partiel, et aucun moyen de revenir en
-- arriere. C6 avait pose la regle inverse en toutes lettres : « refus global,
-- toujours avant la premiere ecriture ». Une commande de N lots doit donc etre
-- UNE transaction, qui refuse tout ou fait tout.
--
-- POURQUOI UN NOUVEAU NOM, ET PAS UN PARAMETRE DE PLUS. Ajouter `p_lots` a
-- fonds_reference_produire creerait une seconde surcharge, et un appel a quatre
-- arguments -- exactement ce que le parcours public envoie -- deviendrait
-- AMBIGU (42725, « function is not unique ». Le piege a deja coute un chantier
-- sur militaire_ordre_collectif). Et supprimer l'ancienne signature obligerait
-- a toucher le parcours visiteur, hors de ce lot.
--
-- LA LOGIQUE N'EST DONC PAS DUPLIQUEE POUR AUTANT : elle demenage en entier
-- dans fonds_reference_produire_lots, et fonds_reference_produire devient un
-- relais d'une ligne vers `1 lot`. Une seule economie, deux portes -- c'est
-- exactement la forme que C6 avait retenue pour la production publique.
--
-- CE QUI NE CHANGE PAS, ET QUI EST VERIFIE AU BANC : le rendement reste
-- indivisible, le salaire reste la constante cout_main_oeuvre_pa_alimentaire
-- (50 FR/PA), le CMUP du produit fini se calcule comme avant (le cout unitaire
-- d'un lot ne depend pas du nombre de lots : la moyenne ponderee donne le meme
-- resultat qu'on melange les lots un a un ou tous ensemble), la fiscalite n'est
-- pas touchee, et une commande laisse UNE ligne dans productions_references --
-- une commande, une preuve, des grandeurs agregees.

-- ---------------------------------------------------------------------------
-- 1. LA PRODUCTION, DE UN A N LOTS
-- ---------------------------------------------------------------------------
create or replace function public.fonds_reference_produire_lots(
  p_requete text, p_acteur text, p_fonds_id text, p_reference_id text, p_lots integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
DECLARE
  v_lots integer := coalesce(p_lots, 0);
  v_max_ref integer;
  v_data jsonb; v_ref jsonb; v_r record; v_gen record;
  v_sm jsonb; v_couts jsonb; v_m text; v_q jsonb;
  v_besoin numeric; v_dispo numeric; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_pa_requis integer;
  v_nom_pj text; v_pa integer; v_manque jsonb := '[]'::jsonb;
  v_stock_avant integer; v_quantite integer; v_cout_lot numeric; v_unit numeric;
  v_cmup_avant numeric; v_cmup_apres numeric;
  v_deja record; v_salaire numeric; v_caisse numeric; v_jour integer;
  v_conso jsonb := '{}'::jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_requete IS NULL OR p_requete !~ '^prod-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  -- GARDE DE FORME, PAS REGLE DE JEU. Ce qui limite reellement une commande, ce
  -- sont les PA, les matieres, la caisse et le stock maximum -- tous verifies
  -- plus bas. Ce plafond-ci n'est la que pour qu'une valeur absurde recoive un
  -- refus nomme au lieu d'un debordement d'entier.
  IF v_lots < 1 OR v_lots > 99 OR v_lots IS DISTINCT FROM p_lots THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lots_invalides',
                              'minimum', 1, 'maximum', 99);
  END IF;
  v_nom_pj := CASE WHEN left(p_acteur,3) = 'pj:' THEN substr(p_acteur,4) ELSE p_acteur END;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(v_nom_pj, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF coalesce(v_ref->>'recette_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_recette'); END IF;

  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_ref->>'recette_id';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inexistante'); END IF;
  IF v_r.generique_id IS DISTINCT FROM (v_ref->>'generique_id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                              'recetteGenerique', v_r.generique_id,
                              'referenceGenerique', v_ref->>'generique_id'); END IF;
  IF coalesce(v_r.portions, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rendement_non_declare'); END IF;

  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_ref->>'generique_id'); END IF;

  -- IDEMPOTENCE INCHANGEE : une cle, une commande. Un double clic sur « produire
  -- 3 lots » ne produit toujours que 3 lots.
  SELECT * INTO v_deja FROM public.productions_references WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'coutUnitaire', v_deja.cout_unitaire);
  END IF;

  SELECT coalesce(pa, 0), coalesce(day, 1) INTO v_pa, v_jour
    FROM public.personnages_donnees WHERE name = v_nom_pj FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- LES PA DE LA COMMANDE ENTIERE. Un lot de plus, c'est un PA de plus : le refus
  -- porte sur le total, jamais sur le premier lot.
  v_pa_requis := greatest(0, coalesce(v_r.pa, 0)) * v_lots;
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'disponibles', v_pa,
                              'lots', v_lots); END IF;

  SELECT valeur::numeric INTO v_pa_val FROM public.entreprises_constantes
   WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  IF v_pa_val IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_pa_non_declaree'); END IF;
  v_salaire := round(v_pa_requis * v_pa_val, 2);

  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_couts := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_besoin := (v_q#>>'{}')::numeric * v_lots;
    v_conso  := jsonb_set(v_conso, ARRAY[v_m], to_jsonb(v_besoin), true);
    v_dispo  := coalesce((v_sm->>v_m)::numeric, 0);
    IF v_dispo < v_besoin THEN
      v_manque := v_manque || jsonb_build_object('matiere', v_m, 'requis', v_besoin, 'dispo', v_dispo);
    END IF;
    v_cm := (v_couts->>v_m)::numeric;
    IF v_cm IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cout_matiere_inconnu', 'matiere', v_m);
    END IF;
    v_mat := v_mat + v_besoin * v_cm;
  END LOOP;
  IF jsonb_array_length(v_manque) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                              'manquantes', v_manque, 'lots', v_lots);
  END IF;

  -- STOCK MAXIMUM DE L'ARTICLE. Le rendement reste INDIVISIBLE, et la commande
  -- l'est aussi : on ne fabrique pas « les deux lots qui rentrent sur trois ».
  -- `rendement` rend le total demande, parce que c'est ce total que le joueur a
  -- demande et que le message d'ecran lui oppose.
  v_quantite := v_r.portions * v_lots;
  v_max_ref  := nullif((v_data->'parametres'->'stockMaxReferences'->>p_reference_id)::integer, 0);
  v_stock_avant := greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  IF v_max_ref IS NOT NULL AND v_stock_avant + v_quantite > v_max_ref THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_reference_depasse',
      'stock', v_stock_avant, 'rendement', v_quantite, 'rendementLot', v_r.portions,
      'lots', v_lots, 'maximum', v_max_ref);
  END IF;

  -- LA CAISSE DOIT POUVOIR PAYER LA COMMANDE ENTIERE.
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  IF v_caisse < v_salaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'salaire', v_salaire, 'lots', v_lots);
  END IF;

  -- ===== A PARTIR D'ICI, ET SEULEMENT ICI, ON ECRIT =====
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_conso) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
              to_jsonb(coalesce((v_sm->>v_m)::numeric, 0) - (v_q#>>'{}')::numeric));
  END LOOP;

  v_cout_lot := v_mat + v_pa_requis * v_pa_val;
  v_unit     := v_cout_lot / v_quantite;

  -- CMUP DU PRODUIT FINI : inchange. Tous les lots d'une commande ont le meme
  -- cout unitaire, donc les melanger un a un ou d'un coup donne le meme resultat.
  v_cmup_avant := (v_data->'coutMoyenReferences'->>p_reference_id)::numeric;
  IF v_stock_avant <= 0 OR v_cmup_avant IS NULL THEN
    v_cmup_apres := v_unit;
  ELSE
    v_cmup_apres := (v_stock_avant * v_cmup_avant + v_cout_lot) / (v_stock_avant + v_quantite);
  END IF;

  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm);
  v_data := jsonb_set(v_data, ARRAY['stockReferences', p_reference_id],
              to_jsonb(v_stock_avant + v_quantite), true);
  v_data := jsonb_set(v_data, ARRAY['coutMoyenReferences', p_reference_id],
              to_jsonb(v_cmup_apres), true);
  v_data := v_data || jsonb_build_object('caisse', v_caisse - v_salaire);
  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || coalesce(v_ref->>'nom', p_reference_id)
              || ' (' || v_lots || ' lot(s), ' || v_quantite || ' unites) — ' || v_nom_pj, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  UPDATE public.personnages_donnees
     SET pa      = v_pa - v_pa_requis,
         arg     = COALESCE(arg, 0)     + v_salaire,
         liquide = COALESCE(liquide, 0) + v_salaire,
         updated_at = now()
   WHERE name = v_nom_pj;

  -- UNE COMMANDE, UNE PREUVE. Les grandeurs inscrites sont celles de la commande
  -- entiere : c'est ce qui a reellement ete consomme et produit.
  INSERT INTO public.productions_references
    (requete, fonds_id, reference_id, generique_id, recette_id, acteur,
     quantite, pa, matieres, cout_matieres, cout_lot, cout_unitaire)
  VALUES (p_requete, p_fonds_id, p_reference_id, v_r.generique_id, v_r.id, p_acteur,
     v_quantite, v_pa_requis, v_conso, v_mat, v_cout_lot, v_unit);

  RETURN jsonb_build_object('ok', true, 'rejeu', false,
    'referenceId', p_reference_id, 'recette', v_r.id, 'generique', v_r.generique_id,
    'lots', v_lots, 'rendementLot', v_r.portions,
    'quantite', v_quantite, 'stockAvant', v_stock_avant, 'stockApres', v_stock_avant + v_quantite,
    'paPreleves', v_pa_requis, 'paRestants', v_pa - v_pa_requis,
    'salaire', v_salaire, 'caisse', v_caisse - v_salaire,
    'coutMatieres', v_mat, 'coutLot', v_cout_lot, 'coutUnitaireLot', v_unit,
    'cmupAvant', v_cmup_avant, 'cmupApres', v_cmup_apres,
    'matieresConsommees', v_conso);
END; $fn$;

comment on function public.fonds_reference_produire_lots(text,text,text,text,integer) is
  'Fabrique de 1 a 99 lots d''une reference PJ en UNE transaction. Ouverte a tout joueur physiquement present : le commerce fournit ses matieres et paie 50 FR par PA depense, le producteur fournit ses PA, le produit va au stock du commerce. La commande est indivisible comme le rendement : PA, matieres, stock maximum ou caisse insuffisants pour le TOTAL refusent la commande entiere avant la premiere ecriture -- jamais de demi-production. Idempotente par cle de requete, et laisse une seule ligne de preuve aux grandeurs agregees.';

revoke all on function public.fonds_reference_produire_lots(text,text,text,text,integer) from public, anon, authenticated;
grant execute on function public.fonds_reference_produire_lots(text,text,text,text,integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. L'ANCIENNE PORTE — UN RELAIS, PLUS UNE COPIE
-- ---------------------------------------------------------------------------
-- Meme nom, memes quatre arguments, meme comportement exact : le parcours
-- visiteur et les bancs C6 n'ont rien a savoir de ce lot. Ce qui disparait,
-- c'est la SECONDE implementation de l'economie de la production.
create or replace function public.fonds_reference_produire(
  p_requete text, p_acteur text, p_fonds_id text, p_reference_id text)
returns jsonb
language sql
security definer
set search_path to 'public'
as $fn$
  SELECT public.fonds_reference_produire_lots(p_requete, p_acteur, p_fonds_id, p_reference_id, 1);
$fn$;

comment on function public.fonds_reference_produire(text,text,text,text) is
  'Fabrique UN lot d''une reference PJ. Relais vers fonds_reference_produire_lots(..., 1) : toute l''economie de la production vit desormais la-bas, et cette porte-ci existe pour le parcours visiteur et les appels historiques, a comportement identique.';

revoke all on function public.fonds_reference_produire(text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_produire(text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. AUCUNE SURCHARGE — LA VERIFICATION QUI MANQUAIT A UN AUTRE CHANTIER
-- ---------------------------------------------------------------------------
-- Deux noms distincts, une signature chacun. Si ce compte devient superieur a 1
-- un jour, PostgREST repondra 42725 sur le parcours public.
do $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'fonds_reference_produire';
  IF n <> 1 THEN RAISE EXCEPTION 'surcharge de fonds_reference_produire : % signatures', n; END IF;
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'fonds_reference_produire_lots';
  IF n <> 1 THEN RAISE EXCEPTION 'surcharge de fonds_reference_produire_lots : % signatures', n; END IF;
END $$;
