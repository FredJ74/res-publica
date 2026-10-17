-- NON DEPLOYEE. Depend de la precision monetaire. Regle bancaire validee.
BEGIN;
DO $garde$
DECLARE p pg_proc%rowtype;
BEGIN
 SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.prelever_loyer_bail(text)');
 IF NOT FOUND OR md5(p.prosrc) NOT IN ('ddd1f687b157f6b88cbd52a033556a2d','960d7f0d0d22ab9f11e0a8deae808673')
 OR NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
  RAISE EXCEPTION 'loyers: definition serveur differente de celle examinee';
 END IF;
END;
$garde$;
CREATE OR REPLACE FUNCTION public.prelever_loyer_bail(p_bail_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bail        locations_actives%ROWTYPE;
  v_data        jsonb;
  v_locataire   text;
  v_prix        numeric;
  v_dest        jsonb;
  v_dest_type   text;
  v_pays        text;
  v_ville       text;
  v_building    text;
  v_liquide     numeric;
  v_banque      numeric := 0;
  v_debit_banque numeric;
  v_reste       numeric;
  v_compte      record;
  v_pays_locataire text;
  v_jour        text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
  v_cle         text;
  v_titulaire   text;
  v_orga_id     text;
  v_orga_data   text;
  v_maj         integer;
  v_rec         jsonb;
  -- L'ardoise de l'impaye, desormais calculee ET posee ici : voir le bloc de la
  -- branche « expulsion_requise ».
  v_imp         jsonb;
  v_avise       boolean;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RAISE EXCEPTION 'appel_serveur_requis' USING ERRCODE='42501';
  END IF;
  -- Meme ordre entre loyers concurrents, y compris des baux de parties inversees.
  PERFORM pg_advisory_xact_lock(70491262);
  SELECT *
  INTO v_bail
  FROM locations_actives
  WHERE id = p_bail_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'bail_absent';
  END IF;

  v_data      := v_bail.data;
  v_locataire := v_data ->> 'locataire';
  v_prix      := COALESCE((v_data ->> 'prix')::numeric, 0)::public.hg_francs_exacts;

  -- Anti-rejeu : un seul prélèvement par bail et par jour réel.
  IF (v_data ->> 'jourPaiement') = v_jour THEN
    RETURN 'deja_preleve';
  END IF;

  -- Usages sans loyer réel.
  IF v_prix <= 0
     OR (v_data ->> 'chambreClinique') = 'true'
     OR v_locataire IS NULL
  THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  -- DESTINATION ATTESTEE (20 septembre 2026). Elle n'est plus lue dans le bail --
  -- ecriture directe falsifiable -- mais DERIVEE du local, par la meme regle que le
  -- client (destinationLoyerPourLocal). Le champ destinationLoyer du bail n'est plus
  -- qu'informatif. Fail-closed inchange : pas de destination -> pas de mouvement.
  v_dest := public.bail_destination_attestee(v_data);
  IF v_dest IS NULL THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;
    RETURN 'ignore_sans_loyer';
  END IF;

  IF v_dest IS NULL OR jsonb_typeof(v_dest) = 'null' THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  v_dest_type := v_dest ->> 'type';

  -- Verrou du locataire.
  SELECT liquide, country
  INTO v_liquide, v_pays_locataire
  FROM personnages
  WHERE name = v_locataire
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'locataire_absent';
  END IF;

  -- Banque nationale du pays du locataire, hors Helvetia et placements.
  -- Verrous conserves jusqu'au credit, au debit et au marqueur de paiement.
  FOR v_compte IN SELECT id,solde FROM public.comptes_bancaires
    WHERE personnage=v_locataire AND banque='nationale' AND pays=v_pays_locataire
    ORDER BY id FOR UPDATE
  LOOP
    v_banque:=v_banque+greatest(0,v_compte.solde);
  END LOOP;
  -- Aucun debit partiel si la somme disponible est insuffisante.
  IF v_banque + greatest(0,coalesce(v_liquide,0)) < v_prix THEN
    IF COALESCE((v_data ->> 'avertissement')::boolean, false) THEN
      -- ARDOISE ATOMIQUE (chantier 6, 9 octobre 2026). Cette branche etait LA SEULE sortie
      -- a effet a ne pas poser jourPaiement : un rejeu du cron la meme nuit rendait de
      -- nouveau « expulsion_requise », et l'appelant rajoutait un jour et un loyer a
      -- l'ardoise. La dette DOUBLAIT a chaque passe.
      --
      -- Poser le marqueur ne suffisait pas : l'appelant reecrivait le blob entier depuis
      -- une lecture ANTERIEURE a cet appel, et effacait donc le marqueur dans la foulee.
      -- Le calcul de l'ardoise descend ici, ou il devient atomique avec sa revendication :
      -- une RPC est une seule transaction, et v_data a ete lu FOR UPDATE.
      --
      -- La regle, elle, ne change pas (arbitrage du 8 septembre 2026) : aucune expulsion
      -- automatique, un impaye est un FAIT qu'on chiffre et qu'on conserve, et un seul
      -- avis a l'ouverture de l'ardoise. Aucun argent ne bouge : le loyer reste du.
      v_imp := CASE WHEN jsonb_typeof(v_data -> 'impaye') = 'object'
                    THEN v_data -> 'impaye' ELSE '{}'::jsonb END;
      v_avise := COALESCE((v_imp ->> 'avisEnvoye')::boolean, false);
      UPDATE locations_actives
         SET data = v_data || jsonb_build_object(
               'jourPaiement', v_jour,
               'impaye', jsonb_build_object(
                  'depuis',     COALESCE(v_imp ->> 'depuis', v_jour),
                  'jours',      COALESCE((v_imp ->> 'jours')::numeric, 0) + 1,
                  'montantDu',  COALESCE((v_imp ->> 'montantDu')::numeric, 0) + v_prix,
                  'avisEnvoye', true))
       WHERE id = p_bail_id;
      -- Deux verdicts distincts, parce que l'appelant n'a plus qu'une chose a faire et
      -- qu'elle depend de celui-ci : poster l'avis UNE fois, a l'ouverture.
      IF v_avise THEN
        RETURN 'expulsion_requise_deja_avise';
      END IF;
      RETURN 'expulsion_requise';
    END IF;

    UPDATE locations_actives
    SET data = v_data
      || jsonb_build_object(
           'avertissement', true,
           'jourPaiement', v_jour
         )
    WHERE id = p_bail_id;

    RETURN 'avertissement';
  END IF;

  -- Crédit de la destination.
  IF v_dest_type = 'municipal' THEN

    v_pays  := COALESCE(v_dest ->> 'pays',  v_data ->> 'country');
    v_ville := COALESCE(v_dest ->> 'ville', v_data ->> 'city');

    v_rec := public.recette_municipale(v_pays, v_ville, v_prix, 'loyer');
    IF NOT COALESCE((v_rec ->> 'ok')::boolean, false) THEN
      RAISE EXCEPTION 'destination_introuvable';
    END IF;

  ELSIF v_dest_type = 'titulaire_murs' THEN

    -- Le titulaire explicite n'est PLUS lu : c'etait la porte par laquelle un bail
    -- falsifie redirigeait le loyer. Le proprietaire ACTUEL fait foi, toujours.
    v_titulaire := NULL;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      SELECT (data::jsonb ->> 'proprietaire')
      INTO v_titulaire
      FROM terrains_etat
      WHERE country = (v_data ->> 'country')
        AND building_id = (v_data ->> 'buildingId');
    END IF;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      RAISE EXCEPTION 'destination_introuvable';
    END IF;

    -- Organisation propriétaire.
    IF left(v_titulaire, 5) = 'orga:' THEN

      v_orga_id := substr(v_titulaire, 6);

      IF v_orga_id = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      SELECT data
      INTO v_orga_data
      FROM organisations
      WHERE id = v_orga_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      IF v_orga_data IS NULL OR btrim(v_orga_data) = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      UPDATE organisations
      SET data = jsonb_set(
                   v_orga_data::jsonb,
                   '{caisse}',
                   to_jsonb(
                     COALESCE(
                       (v_orga_data::jsonb ->> 'caisse')::numeric,
                       0
                     ) + v_prix
                   )
                 )::text
      WHERE id = v_orga_id;

    ELSE

      -- PJ propriétaire, avec compatibilité ancien format nom brut.
      IF left(v_titulaire, 3) = 'pj:' THEN
        v_titulaire := substr(v_titulaire, 4);
      END IF;

      UPDATE personnages
      SET arg = COALESCE(arg, 0) + v_prix
      WHERE name = v_titulaire;

      GET DIAGNOSTICS v_maj = ROW_COUNT;

      IF v_maj = 0 THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

    END IF;

  ELSIF v_dest_type = 'caisse_batiment' THEN

    v_building := COALESCE(
      v_dest ->> 'buildingId',
      v_data ->> 'buildingId'
    );

    v_cle := (v_data ->> 'country') || '_' || v_building;

    UPDATE caisses_batiments
    SET data = jsonb_set(
                 COALESCE(data, '{}'::jsonb),
                 '{solde}',
                 to_jsonb(
                   COALESCE((data ->> 'solde')::numeric, 0) + v_prix
                 )
               ),
        updated_at = now()
    WHERE id = v_cle;

    GET DIAGNOSTICS v_maj = ROW_COUNT;

    IF v_maj = 0 THEN
      INSERT INTO caisses_batiments (id, data, updated_at)
      VALUES (
        v_cle,
        jsonb_build_object('solde', v_prix),
        now()
      );
    END IF;

  ELSE
    RAISE EXCEPTION 'destination_introuvable';
  END IF;

  -- Prelevement bancaire prioritaire puis complement liquide.
  -- Les contreparties et le marqueur restent dans la MEME transaction RPC.
  v_debit_banque:=least(v_prix,v_banque);
  v_reste:=v_debit_banque;
  FOR v_compte IN SELECT id,solde FROM public.comptes_bancaires
    WHERE personnage=v_locataire AND banque='nationale' AND pays=v_pays_locataire
    ORDER BY id FOR UPDATE
  LOOP
    UPDATE public.comptes_bancaires SET
      solde=solde-least(greatest(0,v_compte.solde),v_reste),updated_at=now()
      WHERE id=v_compte.id;
    v_reste:=v_reste-least(greatest(0,v_compte.solde),v_reste);
    EXIT WHEN v_reste=0;
  END LOOP;
  IF v_reste<>0 THEN RAISE EXCEPTION 'prelevement_bancaire_incomplet'; END IF;
  UPDATE public.personnages SET liquide=coalesce(liquide,0)-(v_prix-v_debit_banque)
    WHERE name=v_locataire;

  UPDATE locations_actives
  SET data = (v_data - 'avertissement')
    || jsonb_build_object(
         'jourPaiement', v_jour,
         'dernierLoyerPaye', v_jour
       )
  WHERE id = p_bail_id;

  RETURN 'paye';
END;
$function$;
REVOKE ALL ON FUNCTION public.prelever_loyer_bail(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.prelever_loyer_bail(text) TO service_role;
COMMIT;
