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

  -- Place restante : meme regle que addToInventory (plafond global de 100, toutes
  -- lignes confondues, qty ou encombrement a defaut).
  SELECT coalesce(sum(coalesce((e->>'qty')::numeric, (e->>'encombrement')::numeric, 1)), 0)::int
    INTO v_occupe FROM jsonb_array_elements(v_inv) e;
  v_place := greatest(0, 100 - v_occupe);

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

-- acheter_produit_commerce(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.acheter_produit_commerce(p_requete text, p_acheteur text, p_fonds_id text, p_reference_id text, p_quantite integer)
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
  IF NOT v_gen.individualise AND NOT v_gen.empilable THEN
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
    'provenance',   jsonb_build_object(
                      'fondsId',     p_fonds_id,
                      'referenceId', p_reference_id,
                      'createur',    v_fonds->>'proprietaire',
                      'etapes',      '[]'::jsonb)
  ));

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

  IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

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
  v_depense numeric := 0;
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
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
             v_entrepot || jsonb_build_object('stock', v_stock,
               'caisse', coalesce((v_entrepot->>'caisse')::numeric,0) + v_depense)))::text),
           updated_at = now()
     WHERE id = v_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'depense', v_depense,
                            'stockChantier', v_nouveau_chantier);
END; $function$;

-- capacite_entrepot() -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.capacite_entrepot()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT 5000; $function$;

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
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
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

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, p_apport) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'apport', p_apport);
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_chantier := v_pal.gabarit
                || jsonb_build_object('jourDebut', v_jour,
                                      'totalVerse', p_apport, 'tresorerie', p_apport);

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_chantier))::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'chantier', v_chantier, 'apport', p_apport,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- chantier_travailler(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.chantier_travailler(p_acteur text, p_pays text, p_batiment text, p_heures integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_data jsonb; v_ch jsonb; v_stock jsonb; v_besoin record;
  v_jour_num integer; v_fraction numeric := 1; v_capacite numeric; v_utiles numeric;
  v_faites numeric; v_restantes numeric; v_tresorerie numeric; v_payables numeric;
  v_taux numeric; v_pa integer; v_arg numeric; v_liquide numeric; v_jour integer;
  v_heures integer; v_montant numeric; v_m text; v_req numeric; v_dispo numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_heures, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'heures_invalides');
  END IF;
  v_id := p_pays || '_' || p_batiment;

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

  v_ch := v_data->'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;
  -- Le besoin quotidien d'un reamenagement se derive de SON budget, pas du cycle de construction :
  -- ce chemin n'est pas couvert ici et reste a traiter separement.
  IF COALESCE(v_ch->>'type','') <> 'construction' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert', 'type', v_ch->>'type');
  END IF;

  -- --- Borne 2 : heures encore utiles aujourd'hui --------------------------
  v_jour_num := floor(GREATEST(0, COALESCE((v_ch->>'progressionJours')::numeric, 0)))::integer + 1;
  SELECT * INTO v_besoin FROM public.chantiers_besoins_jour
   WHERE position_cycle = ((v_jour_num - 1) % (SELECT count(*) FROM public.chantiers_besoins_jour)) + 1;
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
  v_utiles   := floor(v_capacite * v_fraction);
  v_faites   := GREATEST(0, COALESCE((v_ch->>'heuresFaites')::numeric, 0));
  v_restantes := GREATEST(0, v_utiles - v_faites);

  -- --- Bornes 3 et 4 : PA reels et tresorerie reelle -----------------------
  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_tresorerie := GREATEST(0, COALESCE((v_ch->>'tresorerie')::numeric, 0));
  v_payables   := floor(v_tresorerie / v_taux);

  v_heures := GREATEST(0, LEAST(p_heures, v_restantes, v_pa, v_payables))::integer;
  IF v_heures <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_heure_travaillable',
      'utilesRestantes', v_restantes, 'pa', v_pa, 'payables', v_payables,
      'fractionMateriaux', round(v_fraction, 4));
  END IF;
  v_montant := v_heures * v_taux;

  -- --- Application, tout ou rien -------------------------------------------
  v_ch := v_ch || jsonb_build_object(
    'heuresFaites', v_faites + v_heures,
    'tresorerie', v_tresorerie - v_montant,
    'travauxPJ', COALESCE(v_ch->'travauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('nom', p_acteur, 'heures', v_heures, 'montant', v_montant,
                         'jour', v_jour)));

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_ch))::text, updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET pa = v_pa - v_heures, arg = v_arg + v_montant, liquide = v_liquide + v_montant,
         updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'heures', v_heures, 'montant', v_montant,
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

-- commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text)
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
      v_au_catalogue := COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(v_id));
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
      v_prix := (v_data->'parametres'->'prixVente'->>v_id)::numeric;
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
      'prixUnitaire', (v_data->'parametres'->'prixVente'->>v_id)::numeric,
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

  RETURN jsonb_build_object('ok', true, 'mode', p_mode,
    'total', v_dynamique, 'assiette', v_assiette, 'net', v_net,
    'paMetier', v_pa_metier,
    'arg', v_arg, 'liquide', v_liquide, 'pa', v_pa_reste,
    'livraison', v_livraison);
END; $function$;

