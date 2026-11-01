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

-- acheter_a_entrepot(text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_a_entrepot(p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_entrepot jsonb; v_stock jsonb; v_reserve jsonb; v_prix_manuel jsonb;
  v_cle text; v_qte int; v_dispo numeric; v_prix numeric;
  v_total numeric := 0; v_lignes jsonb := '[]'::jsonb;
  v_inv jsonb; v_occupe int; v_place int; v_ajoute int;
  v_liquide numeric; v_arg numeric; v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric; v_paye numeric := 0;
  v_idx int; v_ligne jsonb; v_existe boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : achat de matieres a l'Entrepot logistique.
  -- Tout le panier est examine : une seule matiere interdite suffit a refuser,
  -- avant le moindre debit et avant la moindre entree en inventaire.
  IF public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, 'achat') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, 'achat');
  END IF;
  IF p_achats IS NULL OR jsonb_typeof(p_achats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'achats_absents');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat
  FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable', 'id', v_id);
  END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_stock := coalesce(v_entrepot->'stock', '{}'::jsonb);
  v_reserve := coalesce(v_entrepot->'reserveMilitaire', '{}'::jsonb);
  v_prix_manuel := coalesce(v_entrepot->'prixManuel', '{}'::jsonb);

  -- Inventaire et fonds du joueur, sous verrou.
  SELECT coalesce(inventory, '[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  -- Place restante : la regle universelle (30/10/2026), comme la Criee, l'usine,
  -- la manufacture et inventaire_deposer_interne. L'ancien calcul local ignorait
  -- la quantite des piles a `quantite` (tracts) : 87 bois livres pour 86 places.
  v_place := public.inventaire_place_restante(v_inv);

  -- Premiere passe : validation. Aucune mutation avant d'etre sur de tout.
  FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::int FROM jsonb_each(p_achats)
  LOOP
    IF v_qte IS NULL OR v_qte <= 0 THEN CONTINUE; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    -- Stock CIVIL disponible = stock physique moins la reserve militaire.
    v_dispo := greatest(0, coalesce((v_stock->>v_cle)::numeric, 0)
                          - coalesce((v_reserve->>v_cle)::numeric, 0));
    IF v_qte > v_dispo THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                                'cle', v_cle, 'disponible', v_dispo);
    END IF;
    SELECT coalesce((v_prix_manuel->>v_cle)::numeric, r.prix_base) INTO v_prix
    FROM public.ressources_economie r WHERE r.cle = v_cle;
    v_total := v_total + v_qte * v_prix;
    v_lignes := v_lignes || jsonb_build_object('cle', v_cle, 'qte', v_qte, 'prix', v_prix);
  END LOOP;

  IF jsonb_array_length(v_lignes) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_acheter');
  END IF;
  IF v_liquide + v_solde < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'requis', v_total, 'disponible', v_liquide + v_solde);
  END IF;

  -- Seconde passe : application. Comme cote client, un lot empilable peut entrer
  -- PARTIELLEMENT si la place manque, et seul ce qui entre est paye.
  FOR v_idx IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes -> v_idx;
    v_cle := v_ligne->>'cle';
    v_ajoute := least((v_ligne->>'qte')::int, v_place);
    IF v_ajoute <= 0 THEN CONTINUE; END IF;
    v_place := v_place - v_ajoute;
    v_paye := v_paye + v_ajoute * (v_ligne->>'prix')::numeric;

    SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e
                   WHERE e->>'stackKey' = v_cle) INTO v_existe;
    IF v_existe THEN
      SELECT jsonb_agg(CASE WHEN e->>'stackKey' = v_cle
                            THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) + v_ajoute))
                            ELSE e END)
        INTO v_inv FROM jsonb_array_elements(v_inv) e;
    ELSE
      v_inv := v_inv || jsonb_build_array(jsonb_build_object(
        'name', (SELECT cle FROM public.ressources_economie WHERE cle = v_cle),
        'stackable', true, 'stackKey', v_cle, 'qty', v_ajoute,
        'desc', 'Ressource achetée à l''entrepôt logistique.'));
    END IF;

    v_stock := jsonb_set(v_stock, ARRAY[v_cle],
                         to_jsonb(coalesce((v_stock->>v_cle)::numeric,0) - v_ajoute));
  END LOOP;

  IF v_paye <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- Debit : liquide d'abord, Banque nationale en complement (regle inchangee).
  v_pris_liquide := least(v_liquide, v_paye);
  v_pris_national := v_paye - v_pris_liquide;
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pris_liquide, arg = v_arg - v_paye
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now()
     WHERE id = v_compte_id;
  END IF;

  -- Le produit de la vente revient a la caisse de l'entrepot : sans quoi l'argent
  -- paye par le joueur disparaitrait sans contrepartie.
  v_entrepot := v_entrepot || jsonb_build_object('stock', v_stock,
                  'caisse', coalesce((v_entrepot->>'caisse')::numeric, 0) + v_paye);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', v_entrepot))::text),
         updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'paye', v_paye, 'lignes', v_lignes,
    'inventory', v_inv, 'liquide', v_liquide - v_pris_liquide, 'arg', v_arg - v_paye,
    'solde_national', v_solde - v_pris_national,
    'caisse_entrepot', (v_entrepot->>'caisse')::numeric);
END;
$function$;

-- acheter_a_entrepot(uuid,text,text,text,text,jsonb,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_a_entrepot(p_requete uuid, p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'ville', p_ville, 'batiment', p_batiment, 'achats', p_achats, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_a_entrepot', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.payer_ordre(p_acteur, 'acheter_ressources_entrepot', p_pa, p_cost);
    IF (v->>'ok')::boolean IS TRUE THEN v := public.acheter_a_entrepot(p_acteur, p_pays, p_ville, p_batiment, p_achats); END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_a_entrepot', prm, v);
END; $function$;

-- acheter_a_la_criee(text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_a_la_criee(p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_port jsonb; v_criee jsonb; v_stock jsonb;
  v_cle text; v_qte int; v_dispo numeric; v_prix numeric;
  v_total numeric := 0; v_lignes jsonb := '[]'::jsonb;
  v_inv jsonb; v_place int; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_paye numeric := 0; v_idx int; v_ligne jsonb; v_ajoute int; v_caisse_id text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : achat de matieres a la criee du port.
  -- Tout le panier est examine : une seule matiere interdite suffit a refuser,
  -- avant le moindre debit et avant la moindre entree en inventaire.
  IF public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, 'achat') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, 'achat');
  END IF;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_introuvable'); END IF;
  v_port := coalesce(v_etat->'port', '{}'::jsonb);
  v_criee := coalesce(v_port->'criee', '{}'::jsonb);
  v_stock := coalesce(v_criee->'stock', '{}'::jsonb);

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  v_place := public.inventaire_place_restante(v_inv);

  FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::int FROM jsonb_each(p_achats) LOOP
    IF v_qte IS NULL OR v_qte <= 0 THEN CONTINUE; END IF;
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle); END IF;
    v_dispo := coalesce((v_stock->>v_cle)::numeric, 0);
    IF v_qte > v_dispo THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'cle', v_cle, 'disponible', v_dispo);
    END IF;
    v_total := v_total + v_qte * v_prix;
    v_lignes := v_lignes || jsonb_build_object('cle', v_cle, 'qte', v_qte, 'prix', v_prix);
  END LOOP;
  IF jsonb_array_length(v_lignes) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_acheter'); END IF;
  IF v_liquide + v_solde < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                              'disponible', v_liquide + v_solde);
  END IF;

  FOR v_idx IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes -> v_idx; v_cle := v_ligne->>'cle';
    v_ajoute := least((v_ligne->>'qte')::int, v_place);
    IF v_ajoute <= 0 THEN CONTINUE; END IF;
    v_place := v_place - v_ajoute;
    v_paye := v_paye + v_ajoute * (v_ligne->>'prix')::numeric;
    v_inv := public.inventaire_ajouter(v_inv, v_cle, v_ajoute,
               'Marchandise achetée à la Criée du Port de Port-Sainte-Marie.');
    v_stock := jsonb_set(v_stock, ARRAY[v_cle], to_jsonb(coalesce((v_stock->>v_cle)::numeric,0) - v_ajoute));
  END LOOP;
  IF v_paye <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;

  v_pris_liquide := least(v_liquide, v_paye);
  v_pris_national := v_paye - v_pris_liquide;
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pris_liquide, arg = v_arg - v_paye
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('port',
           v_port || jsonb_build_object('criee', v_criee || jsonb_build_object('stock', v_stock))))::text),
         updated_at = now()
   WHERE id = v_id;

  -- Le produit va a la caisse du port, comme avant (crediterCaisseBatiment).
  v_caisse_id := p_pays || '_' || p_batiment;
  UPDATE public.caisses_batiments
     SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}',
                to_jsonb(coalesce((data->>'solde')::numeric,0) + v_paye)), updated_at = now()
   WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data) VALUES (v_caisse_id, jsonb_build_object('solde', v_paye))
    ON CONFLICT (id) DO UPDATE SET data = jsonb_set(coalesce(public.caisses_batiments.data,'{}'::jsonb),
      '{solde}', to_jsonb(coalesce((public.caisses_batiments.data->>'solde')::numeric,0) + v_paye));
  END IF;

  RETURN jsonb_build_object('ok', true, 'paye', v_paye, 'lignes', v_lignes, 'inventory', v_inv,
    'liquide', v_liquide - v_pris_liquide, 'arg', v_arg - v_paye, 'solde_national', v_solde - v_pris_national);
END; $function$;

