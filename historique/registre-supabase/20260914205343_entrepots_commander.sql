-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914205343
-- Nom original      : entrepots_commander
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-14 20:53:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 62195c44a4f16af683492f91f484226d
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- COMMANDE DIRECTE D'UN DIRECTEUR D'ENTREPOT — TRANSACTION UNIQUE
-- =====================================================================
-- Tout se joue ici, sous verrou, dans une seule transaction : controle des conditions, debit
-- integral de l'acheteur, retrait du stock fournisseur, credit du vendeur, creation du transit,
-- inscription au registre. Ouvrir l'ecran ou saisir une quantite ne reserve RIEN : le premier
-- qui valide correctement emporte la marchandise, le suivant se voit refuser le stock.
--
-- Les verrous sont poses dans un ORDRE DETERMINISTE (identifiants tries) : deux directeurs qui
-- se commandent mutuellement au meme instant ne peuvent donc pas s'interbloquer.
--
-- 0 PA : cette fonction ne touche jamais aux points d'action.
CREATE OR REPLACE FUNCTION public.entrepot_commander(
  p_acteur text, p_ressource text, p_quantite integer,
  p_fournisseur_type text,      -- 'entrepot' | 'port' | 'etranger'
  p_fournisseur_id text)        -- batiments_etat.id si interne, code pays si etranger
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_dest_id text; v_dest_ville text;
  v_prix numeric; v_fret numeric := 0; v_total numeric;
  v_cap integer; v_delai integer; v_libelle text;
  v_etat_d jsonb; v_ent_d jsonb; v_caisse_d numeric;
  v_etat_f jsonb; v_ent_f jsonb; v_caisse_f numeric; v_stock_f numeric;
  v_ids text[]; v_i text; v_arrivee date;
BEGIN
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
END; $$;

REVOKE ALL ON FUNCTION public.entrepot_commander(text, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entrepot_commander(text, text, integer, text, text) TO authenticated;
