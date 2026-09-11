BEGIN;

CREATE OR REPLACE FUNCTION public.regler_creances_helvetia_quotidien(p_pays text)
RETURNS TABLE(creance_id text, type_creance text, action text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_caisse_id text := p_pays || '_banque-privee';
  v_caisse numeric;
  v_item record;
BEGIN
  SELECT COALESCE((data->>'solde')::numeric, 0) INTO v_caisse
    FROM public.caisses_batiments WHERE id = v_caisse_id FOR UPDATE;
  IF NOT FOUND THEN v_caisse := 0; END IF;

  FOR v_item IN
    SELECT id, 'obligation'::text AS type, created_at AS exigible_depuis
      FROM public.obligations_helvetia WHERE country = p_pays AND statut = 'due'
    UNION ALL
    SELECT id, 'bnr'::text AS type, jour_echeance AS exigible_depuis
      FROM public.bnr_refinancements_helvetia WHERE country = p_pays AND statut = 'actif' AND jour_echeance <= now()
    ORDER BY exigible_depuis ASC
  LOOP
    IF v_item.type = 'obligation' THEN
      DECLARE
        v_obl public.obligations_helvetia%rowtype;
        v_paye numeric;
      BEGIN
        SELECT * INTO v_obl FROM public.obligations_helvetia WHERE id = v_item.id FOR UPDATE;
        IF NOT FOUND OR v_obl.statut <> 'due' THEN CONTINUE; END IF;

        v_paye := LEAST(v_caisse, v_obl.montant_du);
        IF v_paye <= 0 THEN CONTINUE; END IF;

        v_caisse := v_caisse - v_paye;
        PERFORM public.helvetia_crediter_destination(v_obl.beneficiaire, v_paye, v_obl.destination_type);
        UPDATE public.personnages SET arg = COALESCE(arg,0) + v_paye WHERE name = v_obl.beneficiaire;

        IF v_paye >= v_obl.montant_du THEN
          UPDATE public.obligations_helvetia SET statut = 'soldee', montant_du = 0, updated_at = now() WHERE id = v_obl.id;
          creance_id := v_obl.id; type_creance := 'obligation'; action := 'soldee'; RETURN NEXT;
        ELSE
          UPDATE public.obligations_helvetia SET montant_du = montant_du - v_paye, updated_at = now() WHERE id = v_obl.id;
          creance_id := v_obl.id; type_creance := 'obligation'; action := 'paiement_partiel'; RETURN NEXT;
        END IF;
      END;
    ELSE
      DECLARE
        v_bnr public.bnr_refinancements_helvetia%rowtype;
        v_total_du numeric;
      BEGIN
        SELECT * INTO v_bnr FROM public.bnr_refinancements_helvetia WHERE id = v_item.id FOR UPDATE;
        IF NOT FOUND OR v_bnr.statut <> 'actif' THEN CONTINUE; END IF;

        v_total_du := v_bnr.montant + v_bnr.interets_cumules + ROUND(v_bnr.montant * v_bnr.taux_courant / 100);

        IF v_caisse >= v_total_du THEN
          v_caisse := v_caisse - v_total_du;
          UPDATE public.bnr_refinancements_helvetia SET statut = 'rembourse', updated_at = now() WHERE id = v_bnr.id;
          creance_id := v_bnr.id; type_creance := 'bnr'; action := 'remboursee'; RETURN NEXT;
        ELSE
          UPDATE public.bnr_refinancements_helvetia
            SET interets_cumules = interets_cumules + ROUND(montant * taux_courant / 100),
                taux_courant = taux_courant + 1,
                nb_tranches = nb_tranches + 1,
                jour_echeance = jour_echeance + interval '7 days',
                updated_at = now()
            WHERE id = v_bnr.id;
          creance_id := v_bnr.id; type_creance := 'bnr'; action := 'prorogee'; RETURN NEXT;
        END IF;
      END;
    END IF;
  END LOOP;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(v_caisse)), updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_caisse), now());
  END IF;

  RETURN;
END;
$$;

COMMIT;