-- acheter_a_la_criee(uuid,text,text,text,text,jsonb,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_a_la_criee(p_requete uuid, p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'ville', p_ville, 'batiment', p_batiment, 'achats', p_achats, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_a_la_criee', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.payer_ordre(p_acteur, 'acheter_criee', p_pa, p_cost);
    IF (v->>'ok')::boolean IS TRUE THEN v := public.acheter_a_la_criee(p_acteur, p_pays, p_ville, p_batiment, p_achats); END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_a_la_criee', prm, v);
END; $function$;

-- acheter_produit_commerce(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_produit_commerce(p_requete text, p_acheteur text, p_fonds_id text, p_reference_id text, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r boolean;
BEGIN
 SELECT coalesce((data->'references'->p_reference_id->>'venteSurPlaceUniquement')::boolean,false)
 INTO r FROM public.entreprises WHERE id=p_fonds_id;
 IF r IS TRUE THEN RETURN jsonb_build_object('ok',false,'raison','consommation_sur_place_uniquement');END IF;
 RETURN public.acheter_produit_commerce_interne(p_requete,p_acheteur,p_fonds_id,p_reference_id,p_quantite);
END $function$;

-- acheter_produit_commerce_interne(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.acheter_produit_commerce_interne(p_requete text, p_acheteur text, p_fonds_id text, p_reference_id text, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_fonds       jsonb;
  v_ref         jsonb;
  v_gen         record;
  v_acces       record;
  v_var_id      text := null;
  v_var_libelle text := null;
  v_prix        integer;
  v_stock       integer;
  v_veut        integer := GREATEST(0, COALESCE(p_quantite, 0));
  v_qte         integer;
  v_montant     integer;
  v_taxe        jsonb;
  v_net         numeric;
  v_arg         numeric;
  v_cout        jsonb;
  v_objet       jsonb;
  v_livre       jsonb;
  v_fiche       jsonb;
  v_ids         text[] := '{}';
  v_id          text;
  v_destinataire text;
  v_enseigne    text;
  v_types       jsonb;
  v_deja        record;
  i             integer;
BEGIN
  PERFORM public.exiger_acteur(p_acheteur);

  IF p_requete IS NULL OR p_requete !~ '^achat-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF COALESCE(p_acheteur,'') = '' OR COALESCE(p_fonds_id,'') = ''
     OR COALESCE(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  SELECT * INTO v_deja FROM public.ventes_snapshots WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'venteId', v_deja.id, 'quantite', v_deja.quantite,
                              'montant', v_deja.montant_total);
  END IF;

  IF NOT public.mouvement_titulaire(p_acheteur, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;

  SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE((v_fonds->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj');
  END IF;
  IF COALESCE(v_fonds->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;

  -- PRESENCE PHYSIQUE (C6). On n'achete que dans la boutique ou l'on se tient.
  -- Sans cette regle il n'y a ni transport, ni ecart de prix entre villes, ni
  -- penurie : toute l'economie materielle du jeu repose dessus.
  IF NOT public.fonds_acteur_present(p_acheteur, v_fonds->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_ref := v_fonds->'references'->p_reference_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;
  IF COALESCE((v_ref->>'active')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_inactive');
  END IF;
  v_prix  := GREATEST(0, COALESCE((v_ref->>'prixVente')::numeric, 0))::integer;
  v_stock := GREATEST(0, COALESCE((v_fonds->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  IF v_prix <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe');
  END IF;
  IF v_stock <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rupture_de_stock');
  END IF;

  IF COALESCE(v_ref->>'generique_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_generique');
  END IF;
  SELECT g.id, g.libelle, g.regime, g.est_service, g.empilable, g.individualise,
         g.encombrement, g.famille_id
    INTO v_gen
    FROM public.catalogue_generiques g
   WHERE g.id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_inconnu');
  END IF;
  IF v_gen.est_service THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_est_un_service');
  END IF;
  IF NOT v_gen.individualise AND NOT v_gen.empilable
     AND coalesce(current_setting('hg.consommation_sur_place', true), '') <> 'on' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_regime_indetermine');
  END IF;

  SELECT * INTO v_acces FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_gen.id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_gen.id);
  END IF;

  IF COALESCE(v_ref->>'recette_id','') <> '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.recettes_commerce
                    WHERE id = v_ref->>'recette_id' AND generique_id = v_gen.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                                'recette', v_ref->>'recette_id', 'generique', v_gen.id);
    END IF;
  END IF;

  IF COALESCE(v_ref->>'variante_id','') <> '' THEN
    SELECT v.id, v.libelle INTO v_var_id, v_var_libelle
      FROM public.catalogue_variantes v
     WHERE v.id = v_ref->>'variante_id' AND v.generique_id = v_gen.id;
    IF v_var_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'variante_incoherente');
    END IF;
  END IF;

  -- REVALIDATION DU PRIX contre le cout du STOCK REELLEMENT DETENU
  v_cout := public.fonds_cout_revient_reference(p_fonds_id, p_reference_id);
  IF (v_cout->>'disponible')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_de_revient_indisponible',
                              'detail', v_cout);
  END IF;
  IF v_prix > (v_cout->>'prixMaximum')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_devenu_hors_plafond',
                              'prix', v_prix, 'maximum', (v_cout->>'prixMaximum')::numeric,
                              'coutUnitaire', (v_cout->>'coutUnitaire')::numeric,
                              'coefficient', (v_cout->>'coefficient')::numeric);
  END IF;

  IF left(p_acheteur, 5) = 'orga:' THEN
    SELECT GREATEST(0, COALESCE((data::jsonb->>'caisse')::numeric, 0)) INTO v_arg
      FROM public.organisations WHERE id = substr(p_acheteur, 6);
  ELSE
    SELECT COALESCE(arg, 0) INTO v_arg FROM public.personnages
     WHERE name = CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  END IF;
  IF v_arg IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;
  IF v_veut > v_stock THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                              'demande', v_veut, 'stock', v_stock);
  END IF;
  v_qte := v_veut;
  v_montant := v_qte * v_prix;
  IF v_arg < v_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'requis', v_montant, 'disponibles', v_arg);
  END IF;

  v_destinataire := CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  v_enseigne     := COALESCE(NULLIF(btrim(v_fonds->>'enseigne'), ''), 'Commerce');
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'type',         p_reference_id,
    'generique_id', v_gen.id,
    'recette_id',   NULLIF(btrim(COALESCE(v_ref->>'recette_id','')), ''),
    'variante_id',  v_var_id,
    'name',         COALESCE(NULLIF(btrim(v_ref->>'nom'), ''),
                             COALESCE(v_var_libelle, v_gen.libelle)),
    'desc',         NULLIF(btrim(v_ref->>'description'), ''),
    'icon',         'ti-package',
    'imageUrl',     NULLIF(btrim(v_ref->>'image'), ''),
    'legal',        CASE WHEN v_gen.regime = 'illegal' THEN false ELSE true END,
    'familleProduitMarche', CASE WHEN v_ref->>'recette_id' IS NOT NULL AND v_gen.id IN ('encas-a-emporter', 'encas', 'plat-simple', 'plat-elabore', 'menu-gastronomique', 'aliment-prepare') THEN 'aliment' ELSE NULL END,
    'dateAchat', CASE WHEN v_ref->>'recette_id' IS NOT NULL AND v_gen.id IN ('encas-a-emporter', 'encas', 'plat-simple', 'plat-elabore', 'menu-gastronomique', 'aliment-prepare') THEN floor(extract(epoch from clock_timestamp())*1000)::bigint ELSE NULL END,
    'provenance',   jsonb_build_object(
                      'fondsId',     p_fonds_id,
                      'referenceId', p_reference_id,
                      'createur',    v_fonds->>'proprietaire',
                      'etapes',      '[]'::jsonb)
  ));

  IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  IF v_gen.individualise THEN
    FOR i IN 1..v_qte LOOP
      v_id := p_requete || '-' || i;
      v_livre := v_objet
                 || jsonb_build_object('qty', 1)
                 || CASE WHEN v_gen.encombrement IS NOT NULL
                         THEN jsonb_build_object('encombrement', v_gen.encombrement)
                         ELSE '{}'::jsonb END
                 || jsonb_build_object('exemplaire', jsonb_build_object('id', v_id));
      INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
      VALUES (v_id, v_destinataire, v_enseigne, to_jsonb(v_livre::text))
      ON CONFLICT (id) DO NOTHING;
      v_ids := v_ids || v_id;
    END LOOP;
  ELSE
    v_id    := p_requete;
    v_livre := v_objet || jsonb_build_object(
                 'stackable', true, 'stackKey', p_reference_id, 'qty', v_qte);
    INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
    VALUES (v_id, v_destinataire, v_enseigne, to_jsonb(v_livre::text))
    ON CONFLICT (id) DO NOTHING;
    v_ids := v_ids || v_id;
  END IF;

  -- HG debit deplace avant livraison (20261016070541).

  -- LA VENTE FAIT BAISSER LA QUANTITE, JAMAIS LE COUT MOYEN.
  v_fonds := jsonb_set(v_fonds, ARRAY['stockReferences', p_reference_id],
               to_jsonb(v_stock - v_qte), true);
  IF (v_stock - v_qte) <= 0 THEN
    v_fonds := jsonb_set(v_fonds, '{coutMoyenReferences}',
                 coalesce(v_fonds->'coutMoyenReferences', '{}'::jsonb) - p_reference_id, true);
  END IF;
  -- FISCALITE (C6). La vente d'un commerce PJ est soumise a la fiscalite
  -- commerciale COMMUNE, celle qu'applique deja commerce_vendre_produit. Le
  -- moteur ne connait aucun taux : appliquer_taxe_transaction lit le taux LOCAL
  -- dans budgets_municipaux et le taux NATIONAL dans budgets_nationaux -- la
  -- couche pays/ville est donc en donnees, pas en code. Le commerce encaisse le
  -- NET, l'acheteur paie le prix affiche. Meme transaction que la vente : si le
  -- prelevement echoue, la vente entiere est annulee, jamais l'inverse.
  v_taxe := public.appliquer_taxe_transaction(
              v_fonds->'implantation'->>'country',
              v_fonds->'implantation'->>'city',
              v_montant);
  v_net  := COALESCE((v_taxe->>'net')::numeric, v_montant);
  v_fonds := jsonb_set(v_fonds, '{caisse}',
               to_jsonb(GREATEST(0, COALESCE((v_fonds->>'caisse')::numeric, 0)) + v_net));
  UPDATE public.entreprises SET data = v_fonds, updated_at = now() WHERE id = p_fonds_id;

  v_fiche := public.objet_fiche_officielle(v_livre);
  SELECT jsonb_agg(ty.libelle ORDER BY ty.ordre) INTO v_types
    FROM public.catalogue_generique_type gt
    JOIN public.catalogue_types ty ON ty.id = gt.type_id
   WHERE gt.generique_id = v_gen.id;

  INSERT INTO public.ventes_snapshots
    (requete, jour_paris, acheteur, vendeur, fonds_id, pays,
     reference_id, nom_commercial, description_commerciale,
     generique_id, recette_id, variante_id, famille, types,
     quantite, prix_unitaire, montant_total, fiche_officielle)
  VALUES (p_requete,
     to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD'),
     p_acheteur, v_fonds->>'proprietaire', p_fonds_id, v_fonds->'implantation'->>'country',
     p_reference_id,
     COALESCE(NULLIF(btrim(v_ref->>'nom'), ''), COALESCE(v_var_libelle, v_gen.libelle)),
     NULLIF(btrim(v_ref->>'description'), ''),
     v_gen.id, NULLIF(btrim(COALESCE(v_ref->>'recette_id','')), ''), v_var_id,
     v_acces.famille, v_types,
     v_qte, v_prix, v_montant, v_fiche);

  RETURN jsonb_build_object(
    'ok', true, 'rejeu', false,
    'quantite', v_qte, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stockRestant', v_stock - v_qte,
    'coutUnitaireStock', (v_cout->>'coutUnitaire')::numeric,
    'generique_id', v_gen.id, 'recette_id', v_ref->>'recette_id', 'variante_id', v_var_id,
    'livraisons', to_jsonb(v_ids),
    'venteId', (SELECT id FROM public.ventes_snapshots WHERE requete = p_requete),
    'net', v_net, 'taxeLocale', (v_taxe->>'taxeLocale')::numeric,
    'taxeNationale', (v_taxe->>'taxeNationale')::numeric);
END;
$function$;

-- acheter_produit_manufacture(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_produit_manufacture(p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ville text; v_bat text; v_prix numeric; v_enc int; v_id text;
  v_etat jsonb; v_usine jsonb; v_sp jsonb; v_stock numeric;
  v_inv jsonb; v_place int; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pl numeric; v_pn numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, prix_vente, encombrement INTO v_ville, v_bat, v_prix, v_enc
  FROM public.produits_manufactures WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sp := coalesce(v_usine->'stockProduits', '{}'::jsonb);
  v_stock := coalesce((v_sp->>p_produit)::numeric, 0);
  IF v_stock <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock'); END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_place := public.inventaire_place_restante(v_inv);
  -- Un objet non empilable a encombrement > 1 est refuse EN BLOC, jamais partiellement.
  IF v_place < v_enc THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_insuffisant', 'encombrement', v_enc);
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  IF v_liquide + v_solde < v_prix THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_prix,
                              'disponible', v_liquide + v_solde);
  END IF;
  v_pl := least(v_liquide, v_prix); v_pn := v_prix - v_pl;

  v_sp := jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(v_stock - 1));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('stockProduits', v_sp,
             'caisse', coalesce((v_usine->>'caisse')::numeric,0) + v_prix)))::text), updated_at = now()
   WHERE id = v_id;

  v_inv := v_inv || jsonb_build_array(jsonb_build_object(
    'type', p_produit, 'name', p_produit, 'encombrement', v_enc,
    'desc', 'Acheté à l''atelier.'));
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pl, arg = v_arg - v_prix
   WHERE name = p_acteur;
  IF v_pn > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pn, updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'inventory', v_inv,
    'liquide', v_liquide - v_pl, 'arg', v_arg - v_prix, 'solde_national', v_solde - v_pn);
END; $function$;

-- acheter_produit_manufacture(uuid,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_produit_manufacture(p_requete uuid, p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'produit', p_produit);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_produit_manufacture', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.acheter_produit_manufacture(p_acteur, p_pays, p_produit);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_produit_manufacture', prm, v);
END; $function$;

-- acheter_vente_directe_usine(text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_vente_directe_usine(p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_usine jsonb; v_vd jsonb; v_prix_manuel jsonb;
  v_cle text; v_qte int; v_stock numeric; v_prix numeric;
  v_total numeric := 0; v_lignes jsonb := '[]'::jsonb;
  v_inv jsonb; v_place int; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_paye numeric := 0; v_idx int; v_ligne jsonb; v_ajoute int;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_achats IS NULL OR jsonb_typeof(p_achats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'achats_absents');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat
  FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_vd := coalesce(v_usine->'venteDirecte', '{}'::jsonb);
  v_prix_manuel := coalesce(v_usine->'prixManuel', '{}'::jsonb);

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  v_place := public.inventaire_place_restante(v_inv);

  FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::int FROM jsonb_each(p_achats) LOOP
    IF v_qte IS NULL OR v_qte <= 0 THEN CONTINUE; END IF;
    v_stock := coalesce((v_vd->>v_cle)::numeric, 0);
    IF v_qte > v_stock THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'cle', v_cle, 'disponible', v_stock);
    END IF;
    -- Prix : celui du directeur s'il en a fixe un, sinon le prix variable selon
    -- le remplissage -- exactement getPrixRessource(cle, enStock).
    v_prix := coalesce((v_prix_manuel->>v_cle)::numeric, public.prix_ressource_selon_stock(v_cle, v_stock));
    IF v_prix IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    v_total := v_total + v_qte * v_prix;
    v_lignes := v_lignes || jsonb_build_object('cle', v_cle, 'qte', v_qte, 'prix', v_prix);
  END LOOP;

  IF jsonb_array_length(v_lignes) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_acheter'); END IF;
  IF v_liquide + v_solde < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                              'disponible', v_liquide + v_solde);
  END IF;

  FOR v_idx IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes -> v_idx; v_cle := v_ligne->>'cle';
    v_ajoute := least((v_ligne->>'qte')::int, v_place);
    IF v_ajoute <= 0 THEN CONTINUE; END IF;
    v_place := v_place - v_ajoute;
    v_paye := v_paye + v_ajoute * (v_ligne->>'prix')::numeric;
    v_inv := public.inventaire_ajouter(v_inv, v_cle, v_ajoute, 'Produit acheté en vente directe.');
    v_vd := jsonb_set(v_vd, ARRAY[v_cle], to_jsonb(coalesce((v_vd->>v_cle)::numeric,0) - v_ajoute));
  END LOOP;
  IF v_paye <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;

  v_pris_liquide := least(v_liquide, v_paye);
  v_pris_national := v_paye - v_pris_liquide;
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pris_liquide, arg = v_arg - v_paye
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  v_usine := v_usine || jsonb_build_object('venteDirecte', v_vd,
               'caisse', coalesce((v_usine->>'caisse')::numeric,0) + v_paye);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'paye', v_paye, 'lignes', v_lignes, 'inventory', v_inv,
    'liquide', v_liquide - v_pris_liquide, 'arg', v_arg - v_paye,
    'solde_national', v_solde - v_pris_national, 'caisse_usine', (v_usine->>'caisse')::numeric);
END; $function$;

-- acheter_vente_directe_usine(uuid,text,text,text,text,jsonb,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acheter_vente_directe_usine(p_requete uuid, p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'ville', p_ville, 'batiment', p_batiment, 'achats', p_achats, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_vente_directe_usine', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.payer_ordre(p_acteur, 'vente_directe_usine', p_pa, p_cost);
    IF (v->>'ok')::boolean IS TRUE THEN v := public.acheter_vente_directe_usine(p_acteur, p_pays, p_ville, p_batiment, p_achats); END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_vente_directe_usine', prm, v);
END; $function$;

-- approvisionner_chantier(text,text,text,text,jsonb,jsonb,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.approvisionner_chantier(p_acteur text, p_pays text, p_ville text, p_entrepot text, p_besoin jsonb, p_stock_chantier jsonb, p_tresorerie numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_entrepot;
  v_etat jsonb; v_entrepot jsonb; v_stock jsonb; v_reserve jsonb;
  v_cle text; v_en_chantier numeric; v_manque numeric; v_prix numeric;
  v_present numeric; v_reserve_m numeric; v_dispo numeric; v_abordable numeric; v_qte numeric;
  v_achats jsonb := '{}'::jsonb; v_nouveau_chantier jsonb := '{}'::jsonb;
  v_depense numeric := 0; v_recette jsonb; v_ancien_flag text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'depense', 0, 'achats', '{}'::jsonb,
                              'stockChantier', coalesce(p_stock_chantier,'{}'::jsonb));
  END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_stock := coalesce(v_entrepot->'stock', '{}'::jsonb);
  v_reserve := coalesce(v_entrepot->'reserveMilitaire', '{}'::jsonb);

  -- Meme boucle, dans le meme ordre, sur les memes trois materiaux.
  FOREACH v_cle IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    v_en_chantier := greatest(0, coalesce((p_stock_chantier->>v_cle)::numeric, 0));
    v_nouveau_chantier := jsonb_set(v_nouveau_chantier, ARRAY[v_cle], to_jsonb(v_en_chantier));
    v_manque := greatest(0, greatest(0, coalesce((p_besoin->>v_cle)::numeric, 0)) - v_en_chantier);
    CONTINUE WHEN v_manque <= 0;
    -- Le PRIX vient du miroir, jamais du client.
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    CONTINUE WHEN v_prix IS NULL OR v_prix <= 0;
    v_present := greatest(0, floor(coalesce((v_stock->>v_cle)::numeric, 0)));
    v_reserve_m := greatest(0, floor(coalesce((v_reserve->>v_cle)::numeric, 0)));
    v_dispo := greatest(0, v_present - v_reserve_m);     -- reserve militaire opposable
    v_abordable := floor(greatest(0, coalesce(p_tresorerie,0) - v_depense) / v_prix);
    v_qte := least(v_manque, v_dispo, v_abordable);
    CONTINUE WHEN v_qte <= 0;
    v_achats := jsonb_set(v_achats, ARRAY[v_cle], to_jsonb(v_qte));
    v_depense := v_depense + v_qte * v_prix;
    v_nouveau_chantier := jsonb_set(v_nouveau_chantier, ARRAY[v_cle], to_jsonb(v_en_chantier + v_qte));
    -- On debite le stock PHYSIQUE, jamais la vue « disponible ».
    v_stock := jsonb_set(v_stock, ARRAY[v_cle], to_jsonb(v_present - v_qte));
  END LOOP;

  IF v_depense > 0 THEN
    v_ancien_flag:=current_setting('rp.caisse_interne',true);
    PERFORM set_config('rp.caisse_interne','on',true);
    v_recette:=public.caisse_institution_mouvement(public.entrepot_caisse_id(v_id),v_depense,true);
    PERFORM set_config('rp.caisse_interne',coalesce(v_ancien_flag,''),true);
    IF NOT coalesce((v_recette->>'ok')::boolean,false) THEN
      RAISE EXCEPTION 'recette_entrepot_non_confirmee';END IF;
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
             (v_entrepot-'caisse') || jsonb_build_object('stock', v_stock)))::text),
           updated_at = now()
     WHERE id = v_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'depense', v_depense,
                            'stockChantier', v_nouveau_chantier);
END; $function$;