-- creer_fonds_commerce(text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.creer_fonds_commerce(p_proprietaire text, p_bail_id text, p_fonds_id text, p_apport integer, p_enseigne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bail jsonb;
  v_apport integer := GREATEST(0, COALESCE(p_apport, 0));
  v_lot text;
  v_deja integer;
  v_vocation text;
BEGIN
  PERFORM public.exiger_acteur(p_proprietaire);
  IF COALESCE(p_proprietaire, '') = '' OR COALESCE(p_bail_id, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
  SELECT count(*) INTO v_deja FROM entreprises WHERE id = p_fonds_id;
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_id_deja_pris'; END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RAISE EXCEPTION 'bail_absent'; END IF;
  IF (v_bail ->> 'locataire') IS DISTINCT FROM p_proprietaire
     AND ('pj:' || COALESCE(v_bail ->> 'locataire', '')) IS DISTINCT FROM p_proprietaire THEN
    RAISE EXCEPTION 'pas_titulaire';
  END IF;

  v_vocation := public.local_vocation_commerciale(v_bail ->> 'buildingId');
  IF v_vocation IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'local_non_commercial',
                              'batiment', v_bail ->> 'buildingId');
  END IF;

  SELECT count(*) INTO v_deja FROM entreprises
   WHERE data -> 'implantation' ->> 'bailId' = p_bail_id
     AND COALESCE(data ->> 'statut', 'actif') = 'actif';
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_deja_present'; END IF;
  v_lot := v_bail ->> 'lotId';
  INSERT INTO entreprises (id, data, updated_at)
  VALUES (p_fonds_id, jsonb_build_object(
    'id', p_fonds_id,
    'version', 2,
    'type', 'fonds_commerce',
    'enseigne', COALESCE(NULLIF(btrim(COALESCE(p_enseigne, '')), ''), 'Fonds de commerce'),
    'proprietaire', p_proprietaire,
    'statut', 'actif',
    'caisse', v_apport,
    'implantation', jsonb_build_object(
      'country', v_bail ->> 'country', 'city', v_bail ->> 'city',
      'buildingId', v_bail ->> 'buildingId', 'roomId', v_bail ->> 'roomId',
      'lotId', v_lot, 'localKey', v_bail ->> 'localKey', 'bailId', p_bail_id,
      'vocation', v_vocation),
    'typesAutorises',      '[]'::jsonb,
    'references',          '{}'::jsonb,
    'stockReferences',     '{}'::jsonb,
    'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres',       '{}'::jsonb,
    'coutMoyenMatieres',   '{}'::jsonb,
    'stockProduits',       '{}'::jsonb,
    'historique', jsonb_build_array(jsonb_build_object(
      'evenement', 'creation', 'proprietaire', p_proprietaire, 'apport', v_apport,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')))
  ), now());
  UPDATE locations_actives SET data = v_bail || jsonb_build_object('fondsId', p_fonds_id) WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'caisse', v_apport,
                            'apport', v_apport, 'proprietaire', p_proprietaire,
                            'vocation', v_vocation, 'typesMax', public.fonds_types_max(p_proprietaire));
END;
$function$;

-- creer_oeuvre(text,text,text,text,integer,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.creer_oeuvre(p_auteur text, p_type text, p_titre text, p_country text, p_jour integer, p_contenu text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auteur  text := NULLIF(btrim(COALESCE(p_auteur, '')), '');
  v_type    text := lower(btrim(COALESCE(p_type, '')));
  v_titre   text := btrim(COALESCE(p_titre, ''));
  v_contenu text := COALESCE(p_contenu, '');
  v_data    jsonb;
  v_id      text;
  v_deja    text;
BEGIN
  PERFORM public.exiger_acteur(p_auteur);
  IF v_titre = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_requis'); END IF;
  IF length(v_titre) > 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_trop_long'); END IF;
  IF v_type !~ '^[a-z][a-z0-9_]{1,39}$' THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  IF length(v_contenu) > 200000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'contenu_trop_volumineux'); END IF;
  IF v_auteur IS NOT NULL AND NOT ref_patrimoine_existe(v_auteur) THEN RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inexistant'); END IF;
  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'auteur' - 'created_at' - 'updated_at';
  IF length(v_data::text) > 8000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'data_trop_volumineux'); END IF;
  SELECT id INTO v_deja FROM oeuvres WHERE type = v_type AND titre = v_titre AND COALESCE(auteur, '') = COALESCE(v_auteur, '') LIMIT 1;
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true); END IF;
  v_id := 'oeuvre-' || extract(epoch from clock_timestamp())::bigint || '-' || substr(md5(random()::text || COALESCE(v_auteur, '') || v_titre), 1, 8);
  INSERT INTO oeuvres (id, type, titre, auteur, country, jour, contenu, data)
  VALUES (v_id, v_type, v_titre, v_auteur, NULLIF(btrim(COALESCE(p_country, '')), ''), p_jour, NULLIF(v_contenu, ''), v_data);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false);
END;
$function$;

-- creer_offre(text,text,text,text,integer,bigint,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.creer_offre(p_emetteur text, p_destinataire text, p_type text, p_actif text, p_montant integer, p_duree_ms bigint, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_offres_max constant integer := 20;
  c_duree_min constant bigint := 3600000;
  c_duree_max constant bigint := 30 * 24 * 3600000;
  c_duree_defaut constant bigint := 3 * 24 * 3600000;
  v_em text := btrim(COALESCE(p_emetteur, ''));
  v_de text := btrim(COALESCE(p_destinataire, ''));
  v_type text := btrim(COALESCE(p_type, ''));
  v_actif text := NULLIF(btrim(COALESCE(p_actif, '')), '');
  v_montant integer := GREATEST(0, COALESCE(p_montant, 0));
  v_duree bigint; v_data jsonb; v_id text; v_deja text; v_ouvertes integer; v_fonds jsonb; v_bail jsonb; v_locataire text; v_bailleur text;
BEGIN
  PERFORM public.exiger_acteur(p_emetteur);
  IF v_em = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_requis'); END IF;
  IF v_de = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_requis'); END IF;
  IF v_em = v_de THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_identique'); END IF;
  IF v_type NOT IN ('vente_objet', 'vente_fonds', 'resiliation_amiable', 'prestation') THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  IF NOT ref_patrimoine_existe(v_em) THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_inexistant'); END IF;
  IF NOT ref_patrimoine_existe(v_de) THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_inexistant'); END IF;
  v_duree := COALESCE(NULLIF(p_duree_ms, 0), c_duree_defaut);
  IF v_duree < c_duree_min THEN v_duree := c_duree_min; END IF;
  IF v_duree > c_duree_max THEN v_duree := c_duree_max; END IF;
  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'type' - 'emetteur' - 'destinataire' - 'montant' - 'statut' - 'expire_a' - 'created_at' - 'resolu_a';
  IF length(v_data::text) > 4000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'termes_trop_volumineux'); END IF;
  IF v_type = 'vente_fonds' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_requis'); END IF;
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_actif;
    IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
    IF (v_fonds ->> 'proprietaire') IS DISTINCT FROM v_em THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  ELSIF v_type = 'resiliation_amiable' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_requis'); END IF;
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_actif;
    IF v_bail IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_absent'); END IF;
    v_locataire := COALESCE(v_bail ->> 'locataireRef', 'pj:' || COALESCE(v_bail ->> 'locataire', ''));
    SELECT (data::jsonb ->> 'proprietaire') INTO v_bailleur FROM terrains_etat WHERE id = (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');
    IF NOT ((v_em = v_locataire AND v_de = v_bailleur) OR (v_em = v_bailleur AND v_de = v_locataire)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_partie_au_bail'); END IF;
  END IF;
  SELECT count(*) INTO v_ouvertes FROM offres WHERE emetteur = v_em AND statut = 'ouverte' AND expire_a > now();
  IF v_ouvertes >= c_offres_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'quota_offres_ouvertes', 'plafond', c_offres_max); END IF;
  SELECT id INTO v_deja FROM offres WHERE emetteur = v_em AND destinataire = v_de AND type = v_type AND COALESCE(actif, '') = COALESCE(v_actif, '') AND montant = v_montant AND statut = 'ouverte' AND expire_a > now() LIMIT 1;
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true); END IF;
  v_id := 'offre-' || extract(epoch from clock_timestamp())::bigint || '-' || substr(md5(random()::text || v_em || v_de), 1, 8);
  INSERT INTO offres (id, type, emetteur, destinataire, actif, montant, statut, data, expire_a)
  VALUES (v_id, v_type, v_em, v_de, v_actif, v_montant, 'ouverte', v_data, now() + make_interval(secs => v_duree / 1000.0));
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false, 'statut', 'ouverte', 'montant', v_montant, 'expireDansMs', v_duree);
END;
$function$;

-- employer_fonds(text,text,text,text,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.employer_fonds(p_employeur text, p_fonds_id text, p_salarie text, p_role text, p_taux integer, p_actif boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_fonds jsonb; v_salaries jsonb; v_trouve boolean:=false; v_i integer; v_taux integer:=GREATEST(0,COALESCE(p_taux,0));
BEGIN
  PERFORM public.exiger_acteur(p_employeur);
  IF COALESCE(p_employeur,'')='' OR COALESCE(p_fonds_id,'')='' OR COALESCE(p_salarie,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF p_employeur=p_salarie THEN RETURN jsonb_build_object('ok',false,'raison','auto_embauche'); END IF;
  SELECT data INTO v_fonds FROM entreprises WHERE id=p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','fonds_absent'); END IF;
  IF (v_fonds->>'proprietaire') IS DISTINCT FROM p_employeur THEN RETURN jsonb_build_object('ok',false,'raison','pas_proprietaire'); END IF;
  IF left(p_salarie,3)='pj:' AND NOT EXISTS(SELECT 1 FROM personnages WHERE name=substr(p_salarie,4)) THEN RETURN jsonb_build_object('ok',false,'raison','salarie_absent'); END IF;
  v_salaries:=COALESCE(v_fonds->'salaries','[]'::jsonb);
  IF jsonb_array_length(v_salaries)>0 THEN
    FOR v_i IN 0..jsonb_array_length(v_salaries)-1 LOOP
      IF (v_salaries->v_i->>'ref')=p_salarie THEN
        v_salaries:=jsonb_set(v_salaries,ARRAY[v_i::text],(v_salaries->v_i)||jsonb_build_object('role',COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''),'Employé'),'tauxHoraire',v_taux,'actif',COALESCE(p_actif,true)));
        v_trouve:=true;
      END IF;
    END LOOP;
  END IF;
  IF NOT v_trouve THEN
    IF COALESCE(p_actif,true) IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','salarie_inconnu'); END IF;
    v_salaries:=v_salaries||jsonb_build_array(jsonb_build_object('ref',p_salarie,'role',COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''),'Employé'),'tauxHoraire',v_taux,'actif',true,'depuis',to_char(now() AT TIME ZONE 'Europe/Paris','YYYY-MM-DD')));
  END IF;
  UPDATE entreprises SET data=jsonb_set(v_fonds,'{salaries}',v_salaries),updated_at=now() WHERE id=p_fonds_id;
  RETURN jsonb_build_object('ok',true,'salarie',p_salarie,'actif',COALESCE(p_actif,true),'tauxHoraire',v_taux,'nouveau',NOT v_trouve);
