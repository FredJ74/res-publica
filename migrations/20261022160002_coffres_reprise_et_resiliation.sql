-- #69 PREPAREE. Consultation de recu et resiliation via le moteur commun.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_recu(text)');IF h IS NOT NULL AND h<>'e3ec4f06a139aaacb37fc8cd96b1db47' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_recu(text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_resilier(text,uuid,bigint)');IF h IS NOT NULL AND h<>'1b79b38926f8301cccf63a79dd93fcf3' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_resilier(text,uuid,bigint)';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.coffre_recu(p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p uuid;n text:=public.mon_personnage();
BEGIN
 SELECT id INTO p FROM public.personnages_donnees WHERE name=n AND user_id=auth.uid();
 IF p IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 RETURN jsonb_build_object('ok',true,'terminee',EXISTS(SELECT 1 FROM public.coffres_requetes WHERE personnage_id=p AND requete=p_requete));
END;$f$;
CREATE OR REPLACE FUNCTION public.coffre_resilier(p_requete text,p_coffre uuid,p_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();p uuid;c public.coffres_bancaires;commande jsonb;rec record;r jsonb;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 PERFORM public.inventaire_reception_etat(n);SELECT id INTO p FROM public.personnages_donnees WHERE name=n;
 IF p_requete IS NULL OR p_requete !~ '^coffre-[A-Za-z0-9-]{8,100}$' THEN RAISE EXCEPTION 'requete_invalide';END IF;
 commande:=jsonb_build_object('action','resilier','coffre',p_coffre,'revision',p_revision);
 SELECT * INTO rec FROM public.coffres_requetes WHERE personnage_id=p AND requete=p_requete;
 IF FOUND THEN
  IF rec.commande IS DISTINCT FROM commande THEN RAISE EXCEPTION 'requete_reutilisee';END IF;
  RETURN rec.resultat||jsonb_build_object('rejeu',true);
 END IF;
 c:=public.coffre_verrouiller_interne(p_coffre,p,n);
 IF c.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'coffre_perime';END IF;
 r:=public.resilier_bail_volontaire(c.bail_id,n);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r;END IF;
 r:=jsonb_build_object('ok',true,'coffre',p_coffre,'resilie',true);
 INSERT INTO public.coffres_requetes(personnage_id,requete,commande,resultat) VALUES(p,p_requete,commande,r);
 RETURN r;
EXCEPTION WHEN raise_exception THEN
 IF SQLERRM=ANY(ARRAY['requete_invalide','requete_reutilisee','coffre_inaccessible','contrat_modifie','coffre_perime']) THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;RAISE;
END;$f$;
REVOKE ALL ON FUNCTION public.coffre_recu(text),public.coffre_resilier(text,uuid,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coffre_recu(text),public.coffre_resilier(text,uuid,bigint) TO authenticated;
COMMIT;
