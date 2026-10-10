-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- taux_imposition_fixer(text,integer,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.taux_imposition_fixer(p_portee text, p_taux integer, p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste_requis text; v_cle_champ text; v_nom text; v_pays text; v_ville text;
  v_paie jsonb; v_n integer; v_cle text;
BEGIN
  IF p_portee = 'local' THEN
    v_poste_requis := 'maire'; v_cle_champ := 'tauxLocal';
  ELSIF p_portee = 'national' THEN
    v_poste_requis := 'min_fin'; v_cle_champ := 'tauxNational';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_inconnue');
  END IF;

  IF p_taux IS NULL OR p_taux < 0 OR p_taux > 40 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_hors_bornes');
  END IF;

  -- L'AUTORITE ET LE TERRITOIRE VIENNENT DU POSTE REEL, JAMAIS DU CLIENT.
  SELECT a.nom, a.pays, a.poste_city INTO v_nom, v_pays, v_ville
    FROM public.acteur_poste_courant() a
   WHERE a.poste_id = v_poste_requis
   LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', v_poste_requis);
  END IF;
  IF p_portee = 'local' AND coalesce(btrim(coalesce(v_ville,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maire_sans_ville');
  END IF;

  -- LE PAIEMENT, DANS CETTE TRANSACTION. Son refus arrete tout ; son echec apres l'ecriture du
  -- taux est impossible puisqu'il la precede dans le meme BEGIN.
  v_paie := public.payer_ordre(v_nom, p_fn, coalesce(p_pa,0), coalesce(p_cost,0));
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison',
                              coalesce(v_paie->>'raison','paiement_refuse'),
                              'disponible', v_paie->'disponible');
  END IF;

  -- UNE SEULE CLE EST TOUCHEE : aucun autre champ du blob ne peut etre perdu.
  IF p_portee = 'local' THEN
    v_cle := v_pays || '_' || v_ville;
    UPDATE public.budgets_municipaux
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), ARRAY[v_cle_champ],
                            to_jsonb(p_taux), true),
           updated_at = now()
     WHERE id = v_cle;
  ELSE
    v_cle := v_pays;
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), ARRAY[v_cle_champ],
                            to_jsonb(p_taux), true),
           updated_at = now()
     WHERE id = v_cle;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    -- Le budget n'existe pas : on ne l'invente pas, et le paiement est annule avec le reste.
    RAISE EXCEPTION 'budget_introuvable:%', v_cle USING ERRCODE = 'no_data_found';
  END IF;

  RETURN jsonb_build_object('ok', true, 'portee', p_portee, 'taux', p_taux,
    'cle', v_cle, 'ville', v_ville, 'pays', v_pays,
    'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg',
    'solde_national', v_paie->'solde_national',
    'pa_preleves', v_paie->'pa_preleves', 'montant_preleve', v_paie->'montant_preleve');
EXCEPTION WHEN no_data_found THEN
  RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable');
END; $function$;