END;
$function$;

-- entrepot_caisse_lire(text) -> numeric | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_caisse_lire(p_id text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data) -> 'entrepot' -> 'caisse') = 'number'
              THEN (public.batiment_etat_lire(e.data) -> 'entrepot' ->> 'caisse')::numeric
              ELSE 0 END
    FROM public.batiments_etat e WHERE e.id = p_id;
$function$;

-- entrepot_capacite_disponible(text,text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_capacite_disponible(p_entrepot_id text, p_ressource text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0, public.capacite_entrepot()
    - coalesce((SELECT (public.batiment_etat_lire(data)->'entrepot'->'stock'->>p_ressource)::numeric
                  FROM public.batiments_etat WHERE id = p_entrepot_id), 0)
    - coalesce((SELECT sum(quantite) FROM public.entrepot_transits
                 WHERE destination_id = p_entrepot_id AND ressource = p_ressource), 0))::int;
$function$;

-- entrepot_commander(text,text,integer,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_commander(p_acteur text, p_ressource text, p_quantite integer, p_fournisseur_type text, p_fournisseur_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dest_id text; v_dest_ville text;
  v_prix numeric; v_fret numeric := 0; v_total numeric;
  v_cap integer; v_delai integer; v_libelle text;
  v_etat_d jsonb; v_ent_d jsonb; v_caisse_d numeric;
  v_etat_f jsonb; v_ent_f jsonb; v_caisse_f numeric; v_stock_f numeric;
  v_ids text[]; v_i text; v_arrivee date;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_quantite IS NULL OR p_quantite <= 0 OR p_quantite <> floor(p_quantite) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;

  SELECT entrepot_id, ville INTO v_dest_id, v_dest_ville
    FROM public.entrepot_du_directeur(p_acteur);
  IF v_dest_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_fournisseur_type = 'entrepot' AND p_fournisseur_id = v_dest_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_est_soi_meme');
  END IF;

  -- --- Verrouillage ordonne des lignes touchees --------------------------------
  v_ids := CASE WHEN p_fournisseur_type IN ('entrepot', 'port')
                THEN ARRAY(SELECT unnest(ARRAY[v_dest_id, p_fournisseur_id]) ORDER BY 1)
                ELSE ARRAY[v_dest_id] END;
  FOREACH v_i IN ARRAY v_ids LOOP
    PERFORM 1 FROM public.batiments_etat WHERE id = v_i FOR UPDATE;
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat_d FROM public.batiments_etat WHERE id = v_dest_id;
  IF v_etat_d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent_d := coalesce(v_etat_d->'entrepot', '{}'::jsonb);
  v_caisse_d := coalesce((v_ent_d->>'caisse')::numeric, 0);

  -- --- Le fournisseur : prix, stock, delai, libelle -----------------------------
  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    v_delai := 1;
    SELECT public.batiment_etat_lire(data) INTO v_etat_f FROM public.batiments_etat WHERE id = p_fournisseur_id;
    IF v_etat_f IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable'); END IF;

    IF p_fournisseur_type = 'entrepot' THEN
      v_ent_f := coalesce(v_etat_f->'entrepot', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      -- Prix AFFICHE par le fournisseur : son prix manuel s'il en a pose un, sinon le prix de
      -- reference. Le vendeur ne peut pas refuser : s'il affiche, il vend.
      v_prix := coalesce((v_ent_f->'prixManuel'->>p_ressource)::numeric,
                         (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource));
    ELSE
      -- Port industriel : son stock institutionnel en attente de repartition, au prix de reference.
      v_ent_f := coalesce(v_etat_f->'port', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      v_prix := (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource);
    END IF;

    IF v_stock_f < p_quantite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_fournisseur_insuffisant',
                                'disponible', v_stock_f);
    END IF;
    v_libelle := p_fournisseur_id;
  ELSIF p_fournisseur_type = 'etranger' THEN
    v_delai := 2;
    SELECT prix_unitaire, libelle INTO v_prix, v_libelle
      FROM public.fournisseurs_etrangers()
     WHERE pays = p_fournisseur_id AND ressource = p_ressource;
    IF v_prix IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable');
    END IF;
    -- EMBARGO : seules les NOUVELLES commandes sont interdites. Ce qui est deja paye et en
    -- transit poursuit sa route -- aucun effet retroactif.
    IF public.embargo_actif('republic', p_fournisseur_id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'embargo', 'pays', p_fournisseur_id);
    END IF;
    v_fret := public.fret_unitaire_international();
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_type_inconnu');
  END IF;

  -- --- Capacite du destinataire, transit compris --------------------------------
  v_cap := public.entrepot_capacite_disponible(v_dest_id, p_ressource);
  IF v_cap < p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante',
                              'capacite_disponible', v_cap, 'plafond', public.capacite_entrepot());
  END IF;

  -- --- Tresorerie ---------------------------------------------------------------
  v_total := round(p_quantite * (v_prix + v_fret), 2);
  IF v_caisse_d < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante',
                              'caisse', v_caisse_d, 'montant', v_total);
  END IF;

  -- --- Mouvements : tout ou rien -------------------------------------------------
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat_d || jsonb_build_object('entrepot',
           v_ent_d || jsonb_build_object('caisse', round(v_caisse_d - v_total, 2))))::text),
         updated_at = now()
   WHERE id = v_dest_id;

  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    -- Le stock part immediatement de chez le fournisseur : il ne peut pas etre vendu deux fois.
    -- Le fret n'est PAS verse au vendeur -- c'est un cout logistique absorbe.
    IF p_fournisseur_type = 'entrepot' THEN
      v_caisse_f := coalesce((v_ent_f->>'caisse')::numeric, 0);
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)))
        || jsonb_build_object('caisse', round(v_caisse_f + round(p_quantite * v_prix, 2), 2));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('entrepot', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
    ELSE
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('port', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
      -- Le produit de la vente du Port va a SA caisse institutionnelle, la ou vont deja ses
      -- autres recettes (criee, dedouanement).
      PERFORM public.caisse_institution_mouvement('republic_port-sainte-marie',
                                                  round(p_quantite * v_prix, 2), false);
    END IF;
  END IF;

  v_arrivee := ((now() AT TIME ZONE 'utc')::date + v_delai);
  INSERT INTO public.entrepot_transits (destination_id, ressource, quantite, origine_type,
    origine_id, origine_libelle, prix_unitaire, fret_unitaire, montant_total, arrivee_le, commande_par)
  VALUES (v_dest_id, p_ressource, p_quantite, p_fournisseur_type,
    CASE WHEN p_fournisseur_type = 'etranger' THEN NULL ELSE p_fournisseur_id END,
    v_libelle, v_prix, v_fret, v_total, v_arrivee, p_acteur);

  INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
    quantite, prix_unitaire, fret_unitaire, montant, statut, arrivee_le, acteur)
  VALUES (v_dest_id, 'commande_directe', 'entree', v_libelle, p_ressource,
    p_quantite, v_prix, v_fret, v_total, 'en_transit', v_arrivee, p_acteur);

  IF p_fournisseur_type = 'entrepot' THEN
    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (p_fournisseur_id, 'commande_directe', 'sortie', v_dest_id, p_ressource,
      p_quantite, v_prix, 0, round(p_quantite * v_prix, 2), 'comptant', p_acteur);
  END IF;

  RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite,
    'prix_unitaire', v_prix, 'fret_unitaire', v_fret, 'montant', v_total,
    'arrivee_le', v_arrivee, 'delai_jours', v_delai,
    'caisse', round(v_caisse_d - v_total, 2), 'fournisseur', v_libelle);
