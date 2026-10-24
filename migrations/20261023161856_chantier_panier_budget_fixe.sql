-- Arbitrage #94 : panier entier borne par les 30 % annonces, sans surcout technique.
BEGIN;
DO $g$ DECLARE h text;BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_besoin_jour_interne(jsonb,integer)');
 IF h IS NULL OR h NOT IN ('db2ff57c512261055adc54042a857c79','6cd6e6e2c11b4ea57a1a02221255d714') THEN RAISE EXCEPTION 'definition_non_examinee: chantier_besoin_jour_interne';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_besoin_jour_interne(p_ch jsonb,p_num integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=public,pg_temp AS $f$
DECLARE r jsonb;BEGIN
 IF p_ch->>'type'='construction' THEN
  SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO r FROM public.chantiers_besoins_jour WHERE position_cycle=((p_num-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;
 ELSIF p_ch->>'type'='reamenagement' THEN
  SELECT jsonb_object_agg(cle,floor(((p_ch->>'coutMateriaux')::numeric/(p_ch->>'dureeJours')::numeric/3/prix_base))) INTO r FROM public.ressources_economie WHERE cle IN('bois','minerai','metal') AND prix_base>0;
 END IF;
 IF r IS NULL OR (SELECT count(*) FROM jsonb_object_keys(r))<>3 THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
 RETURN r;
END;$f$;
COMMIT;
