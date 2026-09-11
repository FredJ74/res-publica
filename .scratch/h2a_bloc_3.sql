BEGIN;

CREATE OR REPLACE FUNCTION public.deposer_helvetia(p_personnage text, p_montant numeric, p_source_type text)
RETURNS public.comptes_bancaires
LANGUAGE plpgsql
AS $$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_caisse_id text;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RAISE EXCEPTION 'Montant invalide'; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;

  IF NOT public.helvetia_debiter_source(p_personnage, p_montant, p_source_type) THEN
    RAISE EXCEPTION 'Fonds insuffisants sur la source choisie';
  END IF;

  UPDATE public.comptes_bancaires SET solde = solde + p_montant, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia'
    RETURNING * INTO v_compte;

  v_caisse_id := v_perso.country || '_banque-privee';
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) + p_montant)),
        updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', p_montant), now());
  END IF;

  RETURN v_compte;
END;
$$;

CREATE OR REPLACE FUNCTION public.retirer_helvetia(p_personnage text, p_montant numeric, p_destination_type text)
RETURNS public.comptes_bancaires
LANGUAGE plpgsql
AS $$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_caisse_id text;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RAISE EXCEPTION 'Montant invalide'; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;

  IF (v_compte.solde - p_montant) < 10000 THEN
    RAISE EXCEPTION 'Ce retrait entrainerait une fermeture de compte -- utiliser fermer_compte_helvetia';
  END IF;

  v_caisse_id := v_perso.country || '_banque-privee';
  IF NOT public.helvetia_assurer_liquidite(v_perso.country, p_montant, 'retrait_client') THEN
    RAISE EXCEPTION 'Helvetia ne peut pas honorer ce retrait actuellement';
  END IF;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) - p_montant)), updated_at = now()
    WHERE id = v_caisse_id;

  UPDATE public.comptes_bancaires SET solde = solde - p_montant, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia'
    RETURNING * INTO v_compte;

  PERFORM public.helvetia_crediter_destination(p_personnage, p_montant, p_destination_type);

  RETURN v_compte;
END;
$$;

CREATE OR REPLACE FUNCTION public.fermer_compte_helvetia(p_personnage text, p_destination_type text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_placements numeric := 0;
  v_placement_row record;
  v_pret public.prets%rowtype;
  v_pret_existe boolean;
  v_dette numeric := 0;
  v_disponible numeric;
  v_applique_a_la_dette numeric;
  v_restitution numeric;
  v_net numeric;
  v_caisse_id text;
BEGIN
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;

  v_placements := 0;
  FOR v_placement_row IN
    SELECT id, montant FROM public.placements_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' AND statut = 'actif'
    FOR UPDATE
  LOOP
    v_placements := v_placements + v_placement_row.montant;
  END LOOP;

  SELECT * INTO v_pret FROM public.prets
    WHERE emprunteur = p_personnage AND type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')
    FOR UPDATE;
  v_pret_existe := FOUND;
  IF v_pret_existe THEN v_dette := v_pret.montant_restant; END IF;

  v_disponible := v_compte.solde + v_placements;
  v_net := v_disponible - v_dette;
  v_applique_a_la_dette := LEAST(v_disponible, v_dette);
  v_restitution := GREATEST(0, v_disponible - v_dette);
  v_caisse_id := v_perso.country || '_banque-privee';

  IF v_restitution > 0 THEN
    IF NOT public.helvetia_assurer_liquidite(v_perso.country, v_restitution, 'fermeture_compte') THEN
      RAISE EXCEPTION 'Helvetia ne peut pas honorer la restitution de fermeture actuellement';
    END IF;
  END IF;

  IF v_placements > 0 THEN
    UPDATE public.placements_bancaires SET statut = 'resolu', date_resolution = now(), montant_final = montant
      WHERE personnage = p_personnage AND banque = 'helvetia' AND statut = 'actif';
  END IF;

  UPDATE public.comptes_bancaires SET solde = 0, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia';

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}',
        to_jsonb(GREATEST(0, COALESCE((data->>'solde')::numeric,0) + v_applique_a_la_dette - v_restitution))),
        updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (v_caisse_id, jsonb_build_object('solde', GREATEST(0, v_applique_a_la_dette - v_restitution)), now());
  END IF;

  IF v_pret_existe THEN
    IF v_applique_a_la_dette >= v_dette THEN
      UPDATE public.prets SET montant_restant = 0, statut = 'rembourse' WHERE id = v_pret.id;
    ELSE
      UPDATE public.prets
        SET montant_restant = v_dette - v_applique_a_la_dette, statut = 'contentieux'
        WHERE id = v_pret.id;
    END IF;
  END IF;

  IF v_restitution > 0 THEN
    PERFORM public.helvetia_crediter_destination(p_personnage, v_restitution, p_destination_type);
  END IF;

  IF v_applique_a_la_dette > 0 THEN
    UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_applique_a_la_dette) WHERE name = p_personnage;
  END IF;

  RETURN jsonb_build_object('net', v_net, 'applique_a_la_dette', v_applique_a_la_dette,
    'restitution', v_restitution, 'dette_restante', GREATEST(0, v_dette - v_applique_a_la_dette));