END; $function$;

-- entrepot_du_directeur(text) -> TABLE(entrepot_id text, ville text, batiment text) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_du_directeur(p_acteur text)
 RETURNS TABLE(entrepot_id text, ville text, batiment text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'republic_' || e.ville || '_' || e.building_id, e.ville, e.building_id
    FROM public.personnages_donnees p
    JOIN public.entrepots_par_ville e ON e.ville = p.poste->>'city'
   WHERE p.name = p_acteur AND p.poste->>'id' = 'directeur_entrepot';
$function$;

-- entrepot_fixer_desiderata(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_fixer_desiderata(p_acteur text, p_desiderata jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_etat jsonb; v_ent jsonb; v_d jsonb := '{}'::jsonb;
        v_cle text; v_val numeric; v_cap integer := public.capacite_entrepot();
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT entrepot_id INTO v_id FROM public.entrepot_du_directeur(p_acteur);
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_desiderata IS NULL OR jsonb_typeof(p_desiderata) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'desiderata_absents');
  END IF;

  -- Validation AVANT toute ecriture : une seule valeur invalide annule l'ensemble.
  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(p_desiderata) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    IF v_val IS NULL OR NOT (v_val = v_val) OR v_val < 0 OR v_val > v_cap OR v_val <> floor(v_val) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'desiderata_invalide', 'cle', v_cle,
                                'min', 0, 'max', v_cap);
    END IF;
    v_d := jsonb_set(v_d, ARRAY[v_cle], to_jsonb(v_val::int));
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
           v_ent || jsonb_build_object('desiderata', v_d, 'desiderataPar', p_acteur)))::text),
         updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'desiderata', v_d, 'entrepot', v_id);
END; $function$;

-- entrepot_livrer_transits() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_livrer_transits()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ligne record; v_etat jsonb; v_ent jsonb; v_stock numeric; v_place integer;
  v_recu integer; v_perdu integer; v_livrees int := 0; v_unites int := 0; v_pertes int := 0;
BEGIN
  FOR v_ligne IN
    SELECT * FROM public.entrepot_transits
     WHERE arrivee_le <= (now() AT TIME ZONE 'utc')::date
     ORDER BY cree_le
     FOR UPDATE
  LOOP
    SELECT public.batiment_etat_lire(data) INTO v_etat
      FROM public.batiments_etat WHERE id = v_ligne.destination_id FOR UPDATE;
    IF v_etat IS NULL THEN CONTINUE; END IF;   -- entrepot disparu : la ligne reste, on reessaiera

    v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);
    v_stock := coalesce((v_ent->'stock'->>v_ligne.ressource)::numeric, 0);
    -- La place est recalculee A LA LIVRAISON : entre la commande et l'arrivee, une livraison
    -- automatique a pu remplir l'entrepot. La capacite reservee a la commande rend ce cas tres
    -- improbable, mais on ne fait jamais deborder un entrepot en silence.
    v_place := greatest(0, public.capacite_entrepot() - v_stock::int);
    v_recu := least(v_ligne.quantite, v_place);
    v_perdu := v_ligne.quantite - v_recu;

    IF v_recu > 0 THEN
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
               v_ent || jsonb_build_object('stock',
                 jsonb_set(coalesce(v_ent->'stock', '{}'::jsonb),
                           ARRAY[v_ligne.ressource], to_jsonb(v_stock + v_recu)))))::text),
             updated_at = now()
       WHERE id = v_ligne.destination_id;
    END IF;

    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (v_ligne.destination_id,
      CASE WHEN v_ligne.origine_type = 'auto' THEN 'approvisionnement_auto' ELSE 'commande_directe' END,
      'entree', v_ligne.origine_libelle, v_ligne.ressource, v_recu,
      v_ligne.prix_unitaire, v_ligne.fret_unitaire, v_ligne.montant_total,
      CASE WHEN v_perdu > 0 THEN 'livre_partiel_capacite' ELSE 'livre' END, v_ligne.commande_par);

    DELETE FROM public.entrepot_transits WHERE id = v_ligne.id;
    v_livrees := v_livrees + 1;
    v_unites := v_unites + v_recu;
    v_pertes := v_pertes + v_perdu;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'lignes_livrees', v_livrees,
                            'unites_livrees', v_unites, 'unites_perdues_capacite', v_pertes);
