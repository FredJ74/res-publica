BEGIN;

CREATE OR REPLACE FUNCTION public.signer_compromis_bien_helvetia(p_personnage text, p_terrain_id text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_terrain record;
  v_data jsonb;
  v_bien public.biens_saisis_helvetia%rowtype;
  v_acompte numeric := 1000;
BEGIN
  SELECT id, data INTO v_terrain FROM public.terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bien introuvable'; END IF;
  v_data := v_terrain.data::jsonb;

  IF (v_data->>'proprietaire') <> 'Helvetia' THEN
    RAISE EXCEPTION 'Ce bien n''appartient pas a Helvetia';
  END IF;
  IF (v_data->>'compromis')::boolean IS TRUE THEN
    RAISE EXCEPTION 'Ce bien est deja sous compromis';
  END IF;

  SELECT * INTO v_bien FROM public.biens_saisis_helvetia
    WHERE terrain_id = p_terrain_id AND statut = 'en_vente' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ce bien n''est pas propose a la vente'; END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_personnage, v_acompte) THEN
    RAISE EXCEPTION 'Fonds insuffisants pour l''acompte';
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', true,
    'compromisPar', p_personnage,
    'acompte', v_acompte,
    'compromisAt', (extract(epoch from now())*1000)::bigint,
    'compromisExpireAt', (extract(epoch from now())*1000)::bigint + 7*86400000
  );
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;

  RETURN jsonb_build_object('terrain_id', p_terrain_id, 'acompte', v_acompte, 'prix', v_bien.prix_notaire);
END;
$$;

CREATE OR REPLACE FUNCTION public.finaliser_achat_bien_helvetia(p_personnage text, p_terrain_id text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_terrain record;
  v_data jsonb;
  v_bien public.biens_saisis_helvetia%rowtype;
  v_acompte numeric;
  v_solde numeric;
  v_caisse_id text;
  v_reste_debiteur numeric;
  v_excedent numeric;
  v_pret public.prets%rowtype;
BEGIN
  SELECT id, data, country INTO v_terrain FROM public.terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bien introuvable'; END IF;
  v_data := v_terrain.data::jsonb;

  SELECT * INTO v_bien FROM public.biens_saisis_helvetia
    WHERE terrain_id = p_terrain_id AND statut = 'en_vente' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ce bien n''est plus propose a la vente'; END IF;

  IF (v_data->>'proprietaire') <> 'Helvetia' THEN
    RAISE EXCEPTION 'Ce bien n''appartient plus a Helvetia';
  END IF;
  IF (v_data->>'compromis')::boolean IS NOT TRUE OR (v_data->>'compromisPar') <> p_personnage THEN
    RAISE EXCEPTION 'Aucun compromis actif de ce personnage sur ce bien';
  END IF;
  IF ((v_data->>'compromisExpireAt')::bigint) <= (extract(epoch from now())*1000)::bigint THEN
    RAISE EXCEPTION 'Ce compromis a expire';
  END IF;

  v_acompte := COALESCE((v_data->>'acompte')::numeric, 0);
  v_solde := v_bien.prix_notaire - v_acompte;

  IF v_solde > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_personnage, v_solde) THEN
      RAISE EXCEPTION 'Fonds insuffisants pour le solde';
    END IF;
  END IF;

  v_caisse_id := v_terrain.country || '_banque-privee';
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_bien.prix_notaire)), updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_bien.prix_notaire), now());
  END IF;

  v_data := v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt' - 'pretDemande';
  v_data := v_data || jsonb_build_object('proprietaire', p_personnage, 'coproprietaire', NULL);
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;

  UPDATE public.biens_saisis_helvetia
    SET prix_vente_reel = v_bien.prix_notaire, statut = 'vendu', date_vente = now()
    WHERE id = v_bien.id;

  IF v_bien.coproprietaire IS NOT NULL THEN
    INSERT INTO public.obligations_helvetia (id, country, beneficiaire, montant_du, motif, bien_id, pret_id, destination_type)
      VALUES ('obl-coprop-'||v_bien.id, v_bien.country, v_bien.coproprietaire, v_bien.quote_part_coproprietaire,
              'quote_part_coproprietaire', v_bien.id, v_bien.pret_id, 'liquide');

    INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
      VALUES (v_bien.coproprietaire, 'Banque Privée Helvetia', 'Revente de votre bien en copropriété',
        'Le bien a été revendu. Votre quote-part protégée (' || v_bien.quote_part_coproprietaire || ') vous sera réglée dès que possible.',
        now()::text, false, false);

    v_reste_debiteur := GREATEST(0, v_bien.prix_notaire - v_bien.quote_part_coproprietaire);

    SELECT * INTO v_pret FROM public.prets WHERE id = v_bien.pret_id FOR UPDATE;
    IF FOUND AND v_pret.statut IN ('en_cours','contentieux') THEN
      IF v_reste_debiteur >= v_pret.montant_restant THEN
        v_excedent := v_reste_debiteur - v_pret.montant_restant;
        UPDATE public.prets SET montant_restant = 0, statut = 'rembourse' WHERE id = v_pret.id;
        IF v_excedent > 0 THEN
          INSERT INTO public.obligations_helvetia (id, country, beneficiaire, montant_du, motif, bien_id, pret_id, destination_type)
            VALUES ('obl-surplus-'||v_bien.id, v_bien.country, v_pret.emprunteur, ROUND(v_excedent*0.90),
                    'surplus_saisie', v_bien.id, v_pret.id, 'liquide');
        END IF;
      ELSE
        UPDATE public.prets SET montant_restant = montant_restant - v_reste_debiteur WHERE id = v_pret.id;
      END IF;
      INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
        VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Revente de votre bien en copropriété',
          'Le bien a été revendu. Après règlement de la quote-part de votre copropriétaire, ' || v_reste_debiteur ||
          ' ont été appliqués à votre dette.', now()::text, false, false);
    END IF;
  END IF;

  RETURN jsonb_build_object('terrain_id', p_terrain_id, 'prix', v_bien.prix_notaire, 'acheteur', p_personnage);
