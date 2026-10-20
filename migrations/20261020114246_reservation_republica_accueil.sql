-- Reservation du Republica : accueil uniquement ; paiements et diners conserves.
-- Ne pas appliquer sans lecture du catalogue vivant, droits et empreintes metier.
-- Aucun appel metier ni mutation de joueur dans la migration : DDL transactionnel seulement.
BEGIN;
DO $prevol$
BEGIN
 IF to_regprocedure('public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text)') IS NULL
 OR to_regprocedure('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)') IS NULL THEN
  RAISE EXCEPTION 'precondition_moteur_restaurant_absent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass AND attname='reservation_hotel' AND atttypid='jsonb'::regtype AND NOT attisdropped)
 OR NOT EXISTS(SELECT 1 FROM public.pa_bonus_hotel WHERE building_id='hotel-republica' AND montant=2) THEN
  RAISE EXCEPTION 'precondition_reservation_ou_bonus_different'; END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_est_commerce(jsonb)')) IS DISTINCT FROM 'ff46b5a0cdb7d2004b8da184e40cce23' THEN RAISE EXCEPTION 'precondition_perimetre_hotel_modifie'; END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text)'::regprocedure)
 NOT IN ('125f48ea10cde52aab45689599f1229e','d1b77cb54585e1eb0fe257f000ce956b') THEN RAISE EXCEPTION 'precondition_controle_vente_modifie'; END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)
 NOT IN ('3b1a95240f0adb8234a1b6d3752444d1','e7196487095f71e9e60c8a162c648032') THEN RAISE EXCEPTION 'precondition_encaissement_modifie'; END IF;
 IF to_regprocedure('public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text,text)') IS NOT NULL AND
 (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text,text)')) IS DISTINCT FROM '85fa9d4fc535f3ac4970d0bee5521bf6'
 THEN RAISE EXCEPTION 'precondition_controle_vente_cinq_arguments_modifie'; END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb,acteur text,produits jsonb,mode_vente text,ordre text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica'
  AND CASE WHEN ordre='reserver_chambre_hotel' THEN current_room='accueil' ELSE current_room IN('bar','restaurant') END)
 THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF d->>'versionGastronomieLuthecia' IS DISTINCT FROM '1' THEN RETURN '{"ok":false,"raison":"carte_non_installee"}'; END IF;
 IF ordre='reserver_chambre_hotel' THEN
  -- Une prestation exacte, sans articles ni autre mode, a l'accueil uniquement.
  IF mode_vente IS DISTINCT FROM 'service' OR produits IS DISTINCT FROM '[]'::jsonb THEN
   RETURN '{"ok":false,"raison":"reservation_invalide"}';
  END IF;
 ELSE
  -- Le service des diners reste reserve a sa porte atomique existante.
  IF mode_vente='service' AND current_setting('rp.diner_luthecia',true) IS DISTINCT FROM 'on' THEN
   RETURN '{"ok":false,"raison":"service_par_invitation_requis"}';
  END IF;
 END IF;
 RETURN '{"ok":true}';
END $fn$;
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb,acteur text,produits jsonb,mode_vente text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
BEGIN
 -- Compatibilite des appels historiques : aucune reservation deduite d'un panier vide.
 RETURN public.restaurant_luthecia_vente_verifier(d,acteur,produits,mode_vente,NULL);
END $fn$;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
DO $moteur$
DECLARE s text;
BEGIN
 SELECT pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure) INTO s;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)='3b1a95240f0adb8234a1b6d3752444d1' THEN
  s:=replace(s,$avant$public.restaurant_luthecia_vente_verifier(v_data,p_acteur,p_produits,p_mode)$avant$,$apres$public.restaurant_luthecia_vente_verifier(v_data,p_acteur,p_produits,p_mode,p_ordre)$apres$);
  s:=replace(s,$avant$  RETURN jsonb_build_object('ok', true, 'mode', p_mode,$avant$,$apres$  -- La chambre payee survit meme si le navigateur se ferme avant sa sauvegarde.
  -- Aucun second paiement : meme transaction que payer_ordre, taxe et caisse ci-dessus.
  IF public.restaurant_luthecia_est_commerce(v_data) AND p_ordre='reserver_chambre_hotel' THEN
    UPDATE public.personnages_donnees
       SET reservation_hotel=jsonb_build_object('buildingId','hotel-republica',
             'bonus',jsonb_build_object('moral',3,'paBonus',
               (SELECT montant FROM public.pa_bonus_hotel WHERE building_id='hotel-republica'))),
           updated_at=now()
     WHERE name=p_acteur;
  END IF;

  RETURN jsonb_build_object('ok', true, 'mode', p_mode,$apres$);
  EXECUTE s;
 END IF;
END $moteur$;
DO $verification$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure) IS DISTINCT FROM 'e7196487095f71e9e60c8a162c648032' THEN
  RAISE EXCEPTION 'correction_encaissement_non_confirmee'; END IF;
 IF has_function_privilege('authenticated','public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)','EXECUTE') THEN
  RAISE EXCEPTION 'moteur_interne_expose'; END IF;
END $verification$;
COMMIT;