END; $function$;

-- entrepot_reverser(text,numeric,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_reverser(p_entrepot_id text, p_montant numeric, p_mode text, p_acteur text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_roulement constant numeric := 5000;   -- fonds de roulement permanent (regle GD)
  v_pays text; v_ville text; v_etat jsonb; v_caisse numeric;
  v_mairie text; v_verse numeric; v_jour date; v_id text;
BEGIN
  -- L'identifiant est <pays>_<ville>_<batiment> : on en derive pays et ville.
  v_pays  := split_part(p_entrepot_id, '_', 1);
  v_ville := split_part(p_entrepot_id, '_', 2);
  IF v_pays = '' OR v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_invalide');
  END IF;

  -- Verrou de ligne : deux reversements simultanes se serialisent.
  SELECT public.batiment_etat_lire(e.data) INTO v_etat
    FROM public.batiments_etat e WHERE e.id = p_entrepot_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable');
  END IF;

  v_caisse := CASE WHEN jsonb_typeof(v_etat -> 'entrepot' -> 'caisse') = 'number'
                   THEN (v_etat -> 'entrepot' ->> 'caisse')::numeric ELSE 0 END;

  v_mairie := public.salaire_caisse_de('maire', v_pays, v_ville);
  IF v_mairie IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mairie_introuvable', 'ville', v_ville);
  END IF;

  IF p_mode = 'automatique' THEN
    v_verse := greatest(0, v_caisse - c_roulement);
  ELSE
    -- Virement volontaire : borne par la tresorerie REELLE, jamais par ce que
    -- le client annonce.
    v_verse := least(greatest(coalesce(p_montant, 0), 0), greatest(v_caisse, 0));
  END IF;

  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'caisse', v_caisse,
                              'roulement', c_roulement);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id := p_entrepot_id || ':' || v_jour::text ||
          CASE WHEN p_mode = 'volontaire'
               THEN ':v' || (extract(epoch from clock_timestamp())*1000)::bigint
               ELSE '' END;

  -- L'anti-rejeu EST la cle : un reversement automatique deja fait aujourd'hui
  -- ne peut pas etre rejoue, meme par deux crons concurrents.
  BEGIN
    INSERT INTO public.entrepots_reversements (id, entrepot_id, mairie_id, jour, montant, mode, acteur)
    VALUES (v_id, p_entrepot_id, v_mairie, v_jour, v_verse, p_mode, p_acteur);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reverse_aujourdhui',
                              'jour', v_jour, 'caisse', v_caisse);
  END;

  -- Debit de l'entrepot, en conservant la forme d'origine (chaine JSON).
  v_etat := jsonb_set(v_etat, '{entrepot,caisse}', to_jsonb(v_caisse - v_verse));
  UPDATE public.batiments_etat
     SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = p_entrepot_id;

  -- Credit de la mairie, par la primitive verrouillee (appel interne).
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.caisse_institution_mouvement(v_mairie, v_verse, true);

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'mairie', v_mairie,
                            'caisse', v_caisse - v_verse, 'mode', p_mode, 'jour', v_jour);
END;
$function$;