-- arme_acheter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.arme_acheter(p_entreprise text, p_arme text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_objet jsonb; v_r jsonb; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_objet := public.arme_modele_interne(p_entreprise, p_arme, v_moi);
  IF v_objet IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose'); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_r := public.commerce_vendre_produit_interne(v_moi, p_entreprise, jsonb_build_array(jsonb_build_object('produit', p_arme, 'qte', 1)),
           'comptoir', 'choisir_arme', 1, 0, NULL, NULL);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_dep := public.inventaire_deposer_interne(v_moi, v_objet || jsonb_build_object('legal', true));
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'arme_acheter: depot refuse %', v_dep; END IF;
  RETURN v_r || (v_dep - 'ok' - 'qte') || jsonb_build_object('objet', v_objet ->> 'name');
END; $function$;

-- arme_acheter(uuid,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.arme_acheter(p_requete uuid, p_entreprise text, p_arme text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('entreprise', p_entreprise, 'arme', p_arme);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'arme_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.arme_acheter(p_entreprise, p_arme);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'arme_acheter', prm, v);
END; $function$;

-- arme_modele_interne(text,text,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.arme_modele_interne(p_entreprise text, p_arme text, p_acteur text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ WITH e AS (SELECT coalesce(en.data ->> 'country', (SELECT country FROM public.personnages_donnees WHERE name = p_acteur), 'republic') AS pays,
                        coalesce(en.data ->> 'city', (SELECT current_city FROM public.personnages_donnees WHERE name = p_acteur)) AS ville
                   FROM public.entreprises en WHERE en.id = p_entreprise)
      SELECT coalesce((SELECT objet FROM public.objets_modeles, e WHERE id = 'arme:' || e.pays || ':' || p_arme || ':' || e.ville),
                      (SELECT objet FROM public.objets_modeles, e WHERE id = 'arme:' || e.pays || ':' || p_arme)) $function$;

-- capacite_entrepot() -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.capacite_entrepot()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT 5000; $function$;

-- chantier_appel_fonds_interne(jsonb,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_appel_fonds_interne(p_chantier jsonb, p_source jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ch jsonb:=p_chantier;p numeric;d numeric;t numeric;verse numeric;cible numeric;m numeric;mail jsonb;evenement text;
BEGIN
 p:=(ch->>'progressionJours')::numeric;d:=(ch->>'dureeJours')::numeric;t:=(ch->>'coutTotal')::numeric;
 verse:=(ch->>'totalVerse')::numeric;
 IF p IS NULL OR d IS NULL OR d<=0 OR t IS NULL OR t<=0 OR verse IS NULL OR verse<0 THEN RAISE EXCEPTION 'dimensionnement_chantier_invalide';END IF;
 cible:=ceil(t*CASE WHEN p>=d*2/3 THEN 1 WHEN p>=d/3 THEN .70 ELSE .35 END);
 m:=greatest(0,cible-verse);
 IF m=0 THEN
  IF ch->>'arrete'='financement' THEN ch:=ch||jsonb_build_object('arrete',null,'appelFondsManquant',null);END IF;
  RETURN ch;END IF;
 IF public.chantier_financeur_debiter_interne(p_source,m) THEN
  ch:=ch||jsonb_build_object('totalVerse',verse+m,'tresorerie',coalesce((ch->>'tresorerie')::numeric,0)+m,'arrete',null,'appelFondsManquant',null);
  evenement:='appel_fonds_paye';
 ELSE
  ch:=ch||jsonb_build_object('arrete','financement');
  IF ch->>'appelFondsManquant'=cible::text THEN RETURN ch;END IF;
  ch:=ch||jsonb_build_object('appelFondsManquant',cible);evenement:='appel_fonds_manquant';
 END IF;
 ch:=ch||jsonb_build_object('evenements',coalesce(ch->'evenements','[]')||jsonb_build_array(jsonb_build_object('cle',evenement,'cible',cible,'montant',m,'date',now())));
 IF nullif(p_source->>'destinataire','') IS NOT NULL THEN
  mail:=public.mail_systeme_poser_interne('Chef de Chantier',p_source->>'destinataire',CASE WHEN evenement='appel_fonds_paye' THEN 'Appel de fonds du chantier acquitte' ELSE 'Chantier en pause — financement' END,
   CASE WHEN evenement='appel_fonds_paye' THEN m||' FR preleves. Financement cumule : '||cible||' FR.' ELSE 'Il manque '||m||' FR. Aucun debit partiel. Le chantier reprendra automatiquement lorsque les fonds seront disponibles.' END);
  IF NOT coalesce((mail->>'ok')::boolean,false) THEN ch:=ch||jsonb_build_object('notificationEchec',mail);END IF;
 END IF;
 RETURN ch;
END;$function$;

-- chantier_approvisionner(text,text,text,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_approvisionner(p_terrain_id text, p_cle_chantier text, p_entrepot text, p_besoin jsonb, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_cle text; v_data jsonb; v_ch jsonb; v_pays text; v_ville text;
  v_plan jsonb; v_dep numeric; v_evts jsonb;
BEGIN
  IF p_cle_chantier NOT IN ('chantier','chantierReamenagement') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_inconnu');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT t.id, t.data::jsonb, t.country INTO v_cle, v_data, v_pays
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable'); END IF;
  v_data := coalesce(v_data, '{}'::jsonb);

  -- SEUL LE PROPRIETAIRE APPROVISIONNE SON CHANTIER. Rien ne le verifiait.
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_terrain');
  END IF;

  v_ch := v_data -> p_cle_chantier;
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_chantier');
  END IF;
  v_ville := coalesce(nullif(v_data ->> 'city', ''), 'capitale');

  -- LE STOCK ET LA TRESORERIE VIENNENT DE LA BASE, PLUS DU NAVIGATEUR. C'est le second defaut.
  v_plan := public.approvisionner_chantier(
    v_moi, v_pays, v_ville, p_entrepot, coalesce(p_besoin, '{}'::jsonb),
    coalesce(v_ch -> 'stockMateriaux', '{}'::jsonb),
    greatest(0, coalesce((v_ch ->> 'tresorerie')::numeric, 0)));
  IF NOT coalesce((v_plan ->> 'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison',
                              coalesce(v_plan ->> 'raison','approvisionnement_refuse'));
  END IF;
  v_dep := coalesce((v_plan ->> 'depense')::numeric, 0);

  -- LA CONTREPARTIE, DANS LA MEME TRANSACTION QUE LE DEBIT DE L'ENTREPOT.
  IF v_dep > 0 THEN
    v_evts := CASE WHEN jsonb_typeof(v_ch -> 'evenements') = 'array'
                   THEN v_ch -> 'evenements' ELSE '[]'::jsonb END;
    v_evts := v_evts || jsonb_build_array(jsonb_build_object(
      'cle', 'approvisionnement', 'jour', coalesce(p_jour, 1),
      'achats', v_plan -> 'achats', 'cout', v_dep));
    v_ch := v_ch
      || jsonb_build_object('stockMateriaux', v_plan -> 'stockChantier',
           'tresorerie', greatest(0, coalesce((v_ch ->> 'tresorerie')::numeric, 0) - v_dep),
           'evenements', v_evts);
    v_data := jsonb_set(v_data, ARRAY[p_cle_chantier], v_ch, true);
    UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = v_cle;
  END IF;

  RETURN jsonb_build_object('ok', true, 'depense', v_dep, 'achats', v_plan -> 'achats',
    'cle', v_cle, 'chantier', v_ch);
END; $function$;

-- chantier_autorite_exiger_interne(text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_autorite_exiger_interne(p_titulaire text, p_pays text, p_ville text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n text:=public.mon_personnage();a record;d jsonb;
BEGIN
 IF n IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501';END IF;
 IF p_titulaire LIKE 'orga:%' THEN
  -- Reutiliser la porte de representation existante, pas la presence dans une piece.
  d:=public.organisation_equipement_exiger(substr(p_titulaire,6));
 ELSIF p_titulaire='ville:'||p_pays||':'||p_ville THEN
  SELECT * INTO a FROM public.acteur_poste_courant();
  SELECT poste INTO d FROM public.personnages_donnees WHERE name=n;
  IF a.pays IS DISTINCT FROM p_pays OR a.poste_id IS DISTINCT FROM 'maire' OR a.poste_city IS DISTINCT FROM p_ville
    OR NOT public.poste_est_atteste(n,d,p_pays) THEN RAISE EXCEPTION 'mandat_municipal_requis' USING ERRCODE='42501';END IF;
 ELSIF p_titulaire IS DISTINCT FROM n AND p_titulaire IS DISTINCT FROM 'pj:'||n THEN
  RAISE EXCEPTION 'pas_proprietaire' USING ERRCODE='42501';
 END IF;
END;$function$;

-- chantier_besoin_jour_interne(jsonb,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_besoin_jour_interne(p_ch jsonb, p_num integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r jsonb;BEGIN
 IF p_ch->>'type'='construction' THEN
  SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO r FROM public.chantiers_besoins_jour WHERE position_cycle=((p_num-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;
 ELSIF p_ch->>'type'='reamenagement' THEN
  SELECT jsonb_object_agg(cle,floor(((p_ch->>'coutMateriaux')::numeric/(p_ch->>'dureeJours')::numeric/3/prix_base))) INTO r FROM public.ressources_economie WHERE cle IN('bois','minerai','metal') AND prix_base>0;
 END IF;
 IF r IS NULL OR (SELECT count(*) FROM jsonb_object_keys(r))<>3 THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
 RETURN r;
END;$function$;

-- chantier_commande(text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_commande(p_requete text, p_terrain_id text, p_action text, p_parametres jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_variable
DECLARE acteur text:=public.mon_personnage();t record;a record;etat jsonb;ancien_etat jsonb;source jsonb;ch jsonb;pal record;rec record;commande jsonb;resultat jsonb;
 emplacement text;montant numeric;prix jsonb;plan jsonb;lot jsonb;lots jsonb:='[]';s numeric;total numeric:=0;minimum numeric;vus text[]:=ARRAY[]::text[];idlot text;dest text;r jsonb;cle text;v numeric;caisse text;avant text;entrepot text;besoin jsonb;
BEGIN
 IF acteur IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501';END IF;
 IF p_requete IS NULL OR p_requete !~ '^ch-[A-Za-z0-9-]{8,100}$' OR p_parametres IS NULL OR jsonb_typeof(p_parametres)<>'object' THEN RAISE EXCEPTION 'commande_invalide';END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('chantier:'||acteur||':'||p_requete,0));
 commande:=jsonb_build_object('action',p_action,'parametres',p_parametres);
 SELECT * INTO rec FROM public.chantier_commandes_recus cr WHERE cr.acteur=acteur AND cr.requete=p_requete;
 IF FOUND THEN
  IF rec.personnage_id IS DISTINCT FROM a.id OR rec.terrain_id IS DISTINCT FROM p_terrain_id OR rec.commande<>commande THEN RAISE EXCEPTION 'requete_reutilisee';END IF;
  RETURN rec.resultat||jsonb_build_object('rejeu',true);
 END IF;
 IF coalesce(a.hp,0)<=0 OR coalesce(a.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RAISE EXCEPTION 'acteur_incapacite';END IF;
 IF EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN RAISE EXCEPTION 'acteur_detenu';END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE country=a.country AND
  (id=p_terrain_id OR building_id=p_terrain_id AND data::jsonb->>'city'=a.current_city) ORDER BY (id=p_terrain_id) DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'terrain_introuvable';END IF;
 ancien_etat:=t.data::jsonb;
 IF p_action<>'travailler' THEN IF p_action<>'travailler' THEN source:=public.chantier_financeur_verrouiller_interne(ancien_etat->>'proprietaire',t.country,ancien_etat->>'city');END IF;END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=t.id FOR UPDATE;etat:=t.data::jsonb;
 IF etat->>'proprietaire' IS DISTINCT FROM ancien_etat->>'proprietaire' OR etat->>'city' IS DISTINCT FROM ancien_etat->>'city' THEN RAISE EXCEPTION 'titulaire_modifie';END IF;
 IF p_action<>'travailler' THEN -- Le travail remunere est ouvert aux PJ presents ; seule la gestion exige le proprietaire.
 IF p_action NOT IN('travailler','louer') THEN
 PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');
 END IF;END IF;
 IF coalesce(etat->>'succession_gel','')<>'' THEN RAISE EXCEPTION 'terrain_gele';END IF;
 emplacement:=CASE WHEN jsonb_typeof(etat->'chantierReamenagement')='object' THEN 'chantierReamenagement' ELSE 'chantier' END;ch:=etat->emplacement;
 IF p_action='lancer' THEN
  IF p_parametres-ARRAY['palier','apport']<>'{}' THEN RAISE EXCEPTION 'champs_interdits';END IF;
  IF jsonb_typeof(ch)='object' OR jsonb_typeof(etat->'chantierReamenagement')='object' OR nullif(etat->>'niveau_construction','') IS NOT NULL THEN RAISE EXCEPTION 'chantier_ou_batiment_existant';END IF;
  IF NOT coalesce((etat->>'constructionAutorisee')::boolean,false) OR etat->'permis'->>'statut' IS DISTINCT FROM 'valide' OR etat->'permis'->>'palierDemande' IS DISTINCT FROM p_parametres->>'palier' THEN RAISE EXCEPTION 'permis_non_conforme';END IF;
  IF etat->>'pnj' IN('squatter_cool','squatter_agr','cadavre') THEN RAISE EXCEPTION 'occupation_bloquante';END IF;
  SELECT * INTO pal FROM public.chantiers_paliers WHERE palier=p_parametres->>'palier';
  IF NOT FOUND THEN RAISE EXCEPTION 'palier_inconnu';END IF;
  IF p_parametres->>'apport' !~ '^[0-9]+$' OR p_parametres->>'apport' IS NULL THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
  montant:=(p_parametres->>'apport')::numeric;
  IF montant<pal.apport_minimal OR montant>pal.cout_total THEN RAISE EXCEPTION 'apport_hors_bornes';END IF;
  SELECT jsonb_object_agg(e.cle,ceil(e.prix_base*1.1)) INTO prix FROM public.ressources_economie e WHERE e.cle IN('bois','minerai','metal') AND e.prix_base>=0 AND e.prix_base::text NOT IN('NaN','Infinity','-Infinity');
  IF prix IS NULL OR (SELECT count(*) FROM jsonb_object_keys(prix))<>3 THEN RAISE EXCEPTION 'prix_indisponibles';END IF;
  IF NOT public.chantier_financeur_debiter_interne(source,montant) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ch:=pal.gabarit||jsonb_build_object('jourDebut',a.day,'jourTraite',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'totalVerse',montant,'tresorerie',montant,'prixAchatPJ',prix,'maitreOuvrage',etat->>'proprietaire','planInitialValide',false);
  SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE ville=etat->>'city';
  IF entrepot IS NOT NULL THEN
   SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO besoin FROM public.chantiers_besoins_jour WHERE position_cycle=1;
   IF besoin IS NULL THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
   plan:=public.approvisionner_chantier(acteur,t.country,etat->>'city',entrepot,besoin,coalesce(ch->'stockMateriaux','{}'),(ch->>'tresorerie')::numeric);
   IF NOT coalesce((plan->>'ok')::boolean,false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme';END IF;
   ch:=ch||jsonb_build_object('stockMateriaux',plan->'stockChantier','tresorerie',(ch->>'tresorerie')::numeric-(plan->>'depense')::numeric);
  END IF;
  etat:=etat||jsonb_build_object(emplacement,ch);
 ELSIF p_action='reamenager' THEN
  IF p_parametres-ARRAY['lots']<>'{}' OR jsonb_typeof(p_parametres->'lots') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
  ch:=public.chantier_reamenagement_preparer_interne(etat,p_parametres->'lots',t.country,t.building_id,a.day)||jsonb_build_object('versionCalculTravail',2);
  montant:=(ch->>'coutTotal')::numeric;
  IF NOT public.chantier_financeur_debiter_interne(source,montant) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  etat:=etat||jsonb_build_object('chantierReamenagement',ch);
 ELSIF p_action='verser' THEN
  IF p_parametres-ARRAY['montant']<>'{}' OR jsonb_typeof(ch) IS DISTINCT FROM 'object' OR (ch->>'progressionJours')::numeric>=(ch->>'dureeJours')::numeric THEN RAISE EXCEPTION 'versement_impossible';END IF;
  IF p_parametres->>'montant' !~ '^[0-9]+$' OR p_parametres->>'montant' IS NULL THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
  montant:=least((p_parametres->>'montant')::numeric,(ch->>'coutTotal')::numeric-(ch->>'totalVerse')::numeric);
  IF montant<=0 THEN RAISE EXCEPTION 'montant_invalide';END IF;
  IF NOT public.chantier_financeur_debiter_interne(source,montant) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ch:=ch||jsonb_build_object('totalVerse',(ch->>'totalVerse')::numeric+montant,'tresorerie',(ch->>'tresorerie')::numeric+montant);
  etat:=etat||jsonb_build_object(emplacement,ch);
 ELSIF p_action='travailler' THEN
  IF p_parametres-ARRAY['heures']<>'{}' OR coalesce(p_parametres->>'heures','') !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'heures_invalides';END IF;
  IF a.current_city IS DISTINCT FROM etat->>'city' OR a.current_building IS DISTINCT FROM t.building_id THEN RAISE EXCEPTION 'pas_sur_place';END IF;
  r:=public.chantier_travailler(acteur,t.country,t.id,(p_parametres->>'heures')::integer);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'travail_refuse';END IF;
  SELECT data::jsonb INTO etat FROM public.terrains_etat WHERE id=t.id;
  montant:=(r->>'montant')::numeric;
 ELSIF p_action='prix' THEN
  IF p_parametres-ARRAY['prix']<>'{}' OR jsonb_typeof(p_parametres->'prix') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'prix_invalides';END IF;
  r:=public.chantier_prix_definir(t.id,p_parametres->'prix');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'prix_invalides';END IF;
  SELECT data::jsonb INTO etat FROM public.terrains_etat WHERE id=t.id;
 ELSIF p_action='louer' THEN
  IF p_parametres-ARRAY['lot']<>'{}' OR nullif(p_parametres->>'lot','') IS NULL THEN RAISE EXCEPTION 'lot_introuvable';END IF;
  IF a.current_city IS DISTINCT FROM etat->>'city' OR a.current_building IS DISTINCT FROM t.building_id THEN RAISE EXCEPTION 'pas_sur_place';END IF;
  IF coalesce(a.pa,0)<1 THEN RAISE EXCEPTION 'pa_insuffisants';END IF;
  INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat)
   VALUES(a.id,acteur,p_requete,p_terrain_id,commande,jsonb_build_object('interne','location_lot','transaction_id',txid_current()::text,'bail_id',t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_parametres->>'lot','[^A-Za-z0-9_-]','_','g')||':'||(etat->>'city')));
  etat:=public.location_lot_enregistrer_interne(etat,t.country,t.building_id,p_parametres->>'lot',acteur,a.day);
  UPDATE public.personnages_donnees SET pa=pa-1,updated_at=now() WHERE name=acteur;
 ELSIF p_action='taux' THEN
  IF p_parametres-ARRAY['taux']<>'{}' OR jsonb_typeof(p_parametres->'taux') NOT IN ('string','number') THEN RAISE EXCEPTION 'taux_invalide';END IF;
  r:=public.chantier_taux_definir(t.id,p_parametres->'taux');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'taux_invalide';END IF;
  SELECT data::jsonb INTO etat FROM public.terrains_etat WHERE id=t.id;
 ELSIF p_action='plan' THEN
  IF p_parametres-ARRAY['lots','valider']<>'{}' OR jsonb_typeof(p_parametres->'lots') IS DISTINCT FROM 'array' OR jsonb_typeof(p_parametres->'valider') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'plan_invalide';END IF;
  etat:=public.chantier_plan_enregistrer_interne(etat,p_parametres->'lots',(p_parametres->>'valider')::boolean,t.building_id,t.country,acteur,p_requete,a.day);
 ELSIF p_action='receptionner' THEN
  IF p_parametres<>'{}'::jsonb OR jsonb_typeof(ch) IS DISTINCT FROM 'object' OR NOT coalesce((ch->>'progressionJours')::numeric>=(ch->>'dureeJours')::numeric AND (ch->>'dureeJours')::numeric>0,false) THEN RAISE EXCEPTION 'chantier_non_acheve';END IF;
  IF coalesce((ch->>'totalVerse')::numeric,0)<coalesce((ch->>'coutTotal')::numeric,1) THEN RAISE EXCEPTION 'financement_incomplet';END IF;
  IF a.country IS DISTINCT FROM t.country OR a.current_city IS DISTINCT FROM etat->>'city' OR a.current_building IS DISTINCT FROM t.building_id THEN RAISE EXCEPTION 'pas_sur_place';END IF;
  IF etat->'chantierAcheve'->'reliquats'->>'restitue'='false' THEN RAISE EXCEPTION 'anciens_reliquats_en_attente';END IF;
  plan:=CASE WHEN ch->>'type'='reamenagement' THEN ch->'planCible' ELSE coalesce(etat->'permis'->'decoupageInitial','[]') END;
  IF jsonb_typeof(plan)<>'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
  lots:=CASE WHEN ch->>'type'='reamenagement' THEN public.chantier_reamenagement_livrer_plan_interne(etat,t.country,t.building_id) ELSE public.chantier_plan_normaliser_interne(etat,ch->>'niveau',plan) END;
  IF ch->>'type'<>'reamenagement' AND jsonb_array_length(coalesce(etat->'subdivisions','[]'))>0 THEN RAISE EXCEPTION 'lots_preexistants_a_examiner';END IF;
  montant:=coalesce((ch->>'tresorerie')::numeric,0);
  IF montant<0 OR montant<>trunc(montant) OR montant::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'reliquat_invalide';END IF;
  caisse:=t.country||'_'||(etat->>'city')||'_'||t.building_id;
  IF montant>0 THEN
   avant:=current_setting('rp.caisse_interne',true);PERFORM set_config('rp.caisse_interne','on',true);
   r:=public.caisse_institution_mouvement(caisse,montant,false);PERFORM set_config('rp.caisse_interne',coalesce(avant,''),true);
   IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'reliquat_caisse_non_confirme';END IF;
  END IF;
  FOREACH cle IN ARRAY ARRAY['bois','minerai','metal'] LOOP
   v:=coalesce((ch->'stockMateriaux'->>cle)::numeric,0);
   IF v<0 OR v<>trunc(v) OR v::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'stock_reliquat_invalide';END IF;
   etat:=jsonb_set(etat,'{stockMateriaux}',coalesce(etat->'stockMateriaux','{}')||jsonb_build_object(cle,coalesce((etat->'stockMateriaux'->>cle)::numeric,0)+v));
  END LOOP;
  IF jsonb_typeof(etat->'chantierAcheve')='object' THEN etat:=etat||jsonb_build_object('chantiersArchives',coalesce(etat->'chantiersArchives','[]')||jsonb_build_array(etat->'chantierAcheve'));END IF;
  etat:=(etat-emplacement)||jsonb_build_object('niveau_construction',CASE WHEN ch->>'type'='reamenagement' THEN etat->>'niveau_construction' ELSE ch->>'niveau' END,'subdivisions',lots,'planInitialValide',(coalesce((ch->>'planInitialValide')::boolean,false) OR jsonb_array_length(lots)>0),
   'chantierAcheve',ch||jsonb_build_object('livre',true,'jourLivraison',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'tresorerie',0,'stockMateriaux',jsonb_build_object('bois',0,'minerai',0,'metal',0),'reliquats',jsonb_build_object('restitue',true,'beneficiaire',etat->>'proprietaire','caisse',caisse,'tresorerie',montant,'materiaux',ch->'stockMateriaux')));
 ELSE RAISE EXCEPTION 'action_inconnue';
 END IF;
 UPDATE public.terrains_etat SET data=etat::text,niveau_construction=etat->>'niveau_construction',updated_at=now() WHERE id=t.id;
 resultat:=jsonb_build_object('ok',true,'etat',etat,'chantier',etat->'chantier','montant',montant,'pourcentage',CASE WHEN etat ? 'chantier' THEN floor((etat->'chantier'->>'totalVerse')::numeric*100/(etat->'chantier'->>'coutTotal')::numeric) ELSE 100 END);
 IF p_action='louer' THEN
  UPDATE public.chantier_commandes_recus cr SET resultat=resultat WHERE cr.acteur=acteur AND cr.requete=p_requete AND cr.personnage_id=a.id AND cr.resultat->>'transaction_id'=txid_current()::text AND cr.resultat->>'interne'='location_lot';
  IF NOT FOUND THEN RAISE EXCEPTION 'recu_location_absent';END IF;
 ELSE
  INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat) VALUES(a.id,acteur,p_requete,p_terrain_id,commande,resultat);
 END IF;
 RETURN resultat;
EXCEPTION WHEN SQLSTATE 'P0001' OR insufficient_privilege THEN
 IF SQLERRM=ANY(ARRAY['taux_invalide','lot_introuvable','lot_en_travaux','loyer_invalide','loyer_non_fixe','premier_loyer_refuse','pa_insuffisants','reamenagement_indisponible','lot_vendu','aucun_changement','lots_modifies_pendant_travaux','prix_invalides','heures_invalides','travail_refuse','plan_initial_valide','dernier_tiers_requis','reamenagement_payant_requis','local_occupe','batiment_indivisible','document_plan_non_confirme','acteur_detenu','financement_incomplet','acteur_incapacite','acteur_non_authentifie','action_inconnue','anciens_reliquats_en_attente','apport_hors_bornes','approvisionnement_non_confirme','besoin_chantier_absent','champs_interdits','chantier_non_acheve','chantier_ou_batiment_existant','commande_invalide','fonds_insuffisants','francs_entiers_requis','lots_preexistants_a_examiner','mandat_municipal_requis','montant_invalide','occupation_bloquante','palier_inconnu','pas_proprietaire','pas_sur_place','permis_non_conforme','plan_invalide','prix_indisponibles','reliquat_caisse_non_confirme','reliquat_invalide','requete_reutilisee','stock_reliquat_invalide','terrain_gele','terrain_introuvable','titulaire_modifie','versement_impossible','representation_organisation_refusee','etat_financier_non_entier','organisation_absente']) THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;
 RAISE;
END;$function$;

-- chantier_commande_recu(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_commande_recu(p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n text:=public.mon_personnage();r record;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT * INTO r FROM public.chantier_commandes_recus cr WHERE cr.acteur=n AND cr.requete=p_requete AND cr.personnage_id=(SELECT id FROM public.personnages_donnees WHERE name=n);
 RETURN jsonb_build_object('ok',true,'terminee',FOUND);
END;$function$;

-- chantier_financeur_debiter_interne(jsonb,numeric) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_financeur_debiter_interne(p_source jsonb, p_montant numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d jsonb;s numeric;r jsonb;ancien text;
BEGIN
 IF p_montant IS NULL OR p_montant<0 OR p_montant<>trunc(p_montant) OR p_montant::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
 IF p_montant=0 THEN RETURN true;END IF;
 IF p_source->>'type'='pj' THEN
  RETURN public.helvetia_debiter_fonds_ordinaires(p_source->>'id',p_montant,'nationale');
 ELSIF p_source->>'type'='orga' THEN
  -- Meme bourse organisations.data.caisse que les ordres existants, jamais une caisse de chantier fictive.
  SELECT data::jsonb INTO d FROM public.organisations WHERE id=p_source->>'id' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'organisation_absente';END IF;
  s:=coalesce((d->>'caisse')::numeric,0);
  IF s<0 OR s<>trunc(s) OR s::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'caisse_organisation_invalide';END IF;
  IF s<p_montant THEN RETURN false;END IF;
  UPDATE public.organisations SET data=jsonb_set(d,'{caisse}',to_jsonb(s-p_montant))::text WHERE id=p_source->>'id';
  RETURN true;
 ELSIF p_source->>'type'='ville' THEN
  ancien:=current_setting('rp.caisse_interne',true);
  PERFORM set_config('rp.caisse_interne','on',true);
  r:=public.caisse_institution_mouvement(p_source->>'id',-p_montant,true);
  PERFORM set_config('rp.caisse_interne',coalesce(ancien,''),true);
  RETURN coalesce((r->>'ok')::boolean,false);
 END IF;
 RAISE EXCEPTION 'source_financiere_inconnue';
END;$function$;

-- chantier_financeur_verrouiller_interne(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_financeur_verrouiller_interne(p_titulaire text, p_pays text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d jsonb;n text;c text;v text;
BEGIN
 IF p_titulaire LIKE 'orga:%' THEN
  n:=substr(p_titulaire,6);
  SELECT data::jsonb INTO d FROM public.organisations WHERE id=n FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'organisation_absente';END IF;
  RETURN jsonb_build_object('type','orga','id',n,'destinataire',d->>'chef');
 ELSIF p_titulaire LIKE 'ville:%' THEN
  IF p_titulaire<>'ville:'||p_pays||':'||p_ville THEN RAISE EXCEPTION 'commune_hors_territoire';END IF;
  c:=public.salaire_caisse_de('maire',p_pays,p_ville);IF c IS NULL THEN RAISE EXCEPTION 'caisse_communale_absente';END IF;
  SELECT data INTO d FROM public.caisses_batiments WHERE id=c FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'caisse_communale_absente';END IF;
  IF (d->>'solde') IS NULL OR (d->>'solde')::numeric<0 OR (d->>'solde')::numeric<>trunc((d->>'solde')::numeric) OR d->>'solde' IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'caisse_communale_invalide';END IF;
  SELECT data::jsonb->>'eluId' INTO n FROM public.cycles_electoraux WHERE country=p_pays AND poste_id='maire' AND city=p_ville;
  RETURN jsonb_build_object('type','ville','id',c,'destinataire',n);
 ELSE
  n:=CASE WHEN p_titulaire LIKE 'pj:%' THEN substr(p_titulaire,4) ELSE p_titulaire END;
  IF n IS NULL OR n='' THEN RAISE EXCEPTION 'titulaire_non_pris_en_charge';END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=n FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proprietaire_absent';END IF;
  PERFORM 1 FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale' FOR UPDATE;
  RETURN jsonb_build_object('type','pj','id',n,'destinataire',n);
 END IF;
END;$function$;

-- chantier_jour_traiter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_jour_traiter(p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE paye numeric;cible_travail numeric;gain_travail numeric;emplacement text;r record;snapshot jsonb;etat jsonb;ch jsonb;source jsonb;jour text;avant numeric;apres numeric;d numeric;
 besoin jsonb;stock jsonb;plan jsonb;entrepot text;num integer;m text;req numeric;f numeric:=1;cap numeric;faites numeric;heures numeric;cout numeric;gain numeric;plafond numeric;taux numeric;rep jsonb;ancien text;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur');END IF;
 SELECT * INTO r FROM public.terrains_etat WHERE id=p_terrain_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_absent');END IF;
 snapshot:=r.data::jsonb;
 emplacement:=CASE WHEN jsonb_typeof(snapshot->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;
 IF jsonb_typeof(snapshot->emplacement) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',true,'ignore',true);END IF;
 -- Le verrou du financeur precede celui du terrain, comme lancement/ventes/transferts.
 source:=public.chantier_financeur_verrouiller_interne(snapshot->>'proprietaire',r.country,snapshot->>'city');
 SELECT * INTO r FROM public.terrains_etat WHERE id=p_terrain_id FOR UPDATE;etat:=r.data::jsonb;
 IF etat->>'proprietaire' IS DISTINCT FROM snapshot->>'proprietaire' OR etat->>'city' IS DISTINCT FROM snapshot->>'city' THEN
  RETURN jsonb_build_object('ok',false,'raison','titulaire_modifie');END IF;
 ch:=etat->emplacement;jour:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF coalesce(etat->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',true,'ignore',true,'raison','terrain_gele');END IF;
 IF coalesce(ch->>'type','') NOT IN('construction','reamenagement') THEN RETURN jsonb_build_object('ok',false,'raison','chantier_historique_a_examiner');END IF;
 IF ch->>'jourTraite'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat);END IF;
 avant:=(ch->>'progressionJours')::numeric;d:=(ch->>'dureeJours')::numeric;
 IF avant IS NULL OR avant<0 OR d IS NULL OR d<=0 OR d<>trunc(d) THEN RAISE EXCEPTION 'dimensionnement_chantier_invalide';END IF;
 IF avant<d THEN
  ch:=public.chantier_appel_fonds_interne(ch,source);
  IF ch->>'arrete' IS DISTINCT FROM 'financement' THEN
   num:=floor(avant)::integer+1;
   besoin:=public.chantier_besoin_jour_interne(ch,num);
   IF besoin IS NULL THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
   SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE ville=etat->>'city';
   stock:=coalesce(ch->'stockMateriaux','{}');
   IF entrepot IS NOT NULL THEN
    plan:=public.approvisionner_chantier(source->>'destinataire',r.country,etat->>'city',entrepot,besoin,stock,coalesce((ch->>'tresorerie')::numeric,0));
    IF NOT coalesce((plan->>'ok')::boolean,false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme';END IF;
    stock:=plan->'stockChantier';ch:=ch||jsonb_build_object('tresorerie',(ch->>'tresorerie')::numeric-(plan->>'depense')::numeric);
   END IF;
   FOREACH m IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    req:=(besoin->>m)::numeric;
    IF req>0 THEN f:=least(f,greatest(0,coalesce((stock->>m)::numeric,0))/req);END IF;
   END LOOP;
   IF f<1 THEN
    IF ch->>'manqueMateriauxAvise' IS NULL THEN
     BEGIN
      PERFORM public.mail_systeme_poser_interne('Chantier', ch->>'maitreOuvrage', 'Chantier à l''arrêt : matériaux manquants',
        'L''entrepôt de la ville ne peut pas fournir assez de '
        || (SELECT string_agg(CASE m2 WHEN 'metal' THEN 'métal' ELSE m2 END, ', ') FROM unnest(ARRAY['bois','minerai','metal']) m2
             WHERE coalesce((besoin->>m2)::numeric,0) > coalesce((stock->>m2)::numeric,0))
        || ' pour la journée de travail. Le chantier reprendra dès que l''entrepôt sera réapprovisionné, ou si des matériaux sont apportés au chantier.', NULL);
     EXCEPTION WHEN others THEN NULL;
     END;
     ch:=ch||jsonb_build_object('manqueMateriauxAvise',jour);
    END IF;
   ELSIF ch ? 'manqueMateriauxAvise' THEN
    ch:=ch-'manqueMateriauxAvise';
   END IF;
   SELECT valeur INTO taux FROM public.entreprises_constantes WHERE cle='chantier_taux_horaire';
   IF taux IS NULL OR taux<=0 THEN RAISE EXCEPTION 'taux_chantier_indisponible';END IF;
   cap:=(ch->>'coutTravail')::numeric/taux/d;faites:=coalesce((ch->>'heuresFaites')::numeric,0);
   IF cap IS NULL OR cap<=0 OR faites<0 OR faites>cap THEN RAISE EXCEPTION 'capacite_travail_invalide';END IF;
   plafond:=CASE WHEN (ch->>'totalVerse')::numeric>=(ch->>'coutTotal')::numeric THEN d
     WHEN (ch->>'totalVerse')::numeric>=ceil((ch->>'coutTotal')::numeric*.7) THEN d*2/3 ELSE d/3 END;
   IF ch->>'type'='reamenagement' AND ch->>'versionCalculTravail'='2' THEN
    -- Les paiements de chaque jour restent entiers ; leur cumul solde exactement le cout.
    -- Les heures PJ restent entieres a 1 PA/heure. Aucun ancien salaire n'est reconstitue.
    SELECT coalesce(sum((e->>'coutPNJ')::numeric),0) INTO paye FROM jsonb_array_elements(coalesce(ch->'evenements','[]')) e WHERE e->>'cle'='journee';
    SELECT paye+coalesce(sum((e->>'montant')::numeric),0) INTO paye FROM jsonb_array_elements(coalesce(ch->'travauxPJ','[]')) e;
    IF paye<0 OR paye>(ch->>'coutTravail')::numeric THEN RAISE EXCEPTION 'journal_travail_incoherent';END IF;
    cible_travail:=least((ch->>'coutTravail')::numeric,ceil((ch->>'coutTravail')::numeric*least(d,plafond,avant+least(1,f))/d));
    cout:=greatest(0,least(cible_travail-paye,floor((ch->>'tresorerie')::numeric)));heures:=cout/taux;
    gain_travail:=greatest(0,(paye+cout)*d/(ch->>'coutTravail')::numeric-avant);
   ELSE
   heures:=greatest(0,least(floor(cap*least(f,d-avant,plafond-avant))-faites,floor((ch->>'tresorerie')::numeric/taux)));cout:=heures*taux;
   END IF;
   IF cout>0 THEN
    ancien:=current_setting('rp.caisse_interne',true);PERFORM set_config('rp.caisse_interne','on',true);
    rep:=public.caisse_institution_mouvement(r.country||'_gouvernement-min_fin',cout,true);
    PERFORM set_config('rp.caisse_interne',coalesce(ancien,''),true);
    IF NOT coalesce((rep->>'ok')::boolean,false) THEN RAISE EXCEPTION 'remuneration_pnj_non_confirmee';END IF;
   END IF;
   gain:=least(1,f,CASE WHEN ch->>'type'='reamenagement' AND ch->>'versionCalculTravail'='2' THEN gain_travail ELSE (faites+heures)/cap END,d-avant);
   gain:=greatest(0,least(gain,plafond-avant));apres:=avant+gain;
   FOREACH m IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    stock:=jsonb_set(stock,ARRAY[m],to_jsonb(greatest(0,coalesce((stock->>m)::numeric,0)-floor((besoin->>m)::numeric*gain))));
   END LOOP;
   ch:=ch||jsonb_build_object('progressionJours',apres,'tresorerie',(ch->>'tresorerie')::numeric-cout,'stockMateriaux',stock,'heuresFaites',0,'arrete',CASE WHEN gain=0 THEN 'penurie_materiaux' ELSE NULL END,
    'evenements',coalesce(ch->'evenements','[]')||jsonb_build_array(jsonb_build_object('cle','journee','date',jour,'avance',gain,'heuresPNJ',heures,'coutPNJ',cout,'achats',plan->'achats')));
   -- Un seuil atteint aujourd'hui appelle immediatement la tranche suivante, sans avancer le temps utile si refus.
   IF apres<d THEN ch:=public.chantier_appel_fonds_interne(ch,source);END IF;
  END IF;
 END IF;
 IF (ch->>'progressionJours')::numeric>=d THEN
  IF NOT coalesce((ch->>'attenteReception')::boolean,false) AND nullif(source->>'destinataire','') IS NOT NULL THEN
   rep:=public.mail_systeme_poser_interne('Chef de Chantier',source->>'destinataire','Chantier acheve — reception sur place','Les travaux sont acheves. Venez sur place pour receptionner le batiment et ouvrir ses locaux.');
   IF NOT coalesce((rep->>'ok')::boolean,false) THEN ch:=ch||jsonb_build_object('notificationEchec',rep);END IF;
  END IF;
  ch:=ch||jsonb_build_object('attenteReception',true,'arrete',null);
 END IF;
 ch:=ch||jsonb_build_object('jourTraite',jour);
 etat:=etat||jsonb_build_object(emplacement,ch);
 UPDATE public.terrains_etat SET data=etat::text,updated_at=now() WHERE id=p_terrain_id;
 RETURN jsonb_build_object('ok',true,'etat',etat,'attenteReception',coalesce((ch->>'attenteReception')::boolean,false),'avance',coalesce(gain,0));
END;$function$;

-- chantier_lancer(text,text,text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.chantier_lancer(p_acteur text, p_pays text, p_batiment text, p_palier text, p_apport numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_data jsonb; v_pal record; v_chantier jsonb; v_jour integer;
  v_palier_permis text;
  v_prix_initiaux jsonb; v_nb_prix integer; v_prix_valides boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- Ordre de verrous commun avec les transferts : personnage puis terrain puis compte.
  PERFORM 1 FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
  v_id := p_pays || '_' || p_batiment;

  SELECT * INTO v_pal FROM public.chantiers_paliers WHERE palier = p_palier;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'palier_inconnu'); END IF;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- Regles existantes, relues sur l'etat reel du terrain -- l'ecran n'est qu'une anticipation.
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;
  IF v_data ? 'chantier' AND jsonb_typeof(v_data->'chantier') = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_en_cours');
  END IF;
  IF COALESCE((v_data->>'constructionAutorisee')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'permis_requis');
  END IF;
  v_palier_permis := v_data->'permis'->>'palierDemande';
  IF v_palier_permis IS NOT NULL AND v_palier_permis <> p_palier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'permis_non_conforme',
                              'attendu', v_palier_permis);
  END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  -- L'apport minimal vient du miroir, jamais d'un calcul transmis.
  IF p_apport IS NULL OR p_apport < v_pal.apport_minimal THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'apport_insuffisant',
                              'minimum', v_pal.apport_minimal);
  END IF;
  IF p_apport > v_pal.cout_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'apport_excessif',
                              'maximum', v_pal.cout_total);
  END IF;

  -- #57 : photographier les trois prix initiaux avant tout debit, dans le meme lancement.
  -- Aucun tarif ne vient du navigateur, aucun arrondi des soldes ni changement d'unite.
  IF p_apport<>trunc(p_apport) THEN RETURN jsonb_build_object('ok',false,'raison','francs_entiers_requis'); END IF;
  SELECT jsonb_object_agg(cle,ceil(prix_base*1.10)),count(*),
    bool_and(prix_base>=0 AND prix_base::text NOT IN ('NaN','Infinity','-Infinity'))
    INTO v_prix_initiaux,v_nb_prix,v_prix_valides FROM public.ressources_economie
    WHERE cle IN ('bois','minerai','metal');
  IF v_nb_prix<>3 OR NOT coalesce(v_prix_valides,false) THEN
    RETURN jsonb_build_object('ok',false,'raison','prix_entrepot_indisponibles'); END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, p_apport, 'nationale') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'apport', p_apport);
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_chantier := v_pal.gabarit
                || jsonb_build_object('jourDebut', v_jour,
                                      'totalVerse', p_apport, 'tresorerie', p_apport,
                                      'prixAchatPJ', v_prix_initiaux);

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_chantier))::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'chantier', v_chantier, 'apport', p_apport,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_plan_enregistrer_interne(p_etat jsonb, p_plan jsonb, p_valider boolean, p_terrain text, p_pays text, p_acteur text, p_requete text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ch jsonb:=p_etat->'chantier';niveau text;lots jsonb;doc jsonb;ref text;r jsonb;
BEGIN
 IF jsonb_typeof(ch)='object' THEN
  IF coalesce((ch->>'planInitialValide')::boolean,false) THEN RAISE EXCEPTION 'plan_initial_valide';END IF;
  IF NOT coalesce((ch->>'progressionJours')::numeric>=(ch->>'dureeJours')::numeric*2/3 AND (ch->>'dureeJours')::numeric>0,false) THEN RAISE EXCEPTION 'dernier_tiers_requis';END IF;
  niveau:=ch->>'niveau';
 ELSE
  niveau:=p_etat->>'niveau_construction';
  IF niveau IS NULL OR coalesce((p_etat->>'planInitialValide')::boolean,false) OR jsonb_array_length(coalesce(p_etat->'subdivisions','[]'))>0 THEN RAISE EXCEPTION 'reamenagement_payant_requis';END IF;
  IF EXISTS(SELECT 1 FROM public.locations_actives WHERE country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_terrain) THEN RAISE EXCEPTION 'local_occupe';END IF;
 END IF;
 IF niveau NOT IN('commerce_premium','building') THEN RAISE EXCEPTION 'batiment_indivisible';END IF;
 lots:=public.chantier_plan_normaliser_interne(p_etat,niveau,p_plan);
 -- Conserver les informations du permis : seul son plan change, aucune autorisation forgeable.
 p_etat:=jsonb_set(p_etat,'{permis}',coalesce(p_etat->'permis','{}')||jsonb_build_object('decoupageInitial',p_plan));
 IF jsonb_typeof(ch)='object' THEN
  p_etat:=jsonb_set(p_etat,'{chantier}',ch||jsonb_build_object('planInitialValide',p_valider));
 ELSE
  p_etat:=p_etat||jsonb_build_object('subdivisions',lots,'planInitialValide',true);
 END IF;
 ref:='urb-plan-'||p_requete;
 doc:=jsonb_build_object('id',ref||'-document','nature','modification_plan','numeroDossier',p_etat->'permis'->>'numeroDossier','jour',p_jour,'demandeur',p_acteur,'pays',p_pays,'ville',p_etat->>'city','buildingId',p_terrain,'batimentLabel',p_terrain,'palier',niveau,'surfaceExploitable',p_etat->'surface','decoupage',p_plan);
 INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
 VALUES(ref,p_pays,p_etat->>'city',p_terrain,p_etat->'permis'->>'numeroDossier','modification_plan',p_acteur,p_jour,'Modification du plan de decoupage',doc);
 r:=public.objet_sas_deposer('document_urbanisme',p_acteur,jsonb_build_object('id',doc->>'id','type','document_urbanisme_modification_plan','name','Recepisse de modification du plan','icon','ti-file-text','legal',true,'documentUrbanisme',doc),ref);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'document_plan_non_confirme';END IF;
 RETURN p_etat;
END;$function$;

-- chantier_plan_normaliser_interne(jsonb,text,jsonb) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_plan_normaliser_interne(p_etat jsonb, p_niveau text, p_plan jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE lot jsonb;sortie jsonb:='[]';vus text[]:=ARRAY[]::text[];idlot text;dest text;s numeric;total numeric:=0;minimum numeric;
BEGIN
 IF p_niveau IN('logements_petit','logements_moyen','logements_barre') THEN RETURN public.logements_sociaux_lots_interne(p_niveau);END IF;
 IF jsonb_typeof(p_plan) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
 FOR lot IN SELECT value FROM jsonb_array_elements(p_plan) LOOP
  idlot:=nullif(btrim(lot->>'id'),'');dest:=coalesce(lot->>'destination','commerce');s:=(lot->>'surface')::numeric;
  minimum:=CASE WHEN p_niveau='commerce_premium' AND dest='commerce' THEN 600 WHEN p_niveau='building' AND dest='commerce' THEN 300 WHEN p_niveau='building' AND dest='appartement' THEN 150 END;
  total:=total+s;
  IF idlot IS NULL OR idlot=ANY(vus) OR minimum IS NULL OR s IS NULL OR s<minimum OR nullif(p_etat->>'surface','') IS NULL OR total>(p_etat->>'surface')::numeric THEN RAISE EXCEPTION 'plan_invalide';END IF;
  vus:=array_append(vus,idlot);
  sortie:=sortie||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Lot'),'surface',s,'destination',dest,'locataire',NULL,'loyer',0));
 END LOOP;
 RETURN sortie;
END;$function$;

-- chantier_prix_definir(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_prix_definir(p_terrain_id text, p_prix jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_emplacement text;v_id text; v_acteur text:=public.mon_personnage(); v_pays text; v_etat jsonb; v_ch jsonb; v_k text; v_val jsonb; v_n numeric;
BEGIN
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name=v_acteur;
  SELECT t.id,t.data::jsonb INTO v_id,v_etat FROM public.terrains_etat t WHERE t.country=v_pays AND (t.id=p_terrain_id OR t.building_id=p_terrain_id AND t.data::jsonb->>'city'=(SELECT current_city FROM public.personnages_donnees WHERE name=v_acteur)) ORDER BY (t.id=p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_proprietaire'); END IF;
  PERFORM public.chantier_autorite_exiger_interne(v_etat->>'proprietaire',v_pays,v_etat->>'city');
  v_emplacement:=CASE WHEN jsonb_typeof(v_etat->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_ch:=v_etat->v_emplacement;
  IF v_ch IS NULL OR (v_ch->>'progressionJours')::numeric >= (v_ch->>'dureeJours')::numeric
     OR nullif(v_etat->>'succession_gel','') IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','chantier_indisponible'); END IF;
  IF jsonb_typeof(p_prix) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',false,'raison','prix_invalides'); END IF;
  FOR v_k,v_val IN SELECT * FROM jsonb_each(p_prix) LOOP
    IF v_k NOT IN ('bois','minerai','metal') OR jsonb_typeof(v_val) NOT IN ('string','number') OR (v_val#>>'{}') !~ '^(0|[1-9][0-9]*)$' THEN
      RETURN jsonb_build_object('ok',false,'raison','prix_invalides'); END IF;
    v_n:=(v_val#>>'{}')::numeric;
    v_ch:=jsonb_set(v_ch,ARRAY['prixAchatPJ'],coalesce(v_ch->'prixAchatPJ','{}')||jsonb_build_object(v_k,v_n));
  END LOOP;
  v_etat:=jsonb_set(v_etat,ARRAY[v_emplacement],v_ch);
  UPDATE public.terrains_etat SET data=v_etat::text,updated_at=now() WHERE id=v_id;
  RETURN jsonb_build_object('ok',true,'etat',v_etat);
END;$function$;

-- chantier_reamenagement_livrer_plan_interne(jsonb,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_reamenagement_livrer_plan_interne(p_etat jsonb, p_pays text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ch jsonb:=p_etat->'chantierReamenagement';cible jsonb;source jsonb;a jsonb;b jsonb;sortie jsonb:='[]';
BEGIN
 IF jsonb_typeof(ch) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'chantier_non_acheve';END IF;
 -- Le chantier n'efface jamais une ecriture immobiliere concurrente.
 FOR a IN SELECT value FROM jsonb_array_elements(ch->'planSource') LOOP
  SELECT value INTO source FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=a->>'id';
  IF source IS NULL OR source->'surface' IS DISTINCT FROM a->'surface' OR source->>'destination' IS DISTINCT FROM a->>'destination' THEN RAISE EXCEPTION 'lots_modifies_pendant_travaux';END IF;
  IF ch->'lotsConcernes' ? (a->>'id') THEN
   IF nullif(source->>'locataire','') IS NOT NULL OR EXISTS(SELECT 1 FROM public.locations_actives WHERE country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_batiment AND (data->>'lotId'=a->>'id' OR data->>'roomId'='lot_dyn_'||regexp_replace(a->>'id','[^A-Za-z0-9_-]','_','g'))) THEN RAISE EXCEPTION 'local_occupe';END IF;
   IF source->>'proprietaire' IS DISTINCT FROM a->>'proprietaire' THEN RAISE EXCEPTION 'lot_vendu';END IF;
  END IF;
 END LOOP;
 IF jsonb_array_length(coalesce(p_etat->'subdivisions','[]'))<>jsonb_array_length(ch->'planSource') THEN RAISE EXCEPTION 'lots_modifies_pendant_travaux';END IF;
 cible:=public.chantier_plan_normaliser_interne(p_etat,p_etat->>'niveau_construction',ch->'planCible');
 FOR b IN SELECT value FROM jsonb_array_elements(cible) LOOP
  SELECT value INTO a FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=b->>'id';
  sortie:=sortie||jsonb_build_array(CASE WHEN a IS NULL THEN b ELSE a||jsonb_build_object('surface',b->'surface','destination',b->'destination','label',b->'label') END);
 END LOOP;
 RETURN sortie;
END;$function$;

-- chantier_reamenagement_preparer_interne(jsonb,jsonb,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_reamenagement_preparer_interne(p_etat jsonb, p_plan jsonb, p_pays text, p_batiment text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE cible jsonb;source jsonb:=coalesce(p_etat->'subdivisions','[]');a jsonb;b jsonb;plan jsonb:='[]';touches jsonb:='[]';operations jsonb:='[]';s numeric:=0;ecart numeric;total numeric;d numeric;prix jsonb;
BEGIN
 IF jsonb_typeof(p_etat->'chantier')='object' OR jsonb_typeof(p_etat->'chantierReamenagement')='object' OR coalesce(p_etat->>'niveau_construction','') NOT IN('commerce_premium','building') THEN RAISE EXCEPTION 'reamenagement_indisponible';END IF;
 cible:=public.chantier_plan_normaliser_interne(p_etat,p_etat->>'niveau_construction',p_plan);
 -- Meme difference de plans que le moteur navigateur : aucune facturation des simples libelles.
 FOR a IN SELECT value FROM jsonb_array_elements(source) LOOP
  SELECT value INTO b FROM jsonb_array_elements(cible) WHERE value->>'id'=a->>'id';
  ecart:=CASE WHEN b IS NULL THEN (a->>'surface')::numeric WHEN a->>'destination' IS DISTINCT FROM b->>'destination' THEN greatest((a->>'surface')::numeric,(b->>'surface')::numeric) ELSE abs((a->>'surface')::numeric-(b->>'surface')::numeric) END;
  IF ecart>0 THEN
   IF nullif(a->>'proprietaire','') IS NOT NULL AND a->>'proprietaire' IS DISTINCT FROM p_etat->>'proprietaire' THEN RAISE EXCEPTION 'lot_vendu';END IF;
   IF nullif(a->>'locataire','') IS NOT NULL OR EXISTS(SELECT 1 FROM public.locations_actives WHERE country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_batiment AND (data->>'lotId'=a->>'id' OR data->>'roomId'='lot_dyn_'||regexp_replace(a->>'id','[^A-Za-z0-9_-]','_','g'))) THEN RAISE EXCEPTION 'local_occupe';END IF;
   s:=s+ecart;touches:=touches||jsonb_build_array(a->>'id');
   operations:=operations||jsonb_build_array(jsonb_build_object('id',a->>'id','surface',ecart,'operation',CASE WHEN b IS NULL THEN 'suppression' WHEN a->>'destination' IS DISTINCT FROM b->>'destination' THEN 'destination' WHEN (b->>'surface')::numeric>(a->>'surface')::numeric THEN 'agrandissement' ELSE 'reduction' END));
  END IF;
 END LOOP;
 FOR b IN SELECT value FROM jsonb_array_elements(cible) LOOP
  SELECT value INTO a FROM jsonb_array_elements(source) WHERE value->>'id'=b->>'id';
  IF a IS NULL THEN
   s:=s+(b->>'surface')::numeric;operations:=operations||jsonb_build_array(jsonb_build_object('id',b->>'id','surface',(b->>'surface')::numeric,'operation','creation'));plan:=plan||jsonb_build_array(b);
  ELSE
   -- Preserver l'identite et les metadonnees, surtout des lots non touches et loues.
   plan:=plan||jsonb_build_array(a||jsonb_build_object('surface',b->'surface','destination',b->'destination','label',b->'label'));
  END IF;
 END LOOP;
 IF s IS NULL OR s<=0 OR s::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'aucun_changement';END IF;
 total:=s*10;
 IF total<>trunc(total) THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
 d:=greatest(1,ceil(s/300));
 SELECT jsonb_object_agg(cle,ceil(prix_base*1.1)) INTO prix FROM public.ressources_economie WHERE cle IN('bois','minerai','metal') AND prix_base>=0;
 IF prix IS NULL OR (SELECT count(*) FROM jsonb_object_keys(prix))<>3 THEN RAISE EXCEPTION 'prix_indisponibles';END IF;
 RETURN jsonb_build_object('type','reamenagement','niveau',NULL,'jourDebut',p_jour,'planSource',source,'planCible',plan,'surfaceConcernee',s,'lotsConcernes',touches,'operations',operations,'surfaceLibreImmobilisee',s,'dureeJours',d,'coutTotal',total,'coutMateriaux',total*.3,'coutTravail',total*.7,'heuresTotales',total*.7/70,'totalVerse',total,'tresorerie',total,'stockMateriaux',jsonb_build_object('bois',0,'minerai',0,'metal',0),'prixAchatPJ',prix,'progressionJours',0,'heuresFaites',0,'jourTraite',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'arrete',NULL,'evenements',jsonb_build_array(jsonb_build_object('cle','lancement','surfaceConcernee',s,'coutTotal',total,'dureeJours',d)),'travauxPJ','[]'::jsonb,'ventesMateriauxPJ','[]'::jsonb);
END;$function$;

-- chantier_taux_definir(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.chantier_taux_definir(p_terrain_id text, p_taux jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_acteur text := public.mon_personnage(); v_pays text; v_etat jsonb; v_ch jsonb;
        v_n numeric; v_min numeric;
BEGIN
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;
  SELECT t.id, t.data::jsonb INTO v_id, v_etat FROM public.terrains_etat t
   WHERE t.country = v_pays AND (t.id = p_terrain_id OR t.building_id = p_terrain_id
         AND t.data::jsonb ->> 'city' = (SELECT current_city FROM public.personnages_donnees WHERE name = v_acteur))
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  PERFORM public.chantier_autorite_exiger_interne(v_etat ->> 'proprietaire', v_pays, v_etat ->> 'city');
  v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR (v_ch ->> 'progressionJours')::numeric >= (v_ch ->> 'dureeJours')::numeric
     OR nullif(v_etat ->> 'succession_gel', '') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_indisponible'); END IF;
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  IF jsonb_typeof(p_taux) NOT IN ('string', 'number') OR (p_taux #>> '{}') !~ '^[1-9][0-9]{0,5}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_invalide'); END IF;
  v_n := (p_taux #>> '{}')::numeric;
  IF v_n < coalesce(v_min, 50) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_invalide', 'minimum', coalesce(v_min, 50)); END IF;
  v_ch := v_ch || jsonb_build_object('tauxHoraire', v_n);
  v_etat := jsonb_set(v_etat, '{chantier}', v_ch);
  UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'taux', v_n, 'etat', v_etat);
END; $function$;

-- chantier_travailler(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.chantier_travailler(p_acteur text, p_pays text, p_batiment text, p_heures integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_emplacement text;v_id text; v_data jsonb; v_ch jsonb; v_stock jsonb; v_besoin record;
  v_jour_num integer; v_fraction numeric := 1; v_capacite numeric; v_utiles numeric;
  v_faites numeric; v_restantes numeric; v_tresorerie numeric; v_payables numeric;
  v_taux numeric; v_pa integer; v_arg numeric; v_liquide numeric; v_jour integer;
  v_plafond numeric; v_taux_paye numeric; v_min numeric;
  v_heures integer; v_montant numeric; v_m text; v_req numeric; v_dispo numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_heures, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'heures_invalides');
  END IF;
  SELECT id INTO v_id FROM public.terrains_etat WHERE country=p_pays AND id=p_batiment;
  IF v_id IS NULL THEN v_id:=p_pays||'_'||p_batiment;END IF;

  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  IF COALESCE(v_taux, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_indisponible');
  END IF;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  v_emplacement:=CASE WHEN jsonb_typeof(v_data->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_ch:=v_data->v_emplacement;
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;
  -- Le besoin quotidien d'un reamenagement se derive de SON budget, pas du cycle de construction :
  -- ce chemin n'est pas couvert ici et reste a traiter separement.
  IF COALESCE(v_ch->>'type','') NOT IN('construction','reamenagement') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert', 'type', v_ch->>'type');
  END IF;

  -- --- Borne 2 : heures encore utiles aujourd'hui --------------------------
  v_jour_num := floor(GREATEST(0, COALESCE((v_ch->>'progressionJours')::numeric, 0)))::integer + 1;
  SELECT (x->>'bois')::numeric AS bois,(x->>'minerai')::numeric AS minerai,(x->>'metal')::numeric AS metal INTO v_besoin FROM (SELECT public.chantier_besoin_jour_interne(v_ch,v_jour_num) AS x) b;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'besoin_indisponible'); END IF;

  v_stock := COALESCE(v_ch->'stockMateriaux', '{}'::jsonb);
  FOR v_m, v_req IN SELECT * FROM (VALUES ('bois', v_besoin.bois), ('minerai', v_besoin.minerai),
                                          ('metal', v_besoin.metal)) AS t(m, r) LOOP
    IF v_req > 0 THEN
      v_dispo := GREATEST(0, COALESCE((v_stock->>v_m)::numeric, 0));
      v_fraction := LEAST(v_fraction, LEAST(1, GREATEST(0, v_dispo / v_req)));
    END IF;
  END LOOP;

  v_capacite := CASE WHEN COALESCE((v_ch->>'dureeJours')::numeric, 0) > 0
                     THEN (COALESCE((v_ch->>'coutTravail')::numeric, 0) / v_taux)
                          / (v_ch->>'dureeJours')::numeric
                     ELSE 0 END;
  v_plafond:=CASE WHEN (v_ch->>'totalVerse')::numeric>=(v_ch->>'coutTotal')::numeric THEN (v_ch->>'dureeJours')::numeric WHEN (v_ch->>'totalVerse')::numeric>=ceil((v_ch->>'coutTotal')::numeric*.7) THEN (v_ch->>'dureeJours')::numeric*2/3 WHEN (v_ch->>'totalVerse')::numeric>=ceil((v_ch->>'coutTotal')::numeric*.35) THEN (v_ch->>'dureeJours')::numeric/3 ELSE 0 END;
  v_utiles:=floor(v_capacite*least(v_fraction,greatest(0,v_plafond-coalesce((v_ch->>'progressionJours')::numeric,0))));
  v_faites   := GREATEST(0, COALESCE((v_ch->>'heuresFaites')::numeric, 0));
  v_restantes := GREATEST(0, v_utiles - v_faites);

  -- --- Bornes 3 et 4 : PA reels et tresorerie reelle -----------------------
  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_tresorerie := GREATEST(0, COALESCE((v_ch->>'tresorerie')::numeric, 0));
  -- Taux fixe par le proprietaire (Fred, 25/10/2026), jamais sous le salaire minimum.
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  v_taux_paye := GREATEST(COALESCE((v_ch->>'tauxHoraire')::numeric, v_taux), COALESCE(v_min, 50));
  v_payables   := floor(v_tresorerie / v_taux_paye);

  v_heures := GREATEST(0, LEAST(p_heures, v_restantes, v_pa, v_payables))::integer;
  IF v_heures <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_heure_travaillable',
      'utilesRestantes', v_restantes, 'pa', v_pa, 'payables', v_payables,
      'fractionMateriaux', round(v_fraction, 4));
  END IF;
  v_montant := v_heures * v_taux_paye;

  -- --- Application, tout ou rien -------------------------------------------
  v_ch := v_ch || jsonb_build_object(
    'heuresFaites', v_faites + v_heures,
    'tresorerie', v_tresorerie - v_montant,
    'travauxPJ', COALESCE(v_ch->'travauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('nom', p_acteur, 'heures', v_heures, 'montant', v_montant,
                         'jour', v_jour)));

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object(v_emplacement, v_ch))::text, updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET pa = v_pa - v_heures, arg = v_arg + v_montant, liquide = v_liquide + v_montant,
         updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'heures', v_heures, 'montant', v_montant, 'taux', v_taux_paye,
    'pa', v_pa - v_heures, 'arg', v_arg + v_montant, 'liquide', v_liquide + v_montant,
    'chantier', v_ch);
END; $function$;

-- chantier_verser(text,text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.chantier_verser(p_acteur text, p_pays text, p_batiment text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_data jsonb; v_ch jsonb; v_total numeric; v_verse numeric; v_restant numeric;
  v_montant numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_id := p_pays || '_' || p_batiment;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  v_ch := v_data->'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  v_total   := GREATEST(0, COALESCE((v_ch->>'coutTotal')::numeric, 0));
  v_verse   := GREATEST(0, COALESCE((v_ch->>'totalVerse')::numeric, 0));
  v_restant := GREATEST(0, v_total - v_verse);
  IF v_restant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_finance');
  END IF;

  -- Un montant absent ou nul vaut « solder » : c'est la regle de l'ecran, conservee telle quelle.
  v_montant := CASE WHEN COALESCE(p_montant, 0) > 0 THEN LEAST(p_montant, v_restant)
                    ELSE v_restant END;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'montant', v_montant);
  END IF;

  v_ch := v_ch || jsonb_build_object(
    'totalVerse', v_verse + v_montant,
    'tresorerie', GREATEST(0, COALESCE((v_ch->>'tresorerie')::numeric, 0)) + v_montant);

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_ch))::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'chantier', v_ch,
    'pourcentage', floor((v_verse + v_montant) * 100 / NULLIF(v_total, 0)),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- coef_prix_max_pj(text) -> numeric | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.coef_prix_max_pj(p_pays text)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  select valeur::numeric
    from public.entreprises_constantes
   where cle = 'coef_prix_max_pj_' || coalesce(nullif(btrim(p_pays), ''), '__aucun__');
$function$;

-- commerce_acheter_matiere(text,text,text,integer) -> jsonb | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_acheter_matiere(p_acteur text, p_entreprise text, p_matiere text, p_qte integer)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT public.commerce_apporter_matiere(
    'appro-legacy-' || md5(random()::text || clock_timestamp()::text),
    p_acteur, p_entreprise, p_matiere, p_qte, 'vente');
$function$;

-- commerce_apporter_matiere(text,text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_apporter_matiere(p_requete text, p_acteur text, p_entreprise text, p_matiere text, p_qte integer, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_deja    record;
  v_data    jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_mode    text := lower(btrim(coalesce(p_mode, 'vente')));
  v_mat     text := btrim(coalesce(p_matiere, ''));
  v_inv     jsonb; v_arg numeric; v_liquide numeric; v_detenu numeric;
  v_sm      jsonb; v_cmm jsonb; v_caisse numeric; v_stock numeric;
  v_plafond numeric; v_declare numeric; v_smc numeric;
  v_prix    numeric; v_total numeric; v_cout_moyen numeric;
  v_categorie text; v_caisse_id text; v_r jsonb; v_inv_apres jsonb;
  v_accepte boolean; v_place numeric; v_refus jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_entreprise, '') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  -- REJEU : on rend le meme verdict sans rien refaire.
  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'mode', v_deja.mode, 'quantite', v_deja.quantite,
                              'qte', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'total', v_deja.montant);
  END IF;

  -- ORDRE DES VERROUS : entreprises puis personnages_donnees.
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type  := coalesce(v_data->>'type', '');
  v_pays  := coalesce(v_data->>'country', 'republic');
  -- La ville ne prend PLUS 'capitale' par defaut : ce repli etait inoffensif tant
  -- qu'il ne servait qu'a nommer une caisse institutionnelle, mais il deviendrait
  -- un mensonge compare a la position du joueur.
  v_ville := coalesce(v_data->>'city', '');

  SELECT coalesce(inventory, '[]'::jsonb), coalesce(arg, 0), coalesce(liquide, 0), coalesce(day, 1)
    INTO v_inv, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- PRESENCE PHYSIQUE. On ne vend ni ne donne a distance.
  IF NOT public.acteur_present_sur_site(p_acteur, v_pays, v_ville,
                                        v_data->>'buildingId', v_data->>'roomId') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LEGALITE. Une matiere interdite par l'Assemblee est hors economie legale : ni
  -- vendue, ni donnee. Le serveur lit la loi lui-meme ; aucun etat legal ne vient
  -- du navigateur.
  v_refus := public.matiere_refus_circuit_legal(p_acteur, v_mat, v_mode);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;

  -- MATIERE ACCEPTEE : deduite des recettes, jamais d'une liste tenue a la main.
  IF v_type = 'armurerie' THEN
    SELECT EXISTS (SELECT 1 FROM public.recettes_production r, jsonb_object_keys(r.materiaux) m
                    WHERE r.pays = v_pays AND m = v_mat) INTO v_accepte;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(coalesce(v_data->'carte', '[]'::jsonb)) c
        JOIN public.recettes_commerce r ON r.id = c.value, jsonb_object_keys(r.materiaux) m
       WHERE m = v_mat) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee'); END IF;

  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  v_sm     := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm    := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  v_stock  := coalesce((v_sm->>v_mat)::numeric, 0);

  -- PLAFOND DE STOCK. L'armurerie n'en a jamais eu : regle metier historique.
  v_place := NULL;
  IF v_type <> 'armurerie' THEN
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_declare := (v_data->'parametres'->'stockMax'->>v_mat)::numeric;
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, coalesce(v_smc, 20))
                      ELSE coalesce(v_smc, 20) END;
    v_place := GREATEST(0, v_plafond - v_stock);
    IF v_stock + p_qte > v_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
    END IF;
  END IF;

  -- PRIX. LA seule difference entre les deux modes, et elle tient en une ligne.
  IF v_mode = 'don' THEN
    v_prix := 0;
  ELSE
    v_prix := (v_data->'parametres'->'prixAchatMatiere'->>v_mat)::numeric;
    IF v_prix IS NULL THEN
      SELECT prix_achat_fournisseur INTO v_prix FROM public.ressources_economie WHERE cle = v_mat;
    END IF;
    IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
    v_prix := GREATEST(0, v_prix);
  END IF;
  v_total := round(v_prix * p_qte, 2);

  -- MOUVEMENT DE CAISSE. v_total = 0 pour un don : la caisse n'est ni lue ni
  -- debitee, un commerce a 0 FR accepte donc le don.
  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  IF v_total > 0 THEN
    IF v_categorie IS NOT NULL THEN
      v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
      v_r := public.caisse_institution_mouvement(v_caisse_id, -v_total, false);
      IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
      END IF;
    ELSE
      IF v_caisse < v_total THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
      END IF;
    END IF;
  END IF;

  -- CMUP : cout moyen pondere sur ce que le commerce a REELLEMENT paye.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>v_mat)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  v_inv_apres := public.inventaire_retirer(v_inv, v_mat, p_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres,
         arg     = v_arg     + v_total,
         liquide = v_liquide + v_total,
         updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data || jsonb_build_object(
    'stockMatieres',     jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[v_mat], to_jsonb(v_cout_moyen)));
  IF v_categorie IS NULL THEN
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_total), true);
  END IF;
  v_data := public.entreprise_ajouter_historique(v_data, -v_total,
    CASE WHEN v_mode = 'don' THEN 'Don de matière première (' ELSE 'Achat de matière première (' END
    || v_mat || ' x' || p_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  INSERT INTO public.apports_matieres
    (requete, fonds_id, acteur, matiere, mode, quantite, prix_unitaire, montant)
  VALUES (p_requete, p_entreprise, p_acteur, v_mat, v_mode, p_qte, v_prix, v_total);

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', p_qte, 'qte', p_qte, 'demandee', p_qte,
    'prixUnitaire', v_prix, 'montant', v_total, 'total', v_total,
    'stock', v_stock + p_qte,
    'placeRestante', CASE WHEN v_place IS NULL THEN NULL ELSE GREATEST(0, v_place - p_qte) END,
    'coutMoyen', v_cout_moyen, 'caisse', v_caisse - v_total,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total, 'inventory', v_inv_apres);
END; $function$;

-- commerce_cout_revient_portion(jsonb,text) -> numeric | plpgsql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_cout_revient_portion(p_data jsonb, p_recette text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE v_r record; v_cout numeric := 0; v_m text; v_q jsonb; v_mo numeric;
BEGIN
  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = p_recette;
  IF NOT FOUND OR COALESCE(v_r.portions, 0) <= 0 THEN RETURN NULL; END IF;
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_r.materiaux) LOOP
    v_cout := v_cout + (v_q#>>'{}')::numeric
              * COALESCE((p_data->'coutMoyenMatieres'->>v_m)::numeric, 0);
  END LOOP;
  SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  RETURN (v_cout + v_r.pa * COALESCE(v_mo, 0)) / v_r.portions;
END; $function$;

-- commerce_fixer_parametres(text,text,jsonb,jsonb,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_fixer_parametres(p_acteur text, p_entreprise text, p_prix_vente jsonb, p_prix_achat_matiere jsonb, p_stock_max jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_param jsonb; v_type text; v_pays text;
  v_k text; v_v jsonb; v_n numeric; v_cout numeric; v_base numeric;
  v_matieres text[];
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'entreprise_absente'); END IF;

  IF COALESCE(v_data->>'proprietaire','PNJ') = 'PNJ'
     OR (v_data->>'proprietaire') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_proprietaire');
  END IF;

  v_type  := COALESCE(v_data->>'type', '');
  v_pays  := COALESCE(v_data->>'country', 'republic');
  v_param := COALESCE(v_data->'parametres', '{}'::jsonb);

  IF v_type = 'armurerie' THEN
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_vente,'{}'::jsonb)) LOOP
      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide', 'cle', v_k); END IF;
      v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], to_jsonb(trunc(v_n)), true);
    END LOOP;

    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_stock_max,'{}'::jsonb)) LOOP
      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide', 'cle', v_k); END IF;
      v_param := jsonb_set(v_param, ARRAY['stockMax', v_k], to_jsonb(trunc(v_n)), true);
    END LOOP;

    SELECT array_agg(DISTINCT m) INTO v_matieres
      FROM public.recettes_production r, jsonb_object_keys(r.materiaux) m
     WHERE r.pays = v_pays;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_achat_matiere,'{}'::jsonb)) LOOP
      IF NOT (v_k = ANY (COALESCE(v_matieres, ARRAY[]::text[]))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide', 'cle', v_k); END IF;
      v_param := jsonb_set(v_param, ARRAY['prixAchatMatiere', v_k], to_jsonb(trunc(v_n)), true);
    END LOOP;

  ELSE
    IF p_stock_max IS NOT NULL AND p_stock_max <> '{}'::jsonb THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_non_modifiable');
    END IF;

    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_vente,'{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(v_k))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'hors_carte', 'cle', v_k);
      END IF;
      IF EXISTS (SELECT 1 FROM public.recettes_commerce WHERE id = v_k AND prix_fixe IS NOT NULL) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_fixe', 'cle', v_k);
      END IF;
      v_cout := public.commerce_cout_revient_portion(v_data, v_k);
      IF v_cout IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue', 'cle', v_k); END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL
         OR v_n < round(v_cout * 1.10, 2) OR v_n > round(v_cout * 1.80, 2) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette', 'cle', v_k,
                                  'min', round(v_cout * 1.10, 2), 'max', round(v_cout * 1.80, 2));
      END IF;
      v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], to_jsonb(v_n), true);
    END LOOP;

    SELECT array_agg(DISTINCT m) INTO v_matieres
      FROM jsonb_array_elements_text(COALESCE(v_data->'carte','[]'::jsonb)) c
      JOIN public.recettes_commerce r ON r.id = c.value,
           jsonb_object_keys(r.materiaux) m;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_achat_matiere,'{}'::jsonb)) LOOP
      IF NOT (v_k = ANY (COALESCE(v_matieres, ARRAY[]::text[]))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'cle', v_k);
      END IF;
      SELECT prix_achat_fournisseur INTO v_base FROM public.ressources_economie WHERE cle = v_k;
      IF v_base IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_fournisseur_absent', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < round(v_base * 0.5, 2) OR v_n > round(v_base * 1.5, 2) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette', 'cle', v_k,
                                  'min', round(v_base * 0.5, 2), 'max', round(v_base * 1.5, 2));
      END IF;
      v_param := jsonb_set(v_param, ARRAY['prixAchatMatiere', v_k], to_jsonb(v_n), true);
    END LOOP;
  END IF;

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_param, true), updated_at = now()
   WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'parametres', v_param);
END; $function$;

-- commerce_production_autorisee(jsonb,text) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.commerce_production_autorisee(p_data jsonb, p_acteur text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT coalesce(p_acteur,'')<>'' AND (
  regexp_replace(coalesce(p_data->>'proprietaire',''),'^pj:','')=regexp_replace(p_acteur,'^pj:','')
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_data->'salaries')='array' THEN p_data->'salaries' ELSE '[]'::jsonb END) s
    WHERE s->'actif'='true'::jsonb AND regexp_replace(s->>'ref','^pj:','')=regexp_replace(p_acteur,'^pj:',''))
  OR (coalesce(p_data->>'buildingId','')<>''
   AND EXISTS (
     SELECT 1 FROM public.personnages_donnees d
      WHERE d.name = p_acteur
        AND d.country = p_data->>'country'
        AND d.current_city = p_data->>'city'
        AND d.current_building = p_data->>'buildingId'
        AND (nullif(p_data->>'roomId','') IS NULL
             OR d.current_room = p_data->>'roomId')
   )));
$function$;

-- commerce_produire(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_produire(p_acteur text, p_entreprise text, p_recette text, p_ordre text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_bat text; v_jour integer;
  v_rec record; v_prod record; v_prix_fixe numeric;
  v_pa_requis integer; v_salaire numeric; v_portions integer; v_materiaux jsonb;
  v_sm jsonb; v_sp jsonb; v_stock numeric; v_plafond numeric; v_declare numeric; v_smc numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text; v_r jsonb;
  v_pa integer; v_arg numeric; v_liquide numeric;
  v_m text; v_q jsonb; v_dispo numeric; v_cout numeric; v_mo numeric;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF NOT public.commerce_production_autorisee(v_data,p_acteur) THEN
    RETURN jsonb_build_object('ok',false,'raison','production_non_autorisee'); END IF;
  v_type := COALESCE(v_data->>'type','');
  v_pays := COALESCE(v_data->>'country','republic');
  v_ville:= COALESCE(v_data->>'city','capitale');
  v_bat  := COALESCE(v_data->>'buildingId','');

  IF v_type = 'armurerie' THEN
    SELECT * INTO v_prod FROM public.recettes_production WHERE id = p_recette AND pays = v_pays;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    v_materiaux := v_prod.materiaux;
    v_portions  := 1;
    v_prix_fixe := NULL;
    SELECT valeur INTO v_pa_requis FROM public.entreprises_constantes WHERE cle = 'pa_production_armurerie';
    SELECT valeur INTO v_salaire   FROM public.entreprises_constantes WHERE cle = 'salaire_production_armurerie';
  ELSE
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = p_recette;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(p_recette))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_carte');
    END IF;
    IF v_rec.types_autorises IS NOT NULL THEN
      IF NOT (v_rec.types_autorises @> jsonb_build_array(to_jsonb(v_type))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'type_non_autorise');
      END IF;
    END IF;
    IF v_rec.pays_autorises IS NOT NULL THEN
      IF NOT (v_rec.pays_autorises @> jsonb_build_array(to_jsonb(v_pays))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_autorise');
      END IF;
    END IF;
    IF v_rec.villes_autorisees IS NOT NULL THEN
      IF NOT (v_rec.villes_autorisees @> jsonb_build_array(to_jsonb(v_ville))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'ville_non_autorisee');
      END IF;
    END IF;
    IF v_rec.buildings_autorises IS NOT NULL THEN
      IF NOT (v_rec.buildings_autorises @> jsonb_build_array(to_jsonb(v_bat))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'batiment_non_autorise');
      END IF;
    END IF;
    v_materiaux := v_rec.materiaux;
    v_portions  := v_rec.portions;
    v_pa_requis := v_rec.pa;
    v_prix_fixe := v_rec.prix_fixe;
    SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
    v_salaire := v_rec.pa * COALESCE(v_mo, 0);
  END IF;

  v_r:=public.restaurant_luthecia_production_verifier(v_data,p_acteur,p_recette);
  IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RETURN v_r; END IF;
  v_sp := COALESCE(v_data->'stockProduits','{}'::jsonb);
  v_stock := COALESCE((v_sp->>p_recette)::numeric, 0);
  v_declare := (v_data->'parametres'->'stockMax'->>p_recette)::numeric;
  IF v_type = 'armurerie' THEN
    v_plafond := v_declare;
  ELSE
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, COALESCE(v_smc,20))
                      ELSE COALESCE(v_smc,20) END;
  END IF;
  IF v_plafond IS NOT NULL AND v_stock + v_portions > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'plafond', v_plafond);
  END IF;

  -- TRANSFORMATION D'UN STOCK (30 septembre 2026). Une loi appliquee peut
  -- interdire de transformer la matiere en produits finis (cas B). Le stock
  -- reste possede et consommable : seule la fabrication est fermee. Verifie
  -- avant toute lecture de stock et toute ecriture.
  IF public.matiere_refus_circuit_legal_lot(p_acteur, v_materiaux, 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, v_materiaux, 'transformation');
  END IF;
  v_sm := COALESCE(v_data->'stockMatieres','{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_dispo := COALESCE((v_sm->>v_m)::numeric, 0);
    IF v_dispo < (v_q#>>'{}')::numeric THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_m, 'disponible', v_dispo);
    END IF;
  END LOOP;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, 0, 0);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','ordre_refuse'));
    END IF;
  END IF;

  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < COALESCE(v_pa_requis,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;

  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  IF v_categorie IS NOT NULL THEN
    v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
    v_r := public.caisse_institution_mouvement(v_caisse_id, -v_salaire, false);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
    END IF;
  ELSE
    IF v_caisse < v_salaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_salaire), true);
  END IF;

  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
             to_jsonb(COALESCE((v_sm->>v_m)::numeric,0) - (v_q#>>'{}')::numeric));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm, true);
  v_data := jsonb_set(v_data, '{stockProduits}',
                      jsonb_set(v_sp, ARRAY[p_recette], to_jsonb(v_stock + v_portions)), true);

  IF v_type <> 'armurerie' THEN
    IF COALESCE(v_data->>'proprietaire','PNJ') = 'PNJ' AND v_prix_fixe IS NULL THEN
      v_cout := public.commerce_cout_revient_portion(v_data, p_recette);
      IF v_cout IS NOT NULL THEN
        v_data := jsonb_set(v_data, ARRAY['parametres','prixVente',p_recette],
                            to_jsonb(round(v_cout * 2)), true);
      END IF;
    END IF;
  END IF;

  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || p_recette || ' (' || v_portions || ' portions) — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  UPDATE public.personnages_donnees
     SET pa = v_pa - COALESCE(v_pa_requis,0),
         arg = v_arg + v_salaire, liquide = v_liquide + v_salaire, updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'recette', p_recette, 'portions', v_portions,
    'salaire', v_salaire, 'paPreleves', COALESCE(v_pa_requis,0),
    'pa', v_pa - COALESCE(v_pa_requis,0), 'arg', v_arg + v_salaire,
    'liquide', v_liquide + v_salaire,
    'stockProduit', v_stock + v_portions,
    'prixVente', v_data->'parametres'->'prixVente'->p_recette);
END; $function$;

-- commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 27/10/2026 : le marche noir passe par crime_acheter_arme_noire (jet, denonciation, trace).
  IF p_mode = 'marche_noir' THEN RETURN jsonb_build_object('ok', false, 'raison', 'marche_noir_par_le_serveur'); END IF;
  -- 27/10/2026 : une arme achetee au comptoir est deposee par arme_acheter.
  IF p_ordre = 'choisir_arme' THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_arme_par_le_serveur'); END IF;
  RETURN public.commerce_vendre_produit_interne(p_acteur, p_entreprise, p_produits, p_mode, p_ordre, p_pa, p_cost, p_regle_pa, NULL);
END; $function$;

-- commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit_interne(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text, p_prix_tournee numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_jour integer;
  v_sp jsonb; v_ligne jsonb; v_id text; v_qte numeric; v_stock numeric; v_prix numeric;
  v_dynamique numeric := 0; v_assiette numeric; v_net numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text;
  v_r jsonb; v_taxe jsonb; v_au_catalogue boolean; v_livraison jsonb := '[]'::jsonb;
  v_rec record; v_arg numeric; v_liquide numeric; v_pa_reste integer; v_libelle text := '';
  v_pa_metier numeric := 0; v_pa_actuel integer;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  IF p_mode NOT IN ('comptoir', 'service', 'marche_noir') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END IF;
  IF p_mode = 'service' AND (COALESCE(p_ordre,'') = '' OR COALESCE(p_cost,0) <= 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_requis');
  END IF;
  IF p_produits IS NULL OR jsonb_typeof(p_produits) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
  END IF;
  IF jsonb_array_length(p_produits) = 0 AND p_mode <> 'service' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
  END IF;

  IF COALESCE(p_regle_pa,'') <> '' THEN
    SELECT valeur INTO v_pa_metier FROM public.entreprises_constantes WHERE cle = p_regle_pa;
    IF v_pa_metier IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'regle_pa_inconnue', 'cle', p_regle_pa);
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_r:=public.restaurant_luthecia_vente_verifier(v_data,p_acteur,p_produits,p_mode,p_ordre);
  IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RETURN v_r; END IF;
  v_type  := COALESCE(v_data->>'type','');
  v_pays  := COALESCE(v_data->>'country','republic');
  v_ville := COALESCE(v_data->>'city','capitale');
  v_sp    := COALESCE(v_data->'stockProduits', '{}'::jsonb);

  FOR v_ligne IN SELECT value FROM jsonb_array_elements(p_produits) LOOP
    v_id  := v_ligne->>'produit';
    v_qte := COALESCE((v_ligne->>'qte')::numeric, 1);
    IF COALESCE(v_id,'') = '' OR v_qte <= 0 OR v_qte <> trunc(v_qte) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'articles_invalides');
    END IF;
    IF v_type = 'armurerie' THEN
      SELECT EXISTS (SELECT 1 FROM public.recettes_production
                      WHERE id = v_id AND pays = v_pays) INTO v_au_catalogue;
    ELSE
      v_au_catalogue := public.restaurant_luthecia_carte(v_data,p_acteur) @> jsonb_build_array(to_jsonb(v_id));
    END IF;
    IF NOT v_au_catalogue THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose', 'produit', v_id);
    END IF;
    v_stock := COALESCE((v_sp->>v_id)::numeric, 0);
    IF v_stock < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                                'produit', v_id, 'stock', v_stock);
    END IF;
    IF p_mode <> 'service' THEN
      v_prix := CASE WHEN public.restaurant_luthecia_est_commerce(v_data) AND v_id LIKE 'menu_gastronomique_%' THEN 125 WHEN public.restaurant_luthecia_est_commerce(v_data) AND v_id IN('champagne_luthecia','cocktail_luthecia') THEN 25 ELSE coalesce(p_prix_tournee, (v_data->'parametres'->'prixVente'->>v_id)::numeric) END;
      IF v_prix IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_defini', 'produit', v_id);
      END IF;
      v_dynamique := v_dynamique + v_prix * v_qte
                     * CASE WHEN p_mode = 'marche_noir' THEN 3 ELSE 1 END;
    END IF;
  END LOOP;

  SELECT COALESCE(day,1), COALESCE(pa,0) INTO v_jour, v_pa_actuel
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa_metier > 0 AND v_pa_actuel < v_pa_metier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa_actuel);
  END IF;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'),
                                'detail', v_r);
    END IF;
  END IF;

  IF v_pa_metier > 0 THEN
    UPDATE public.personnages_donnees SET pa = GREATEST(0, pa - v_pa_metier), updated_at = now()
     WHERE name = p_acteur;
  END IF;

  IF v_dynamique > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_dynamique) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'total', v_dynamique);
    END IF;
  END IF;

  SELECT COALESCE(arg,0), COALESCE(liquide,0), COALESCE(pa,0)
    INTO v_arg, v_liquide, v_pa_reste
    FROM public.personnages_donnees WHERE name = p_acteur;

  v_assiette := CASE p_mode WHEN 'service' THEN COALESCE(p_cost,0) ELSE v_dynamique END;
  IF p_mode = 'marche_noir' THEN
    v_net := 0;
  ELSE
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_assiette);
    v_net := COALESCE((v_taxe->>'net')::numeric, v_assiette);
    v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
    IF v_categorie IS NOT NULL THEN
      v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
      PERFORM public.caisse_institution_mouvement(v_caisse_id, v_net, false);
    ELSE
      v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
      v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_net), true);
    END IF;
  END IF;

  FOR v_ligne IN SELECT value FROM jsonb_array_elements(p_produits) LOOP
    v_id  := v_ligne->>'produit';
    v_qte := COALESCE((v_ligne->>'qte')::numeric, 1);
    v_stock := COALESCE((v_sp->>v_id)::numeric, 0);
    v_sp := jsonb_set(v_sp, ARRAY[v_id], to_jsonb(v_stock - v_qte));
    v_libelle := v_libelle || CASE WHEN v_libelle = '' THEN '' ELSE ', ' END || v_id || ' x' || v_qte;
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = v_id;
    v_livraison := v_livraison || jsonb_build_array(jsonb_build_object(
      'produit', v_id, 'qte', v_qte,
      'prixUnitaire', coalesce(p_prix_tournee, (v_data->'parametres'->'prixVente'->>v_id)::numeric),
      'label', v_rec.label, 'categorie', v_rec.categorie,
      'effets', COALESCE(v_rec.effets, '{}'::jsonb), 'icone', v_rec.icone,
      'image', v_rec.image, 'description', v_rec.description,
      'familleProduitMarche', v_rec.famille_produit_marche,
      'bonusIntegrationVille', v_rec.bonus_integration_ville));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockProduits}', v_sp, true);

  v_data := public.entreprise_ajouter_historique(v_data, v_net,
              CASE WHEN p_mode = 'marche_noir' THEN 'Vol — ' ELSE 'Vente — ' END
              || COALESCE(NULLIF(v_libelle,''), 'prestation') || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  -- La chambre payee survit meme si le navigateur se ferme avant sa sauvegarde.
  -- Aucun second paiement : meme transaction que payer_ordre, taxe et caisse ci-dessus.
  IF public.restaurant_luthecia_est_commerce(v_data) AND p_ordre='reserver_chambre_hotel' THEN
    PERFORM public.hotel_nuitee_ajouter_interne(p_acteur,'hotel-republica');
  END IF;

  RETURN jsonb_build_object('ok', true, 'mode', p_mode,
    'total', v_dynamique, 'assiette', v_assiette, 'net', v_net,
    'paMetier', v_pa_metier,
    'arg', v_arg, 'liquide', v_liquide, 'pa', v_pa_reste,
    'livraison', v_livraison);
END; $function$;

-- consommer_sur_place_commerce(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.consommer_sur_place_commerce(p_requete text, p_acheteur text, p_fonds_id text, p_reference_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_fonds jsonb; v_ref jsonb; v_rec record; v_achat jsonb; v_id text; v_effets jsonb; v_hp integer; v_moral integer; v_nom text;
BEGIN
 PERFORM public.exiger_acteur(p_acheteur);
 IF left(coalesce(p_acheteur,''),5)='orga:' THEN RETURN jsonb_build_object('ok',false,'raison','consommation_reservee_pj'); END IF;
 SELECT data INTO v_fonds FROM public.entreprises WHERE id=p_fonds_id;
 IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','fonds_absent'); END IF;
 IF NOT coalesce(v_fonds->'typesAutorises','[]'::jsonb) ? 'bar-restauration' THEN RETURN jsonb_build_object('ok',false,'raison','activite_sur_place_absente'); END IF;
 v_ref:=v_fonds->'references'->p_reference_id;
 IF v_ref IS NULL OR coalesce(v_ref->>'recette_id','')='' THEN RETURN jsonb_build_object('ok',false,'raison','recette_absente'); END IF;
 SELECT effets,generique_id INTO v_effets,v_id FROM public.recettes_commerce WHERE id=v_ref->>'recette_id';
 IF NOT FOUND OR v_id IS DISTINCT FROM v_ref->>'generique_id' THEN RETURN jsonb_build_object('ok',false,'raison','recette_invalide'); END IF;
 IF NOT (coalesce(v_ref->>'generique_id','') IN ('boisson','encas','encas-a-emporter','plat-simple','plat-elabore','menu-gastronomique','aliment-prepare')) THEN RETURN jsonb_build_object('ok',false,'raison','produit_non_consommable'); END IF;
 PERFORM set_config('hg.consommation_sur_place','on',true);
 v_achat:=public.acheter_produit_commerce_interne(p_requete,p_acheteur,p_fonds_id,p_reference_id,1);
 PERFORM set_config('hg.consommation_sur_place','',true);
 IF coalesce((v_achat->>'ok')::boolean,false) IS NOT TRUE OR coalesce((v_achat->>'rejeu')::boolean,false) THEN RETURN v_achat; END IF;
 SELECT value #>> '{}' INTO v_id FROM jsonb_array_elements(v_achat->'livraisons') LIMIT 1;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Livraison absente: annulation transaction'; END IF;
 DELETE FROM public.objets_recus WHERE id=v_id AND destinataire=regexp_replace(p_acheteur,'^pj:','');
 IF NOT FOUND THEN RAISE EXCEPTION 'Livraison introuvable: annulation transaction'; END IF;
 v_hp:=greatest(0,least(100,coalesce((v_effets->>'hp')::integer,0)));
 v_moral:=greatest(0,least(100,coalesce((v_effets->>'moral')::integer,0)));
 v_nom:=regexp_replace(p_acheteur,'^pj:','');
 UPDATE public.personnages_donnees SET hp=least(100,coalesce(hp,0)+v_hp),moral=least(100,coalesce(moral,0)+v_moral) WHERE name=v_nom;
 IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable: annulation transaction'; END IF;
 RETURN v_achat || jsonb_build_object('consommeSurPlace',true,'effets',jsonb_build_object('hp',v_hp,'moral',v_moral));
END $function$;
