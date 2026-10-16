-- EN ATTENTE : relire le vrai catalogue avant application. Debit avant livraison.
-- MD5 : garde de code contre un remplacement aveugle, pas une mesure de production.
DO $garde$
DECLARE v_corps text;
BEGIN
  SELECT prosrc INTO v_corps FROM pg_proc
   WHERE oid = to_regprocedure('public.acheter_produit_commerce(text,text,text,text,integer)');
  IF v_corps IS NULL OR md5(v_corps) NOT IN ('19f6cb294da782dbbf962028a1e315de', '37f4b161289413593665804b683e59ec') THEN
    RAISE EXCEPTION 'achat_commerce_definition_a_reexaminer_avant_migration';
  END IF;
END;
$garde$;

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

  v_fonds := jsonb_set(v_fonds, ARRAY['stockReferences', p_reference_id],
               to_jsonb(v_stock - v_qte), true);
  IF (v_stock - v_qte) <= 0 THEN
    v_fonds := jsonb_set(v_fonds, '{coutMoyenReferences}',
                 coalesce(v_fonds->'coutMoyenReferences', '{}'::jsonb) - p_reference_id, true);
  END IF;
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

-- Preuve structurelle uniquement : aucun appel metier dans la migration.
DO $preuve$
DECLARE v_corps text;
BEGIN
  SELECT prosrc INTO v_corps FROM pg_proc
   WHERE oid = 'public.acheter_produit_commerce(text,text,text,text,integer)'::regprocedure;
  IF strpos(v_corps, 'IF NOT public.mouvement_titulaire(p_acheteur, -v_montant)') = 0
     OR strpos(v_corps, 'IF NOT public.mouvement_titulaire(p_acheteur, -v_montant)')
       > strpos(v_corps, 'INSERT INTO public.objets_recus') THEN
    RAISE EXCEPTION 'achat_commerce_livraison_avant_debit';
  END IF;
END;
$preuve$;