-- entrepot_virement_mairie(text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_virement_mairie(p_entrepot_id text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_pays  := split_part(p_entrepot_id, '_', 1);
  v_ville := split_part(p_entrepot_id, '_', 2);

  -- AUTORITE : directeur de CET entrepot, dans SA ville. Le maire et son adjoint
  -- ne sont pas inclus : l'autonomie de la caisse est precisement le sujet.
  IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = 'directeur_entrepot'
                    AND a.pays = v_pays
                    AND coalesce(a.poste_city, '') = v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  RETURN public.entrepot_reverser(p_entrepot_id, p_montant, 'volontaire', v_moi);
END;
$function$;

-- entrepots_reverser_excedent() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepots_reverser_excedent()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v jsonb; v_total numeric := 0; v_n int := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  FOR r IN SELECT e.id FROM public.batiments_etat e
            WHERE e.id LIKE '%\_entrepot-%'
              AND public.batiment_etat_lire(e.data) ? 'entrepot'
            ORDER BY e.id
  LOOP
    v := public.entrepot_reverser(r.id, NULL, 'automatique', NULL);
    IF coalesce((v->>'ok')::boolean, false) AND coalesce((v->>'verse')::numeric, 0) > 0 THEN
      v_total := v_total + (v->>'verse')::numeric;
      v_n := v_n + 1;
      v_detail := v_detail || jsonb_build_array(jsonb_build_object('entrepot', r.id, 'verse', v->>'verse'));
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'entrepots', v_n, 'total', v_total, 'detail', v_detail);
END;
$function$;

-- entreprise_acte_preemption(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_acte_preemption(p_acteur text, p_entreprise text, p_libelle_etat text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_r jsonb; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'preemptionEtat','') <> 'attente_acte' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'preemption_introuvable');
  END IF;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'));
    END IF;
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := (v_data - 'preemptionEtat' - 'preemptionPar')
            || jsonb_build_object('proprietaire',
                 COALESCE(NULLIF(btrim(COALESCE(p_libelle_etat,'')),''), 'État'));
  v_data := public.entreprise_ajouter_historique(v_data, 0,
              'Préemption par l''État, officialisée par le Ministre des Finances', v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'proprietaire', v_data->>'proprietaire',
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- entreprise_acte_rachat(text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_acte_rachat(p_acteur text, p_entreprise text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_prix numeric; v_solde numeric; v_r jsonb; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE((v_data->>'compromis')::boolean, false) IS NOT TRUE
     OR (v_data->>'compromisPar') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_compromis');
  END IF;
  IF COALESCE(v_data->'pretDemande'->>'statut','') = 'attente_validation' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pret_en_attente');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  v_solde := GREATEST(0, v_prix - COALESCE((v_data->>'acompte')::numeric, 0));

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'));
    END IF;
  END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_solde) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'solde', v_solde);
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt'
                    - 'compromisExpireAt')
            || jsonb_build_object('proprietaire', p_acteur);
  v_data := public.entreprise_ajouter_historique(v_data, 0,
              'Rachat de l''entreprise par ' || p_acteur || ' (acte notarié)', v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'solde', v_solde,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- entreprise_ajouter_historique(jsonb,numeric,text,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_ajouter_historique(p_data jsonb, p_montant numeric, p_motif text, p_jour integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_set(p_data, '{historique}', (
    SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) FROM (
      SELECT e FROM jsonb_array_elements(
        COALESCE(p_data->'historique', '[]'::jsonb)
        || jsonb_build_array(jsonb_build_object('jour', COALESCE(p_jour,1),
                                                'montant', p_montant, 'motif', p_motif))) e
      OFFSET GREATEST(0, jsonb_array_length(COALESCE(p_data->'historique','[]'::jsonb)) + 1 - 50)
    ) t
  ), true);
$function$;

-- entreprise_assurer_existence(text,text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_assurer_existence(p_id text, p_type text, p_pays text, p_ville text, p_batiment text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_dot record; v_arm record; v_cle text; v_type_attendu text;
  v_id_attendu text; v_param jsonb; v_modifie boolean := false;
  v_k text; v_v jsonb;
BEGIN
  IF COALESCE(p_id,'') = '' OR COALESCE(p_pays,'') = '' OR COALESCE(p_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF NOT public.est_appel_serveur()
     AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_id FOR UPDATE;

  IF FOUND THEN
    IF COALESCE((v_data->>'version')::integer, 0) >= 2 THEN
      RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false);
    END IF;
    v_cle := CASE WHEN COALESCE(p_room,'') <> '' THEN p_batiment || '|' || p_room ELSE p_batiment END;
    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;
    IF NOT FOUND THEN
      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment;
    END IF;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false);
    END IF;

    FOR v_v IN SELECT value FROM jsonb_array_elements(v_dot.carte) LOOP
      IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(v_v)) THEN
        v_data := jsonb_set(v_data, '{carte}', COALESCE(v_data->'carte','[]'::jsonb) || jsonb_build_array(v_v), true);
        v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_dot.stock_matieres) LOOP
      IF NOT (COALESCE(v_data->'stockMatieres','{}'::jsonb) ? v_k) THEN
        v_data := jsonb_set(v_data, ARRAY['stockMatieres', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_dot.cout_moyen_matieres) LOOP
      IF NOT (COALESCE(v_data->'coutMoyenMatieres','{}'::jsonb) ? v_k) THEN
        v_data := jsonb_set(v_data, ARRAY['coutMoyenMatieres', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    v_param := COALESCE(v_data->'parametres', '{}'::jsonb);
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(v_dot.parametres->'stockMax','{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_param->'stockMax','{}'::jsonb) ? v_k) THEN
        v_param := jsonb_set(v_param, ARRAY['stockMax', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(v_dot.parametres->'prixVente','{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_param->'prixVente','{}'::jsonb) ? v_k) THEN
        v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    IF v_modifie THEN
      v_data := jsonb_set(v_data, '{parametres}', v_param, true);
      UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_id;
    END IF;
    RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false, 'rattrapee', v_modifie);
  END IF;

  IF p_type = 'armurerie' THEN
    v_id_attendu := 'armurerie-' || p_pays || '-' || p_ville;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme');
    END IF;
    SELECT * INTO v_arm FROM public.armureries_dotations WHERE pays = p_pays;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'armurerie_inconnue');
    END IF;
    v_data := jsonb_build_object(
      'id', p_id, 'type', 'armurerie', 'country', p_pays, 'city', p_ville,
      'buildingId', 'armurerie', 'roomId', NULL, 'proprietaire', 'PNJ',
      'caisse', v_arm.caisse, 'stockMatieres', v_arm.stock_matieres,
      'coutMoyenMatieres', '{}'::jsonb, 'stockProduits', '{}'::jsonb,
      'carte', '[]'::jsonb, 'parametres', v_arm.parametres, 'historique', '[]'::jsonb);

  ELSIF p_type = 'imprimerie' THEN
    v_id_attendu := 'imprimerie-' || p_pays || '-' || p_ville || '-' || p_batiment;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.imprimeries_declarees
                    WHERE pays = p_pays AND ville = p_ville AND batiment = p_batiment) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'imprimerie_non_declaree');
    END IF;
    -- Identite de propriete SEULE : la caisse et le stock de bois vivent dans batiments_etat.
    v_data := jsonb_build_object(
      'id', p_id, 'type', 'imprimerie', 'country', p_pays, 'city', p_ville,
      'buildingId', p_batiment, 'roomId', NULL, 'proprietaire', 'PNJ',
      'caisseExterne', jsonb_build_object('table','batiments_etat','sousCle','imprimerie'),
      'historique', '[]'::jsonb);

  ELSE
    v_cle := CASE WHEN COALESCE(p_room,'') <> '' THEN p_batiment || '|' || p_room ELSE p_batiment END;
    SELECT type INTO v_type_attendu FROM public.commerces_types WHERE cle = v_cle;
    IF NOT FOUND THEN
      SELECT type INTO v_type_attendu FROM public.commerces_types WHERE cle = p_batiment;
      v_cle := p_batiment;
    END IF;
    IF v_type_attendu IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'batiment_sans_commerce');
    END IF;
    IF p_type IS DISTINCT FROM v_type_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_non_conforme', 'attendu', v_type_attendu);
    END IF;
    v_id_attendu := p_type || '-' || p_pays || '-' || p_ville || '-' || p_batiment
                    || CASE WHEN COALESCE(p_room,'') <> '' THEN '-' || p_room ELSE '' END;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme', 'attendu', v_id_attendu);
    END IF;
    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;
    v_data := jsonb_build_object(
      'id', p_id, 'type', p_type, 'country', p_pays, 'city', p_ville,
      'buildingId', p_batiment, 'roomId', NULLIF(COALESCE(p_room,''), ''),
      'proprietaire', 'PNJ',
      'caisse', COALESCE(v_dot.caisse, 0),
      'stockMatieres', COALESCE(v_dot.stock_matieres, '{}'::jsonb),
      'coutMoyenMatieres', COALESCE(v_dot.cout_moyen_matieres, '{}'::jsonb),
      'stockProduits', '{}'::jsonb,
      'carte', COALESCE(v_dot.carte, '[]'::jsonb),
      'parametres', COALESCE(v_dot.parametres, jsonb_build_object('prixVente','{}'::jsonb,'stockMax','{}'::jsonb)),
      'historique', '[]'::jsonb);
  END IF;

  INSERT INTO public.entreprises (id, data, updated_at) VALUES (p_id, v_data, now())
  ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', true);
END; $function$;

-- entreprise_mouvement_fiscal(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_mouvement_fiscal(p_acteur text, p_entreprise text, p_delta numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_caisse numeric; v_reel numeric; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  IF p_delta IS NULL OR p_delta = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  -- Regle existante : un prelevement ne peut pas depasser le solde ; un versement est integral.
  v_reel := CASE WHEN p_delta >= 0 THEN p_delta ELSE -LEAST(v_caisse, -p_delta) END;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_reel), true);
  v_data := public.entreprise_ajouter_historique(v_data, v_reel,
              CASE WHEN v_reel >= 0 THEN 'Subvention ministérielle' ELSE 'Redressement fiscal' END
              || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'montantReel', v_reel, 'caisse', v_caisse + v_reel);
END; $function$;

-- entreprise_preempter(text,text,numeric,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_preempter(p_acteur text, p_entreprise text, p_montant numeric, p_duree integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_prix numeric; v_pays text; v_taux numeric; v_total numeric;
  v_maintenant bigint; v_r jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;
  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  IF (COALESCE((v_data->>'compromis')::boolean, false)
      AND COALESCE((v_data->>'compromisExpireAt')::bigint,0) > v_maintenant)
     OR COALESCE(v_data->>'preemptionEtat','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  IF p_montant IS NULL OR p_montant < v_prix OR COALESCE(p_duree,0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_insuffisant', 'prix', v_prix);
  END IF;

  v_pays  := COALESCE(v_data->>'country','republic');
  v_taux  := public.taux_pret_nationale(v_pays);
  v_total := round(p_montant * (1 + v_taux / 100));

  -- Mouvements institutionnels atomiques, jamais une lecture-modification-ecriture cliente.
  PERFORM public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', p_montant, false);
  v_r := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', -v_prix, false);
  IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
  END IF;

  v_data := v_data || jsonb_build_object('preemptionEtat', 'attente_acte',
                                         'preemptionPar', p_acteur);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'montant', p_montant,
    'montantTotal', v_total, 'mensualite', ceil(v_total / p_duree), 'taux', v_taux);
END; $function$;

-- entreprise_prix_rachat(jsonb) -> numeric | plpgsql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_prix_rachat(p_data jsonb)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE v_prix numeric; v_type text; v_bat text;
BEGIN
  v_type := COALESCE(p_data->>'type','');
  v_bat  := COALESCE(p_data->>'buildingId','');
  IF v_type = 'armurerie' THEN
    SELECT valeur INTO v_prix FROM public.entreprises_constantes WHERE cle = 'prix_rachat_armurerie';
    RETURN v_prix;
  END IF;
  IF v_type = 'imprimerie' THEN
    SELECT valeur INTO v_prix FROM public.entreprises_constantes WHERE cle = 'prix_rachat_imprimerie';
    RETURN v_prix;
  END IF;
  SELECT prix INTO v_prix FROM public.entreprises_prix_rachat WHERE batiment = v_bat;
  RETURN v_prix;
END; $function$;

-- entreprise_signer_compromis(text,text,numeric,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_signer_compromis(p_acteur text, p_entreprise text, p_pret_montant numeric DEFAULT NULL::numeric, p_pret_duree integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_acompte numeric; v_plafond numeric; v_taux numeric;
  v_total numeric; v_pret jsonb; v_expire bigint; v_maintenant bigint;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_rachetable');
  END IF;
  IF public.entreprise_prix_rachat(v_data) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_rachetable');
  END IF;

  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  v_expire := COALESCE((v_data->>'compromisExpireAt')::bigint, 0);
  IF COALESCE((v_data->>'compromis')::boolean, false) AND v_expire > v_maintenant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reservee',
                              'par', v_data->>'compromisPar');
  END IF;

  SELECT valeur INTO v_acompte FROM public.entreprises_constantes WHERE cle = 'acompte_compromis';
  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_acompte) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'acompte', v_acompte);
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', true, 'compromisPar', p_acteur, 'acompte', v_acompte,
    'compromisAt', v_maintenant, 'compromisExpireAt', v_maintenant + 7 * 86400000);

  IF p_pret_montant IS NOT NULL AND p_pret_montant > 0 THEN
    SELECT valeur INTO v_plafond FROM public.entreprises_constantes WHERE cle = 'plafond_pret_compromis';
    IF p_pret_montant > COALESCE(v_plafond, 0) OR COALESCE(p_pret_duree,0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pret_hors_bornes', 'plafond', v_plafond);
    END IF;
    -- Le taux n'est PAS transmis : il est recalcule depuis l'indice economique reel du pays.
    v_taux  := public.taux_pret_nationale(COALESCE(v_data->>'country','republic'));
    v_total := round(p_pret_montant * (1 + v_taux / 100));
    v_pret  := jsonb_build_object('demandeur', p_acteur, 'montant', p_pret_montant,
                 'montantTotal', v_total, 'duree', p_pret_duree,
                 'mensualite', ceil(v_total / p_pret_duree), 'statut', 'attente_validation');
    v_data := jsonb_set(v_data, '{pretDemande}', v_pret, true);
  END IF;

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'acompte', v_acompte,
    'expireAt', v_maintenant + 7 * 86400000, 'pret', v_pret,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- entreprise_succession_annuler_compromis(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_succession_annuler_compromis(p_acteur text, p_entreprise text, p_succession text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_defunt text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  -- Seul un compromis dont le DEFUNT est l'acheteur peut etre annule ici. Un compromis deja
  -- nettoye n'apparait plus dans le scan du client : on repond ok sans rien ecrire.
  IF (v_data->>'compromisPar') IS DISTINCT FROM v_defunt THEN
    IF v_data ? 'compromisPar' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_compromis_du_defunt');
    END IF;
    RETURN jsonb_build_object('ok', true, 'deja_nettoye', true);
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', NULL, 'compromisPar', NULL, 'acompte', NULL,
    'compromisAt', NULL, 'compromisExpireAt', NULL, 'pretDemande', NULL);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true);
END; $function$;

-- entreprise_succession_geler(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_succession_geler(p_acteur text, p_entreprise text, p_succession text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_defunt text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM v_defunt THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_du_defunt');
  END IF;

  -- Rejouable sans risque : reposer le meme gel est un no-op, c'est ce que fait deja le client
  -- en cas de reprise apres echec partiel.
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{succession_gel}', to_jsonb(p_succession), true),
         updated_at = now()
   WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'gel', p_succession);
END; $function$;

-- fabriquer_produit_manufacture(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fabriquer_produit_manufacture(p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ville text; v_bat text; v_recette jsonb; v_id text; v_pa_requis integer;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_sp jsonb;
  v_cle text; v_q numeric; v_manque text; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, recette, COALESCE(pa, 0)
    INTO v_ville, v_bat, v_recette, v_pa_requis
  FROM public.produits_manufactures WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_sp := coalesce(v_usine->'stockProduits', '{}'::jsonb);

  -- Verification COMPLETE avant toute mutation : refus sans mutation partielle.
  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    IF coalesce((v_sm->>v_cle)::numeric, 0) < v_q THEN v_manque := v_cle; EXIT; END IF;
  END LOOP;
  IF v_manque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'matiere', v_manque);
  END IF;

  -- PA du fabricant, lu dans la recette miroir. Verifie AVANT toute mutation, comme le stock.
  SELECT COALESCE(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'pa_reel', v_pa);
  END IF;

  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_cle], to_jsonb(coalesce((v_sm->>v_cle)::numeric,0) - v_q));
  END LOOP;
  v_sp := jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(coalesce((v_sp->>p_produit)::numeric,0) + 1));

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('stockMatieres', v_sm, 'stockProduits', v_sp)))::text),
         updated_at = now()
   WHERE id = v_id;

  IF v_pa_requis > 0 THEN
    UPDATE public.personnages_donnees SET pa = v_pa - v_pa_requis, updated_at = now()
     WHERE name = p_acteur;
  END IF;

  RETURN jsonb_build_object('ok', true, 'stock_produit', coalesce((v_sp->>p_produit)::numeric,0),
    'paConsommes', v_pa_requis, 'pa', v_pa - v_pa_requis);
