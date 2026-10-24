-- Definition vivante observee le 24 octobre, empreinte 049b15670cb9f660338ab7d20ac31192.
-- Fixture documentaire : aucune application de cette enveloppe en production.
BEGIN;
SET LOCAL check_function_bodies=off;
CREATE OR REPLACE FUNCTION public.creer_fonds_commerce(p_proprietaire text, p_bail_id text, p_fonds_id text, p_apport integer, p_enseigne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bail jsonb;
  v_apport integer := GREATEST(0, COALESCE(p_apport, 0));
  v_lot text;
  v_deja integer;
  v_vocation text;
BEGIN
  IF COALESCE(p_proprietaire, '') = '' OR COALESCE(p_bail_id, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  -- Reference TYPEE, comme tout le reste de cette fonction : `mouvement_titulaire` plus bas et
  -- la comparaison au locataire du bail acceptent deja les deux formes. Seule cette garde
  -- exigeait un nom nu, ce qui tuait le chemin doGererFondsCommerce (ctx.ref = 'pj:<nom>').
  IF NOT public.acteur_est_moi(p_proprietaire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_titulaire');
  END IF;
  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
  SELECT count(*) INTO v_deja FROM entreprises WHERE id = p_fonds_id;
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_id_deja_pris'; END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RAISE EXCEPTION 'bail_absent'; END IF;
  IF (v_bail ->> 'locataire') IS DISTINCT FROM p_proprietaire
     AND ('pj:' || COALESCE(v_bail ->> 'locataire', '')) IS DISTINCT FROM p_proprietaire THEN
    RAISE EXCEPTION 'pas_titulaire';
  END IF;

  v_vocation := public.local_vocation_commerciale(v_bail ->> 'buildingId');
  IF v_vocation IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'local_non_commercial',
                              'batiment', v_bail ->> 'buildingId');
  END IF;

  SELECT count(*) INTO v_deja FROM entreprises
   WHERE data -> 'implantation' ->> 'bailId' = p_bail_id
     AND COALESCE(data ->> 'statut', 'actif') = 'actif';
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_deja_present'; END IF;
  v_lot := v_bail ->> 'lotId';
  INSERT INTO entreprises (id, data, updated_at)
  VALUES (p_fonds_id, jsonb_build_object(
    'id', p_fonds_id,
    'version', 2,
    'type', 'fonds_commerce',
    'enseigne', COALESCE(NULLIF(btrim(COALESCE(p_enseigne, '')), ''), 'Fonds de commerce'),
    'proprietaire', p_proprietaire,
    'statut', 'actif',
    'caisse', v_apport,
    'implantation', jsonb_build_object(
      'country', v_bail ->> 'country', 'city', v_bail ->> 'city',
      'buildingId', v_bail ->> 'buildingId', 'roomId', v_bail ->> 'roomId',
      'lotId', v_lot, 'localKey', v_bail ->> 'localKey', 'bailId', p_bail_id,
      'vocation', v_vocation),
    'typesAutorises',      '[]'::jsonb,
    'references',          '{}'::jsonb,
    'stockReferences',     '{}'::jsonb,
    'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres',       '{}'::jsonb,
    'coutMoyenMatieres',   '{}'::jsonb,
    'stockProduits',       '{}'::jsonb,
    'historique', jsonb_build_array(jsonb_build_object(
      'evenement', 'creation', 'proprietaire', p_proprietaire, 'apport', v_apport,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')))
  ), now());
  UPDATE locations_actives SET data = v_bail || jsonb_build_object('fondsId', p_fonds_id) WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'caisse', v_apport,
                            'apport', v_apport, 'proprietaire', p_proprietaire,
                            'vocation', v_vocation, 'typesMax', public.fonds_types_max(p_proprietaire));
END;
$function$;
CREATE OR REPLACE FUNCTION public.acteur_est_moi(p_ref text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.est_appel_serveur() OR public.titulaire_est_moi(p_ref);
$function$;
ROLLBACK;

