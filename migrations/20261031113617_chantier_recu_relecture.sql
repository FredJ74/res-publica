-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022125121_chantier_recu_relecture.sql ; aucun changement de règle.
-- #57 PREPAREE : consultation privee d'un recu, sans rejeu automatique de commande.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande_recu(text)'); IF h IS NOT NULL AND h<>'743399b3f090658d03394cb7af037336' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande_recu(text)';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_commande_recu(p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();r record;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT * INTO r FROM public.chantier_commandes_recus cr WHERE cr.acteur=n AND cr.requete=p_requete AND cr.personnage_id=(SELECT id FROM public.personnages_donnees WHERE name=n);
 RETURN jsonb_build_object('ok',true,'terminee',FOUND);
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_commande_recu(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.chantier_commande_recu(text) TO authenticated;
COMMIT;