END; $function$;

-- fixer_prix_entrepot(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fixer_prix_entrepot(p_acteur text, p_pays text, p_prix jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_ville text; v_bat text; v_id text;
  v_etat jsonb; v_entrepot jsonb; v_pm jsonb := '{}'::jsonb;
  v_cle text; v_val numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id', poste->>'city' INTO v_poste, v_ville
  FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_poste IS DISTINCT FROM 'directeur_entrepot' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  SELECT building_id INTO v_bat FROM public.entrepots_par_ville WHERE ville = v_ville;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;

  -- Validation AVANT toute ecriture : un seul prix invalide annule l'ensemble.
  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(coalesce(p_prix,'{}'::jsonb)) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    IF v_val IS NULL OR v_val <= 0 OR NOT (v_val = v_val) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'cle', v_cle);
    END IF;
    v_pm := jsonb_set(v_pm, ARRAY[v_cle], to_jsonb(round(v_val, 2)));
  END LOOP;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
           v_entrepot || jsonb_build_object('prixManuel', v_pm)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'prixManuel', v_pm, 'batiment', v_bat);
END; $function$;

-- fixer_prix_vente_directe(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fixer_prix_vente_directe(p_acteur text, p_pays text, p_prix jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_ville text; v_bat text; v_produits jsonb; v_id text;
  v_etat jsonb; v_usine jsonb; v_pm jsonb := '{}'::jsonb;
  v_cle text; v_val numeric; v_base numeric; v_min numeric; v_max numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT ville, building_id, produits INTO v_ville, v_bat, v_produits
  FROM public.directeurs_usine WHERE poste_id = v_poste;
  IF v_bat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;

  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(coalesce(p_prix,'{}'::jsonb)) LOOP
    IF NOT (v_produits ? v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_hors_usine', 'cle', v_cle);
    END IF;
    SELECT prix_base INTO v_base FROM public.ressources_economie WHERE cle = v_cle;
    IF v_base IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle); END IF;
    -- Fourchette +/-40 %, arrondie au centime, exactement comme cote client.
    v_min := round(v_base * 0.6, 2); v_max := round(v_base * 1.4, 2);
    IF v_val IS NULL OR v_val < v_min OR v_val > v_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette',
                                'cle', v_cle, 'min', v_min, 'max', v_max);
    END IF;
    v_pm := jsonb_set(v_pm, ARRAY[v_cle], to_jsonb(round(v_val, 2)));
  END LOOP;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('prixManuel', v_pm)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'prixManuel', v_pm, 'batiment', v_bat);
