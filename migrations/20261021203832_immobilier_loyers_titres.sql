-- #66 PREPAREE : baux conserves, meme perception ; seule l'autorite du bailleur evolue.
BEGIN;
DO $g$ DECLARE h text;BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.bail_destination_attestee(jsonb)');
 IF h IS NULL OR h NOT IN('4f8f753b7aefcf18809664fc504049b5','570465a770490a16d359b038dc4c7bba') THEN RAISE EXCEPTION 'definition_non_examinee: bail_destination_attestee';END IF;
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.prelever_loyer_bail(text)');
 IF h IS NULL OR h NOT IN('ddd1f687b157f6b88cbd52a033556a2d','944b4d5929b11b1775eccc532df15eaa') THEN RAISE EXCEPTION 'definition_non_examinee: prelever_loyer_bail';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.bail_destination_attestee(p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path=public,pg_temp
AS $function$
DECLARE bien text; titulaire text;
BEGIN
 IF coalesce((p_data->>'chambreClinique')::boolean,false) OR coalesce((p_data->>'isBox')::boolean,false) THEN
  RETURN CASE WHEN coalesce((p_data->>'isBox')::boolean,false) THEN jsonb_build_object('type','caisse_batiment','buildingId',p_data->>'buildingId') ELSE NULL END;
 END IF;
 SELECT id INTO bien FROM public.immobilier_biens WHERE pays=p_data->>'country' AND ville=p_data->>'city' AND building_id=p_data->>'buildingId';
 IF bien IS NOT NULL THEN
  titulaire:=public.immobilier_titulaire(bien,'murs');
  IF left(titulaire,6)='ville:' THEN RETURN jsonb_build_object('type','municipal','pays',p_data->>'country','ville',p_data->>'city');END IF;
  RETURN jsonb_build_object('type','titulaire_murs');
 END IF;
 RETURN CASE WHEN left(coalesce(p_data->>'roomId',''),8)='lot_dyn_' THEN jsonb_build_object('type','titulaire_murs')
  ELSE jsonb_build_object('type','municipal','pays',coalesce(p_data->>'country','republic'),'ville',coalesce(p_data->>'city','capitale')) END;
END;
$function$;
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
  v_arg         numeric;
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
  v_prix      := COALESCE((v_data ->> 'prix')::numeric, 0);

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
  SELECT arg
  INTO v_arg
  FROM personnages
  WHERE name = v_locataire
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'locataire_absent';
  END IF;

  -- Impayé.
  IF COALESCE(v_arg, 0) < v_prix THEN
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
      FROM terrains_etat t
      WHERE (t.id=(SELECT b.terrain_id FROM public.immobilier_biens b
         WHERE b.pays=v_data->>'country' AND b.ville=v_data->>'city' AND b.building_id=v_data->>'buildingId'))
        OR (NOT EXISTS(SELECT 1 FROM public.immobilier_biens b WHERE b.pays=v_data->>'country'
         AND b.ville=v_data->>'city' AND b.building_id=v_data->>'buildingId')
         AND t.country=v_data->>'country' AND t.building_id=v_data->>'buildingId');
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

  -- Débit du locataire seulement après crédit valide.
  UPDATE personnages
  SET arg = COALESCE(arg, 0) - v_prix
  WHERE name = v_locataire;

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
REVOKE ALL ON FUNCTION public.bail_destination_attestee(jsonb) FROM PUBLIC,anon,authenticated;
COMMIT;
