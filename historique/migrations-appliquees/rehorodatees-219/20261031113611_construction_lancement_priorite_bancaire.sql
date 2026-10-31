-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261020222029_construction_lancement_priorite_bancaire.sql ; aucun changement de règle.
-- Issue #57 : priorite bancaire du lancement, PREPAREE UNIQUEMENT.
-- Depend de 20261020214955_construction_materiaux_prix_et_dons.sql.
-- Un seul moteur financier commun. La signature historique garde la priorite liquide.
-- Aucun changement de type, aucun passage en centimes, aucun changement de soldes historiques.
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.helvetia_debiter_fonds_ordinaires(text,numeric)'); IF h IS NULL OR h NOT IN ('55ce3acdce6940c964652869f88ab493','a9ef864bfaa3b52da709252e393000d5') THEN RAISE EXCEPTION 'definition_non_examinee: public.helvetia_debiter_fonds_ordinaires(text,numeric)'; END IF; END;$g$;
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.helvetia_debiter_fonds_ordinaires(text,numeric,text)'); IF h IS NOT NULL AND h NOT IN ('a960aeb44ddca7cc78ea837c8cbc8f24') THEN RAISE EXCEPTION 'definition_non_examinee: public.helvetia_debiter_fonds_ordinaires(text,numeric,text)'; END IF; END;$g$;
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_lancer(text,text,text,text,numeric)'); IF h IS NULL OR h NOT IN ('c4c1ada9bcc72a91302b95e524081349','b880f5b95bb7f0da09d51f318ded9b20') THEN RAISE EXCEPTION 'definition_non_examinee: public.chantier_lancer(text,text,text,text,numeric)'; END IF; END;$g$;
CREATE OR REPLACE FUNCTION public.helvetia_debiter_fonds_ordinaires(p_personnage text, p_montant numeric, p_priorite text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_liquide numeric; v_arg numeric; v_solde numeric;
  v_preleve_liquide numeric; v_preleve_national numeric;
BEGIN
  IF p_priorite NOT IN ('liquide','nationale') OR p_priorite IS NULL THEN RAISE EXCEPTION 'priorite_invalide'; END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN true; END IF;

  SELECT COALESCE(liquide,0), COALESCE(arg,0) INTO v_liquide, v_arg
    FROM public.personnages_donnees WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT COALESCE(solde,0) INTO v_solde FROM public.comptes_bancaires
   WHERE personnage = p_personnage AND banque = 'nationale' FOR UPDATE;

  -- Les circuits historiques conservent leur priorite liquide et leur representation.
  -- La construction requiert des francs entiers : ne jamais arrondir un solde historique.
  IF p_priorite='nationale' AND (p_montant<>trunc(p_montant) OR v_liquide<>trunc(v_liquide)
      OR coalesce(v_solde,0)<>trunc(coalesce(v_solde,0)) OR v_liquide<0 OR coalesce(v_solde,0)<0) THEN
    RAISE EXCEPTION 'etat_financier_non_entier'; END IF;
  IF (v_liquide + COALESCE(v_solde,0)) < p_montant THEN RETURN false; END IF;
  IF p_priorite='nationale' THEN
    v_preleve_national:=LEAST(coalesce(v_solde,0),p_montant);
    v_preleve_liquide:=p_montant-v_preleve_national;
  ELSE
    v_preleve_liquide:=LEAST(v_liquide,p_montant);
    v_preleve_national:=p_montant-v_preleve_liquide;
  END IF;

  UPDATE public.personnages_donnees
     SET liquide = v_liquide - v_preleve_liquide,
         arg = GREATEST(0, v_arg - p_montant),
         updated_at = now()
   WHERE name = p_personnage;

  IF v_preleve_national > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_preleve_national, updated_at = now()
     WHERE personnage = p_personnage AND banque = 'nationale';
  END IF;

  RETURN true;
END; $function$;
CREATE OR REPLACE FUNCTION public.helvetia_debiter_fonds_ordinaires(p_personnage text,p_montant numeric)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
BEGIN
  RETURN public.helvetia_debiter_fonds_ordinaires(p_personnage,p_montant,'liquide');
END;$function$;

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
-- La nouvelle option est interne aux moteurs autorises, pas un RPC de debit public.
REVOKE ALL ON FUNCTION public.helvetia_debiter_fonds_ordinaires(text,numeric,text) FROM PUBLIC,anon,authenticated;