END; $function$;

-- fixer_repartition_port(text,numeric,numeric,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fixer_repartition_port(p_cle text, p_capitale numeric, p_ville_a numeric, p_ville_b numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id text := 'republic_ville_a_port-sainte-marie';
        v_data jsonb; v_etat jsonb; v_port jsonb;
BEGIN
  PERFORM public.exiger_poste('capitaine_port');

  IF p_cle IS NULL OR NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_cle) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;
  IF p_capitale IS NULL OR p_ville_a IS NULL OR p_ville_b IS NULL
     OR p_capitale < 0 OR p_ville_a < 0 OR p_ville_b < 0
     OR abs((p_capitale + p_ville_a + p_ville_b) - 100) > 0.1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repartition_invalide');
  END IF;

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_absent'); END IF;

  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_port := COALESCE(v_etat->'port', '{}'::jsonb);
  v_port := jsonb_set(v_port, ARRAY['repartition'],
              COALESCE(v_port->'repartition', '{}'::jsonb), true);
  v_port := jsonb_set(v_port, ARRAY['repartition', p_cle],
              jsonb_build_object('capitale', p_capitale, 'ville_a', p_ville_a,
                                 'ville_b', p_ville_b), true);
  v_etat := jsonb_set(v_etat, ARRAY['port'], v_port, true);

  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'repartition', v_port->'repartition'->p_cle);
END; $function$;

-- fixer_repartition_production(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fixer_repartition_production(p_acteur text, p_pays text, p_pourcentage numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_ville text; v_bat text; v_id text; v_etat jsonb; v_usine jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT ville, building_id INTO v_ville, v_bat FROM public.directeurs_usine WHERE poste_id = v_poste;
  IF v_bat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  IF p_pourcentage IS NULL OR p_pourcentage < 0 OR p_pourcentage > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide');
  END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('repartitionEntrepots', p_pourcentage / 100)))::text),
         updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'repartitionEntrepots', p_pourcentage / 100, 'batiment', v_bat);
END; $function$;

-- fournisseurs_etrangers() -> TABLE(pays text, libelle text, ressource text, prix_unitaire numeric, disponible integer) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fournisseurs_etrangers()
 RETURNS TABLE(pays text, libelle text, ressource text, prix_unitaire numeric, disponible integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH pays_etrangers(code, nom) AS (
    VALUES ('narco', 'El Estado'), ('soviet', 'Sovarka'), ('khalija', 'Al-Khalija')
  ),
  -- Relations d'approvisionnement REELLES, recopiees de ORIGINE_IMPORTS_PORT (api/cron-minuit.js).
  producteurs(code, ressource) AS (
    VALUES ('khalija', 'petrole'), ('soviet', 'petrole'), ('narco', 'produits_exotiques')
  )
  SELECT p.code,
         p.nom,
         r.cle,
         CASE WHEN EXISTS (SELECT 1 FROM producteurs pr WHERE pr.code = p.code AND pr.ressource = r.cle)
              THEN r.prix_achat_fournisseur ELSE r.prix_base END,
         NULL::integer
    FROM pays_etrangers p
    CROSS JOIN public.ressources_economie r
   WHERE r.source = 'livraison';
$function$;