END;
$$;

-- ---------------------------------------------------------------------
-- PRET "EMPRUNTER SANS VERIFICATION"
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.creer_pret_helvetia(p_personnage text, p_montant numeric, p_duree_jours integer)
RETURNS public.prets
LANGUAGE plpgsql
AS $$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_existant record;
  v_caisse_id text;
  v_montant_du numeric;
  v_mensualite numeric;
  v_pret public.prets%rowtype;
  v_id text;
BEGIN
  IF p_montant IS NULL OR p_montant < 1000 OR p_montant > 150000 THEN
    RAISE EXCEPTION 'Montant hors bornes (1000 a 150000)';
  END IF;
  IF p_duree_jours IS NULL OR p_duree_jours < 5 OR p_duree_jours > 30 THEN
    RAISE EXCEPTION 'Duree hors bornes (5 a 30 jours)';
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia obligatoire'; END IF;

  SELECT 1 INTO v_existant FROM public.prets
    WHERE emprunteur = p_personnage AND type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')
    FOR UPDATE;
  IF FOUND THEN RAISE EXCEPTION 'Un pret Helvetia est deja actif'; END IF;

  v_caisse_id := v_perso.country || '_banque-privee';
  IF NOT public.helvetia_assurer_liquidite(v_perso.country, p_montant, 'pret_client') THEN
    RAISE EXCEPTION 'Helvetia ne peut pas financer ce pret actuellement';
  END IF;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) - p_montant)), updated_at = now()
    WHERE id = v_caisse_id;

  v_montant_du := ROUND(p_montant * 1.12);
  v_mensualite := ROUND(v_montant_du / p_duree_jours);
  v_id := 'pret-helvetia-' || p_personnage || '-' || extract(epoch from clock_timestamp())::bigint;

  INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque, type_pret,
      montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
    VALUES (v_id, p_personnage, v_perso.country, NULL, 'helvetia', 'sans_verification',
      p_montant, v_montant_du, p_duree_jours, v_mensualite, 0, 'en_cours')
    RETURNING * INTO v_pret;

  UPDATE public.comptes_bancaires SET solde = solde + p_montant, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia';

  UPDATE public.personnages SET arg = COALESCE(arg,0) + p_montant WHERE name = p_personnage;

  RETURN v_pret;
END;
$$;

CREATE OR REPLACE FUNCTION public.rembourser_pret_helvetia_integral(p_personnage text, p_pret_id text, p_sources jsonb)
RETURNS public.prets
LANGUAGE plpgsql
AS $$
DECLARE
  v_pret public.prets%rowtype;
  v_perso public.personnages%rowtype;
  v_compte_national public.comptes_bancaires%rowtype;
  v_compte_helvetia public.comptes_bancaires%rowtype;
  v_source jsonb;
  v_type text;
  v_montant numeric;
  v_total numeric := 0;
  v_liquide_requis numeric := 0;
  v_national_requis numeric := 0;
  v_helvetia_requis numeric := 0;
  v_helvetia_disponible numeric;
  v_caisse_id text;