END;
$$;

CREATE OR REPLACE FUNCTION public.resoudre_compromis_helvetia_expire(p_terrain_id text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_terrain record;
  v_data jsonb;
  v_expire bigint;
  v_maintenant bigint;
  v_pret_demande jsonb;
  v_refus boolean := false;
  v_acompte numeric;
  v_compromis_par text;
  v_caisse_id text;
  v_arg_demandeur numeric;
  v_risque boolean;
  v_accorde boolean;
  v_montant numeric;
BEGIN
  SELECT id, data, country, building_id INTO v_terrain FROM public.terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'non_applicable'; END IF;
  v_data := v_terrain.data::jsonb;

  IF (v_data->>'proprietaire') <> 'Helvetia' THEN RETURN 'non_applicable'; END IF;
  IF (v_data->>'compromis')::boolean IS NOT TRUE THEN RETURN 'non_applicable'; END IF;

  v_expire := (v_data->>'compromisExpireAt')::bigint;
  v_maintenant := (extract(epoch from now())*1000)::bigint;
  IF v_expire IS NULL OR v_expire > v_maintenant THEN RETURN 'pas_encore_expire'; END IF;

  v_pret_demande := v_data->'pretDemande';
  IF v_pret_demande IS NOT NULL AND v_pret_demande->>'statut' = 'attente_validation' THEN
    v_montant := (v_pret_demande->>'montant')::numeric;
    SELECT arg INTO v_arg_demandeur FROM public.personnages WHERE name = v_pret_demande->>'demandeur' FOR UPDATE;
    v_risque := COALESCE(v_arg_demandeur,0) < v_montant * 0.10;
    v_accorde := (NOT v_risque) OR (random() < 0.5);

    IF v_accorde THEN
      UPDATE public.personnages SET arg = COALESCE(arg,0) + v_montant WHERE name = v_pret_demande->>'demandeur';
      INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque, type_pret,
          montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
        VALUES ('pret-' || extract(epoch from clock_timestamp())::bigint, v_pret_demande->>'demandeur',
          v_terrain.country, v_terrain.building_id, 'nationale', 'travaux',
          v_montant, (v_pret_demande->>'montantTotal')::numeric, (v_pret_demande->>'duree')::integer,
          (v_pret_demande->>'mensualite')::numeric, 0, 'en_cours');
      v_data := jsonb_set(v_data, '{pretDemande,statut}', '"accorde"');
      UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;
      RETURN 'pret_accorde_compromis_gele';
    ELSE
      v_data := jsonb_set(v_data, '{pretDemande,statut}', '"refuse"');
      v_refus := true;
    END IF;
  END IF;

  v_acompte := COALESCE((v_data->>'acompte')::numeric, 0);
  v_compromis_par := v_data->>'compromisPar';
  v_caisse_id := v_terrain.country || '_banque-privee';

  IF v_refus THEN
    IF v_compromis_par IS NOT NULL AND v_acompte > 0 THEN
      UPDATE public.personnages SET liquide = COALESCE(liquide,0) + v_acompte,
          arg = COALESCE(arg,0) + v_acompte
        WHERE name = v_compromis_par;
    END IF;
  ELSE
    IF v_acompte > 0 THEN
      UPDATE public.caisses_batiments
        SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_acompte)), updated_at = now()
        WHERE id = v_caisse_id;
      IF NOT FOUND THEN
        INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_acompte), now());
      END IF;
    END IF;
  END IF;

  v_data := v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt' - 'pretDemande';
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;

  RETURN CASE WHEN v_refus THEN 'rembourse' ELSE 'perdu_acquis_helvetia' END;
END;
$$;

COMMIT;