-- taxe_fonciere_prelever(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.taxe_fonciere_prelever(p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pays text; v_data jsonb; v_ville text; v_proprio text; v_budget jsonb;
  v_taux numeric; v_taxe numeric; v_valeur numeric; v_arg numeric; v_existe boolean;
  v_dette numeric; v_nouvelle numeric; v_ratio numeric; v_action text; v_rec jsonb;
BEGIN
  SELECT t.country, t.data::jsonb INTO v_pays, v_data
    FROM public.terrains_etat t WHERE t.id = p_terrain_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok',false,'action','terrain_introuvable'); END IF;
  v_ville   := coalesce(nullif(btrim(coalesce(v_data->>'city','')),''), 'capitale');
  v_proprio := nullif(btrim(coalesce(v_data->>'proprietaire','')),'');
  -- HORS ASSIETTE : pas de proprietaire ou pas de surface. Verifie AVANT la revendication, pour
  -- ne pas consommer la journee d'un terrain qu'on n'impose pas.
  IF v_proprio IS NULL OR (v_data->>'surface') IS NULL THEN
    RETURN jsonb_build_object('ok',false,'action','hors_assiette'); END IF;
  SELECT b.data INTO v_budget FROM public.budgets_municipaux b
   WHERE b.id = v_pays || '_' || v_ville;
  IF v_budget IS NULL THEN
    RETURN jsonb_build_object('ok',false,'action','budget_municipal_absent'); END IF;
  SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
   WHERE name = v_proprio FOR UPDATE;
  IF NOT coalesce(v_existe,false) THEN
    RETURN jsonb_build_object('ok',false,'action','proprietaire_introuvable'); END IF;

  -- LA REVENDICATION, par terrain et par jour, DANS cette transaction.
  IF NOT public.acte_nocturne_revendiquer(v_pays, 'taxe_fonciere', p_terrain_id,
         jsonb_build_object('ville', v_ville, 'proprietaire', v_proprio)) THEN
    RETURN jsonb_build_object('ok',false,'action','deja_prelevee_aujourdhui'); END IF;

  v_taux   := coalesce(nullif(v_budget->>'tauxFoncier','')::numeric, 0.05);
  v_taxe   := round(((v_data->>'surface')::numeric * v_taux)::numeric, 2);
  v_valeur := coalesce(nullif(v_data->>'valeur_totale','')::numeric,
                       (v_data->>'surface')::numeric * 12);

  IF v_arg >= v_taxe THEN
    UPDATE public.personnages SET arg = v_arg - v_taxe WHERE name = v_proprio;
    v_data := jsonb_set(v_data, '{dette_fonciere}', '0'::jsonb, true);
    v_action := 'collectee';
    -- LE CREDIT DE LA MAIRIE EST INSEPARABLE DU DEBIT. Si elle ne peut pas encaisser, on LEVE :
    -- le proprietaire n'est alors pas debite du tout.
    v_rec := public.recette_municipale(v_pays, v_ville, v_taxe, 'taxe_fonciere');
    IF NOT coalesce((v_rec->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'taxe_fonciere_prelever : la mairie de % n''a pas pu encaisser (%)',
            v_ville, coalesce(v_rec->>'raison','verdict_absent');
    END IF;
  ELSE
    v_dette    := coalesce(nullif(v_data->>'dette_fonciere','')::numeric, 0);
    v_nouvelle := v_dette + v_taxe;
    v_ratio    := CASE WHEN v_valeur > 0 THEN v_nouvelle / v_valeur ELSE 0 END;
    IF v_ratio >= 0.25 THEN
      v_data := v_data || jsonb_build_object('proprietaire', NULL, 'coproprietaire', NULL,
                  'enVenteParMairie', true, 'prixVenteMairie', round(v_valeur * 0.7),
                  'dette_fonciere', 0);
      v_action := 'saisie';
      INSERT INTO public.evenements_globaux (country, city, texte, jour)
      VALUES (v_pays, v_ville,
        '🏛️ SAISIE MUNICIPALE : un bien a été saisi pour non-paiement de la taxe foncière et sera remis en vente.',
        NULL);
    ELSE
      v_data := jsonb_set(v_data, '{dette_fonciere}',
        to_jsonb(CASE WHEN v_ratio >= 0.15 THEN round(v_nouvelle * 1.10) ELSE v_nouvelle END), true);
      v_action := 'avertissement';
    END IF;
  END IF;
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;
  RETURN jsonb_build_object('ok',true,'action',v_action,'montant',v_taxe,
                            'ville',v_ville,'proprietaire',v_proprio);
END; $function$;

-- vente_structure_encaisser(text,integer,integer,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vente_structure_encaisser(p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_caisse text DEFAULT NULL::text, p_ville text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_pays text;
  v_ville text;
  v_taxable boolean;
  v_paye jsonb;
  v_taxe jsonb := NULL;
  v_net numeric;
  v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_taxable := CASE p_fn
    WHEN 'reserver_chambre_hotel' THEN true
    WHEN 'consommer_buvette'      THEN true
    WHEN 'faire_don'              THEN false
    ELSE NULL
  END;
  IF v_taxable IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vente_non_declaree', 'fn', p_fn);
  END IF;

  SELECT coalesce(pd.country, 'republic'),
         coalesce(nullif(btrim(coalesce(p_ville, '')), ''), pd.current_city, 'capitale')
    INTO v_pays, v_ville
    FROM public.personnages_donnees pd
   WHERE pd.name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF coalesce(btrim(coalesce(p_caisse, '')), '') = ''
     OR p_caisse NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_empire', 'caisse', p_caisse);
  END IF;

  v_paye := public.payer_ordre(v_acteur, p_fn, p_pa, p_cost);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RETURN v_paye;
  END IF;

  v_net := coalesce(p_cost, 0);
  IF v_taxable AND v_net > 0 THEN
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_net);
    v_net := coalesce((v_taxe->>'net')::numeric, v_net);
  END IF;

  IF v_net > 0 THEN
    v_credit := public.caisse_institution_mouvement(p_caisse, v_net, false);
    IF NOT coalesce((v_credit->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'vente_structure: credit impossible sur % (%)',
        p_caisse, coalesce(v_credit->>'raison', 'motif inconnu');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'pa', v_paye->'pa',
    'liquide', v_paye->'liquide',
    'arg', v_paye->'arg',
    'solde_national', v_paye->'solde_national',
    'pa_preleves', v_paye->'pa_preleves',
    'montant_preleve', v_paye->'montant_preleve',
    'net', v_net,
    'taxe', v_taxe,
    'caisse', p_caisse,
    'ville', v_ville);
END;
$function$;