BEGIN
  SELECT * INTO v_pret FROM public.prets WHERE id = p_pret_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pret introuvable'; END IF;
  IF v_pret.emprunteur <> p_personnage THEN RAISE EXCEPTION 'Ce pret n''appartient pas a ce personnage'; END IF;
  IF v_pret.type_banque <> 'helvetia' THEN RAISE EXCEPTION 'Pas un pret Helvetia'; END IF;
  IF v_pret.statut NOT IN ('en_cours','contentieux') THEN RAISE EXCEPTION 'Pret deja solde ou clos'; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;
  SELECT * INTO v_compte_national FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'nationale' FOR UPDATE;
  SELECT * INTO v_compte_helvetia FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;

  FOR v_source IN SELECT * FROM jsonb_array_elements(p_sources) LOOP
    v_type := v_source->>'type';
    v_montant := (v_source->>'montant')::numeric;
    IF v_montant IS NULL OR v_montant <= 0 THEN RAISE EXCEPTION 'Montant de source invalide'; END IF;
    v_total := v_total + v_montant;
    IF v_type = 'liquide' THEN
      v_liquide_requis := v_liquide_requis + v_montant;
    ELSIF v_type = 'national' THEN
      v_national_requis := v_national_requis + v_montant;
    ELSIF v_type = 'helvetia' THEN
      v_helvetia_requis := v_helvetia_requis + v_montant;
    ELSE
      RAISE EXCEPTION 'Source non supportee pour ce remboursement: %', v_type;
    END IF;
  END LOOP;

  IF v_total <> v_pret.montant_restant THEN
    RAISE EXCEPTION 'La somme des sources (%) doit egaler exactement le montant restant du (%)', v_total, v_pret.montant_restant;
  END IF;

  IF v_liquide_requis > COALESCE(v_perso.liquide,0) THEN
    RAISE EXCEPTION 'Liquide insuffisant pour la source demandee';
  END IF;
  IF v_national_requis > 0 AND (v_compte_national.solde IS NULL OR v_national_requis > v_compte_national.solde) THEN
    RAISE EXCEPTION 'Solde du compte national insuffisant pour la source demandee';
  END IF;
  IF v_helvetia_requis > 0 THEN
    IF v_compte_helvetia.solde IS NULL THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;
    v_helvetia_disponible := GREATEST(0, v_compte_helvetia.solde - 10000);
    IF v_helvetia_requis > v_helvetia_disponible THEN
      RAISE EXCEPTION 'Le compte Helvetia ne peut fournir que % sans passer sous le plancher de 10000 -- utiliser fermer_compte_helvetia', v_helvetia_disponible;
    END IF;
  END IF;

  IF v_liquide_requis > 0 THEN
    UPDATE public.personnages SET liquide = liquide - v_liquide_requis WHERE name = p_personnage;
  END IF;
  IF v_national_requis > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_national_requis, updated_at = now()
      WHERE personnage = p_personnage AND banque = 'nationale';
  END IF;
  IF v_helvetia_requis > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_helvetia_requis, updated_at = now()
      WHERE personnage = p_personnage AND banque = 'helvetia';
  END IF;

  v_caisse_id := v_pret.country || '_banque-privee';
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_total)), updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_total), now());
  END IF;

  UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_total) WHERE name = p_personnage;

  UPDATE public.prets SET montant_restant = 0, statut = 'rembourse' WHERE id = p_pret_id RETURNING * INTO v_pret;
  RETURN v_pret;
END;
$$;

CREATE OR REPLACE FUNCTION public.accepter_accord_helvetia(p_personnage text, p_pret_id text)
RETURNS public.prets
LANGUAGE plpgsql
AS $$
DECLARE
  v_pret public.prets%rowtype;
BEGIN
  SELECT * INTO v_pret FROM public.prets WHERE id = p_pret_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pret introuvable'; END IF;
  IF v_pret.emprunteur <> p_personnage THEN RAISE EXCEPTION 'Ce pret n''appartient pas a ce personnage'; END IF;
  IF v_pret.type_banque <> 'helvetia' THEN RAISE EXCEPTION 'Pas un pret Helvetia'; END IF;
  IF v_pret.statut <> 'contentieux' THEN RAISE EXCEPTION 'Accord disponible uniquement en procedure contentieuse'; END IF;
  IF NOT v_pret.proposition_en_attente THEN RAISE EXCEPTION 'Aucune proposition en attente pour ce pret'; END IF;
  IF v_pret.accord_actif THEN RAISE EXCEPTION 'Un accord est deja actif'; END IF;

  UPDATE public.prets
    SET montant_restant = ROUND(montant_restant * 1.20),
        accord_actif = true,
        accord_fin_le = now() + interval '10 days',
        accord_avertissement_envoye = false
    WHERE id = p_pret_id
    RETURNING * INTO v_pret;

  RETURN v_pret;
END;
$$;

COMMIT;
