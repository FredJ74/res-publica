BEGIN;

CREATE OR REPLACE FUNCTION public.traiter_prets_helvetia_quotidien()
RETURNS TABLE(pret_id text, action text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_pret record;
  v_perso public.personnages%rowtype;
  v_compte_helvetia public.comptes_bancaires%rowtype;
  v_compte_national public.comptes_bancaires%rowtype;
  v_caisse_id text;
  v_du numeric;
  v_dispo numeric;
  v_a_prelever numeric;
  v_seize numeric;
  v_bien record;
BEGIN
  FOR v_pret IN
    SELECT * FROM public.prets
    WHERE type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')
    ORDER BY id FOR UPDATE
  LOOP
    IF v_pret.accord_actif THEN
      IF now() >= v_pret.accord_fin_le THEN
        UPDATE public.prets SET accord_actif = false WHERE id = v_pret.id;
      ELSIF now() >= v_pret.accord_fin_le - interval '1 day' AND NOT v_pret.accord_avertissement_envoye THEN
        UPDATE public.prets SET accord_avertissement_envoye = true WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Dernier délai',
            'Réglez l''intégralité de votre dette avant minuit demain, faute de quoi le recouvrement reprendra.',
            now()::text, false, false);
        pret_id := v_pret.id; action := 'avertissement_accord'; RETURN NEXT;
        CONTINUE;
      ELSE
        pret_id := v_pret.id; action := 'gele_accord'; RETURN NEXT;
        CONTINUE;
      END IF;
    END IF;

    SELECT * INTO v_perso FROM public.personnages WHERE name = v_pret.emprunteur FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT * INTO v_compte_helvetia FROM public.comptes_bancaires
      WHERE personnage = v_pret.emprunteur AND banque = 'helvetia' FOR UPDATE;
    SELECT * INTO v_compte_national FROM public.comptes_bancaires
      WHERE personnage = v_pret.emprunteur AND banque = 'nationale' FOR UPDATE;
    v_caisse_id := v_pret.country || '_banque-privee';

    IF v_pret.statut = 'en_cours' THEN
      v_dispo := GREATEST(0, COALESCE(v_compte_helvetia.solde,0) - 10000);
      v_a_prelever := LEAST(v_pret.mensualite, v_pret.montant_restant);

      IF v_dispo >= v_a_prelever THEN
        UPDATE public.comptes_bancaires SET solde = solde - v_a_prelever, updated_at = now()
          WHERE personnage = v_pret.emprunteur AND banque = 'helvetia';
        UPDATE public.caisses_batiments
          SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_a_prelever)), updated_at = now()
          WHERE id = v_caisse_id;
        IF NOT FOUND THEN
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_a_prelever), now());
        END IF;
        UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_a_prelever) WHERE name = v_pret.emprunteur;

        IF v_pret.montant_restant - v_a_prelever <= 0 THEN
          UPDATE public.prets SET montant_restant = 0, jours_impayes = 0, statut = 'rembourse' WHERE id = v_pret.id;
          pret_id := v_pret.id; action := 'solde'; RETURN NEXT;
        ELSE
          UPDATE public.prets SET montant_restant = montant_restant - v_a_prelever, jours_impayes = 0 WHERE id = v_pret.id;
          pret_id := v_pret.id; action := 'preleve'; RETURN NEXT;
        END IF;
        CONTINUE;
      END IF;

      IF v_pret.jours_impayes + 1 >= 2 THEN
        UPDATE public.prets SET jours_impayes = jours_impayes + 1, statut = 'contentieux' WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Mise en demeure',
            'La totalité du capital restant dû est désormais exigible immédiatement.', now()::text, false, false);
        pret_id := v_pret.id; action := 'passe_contentieux'; RETURN NEXT;
      ELSE
        UPDATE public.prets SET jours_impayes = jours_impayes + 1 WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Avertissement',
            'Votre échéance n''a pas pu être prélevée.', now()::text, false, false);
        pret_id := v_pret.id; action := 'avertissement'; RETURN NEXT;
        CONTINUE;
      END IF;
    END IF;

    IF NOT v_pret.saisie_financiere_faite THEN
      v_du := v_pret.montant_restant;

      v_seize := LEAST(COALESCE(v_compte_helvetia.solde,0), v_du);
      IF v_seize > 0 THEN
        UPDATE public.comptes_bancaires SET solde = solde - v_seize, updated_at = now()
          WHERE personnage = v_pret.emprunteur AND banque = 'helvetia';
        UPDATE public.caisses_batiments
          SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_seize)), updated_at = now()
          WHERE id = v_caisse_id;
        IF NOT FOUND THEN
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_seize), now());
        END IF;
        UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_seize) WHERE name = v_pret.emprunteur;
        v_du := v_du - v_seize;
      END IF;

      IF v_du > 0 AND v_compte_national.solde IS NOT NULL THEN
        v_seize := LEAST(v_compte_national.solde, v_du);
        IF v_seize > 0 THEN
          UPDATE public.comptes_bancaires SET solde = solde - v_seize, updated_at = now()
            WHERE personnage = v_pret.emprunteur AND banque = 'nationale';
          UPDATE public.caisses_batiments
            SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_seize)), updated_at = now()
            WHERE id = v_caisse_id;
          IF NOT FOUND THEN
            INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_seize), now());
          END IF;
          UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_seize) WHERE name = v_pret.emprunteur;
          v_du := v_du - v_seize;
        END IF;
      END IF;

      IF v_du > 0 AND COALESCE(v_perso.liquide,0) > 0 THEN
        v_seize := LEAST(v_perso.liquide, v_du);
        UPDATE public.personnages SET liquide = liquide - v_seize, arg = GREATEST(0, COALESCE(arg,0) - v_seize)
          WHERE name = v_pret.emprunteur;
        UPDATE public.caisses_batiments
          SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_seize)), updated_at = now()
          WHERE id = v_caisse_id;
        IF NOT FOUND THEN
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_seize), now());
        END IF;
        v_du := v_du - v_seize;
      END IF;

      UPDATE public.prets SET montant_restant = v_du, saisie_financiere_faite = true WHERE id = v_pret.id;
      v_pret.montant_restant := v_du;

      IF v_du <= 0 THEN
        UPDATE public.prets SET statut = 'rembourse' WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'solde_par_saisie'; RETURN NEXT;
        CONTINUE;
      END IF;
      pret_id := v_pret.id; action := 'ladder_financier_execute'; RETURN NEXT;
    END IF;

    IF NOT v_pret.proposition_en_attente THEN
      SELECT t.id, t.data,
             (COALESCE((t.data::jsonb->>'valeur_totale')::numeric,0) +
               CASE t.data::jsonb->>'niveau_construction'
                 WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
                 WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END
             ) AS valeur
        INTO v_bien
        FROM public.terrains_etat t
        WHERE t.country = v_pret.country
          AND (t.data::jsonb->>'proprietaire') = v_pret.emprunteur
          AND t.id NOT IN (SELECT terrain_id FROM public.biens_saisis_helvetia WHERE pret_id = v_pret.id)
        ORDER BY
          (CASE WHEN (COALESCE((t.data::jsonb->>'valeur_totale')::numeric,0) +
               CASE t.data::jsonb->>'niveau_construction'
                 WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
                 WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END) >= v_pret.montant_restant THEN 0 ELSE 1 END),
          ABS((COALESCE((t.data::jsonb->>'valeur_totale')::numeric,0) +
               CASE t.data::jsonb->>'niveau_construction'
                 WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
                 WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END) - v_pret.montant_restant)
        LIMIT 1;

      IF FOUND THEN
        UPDATE public.prets SET bien_cible_id = v_bien.id, proposition_en_attente = true WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Bien ciblé — proposition d''accord',
            'À défaut de règlement, le bien ' || v_bien.id || ' sera saisi. Un accord amiable reste possible.',
            now()::text, false, false);
        pret_id := v_pret.id; action := 'bien_cible_et_propose'; RETURN NEXT;
      ELSE
        UPDATE public.prets SET proposition_en_attente = true WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Proposition d''accord',
            'Un bien pourrait être saisi. Un accord amiable reste possible.', now()::text, false, false);
        pret_id := v_pret.id; action := 'proposition_sans_bien'; RETURN NEXT;
      END IF;
      CONTINUE;
    END IF;

    IF v_pret.bien_cible_id IS NULL THEN
      SELECT t.id INTO v_bien
        FROM public.terrains_etat t
        WHERE t.country = v_pret.country
          AND (t.data::jsonb->>'proprietaire') = v_pret.emprunteur
          AND t.id NOT IN (SELECT terrain_id FROM public.biens_saisis_helvetia WHERE pret_id = v_pret.id)
        LIMIT 1;

      IF FOUND THEN
        UPDATE public.prets SET proposition_en_attente = false WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'nouveau_bien_detecte'; RETURN NEXT;
        CONTINUE;
      END IF;

      IF v_pret.fraude_affaire_id IS NOT NULL THEN
        pret_id := v_pret.id; action := 'attente_fraude'; RETURN NEXT;
      ELSE
        UPDATE public.prets SET montant_restant = 0, statut = 'perte_absorbee' WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'perte_absorbee'; RETURN NEXT;
      END IF;
      CONTINUE;
    END IF;

    DECLARE
      v_terrain_row record;
      v_terrain_data jsonb;
      v_valeur numeric;
      v_coprop text;
      v_quote_part numeric;
      v_bien_id text;
    BEGIN
      SELECT id, data INTO v_terrain_row FROM public.terrains_etat WHERE id = v_pret.bien_cible_id FOR UPDATE;

      IF NOT FOUND OR (v_terrain_row.data::jsonb->>'proprietaire') <> v_pret.emprunteur THEN
        UPDATE public.prets SET bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'cible_invalide_recible'; RETURN NEXT;
        CONTINUE;
      END IF;

      v_terrain_data := v_terrain_row.data::jsonb;
      v_coprop := v_terrain_data->>'coproprietaire';
      v_valeur := COALESCE((v_terrain_data->>'valeur_totale')::numeric,0) +
        CASE v_terrain_data->>'niveau_construction'
          WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
          WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END;

      v_terrain_data := v_terrain_data || jsonb_build_object('proprietaire','Helvetia');
      UPDATE public.terrains_etat SET data = v_terrain_data::text, updated_at = now() WHERE id = v_terrain_row.id;

      v_bien_id := 'bien-' || v_pret.id || '-' || extract(epoch from clock_timestamp())::bigint;

      IF v_coprop IS NULL THEN
        IF v_valeur >= v_pret.montant_restant THEN
          DECLARE
            v_surplus numeric := v_valeur - v_pret.montant_restant;
            v_frais numeric := ROUND(v_surplus * 0.10);
            v_restitution numeric := v_surplus - v_frais;
          BEGIN
            UPDATE public.prets SET montant_restant = 0, statut = 'rembourse',
                bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
            INSERT INTO public.biens_saisis_helvetia
              (id, terrain_id, pret_id, country, city, valeur_objective, coproprietaire, quote_part_coproprietaire, prix_notaire)
              VALUES (v_bien_id, v_terrain_row.id, v_pret.id, v_pret.country, v_terrain_data->>'city',
                      v_valeur, NULL, NULL, v_valeur);
            IF v_restitution > 0 THEN
              INSERT INTO public.obligations_helvetia (id, country, beneficiaire, montant_du, motif, bien_id, pret_id, destination_type)
                VALUES ('obl-'||v_bien_id, v_pret.country, v_pret.emprunteur, v_restitution, 'surplus_saisie', v_bien_id, v_pret.id, 'liquide');
            END IF;
          END;
          pret_id := v_pret.id; action := 'saisie_bien_solde'; RETURN NEXT;
        ELSE
          UPDATE public.prets SET montant_restant = montant_restant - v_valeur,
              bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
          INSERT INTO public.biens_saisis_helvetia
            (id, terrain_id, pret_id, country, city, valeur_objective, coproprietaire, quote_part_coproprietaire, prix_notaire)
            VALUES (v_bien_id, v_terrain_row.id, v_pret.id, v_pret.country, v_terrain_data->>'city',
                    v_valeur, NULL, NULL, v_valeur);
          pret_id := v_pret.id; action := 'saisie_bien_partiel'; RETURN NEXT;
        END IF;
      ELSE
        v_quote_part := v_valeur / 2;
        INSERT INTO public.biens_saisis_helvetia
          (id, terrain_id, pret_id, country, city, valeur_objective, coproprietaire, quote_part_coproprietaire, prix_notaire)
          VALUES (v_bien_id, v_terrain_row.id, v_pret.id, v_pret.country, v_terrain_data->>'city',
                  v_valeur, v_coprop, v_quote_part, v_valeur);
        UPDATE public.prets SET bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Bien en copropriété saisi',
            'Le bien est saisi et mis en vente. Sa quote-part protégée sera réglée à votre copropriétaire à la revente.',
            now()::text, false, false);
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_coprop, 'Banque Privée Helvetia', 'Bien en copropriété saisi',
            'Un bien que vous détenez en copropriété avec ' || v_pret.emprunteur || ' a été saisi au titre d''une dette qui ne vous concerne pas. Votre quote-part (' || v_quote_part || ') est protégée et vous sera réglée à la revente.',
            now()::text, false, false);
        pret_id := v_pret.id; action := 'saisie_bien_copropriete_en_vente'; RETURN NEXT;
      END IF;
    END;
  END LOOP;
  RETURN;
END;
$$;

COMMIT;
