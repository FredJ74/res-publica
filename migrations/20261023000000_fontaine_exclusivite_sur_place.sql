-- #110. Prerequis: empruntes des deux RPC vivantes; migration transactionnelle.
-- PREPAREE : executer tests PostgreSQL jetable avant production.
BEGIN;
DO $g$ DECLARE a text;c text;BEGIN
 SELECT md5(prosrc) INTO a FROM pg_proc WHERE oid=to_regprocedure('public.acheter_produit_commerce(text,text,text,text,integer)');
 SELECT md5(prosrc) INTO c FROM pg_proc WHERE oid=to_regprocedure('public.consommer_sur_place_commerce(text,text,text,text)');
 IF a IS DISTINCT FROM '1c5e04f8c73e2ddb64f0b14686b4a931' OR c IS DISTINCT FROM 'a2fa09c304ac4090945db10959719b48'
 THEN RAISE EXCEPTION 'moteur_commerce_non_examine'; END IF;
 IF to_regprocedure('public.acheter_produit_commerce_interne(text,text,text,text,integer)') IS NOT NULL
 THEN RAISE EXCEPTION 'moteur_interne_deja_present'; END IF;
END $g$;
-- L'ancien moteur atomique est reserve aux seules fonctions privilegiees.
ALTER FUNCTION public.acheter_produit_commerce(text,text,text,text,integer)
 RENAME TO acheter_produit_commerce_interne;
REVOKE ALL ON FUNCTION public.acheter_produit_commerce_interne(text,text,text,text,integer) FROM PUBLIC,anon,authenticated;
-- La consommation authentifiee conserve paiement, stock, suppression de livraison
-- et effets dans une seule transaction, sans second moteur financier.
DO $g$ DECLARE d text;needle constant text:='public.acheter_produit_commerce(';BEGIN
 SELECT pg_get_functiondef(oid) INTO d FROM pg_proc
 WHERE oid=to_regprocedure('public.consommer_sur_place_commerce(text,text,text,text)');
 IF d IS NULL OR (length(d)-length(replace(d,needle,'')))/length(needle)<>1
 THEN RAISE EXCEPTION 'appel_consommation_non_reconnu';END IF;
 EXECUTE replace(d,needle,'public.acheter_produit_commerce_interne(');
END $g$;
-- L'API d'achat a emporter ne peut plus traiter une reference reservee sur place.
CREATE FUNCTION public.acheter_produit_commerce(p_requete text,p_acheteur text,p_fonds_id text,p_reference_id text,p_quantite integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE r boolean;
BEGIN
 SELECT coalesce((data->'references'->p_reference_id->>'venteSurPlaceUniquement')::boolean,false)
 INTO r FROM public.entreprises WHERE id=p_fonds_id;
 IF r IS TRUE THEN RETURN jsonb_build_object('ok',false,'raison','consommation_sur_place_uniquement');END IF;
 RETURN public.acheter_produit_commerce_interne(p_requete,p_acheteur,p_fonds_id,p_reference_id,p_quantite);
END $f$;
REVOKE ALL ON FUNCTION public.acheter_produit_commerce(text,text,text,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.acheter_produit_commerce(text,text,text,text,integer) TO authenticated;
COMMIT;
