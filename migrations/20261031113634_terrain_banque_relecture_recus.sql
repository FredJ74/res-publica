-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024123800_terrain_banque_relecture_recus.sql ; aucun changement de règle.
BEGIN;
DO $nouveau$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='finance_terrain_banque_recu' AND (p.oid IS DISTINCT FROM to_regprocedure('public.finance_terrain_banque_recu(uuid,text)') OR md5(p.prosrc)<>'6925a058b372ee1082f5cbbf18edd241')) THEN RAISE EXCEPTION 'definition_non_examinee: finance_terrain_banque_recu';END IF;END;$nouveau$;

CREATE OR REPLACE FUNCTION public.finance_terrain_banque_recu(p_requete uuid,p_domaine text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();r jsonb;e jsonb;terrain text;
BEGIN
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 IF p_domaine='acquisition' THEN
  SELECT resultat,a.terrain INTO r,terrain FROM public.terrain_acquisitions_recus a WHERE a.acteur=moi AND a.requete=p_requete;
  IF FOUND THEN SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=terrain;END IF;
 ELSIF p_domaine='pret' THEN
  SELECT resultat INTO r FROM public.prets_nationaux_demandes WHERE acteur=moi AND requete=p_requete;
 ELSE RETURN jsonb_build_object('ok',false,'raison','domaine_inconnu');END IF;
 RETURN jsonb_build_object('ok',true,'terminee',r IS NOT NULL,'resultat',r,'etat',e);
END;$f$;
REVOKE ALL ON FUNCTION public.finance_terrain_banque_recu(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.finance_terrain_banque_recu(uuid,text) TO authenticated;
COMMIT;
